#include <math.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "benchmark.h"
#include "som/error.h"
#include "som/vector.h"

// cd.h of the C++ port. Vector2D, Vector3D, CallSign, Collision, Motion and
// Aircraft are value classes, stored by value in the vectors and trees as in
// C++. No class here has a virtual member.

// ---- Vector2D

typedef struct Vector2D {
  double x;
  double y;
} Vector2D;

static int32_t Vector2D_compare_numbers(double a, double b) {
  if (a == b) {
    return 0;
  }
  if (a < b) {
    return -1;
  }
  if (a > b) {
    return 1;
  }

  // We say that NaN is smaller than non-NaN.
  if (a == a) {
    return 1;
  }
  return -1;
}

static Vector2D Vector2D_plus(Vector2D self, Vector2D other) {
  return (Vector2D){self.x + other.x, self.y + other.y};
}

static Vector2D Vector2D_minus(Vector2D self, Vector2D other) {
  return (Vector2D){self.x - other.x, self.y - other.y};
}

static int32_t Vector2D_compare_to(Vector2D self, Vector2D other) {
  const int32_t result = Vector2D_compare_numbers(self.x, other.x);

  if (result != 0) {
    return result;
  }

  return Vector2D_compare_numbers(self.y, other.y);
}

// ---- Vector3D

typedef struct Vector3D {
  double x;
  double y;
  double z;
} Vector3D;

static Vector3D Vector3D_plus(Vector3D self, Vector3D other) {
  return (Vector3D){self.x + other.x, self.y + other.y, self.z + other.z};
}

static Vector3D Vector3D_minus(Vector3D self, Vector3D other) {
  return (Vector3D){self.x - other.x, self.y - other.y, self.z - other.z};
}

static double Vector3D_dot(Vector3D self, Vector3D other) {
  return self.x * other.x + self.y * other.y + self.z * other.z;
}

static double Vector3D_squared_magnitude(Vector3D self) {
  return Vector3D_dot(self, self);
}

static double Vector3D_magnitude(Vector3D self) {
  return sqrt(Vector3D_squared_magnitude(self));
}

static Vector3D Vector3D_times(Vector3D self, double amount) {
  return (Vector3D){self.x * amount, self.y * amount, self.z * amount};
}

// ---- RedBlackTree<K, V>
//
// The C++ template, as a typed module: DEFINE_RED_BLACK_TREE generates the
// tree, its node, its entry and std::optional<V> for one key type, value type
// and key comparison (C++'s K::compareTo).

typedef enum Color { RED = 0, BLACK = 1 } Color;

