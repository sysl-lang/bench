// Upstream C++ deltablue.h and deltablue.cpp.
//
// Variables and constraints form a cyclic graph, so, as upstream's guidelines give C++ for this
// benchmark ("DeltaBlue uses object_tracker"), every one is allocated on its own in a tracker and
// freed when its test ends (memory.rs). References are `&'a`; mutable fields are `Cell`s, and a
// variable's constraint vector a `RefCell`.
//
// The constraint hierarchy is a trait, `AbstractConstraint`, called through `&dyn` as C++'s virtual
// methods are. Its non-virtual methods are inherent methods of the trait object. C++'s
// `BinaryConstraint` and `UnaryConstraint` are structs the concrete constraints hold, and where a
// C++ base method calls a virtual one (`recalculate` calls `execute`), the base receives the
// object as `&dyn` and the call is dynamic, as in C++.
//
// C++ keeps the strength tables in static members, initialized at the start of `chainTest` and
// released at the end of `projectionTest`. Rust has no mutable globals without `unsafe` or a lock,
// so `inner_benchmark_loop` builds the same tables at the same point and hands them to both tests;
// they are freed where C++ releases them.

use std::cell::{Cell, Ref, RefCell};
use std::ptr;

use crate::benchmark::Benchmark;
use crate::memory::Tracker;
use crate::som::{CustomHash, IdentityDictionary, Vector};

#[derive(Clone, Copy, PartialEq)]
enum Direction {
    Forward,
    Backward,
    None,
}

struct Sym {
    hash: u32,
}

impl CustomHash for Sym {
    fn custom_hash(&self) -> u32 {
        self.hash
    }
}

static ABSOLUTE_STRONGEST: Sym = Sym { hash: 0 };
static REQUIRED: Sym = Sym { hash: 1 };
static STRONG_PREFERRED: Sym = Sym { hash: 2 };
static PREFERRED: Sym = Sym { hash: 3 };
static STRONG_DEFAULT: Sym = Sym { hash: 4 };
static DEFAULT: Sym = Sym { hash: 5 };
static WEAK_DEFAULT: Sym = Sym { hash: 6 };
static ABSOLUTE_WEAKEST: Sym = Sym { hash: 7 };

type StrengthTable = IdentityDictionary<'static, Sym, i32>;
type StrengthConstants = IdentityDictionary<'static, Sym, Box<Strength>>;

struct Strength {
    arithmetic_value: i32,
    #[allow(dead_code)]
    symbolic_value: &'static Sym,
}

impl Strength {
    fn new(symbolic_value: &'static Sym, strength_table: &StrengthTable) -> Strength {
        Strength { arithmetic_value: *strength_table.at(symbolic_value).unwrap(), symbolic_value }
    }

    fn same_as(&self, s: &Strength) -> bool {
        self.arithmetic_value == s.arithmetic_value
    }

    fn stronger(&self, s: &Strength) -> bool {
        self.arithmetic_value < s.arithmetic_value
    }

    fn weaker(&self, s: &Strength) -> bool {
        self.arithmetic_value > s.arithmetic_value
    }

    #[allow(dead_code)]
    fn strongest<'s>(&'s self, s: &'s Strength) -> &'s Strength {
        if s.stronger(self) {
            s
        } else {
            self
        }
    }

    fn weakest<'s>(&'s self, s: &'s Strength) -> &'s Strength {
        if s.weaker(self) {
            s
        } else {
            self
        }
    }

    fn create_strength_table() -> Box<StrengthTable> {
        let mut strength_table = Box::new(IdentityDictionary::new());
        strength_table.at_put(&ABSOLUTE_STRONGEST, -10000);
        strength_table.at_put(&REQUIRED, -800);
        strength_table.at_put(&STRONG_PREFERRED, -600);
        strength_table.at_put(&PREFERRED, -400);
        strength_table.at_put(&STRONG_DEFAULT, -200);
        strength_table.at_put(&DEFAULT, 0);
        strength_table.at_put(&WEAK_DEFAULT, 500);
        strength_table.at_put(&ABSOLUTE_WEAKEST, 10000);
        strength_table
    }

