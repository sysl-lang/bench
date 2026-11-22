// Upstream C++ cd.h.
//
// The red-black tree's nodes point at their parent and their children, as C++'s do. Each node is one
// allocation made by the tree's `Tracker` (C++'s `new Node`), its links are `Cell`s holding `&Node`
// (C++'s `Node*`), and the tree's nodes are freed together when the tracker is, which is when C++'s
// `~RedBlackTree` deletes them from the root. The caller declares the tracker beside the tree because
// a Rust struct cannot hold references into its own fields (SOURCES.md, "Rust").

use std::cell::{Cell, RefCell};
use std::ptr;

use crate::benchmark::Benchmark;
use crate::memory::Tracker;
use crate::som::Vector;

#[derive(Clone, Copy)]
pub struct Vector2D {
    pub x: f64,
    pub y: f64,
}

impl Vector2D {
    fn compare_numbers(a: f64, b: f64) -> i32 {
        if a == b {
            return 0;
        }
        if a < b {
            return -1;
        }
        if a > b {
            return 1;
        }

        // We say that NaN is smaller than non-NaN.
        #[allow(clippy::eq_op)]
        if a == a {
            return 1;
        }
        -1
    }

    const fn new(x: f64, y: f64) -> Vector2D {
        Vector2D { x, y }
    }

    fn plus(&self, other: &Vector2D) -> Vector2D {
        Vector2D::new(self.x + other.x, self.y + other.y)
    }

    fn minus(&self, other: &Vector2D) -> Vector2D {
        Vector2D::new(self.x - other.x, self.y - other.y)
    }
}

#[derive(Clone, Copy)]
pub struct Vector3D {
    pub x: f64,
    pub y: f64,
    pub z: f64,
}

impl Vector3D {
    fn new(x: f64, y: f64, z: f64) -> Vector3D {
        Vector3D { x, y, z }
    }

    fn plus(&self, other: &Vector3D) -> Vector3D {
        Vector3D::new(self.x + other.x, self.y + other.y, self.z + other.z)
    }

    fn minus(&self, other: &Vector3D) -> Vector3D {
        Vector3D::new(self.x - other.x, self.y - other.y, self.z - other.z)
    }

    fn dot(&self, other: &Vector3D) -> f64 {
        self.x * other.x + self.y * other.y + self.z * other.z
    }

    fn squared_magnitude(&self) -> f64 {
        self.dot(self)
    }

    fn magnitude(&self) -> f64 {
        self.squared_magnitude().sqrt()
    }

    fn times(&self, amount: f64) -> Vector3D {
        Vector3D::new(self.x * amount, self.y * amount, self.z * amount)
    }
}

/// C++'s duck-typed `key.compareTo(other)` on the tree's key type.
pub trait CompareTo {
    fn compare_to(&self, other: &Self) -> i32;
}

impl CompareTo for Vector2D {
    fn compare_to(&self, other: &Vector2D) -> i32 {
        let result = Vector2D::compare_numbers(self.x, other.x);

        if result != 0 {
            return result;
        }

        Vector2D::compare_numbers(self.y, other.y)
    }
}

#[derive(Clone, Copy, PartialEq, Eq)]
enum Color {
    Red,
    Black,
}

type Link<'t, K, V> = Option<&'t Node<'t, K, V>>;

pub struct Node<'t, K, V> {
    key: K,
    value: RefCell<V>,
    left: Cell<Link<'t, K, V>>,
    right: Cell<Link<'t, K, V>>,
    parent: Cell<Link<'t, K, V>>,
    color: Cell<Color>,
}

/// C++'s `x == y` on two `Node*`, either of which may be null.
fn same<'t, K, V>(a: Link<'t, K, V>, b: Link<'t, K, V>) -> bool {
    match (a, b) {
        (None, None) => true,
        (Some(a), Some(b)) => ptr::eq(a, b),
        _ => false,
    }
}

fn is_black<K, V>(node: Link<'_, K, V>) -> bool {
    node.is_none_or(|n| n.color.get() == Color::Black)
}

