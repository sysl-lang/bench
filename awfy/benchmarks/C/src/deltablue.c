#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

#include "benchmark.h"
#include "memory/object_tracker.h"
#include "som/dictionary.h"
#include "som/error.h"
#include "som/vector.h"

// Constraints and Variables are TrackedObjects, freed by the ObjectTracker as
// in C++. AbstractConstraint's virtual methods are a vtable (ConstraintVtbl)
// whose first member is the TrackedObject vtable (the virtual destructor);
// each concrete class has one, filled with its own and its bases' methods as
// C++ resolves them. Non-virtual members are plain functions. Closures passed
// to inputsDo/inputsHasOne/forEach are a function pointer and a context.

typedef enum Direction { FORWARD, BACKWARD, NONE } Direction;

// ---- Sym and Strength

typedef struct Sym {
  uint32_t hash;
} Sym;

static inline uint32_t Sym_custom_hash(const Sym* self) {
  return self->hash;
}

static const Sym ABSOLUTE_STRONGEST = {0};
static const Sym REQUIRED = {1};
static const Sym STRONG_PREFERRED = {2};
static const Sym PREFERRED = {3};
static const Sym STRONG_DEFAULT = {4};
static const Sym DEFAULT = {5};
static const Sym WEAK_DEFAULT = {6};
static const Sym ABSOLUTE_WEAKEST = {7};

typedef struct Strength {
  int32_t arithmetic_value;
  const Sym* symbolic_value;
} Strength;

DEFINE_VECTOR(SymVector, const Sym*)
DEFINE_IDENTITY_DICTIONARY(StrengthTable, Sym, int32_t, SymVector,
                           Sym_custom_hash)
DEFINE_IDENTITY_DICTIONARY(StrengthConstants, Sym, const Strength*, SymVector,
                           Sym_custom_hash)

static StrengthTable* strength_table;
static StrengthConstants* strength_constant;
static const Strength* strength_absolute_weakest;
static const Strength* strength_required;

static Strength* Strength_new(const Sym* symbolic_value) {
  Strength* s = (Strength*)malloc(sizeof(Strength));
  s->arithmetic_value = *StrengthTable_at(strength_table, symbolic_value);
  s->symbolic_value = symbolic_value;
  return s;
}

static void Strength_delete(const Strength* self) {
  free((void*)self);
}

static inline bool Strength_same_as(const Strength* self, const Strength* s) {
  return self->arithmetic_value == s->arithmetic_value;
}

static inline bool Strength_stronger(const Strength* self, const Strength* s) {
  return self->arithmetic_value < s->arithmetic_value;
}

static inline bool Strength_weaker(const Strength* self, const Strength* s) {
  return self->arithmetic_value > s->arithmetic_value;
}

static inline const Strength* Strength_weakest(const Strength* self,
                                               const Strength* s) {
  return Strength_weaker(s, self) ? s : self;
}

static inline const Strength* Strength_of(const Sym* strength) {
  return *StrengthConstants_at(strength_constant, strength);
}

static StrengthTable* create_strength_table(void) {
  StrengthTable* t = StrengthTable_new();
  StrengthTable_at_put(t, &ABSOLUTE_STRONGEST, -10000);
  StrengthTable_at_put(t, &REQUIRED, -800);
  StrengthTable_at_put(t, &STRONG_PREFERRED, -600);
  StrengthTable_at_put(t, &PREFERRED, -400);
  StrengthTable_at_put(t, &STRONG_DEFAULT, -200);
  StrengthTable_at_put(t, &DEFAULT, 0);
  StrengthTable_at_put(t, &WEAK_DEFAULT, 500);
  StrengthTable_at_put(t, &ABSOLUTE_WEAKEST, 10000);
  return t;
}

static void put_strength_constant(void* ctx, const Sym* const* key) {
  StrengthConstants* constants = (StrengthConstants*)ctx;
  StrengthConstants_at_put(constants, *key, Strength_new(*key));
}

static StrengthConstants* create_strength_constants(void) {
  StrengthConstants* constants = StrengthConstants_new();
  SymVector* keys = StrengthTable_get_keys(strength_table);
  SymVector_for_each(keys, put_strength_constant, constants);
  SymVector_delete(keys);
  return constants;
}

static void Strength_initialize_constants(void) {
  strength_table = create_strength_table();
  strength_constant = create_strength_constants();
  strength_absolute_weakest = Strength_of(&ABSOLUTE_WEAKEST);
  strength_required = Strength_of(&REQUIRED);
}