    fn create_strength_constants(strength_table: &StrengthTable) -> Box<StrengthConstants> {
        let mut strength_constant = Box::new(IdentityDictionary::new());
        let keys = strength_table.get_keys();
        keys.for_each(|key| {
            strength_constant.at_put(*key, Box::new(Strength::new(key, strength_table)));
        });
        drop(keys);

        strength_constant
    }
}

/// C++'s static members of `Strength`: the tables and the two cached constants.
struct Strengths<'s> {
    #[allow(dead_code)]
    strength_table: &'s StrengthTable,
    strength_constant: &'s StrengthConstants,
    absolute_weakest: &'s Strength,
    required: &'s Strength,
}

impl<'s> Strengths<'s> {
    fn initialize_constants(strength_table: &'s StrengthTable, strength_constant: &'s StrengthConstants) -> Self {
        Strengths {
            strength_table,
            strength_constant,
            absolute_weakest: Strengths::lookup(strength_constant, &ABSOLUTE_WEAKEST),
            required: Strengths::lookup(strength_constant, &REQUIRED),
        }
    }

    fn lookup(strength_constant: &'s StrengthConstants, strength: &Sym) -> &'s Strength {
        strength_constant.at(strength).unwrap()
    }

    fn of(&self, strength: &Sym) -> &'s Strength {
        Strengths::lookup(self.strength_constant, strength)
    }
}

type ConstraintRef<'a> = &'a dyn AbstractConstraint<'a>;

fn same_constraint<'a>(c: ConstraintRef<'a>, d: Option<ConstraintRef<'a>>) -> bool {
    match d {
        Some(d) => ptr::addr_eq(c as *const dyn AbstractConstraint<'a>, d as *const dyn AbstractConstraint<'a>),
        None => false,
    }
}

trait AbstractConstraint<'a> {
    fn get_strength(&self) -> &'a Strength;

    fn is_input(&self) -> bool {
        false
    }

    fn is_satisfied(&self) -> bool;
    fn add_to_graph(&'a self);
    fn remove_from_graph(&'a self);
    fn choose_method(&self, mark: i32) -> Direction;
    fn execute(&self);
    fn inputs_do(&self, f: &mut dyn FnMut(&'a Variable<'a>));
    fn inputs_has_one(&self, f: &mut dyn FnMut(&'a Variable<'a>) -> bool) -> bool;
    fn mark_unsatisfied(&self);
    fn get_output(&self) -> &'a Variable<'a>;
    fn recalculate(&self);
}

impl<'a> dyn AbstractConstraint<'a> + 'a {
    fn add_constraint(&'a self, planner: &Planner<'a>) {
        self.add_to_graph();
        planner.incremental_add(self);
    }

    fn destroy_constraint(&'a self, planner: &Planner<'a>) {
        if self.is_satisfied() {
            planner.incremental_remove(self);
        }
        self.remove_from_graph();
    }

    fn inputs_known(&self, mark: i32) -> bool {
        !self.inputs_has_one(&mut |v| !(v.get_mark() == mark || v.get_stay() || v.get_determined_by().is_none()))
    }

    fn satisfy(&'a self, mark: i32, planner: &Planner<'a>) -> Option<ConstraintRef<'a>> {
        let overridden;

        self.choose_method(mark);

        if self.is_satisfied() {
            self.inputs_do(&mut |input| input.set_mark(mark));

            let out = self.get_output();
            overridden = out.get_determined_by();
            if let Some(overridden) = overridden {
                overridden.mark_unsatisfied();
            }
            out.set_determined_by(Some(self));
            if !planner.add_propagate(self, mark) {
                panic!("Cycle encountered");
            }
            out.set_mark(mark);
        } else {
            overridden = None;
            if self.get_strength().same_as(planner.strengths.required) {
                panic!("Could not satisfy a required constraint");
            }
        }
        overridden
    }
}