impl<'t, K, V> Node<'t, K, V> {
    fn new(key: K, value: V) -> Node<'t, K, V> {
        Node {
            key,
            value: RefCell::new(value),
            left: Cell::new(None),
            right: Cell::new(None),
            parent: Cell::new(None),
            color: Cell::new(Color::Red),
        }
    }

    /// C++'s `x->_parent` where the algorithm knows it is not null.
    fn parent(&self) -> &'t Node<'t, K, V> {
        self.parent.get().unwrap()
    }

    fn successor(&'t self) -> Link<'t, K, V> {
        let mut x = self;
        if let Some(right) = x.right.get() {
            return Some(tree_minimum(right));
        }
        let mut y = x.parent.get();
        while let Some(yy) = y {
            if !same(Some(x), yy.right.get()) {
                break;
            }
            x = yy;
            y = yy.parent.get();
        }
        y
    }
}

fn tree_minimum<'t, K, V>(x: &'t Node<'t, K, V>) -> &'t Node<'t, K, V> {
    let mut current = x;
    while let Some(left) = current.left.get() {
        current = left;
    }
    current
}

/// C++'s `InsertResult`: a new node, or the value an existing entry held before.
enum InsertResult<'t, K, V> {
    NewEntry(&'t Node<'t, K, V>),
    Existing(V),
}

pub struct RedBlackTree<'t, K, V> {
    root: Cell<Link<'t, K, V>>,
    nodes: &'t Tracker<Node<'t, K, V>>,
}