static void Strength_release_constants(void) {
  StrengthTable_delete(strength_table);
  StrengthConstants_destroy_values(strength_constant, Strength_delete);
  StrengthConstants_delete(strength_constant);
  strength_absolute_weakest = NULL;
  strength_required = NULL;
}

// ---- Classes

typedef struct AbstractConstraint AbstractConstraint;
typedef struct Variable Variable;
typedef struct Planner Planner;

DEFINE_VECTOR_OF_POINTERS(ConstraintVector, AbstractConstraint*)
DEFINE_VECTOR_OF_POINTERS(VariableVector, Variable*)

typedef void (*VariableFn)(void* ctx, Variable* v);
typedef bool (*VariableTest)(void* ctx, Variable* v);

typedef struct ConstraintVtbl {
  TrackedObjectVtbl object;
  bool (*is_input)(AbstractConstraint* self);
  bool (*is_satisfied)(AbstractConstraint* self);
  void (*add_to_graph)(AbstractConstraint* self);
  void (*remove_from_graph)(AbstractConstraint* self);
  Direction (*choose_method)(AbstractConstraint* self, int32_t mark);
  void (*execute)(AbstractConstraint* self);
  void (*inputs_do)(AbstractConstraint* self, VariableFn fn, void* ctx);
  bool (*inputs_has_one)(AbstractConstraint* self, VariableTest fn, void* ctx);
  void (*mark_unsatisfied)(AbstractConstraint* self);
  Variable* (*get_output)(AbstractConstraint* self);
  void (*recalculate)(AbstractConstraint* self);
} ConstraintVtbl;

struct AbstractConstraint {
  TrackedObject base;
  const Strength* strength;
  Planner* planer;
};

static inline const ConstraintVtbl* vt(const AbstractConstraint* c) {
  return (const ConstraintVtbl*)c->base.vt;
}

struct Variable {
  TrackedObject base;
  int32_t value;
  ConstraintVector* constraints;
  AbstractConstraint* determined_by;
  int32_t mark;
  const Strength* walk_strength;
  bool stay;
};

typedef struct BinaryConstraint {
  AbstractConstraint base;
  Variable* v1;
  Variable* v2;
  Direction direction;
} BinaryConstraint;

typedef struct UnaryConstraint {
  AbstractConstraint base;
  Variable* output;
  bool satisfied;
} UnaryConstraint;

typedef UnaryConstraint EditConstraint;
typedef UnaryConstraint StayConstraint;
typedef BinaryConstraint EqualityConstraint;

typedef struct ScaleConstraint {
  BinaryConstraint base;
  Variable* scale;
  Variable* offset;
} ScaleConstraint;

struct Planner {
  int32_t current_mark;
};

static void Planner_incremental_add(Planner* self, AbstractConstraint* c);
static void Planner_incremental_remove(Planner* self, AbstractConstraint* c);
static bool Planner_add_propagate(Planner* self, AbstractConstraint* c,
                                  int32_t mark);

// ---- Variable

static void Variable_destroy(TrackedObject* o) {
  Variable* self = (Variable*)o;
  ConstraintVector_delete(self->constraints);
  free(self);
}

static const TrackedObjectVtbl Variable_vtbl = {Variable_destroy};

static Variable* Variable_new(void) {
  Variable* v = (Variable*)malloc(sizeof(Variable));
  TrackedObject_init(&v->base, &Variable_vtbl);
  v->value = 0;
  v->constraints = ConstraintVector_new(2);
  v->determined_by = NULL;
  v->mark = 0;
  v->walk_strength = strength_absolute_weakest;
  v->stay = true;
  return v;
}

static Variable* Variable_value(int32_t a_value) {
  Variable* v = Variable_new();
  v->value = a_value;
  return v;
}

static inline void Variable_add_constraint(Variable* self,
                                           AbstractConstraint* c) {
  ConstraintVector_append(self->constraints, c);
}

static inline void Variable_remove_constraint(Variable* self,
                                              AbstractConstraint* c) {
  ConstraintVector_remove(self->constraints, c);
  if (self->determined_by == c) {
    self->determined_by = NULL;
  }
}

// ---- AbstractConstraint

static void AbstractConstraint_init(AbstractConstraint* self,
                                    const ConstraintVtbl* vtbl,
                                    const Sym* strength) {
  TrackedObject_init(&self->base, &vtbl->object);
  self->strength = Strength_of(strength);
  self->planer = NULL;
}