struct Variable<'a> {
    value: Cell<i32>,
    constraints: RefCell<Vector<ConstraintRef<'a>>>,
    determined_by: Cell<Option<ConstraintRef<'a>>>,
    mark: Cell<i32>,
    walk_strength: Cell<&'a Strength>,
    stay: Cell<bool>,
}

impl<'a> Variable<'a> {
    /// C++'s `new Variable()`.
    fn create(planner: &Planner<'a>) -> &'a Variable<'a> {
        planner.objects.variables.track(Variable {
            value: Cell::new(0),
            constraints: RefCell::new(Vector::with_capacity(2)),
            determined_by: Cell::new(None),
            mark: Cell::new(0),
            walk_strength: Cell::new(planner.strengths.absolute_weakest),
            stay: Cell::new(true),
        })
    }

    fn value(planner: &Planner<'a>, a_value: i32) -> &'a Variable<'a> {
        let v = Variable::create(planner);
        v.set_value(a_value);
        v
    }

    fn add_constraint(&self, c: ConstraintRef<'a>) {
        self.constraints.borrow_mut().append(c);
    }

    fn get_constraints(&self) -> Ref<'_, Vector<ConstraintRef<'a>>> {
        self.constraints.borrow()
    }

    fn get_determined_by(&self) -> Option<ConstraintRef<'a>> {
        self.determined_by.get()
    }

    fn set_determined_by(&self, c: Option<ConstraintRef<'a>>) {
        self.determined_by.set(c);
    }

    fn get_mark(&self) -> i32 {
        self.mark.get()
    }

    fn set_mark(&self, mark_value: i32) {
        self.mark.set(mark_value);
    }

    fn remove_constraint(&self, c: ConstraintRef<'a>) {
        self.constraints.borrow_mut().remove(&c);
        if same_constraint(c, self.determined_by.get()) {
            self.determined_by.set(None);
        }
    }

    fn get_stay(&self) -> bool {
        self.stay.get()
    }

    fn set_stay(&self, v: bool) {
        self.stay.set(v);
    }

    fn get_value(&self) -> i32 {
        self.value.get()
    }

    fn set_value(&self, value: i32) {
        self.value.set(value);
    }

    fn get_walk_strength(&self) -> &'a Strength {
        self.walk_strength.get()
    }

    fn set_walk_strength(&self, strength: &'a Strength) {
        self.walk_strength.set(strength);
    }
}

struct BinaryConstraint<'a> {
    strength: &'a Strength,
    v1: &'a Variable<'a>,
    v2: &'a Variable<'a>,
    direction: Cell<Direction>,
}

impl<'a> BinaryConstraint<'a> {
    fn new(var1: &'a Variable<'a>, var2: &'a Variable<'a>, strength: &Sym, planner: &Planner<'a>) -> Self {
        BinaryConstraint { strength: planner.strengths.of(strength), v1: var1, v2: var2, direction: Cell::new(Direction::None) }
    }

    fn is_satisfied(&self) -> bool {
        self.direction.get() != Direction::None
    }

    fn add_to_graph(&self, this: ConstraintRef<'a>) {
        self.v1.add_constraint(this);
        self.v2.add_constraint(this);
        self.direction.set(Direction::None);
    }

    fn remove_from_graph(&self, this: ConstraintRef<'a>) {
        self.v1.remove_constraint(this);
        self.v2.remove_constraint(this);
        self.direction.set(Direction::None);
    }

