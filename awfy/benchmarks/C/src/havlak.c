#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "benchmark.h"
#include "som/dictionary.h"
#include "som/error.h"
#include "som/set.h"
#include "som/vector.h"

// No class here has a virtual member in the C++ port, so every call is a
// plain function call. Memory is owned as in C++: the ControlFlowGraph owns
// the basic blocks and edges, the LoopStructureGraph the loops, the
// HavlakLoopFinder its sets, vectors, arrays and UnionFindNodes.

typedef struct BasicBlock BasicBlock;
typedef struct BasicBlockEdge BasicBlockEdge;
typedef struct SimpleLoop SimpleLoop;
typedef struct UnionFindNode UnionFindNode;

DEFINE_VECTOR(IntVector, int32_t)
DEFINE_VECTOR_OF_POINTERS(BasicBlockVector, BasicBlock*)
DEFINE_VECTOR_OF_POINTERS(EdgeVector, BasicBlockEdge*)
DEFINE_VECTOR_OF_POINTERS(LoopVector, SimpleLoop*)
DEFINE_VECTOR_OF_POINTERS(NodeVector, UnionFindNode*)

// ---- BasicBlock

struct BasicBlock {
  BasicBlockVector in_edges;
  BasicBlockVector out_edges;
  uint32_t name;
};

static BasicBlock* BasicBlock_new(int32_t name) {
  BasicBlock* b = (BasicBlock*)malloc(sizeof(BasicBlock));
  BasicBlockVector_init(&b->in_edges, 2);
  BasicBlockVector_init(&b->out_edges, 2);
  b->name = (uint32_t)name;
  return b;
}

static void BasicBlock_delete(BasicBlock* self) {
  BasicBlockVector_deinit(&self->out_edges);
  BasicBlockVector_deinit(&self->in_edges);
  free(self);
}

static inline int32_t BasicBlock_get_num_pred(const BasicBlock* self) {
  return (int32_t)BasicBlockVector_size(&self->in_edges);
}

static inline uint32_t BasicBlock_custom_hash(const BasicBlock* self) {
  return self->name;
}

static inline bool BasicBlock_equal(BasicBlock* self, BasicBlock* other) {
  return self->name == other->name;
}

static inline bool SimpleLoop_equal(SimpleLoop* self, SimpleLoop* other) {
  return self == other;
}

static inline bool int_equal(int32_t a, int32_t b) {
  return a == b;
}

DEFINE_SET(IntSet, IntVector, int32_t, int_equal)
DEFINE_SET(BasicBlockSet, BasicBlockVector, BasicBlock*, BasicBlock_equal)
DEFINE_SET(LoopSet, LoopVector, SimpleLoop*, SimpleLoop_equal)

DEFINE_VECTOR_OF_POINTERS(IntSetVector, IntSet*)
DEFINE_VECTOR_OF_POINTERS(IntVectorVector, IntVector*)

DEFINE_VECTOR(BasicBlockKeyVector, const BasicBlock*)
DEFINE_IDENTITY_DICTIONARY(NumberDictionary, BasicBlock, int32_t,
                           BasicBlockKeyVector, BasicBlock_custom_hash)

// ---- ControlFlowGraph and BasicBlockEdge

typedef struct ControlFlowGraph {
  BasicBlockVector basic_block_map;
  BasicBlock* start_node;
  EdgeVector edge_list;
} ControlFlowGraph;

struct BasicBlockEdge {
  BasicBlock* from;
  BasicBlock* to;
};

static void BasicBlockEdge_delete(BasicBlockEdge* self) {
  free(self);
}

static void ControlFlowGraph_init(ControlFlowGraph* self) {
  BasicBlockVector_init(&self->basic_block_map, 0);
  self->start_node = NULL;
  EdgeVector_init(&self->edge_list, 0);
}

static void ControlFlowGraph_deinit(ControlFlowGraph* self) {
  BasicBlockVector_destroy_values(&self->basic_block_map, BasicBlock_delete);
  EdgeVector_destroy_values(&self->edge_list, BasicBlockEdge_delete);
  EdgeVector_deinit(&self->edge_list);
  BasicBlockVector_deinit(&self->basic_block_map);
}