static void AbstractConstraint_destroy(TrackedObject* o) {
  free(o);
}

static bool AbstractConstraint_is_input(AbstractConstraint* self) {
  (void)self;
  return false;
}

static void AbstractConstraint_add_constraint(AbstractConstraint* self,
                                              Planner* planner) {
  vt(self)->add_to_graph(self);
  Planner_incremental_add(planner, self);
}

static void AbstractConstraint_destroy_constraint(AbstractConstraint* self,
                                                  Planner* planner) {
  if (vt(self)->is_satisfied(self)) {
    Planner_incremental_remove(planner, self);
  }
  vt(self)->remove_from_graph(self);
}

static bool inputs_known_test(void* ctx, Variable* v) {
  const int32_t mark = *(const int32_t*)ctx;
  return !(v->mark == mark || v->stay || v->determined_by == NULL);
}

static bool AbstractConstraint_inputs_known(AbstractConstraint* self,
                                            int32_t mark) {
  return !vt(self)->inputs_has_one(self, inputs_known_test, &mark);
}

static void set_mark_fn(void* ctx, Variable* in) {
  in->mark = *(const int32_t*)ctx;
}

static AbstractConstraint* AbstractConstraint_satisfy(AbstractConstraint* self,
                                                      int32_t mark,
                                                      Planner* planner) {
  AbstractConstraint* overridden = NULL;

  vt(self)->choose_method(self, mark);

  if (vt(self)->is_satisfied(self)) {
    vt(self)->inputs_do(self, set_mark_fn, &mark);

    Variable* out = vt(self)->get_output(self);
    overridden = out->determined_by;
    if (overridden != NULL) {
      vt(overridden)->mark_unsatisfied(overridden);
    }
    out->determined_by = self;
    if (!Planner_add_propagate(planner, self, mark)) {
      error("Cycle encountered");
    }
    out->mark = mark;
  } else {
    overridden = NULL;
    if (Strength_same_as(self->strength, strength_required)) {
      error("Could not satisfy a required constraint");
    }
  }
  return overridden;
}

// ---- BinaryConstraint

static void BinaryConstraint_init(BinaryConstraint* self,
                                  const ConstraintVtbl* vtbl, Variable* var1,
                                  Variable* var2, const Sym* strength) {
  AbstractConstraint_init(&self->base, vtbl, strength);
  self->v1 = var1;
  self->v2 = var2;
  self->direction = NONE;
}

static bool BinaryConstraint_is_satisfied(AbstractConstraint* c) {
  return ((BinaryConstraint*)c)->direction != NONE;
}

static void BinaryConstraint_add_to_graph(AbstractConstraint* c) {
  BinaryConstraint* self = (BinaryConstraint*)c;
  Variable_add_constraint(self->v1, c);
  Variable_add_constraint(self->v2, c);
  self->direction = NONE;
}

static void BinaryConstraint_remove_from_graph(AbstractConstraint* c) {
  BinaryConstraint* self = (BinaryConstraint*)c;
  Variable_remove_constraint(self->v1, c);
  Variable_remove_constraint(self->v2, c);
  self->direction = NONE;
}

static Direction BinaryConstraint_choose_method(AbstractConstraint* c,
                                                int32_t mark) {
  BinaryConstraint* self = (BinaryConstraint*)c;
  const Strength* strength = c->strength;
  if (self->v1->mark == mark) {
    if (self->v2->mark != mark &&
        Strength_stronger(strength, self->v2->walk_strength)) {
      self->direction = FORWARD;
      return self->direction;
    }

    self->direction = NONE;
    return self->direction;
  }

  if (self->v2->mark == mark) {
    if (self->v1->mark != mark &&
        Strength_stronger(strength, self->v1->walk_strength)) {
      self->direction = BACKWARD;
      return self->direction;
    }

    self->direction = NONE;
    return self->direction;
  }

  if (Strength_weaker(self->v1->walk_strength, self->v2->walk_strength)) {
    if (Strength_stronger(strength, self->v1->walk_strength)) {
      self->direction = BACKWARD;
      return self->direction;
    }

    self->direction = NONE;
    return self->direction;
  }

  if (Strength_stronger(strength, self->v2->walk_strength)) {
    self->direction = FORWARD;
    return self->direction;
  }

  self->direction = NONE;
  return self->direction;
}