    fn choose_method(&self, mark: i32) -> Direction {
        if self.v1.get_mark() == mark {
            if self.v2.get_mark() != mark && self.strength.stronger(self.v2.get_walk_strength()) {
                self.direction.set(Direction::Forward);
                return self.direction.get();
            }

            self.direction.set(Direction::None);
            return self.direction.get();
        }

        if self.v2.get_mark() == mark {
            if self.v1.get_mark() != mark && self.strength.stronger(self.v1.get_walk_strength()) {
                self.direction.set(Direction::Backward);
                return self.direction.get();
            }

            self.direction.set(Direction::None);
            return self.direction.get();
        }

        if self.v1.get_walk_strength().weaker(self.v2.get_walk_strength()) {
            if self.strength.stronger(self.v1.get_walk_strength()) {
                self.direction.set(Direction::Backward);
                return self.direction.get();
            }

            self.direction.set(Direction::None);
            return self.direction.get();
        }

        if self.strength.stronger(self.v2.get_walk_strength()) {
            self.direction.set(Direction::Forward);
            return self.direction.get();
        }

        self.direction.set(Direction::None);
        self.direction.get()
    }

    fn inputs_do(&self, f: &mut dyn FnMut(&'a Variable<'a>)) {
        if self.direction.get() == Direction::Forward {
            f(self.v1);
        } else {
            f(self.v2);
        }
    }

    fn inputs_has_one(&self, f: &mut dyn FnMut(&'a Variable<'a>) -> bool) -> bool {
        if self.direction.get() == Direction::Forward {
            return f(self.v1);
        }
        f(self.v2)
    }

    fn mark_unsatisfied(&self) {
        self.direction.set(Direction::None);
    }

    fn get_output(&self) -> &'a Variable<'a> {
        if self.direction.get() == Direction::Forward {
            self.v2
        } else {
            self.v1
        }
    }

    fn recalculate(&self, this: &dyn AbstractConstraint<'a>) {
        let input;
        let out;

        if self.direction.get() == Direction::Forward {
            input = self.v1;
            out = self.v2;
        } else {
            input = self.v2;
            out = self.v1;
        }

        out.set_walk_strength(self.strength.weakest(input.get_walk_strength()));
        out.set_stay(input.get_stay());
        if out.get_stay() {
            this.execute();
        }
    }
}

struct UnaryConstraint<'a> {
    strength: &'a Strength,
    output: &'a Variable<'a>,
    satisfied: Cell<bool>,
}

impl<'a> UnaryConstraint<'a> {
    fn new(v: &'a Variable<'a>, strength: &Sym, planner: &Planner<'a>) -> Self {
        // C++ calls addConstraint from the subclass constructor, so that the right methods run.
        UnaryConstraint { strength: planner.strengths.of(strength), output: v, satisfied: Cell::new(false) }
    }

    fn is_satisfied(&self) -> bool {
        self.satisfied.get()
    }

    fn add_to_graph(&self, this: ConstraintRef<'a>) {
        self.output.add_constraint(this);
        self.satisfied.set(false);
    }

    fn remove_from_graph(&self, this: ConstraintRef<'a>) {
        self.output.remove_constraint(this);
        self.satisfied.set(false);
    }

    fn choose_method(&self, mark: i32) -> Direction {
        self.satisfied.set(self.output.get_mark() != mark && self.strength.stronger(self.output.get_walk_strength()));
        Direction::None
    }

    fn mark_unsatisfied(&self) {
        self.satisfied.set(false);
    }

    fn get_output(&self) -> &'a Variable<'a> {
        self.output
    }

    fn recalculate(&self, this: &dyn AbstractConstraint<'a>) {
        self.output.set_walk_strength(self.strength);
        self.output.set_stay(!this.is_input());
        if self.output.get_stay() {
            this.execute();
        }
    }
}

/// The trait members a unary constraint takes from `UnaryConstraint` unchanged.
macro_rules! unary_members {
    () => {
        fn get_strength(&self) -> &'a Strength {
            self.base.strength
        }
        fn is_satisfied(&self) -> bool {
            self.base.is_satisfied()
        }
        fn add_to_graph(&'a self) {
            self.base.add_to_graph(self);
        }
        fn remove_from_graph(&'a self) {
            self.base.remove_from_graph(self);
        }
        fn choose_method(&self, mark: i32) -> Direction {
            self.base.choose_method(mark)
        }
        fn inputs_do(&self, _f: &mut dyn FnMut(&'a Variable<'a>)) {}
        fn inputs_has_one(&self, _f: &mut dyn FnMut(&'a Variable<'a>) -> bool) -> bool {
            false
        }
        fn mark_unsatisfied(&self) {
            self.base.mark_unsatisfied();
        }
        fn get_output(&self) -> &'a Variable<'a> {
            self.base.get_output()
        }
        fn recalculate(&self) {
            self.base.recalculate(self);
        }
    };
}