static inline int32_t ControlFlowGraph_get_num_nodes(
    const ControlFlowGraph* self) {
  return (int32_t)BasicBlockVector_size(&self->basic_block_map);
}

static BasicBlock* ControlFlowGraph_create_node(ControlFlowGraph* self,
                                                int32_t name) {
  BasicBlock* node = NULL;
  if (BasicBlockVector_at(&self->basic_block_map, (size_t)name) != NULL) {
    node = *BasicBlockVector_at(&self->basic_block_map, (size_t)name);
  } else {
    node = BasicBlock_new(name);
    BasicBlockVector_at_put(&self->basic_block_map, (size_t)name, node);
  }

  if (ControlFlowGraph_get_num_nodes(self) == 1) {
    self->start_node = node;
  }
  return node;
}

static BasicBlockEdge* BasicBlockEdge_new(ControlFlowGraph* cfg,
                                          int32_t from_name, int32_t to_name) {
  BasicBlockEdge* e = (BasicBlockEdge*)malloc(sizeof(BasicBlockEdge));
  e->from = ControlFlowGraph_create_node(cfg, from_name);
  e->to = ControlFlowGraph_create_node(cfg, to_name);
  BasicBlockVector_append(&e->from->out_edges, e->to);
  BasicBlockVector_append(&e->to->in_edges, e->from);

  EdgeVector_append(&cfg->edge_list, e);
  return e;
}

// ---- SimpleLoop

struct SimpleLoop {
  BasicBlockSet basic_blocks;
  LoopSet children;
  SimpleLoop* parent;
  BasicBlock* header;
  bool is_reducible;
  bool is_root;
  int32_t nesting_level;
  int32_t counter;
  int32_t depth_level;
};

static SimpleLoop* SimpleLoop_new(BasicBlock* bb, bool is_reducible) {
  SimpleLoop* l = (SimpleLoop*)malloc(sizeof(SimpleLoop));
  BasicBlockSet_init(&l->basic_blocks);
  LoopSet_init(&l->children);
  l->parent = NULL;
  l->header = bb;
  l->is_reducible = is_reducible;
  l->is_root = false;
  l->nesting_level = 0;
  l->counter = 0;
  l->depth_level = 0;
  if (bb != NULL) {
    BasicBlockSet_add(&l->basic_blocks, bb);
  }
  return l;
}

static void SimpleLoop_delete(SimpleLoop* self) {
  LoopSet_deinit(&self->children);
  BasicBlockSet_deinit(&self->basic_blocks);
  free(self);
}

static void SimpleLoop_set_parent(SimpleLoop* self, SimpleLoop* parent) {
  self->parent = parent;
  LoopSet_add(&self->parent->children, self);
}

static void SimpleLoop_set_nesting_level(SimpleLoop* self, int32_t level) {
  self->nesting_level = level;
  if (level == 0) {
    self->is_root = true;
  }
}

// ---- LoopStructureGraph

typedef struct LoopStructureGraph {
  SimpleLoop* root;
  LoopVector loops;
  int32_t loop_counter;
} LoopStructureGraph;

static void LoopStructureGraph_init(LoopStructureGraph* self) {
  self->root = SimpleLoop_new(NULL, true);
  LoopVector_init(&self->loops, 0);
  self->loop_counter = 0;
  SimpleLoop_set_nesting_level(self->root, 0);
  self->root->counter = self->loop_counter;
  self->loop_counter += 1;
  LoopVector_append(&self->loops, self->root);
}

static void LoopStructureGraph_deinit(LoopStructureGraph* self) {
  LoopVector_destroy_values(&self->loops, SimpleLoop_delete);
  LoopVector_deinit(&self->loops);
}

static SimpleLoop* LoopStructureGraph_create_new_loop(LoopStructureGraph* self,
                                                      BasicBlock* bb,
                                                      bool is_reducible) {
  SimpleLoop* loop = SimpleLoop_new(bb, is_reducible);
  loop->counter = self->loop_counter;
  self->loop_counter += 1;
  LoopVector_append(&self->loops, loop);
  return loop;
}

