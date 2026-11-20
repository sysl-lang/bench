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
  static inline void Name##_init(Name* self) {                                 \
    Vec##_init(&self->items, VECTOR_INITIAL_SIZE);                             \
  }                                                                            \
                                                                               \
  static inline Name* Name##_new(void) {                                       \
    Name* s = (Name*)malloc(sizeof(Name));                                     \
    Name##_init(s);                                                            \
    return s;                                                                  \
  }                                                                            \
                                                                               \
  static inline void Name##_deinit(Name* self) { Vec##_deinit(&self->items); } \
                                                                               \
  static inline void Name##_delete(Name* self) {                               \
    Name##_deinit(self);                                                       \
    free(self);                                                                \
  }                                                                            \
                                                                               \
  static inline size_t Name##_size(const Name* self) {                         \
    return Vec##_size(&self->items);                                           \
  }                                                                            \
                                                                               \
  static inline void Name##_for_each(                                          \
      const Name* self, void (*fn)(void* ctx, const E* e), void* ctx) {        \
    Vec##_for_each(&self->items, fn, ctx);                                     \
  }                                                                            \
                                                                               \
  static inline bool Name##_contains_test(void* ctx, const E* e) {             \
    return equal(*e, *(const E*)ctx);                                          \
  }                                                                            \
                                                                               \
  static inline bool Name##_contains(const Name* self, E obj) {                \
    return Vec##_has_some(&self->items, Name##_contains_test, &obj);           \
  }                                                                            \
                                                                               \
  static inline void Name##_add(Name* self, E obj) {                           \
    if (!Name##_contains(self, obj)) {                                         \
      Vec##_append(&self->items, obj);                                         \
    }                                                                          \
  }