struct EditConstraint<'a> {
    base: UnaryConstraint<'a>,
}

impl<'a> EditConstraint<'a> {
    fn new(v: &'a Variable<'a>, strength: &Sym, planner: &Planner<'a>) -> &'a EditConstraint<'a> {
        let c = planner.objects.edit.track(EditConstraint { base: UnaryConstraint::new(v, strength, planner) });
        (c as ConstraintRef<'a>).add_constraint(planner);
        c
    }
}

impl<'a> AbstractConstraint<'a> for EditConstraint<'a> {
    unary_members!();

    fn is_input(&self) -> bool {
        true
    }

    fn execute(&self) {
        // Edit constraints do nothing.
    }
}

struct EqualityConstraint<'a> {
    base: BinaryConstraint<'a>,
}

impl<'a> EqualityConstraint<'a> {
    fn new(var1: &'a Variable<'a>, var2: &'a Variable<'a>, strength: &Sym, planner: &Planner<'a>) -> &'a EqualityConstraint<'a> {
        let c = planner.objects.equality.track(EqualityConstraint { base: BinaryConstraint::new(var1, var2, strength, planner) });
        (c as ConstraintRef<'a>).add_constraint(planner);
        c
    }
}

impl<'a> AbstractConstraint<'a> for EqualityConstraint<'a> {
    fn get_strength(&self) -> &'a Strength {
        self.base.strength
    }
    fn is_satisfied(&self) -> bool {
        self.base.is_satisfied()
    }
    fn add_to_graph(&'a self) {
        self.base.add_to_graph(self);
    }
    fn remove_from_graph(&'a self) {
        self.base.remove_from_graph(self);
    }
    fn choose_method(&self, mark: i32) -> Direction {
        self.base.choose_method(mark)
    }
    fn inputs_do(&self, f: &mut dyn FnMut(&'a Variable<'a>)) {
        self.base.inputs_do(f);
    }
    fn inputs_has_one(&self, f: &mut dyn FnMut(&'a Variable<'a>) -> bool) -> bool {
        self.base.inputs_has_one(f)
    }
    fn mark_unsatisfied(&self) {
        self.base.mark_unsatisfied();
    }
    fn get_output(&self) -> &'a Variable<'a> {
        self.base.get_output()
    }
    fn recalculate(&self) {
        self.base.recalculate(self);
    }

    fn execute(&self) {
        if self.base.direction.get() == Direction::Forward {
            self.base.v2.set_value(self.base.v1.get_value());
        } else {
            self.base.v1.set_value(self.base.v2.get_value());
        }
    }
}

struct Plan<'a> {
    constraints: Vector<ConstraintRef<'a>>,
}

impl<'a> Plan<'a> {
    fn new() -> Plan<'a> {
        Plan { constraints: Vector::with_capacity(15) }
    }

    fn append(&mut self, c: ConstraintRef<'a>) {
        self.constraints.append(c);
    }

    fn execute(&self) {
        self.constraints.for_each(|c| c.execute());
    }
}

struct ScaleConstraint<'a> {
    base: BinaryConstraint<'a>,
    scale: &'a Variable<'a>,
    offset: &'a Variable<'a>,
}