#define DEFINE_RED_BLACK_TREE(Name, K, V, compare_to)                          \
  typedef struct Name##Node Name##Node;                                        \
  struct Name##Node {                                                          \
    K key;                                                                     \
    V value;                                                                   \
    Name##Node* left;                                                          \
    Name##Node* right;                                                         \
    Name##Node* parent;                                                        \
    Color color;                                                               \
  };                                                                           \
                                                                               \
  /* std::optional<V> */                                                       \
  typedef struct Name##Optional {                                              \
    bool has_value;                                                            \
    V value;                                                                   \
  } Name##Optional;                                                            \
                                                                               \
  typedef struct Name##InsertResult {                                          \
    bool is_new_entry;                                                         \
    Name##Node* new_node;                                                      \
    V old_value;                                                               \
  } Name##InsertResult;                                                        \
                                                                               \
  typedef struct Name##Entry {                                                 \
    K key;                                                                     \
    V value;                                                                   \
  } Name##Entry;                                                               \
                                                                               \
  typedef struct Name {                                                        \
    Name##Node* root;                                                          \
  } Name;                                                                      \
                                                                               \
  SOM_INLINE Name##Node* Name##_tree_minimum(Name##Node* x) {                      \
    Name##Node* current = x;                                                   \
    while (current->left != NULL) {                                            \
      current = current->left;                                                 \
    }                                                                          \
    return current;                                                            \
  }                                                                            \
                                                                               \
  SOM_INLINE Name##Node* Name##Node_successor(Name##Node* self) {                  \
    Name##Node* x = self;                                                      \
    if (x->right != NULL) {                                                    \
      return Name##_tree_minimum(x->right);                                    \
    }                                                                          \
    Name##Node* y = x->parent;                                                 \
    while (y != NULL && x == y->right) {                                       \
      x = y;                                                                   \
      y = y->parent;                                                           \
    }                                                                          \
    return y;                                                                  \
  }                                                                            \
                                                                               \
  SOM_INLINE Name##Node* Name##Node_new(K key, V value) {                          \
    Name##Node* n = (Name##Node*)malloc(sizeof(Name##Node));                   \
    n->key = key;                                                              \
    n->value = value;                                                          \
    n->left = NULL;                                                            \
    n->right = NULL;                                                           \
    n->parent = NULL;                                                          \
    n->color = RED;                                                            \
    return n;                                                                  \
  }                                                                            \
                                                                               \
  /* `delete node`: the destructor deletes both subtrees. */                   \
  SOM_INLINE void Name##Node_delete(Name##Node* self) {                            \
    if (self == NULL) {                                                        \
      return;                                                                  \
    }                                                                          \
    Name##Node_delete(self->left);                                             \
    Name##Node_delete(self->right);                                            \
    free(self);                                                                \
  }                                                                            \
                                                                               \
  SOM_INLINE void Name##_init(Name* self) { self->root = NULL; }                   \
                                                                               \
  SOM_INLINE void Name##_deinit(Name* self) { Name##Node_delete(self->root); }     \
                                                                               \
  SOM_INLINE Name##InsertResult Name##_tree_insert(Name* self, K key, V value) {   \
    Name##Node* y = NULL;                                                      \
    Name##Node* x = self->root;                                                \
                                                                               \
    while (x != NULL) {                                                        \
      y = x;                                                                   \
      const int32_t comparison_result = compare_to(key, x->key);               \
      if (comparison_result < 0) {                                             \
        x = x->left;                                                           \
      } else if (comparison_result > 0) {                                      \
        x = x->right;                                                          \
      } else {                                                                 \
        V old_value = x->value;                                                \
        x->value = value;                                                      \
        return (Name##InsertResult){false, NULL, old_value};                   \
      }                                                                        \
    }                                                                          \
                                                                               \
    Name##Node* z = Name##Node_new(key, value);                                \
    z->parent = y;                                                             \
    if (y == NULL) {                                                           \
      self->root = z;                                                          \
    } else {                                                                   \
      if (compare_to(key, y->key) < 0) {                                       \
        y->left = z;                                                           \
      } else {                                                                 \
        y->right = z;                                                          \
      }                                                                        \
    }                                                                          \
    return (Name##InsertResult){true, z, (V){0}};                              \
  }                                                                            \
                                                                               \
  SOM_INLINE Name##Node* Name##_left_rotate(Name* self, Name##Node* x) {           \
    Name##Node* y = x->right;                                                  \
                                                                               \
    /* Turn y's left subtree into x's right subtree. */                        \
    x->right = y->left;                                                        \
    if (y->left != NULL) {                                                     \
      y->left->parent = x;                                                     \
    }                                                                          \
                                                                               \
    /* Link x's parent to y */                                                 \
    y->parent = x->parent;                                                     \
    if (x->parent == NULL) {                                                   \
      self->root = y;                                                          \
    } else {                                                                   \
      if (x == x->parent->left) {                                              \
        x->parent->left = y;                                                   \
      } else {                                                                 \
        x->parent->right = y;                                                  \
      }                                                                        \
    }                                                                          \
                                                                               \
    /* Put x on y's left. */                                                   \
    y->left = x;                                                               \
    x->parent = y;                                                             \
                                                                               \
    return y;                                                                  \
  }                                                                            \
                                                                               \
  SOM_INLINE Name##Node* Name##_right_rotate(Name* self, Name##Node* y) {          \
    Name##Node* x = y->left;                                                   \
                                                                               \
    /* Turn x's right subtree into y's left subtree. */                        \
    y->left = x->right;                                                        \
    if (x->right != NULL) {                                                    \
      x->right->parent = y;                                                    \
    }                                                                          \
                                                                               \
    /* Link y's parent to x; */                                                \
    x->parent = y->parent;                                                     \
    if (y->parent == NULL) {                                                   \
      self->root = x;                                                          \
    } else {                                                                   \
      if (y == y->parent->left) {                                              \
        y->parent->left = x;                                                   \
      } else {                                                                 \
        y->parent->right = x;                                                  \
      }                                                                        \
    }                                                                          \
                                                                               \
    x->right = y;                                                              \
    y->parent = x;                                                             \
                                                                               \
    return x;                                                                  \
  }                                                                            \
                                                                               \
  SOM_INLINE void Name##_remove_fixup(Name* self, Name##Node* x,                   \
                                  Name##Node* x_parent) {                      \
    while (x != self->root && (x == NULL || x->color == BLACK)) {              \
      if (x == x_parent->left) {                                               \
        /* Note: the text points out that w cannot be null. The reason is not  \
           obvious from simply looking at the code; it comes about from the    \
           properties of the red-black tree. */                                \
        Name##Node* w = x_parent->right;                                       \
        if (w->color == RED) {                                                 \
          /* Case 1 */                                                         \
          w->color = BLACK;                                                    \
          x_parent->color = RED;                                               \
          Name##_left_rotate(self, x_parent);                                  \
          w = x_parent->right;                                                 \
        }                                                                      \
        if ((w->left == NULL || w->left->color == BLACK) &&                    \
            (w->right == NULL || w->right->color == BLACK)) {                  \
          /* Case 2 */                                                         \
          w->color = RED;                                                      \
          x = x_parent;                                                        \
          x_parent = x->parent;                                                \
        } else {                                                               \
          if (w->right == NULL || w->right->color == BLACK) {                  \
            /* Case 3 */                                                       \
            w->left->color = BLACK;                                            \
            w->color = RED;                                                    \
            Name##_right_rotate(self, w);                                      \
            w = x_parent->right;                                               \
          }                                                                    \
          /* Case 4 */                                                         \
          w->color = x_parent->color;                                          \
          x_parent->color = BLACK;                                             \
          if (w->right != NULL) {                                              \
            w->right->color = BLACK;                                           \
          }                                                                    \
          Name##_left_rotate(self, x_parent);                                  \
          x = self->root;                                                      \
          x_parent = x->parent;                                                \
        }                                                                      \
      } else {                                                                 \
        /* Same as "then" clause with "right" and "left" exchanged. */         \
        Name##Node* w = x_parent->left;                                        \
        if (w->color == RED) {                                                 \
          /* Case 1 */                                                         \
          w->color = BLACK;                                                    \
          x_parent->color = RED;                                               \
          Name##_right_rotate(self, x_parent);                                 \
          w = x_parent->left;                                                  \
        }                                                                      \
        if ((w->right == NULL || w->right->color == BLACK) &&                  \
            (w->left == NULL || w->left->color == BLACK)) {                    \
          /* Case 2 */                                                         \
          w->color = RED;                                                      \
          x = x_parent;                                                        \
          x_parent = x->parent;                                                \
        } else {                                                               \
          if (w->left == NULL || w->left->color == BLACK) {                    \
            /* Case 3 */                                                       \
            w->right->color = BLACK;                                           \
            w->color = RED;                                                    \
            Name##_left_rotate(self, w);                                       \
            w = x_parent->left;                                                \
          }                                                                    \
          /* Case 4 */                                                         \
          w->color = x_parent->color;                                          \
          x_parent->color = BLACK;                                             \
          if (w->left != NULL) {                                               \
            w->left->color = BLACK;                                            \
          }                                                                    \
          Name##_right_rotate(self, x_parent);                                 \
          x = self->root;                                                      \
          x_parent = x->parent;                                                \
        }                                                                      \
      }                                                                        \
    }                                                                          \
    if (x != NULL) {                                                           \
      x->color = BLACK;                                                        \
    }                                                                          \
  }                                                                            \
                                                                               \
  SOM_INLINE Name##Optional Name##_put(Name* self, K key, V value) {               \
    Name##InsertResult insertion_result = Name##_tree_insert(self, key, value); \
                                                                               \
    if (!insertion_result.is_new_entry) {                                      \
      return (Name##Optional){true, insertion_result.old_value};               \
    }                                                                          \
    Name##Node* x = insertion_result.new_node;                                 \
                                                                               \
    while (x != self->root && x->parent->color == RED) {                       \
      if (x->parent == x->parent->parent->left) {                              \
        Name##Node* y = x->parent->parent->right;                              \
        if (y != NULL && y->color == RED) {                                    \
          /* Case 1 */                                                         \
          x->parent->color = BLACK;                                            \
          y->color = BLACK;                                                    \
          x->parent->parent->color = RED;                                      \
          x = x->parent->parent;                                               \
        } else {                                                               \
          if (x == x->parent->right) {                                         \
            /* Case 2 */                                                       \
            x = x->parent;                                                     \
            Name##_left_rotate(self, x);                                       \
          }                                                                    \
          /* Case 3 */                                                         \
          x->parent->color = BLACK;                                            \
          x->parent->parent->color = RED;                                      \
          Name##_right_rotate(self, x->parent->parent);                        \
        }                                                                      \
      } else {                                                                 \
        /* Same as "then" clause with "right" and "left" exchanged. */         \
        Name##Node* y = x->parent->parent->left;                               \
        if (y != NULL && y->color == RED) {                                    \
          /* Case 1 */                                                         \
          x->parent->color = BLACK;                                            \
          y->color = BLACK;                                                    \
          x->parent->parent->color = RED;                                      \
          x = x->parent->parent;                                               \
        } else {                                                               \
          if (x == x->parent->left) {                                          \
            /* Case 2 */                                                       \
            x = x->parent;                                                     \
            Name##_right_rotate(self, x);                                      \
          }                                                                    \
          /* Case 3 */                                                         \
          x->parent->color = BLACK;                                            \
          x->parent->parent->color = RED;                                      \
          Name##_left_rotate(self, x->parent->parent);                         \
        }                                                                      \
      }                                                                        \
    }                                                                          \
    self->root->color = BLACK;                                                 \
    return (Name##Optional){false, (V){0}};                                    \
  }                                                                            \
                                                                               \
  SOM_INLINE Name##Node* Name##_find_node(Name* self, K key) {                     \
    Name##Node* current = self->root;                                          \
    while (current != NULL) {                                                  \
      const int32_t comparison_result = compare_to(key, current->key);         \
      if (comparison_result == 0) {                                            \
        return current;                                                        \
      }                                                                        \
      if (comparison_result < 0) {                                             \
        current = current->left;                                               \
      } else {                                                                 \
        current = current->right;                                              \
      }                                                                        \
    }                                                                          \
    return NULL;                                                               \
  }                                                                            \
                                                                               \
  /* As C++'s: the unlinked node is not deleted. */                            \
  SOM_INLINE Name##Optional Name##_remove(Name* self, K key) {              \
    Name##Node* z = Name##_find_node(self, key);                               \
    if (z == NULL) {                                                           \
      return (Name##Optional){false, (V){0}};                                  \
    }                                                                          \
                                                                               \
    /* Y is the node to be unlinked from the tree. */                          \
    Name##Node* y = NULL;                                                      \
    if (z->left == NULL || z->right == NULL) {                                 \
      y = z;                                                                   \
    } else {                                                                   \
      y = Name##Node_successor(z);                                             \
    }                                                                          \
                                                                               \
    /* Y is guaranteed to be non-null at this point. */                        \
    Name##Node* x = NULL;                                                      \
    if (y->left != NULL) {                                                     \
      x = y->left;                                                             \
    } else {                                                                   \
      x = y->right;                                                            \
    }                                                                          \
    /* X is the child of y which might potentially replace y in the tree. X    \
       might be null at this point. */                                         \
    Name##Node* x_parent = NULL;                                               \
    if (x != NULL) {                                                           \
      x->parent = y->parent;                                                   \
      x_parent = x->parent;                                                    \
    } else {                                                                   \
      x_parent = y->parent;                                                    \
    }                                                                          \
    if (y->parent == NULL) {                                                   \
      self->root = x;                                                          \
    } else {                                                                   \
      if (y == y->parent->left) {                                              \
        y->parent->left = x;                                                   \
      } else {                                                                 \
        y->parent->right = x;                                                  \
      }                                                                        \
    }                                                                          \
                                                                               \
    if (y != z) {                                                              \
      if (y->color == BLACK) {                                                 \
        Name##_remove_fixup(self, x, x_parent);                                \
      }                                                                        \
                                                                               \
      y->parent = z->parent;                                                   \
      y->color = z->color;                                                     \
      y->left = z->left;                                                       \
      y->right = z->right;                                                     \
                                                                               \
      if (z->left != NULL) {                                                   \
        z->left->parent = y;                                                   \
      }                                                                        \
      if (z->right != NULL) {                                                  \
        z->right->parent = y;                                                  \
      }                                                                        \
      if (z->parent != NULL) {                                                 \
        if (z->parent->left == z) {                                            \
          z->parent->left = y;                                                 \
        } else {                                                               \
          z->parent->right = y;                                                \
        }                                                                      \
      } else {                                                                 \
        self->root = y;                                                        \
      }                                                                        \
    } else if (y->color == BLACK) {                                            \
      Name##_remove_fixup(self, x, x_parent);                                  \
    }                                                                          \
                                                                               \
    return (Name##Optional){true, z->value};                                   \
  }                                                                            \
                                                                               \
  SOM_INLINE V* Name##_get(Name* self, K key) {                             \
    Name##Node* node = Name##_find_node(self, key);                            \
    if (node == NULL) {                                                        \
      return NULL;                                                             \
    }                                                                          \
    return &node->value;                                                       \
  }                                                                            \
                                                                               \
  SOM_INLINE void Name##_for_each(                                          \
      Name* self, void (*fn)(void* ctx, Name##Entry* entry), void* ctx) {      \
    if (self->root == NULL) {                                                  \
      return;                                                                  \
    }                                                                          \
    Name##Node* current = Name##_tree_minimum(self->root);                     \
    while (current != NULL) {                                                  \
      Name##Entry entry = {current->key, current->value};                      \
      fn(ctx, &entry);                                                         \
      current = Name##Node_successor(current);                                 \
    }                                                                          \
  }

