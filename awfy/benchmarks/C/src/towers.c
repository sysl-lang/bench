#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "benchmark.h"

typedef struct TowersDisk {
  int32_t size;
  struct TowersDisk* next;
} TowersDisk;

static TowersDisk* TowersDisk_new(int32_t size) {
  TowersDisk* d = (TowersDisk*)malloc(sizeof(TowersDisk));
  d->size = size;
  d->next = NULL;
  return d;
}

// `delete disk`: ~TowersDisk deletes the disks below it.
static void TowersDisk_delete(TowersDisk* self) {
  if (self == NULL) {
    return;
  }
  TowersDisk_delete(self->next);
  free(self);
}

typedef struct Towers {
  Benchmark base;
  TowersDisk* piles[3];
  int32_t moves_done;
} Towers;

static void push_disk(Towers* self, TowersDisk* disk, int32_t pile) {
  TowersDisk* top = self->piles[pile];
  if (!(top == NULL) && (disk->size >= top->size)) {
    fprintf(stderr, "Cannot put a big disk on a smaller one");
    exit(1);
  }

  disk->next = top;
  self->piles[pile] = disk;
}

static TowersDisk* pop_disk_from(Towers* self, int32_t pile) {
  TowersDisk* top = self->piles[pile];
  if (top == NULL) {
    fprintf(stderr, "Attempting to remove a disk from an empty pile");
    exit(1);
  }

  self->piles[pile] = top->next;
  top->next = NULL;
  return top;
}

static void move_top_disk(Towers* self, int32_t from_pile, int32_t to_pile) {
  push_disk(self, pop_disk_from(self, from_pile), to_pile);
  self->moves_done += 1;
}

static void build_tower_at(Towers* self, int32_t pile, int32_t disks) {
  for (int32_t i = disks; i >= 0; i -= 1) {
    push_disk(self, TowersDisk_new(i), pile);
  }
}

static void move_disks(Towers* self, int32_t disks, int32_t from_pile,
                       int32_t to_pile) {
  if (disks == 1) {
    move_top_disk(self, from_pile, to_pile);
  } else {
    const int32_t other_pile = (3 - from_pile) - to_pile;
    move_disks(self, disks - 1, from_pile, other_pile);
    move_top_disk(self, from_pile, to_pile);
    move_disks(self, disks - 1, other_pile, to_pile);
  }
}

static Result Towers_benchmark(Benchmark* base) {
  Towers* self = (Towers*)base;
  self->piles[0] = NULL;
  self->piles[1] = NULL;
  self->piles[2] = NULL;
  build_tower_at(self, 0, 13);
  self->moves_done = 0;
  move_disks(self, 13, 0, 1);

  for (int32_t i = 0; i < 3; i += 1) {
    TowersDisk_delete(self->piles[i]);
  }

  return (Result){.i = self->moves_done};
}

static bool Towers_verify_result(Benchmark* self, Result result) {
  (void)self;
  return 8191 == result.i;
}

static const BenchmarkVtbl Towers_vtbl = {Benchmark_destroy, Towers_benchmark,
                                          Towers_verify_result,
                                          Benchmark_inner_benchmark_loop};

Benchmark* Towers_new(void) {
  Towers* t = (Towers*)Benchmark_alloc(sizeof(Towers), &Towers_vtbl);
  t->piles[0] = NULL;
  t->piles[1] = NULL;
  t->piles[2] = NULL;
  t->moves_done = 0;
  return &t->base;
}