impl<'a> ScaleConstraint<'a> {
    fn new(
        src: &'a Variable<'a>,
        scale: &'a Variable<'a>,
        offset: &'a Variable<'a>,
        dest: &'a Variable<'a>,
        strength: &Sym,
        planner: &Planner<'a>,
    ) -> &'a ScaleConstraint<'a> {
        let c = planner.objects.scale.track(ScaleConstraint { base: BinaryConstraint::new(src, dest, strength, planner), scale, offset });
        (c as ConstraintRef<'a>).add_constraint(planner);
        c
    }
}

impl<'a> AbstractConstraint<'a> for ScaleConstraint<'a> {
    fn get_strength(&self) -> &'a Strength {
        self.base.strength
    }
    fn is_satisfied(&self) -> bool {
        self.base.is_satisfied()
    }
    fn choose_method(&self, mark: i32) -> Direction {
        self.base.choose_method(mark)
    }
    fn inputs_has_one(&self, f: &mut dyn FnMut(&'a Variable<'a>) -> bool) -> bool {
        self.base.inputs_has_one(f)
    }
    fn mark_unsatisfied(&self) {
        self.base.mark_unsatisfied();
    }
    fn get_output(&self) -> &'a Variable<'a> {
        self.base.get_output()
    }

    fn add_to_graph(&'a self) {
        self.base.v1.add_constraint(self);
        self.base.v2.add_constraint(self);
        self.scale.add_constraint(self);
        self.offset.add_constraint(self);
        self.base.direction.set(Direction::None);
    }

    fn remove_from_graph(&'a self) {
        self.base.v1.remove_constraint(self);
        self.base.v2.remove_constraint(self);
        self.scale.remove_constraint(self);
        self.offset.remove_constraint(self);
        self.base.direction.set(Direction::None);
    }

    fn execute(&self) {
        let base = &self.base;
        if base.direction.get() == Direction::Forward {
            base.v2.set_value(base.v1.get_value() * self.scale.get_value() + self.offset.get_value());
        } else {
            base.v1.set_value((base.v2.get_value() - self.offset.get_value()) / self.scale.get_value());
        }
    }

    fn inputs_do(&self, f: &mut dyn FnMut(&'a Variable<'a>)) {
        if self.base.direction.get() == Direction::Forward {
            f(self.base.v1);
            f(self.scale);
            f(self.offset);
        } else {
            f(self.base.v2);
            f(self.scale);
            f(self.offset);
        }
    }

    fn recalculate(&self) {
        let input;
        let out;

        if self.base.direction.get() == Direction::Forward {
            input = self.base.v1;
            out = self.base.v2;
        } else {
            out = self.base.v1;
            input = self.base.v2;
        }

        out.set_walk_strength(self.base.strength.weakest(input.get_walk_strength()));
        out.set_stay(input.get_stay() && self.scale.get_stay() && self.offset.get_stay());
        if out.get_stay() {
            self.execute(); // stay optimization
        }
    }
}

struct StayConstraint<'a> {
    base: UnaryConstraint<'a>,
}

impl<'a> StayConstraint<'a> {
    fn new(v: &'a Variable<'a>, strength: &Sym, planner: &Planner<'a>) -> &'a StayConstraint<'a> {
        let c = planner.objects.stay.track(StayConstraint { base: UnaryConstraint::new(v, strength, planner) });
        (c as ConstraintRef<'a>).add_constraint(planner);
        c
    }
}

impl<'a> AbstractConstraint<'a> for StayConstraint<'a> {
    unary_members!();

    fn execute(&self) {
        // StayConstraints do nothing.
    }
}

/// C++'s `ObjectTracker` for one test: every variable and constraint `new` allocates.
struct Objects<'a> {
    variables: Tracker<Variable<'a>>,
    equality: Tracker<EqualityConstraint<'a>>,
    scale: Tracker<ScaleConstraint<'a>>,
    stay: Tracker<StayConstraint<'a>>,
    edit: Tracker<EditConstraint<'a>>,
}

impl<'a> Objects<'a> {
    fn new() -> Self {
        Objects { variables: Tracker::new(), equality: Tracker::new(), scale: Tracker::new(), stay: Tracker::new(), edit: Tracker::new() }
    }
}

struct Planner<'a> {
    current_mark: Cell<i32>,
    objects: &'a Objects<'a>,
    strengths: &'a Strengths<'a>,
}