static void BinaryConstraint_inputs_do(AbstractConstraint* c, VariableFn fn,
                                       void* ctx) {
  BinaryConstraint* self = (BinaryConstraint*)c;
  if (self->direction == FORWARD) {
    fn(ctx, self->v1);
  } else {
    fn(ctx, self->v2);
  }
}

static bool BinaryConstraint_inputs_has_one(AbstractConstraint* c,
                                            VariableTest fn, void* ctx) {
  BinaryConstraint* self = (BinaryConstraint*)c;
  if (self->direction == FORWARD) {
    return fn(ctx, self->v1);
  }
  return fn(ctx, self->v2);
}

static void BinaryConstraint_mark_unsatisfied(AbstractConstraint* c) {
  ((BinaryConstraint*)c)->direction = NONE;
}

static Variable* BinaryConstraint_get_output(AbstractConstraint* c) {
  BinaryConstraint* self = (BinaryConstraint*)c;
  return self->direction == FORWARD ? self->v2 : self->v1;
}

static void BinaryConstraint_recalculate(AbstractConstraint* c) {
  BinaryConstraint* self = (BinaryConstraint*)c;
  Variable* in = NULL;
  Variable* out = NULL;

  if (self->direction == FORWARD) {
    in = self->v1;
    out = self->v2;
  } else {
    in = self->v2;
    out = self->v1;
  }

  out->walk_strength = Strength_weakest(c->strength, in->walk_strength);
  out->stay = in->stay;
  if (out->stay) {
    vt(c)->execute(c);
  }
}

// ---- UnaryConstraint

static void UnaryConstraint_init(UnaryConstraint* self,
                                 const ConstraintVtbl* vtbl, Variable* v,
                                 const Sym* strength) {
  AbstractConstraint_init(&self->base, vtbl, strength);
  self->output = v;
  self->satisfied = false;
}

static bool UnaryConstraint_is_satisfied(AbstractConstraint* c) {
  return ((UnaryConstraint*)c)->satisfied;
}

static void UnaryConstraint_add_to_graph(AbstractConstraint* c) {
  UnaryConstraint* self = (UnaryConstraint*)c;
  Variable_add_constraint(self->output, c);
  self->satisfied = false;
}

static void UnaryConstraint_remove_from_graph(AbstractConstraint* c) {
  UnaryConstraint* self = (UnaryConstraint*)c;
  if (self->output != NULL) {
    Variable_remove_constraint(self->output, c);
  }
  self->satisfied = false;
}

static Direction UnaryConstraint_choose_method(AbstractConstraint* c,
                                               int32_t mark) {
  UnaryConstraint* self = (UnaryConstraint*)c;
  self->satisfied = (self->output->mark != mark) &&
                    Strength_stronger(c->strength, self->output->walk_strength);
  return NONE;
}

static void UnaryConstraint_inputs_do(AbstractConstraint* c, VariableFn fn,
                                      void* ctx) {
  (void)c;
  (void)fn;
  (void)ctx;
}

static bool UnaryConstraint_inputs_has_one(AbstractConstraint* c,
                                           VariableTest fn, void* ctx) {
  (void)c;
  (void)fn;
  (void)ctx;
  return false;
}

static void UnaryConstraint_mark_unsatisfied(AbstractConstraint* c) {
  ((UnaryConstraint*)c)->satisfied = false;
}

static Variable* UnaryConstraint_get_output(AbstractConstraint* c) {
  return ((UnaryConstraint*)c)->output;
}

static void UnaryConstraint_recalculate(AbstractConstraint* c) {
  UnaryConstraint* self = (UnaryConstraint*)c;
  self->output->walk_strength = c->strength;
  self->output->stay = !vt(c)->is_input(c);
  if (self->output->stay) {
    vt(c)->execute(c);
  }
}

// ---- EditConstraint

static bool EditConstraint_is_input(AbstractConstraint* c) {
  (void)c;
  return true;
}

static void EditConstraint_execute(AbstractConstraint* c) {
  (void)c;
  // Edit constraints do nothing.
}

static const ConstraintVtbl EditConstraint_vtbl = {
    {AbstractConstraint_destroy},
    EditConstraint_is_input,
    UnaryConstraint_is_satisfied,
    UnaryConstraint_add_to_graph,
    UnaryConstraint_remove_from_graph,
    UnaryConstraint_choose_method,
    EditConstraint_execute,
    UnaryConstraint_inputs_do,
    UnaryConstraint_inputs_has_one,
    UnaryConstraint_mark_unsatisfied,
    UnaryConstraint_get_output,
    UnaryConstraint_recalculate,
};