impl<'t, K: CompareTo + Copy, V> RedBlackTree<'t, K, V> {
    pub fn new(nodes: &'t Tracker<Node<'t, K, V>>) -> RedBlackTree<'t, K, V> {
        RedBlackTree { root: Cell::new(None), nodes }
    }

    fn tree_insert(&self, key: K, value: V) -> InsertResult<'t, K, V> {
        let mut y = None;
        let mut x = self.root.get();

        while let Some(node) = x {
            y = Some(node);
            let comparison_result = key.compare_to(&node.key);
            if comparison_result < 0 {
                x = node.left.get();
            } else if comparison_result > 0 {
                x = node.right.get();
            } else {
                return InsertResult::Existing(node.value.replace(value));
            }
        }

        let z = self.nodes.track(Node::new(key, value));
        z.parent.set(y);
        match y {
            None => self.root.set(Some(z)),
            Some(y) => {
                if key.compare_to(&y.key) < 0 {
                    y.left.set(Some(z));
                } else {
                    y.right.set(Some(z));
                }
            }
        }
        InsertResult::NewEntry(z)
    }

    fn left_rotate(&self, x: &'t Node<'t, K, V>) -> &'t Node<'t, K, V> {
        let y = x.right.get().unwrap();

        // Turn y's left subtree into x's right subtree.
        x.right.set(y.left.get());
        if let Some(y_left) = y.left.get() {
            y_left.parent.set(Some(x));
        }

        // Link x's parent to y
        y.parent.set(x.parent.get());
        match x.parent.get() {
            None => self.root.set(Some(y)),
            Some(x_parent) => {
                if same(Some(x), x_parent.left.get()) {
                    x_parent.left.set(Some(y));
                } else {
                    x_parent.right.set(Some(y));
                }
            }
        }

        // Put x on y's left.
        y.left.set(Some(x));
        x.parent.set(Some(y));

        y
    }

    fn right_rotate(&self, y: &'t Node<'t, K, V>) -> &'t Node<'t, K, V> {
        let x = y.left.get().unwrap();

        // Turn x's right subtree into y's left subtree.
        y.left.set(x.right.get());
        if let Some(x_right) = x.right.get() {
            x_right.parent.set(Some(y));
        }

        // Link y's parent to x;
        x.parent.set(y.parent.get());
        match y.parent.get() {
            None => self.root.set(Some(x)),
            Some(y_parent) => {
                if same(Some(y), y_parent.left.get()) {
                    y_parent.left.set(Some(x));
                } else {
                    y_parent.right.set(Some(x));
                }
            }
        }

        x.right.set(Some(y));
        y.parent.set(Some(x));

        x
    }

    fn remove_fixup(&self, mut x: Link<'t, K, V>, mut x_parent: Link<'t, K, V>) {
        while !same(x, self.root.get()) && is_black(x) {
            let xp = x_parent.unwrap();
            if same(x, xp.left.get()) {
                // Note: the text points out that w cannot be null. The reason is not obvious from
                // simply looking at the code; it comes about from the properties of the red-black
                // tree.
                let mut w = xp.right.get().unwrap();
                if w.color.get() == Color::Red {
                    // Case 1
                    w.color.set(Color::Black);
                    xp.color.set(Color::Red);
                    self.left_rotate(xp);
                    w = xp.right.get().unwrap();
                }
                if is_black(w.left.get()) && is_black(w.right.get()) {
                    // Case 2
                    w.color.set(Color::Red);
                    x = Some(xp);
                    x_parent = xp.parent.get();
                } else {
                    if is_black(w.right.get()) {
                        // Case 3
                        w.left.get().unwrap().color.set(Color::Black);
                        w.color.set(Color::Red);
                        self.right_rotate(w);
                        w = xp.right.get().unwrap();
                    }
                    // Case 4
                    w.color.set(xp.color.get());
                    xp.color.set(Color::Black);
                    if let Some(w_right) = w.right.get() {
                        w_right.color.set(Color::Black);
                    }
                    self.left_rotate(xp);
                    x = self.root.get();
                    x_parent = x.unwrap().parent.get();
                }
            } else {
                // Same as "then" clause with "right" and "left" exchanged.
                let mut w = xp.left.get().unwrap();
                if w.color.get() == Color::Red {
                    // Case 1
                    w.color.set(Color::Black);
                    xp.color.set(Color::Red);
                    self.right_rotate(xp);
                    w = xp.left.get().unwrap();
                }
                if is_black(w.right.get()) && is_black(w.left.get()) {
                    // Case 2
                    w.color.set(Color::Red);
                    x = Some(xp);
                    x_parent = xp.parent.get();
                } else {
                    if is_black(w.left.get()) {
                        // Case 3
                        w.right.get().unwrap().color.set(Color::Black);
                        w.color.set(Color::Red);
                        self.left_rotate(w);
                        w = xp.left.get().unwrap();
                    }
                    // Case 4
                    w.color.set(xp.color.get());
                    xp.color.set(Color::Black);
                    if let Some(w_left) = w.left.get() {
                        w_left.color.set(Color::Black);
                    }
                    self.right_rotate(xp);
                    x = self.root.get();
                    x_parent = x.unwrap().parent.get();
                }
            }
        }
        if let Some(x) = x {
            x.color.set(Color::Black);
        }
    }

    pub fn put(&self, key: K, value: V) -> Option<V> {
        let mut x = match self.tree_insert(key, value) {
            InsertResult::Existing(old_value) => return Some(old_value),
            InsertResult::NewEntry(new_node) => new_node,
        };

        while !same(Some(x), self.root.get()) && x.parent().color.get() == Color::Red {
            if same(Some(x.parent()), x.parent().parent().left.get()) {
                let y = x.parent().parent().right.get();
                match y {
                    Some(y) if y.color.get() == Color::Red => {
                        // Case 1
                        x.parent().color.set(Color::Black);
                        y.color.set(Color::Black);
                        x.parent().parent().color.set(Color::Red);
                        x = x.parent().parent();
                    }
                    _ => {
                        if same(Some(x), x.parent().right.get()) {
                            // Case 2
                            x = x.parent();
                            self.left_rotate(x);
                        }
                        // Case 3
                        x.parent().color.set(Color::Black);
                        x.parent().parent().color.set(Color::Red);
                        self.right_rotate(x.parent().parent());
                    }
                }
            } else {
                // Same as "then" clause with "right" and "left" exchanged.
                let y = x.parent().parent().left.get();
                match y {
                    Some(y) if y.color.get() == Color::Red => {
                        // Case 1
                        x.parent().color.set(Color::Black);
                        y.color.set(Color::Black);
                        x.parent().parent().color.set(Color::Red);
                        x = x.parent().parent();
                    }
                    _ => {
                        if same(Some(x), x.parent().left.get()) {
                            // Case 2
                            x = x.parent();
                            self.right_rotate(x);
                        }
                        // Case 3
                        x.parent().color.set(Color::Black);
                        x.parent().parent().color.set(Color::Red);
                        self.left_rotate(x.parent().parent());
                    }
                }
            }
        }
        self.root.get().unwrap().color.set(Color::Black);
        None
    }

    pub fn remove(&self, key: K) -> Option<V>
    where
        V: Copy,
    {
        let z = self.find_node(key)?;

        // Y is the node to be unlinked from the tree.
        let y = if z.left.get().is_none() || z.right.get().is_none() {
            z
        } else {
            z.successor().unwrap()
        };

        // Y is guaranteed to be non-null at this point.
        let x = if y.left.get().is_some() { y.left.get() } else { y.right.get() };
        // X is the child of y which might potentially replace y in the tree. X might be null at
        // this point.
        let x_parent = match x {
            Some(x) => {
                x.parent.set(y.parent.get());
                x.parent.get()
            }
            None => y.parent.get(),
        };
        match y.parent.get() {
            None => self.root.set(x),
            Some(y_parent) => {
                if same(Some(y), y_parent.left.get()) {
                    y_parent.left.set(x);
                } else {
                    y_parent.right.set(x);
                }
            }
        }

        if !ptr::eq(y, z) {
            if y.color.get() == Color::Black {
                self.remove_fixup(x, x_parent);
            }

            y.parent.set(z.parent.get());
            y.color.set(z.color.get());
            y.left.set(z.left.get());
            y.right.set(z.right.get());

            if let Some(z_left) = z.left.get() {
                z_left.parent.set(Some(y));
            }
            if let Some(z_right) = z.right.get() {
                z_right.parent.set(Some(y));
            }
            match z.parent.get() {
                Some(z_parent) => {
                    if same(z_parent.left.get(), Some(z)) {
                        z_parent.left.set(Some(y));
                    } else {
                        z_parent.right.set(Some(y));
                    }
                }
                None => self.root.set(Some(y)),
            }
        } else if y.color.get() == Color::Black {
            self.remove_fixup(x, x_parent);
        }

        Some(*z.value.borrow())
    }

    pub fn get(&self, key: K) -> Option<&'t RefCell<V>> {
        self.find_node(key).map(|node| &node.value)
    }

    pub fn for_each(&self, mut f: impl FnMut(K, &RefCell<V>)) {
        let Some(root) = self.root.get() else {
            return;
        };
        let mut current = Some(tree_minimum(root));
        while let Some(node) = current {
            f(node.key, &node.value);
            current = node.successor();
        }
    }

    fn find_node(&self, key: K) -> Link<'t, K, V> {
        let mut current = self.root.get();
        while let Some(node) = current {
            let comparison_result = key.compare_to(&node.key);
            if comparison_result == 0 {
                return current;
            }
            if comparison_result < 0 {
                current = node.left.get();
            } else {
                current = node.right.get();
            }
        }
        None
    }
}

