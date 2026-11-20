#pragma once

// som/vector.h of the C++ port, as a typed C module.
//
// The C++ Vector<E> is a template: each instantiation stores its elements
// inline, by value, and is compiled for its element type. DEFINE_VECTOR does
// the same in C: it generates a struct and static inline functions for one
// element type. DEFINE_VECTOR_OF_POINTERS adds the members the C++ template
// can only instantiate for pointer elements (remove, removeAll, sort, getOne,
// destroyValues; they compare with == or call delete).
//
// Closures (C++ std::function) are a function pointer and a context pointer.

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define VECTOR_INITIAL_SIZE ((size_t)10)

#define DEFINE_VECTOR(Name, E)                                                 \
  typedef struct Name {                                                        \
    E* storage;                                                                \
    size_t capacity;                                                           \
    size_t first_idx;                                                          \
    size_t last_idx;                                                           \
  } Name;                                                                      \
                                                                               \
  static inline void Name##_init(Name* self, size_t size) {                    \
    self->storage = size == 0 ? NULL : (E*)malloc(size * sizeof(E));           \
    self->capacity = size;                                                     \
    self->first_idx = 0;                                                       \
    self->last_idx = 0;                                                        \
  }                                                                            \
                                                                               \
  static inline Name* Name##_new(size_t size) {                                \
    Name* v = (Name*)malloc(sizeof(Name));                                     \
    Name##_init(v, size);                                                      \
    return v;                                                                  \
  }                                                                            \
                                                                               \
  static inline void Name##_deinit(Name* self) { free(self->storage); }        \
                                                                               \
  static inline void Name##_delete(Name* self) {                               \
    Name##_deinit(self);                                                       \
    free(self);                                                                \
  }                                                                            \
                                                                               \
  static inline E* Name##_at(const Name* self, size_t idx) {                   \
    if (self->storage == NULL || idx >= self->last_idx - self->first_idx) {    \
      return NULL;                                                             \
    }                                                                          \
    return &self->storage[self->first_idx + idx];                              \
  }                                                                            \
                                                                               \
  static inline void Name##_at_put(Name* self, size_t idx, E val) {           \
    if (self->storage == NULL) {                                               \
      self->capacity =                                                         \
          idx + 1 > VECTOR_INITIAL_SIZE ? idx + 1 : VECTOR_INITIAL_SIZE;       \
      self->storage = (E*)malloc(self->capacity * sizeof(E));                  \
    } else if (idx >= self->last_idx - self->first_idx) {                      \
      size_t new_length = self->capacity;                                      \
      while (new_length <= idx + self->first_idx) {                            \
        new_length *= 2;                                                       \
      }                                                                        \
      E* new_storage = (E*)malloc(new_length * sizeof(E));                     \
      memcpy(new_storage, self->storage, self->last_idx * sizeof(E));          \
      free(self->storage);                                                     \
      self->storage = new_storage;                                             \
      self->capacity = new_length;                                             \
    }                                                                          \
    self->storage[self->first_idx + idx] = val;                                \
    if (self->last_idx < idx + 1) {                                            \
      self->last_idx = idx + 1;                                                \
    }                                                                          \
  }                                                                            \
                                                                               \
  static inline void Name##_append(Name* self, E elem) {                       \
    if (self->storage == NULL) {                                               \
      self->storage = (E*)malloc(VECTOR_INITIAL_SIZE * sizeof(E));             \
      self->capacity = VECTOR_INITIAL_SIZE;                                    \
    } else if (self->last_idx >= self->capacity) {                             \
      self->capacity *= 2;                                                     \
      E* new_storage = (E*)malloc(self->capacity * sizeof(E));                 \
      memcpy(new_storage, self->storage, self->last_idx * sizeof(E));          \
      free(self->storage);                                                     \
      self->storage = new_storage;                                             \
    }                                                                          \
    self->storage[self->last_idx] = elem;                                      \
    self->last_idx += 1;                                                       \
  }                                                                            \
                                                                               \
  static inline Name* Name##_with(E elem) {                                    \
    Name* v = Name##_new(1);                                                   \
    Name##_append(v, elem);                                                    \
    return v;                                                                  \
  }                                                                            \
                                                                               \
  static inline bool Name##_is_empty(const Name* self) {                       \
    return self->last_idx == self->first_idx;                                  \
  }                                                                            \
                                                                               \
  static inline size_t Name##_size(const Name* self) {                         \
    return self->last_idx - self->first_idx;                                   \
  }                                                                            \
                                                                               \
  static inline void Name##_for_each(                                          \
      const Name* self, void (*fn)(void* ctx, const E* e), void* ctx) {        \
    for (size_t i = self->first_idx; i < self->last_idx; i += 1) {             \
      fn(ctx, &self->storage[i]);                                              \
    }                                                                          \
  }                                                                            \
                                                                               \
  static inline bool Name##_has_some(                                          \
      const Name* self, bool (*fn)(void* ctx, const E* e), void* ctx) {        \
    for (size_t i = self->first_idx; i < self->last_idx; i += 1) {             \
      if (fn(ctx, &self->storage[i])) {                                        \
        return true;                                                           \
      }                                                                        \
    }                                                                          \
    return false;                                                              \
  }