static void link_to_root_fn(void* ctx, SimpleLoop* const* liter) {
  LoopStructureGraph* self = (LoopStructureGraph*)ctx;
  if (!(*liter)->is_root) {
    if ((*liter)->parent == NULL) {
      SimpleLoop_set_parent(*liter, self->root);
    }
  }
}

static void LoopStructureGraph_calculate_nesting_level_rec(
    LoopStructureGraph* self, SimpleLoop* loop, int32_t depth);

typedef struct NestingCtx {
  LoopStructureGraph* self;
  SimpleLoop* loop;
  int32_t depth;
} NestingCtx;

static void nesting_level_fn(void* ctx, SimpleLoop* const* liter) {
  NestingCtx* k = (NestingCtx*)ctx;
  LoopStructureGraph_calculate_nesting_level_rec(k->self, *liter, k->depth + 1);

  const int32_t level = 1 + (*liter)->nesting_level;
  SimpleLoop_set_nesting_level(
      k->loop, k->loop->nesting_level > level ? k->loop->nesting_level : level);
}

static void LoopStructureGraph_calculate_nesting_level_rec(
    LoopStructureGraph* self, SimpleLoop* loop, int32_t depth) {
  loop->depth_level = depth;
  NestingCtx k = {self, loop, depth};
  LoopSet_for_each(&loop->children, nesting_level_fn, &k);
}

static void LoopStructureGraph_calculate_nesting_level(
    LoopStructureGraph* self) {
  // link up all 1st level loops to artificial root node.
  LoopVector_for_each(&self->loops, link_to_root_fn, self);

  // recursively traverse the tree and assign levels.
  LoopStructureGraph_calculate_nesting_level_rec(self, self->root, 0);
}

static inline int32_t LoopStructureGraph_get_num_loops(
    const LoopStructureGraph* self) {
  return (int32_t)LoopVector_size(&self->loops);
}

// ---- UnionFindNode

struct UnionFindNode {
  UnionFindNode* parent;
  BasicBlock* bb;
  SimpleLoop* loop;
  int32_t dfs_number;
};

static UnionFindNode* UnionFindNode_new(void) {
  return (UnionFindNode*)malloc(sizeof(UnionFindNode));
}

static void UnionFindNode_delete(UnionFindNode* self) {
  free(self);
}

static void UnionFindNode_init_node(UnionFindNode* self, BasicBlock* bb,
                                    int32_t dfs_number) {
  self->parent = self;
  self->bb = bb;
  self->dfs_number = dfs_number;
  self->loop = NULL;
}

static void union_set_parent_fn(void* ctx, UnionFindNode* const* iter) {
  (*iter)->parent = (UnionFindNode*)ctx;
}

static UnionFindNode* UnionFindNode_find_set(UnionFindNode* self) {
  NodeVector node_list;
  NodeVector_init(&node_list, 0);

  UnionFindNode* node = self;
  while (node != node->parent) {
    if (node->parent != node->parent->parent) {
      NodeVector_append(&node_list, node);
    }
    node = node->parent;
  }

  // Path Compression, all nodes' parents point to the 1st level parent.
  NodeVector_for_each(&node_list, union_set_parent_fn, self->parent);
  NodeVector_deinit(&node_list);
  return node;
}

// ---- HavlakLoopFinder

typedef enum BasicBlockClass {
  BB_TOP,          // uninitialized
  BB_NONHEADER,    // a regular BB
  BB_REDUCIBLE,    // reducible loop
  BB_SELF,         // single BB loop
  BB_IRREDUCIBLE,  // irreducible loop
  BB_DEAD,         // a dead BB
  BB_LAST          // Sentinel
} BasicBlockClass;

#define UNVISITED INT32_MAX
#define MAXNONBACKPREDS (32 * 1024)

typedef struct HavlakLoopFinder {
  ControlFlowGraph* cfg;
  LoopStructureGraph* lsg;
  IntSetVector non_back_preds;
  IntVectorVector back_preds;
  NumberDictionary number;
  int32_t max_size;
  int32_t* header;
  BasicBlockClass* type;
  int32_t* last;
  UnionFindNode** nodes;
} HavlakLoopFinder;