// ---- CallSign

typedef struct CallSign {
  int32_t value;
} CallSign;

static int32_t CallSign_compare_to(CallSign self, CallSign other) {
  return (self.value == other.value) ? 0 : ((self.value < other.value) ? -1 : 1);
}

// ---- Collision

typedef struct Collision {
  CallSign aircraft_a;
  CallSign aircraft_b;
  Vector3D position;
} Collision;

// ---- Constants

#define MIN_X 0.0
#define MIN_Y 0.0
#define MAX_X 1000.0
#define MAX_Y 1000.0
#define MIN_Z 0.0
#define MAX_Z 10.0
#define PROXIMITY_RADIUS 1.0
#define GOOD_VOXEL_SIZE (PROXIMITY_RADIUS * 2.0)

// ---- Motion

typedef struct Motion {
  CallSign callsign;
  Vector3D pos_one;
  Vector3D pos_two;
} Motion;

static Vector3D Motion_delta(const Motion* self) {
  return Vector3D_minus(self->pos_two, self->pos_one);
}

// std::optional<Vector3D>
typedef struct OptionalVector3D {
  bool has_value;
  Vector3D value;
} OptionalVector3D;

static OptionalVector3D Motion_find_intersection(const Motion* self,
                                                 const Motion* other) {
  const Vector3D init1 = self->pos_one;
  const Vector3D init2 = other->pos_one;
  const Vector3D vec1 = Motion_delta(self);
  const Vector3D vec2 = Motion_delta(other);
  const double radius = PROXIMITY_RADIUS;

  // this test is not geometrical 3-d intersection test, it takes the fact
  // that the aircraft move into account ; so it is more like a 4d test (it
  // assumes that both of the aircraft have a constant speed over the tested
  // interval)

  // we thus have two points, each of them moving on its line segment at
  // constant speed ; we are looking for times when the distance between these
  // two points is smaller than r

  // vec1 is vector of aircraft 1
  // vec2 is vector of aircraft 2

  // a = (V2 - V1)^T * (V2 - V1)
  const double a = Vector3D_squared_magnitude(Vector3D_minus(vec2, vec1));

  if (a != 0.0) {
    // we are first looking for instances of time when the planes are exactly
    // r from each other at least one plane is moving ; if the planes are
    // moving in parallel, they do not have constant speed

    // if the planes are moving in parallel, then
    //   if the faster starts behind the slower, we can have 2, 1, or 0
    //   solutions if the faster plane starts in front of the slower, we can
    //   have 0 or 1 solutions

    // if the planes are not moving in parallel, then

    // point P1 = I1 + vV1
    // point P2 = I2 + vV2
    //   - looking for v, such that dist(P1,P2) = || P1 - P2 || = r

    // it follows that || P1 - P2 || = sqrt( < P1-P2, P1-P2 > )
    //   0 = -r^2 + < P1 - P2, P1 - P2 >
    //  from properties of dot product
    //   0 = -r^2 + <I1-I2,I1-I2> + v * 2<I1-I2, V1-V2> + v^2 *<V1-V2,V1-V2>
    //   so we calculate a, b, c - and solve the quadratic equation
    //   0 = c + bv + av^2

    // b = 2 * <I1-I2, V1-V2>
    const double b = 2.0 * Vector3D_dot(Vector3D_minus(init1, init2),
                                        Vector3D_minus(vec1, vec2));

    // c = -r^2 + (I2 - I1)^T * (I2 - I1)
    const double c = -radius * radius +
                     Vector3D_squared_magnitude(Vector3D_minus(init2, init1));

    const double discr = b * b - 4.0 * a * c;
    if (discr < 0.0) {
      return (OptionalVector3D){false, {0}};
    }

    const double v1 = (-b - sqrt(discr)) / (2.0 * a);
    const double v2 = (-b + sqrt(discr)) / (2.0 * a);

    if (v1 <= v2 && ((v1 <= 1.0 && 1.0 <= v2) || (v1 <= 0.0 && 0.0 <= v2) ||
                     (0.0 <= v1 && v2 <= 1.0))) {
      // Pick a good "time" at which to report the collision.
      double v = 0.0;
      if (v1 <= 0.0) {
        // The collision started before this frame. Report it at the start of
        // the frame.
        v = 0.0;
      } else {
        // The collision started during this frame. Report it at that moment.
        v = v1;
      }

      const Vector3D result1 = Vector3D_plus(init1, Vector3D_times(vec1, v));
      const Vector3D result2 = Vector3D_plus(init2, Vector3D_times(vec2, v));

      const Vector3D result =
          Vector3D_times(Vector3D_plus(result1, result2), 0.5);
      if (result.x >= MIN_X && result.x <= MAX_X && result.y >= MIN_Y &&
          result.y <= MAX_Y && result.z >= MIN_Z && result.z <= MAX_Z) {
        return (OptionalVector3D){true, result};
      }
    }

    return (OptionalVector3D){false, {0}};
  }
  // the planes have the same speeds and are moving in parallel (or they are
  // not moving at all) they  thus have the same distance all the time ; we
  // calculate it from the initial point

  // dist = || i2 - i1 || = sqrt(  ( i2 - i1 )^T * ( i2 - i1 ) )
  const double dist = Vector3D_magnitude(Vector3D_minus(init2, init1));
  if (dist <= radius) {
    return (OptionalVector3D){true,
                              Vector3D_times(Vector3D_plus(init1, init2), 0.5)};
  }

  return (OptionalVector3D){false, {0}};
}