impl<'a> Planner<'a> {
    fn new(objects: &'a Objects<'a>, strengths: &'a Strengths<'a>) -> Self {
        Planner { current_mark: Cell::new(1), objects, strengths }
    }

    fn incremental_add(&self, c: ConstraintRef<'a>) {
        let mark = self.new_mark();
        let mut overridden = c.satisfy(mark, self);

        while let Some(o) = overridden {
            overridden = o.satisfy(mark, self);
        }
    }

    fn incremental_remove(&self, c: ConstraintRef<'a>) {
        let out = c.get_output();
        c.mark_unsatisfied();
        c.remove_from_graph();

        let unsatisfied = self.remove_propagate_from(out);
        unsatisfied.for_each(|u| self.incremental_add(*u));
        drop(unsatisfied);
    }

    fn extract_plan_from_constraints(&self, constraints: &Vector<ConstraintRef<'a>>) -> Box<Plan<'a>> {
        let mut sources = Vector::new();
        constraints.for_each(|c| {
            if c.is_input() && c.is_satisfied() {
                sources.append(*c);
            }
        });
        self.make_plan(&mut sources)
    }

    fn make_plan(&self, sources: &mut Vector<ConstraintRef<'a>>) -> Box<Plan<'a>> {
        let mark = self.new_mark();
        let mut plan = Box::new(Plan::new());
        let todo = sources;

        while !todo.is_empty() {
            let c = todo.remove_first().unwrap();

            if c.get_output().get_mark() != mark && c.inputs_known(mark) {
                plan.append(c);
                c.get_output().set_mark(mark);
                self.add_constraints_consuming_to(c.get_output(), todo);
            }
        }

        plan
    }

    fn add_constraints_consuming_to(&self, v: &'a Variable<'a>, coll: &mut Vector<ConstraintRef<'a>>) {
        let determining_c = v.get_determined_by();

        v.get_constraints().for_each(|c| {
            if !same_constraint(*c, determining_c) && c.is_satisfied() {
                coll.append(*c);
            }
        });
    }

    fn add_propagate(&self, c: ConstraintRef<'a>, mark: i32) -> bool {
        let mut todo = Vector::with(c);

        while !todo.is_empty() {
            let d = todo.remove_first().unwrap();

            if d.get_output().get_mark() == mark {
                self.incremental_remove(c);
                drop(todo);
                return false;
            }

            d.recalculate();
            self.add_constraints_consuming_to(d.get_output(), &mut todo);
        }

        drop(todo);
        true
    }

    fn change(&self, var: &'a Variable<'a>, new_value: i32) {
        let edit_c: ConstraintRef<'a> = EditConstraint::new(var, &PREFERRED, self);
        let edit_v = Vector::with(edit_c);
        let plan = self.extract_plan_from_constraints(&edit_v);

        for _ in 0..10 {
            var.set_value(new_value);
            plan.execute();
        }

        edit_c.destroy_constraint(self);
        drop(plan);
        drop(edit_v);
    }

    fn constraints_consuming(&self, v: &'a Variable<'a>, mut f: impl FnMut(ConstraintRef<'a>)) {
        let determining_c = v.get_determined_by();

        v.get_constraints().for_each(|c| {
            if !same_constraint(*c, determining_c) && c.is_satisfied() {
                f(*c);
            }
        });
    }

    fn new_mark(&self) -> i32 {
        self.current_mark.set(self.current_mark.get() + 1);
        self.current_mark.get()
    }

    fn remove_propagate_from(&self, out: &'a Variable<'a>) -> Box<Vector<ConstraintRef<'a>>> {
        let mut unsatisfied = Box::new(Vector::new());

        out.set_determined_by(None);
        out.set_walk_strength(self.strengths.absolute_weakest);
        out.set_stay(true);

        let mut todo = Vector::with(out);

        while !todo.is_empty() {
            let v = todo.remove_first().unwrap();

            v.get_constraints().for_each(|c| {
                if !c.is_satisfied() {
                    unsatisfied.append(*c);
                }
            });

            self.constraints_consuming(v, |c| {
                c.recalculate();
                todo.append(c.get_output());
            });
        }
        drop(todo);

        unsatisfied.sort(|c1, c2| if c1.get_strength().stronger(c2.get_strength()) { -1 } else { 1 });

        unsatisfied
    }

    fn chain_test(n: i32, strengths: &Strengths) {
        let objects = Objects::new();
        let planner = Planner::new(&objects, strengths);
        let mut vars = Vec::with_capacity((n + 1) as usize);
        for _ in 0..n + 1 {
            vars.push(Variable::create(&planner));
        }
        let vars = vars.into_boxed_slice();
        for i in 0..n as usize {
            let v1 = vars[i];
            let v2 = vars[i + 1];
            EqualityConstraint::new(v1, v2, &REQUIRED, &planner);
        }
        StayConstraint::new(vars[n as usize], &STRONG_DEFAULT, &planner);

        let edit_c: ConstraintRef = EditConstraint::new(vars[0], &PREFERRED, &planner);
        let edit_v = Vector::with(edit_c);
        let plan = planner.extract_plan_from_constraints(&edit_v);
        drop(edit_v);

        for i in 0..100 {
            vars[0].set_value(i);
            plan.execute();
            if vars[n as usize].get_value() != i {
                panic!("Chain test failed!");
            }
        }
        edit_c.destroy_constraint(&planner);
        drop(plan);
        drop(vars);
        drop(planner);
        // `objects` is freed at the end of the scope: C++'s ObjectTracker::releaseAll().
    }

    fn projection_test(n: i32, strengths: &Strengths) {
        let objects = Objects::new();
        let planner = Planner::new(&objects, strengths);
        let mut dests = Vector::new();

        let scale = Variable::value(&planner, 10);
        let offset = Variable::value(&planner, 1000);

        let mut src = None;
        let mut dst = None;
        for i in 1..=n {
            let s = Variable::value(&planner, i);
            let d = Variable::value(&planner, i);
            src = Some(s);
            dst = Some(d);
            dests.append(d);
            StayConstraint::new(s, &DEFAULT, &planner);
            ScaleConstraint::new(s, scale, offset, d, &REQUIRED, &planner);
        }
        let (src, dst) = (src.unwrap(), dst.unwrap());

        planner.change(src, 17);
        if dst.get_value() != 1170 {
            panic!("Projection test 1 failed!");
        }

        planner.change(dst, 1050);
        if src.get_value() != 5 {
            panic!("Projection test 2 failed!");
        }

        planner.change(scale, 5);
        for i in 0..n - 1 {
            let di = *dests.at(i as usize).unwrap();
            if di.get_value() != (i + 1) * 5 + 1000 {
                panic!("Projection test 3 failed!");
            }
        }

        planner.change(offset, 2000);
        for i in 0..n - 1 {
            let di = *dests.at(i as usize).unwrap();
            if di.get_value() != (i + 1) * 5 + 2000 {
                panic!("Projection test 4 failed!");
            }
        }
        drop(dests);
        drop(planner);
        // `objects` is freed at the end of the scope: C++'s ObjectTracker::releaseAll().
    }
}

pub struct DeltaBlue;

impl Benchmark for DeltaBlue {
    type Result = ();

    fn inner_benchmark_loop(&mut self, inner_iterations: i32) -> bool {
        // C++ Strength::initializeConstants(), at the start of chainTest.
        let strength_table = Strength::create_strength_table();
        let strength_constant = Strength::create_strength_constants(&strength_table);
        let strengths = Strengths::initialize_constants(&strength_table, &strength_constant);

        Planner::chain_test(inner_iterations, &strengths);
        Planner::projection_test(inner_iterations, &strengths);

        // C++ Strength::releaseConstants(), at the end of projectionTest.
        drop(strengths);
        drop(strength_constant);
        drop(strength_table);
        true
    }

    fn benchmark(&mut self) {}

    fn verify_result(&mut self, _result: ()) -> bool {
        false
    }
}