static void HavlakLoopFinder_init(HavlakLoopFinder* self,
                                  ControlFlowGraph* cfg,
                                  LoopStructureGraph* lsg) {
  self->cfg = cfg;
  self->lsg = lsg;
  IntSetVector_init(&self->non_back_preds, 0);
  IntVectorVector_init(&self->back_preds, 0);
  NumberDictionary_init(&self->number, DICTIONARY_INITIAL_CAPACITY);
  self->max_size = 0;
  self->header = NULL;
  self->type = NULL;
  self->last = NULL;
  self->nodes = NULL;
}

static void HavlakLoopFinder_deinit(HavlakLoopFinder* self) {
  IntSetVector_destroy_values(&self->non_back_preds, IntSet_delete);
  IntVectorVector_destroy_values(&self->back_preds, IntVector_delete);
  free(self->header);
  free(self->type);
  free(self->last);

  for (int32_t i = 0; i < self->max_size; i += 1) {
    UnionFindNode_delete(self->nodes[i]);
  }
  free(self->nodes);

  NumberDictionary_deinit(&self->number);
  IntVectorVector_deinit(&self->back_preds);
  IntSetVector_deinit(&self->non_back_preds);
}

static inline bool is_ancestor(const HavlakLoopFinder* self, int32_t w,
                               int32_t v) {
  return w <= v && v <= self->last[w];
}

static int32_t do_dfs(HavlakLoopFinder* self, BasicBlock* current_node,
                      int32_t current) {
  UnionFindNode_init_node(self->nodes[current], current_node, current);
  NumberDictionary_at_put(&self->number, current_node, current);

  int32_t last_id = current;
  const BasicBlockVector* outer_blocks = &current_node->out_edges;

  for (int32_t i = 0; i < (int32_t)BasicBlockVector_size(outer_blocks);
       i += 1) {
    BasicBlock* target = *BasicBlockVector_at(outer_blocks, (size_t)i);
    if (*NumberDictionary_at(&self->number, target) == UNVISITED) {
      last_id = do_dfs(self, target, last_id + 1);
    }
  }

  self->last[current] = last_id;
  return last_id;
}

static void mark_unvisited_fn(void* ctx, BasicBlock* const* bb) {
  HavlakLoopFinder* self = (HavlakLoopFinder*)ctx;
  NumberDictionary_at_put(&self->number, *bb, UNVISITED);
}

static void init_all_nodes(HavlakLoopFinder* self) {
  BasicBlockVector_for_each(&self->cfg->basic_block_map, mark_unvisited_fn,
                            self);
  do_dfs(self, self->cfg->start_node, 0);
}

typedef struct FinderW {
  HavlakLoopFinder* self;
  int32_t w;
} FinderW;

static void process_edge_fn(void* ctx, BasicBlock* const* node_v) {
  FinderW* k = (FinderW*)ctx;
  HavlakLoopFinder* self = k->self;
  const int32_t w = k->w;
  const int32_t v = *NumberDictionary_at(&self->number, *node_v);
  if (v != UNVISITED) {
    if (is_ancestor(self, w, v)) {
      IntVector_append(*IntVectorVector_at(&self->back_preds, (size_t)w), v);
    } else {
      IntSet_add(*IntSetVector_at(&self->non_back_preds, (size_t)w), v);
    }
  }
}

static void process_edges(HavlakLoopFinder* self, BasicBlock* node_w,
                          int32_t w) {
  if (BasicBlock_get_num_pred(node_w) > 0) {
    FinderW k = {self, w};
    BasicBlockVector_for_each(&node_w->in_edges, process_edge_fn, &k);
  }
}

static void identify_edges(HavlakLoopFinder* self, int32_t size) {
  for (int32_t w = 0; w < size; w += 1) {
    self->header[w] = 0;
    self->type[w] = BB_NONHEADER;

    BasicBlock* node_w = self->nodes[w]->bb;
    if (node_w == NULL) {
      self->type[w] = BB_DEAD;
    } else {
      process_edges(self, node_w, w);
    }
  }
}

typedef struct StepECtx {
  HavlakLoopFinder* self;
  int32_t w;
  NodeVector* node_pool;
  NodeVector* work_list;
} StepECtx;

static bool is_node_fn(void* ctx, UnionFindNode* const* e) {
  return *e == (UnionFindNode*)ctx;
}