// ---- Aircraft

typedef struct Aircraft {
  CallSign callsign;
  Vector3D position;
} Aircraft;

// ---- The vectors and trees CD instantiates

DEFINE_VECTOR(MotionVector, Motion)
DEFINE_VECTOR_OF_POINTERS(MotionVectorVector, MotionVector*)
DEFINE_VECTOR(CollisionVector, Collision)
DEFINE_VECTOR(AircraftVector, Aircraft)
DEFINE_VECTOR(CallSignVector, CallSign)

DEFINE_RED_BLACK_TREE(VoxelMap, Vector2D, MotionVector*, Vector2D_compare_to)
DEFINE_RED_BLACK_TREE(VoxelSeenTree, Vector2D, bool, Vector2D_compare_to)
DEFINE_RED_BLACK_TREE(StateTree, CallSign, Vector3D, CallSign_compare_to)
DEFINE_RED_BLACK_TREE(CallSignSeenTree, CallSign, bool, CallSign_compare_to)

// ---- CollisionDetector

typedef struct CollisionDetector {
  StateTree state;
} CollisionDetector;

static const Vector2D horizontal = {GOOD_VOXEL_SIZE, 0.0};
static const Vector2D vertical = {0.0, GOOD_VOXEL_SIZE};

static bool CollisionDetector_is_in_voxel(Vector2D voxel, const Motion* motion) {
  if (voxel.x > MAX_X || voxel.x < MIN_X || voxel.y > MAX_Y ||
      voxel.y < MIN_Y) {
    return false;
  }

  const Vector3D init = motion->pos_one;
  const Vector3D fin = motion->pos_two;

  const double v_s = GOOD_VOXEL_SIZE;
  const double r = PROXIMITY_RADIUS / 2.0;

  const double v_x = voxel.x;
  const double x0 = init.x;
  const double xv = fin.x - init.x;

  const double v_y = voxel.y;
  const double y0 = init.y;
  const double yv = fin.y - init.y;

  double low_x = (v_x - r - x0) / xv;
  double high_x = (v_x + v_s + r - x0) / xv;

  if (xv < 0.0) {
    const double tmp = low_x;
    low_x = high_x;
    high_x = tmp;
  }

  double low_y = (v_y - r - y0) / yv;
  double high_y = (v_y + v_s + r - y0) / yv;

  if (yv < 0.0) {
    const double tmp = low_y;
    low_y = high_y;
    high_y = tmp;
  }

  return (((xv == 0.0 && v_x <= x0 + r &&
            x0 - r <= v_x + v_s) /* no motion in x */
           || (low_x <= 1.0 && 1.0 <= high_x) ||
           (low_x <= 0.0 && 0.0 <= high_x) ||
           (0.0 <= low_x && high_x <= 1.0)) &&
          ((yv == 0.0 && v_y <= y0 + r &&
            y0 - r <= v_y + v_s) /* no motion in y */
           || ((low_y <= 1.0 && 1.0 <= high_y) ||
               (low_y <= 0.0 && 0.0 <= high_y) ||
               (0.0 <= low_y && high_y <= 1.0))) &&
          (xv == 0.0 || yv == 0.0 || /* no motion in x or y or both */
           (low_y <= high_x && high_x <= high_y) ||
           (low_y <= low_x && low_x <= high_y) ||
           (low_x <= low_y && high_y <= high_x)));
}