static EditConstraint* EditConstraint_new(Variable* v, const Sym* strength,
                                          Planner* planner) {
  EditConstraint* c = (EditConstraint*)malloc(sizeof(EditConstraint));
  UnaryConstraint_init(c, &EditConstraint_vtbl, v, strength);
  AbstractConstraint_add_constraint(&c->base, planner);
  return c;
}

// ---- StayConstraint

static void StayConstraint_execute(AbstractConstraint* c) {
  (void)c;
  // StayConstraints do nothing.
}

static const ConstraintVtbl StayConstraint_vtbl = {
    {AbstractConstraint_destroy},
    AbstractConstraint_is_input,
    UnaryConstraint_is_satisfied,
    UnaryConstraint_add_to_graph,
    UnaryConstraint_remove_from_graph,
    UnaryConstraint_choose_method,
    StayConstraint_execute,
    UnaryConstraint_inputs_do,
    UnaryConstraint_inputs_has_one,
    UnaryConstraint_mark_unsatisfied,
    UnaryConstraint_get_output,
    UnaryConstraint_recalculate,
};

static StayConstraint* StayConstraint_new(Variable* v, const Sym* strength,
                                          Planner* planner) {
  StayConstraint* c = (StayConstraint*)malloc(sizeof(StayConstraint));
  UnaryConstraint_init(c, &StayConstraint_vtbl, v, strength);
  AbstractConstraint_add_constraint(&c->base, planner);
  return c;
}

// ---- EqualityConstraint

static void EqualityConstraint_execute(AbstractConstraint* c) {
  BinaryConstraint* self = (BinaryConstraint*)c;
  if (self->direction == FORWARD) {
    self->v2->value = self->v1->value;
  } else {
    self->v1->value = self->v2->value;
  }
}

static const ConstraintVtbl EqualityConstraint_vtbl = {
    {AbstractConstraint_destroy},
    AbstractConstraint_is_input,
    BinaryConstraint_is_satisfied,
    BinaryConstraint_add_to_graph,
    BinaryConstraint_remove_from_graph,
    BinaryConstraint_choose_method,
    EqualityConstraint_execute,
    BinaryConstraint_inputs_do,
    BinaryConstraint_inputs_has_one,
    BinaryConstraint_mark_unsatisfied,
    BinaryConstraint_get_output,
    BinaryConstraint_recalculate,
};

static EqualityConstraint* EqualityConstraint_new(Variable* var1,
                                                  Variable* var2,
                                                  const Sym* strength,
                                                  Planner* planner) {
  EqualityConstraint* c =
      (EqualityConstraint*)malloc(sizeof(EqualityConstraint));
  BinaryConstraint_init(c, &EqualityConstraint_vtbl, var1, var2, strength);
  AbstractConstraint_add_constraint(&c->base, planner);
  return c;
}

// ---- ScaleConstraint

static void ScaleConstraint_add_to_graph(AbstractConstraint* c) {
  ScaleConstraint* self = (ScaleConstraint*)c;
  Variable_add_constraint(self->base.v1, c);
  Variable_add_constraint(self->base.v2, c);
  Variable_add_constraint(self->scale, c);
  Variable_add_constraint(self->offset, c);
  self->base.direction = NONE;
}

static void ScaleConstraint_remove_from_graph(AbstractConstraint* c) {
  ScaleConstraint* self = (ScaleConstraint*)c;
  if (self->base.v1 != NULL) {
    Variable_remove_constraint(self->base.v1, c);
  }
  if (self->base.v2 != NULL) {
    Variable_remove_constraint(self->base.v2, c);
  }
  if (self->scale != NULL) {
    Variable_remove_constraint(self->scale, c);
  }
  if (self->offset != NULL) {
    Variable_remove_constraint(self->offset, c);
  }
  self->base.direction = NONE;
}

static void ScaleConstraint_execute(AbstractConstraint* c) {
  ScaleConstraint* self = (ScaleConstraint*)c;
  if (self->base.direction == FORWARD) {
    self->base.v2->value =
        self->base.v1->value * self->scale->value + self->offset->value;
  } else {
    self->base.v1->value =
        (self->base.v2->value - self->offset->value) / self->scale->value;
  }
}

