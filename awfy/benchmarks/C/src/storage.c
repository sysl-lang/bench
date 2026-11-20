#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>

#include "benchmark.h"
#include "som/random.h"

// `new ArrayTree[n]` and `delete[]`: ArrayTree has a destructor, so C++
// stores the element count in front of the array (the array cookie) for
// delete[] to run n destructors. C keeps the count in a header in the same
// allocation.
typedef struct ArrayTreeArray ArrayTreeArray;

typedef struct ArrayTree {
  ArrayTreeArray* children;
} ArrayTree;

struct ArrayTreeArray {
  size_t length;
  ArrayTree items[];
};

static ArrayTreeArray* ArrayTree_new_array(size_t n) {
  ArrayTreeArray* a =
      (ArrayTreeArray*)malloc(sizeof(ArrayTreeArray) + n * sizeof(ArrayTree));
  a->length = n;
  for (size_t i = 0; i < n; i += 1) {
    a->items[i].children = NULL;
  }
  return a;
}

// delete[]: each element's ~ArrayTree deletes its children array.
static void ArrayTree_delete_array(ArrayTreeArray* a) {
  if (a == NULL) {
    return;
  }
  for (size_t i = a->length; i > 0; i -= 1) {
    ArrayTree_delete_array(a->items[i - 1].children);
  }
  free(a);
}

typedef struct Storage {
  Benchmark base;
  int32_t count;
} Storage;

static ArrayTreeArray* build_tree_depth(Storage* self, int32_t depth,
                                        Random* random) {
  self->count += 1;
  if (depth == 1) {
    return ArrayTree_new_array((size_t)(Random_next(random) % 10 + 1));
  }

  ArrayTreeArray* arr = ArrayTree_new_array(4);
  for (size_t i = 0; i < 4; i += 1) {
    arr->items[i].children = build_tree_depth(self, depth - 1, random);
  }
  return arr;
}

static Result Storage_benchmark(Benchmark* base) {
  Storage* self = (Storage*)base;
  Random random = Random_make();

  self->count = 0;
  ArrayTreeArray* result = build_tree_depth(self, 7, &random);
  ArrayTree_delete_array(result);

  return (Result){.i = self->count};
}

static bool Storage_verify_result(Benchmark* self, Result result) {
  (void)self;
  return 5461 == result.i;
}

static const BenchmarkVtbl Storage_vtbl = {
    Benchmark_destroy, Storage_benchmark, Storage_verify_result,
    Benchmark_inner_benchmark_loop};

Benchmark* Storage_new(void) {
  Storage* s = (Storage*)Benchmark_alloc(sizeof(Storage), &Storage_vtbl);
  s->count = 0;
  return &s->base;
}