static void CollisionDetector_put_into_map(VoxelMap* voxel_map, Vector2D voxel,
                                           const Motion* motion) {
  MotionVector** array = VoxelMap_get(voxel_map, voxel);
  if (array == NULL) {
    MotionVector* arr = MotionVector_new(0);
    MotionVector_append(arr, *motion);
    VoxelMap_put(voxel_map, voxel, arr);
  } else {
    MotionVector_append(*array, *motion);
  }
}

static void CollisionDetector_recurse(CollisionDetector* self,
                                      VoxelMap* voxel_map, VoxelSeenTree* seen,
                                      Vector2D next_voxel,
                                      const Motion* motion) {
  if (!CollisionDetector_is_in_voxel(next_voxel, motion)) {
    return;
  }
  const VoxelSeenTreeOptional was_seen = VoxelSeenTree_put(seen, next_voxel, true);
  if (was_seen.has_value && was_seen.value == true) {
    return;
  }
  CollisionDetector_put_into_map(voxel_map, next_voxel, motion);

  CollisionDetector_recurse(self, voxel_map, seen,
                            Vector2D_minus(next_voxel, horizontal), motion);
  CollisionDetector_recurse(self, voxel_map, seen,
                            Vector2D_plus(next_voxel, horizontal), motion);
  CollisionDetector_recurse(self, voxel_map, seen,
                            Vector2D_minus(next_voxel, vertical), motion);
  CollisionDetector_recurse(self, voxel_map, seen,
                            Vector2D_plus(next_voxel, vertical), motion);
  CollisionDetector_recurse(
      self, voxel_map, seen,
      Vector2D_minus(Vector2D_minus(next_voxel, horizontal), vertical), motion);
  CollisionDetector_recurse(
      self, voxel_map, seen,
      Vector2D_plus(Vector2D_minus(next_voxel, horizontal), vertical), motion);
  CollisionDetector_recurse(
      self, voxel_map, seen,
      Vector2D_minus(Vector2D_plus(next_voxel, horizontal), vertical), motion);
  CollisionDetector_recurse(
      self, voxel_map, seen,
      Vector2D_plus(Vector2D_plus(next_voxel, horizontal), vertical), motion);
}