static void ScaleConstraint_inputs_do(AbstractConstraint* c, VariableFn fn,
                                      void* ctx) {
  ScaleConstraint* self = (ScaleConstraint*)c;
  if (self->base.direction == FORWARD) {
    fn(ctx, self->base.v1);
    fn(ctx, self->scale);
    fn(ctx, self->offset);
  } else {
    fn(ctx, self->base.v2);
    fn(ctx, self->scale);
    fn(ctx, self->offset);
  }
}

static void ScaleConstraint_recalculate(AbstractConstraint* c) {
  ScaleConstraint* self = (ScaleConstraint*)c;
  Variable* in = NULL;
  Variable* out = NULL;

  if (self->base.direction == FORWARD) {
    in = self->base.v1;
    out = self->base.v2;
  } else {
    out = self->base.v1;
    in = self->base.v2;
  }

  out->walk_strength = Strength_weakest(c->strength, in->walk_strength);
  out->stay = in->stay && self->scale->stay && self->offset->stay;
  if (out->stay) {
    vt(c)->execute(c);  // stay optimization
  }
}

static const ConstraintVtbl ScaleConstraint_vtbl = {
    {AbstractConstraint_destroy},
    AbstractConstraint_is_input,
    BinaryConstraint_is_satisfied,
    ScaleConstraint_add_to_graph,
    ScaleConstraint_remove_from_graph,
    BinaryConstraint_choose_method,
    ScaleConstraint_execute,
    ScaleConstraint_inputs_do,
    BinaryConstraint_inputs_has_one,
    BinaryConstraint_mark_unsatisfied,
    BinaryConstraint_get_output,
    ScaleConstraint_recalculate,
};

static ScaleConstraint* ScaleConstraint_new(Variable* src, Variable* scale,
                                            Variable* offset, Variable* dest,
                                            const Sym* strength,
                                            Planner* planner) {
  ScaleConstraint* c = (ScaleConstraint*)malloc(sizeof(ScaleConstraint));
  BinaryConstraint_init(&c->base, &ScaleConstraint_vtbl, src, dest, strength);
  c->scale = scale;
  c->offset = offset;
  AbstractConstraint_add_constraint(&c->base.base, planner);
  return c;
}

// ---- Plan: a Vector<AbstractConstraint*> made with capacity 15

typedef ConstraintVector Plan;

static Plan* Plan_new(void) {
  return ConstraintVector_new(15);
}

static void plan_execute_fn(void* ctx, AbstractConstraint* const* c) {
  (void)ctx;
  vt(*c)->execute(*c);
}

static void Plan_execute(Plan* self) {
  ConstraintVector_for_each(self, plan_execute_fn, NULL);
}

// ---- Planner

static int32_t Planner_new_mark(Planner* self) {
  self->current_mark += 1;
  return self->current_mark;
}

static void Planner_incremental_add(Planner* self, AbstractConstraint* c) {
  const int32_t mark = Planner_new_mark(self);
  AbstractConstraint* overridden = AbstractConstraint_satisfy(c, mark, self);

  while (overridden != NULL) {
    overridden = AbstractConstraint_satisfy(overridden, mark, self);
  }
}

typedef struct ConsumingCtx {
  AbstractConstraint* determining_c;
  ConstraintVector* coll;
} ConsumingCtx;

static void add_consuming_fn(void* ctx, AbstractConstraint* const* cp) {
  ConsumingCtx* k = (ConsumingCtx*)ctx;
  AbstractConstraint* c = *cp;
  if (c != k->determining_c && vt(c)->is_satisfied(c)) {
    ConstraintVector_append(k->coll, c);
  }
}

static void Planner_add_constraints_consuming_to(Planner* self, Variable* v,
                                                 ConstraintVector* coll) {
  (void)self;
  ConsumingCtx k = {v->determined_by, coll};
  ConstraintVector_for_each(v->constraints, add_consuming_fn, &k);
}

static int32_t compare_strength(AbstractConstraint* c1,
                                AbstractConstraint* c2) {
  return Strength_stronger(c1->strength, c2->strength) ? -1 : 1;
}

static void collect_unsatisfied_fn(void* ctx, AbstractConstraint* const* cp) {
  AbstractConstraint* c = *cp;
  if (!vt(c)->is_satisfied(c)) {
    ConstraintVector_append((ConstraintVector*)ctx, c);
  }
}

typedef void (*ConstraintFn)(void* ctx, AbstractConstraint* c);