#define DEFINE_VECTOR_OF_POINTERS(Name, E)                                     \
  DEFINE_VECTOR(Name, E)                                                       \
                                                                               \
  static inline void Name##_destroy_values(Name* self, void (*destroy)(E)) {   \
    for (size_t i = self->first_idx; i < self->last_idx; i += 1) {             \
      destroy(self->storage[i]);                                               \
    }                                                                          \
  }                                                                            \
                                                                               \
  static inline E Name##_first(const Name* self) {                             \
    if (Name##_is_empty(self)) {                                               \
      return NULL;                                                             \
    }                                                                          \
    return self->storage[self->first_idx];                                     \
  }                                                                            \
                                                                               \
  static inline E Name##_remove_first(Name* self) {                            \
    if (Name##_is_empty(self)) {                                               \
      return NULL;                                                             \
    }                                                                          \
    self->first_idx += 1;                                                      \
    return self->storage[self->first_idx - 1];                                 \
  }                                                                            \
                                                                               \
  static inline bool Name##_remove(Name* self, E obj) {                        \
    if (self->storage == NULL || Name##_is_empty(self)) {                      \
      return false;                                                            \
    }                                                                          \
    bool found = false;                                                        \
    size_t new_last = self->first_idx;                                         \
    for (size_t i = self->first_idx; i < self->last_idx; i += 1) {             \
      if (self->storage[i] == obj) {                                           \
        found = true;                                                          \
      } else {                                                                 \
        self->storage[new_last] = self->storage[i];                            \
        new_last += 1;                                                         \
      }                                                                        \
    }                                                                          \
    self->last_idx = new_last;                                                 \
    return found;                                                              \
  }                                                                            \
                                                                               \
  static inline void Name##_remove_all(Name* self, void (*destroy)(E)) {       \
    Name##_destroy_values(self, destroy);                                      \
    self->first_idx = 0;                                                       \
    self->last_idx = 0;                                                        \
    if (self->storage != NULL) {                                               \
      free(self->storage);                                                     \
      self->storage = (E*)malloc(self->capacity * sizeof(E));                  \
    }                                                                          \
  }                                                                            \
                                                                               \
  /* Upstream's C++ sort calls a swap that is not implemented: it exits. */   \
  static inline void Name##_swap(E* storage, size_t i, size_t j) {             \
    (void)storage;                                                             \
    (void)i;                                                                   \
    (void)j;                                                                   \
    fprintf(stderr, "swap not implemented\n");                                 \
    exit(1);                                                                   \
  }                                                                            \
                                                                               \
  static inline void Name##_sort_range(Name* self, size_t i, size_t j,         \
                                       int32_t (*c)(E, E)) {                   \
    if (c == NULL) {                                                           \
      fprintf(stderr, "defaultSort not implemented\n");                        \
      exit(1);                                                                 \
    }                                                                          \
    const size_t n = j + 1 - i;                                                \
    if (n <= 1) {                                                              \
      return;                                                                  \
    }                                                                          \
    E* storage = self->storage;                                                \
    E di = storage[i];                                                         \
    E dj = storage[j];                                                         \
    if (c(di, dj) > 0) {                                                       \
      Name##_swap(storage, i, j);                                              \
      E tt = di;                                                               \
      di = dj;                                                                 \
      dj = tt;                                                                 \
    }                                                                          \
    if (n > 2) {                                                               \
      const size_t ij = (i + j) / 2;                                           \
      E dij = storage[ij];                                                     \
      if (c(di, dij) <= 0) {                                                   \
        if (c(dij, dj) > 0) {                                                  \
          Name##_swap(storage, j, ij);                                         \
          dij = dj;                                                            \
        }                                                                      \
      } else {                                                                 \
        Name##_swap(storage, i, ij);                                           \
        dij = di;                                                              \
      }                                                                        \
      if (n > 3) {                                                             \
        size_t k = i;                                                          \
        size_t l = j - 1;                                                      \
        for (;;) {                                                             \
          while (k <= l && c(dij, storage[l]) <= 0) {                          \
            l -= 1;                                                            \
          }                                                                    \
          k += 1;                                                              \
          while (k <= l && c(storage[k], dij) <= 0) {                          \
            k += 1;                                                            \
          }                                                                    \
          if (k > l) {                                                         \
            break;                                                             \
          }                                                                    \
          Name##_swap(storage, k, l);                                          \
        }                                                                      \
        Name##_sort_range(self, i, l, c);                                      \
        Name##_sort_range(self, k, j, c);                                      \
      }                                                                        \
    }                                                                          \
  }                                                                            \
                                                                               \
  static inline void Name##_sort(Name* self, int32_t (*c)(E, E)) {             \
    if (Name##_size(self) > 0) {                                               \
      Name##_sort_range(self, self->first_idx, self->last_idx - 1, c);         \
    }                                                                          \
  }