static Vector2D CollisionDetector_voxel_hash(CollisionDetector* self,
                                             Vector3D position) {
  (void)self;
  const int32_t x_div = (int32_t)(position.x / GOOD_VOXEL_SIZE);
  const int32_t y_div = (int32_t)(position.y / GOOD_VOXEL_SIZE);

  double x = GOOD_VOXEL_SIZE * x_div;
  double y = GOOD_VOXEL_SIZE * y_div;

  if (position.x < 0) {
    x -= GOOD_VOXEL_SIZE;
  }
  if (position.y < 0) {
    y -= GOOD_VOXEL_SIZE;
  }

  return (Vector2D){x, y};
}

static void CollisionDetector_draw_motion_on_voxel_map(CollisionDetector* self,
                                                       VoxelMap* voxel_map,
                                                       const Motion motion) {
  VoxelSeenTree seen;
  VoxelSeenTree_init(&seen);
  CollisionDetector_recurse(self, voxel_map, &seen,
                            CollisionDetector_voxel_hash(self, motion.pos_one),
                            &motion);
  VoxelSeenTree_deinit(&seen);
}

typedef struct DrawMotionCtx {
  CollisionDetector* self;
  VoxelMap* voxel_map;
} DrawMotionCtx;

static void draw_motion_fn(void* ctx, const Motion* motion) {
  DrawMotionCtx* k = (DrawMotionCtx*)ctx;
  CollisionDetector_draw_motion_on_voxel_map(k->self, k->voxel_map, *motion);
}