typedef struct ConstraintsConsumingCtx {
  AbstractConstraint* determining_c;
  ConstraintFn fn;
  void* fn_ctx;
} ConstraintsConsumingCtx;

static void constraints_consuming_fn(void* ctx, AbstractConstraint* const* cp) {
  ConstraintsConsumingCtx* k = (ConstraintsConsumingCtx*)ctx;
  AbstractConstraint* c = *cp;
  if (c != k->determining_c && vt(c)->is_satisfied(c)) {
    k->fn(k->fn_ctx, c);
  }
}

static void Planner_constraints_consuming(Planner* self, Variable* v,
                                          ConstraintFn fn, void* fn_ctx) {
  (void)self;
  ConstraintsConsumingCtx k = {v->determined_by, fn, fn_ctx};
  ConstraintVector_for_each(v->constraints, constraints_consuming_fn, &k);
}

static void recalculate_and_push_fn(void* ctx, AbstractConstraint* c) {
  VariableVector* todo = (VariableVector*)ctx;
  vt(c)->recalculate(c);
  VariableVector_append(todo, vt(c)->get_output(c));
}

static ConstraintVector* Planner_remove_propagate_from(Planner* self,
                                                       Variable* out) {
  ConstraintVector* unsatisfied = ConstraintVector_new(0);

  out->determined_by = NULL;
  out->walk_strength = strength_absolute_weakest;
  out->stay = true;

  VariableVector* todo = VariableVector_with(out);

  while (!VariableVector_is_empty(todo)) {
    Variable* v = VariableVector_remove_first(todo);

    ConstraintVector_for_each(v->constraints, collect_unsatisfied_fn,
                              unsatisfied);

    Planner_constraints_consuming(self, v, recalculate_and_push_fn, todo);
  }
  VariableVector_delete(todo);

  ConstraintVector_sort(unsatisfied, compare_strength);

  return unsatisfied;
}

static void incremental_add_fn(void* ctx, AbstractConstraint* const* u) {
  Planner_incremental_add((Planner*)ctx, *u);
}

static void Planner_incremental_remove(Planner* self, AbstractConstraint* c) {
  Variable* out = vt(c)->get_output(c);
  vt(c)->mark_unsatisfied(c);
  vt(c)->remove_from_graph(c);

  ConstraintVector* unsatisfied = Planner_remove_propagate_from(self, out);
  ConstraintVector_for_each(unsatisfied, incremental_add_fn, self);
  ConstraintVector_delete(unsatisfied);
}

static Plan* Planner_make_plan(Planner* self, ConstraintVector* sources) {
  const int32_t mark = Planner_new_mark(self);
  Plan* plan = Plan_new();
  ConstraintVector* todo = sources;

  while (!ConstraintVector_is_empty(todo)) {
    AbstractConstraint* c = ConstraintVector_remove_first(todo);

    if (vt(c)->get_output(c)->mark != mark &&
        AbstractConstraint_inputs_known(c, mark)) {
      ConstraintVector_append(plan, c);
      vt(c)->get_output(c)->mark = mark;
      Planner_add_constraints_consuming_to(self, vt(c)->get_output(c), todo);
    }
  }

  return plan;
}

static void collect_sources_fn(void* ctx, AbstractConstraint* const* cp) {
  AbstractConstraint* c = *cp;
  if (vt(c)->is_input(c) && vt(c)->is_satisfied(c)) {
    ConstraintVector_append((ConstraintVector*)ctx, c);
  }
}

static Plan* Planner_extract_plan_from_constraints(
    Planner* self, ConstraintVector* constraints) {
  ConstraintVector sources;
  ConstraintVector_init(&sources, 0);
  ConstraintVector_for_each(constraints, collect_sources_fn, &sources);
  Plan* plan = Planner_make_plan(self, &sources);
  ConstraintVector_deinit(&sources);
  return plan;
}

static bool Planner_add_propagate(Planner* self, AbstractConstraint* c,
                                  int32_t mark) {
  ConstraintVector* todo = ConstraintVector_with(c);

  while (!ConstraintVector_is_empty(todo)) {
    AbstractConstraint* d = ConstraintVector_remove_first(todo);

    if (vt(d)->get_output(d)->mark == mark) {
      Planner_incremental_remove(self, c);
      ConstraintVector_delete(todo);
      return false;
    }

    vt(d)->recalculate(d);
    Planner_add_constraints_consuming_to(self, vt(d)->get_output(d), todo);
  }

  ConstraintVector_delete(todo);
  return true;
}