static void step_e_fn(void* ctx, const int32_t* iter) {
  StepECtx* k = (StepECtx*)ctx;
  HavlakLoopFinder* self = k->self;
  const int32_t w = k->w;
  UnionFindNode* y = self->nodes[*iter];
  UnionFindNode* ydash = UnionFindNode_find_set(y);

  if (!is_ancestor(self, w, ydash->dfs_number)) {
    self->type[w] = BB_IRREDUCIBLE;
    IntSet_add(*IntSetVector_at(&self->non_back_preds, (size_t)w),
               ydash->dfs_number);
  } else {
    if (ydash->dfs_number != w) {
      if (!NodeVector_has_some(k->node_pool, is_node_fn, ydash)) {
        NodeVector_append(k->work_list, ydash);
        NodeVector_append(k->node_pool, ydash);
      }
    }
  }
}

static void step_e_process_non_back_preds(HavlakLoopFinder* self, int32_t w,
                                          NodeVector* node_pool,
                                          NodeVector* work_list,
                                          UnionFindNode* x) {
  StepECtx k = {self, w, node_pool, work_list};
  IntSet_for_each(
      *IntSetVector_at(&self->non_back_preds, (size_t)x->dfs_number),
      step_e_fn, &k);
}

typedef struct LoopAttrCtx {
  HavlakLoopFinder* self;
  int32_t w;
  SimpleLoop* loop;
} LoopAttrCtx;

static void loop_attr_fn(void* ctx, UnionFindNode* const* np) {
  LoopAttrCtx* k = (LoopAttrCtx*)ctx;
  UnionFindNode* node = *np;
  k->self->header[node->dfs_number] = k->w;
  node->parent = k->self->nodes[k->w];

  // Nested loops are not added, but linked together.
  if (node->loop != NULL) {
    SimpleLoop_set_parent(node->loop, k->loop);
  } else {
    BasicBlockSet_add(&k->loop->basic_blocks, node->bb);
  }
}

static void set_loop_attributes(HavlakLoopFinder* self, int32_t w,
                                NodeVector* node_pool, SimpleLoop* loop) {
  self->nodes[w]->loop = loop;
  LoopAttrCtx k = {self, w, loop};
  NodeVector_for_each(node_pool, loop_attr_fn, &k);
}

typedef struct StepDCtx {
  HavlakLoopFinder* self;
  int32_t w;
  NodeVector* node_pool;
} StepDCtx;

static void step_d_fn(void* ctx, const int32_t* v) {
  StepDCtx* k = (StepDCtx*)ctx;
  if (*v != k->w) {
    NodeVector_append(k->node_pool,
                      UnionFindNode_find_set(k->self->nodes[*v]));
  } else {
    k->self->type[k->w] = BB_SELF;
  }
}

static void step_d(HavlakLoopFinder* self, int32_t w, NodeVector* node_pool) {
  StepDCtx k = {self, w, node_pool};
  IntVector_for_each(*IntVectorVector_at(&self->back_preds, (size_t)w),
                     step_d_fn, &k);
}

static void copy_to_work_list_fn(void* ctx, UnionFindNode* const* niter) {
  NodeVector_append((NodeVector*)ctx, *niter);
}

