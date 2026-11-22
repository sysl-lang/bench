#pragma once

// som/set.h and som/identity_set.h of the C++ port, as a typed C module.
//
// Set<E> keeps its items in a Vector<E> made with INITIAL_SIZE storage.
// add() calls Set::contains, which compares with e->equal(obj) (== for
// int32_t). IdentitySet<E> only hides contains() with a non-virtual identity
// version that add() does not reach, and the benchmarks never call it, so an
// IdentitySet behaves as a Set at run time: DEFINE_SET serves both, with the
// element type's equal() passed in. `Vec` is the DEFINE_VECTOR type of E.

#include "vector.h"

#define DEFINE_SET(Name, Vec, E, equal)                                        \
  typedef struct Name {                                                        \
    Vec items;                                                                 \
  } Name;                                                                      \
                                                                               \
  SOM_INLINE void Name##_init(Name* self) {                                 \
    Vec##_init(&self->items, VECTOR_INITIAL_SIZE);                             \
  }                                                                            \
                                                                               \
  SOM_INLINE Name* Name##_new(void) {                                       \
    Name* s = (Name*)malloc(sizeof(Name));                                     \
    Name##_init(s);                                                            \
    return s;                                                                  \
  }                                                                            \
                                                                               \
  SOM_INLINE void Name##_deinit(Name* self) { Vec##_deinit(&self->items); } \
                                                                               \
  SOM_INLINE void Name##_delete(Name* self) {                               \
    Name##_deinit(self);                                                       \
    free(self);                                                                \
  }                                                                            \
                                                                               \
  SOM_INLINE size_t Name##_size(const Name* self) {                         \
    return Vec##_size(&self->items);                                           \
  }                                                                            \
                                                                               \
  SOM_INLINE void Name##_for_each(                                          \
      const Name* self, void (*fn)(void* ctx, E const* e), void* ctx) {        \
    Vec##_for_each(&self->items, fn, ctx);                                     \
  }                                                                            \
                                                                               \
  SOM_INLINE bool Name##_contains_test(void* ctx, E const* e) {             \
    return equal(*e, *(E const*)ctx);                                          \
  }                                                                            \
                                                                               \
  SOM_INLINE bool Name##_contains(const Name* self, E obj) {                \
    return Vec##_has_some(&self->items, Name##_contains_test, &obj);           \
  }                                                                            \
                                                                               \
  SOM_INLINE void Name##_add(Name* self, E obj) {                           \
    if (!Name##_contains(self, obj)) {                                         \
      Vec##_append(&self->items, obj);                                         \
    }                                                                          \
  }