#[derive(Clone, Copy)]
pub struct CallSign {
    value: i32,
}

impl CallSign {
    fn new(value: i32) -> CallSign {
        CallSign { value }
    }
}

impl CompareTo for CallSign {
    fn compare_to(&self, other: &CallSign) -> i32 {
        if self.value == other.value {
            0
        } else if self.value < other.value {
            -1
        } else {
            1
        }
    }
}

struct Collision {
    #[allow(dead_code)]
    aircraft_a: CallSign,
    #[allow(dead_code)]
    aircraft_b: CallSign,
    #[allow(dead_code)]
    position: Vector3D,
}

const MIN_X: f64 = 0.0;
const MIN_Y: f64 = 0.0;
const MAX_X: f64 = 1000.0;
const MAX_Y: f64 = 1000.0;
const MIN_Z: f64 = 0.0;
const MAX_Z: f64 = 10.0;
const PROXIMITY_RADIUS: f64 = 1.0;
const GOOD_VOXEL_SIZE: f64 = PROXIMITY_RADIUS * 2.0;

#[derive(Clone, Copy)]
struct Motion {
    callsign: CallSign,
    pos_one: Vector3D,
    pos_two: Vector3D,
}

impl Motion {
    fn delta(&self) -> Vector3D {
        self.pos_two.minus(&self.pos_one)
    }