static void HavlakLoopFinder_find_loops(HavlakLoopFinder* self) {
  if (self->cfg->start_node == NULL) {
    return;
  }

  const int32_t size = ControlFlowGraph_get_num_nodes(self->cfg);

  IntSetVector_remove_all(&self->non_back_preds, IntSet_delete);
  IntVectorVector_remove_all(&self->back_preds, IntVector_delete);
  NumberDictionary_remove_all(&self->number);
  if (size > self->max_size) {
    self->header = (int32_t*)malloc((size_t)size * sizeof(int32_t));
    self->type = (BasicBlockClass*)malloc((size_t)size * sizeof(BasicBlockClass));
    self->last = (int32_t*)malloc((size_t)size * sizeof(int32_t));
    self->nodes = (UnionFindNode**)malloc((size_t)size * sizeof(UnionFindNode*));
    self->max_size = size;
  }

  for (int32_t i = 0; i < size; i += 1) {
    IntSetVector_append(&self->non_back_preds, IntSet_new());
    IntVectorVector_append(&self->back_preds, IntVector_new(0));
    self->nodes[i] = UnionFindNode_new();
  }

  init_all_nodes(self);
  identify_edges(self, size);

  // Start node is root of all other loops.
  self->header[0] = 0;
  for (int32_t w = size - 1; w >= 0; w -= 1) {
    // this is 'P' in Havlak's paper
    NodeVector node_pool;
    NodeVector_init(&node_pool, 0);

    BasicBlock* node_w = self->nodes[w]->bb;
    if (node_w != NULL) {
      step_d(self, w, &node_pool);

      // Copy nodePool to workList.
      NodeVector work_list;
      NodeVector_init(&work_list, 0);
      NodeVector_for_each(&node_pool, copy_to_work_list_fn, &work_list);

      if (NodeVector_size(&node_pool) != 0) {
        self->type[w] = BB_REDUCIBLE;
      }

      // work the list...
      while (!NodeVector_is_empty(&work_list)) {
        UnionFindNode* x = NodeVector_remove_first(&work_list);

        const int32_t non_back_size = (int32_t)IntSet_size(
            *IntSetVector_at(&self->non_back_preds, (size_t)x->dfs_number));
        if (non_back_size > MAXNONBACKPREDS) {
          NodeVector_deinit(&work_list);
          NodeVector_deinit(&node_pool);
          return;
        }
        step_e_process_non_back_preds(self, w, &node_pool, &work_list, x);
      }

      if ((NodeVector_size(&node_pool) > 0) || (self->type[w] == BB_SELF)) {
        SimpleLoop* loop = LoopStructureGraph_create_new_loop(
            self->lsg, node_w, self->type[w] != BB_IRREDUCIBLE);
        set_loop_attributes(self, w, &node_pool, loop);
      }
      NodeVector_deinit(&work_list);
    }
    NodeVector_deinit(&node_pool);
  }  // Step c
}

// ---- LoopTesterApp

typedef struct LoopTesterApp {
  ControlFlowGraph cfg;
  LoopStructureGraph lsg;
} LoopTesterApp;

static int32_t build_diamond(LoopTesterApp* self, int32_t start) {
  const int32_t bb0 = start;
  BasicBlockEdge_new(&self->cfg, bb0, bb0 + 1);
  BasicBlockEdge_new(&self->cfg, bb0, bb0 + 2);
  BasicBlockEdge_new(&self->cfg, bb0 + 1, bb0 + 3);
  BasicBlockEdge_new(&self->cfg, bb0 + 2, bb0 + 3);

  return bb0 + 3;
}

static void build_connect(LoopTesterApp* self, int32_t start, int32_t end) {
  BasicBlockEdge_new(&self->cfg, start, end);
}

static int32_t build_straight(LoopTesterApp* self, int32_t start, int32_t n) {
  for (int32_t i = 0; i < n; i += 1) {
    build_connect(self, start + i, start + i + 1);
  }
  return start + n;
}

static int32_t build_base_loop(LoopTesterApp* self, int32_t from) {
  const int32_t header = build_straight(self, from, 1);
  const int32_t diamond1 = build_diamond(self, header);
  const int32_t d11 = build_straight(self, diamond1, 1);
  const int32_t diamond2 = build_diamond(self, d11);
  int32_t footer = build_straight(self, diamond2, 1);
  build_connect(self, diamond2, d11);
  build_connect(self, diamond1, header);
  build_connect(self, footer, from);
  footer = build_straight(self, footer, 1);
  return footer;
}

static void construct_simple_cfg(LoopTesterApp* self) {
  ControlFlowGraph_create_node(&self->cfg, 0);
  build_base_loop(self, 0);
  ControlFlowGraph_create_node(&self->cfg, 1);

  BasicBlockEdge_new(&self->cfg, 0, 2);
}

static void app_find_loops(LoopTesterApp* self,
                           LoopStructureGraph* loop_structure) {
  HavlakLoopFinder finder;
  HavlakLoopFinder_init(&finder, &self->cfg, loop_structure);
  HavlakLoopFinder_find_loops(&finder);
  HavlakLoopFinder_deinit(&finder);
}