static void collect_reduced_fn(void* ctx, VoxelMapEntry* e) {
  MotionVectorVector* result = (MotionVectorVector*)ctx;
  if (MotionVector_size(e->value) > 1) {
    MotionVectorVector_append(result, e->value);
  } else {
    MotionVector_delete(e->value);
  }
}

static MotionVectorVector* CollisionDetector_reduce_collision_set(
    CollisionDetector* self, MotionVector* motions) {
  VoxelMap voxel_map;
  VoxelMap_init(&voxel_map);
  DrawMotionCtx k = {self, &voxel_map};
  MotionVector_for_each(motions, draw_motion_fn, &k);

  MotionVectorVector* result = MotionVectorVector_new(0);

  VoxelMap_for_each(&voxel_map, collect_reduced_fn, result);
  VoxelMap_deinit(&voxel_map);
  return result;
}

typedef struct NewFrameCtx {
  CollisionDetector* self;
  CallSignSeenTree* seen;
  MotionVector* motions;
} NewFrameCtx;

static void new_frame_fn(void* ctx, const Aircraft* aircraft) {
  NewFrameCtx* k = (NewFrameCtx*)ctx;
  StateTreeOptional old_position =
      StateTree_put(&k->self->state, aircraft->callsign, aircraft->position);
  const Vector3D new_position = aircraft->position;
  CallSignSeenTree_put(k->seen, aircraft->callsign, true);
  if (!old_position.has_value) {
    // Treat newly introduced aircraft as if they were stationary.
    old_position = (StateTreeOptional){true, new_position};
  }
  MotionVector_append(k->motions, (Motion){aircraft->callsign,
                                           old_position.value, new_position});
}

typedef struct ToRemoveCtx {
  CallSignSeenTree* seen;
  CallSignVector* to_remove;
} ToRemoveCtx;

static void to_remove_fn(void* ctx, StateTreeEntry* e) {
  ToRemoveCtx* k = (ToRemoveCtx*)ctx;
  bool* const was_seen = CallSignSeenTree_get(k->seen, e->key);
  if (was_seen == NULL || !*was_seen) {
    CallSignVector_append(k->to_remove, e->key);
  }
}

static void remove_fn(void* ctx, const CallSign* e) {
  CollisionDetector* self = (CollisionDetector*)ctx;
  StateTree_remove(&self->state, *e);
}

static void find_collisions_fn(void* ctx, MotionVector* const* r) {
  CollisionVector* collisions = (CollisionVector*)ctx;
  const MotionVector* reduced = *r;
  for (size_t i = 0; i < MotionVector_size(reduced); i += 1) {
    const Motion* motion1 = MotionVector_at(reduced, i);
    for (size_t j = i + 1; j < MotionVector_size(reduced); j += 1) {
      const Motion* motion2 = MotionVector_at(reduced, j);
      const OptionalVector3D collision =
          Motion_find_intersection(motion1, motion2);
      if (collision.has_value) {
        CollisionVector_append(collisions,
                               (Collision){motion1->callsign, motion2->callsign,
                                           collision.value});
      }
    }
  }
}