    fn find_intersection(&self, other: &Motion) -> Option<Vector3D> {
        let init1 = &self.pos_one;
        let init2 = &other.pos_one;
        let vec1 = self.delta();
        let vec2 = other.delta();
        let radius = PROXIMITY_RADIUS;

        // this test is not geometrical 3-d intersection test, it takes the fact that the aircraft
        // move into account ; so it is more like a 4d test (it assumes that both of the aircraft
        // have a constant speed over the tested interval)

        // we thus have two points, each of them moving on its line segment at constant speed ; we
        // are looking for times when the distance between these two points is smaller than r

        // vec1 is vector of aircraft 1
        // vec2 is vector of aircraft 2

        // a = (V2 - V1)^T * (V2 - V1)
        let a = vec2.minus(&vec1).squared_magnitude();

        if a != 0.0 {
            // we are first looking for instances of time when the planes are exactly r from each
            // other at least one plane is moving ; if the planes are moving in parallel, they do
            // not have constant speed

            // if the planes are moving in parallel, then
            //   if the faster starts behind the slower, we can have 2, 1, or 0 solutions if the
            //   faster plane starts in front of the slower, we can have 0 or 1 solutions

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
            let b = 2.0 * init1.minus(init2).dot(&vec1.minus(&vec2));

            // c = -r^2 + (I2 - I1)^T * (I2 - I1)
            let c = -radius * radius + init2.minus(init1).squared_magnitude();

            let discr = b * b - 4.0 * a * c;
            if discr < 0.0 {
                return None;
            }

            let v1 = (-b - discr.sqrt()) / (2.0 * a);
            let v2 = (-b + discr.sqrt()) / (2.0 * a);

            if v1 <= v2 && ((v1 <= 1.0 && 1.0 <= v2) || (v1 <= 0.0 && 0.0 <= v2) || (0.0 <= v1 && v2 <= 1.0)) {
                // Pick a good "time" at which to report the collision.
                let v = if v1 <= 0.0 {
                    // The collision started before this frame. Report it at the start of the
                    // frame.
                    0.0
                } else {
                    // The collision started during this frame. Report it at that moment.
                    v1
                };

                let result1 = init1.plus(&vec1.times(v));
                let result2 = init2.plus(&vec2.times(v));

                let result = result1.plus(&result2).times(0.5);
                if result.x >= MIN_X
                    && result.x <= MAX_X
                    && result.y >= MIN_Y
                    && result.y <= MAX_Y
                    && result.z >= MIN_Z
                    && result.z <= MAX_Z
                {
                    return Some(result);
                }
            }

            return None;
        }
        // the planes have the same speeds and are moving in parallel (or they are not moving at
        // all) they  thus have the same distance all the time ; we calculate it from the initial
        // point

        // dist = || i2 - i1 || = sqrt(  ( i2 - i1 )^T * ( i2 - i1 ) )
        let dist = init2.minus(init1).magnitude();
        if dist <= radius {
            return Some(init1.plus(init2).times(0.5));
        }

        None
    }
}

struct Aircraft {
    callsign: CallSign,
    position: Vector3D,
}

/// C++'s `RedBlackTree<Vector2D, Vector<Motion>*>`: each voxel's motions are one `new` vector.
/// The `Option` lets `reduce_collision_set` move a vector out of the map, as C++ copies the pointer.
type VoxelMap<'t> = RedBlackTree<'t, Vector2D, Option<Box<Vector<Motion>>>>;

struct CollisionDetector<'t> {
    state: RedBlackTree<'t, CallSign, Vector3D>,
}

const HORIZONTAL: Vector2D = Vector2D::new(GOOD_VOXEL_SIZE, 0.0);
const VERTICAL: Vector2D = Vector2D::new(0.0, GOOD_VOXEL_SIZE);