static void add_dummy_loops(LoopTesterApp* self, int32_t num_dummy_loops) {
  for (int32_t dummyloop = 0; dummyloop < num_dummy_loops; dummyloop += 1) {
    app_find_loops(self, &self->lsg);
  }
}

static void construct_cfg(LoopTesterApp* self, int32_t par_loops,
                          int32_t ppar_loops, int32_t pppar_loops) {
  int32_t n = 2;

  for (int32_t parlooptrees = 0; parlooptrees < par_loops; parlooptrees += 1) {
    ControlFlowGraph_create_node(&self->cfg, n + 1);
    build_connect(self, 2, n + 1);
    n += 1;

    for (int32_t i = 0; i < ppar_loops; i += 1) {
      const int32_t top = n;
      n = build_straight(self, n, 1);
      for (int32_t j = 0; j < pppar_loops; j += 1) {
        n = build_base_loop(self, n);
      }
      const int32_t bottom = build_straight(self, n, 1);
      build_connect(self, n, top);
      n = bottom;
    }
    build_connect(self, n, 1);
  }
}

static void LoopTesterApp_init(LoopTesterApp* self) {
  ControlFlowGraph_init(&self->cfg);
  LoopStructureGraph_init(&self->lsg);
  ControlFlowGraph_create_node(&self->cfg, 0);
}

static void LoopTesterApp_deinit(LoopTesterApp* self) {
  LoopStructureGraph_deinit(&self->lsg);
  ControlFlowGraph_deinit(&self->cfg);
}

typedef struct Pair {
  int32_t loops;
  int32_t nodes;
} Pair;

static Pair LoopTesterApp_main(LoopTesterApp* self, int32_t num_dummy_loops,
                               int32_t find_loop_iterations, int32_t par_loops,
                               int32_t ppar_loops, int32_t pppar_loops) {
  construct_simple_cfg(self);
  add_dummy_loops(self, num_dummy_loops);
  construct_cfg(self, par_loops, ppar_loops, pppar_loops);
  app_find_loops(self, &self->lsg);
  for (int32_t i = 0; i < find_loop_iterations; i += 1) {
    LoopStructureGraph l;
    LoopStructureGraph_init(&l);
    app_find_loops(self, &l);
    LoopStructureGraph_deinit(&l);
  }

  LoopStructureGraph_calculate_nesting_level(&self->lsg);
  return (Pair){LoopStructureGraph_get_num_loops(&self->lsg),
                ControlFlowGraph_get_num_nodes(&self->cfg)};
}

// ---- Havlak

static bool verify(Pair r, int32_t inner_iterations) {
  if (inner_iterations == 15000) {
    return r.loops == 46602 && r.nodes == 5213;
  }
  if (inner_iterations == 1500) {
    return r.loops == 6102 && r.nodes == 5213;
  }
  if (inner_iterations == 150) {
    return r.loops == 2052 && r.nodes == 5213;
  }
  if (inner_iterations == 15) {
    return r.loops == 1647 && r.nodes == 5213;
  }
  if (inner_iterations == 1) {
    return r.loops == 1605 && r.nodes == 5213;
  }

  printf("No verification result for %d found\n", inner_iterations);
  printf("Result is: %d, %d\n", r.loops, r.nodes);
  return false;
}

static bool Havlak_inner_benchmark_loop(Benchmark* self,
                                        int32_t inner_iterations) {
  (void)self;
  LoopTesterApp app;
  LoopTesterApp_init(&app);
  const Pair r = LoopTesterApp_main(&app, inner_iterations, 50, 10, 10, 5);
  LoopTesterApp_deinit(&app);
  return verify(r, inner_iterations);
}

static Result Havlak_benchmark(Benchmark* self) {
  (void)self;
  error("Should never be reached");
}

static bool Havlak_verify_result(Benchmark* self, Result result) {
  (void)self;
  (void)result;
  error("Should never be reached");
}

static const BenchmarkVtbl Havlak_vtbl = {Benchmark_destroy, Havlak_benchmark,
                                          Havlak_verify_result,
                                          Havlak_inner_benchmark_loop};

Benchmark* Havlak_new(void) {
  return Benchmark_alloc(sizeof(Benchmark), &Havlak_vtbl);
}