static void Planner_change(Planner* self, Variable* var, int32_t new_value) {
  EditConstraint* edit_c = EditConstraint_new(var, &PREFERRED, self);
  ConstraintVector* edit_v = ConstraintVector_with(&edit_c->base);
  Plan* plan = Planner_extract_plan_from_constraints(self, edit_v);

  for (int32_t i = 0; i < 10; i += 1) {
    var->value = new_value;
    Plan_execute(plan);
  }

  AbstractConstraint_destroy_constraint(&edit_c->base, self);
  ConstraintVector_delete(plan);
  ConstraintVector_delete(edit_v);
}

static void Planner_chain_test(int32_t n) {
  Strength_initialize_constants();
  Planner planner = {1};
  Variable** vars = (Variable**)malloc((size_t)(n + 1) * sizeof(Variable*));
  for (int32_t i = 0; i < n + 1; i += 1) {
    vars[i] = Variable_new();
  }
  for (int32_t i = 0; i < n; i += 1) {
    Variable* v1 = vars[i];
    Variable* v2 = vars[i + 1];
    EqualityConstraint_new(v1, v2, &REQUIRED, &planner);
  }
  StayConstraint_new(vars[n], &STRONG_DEFAULT, &planner);

  EditConstraint* edit_c = EditConstraint_new(vars[0], &PREFERRED, &planner);
  ConstraintVector* edit_v = ConstraintVector_with(&edit_c->base);
  Plan* plan = Planner_extract_plan_from_constraints(&planner, edit_v);
  ConstraintVector_delete(edit_v);

  for (int32_t i = 0; i < 100; i += 1) {
    vars[0]->value = i;
    Plan_execute(plan);
    if (vars[n]->value != i) {
      error("Chain test failed!");
    }
  }
  AbstractConstraint_destroy_constraint(&edit_c->base, &planner);
  ConstraintVector_delete(plan);
  free(vars);
  ObjectTracker_release_all();
}

static void Planner_projection_test(int32_t n) {
  Planner planner = {1};
  VariableVector dests;
  VariableVector_init(&dests, 0);

  Variable* scale = Variable_value(10);
  Variable* offset = Variable_value(1000);

  Variable* src = NULL;
  Variable* dst = NULL;
  for (int32_t i = 1; i <= n; i += 1) {
    src = Variable_value(i);
    dst = Variable_value(i);
    VariableVector_append(&dests, dst);
    StayConstraint_new(src, &DEFAULT, &planner);
    ScaleConstraint_new(src, scale, offset, dst, &REQUIRED, &planner);
  }

  Planner_change(&planner, src, 17);
  if (dst->value != 1170) {
    error("Projection test 1 failed!");
  }

  Planner_change(&planner, dst, 1050);
  if (src->value != 5) {
    error("Projection test 2 failed!");
  }

  Planner_change(&planner, scale, 5);
  for (int32_t i = 0; i < n - 1; i += 1) {
    Variable* di = *VariableVector_at(&dests, (size_t)i);
    if (di->value != (i + 1) * 5 + 1000) {
      error("Projection test 3 failed!");
    }
  }

  Planner_change(&planner, offset, 2000);
  for (int32_t i = 0; i < n - 1; i += 1) {
    Variable* di = *VariableVector_at(&dests, (size_t)i);
    if (di->value != (i + 1) * 5 + 2000) {
      error("Projection test 4 failed!");
    }
  }
  ObjectTracker_release_all();
  Strength_release_constants();
  VariableVector_deinit(&dests);
}

// ---- DeltaBlue

static bool DeltaBlue_inner_benchmark_loop(Benchmark* self,
                                           int32_t inner_iterations) {
  (void)self;
  Planner_chain_test(inner_iterations);
  Planner_projection_test(inner_iterations);
  return true;
}

static Result DeltaBlue_benchmark(Benchmark* self) {
  (void)self;
  return (Result){.p = NULL};
}

static bool DeltaBlue_verify_result(Benchmark* self, Result result) {
  (void)self;
  (void)result;
  return false;
}

static const BenchmarkVtbl DeltaBlue_vtbl = {
    Benchmark_destroy, DeltaBlue_benchmark, DeltaBlue_verify_result,
    DeltaBlue_inner_benchmark_loop};

Benchmark* DeltaBlue_new(void) {
  return Benchmark_alloc(sizeof(Benchmark), &DeltaBlue_vtbl);
}