impl<'t> CollisionDetector<'t> {
    fn new(state_nodes: &'t Tracker<Node<'t, CallSign, Vector3D>>) -> CollisionDetector<'t> {
        CollisionDetector { state: RedBlackTree::new(state_nodes) }
    }

    fn is_in_voxel(voxel: &Vector2D, motion: &Motion) -> bool {
        if voxel.x > MAX_X || voxel.x < MIN_X || voxel.y > MAX_Y || voxel.y < MIN_Y {
            return false;
        }

        let init = &motion.pos_one;
        let fin = &motion.pos_two;

        let v_s = GOOD_VOXEL_SIZE;
        let r = PROXIMITY_RADIUS / 2.0;

        let v_x = voxel.x;
        let x0 = init.x;
        let xv = fin.x - init.x;

        let v_y = voxel.y;
        let y0 = init.y;
        let yv = fin.y - init.y;

        let mut low_x = (v_x - r - x0) / xv;
        let mut high_x = (v_x + v_s + r - x0) / xv;

        if xv < 0.0 {
            std::mem::swap(&mut low_x, &mut high_x);
        }

        let mut low_y = (v_y - r - y0) / yv;
        let mut high_y = (v_y + v_s + r - y0) / yv;

        if yv < 0.0 {
            std::mem::swap(&mut low_y, &mut high_y);
        }

        ((xv == 0.0 && v_x <= x0 + r && x0 - r <= v_x + v_s) // no motion in x
            || (low_x <= 1.0 && 1.0 <= high_x)
            || (low_x <= 0.0 && 0.0 <= high_x)
            || (0.0 <= low_x && high_x <= 1.0))
            && ((yv == 0.0 && v_y <= y0 + r && y0 - r <= v_y + v_s) // no motion in y
                || ((low_y <= 1.0 && 1.0 <= high_y)
                    || (low_y <= 0.0 && 0.0 <= high_y)
                    || (0.0 <= low_y && high_y <= 1.0)))
            && (xv == 0.0 || yv == 0.0 // no motion in x or y or both
                || (low_y <= high_x && high_x <= high_y)
                || (low_y <= low_x && low_x <= high_y)
                || (low_x <= low_y && high_y <= high_x))
    }

    fn put_into_map(voxel_map: &VoxelMap<'_>, voxel: &Vector2D, motion: &Motion) {
        match voxel_map.get(*voxel) {
            None => {
                let mut arr = Box::new(Vector::new());
                arr.append(*motion);
                voxel_map.put(*voxel, Some(arr));
            }
            Some(array) => array.borrow_mut().as_mut().unwrap().append(*motion),
        }
    }

    fn recurse(
        &self,
        voxel_map: &VoxelMap<'_>,
        seen: &RedBlackTree<'_, Vector2D, bool>,
        next_voxel: &Vector2D,
        motion: &Motion,
    ) {
        if !Self::is_in_voxel(next_voxel, motion) {
            return;
        }
        if seen.put(*next_voxel, true) == Some(true) {
            return;
        }
        Self::put_into_map(voxel_map, next_voxel, motion);

        self.recurse(voxel_map, seen, &next_voxel.minus(&HORIZONTAL), motion);
        self.recurse(voxel_map, seen, &next_voxel.plus(&HORIZONTAL), motion);
        self.recurse(voxel_map, seen, &next_voxel.minus(&VERTICAL), motion);
        self.recurse(voxel_map, seen, &next_voxel.plus(&VERTICAL), motion);
        self.recurse(voxel_map, seen, &next_voxel.minus(&HORIZONTAL).minus(&VERTICAL), motion);
        self.recurse(voxel_map, seen, &next_voxel.minus(&HORIZONTAL).plus(&VERTICAL), motion);
        self.recurse(voxel_map, seen, &next_voxel.plus(&HORIZONTAL).minus(&VERTICAL), motion);
        self.recurse(voxel_map, seen, &next_voxel.plus(&HORIZONTAL).plus(&VERTICAL), motion);
    }

    fn reduce_collision_set(&self, motions: &Vector<Motion>) -> Box<Vector<Box<Vector<Motion>>>> {
        let voxel_map_nodes = Tracker::new();
        let voxel_map: VoxelMap<'_> = RedBlackTree::new(&voxel_map_nodes);
        motions.for_each(|motion| self.draw_motion_on_voxel_map(&voxel_map, motion));

        let mut result = Box::new(Vector::new());

        voxel_map.for_each(|_, value| {
            let array = value.borrow_mut().take().unwrap();
            if array.size() > 1 {
                result.append(array);
            }
            // otherwise `array` is freed here, as C++ deletes it
        });
        result
    }

    fn voxel_hash(&self, position: Vector3D) -> Vector2D {
        let x_div = (position.x / GOOD_VOXEL_SIZE) as i32;
        let y_div = (position.y / GOOD_VOXEL_SIZE) as i32;

        let mut x = GOOD_VOXEL_SIZE * f64::from(x_div);
        let mut y = GOOD_VOXEL_SIZE * f64::from(y_div);

        if position.x < 0.0 {
            x -= GOOD_VOXEL_SIZE;
        }
        if position.y < 0.0 {
            y -= GOOD_VOXEL_SIZE;
        }

        Vector2D::new(x, y)
    }

    fn draw_motion_on_voxel_map(&self, voxel_map: &VoxelMap<'_>, motion: &Motion) {
        let seen_nodes = Tracker::new();
        let seen = RedBlackTree::new(&seen_nodes);
        self.recurse(voxel_map, &seen, &self.voxel_hash(motion.pos_one), motion);
    }

    fn handle_new_frame(&mut self, frame: &Vector<Aircraft>) -> Box<Vector<Collision>> {
        let mut motions = Vector::new();
        let seen_nodes = Tracker::new();
        let seen = RedBlackTree::new(&seen_nodes);

        frame.for_each(|aircraft| {
            let mut old_position = self.state.put(aircraft.callsign, aircraft.position);
            let new_position = aircraft.position;
            seen.put(aircraft.callsign, true);
            if old_position.is_none() {
                // Treat newly introduced aircraft as if they were stationary.
                old_position = Some(new_position);
            }
            motions.append(Motion {
                callsign: aircraft.callsign,
                pos_one: old_position.unwrap(),
                pos_two: new_position,
            });
        });

        let mut to_remove = Vector::new();
        self.state.for_each(|key, _| {
            let was_seen = seen.get(key);
            if was_seen.is_none_or(|was_seen| !*was_seen.borrow()) {
                to_remove.append(key);
            }
        });

        to_remove.for_each(|e| {
            self.state.remove(*e);
        });

        let all_reduced = self.reduce_collision_set(&motions);
        let mut collisions = Box::new(Vector::new());

        all_reduced.for_each(|reduced| {
            for i in 0..reduced.size() {
                let motion1 = reduced.at(i).unwrap();
                for j in i + 1..reduced.size() {
                    let motion2 = reduced.at(j).unwrap();
                    if let Some(collision) = motion1.find_intersection(motion2) {
                        collisions.append(Collision {
                            aircraft_a: motion1.callsign,
                            aircraft_b: motion2.callsign,
                            position: collision,
                        });
                    }
                }
            }
        });
        drop(all_reduced);
        collisions
    }
}