static CollisionVector* CollisionDetector_handle_new_frame(
    CollisionDetector* self, AircraftVector* frame) {
  MotionVector motions;
  MotionVector_init(&motions, 0);
  CallSignSeenTree seen;
  CallSignSeenTree_init(&seen);

  NewFrameCtx frame_ctx = {self, &seen, &motions};
  AircraftVector_for_each(frame, new_frame_fn, &frame_ctx);

  CallSignVector to_remove;
  CallSignVector_init(&to_remove, 0);
  ToRemoveCtx remove_ctx = {&seen, &to_remove};
  StateTree_for_each(&self->state, to_remove_fn, &remove_ctx);

  CallSignVector_for_each(&to_remove, remove_fn, self);

  MotionVectorVector* all_reduced =
      CollisionDetector_reduce_collision_set(self, &motions);
  CollisionVector* collisions = CollisionVector_new(0);

  MotionVectorVector_for_each(all_reduced, find_collisions_fn, collisions);
  MotionVectorVector_destroy_values(all_reduced, MotionVector_delete);
  MotionVectorVector_delete(all_reduced);

  CallSignVector_deinit(&to_remove);
  CallSignSeenTree_deinit(&seen);
  MotionVector_deinit(&motions);
  return collisions;
}

// ---- Simulator

typedef struct Simulator {
  CallSignVector aircraft;
} Simulator;

static void Simulator_init(Simulator* self, int32_t num_aircraft) {
  CallSignVector_init(&self->aircraft, 0);
  for (int32_t i = 0; i < num_aircraft; i += 1) {
    CallSignVector_append(&self->aircraft, (CallSign){i});
  }
}

static void Simulator_deinit(Simulator* self) {
  CallSignVector_deinit(&self->aircraft);
}

static AircraftVector Simulator_simulate(Simulator* self, double time) {
  AircraftVector frame;
  AircraftVector_init(&frame, 0);

  for (size_t i = 0; i < CallSignVector_size(&self->aircraft); i += 2) {
    AircraftVector_append(
        &frame,
        (Aircraft){*CallSignVector_at(&self->aircraft, i),
                   (Vector3D){time, cos(time) * 2 + (double)i * 3, 10}});
    AircraftVector_append(
        &frame,
        (Aircraft){*CallSignVector_at(&self->aircraft, i + 1),
                   (Vector3D){time, sin(time) * 2 + (double)i * 3, 10}});
  }
  return frame;
}

// ---- CD

static size_t CD_run(int32_t num_aircrafts) {
  const int32_t num_frames = 200;

  Simulator simulator;
  Simulator_init(&simulator, num_aircrafts);
  CollisionDetector detector;
  StateTree_init(&detector.state);
  size_t actual_collisions = 0;

  for (int32_t i = 0; i < num_frames; i += 1) {
    const double time = i / 10.0;
    AircraftVector frame = Simulator_simulate(&simulator, time);
    CollisionVector* collisions =
        CollisionDetector_handle_new_frame(&detector, &frame);
    actual_collisions += CollisionVector_size(collisions);
    CollisionVector_delete(collisions);
    AircraftVector_deinit(&frame);
  }

  StateTree_deinit(&detector.state);
  Simulator_deinit(&simulator);
  return actual_collisions;
}

static bool verify(size_t actual_collisions, int32_t num_aircrafts) {
  if (num_aircrafts == 1000) {
    return actual_collisions == 14484;
  }
  if (num_aircrafts == 500) {
    return actual_collisions == 14484;
  }
  if (num_aircrafts == 250) {
    return actual_collisions == 10830;
  }
  if (num_aircrafts == 200) {
    return actual_collisions == 8655;
  }
  if (num_aircrafts == 100) {
    return actual_collisions == 4305;
  }
  if (num_aircrafts == 10) {
    return actual_collisions == 390;
  }
  if (num_aircrafts == 2) {
    return actual_collisions == 42;
  }

  printf("No verification result for %d found\n", num_aircrafts);
  printf("Result is: %zu\n", actual_collisions);
  return false;
}

static bool CD_inner_benchmark_loop(Benchmark* self, int32_t inner_iterations) {
  (void)self;
  return verify(CD_run(inner_iterations), inner_iterations);
}

static Result CD_benchmark(Benchmark* self) {
  (void)self;
  error("Should never be reached");
}

static bool CD_verify_result(Benchmark* self, Result result) {
  (void)self;
  (void)result;
  error("Should never be reached");
}

static const BenchmarkVtbl CD_vtbl = {Benchmark_destroy, CD_benchmark,
                                      CD_verify_result, CD_inner_benchmark_loop};

Benchmark* CD_new(void) {
  return Benchmark_alloc(sizeof(Benchmark), &CD_vtbl);
}
