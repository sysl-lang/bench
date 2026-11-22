#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

#include "benchmark.h"

// The C++ Element holds its value in a std::any; the values are int32_t and
// are never read, so the C Element holds an int32_t.
typedef struct Element {
  int32_t val;
  struct Element* next;
} Element;

static Element* Element_new(int32_t v) {
  Element* e = (Element*)malloc(sizeof(Element));
  e->val = v;
  e->next = NULL;
  return e;
}

// `delete e`: ~Element deletes the rest of the list first.
static void Element_delete(Element* self) {
  if (self->next != NULL) {
    Element_delete(self->next);
  }
  free(self);
}

static int32_t Element_length(const Element* self) {
  if (self->next == NULL) {
    return 1;
  }
  return 1 + Element_length(self->next);
}

static Element* make_list(int32_t length) {
  if (length == 0) {
    return NULL;
  }
  Element* e = Element_new(length);
  e->next = make_list(length - 1);
  return e;
}

static bool is_shorter_than(const Element* x, const Element* y) {
  const Element* x_tail = x;
  const Element* y_tail = y;

  while (y_tail != NULL) {
    if (x_tail == NULL) {
      return true;
    }
    x_tail = x_tail->next;
    y_tail = y_tail->next;
  }
  return false;
}

static Element* tail(Element* x, Element* y, Element* z) {
  if (is_shorter_than(y, x)) {
    return tail(tail(x->next, y, z), tail(y->next, z, x), tail(z->next, x, y));
  }
  return z;
}

static Result List_benchmark(Benchmark* self) {
  (void)self;
  Element* x = make_list(15);
  Element* y = make_list(10);
  Element* z = make_list(6);

  Element* result = tail(x, y, z);
  const int32_t l = Element_length(result);

  Element_delete(x);
  Element_delete(y);
  Element_delete(z);
  return (Result){.i = l};
}

static bool List_verify_result(Benchmark* self, Result result) {
  (void)self;
  return 10 == result.i;
}

static const BenchmarkVtbl List_vtbl = {Benchmark_destroy, List_benchmark,
                                        List_verify_result,
                                        Benchmark_inner_benchmark_loop};

Benchmark* List_new(void) {
  return Benchmark_alloc(sizeof(Benchmark), &List_vtbl);
}
