#pragma once

// som/dictionary.h and som/identity_dictionary.h of the C++ port, as a typed
// C module.
//
// The benchmarks instantiate only IdentityDictionary<K, V>, so that is what
// DEFINE_IDENTITY_DICTIONARY generates, with Dictionary's machinery in it.
// The C++ classes are polymorphic and the C keeps their dispatch:
//   - Entry has a virtual destructor and a virtual match(); IdEntry overrides
//     match. Each C entry carries a vtable pointer and both are called
//     through it.
//   - Dictionary has a virtual destructor and a virtual newEntry(), which
//     IdentityDictionary overrides; the C dictionary carries a vtable pointer
//     and atPut reaches newEntry through it.
// Keys are pointers (const K*); values are stored inline (V), as in C++.
// `KeyVec` is the DEFINE_VECTOR type of const K* that getKeys() returns.
// `custom_hash` is K's customHash(), a plain (non-virtual) call in C++.

#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

#include "vector.h"

#define DICTIONARY_INITIAL_CAPACITY 16U

#define DEFINE_IDENTITY_DICTIONARY(Name, K, V, KeyVec, custom_hash)            \
  typedef struct Name##Entry Name##Entry;                                      \
  typedef struct Name##EntryVtbl {                                             \
    void (*destroy)(Name##Entry* self);                                        \
    bool (*match)(const Name##Entry* self, uint32_t h, const K* k);            \
  } Name##EntryVtbl;                                                           \
  struct Name##Entry {                                                         \
    const Name##EntryVtbl* vt;                                                 \
    uint32_t hash;                                                             \
    const K* key;                                                              \
    V value;                                                                   \
    Name##Entry* next;                                                         \
  };                                                                           \
                                                                               \
  SOM_INLINE void Name##Entry_destroy(Name##Entry* self) { free(self); }    \
                                                                               \
  SOM_INLINE bool Name##IdEntry_match(const Name##Entry* self, uint32_t h,  \
                                         const K* k) {                         \
    return self->hash == h && self->key == k;                                  \
  }                                                                            \
                                                                               \
  static const Name##EntryVtbl Name##IdEntry_vtbl = {Name##Entry_destroy,      \
                                                     Name##IdEntry_match};     \
                                                                               \
  typedef struct Name Name;                                                    \
  typedef struct Name##Vtbl {                                                  \
    void (*destroy)(Name* self);                                               \
    Name##Entry* (*new_entry)(Name* self, const K* key, V value,               \
                              uint32_t hash);                                  \
  } Name##Vtbl;                                                                \
  struct Name {                                                                \
    const Name##Vtbl* vt;                                                      \
    Name##Entry** buckets;                                                     \
    uint32_t size;                                                             \
    uint32_t capacity;                                                         \
  };                                                                           \
                                                                               \
  SOM_INLINE uint32_t Name##_hash(const K* key) {                           \
    if (key == NULL) {                                                         \
      return 0;                                                                \
    }                                                                          \
    const uint32_t h = custom_hash(key);                                       \
    return h ^ (h >> 16U);                                                     \
  }                                                                            \
                                                                               \
  SOM_INLINE uint32_t Name##_bucket_idx(const Name* self, uint32_t hash) {  \
    return (self->capacity - 1) & hash;                                        \
  }                                                                            \
                                                                               \
  SOM_INLINE Name##Entry* Name##_get_bucket(const Name* self,               \
                                               uint32_t hash) {                \
    return self->buckets[Name##_bucket_idx(self, hash)];                       \
  }                                                                            \
                                                                               \
  SOM_INLINE void Name##_remove_all(Name* self) {                           \
    for (uint32_t i = 0; i < self->capacity; i += 1) {                         \
      Name##Entry* current = self->buckets[i];                                 \
      while (current != NULL) {                                                \
        Name##Entry* to_be_deleted = current;                                  \
        current = current->next;                                               \
        to_be_deleted->vt->destroy(to_be_deleted);                             \
      }                                                                        \
      self->buckets[i] = NULL;                                                 \
    }                                                                          \
    self->size = 0;                                                            \
  }                                                                            \
                                                                               \
  SOM_INLINE void Name##_deinit(Name* self) {                               \
    Name##_remove_all(self);                                                   \
    free(self->buckets);                                                       \
  }                                                                            \
                                                                               \
  SOM_INLINE void Name##_destroy(Name* self) {                              \
    Name##_deinit(self);                                                       \
    free(self);                                                                \
  }                                                                            \
                                                                               \
  /* IdentityDictionary::newEntry */                                           \
  SOM_INLINE Name##Entry* Name##_new_id_entry(Name* self, const K* key,     \
                                                 V value, uint32_t hash) {     \
    (void)self;                                                                \
    Name##Entry* e = (Name##Entry*)malloc(sizeof(Name##Entry));                \
    e->vt = &Name##IdEntry_vtbl;                                               \
    e->hash = hash;                                                            \
    e->key = key;                                                              \
    e->value = value;                                                          \
    e->next = NULL;                                                            \
    return e;                                                                  \
  }                                                                            \
                                                                               \
  static const Name##Vtbl Name##_vtbl = {Name##_destroy, Name##_new_id_entry}; \
                                                                               \
  SOM_INLINE void Name##_init(Name* self, uint32_t capacity) {              \
    self->vt = &Name##_vtbl;                                                   \
    self->buckets = (Name##Entry**)calloc(capacity, sizeof(Name##Entry*));     \
    self->size = 0;                                                            \
    self->capacity = capacity;                                                 \
  }                                                                            \
                                                                               \
  SOM_INLINE Name* Name##_new(void) {                                       \
    Name* d = (Name*)malloc(sizeof(Name));                                     \
    Name##_init(d, DICTIONARY_INITIAL_CAPACITY);                               \
    return d;                                                                  \
  }                                                                            \
                                                                               \
  /* delete through the base pointer: the virtual destructor */                \
  SOM_INLINE void Name##_delete(Name* self) { self->vt->destroy(self); }    \
                                                                               \
  SOM_INLINE uint32_t Name##_get_size(const Name* self) {                   \
    return self->size;                                                         \
  }                                                                            \
                                                                               \
  SOM_INLINE bool Name##_contains_key(const Name* self, const K* key) {     \
    const uint32_t h = Name##_hash(key);                                       \
    Name##Entry* e = Name##_get_bucket(self, h);                               \
    while (e != NULL) {                                                        \
      if (e->vt->match(e, h, key)) {                                           \
        return true;                                                           \
      }                                                                        \
      e = e->next;                                                             \
    }                                                                          \
    return false;                                                              \
  }                                                                            \
                                                                               \
  SOM_INLINE V* Name##_at(const Name* self, const K* key) {                 \
    const uint32_t h = Name##_hash(key);                                       \
    Name##Entry* e = Name##_get_bucket(self, h);                               \
    while (e != NULL) {                                                        \
      if (e->vt->match(e, h, key)) {                                           \
        return &e->value;                                                      \
      }                                                                        \
      e = e->next;                                                             \
    }                                                                          \
    return NULL;                                                               \
  }                                                                            \
                                                                               \
  SOM_INLINE void Name##_insert_bucket_entry(                               \
      Name* self, const K* key, V value, uint32_t hash, Name##Entry* head) {   \
    Name##Entry* current = head;                                               \
    for (;;) {                                                                 \
      if (current->vt->match(current, hash, key)) {                            \
        current->value = value;                                                \
        return;                                                                \
      }                                                                        \
      if (current->next == NULL) {                                             \
        self->size += 1;                                                       \
        current->next = self->vt->new_entry(self, key, value, hash);           \
        return;                                                                \
      }                                                                        \
      current = current->next;                                                 \
    }                                                                          \
  }                                                                            \
                                                                               \
  SOM_INLINE void Name##_split_bucket(Name* self, uint32_t old_capacity,    \
                                         uint32_t idx, Name##Entry* head) {    \
    Name##Entry* lo_head = NULL;                                               \
    Name##Entry* lo_tail = NULL;                                               \
    Name##Entry* hi_head = NULL;                                               \
    Name##Entry* hi_tail = NULL;                                               \
    Name##Entry* current = head;                                               \
    while (current != NULL) {                                                  \
      if ((current->hash & old_capacity) == 0) {                               \
        if (lo_tail == NULL) {                                                 \
          lo_head = current;                                                   \
        } else {                                                               \
          lo_tail->next = current;                                             \
        }                                                                      \
        lo_tail = current;                                                     \
      } else {                                                                 \
        if (hi_tail == NULL) {                                                 \
          hi_head = current;                                                   \
        } else {                                                               \
          hi_tail->next = current;                                             \
        }                                                                      \
        hi_tail = current;                                                     \
      }                                                                        \
      current = current->next;                                                 \
    }                                                                          \
    if (lo_tail != NULL) {                                                     \
      lo_tail->next = NULL;                                                    \
      self->buckets[idx] = lo_head;                                            \
    }                                                                          \
    if (hi_tail != NULL) {                                                     \
      hi_tail->next = NULL;                                                    \
      self->buckets[idx + old_capacity] = hi_head;                             \
    }                                                                          \
  }                                                                            \
                                                                               \
  SOM_INLINE void Name##_transfer_entries(                                  \
      Name* self, Name##Entry** old_storage, uint32_t old_capacity) {          \
    for (uint32_t i = 0; i < old_capacity; i += 1) {                           \
      Name##Entry* current = old_storage[i];                                   \
      if (current != NULL) {                                                   \
        old_storage[i] = NULL;                                                 \
        if (current->next == NULL) {                                           \
          self->buckets[current->hash & (old_capacity - 1)] = current;         \
        } else {                                                               \
          Name##_split_bucket(self, old_capacity, i, current);                 \
        }                                                                      \
      }                                                                        \
    }                                                                          \
  }                                                                            \
                                                                               \
  SOM_INLINE void Name##_resize(Name* self) {                               \
    Name##Entry** old_storage = self->buckets;                                 \
    const uint32_t old_capacity = self->capacity;                              \
    self->capacity *= 2;                                                       \
    self->buckets =                                                            \
        (Name##Entry**)calloc(self->capacity, sizeof(Name##Entry*));           \
    Name##_transfer_entries(self, old_storage, old_capacity);                  \
    free(old_storage);                                                         \
  }                                                                            \
                                                                               \
  SOM_INLINE void Name##_at_put(Name* self, const K* key, V value) {        \
    const uint32_t h = Name##_hash(key);                                       \
    const uint32_t i = Name##_bucket_idx(self, h);                             \
    Name##Entry* current = self->buckets[i];                                   \
    if (current == NULL) {                                                     \
      self->buckets[i] = self->vt->new_entry(self, key, value, h);             \
      self->size += 1;                                                         \
    } else {                                                                   \
      Name##_insert_bucket_entry(self, key, value, h, current);                \
    }                                                                          \
    if (self->size > self->capacity) {                                         \
      Name##_resize(self);                                                     \
    }                                                                          \
  }                                                                            \
                                                                               \
  SOM_INLINE KeyVec* Name##_get_keys(const Name* self) {                    \
    KeyVec* keys = KeyVec##_new(0);                                            \
    for (uint32_t i = 0; i < self->capacity; i += 1) {                         \
      Name##Entry* current = self->buckets[i];                                 \
      while (current != NULL) {                                                \
        KeyVec##_append(keys, current->key);                                   \
        current = current->next;                                               \
      }                                                                        \
    }                                                                          \
    return keys;                                                               \
  }                                                                            \
                                                                               \
  SOM_INLINE void Name##_destroy_values(Name* self, void (*destroy)(V)) {   \
    for (uint32_t i = 0; i < self->capacity; i += 1) {                         \
      Name##Entry* current = self->buckets[i];                                 \
      while (current != NULL) {                                                \
        destroy(current->value);                                               \
        current = current->next;                                               \
      }                                                                        \
    }                                                                          \
  }
