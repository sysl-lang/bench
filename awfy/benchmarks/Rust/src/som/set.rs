// Upstream C++ som/set.h and som/identity_set.h: a set over the suite's `Vector`, with linear
// `contains`. C++'s `Set` compares an integer by value and an object with `equal`; its
// `IdentitySet` compares by address. The only sets the suite builds (Havlak's) hold integers or
// object indices, for which both comparisons are `==`, so `IdentitySet` is the same type.

use super::vector::{Identical, Vector};

const INITIAL_SIZE: usize = 10;

pub struct Set<E> {
    items: Vector<E>,
}

pub type IdentitySet<E> = Set<E>;

impl<E: Identical + Clone> Set<E> {
    pub fn new() -> Set<E> {
        Set { items: Vector::with_capacity(INITIAL_SIZE) }
    }

    pub fn size(&self) -> usize {
        self.items.size()
    }

    pub fn for_each(&self, f: impl FnMut(&E)) {
        self.items.for_each(f);
    }

    pub fn has_some(&self, f: impl FnMut(&E) -> bool) -> bool {
        self.items.has_some(f)
    }

    pub fn get_one(&self, f: impl FnMut(&E) -> bool) -> Option<E> {
        self.items.get_one(f)
    }

    pub fn add(&mut self, obj: E) {
        if !self.contains(&obj) {
            self.items.append(obj);
        }
    }

    pub fn collect<T>(&self, mut f: impl FnMut(&E) -> T) -> Box<Vector<T>> {
        let mut coll = Box::new(Vector::new());
        self.for_each(|e| coll.append(f(e)));
        coll
    }

    pub fn contains(&self, obj: &E) -> bool {
        self.has_some(|e| e.identical(obj))
    }

    pub fn remove_all(&mut self) {
        self.items.remove_all();
    }
}