struct Simulator {
    aircraft: Vector<CallSign>,
}

impl Simulator {
    fn new(num_aircraft: i32) -> Simulator {
        let mut aircraft = Vector::new();
        for i in 0..num_aircraft {
            aircraft.append(CallSign::new(i));
        }
        Simulator { aircraft }
    }

    fn simulate(&self, time: f64) -> Vector<Aircraft> {
        let mut frame = Vector::new();

        let mut i = 0;
        while i < self.aircraft.size() {
            frame.append(Aircraft {
                callsign: *self.aircraft.at(i).unwrap(),
                position: Vector3D::new(time, time.cos() * 2.0 + i as f64 * 3.0, 10.0),
            });
            frame.append(Aircraft {
                callsign: *self.aircraft.at(i + 1).unwrap(),
                position: Vector3D::new(time, time.sin() * 2.0 + i as f64 * 3.0, 10.0),
            });
            i += 2;
        }
        frame
    }
}

pub struct CD;

impl CD {
    fn run(num_aircrafts: i32) -> usize {
        let num_frames = 200;

        let simulator = Simulator::new(num_aircrafts);
        let state_nodes = Tracker::new();
        let mut detector = CollisionDetector::new(&state_nodes);
        let mut actual_collisions = 0;

        for i in 0..num_frames {
            let time = f64::from(i) / 10.0;
            let frame = simulator.simulate(time);
            let collisions = detector.handle_new_frame(&frame);
            actual_collisions += collisions.size();
        }

        actual_collisions
    }

    fn verify(actual_collisions: usize, num_aircrafts: i32) -> bool {
        if num_aircrafts == 1000 {
            return actual_collisions == 14484;
        }
        if num_aircrafts == 500 {
            return actual_collisions == 14484;
        }
        if num_aircrafts == 250 {
            return actual_collisions == 10830;
        }
        if num_aircrafts == 200 {
            return actual_collisions == 8655;
        }
        if num_aircrafts == 100 {
            return actual_collisions == 4305;
        }
        if num_aircrafts == 10 {
            return actual_collisions == 390;
        }
        if num_aircrafts == 2 {
            return actual_collisions == 42;
        }

        println!("No verification result for {num_aircrafts} found");
        println!("Result is: {actual_collisions}");
        false
    }
}

impl Benchmark for CD {
    type Result = ();

    fn benchmark(&mut self) {
        unreachable!("Should never be reached");
    }

    fn verify_result(&mut self, _result: ()) -> bool {
        unreachable!("Should never be reached");
    }

    fn inner_benchmark_loop(&mut self, inner_iterations: i32) -> bool {
        CD::verify(CD::run(inner_iterations), inner_iterations)
    }
}
