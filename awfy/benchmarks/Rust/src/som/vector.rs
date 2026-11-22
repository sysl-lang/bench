// Upstream C++ som/vector.h: a growable array with a first index (so `remove_first` is O(1)), an
// initial capacity of 10 that doubles, `for_each`/`has_some`/`get_one` taking closures, and the
// suite's own quicksort. The `Vec` underneath is only the storage C++ allocates with `new E[n]`:
// its length is C++'s `_lastIdx`, and every capacity change is one `reserve_exact` where C++ has
// `new`, copy, `delete[]`.

use std::ptr;

const INITIAL_SIZE: usize = 10;

/// Equality as C++'s `storage[i] == obj` on the suite's element types: the address of an object
/// (`&T`; for a trait object, its data pointer), or the value of an integer.
pub trait Identical {
    fn identical(&self, other: &Self) -> bool;
}

impl<T: ?Sized> Identical for &T {
    fn identical(&self, other: &Self) -> bool {
        ptr::addr_eq(*self as *const T, *other as *const T)
    }
}

impl Identical for i32 {
    fn identical(&self, other: &Self) -> bool {
        self == other
    }
}

impl Identical for usize {
    fn identical(&self, other: &Self) -> bool {
        self == other
    }
}

pub struct Vector<E> {
    storage: Vec<E>,
    capacity: usize,
    first_idx: usize,
}

impl<E> Vector<E> {
    pub fn with(elem: E) -> Box<Vector<E>> {
        let mut v = Box::new(Vector::with_capacity(1));
        v.append(elem);
        v
    }

    pub fn with_capacity(size: usize) -> Vector<E> {
        Vector { storage: Vec::with_capacity(size), capacity: size, first_idx: 0 }
    }

    pub fn new() -> Vector<E> {
        Vector::with_capacity(0)
    }

    fn last_idx(&self) -> usize {
        self.storage.len()
    }

    pub fn at(&self, idx: usize) -> Option<&E> {
        if self.capacity == 0 || idx >= self.last_idx() - self.first_idx {
            return None;
        }
        Some(&self.storage[self.first_idx + idx])
    }

    pub fn at_put(&mut self, idx: usize, val: E)
    where
        E: Default,
    {
        if self.capacity == 0 {
            self.capacity = (idx + 1).max(INITIAL_SIZE);
            self.storage = Vec::with_capacity(self.capacity);
        } else if idx >= self.last_idx() - self.first_idx {
            let mut new_length = self.capacity;
            while new_length <= idx + self.first_idx {
                new_length *= 2;
            }
            self.grow_to(new_length);
        }
        while self.storage.len() <= self.first_idx + idx {
            self.storage.push(E::default());
        }
        self.storage[self.first_idx + idx] = val;
    }

    pub fn append(&mut self, elem: E) {
        if self.capacity == 0 {
            self.capacity = INITIAL_SIZE;
            self.storage = Vec::with_capacity(INITIAL_SIZE);
        } else if self.last_idx() >= self.capacity {
            // Need to expand capacity first
            self.grow_to(self.capacity * 2);
        }
        self.storage.push(elem);
    }

    fn grow_to(&mut self, new_length: usize) {
        if new_length > self.capacity {
            self.storage.reserve_exact(new_length - self.storage.len());
            self.capacity = new_length;
        }
    }

    pub fn is_empty(&self) -> bool {
        self.last_idx() == self.first_idx
    }

    pub fn for_each(&self, mut f: impl FnMut(&E)) {
        for e in &self.storage[self.first_idx..] {
            f(e);
        }
    }

    pub fn for_each_mut(&mut self, mut f: impl FnMut(&mut E)) {
        for e in &mut self.storage[self.first_idx..] {
            f(e);
        }
    }

    pub fn has_some(&self, mut f: impl FnMut(&E) -> bool) -> bool {
        for e in &self.storage[self.first_idx..] {
            if f(e) {
                return true;
            }
        }
        false
    }

    pub fn get_one(&self, mut f: impl FnMut(&E) -> bool) -> Option<E>
    where
        E: Clone,
    {
        for e in &self.storage[self.first_idx..] {
            if f(e) {
                return Some(e.clone());
            }
        }
        None
    }

    pub fn first(&self) -> Option<E>
    where
        E: Clone,
    {
        if self.is_empty() {
            return None;
        }
        Some(self.storage[self.first_idx].clone())
    }

    pub fn remove_first(&mut self) -> Option<E>
    where
        E: Clone,
    {
        if self.is_empty() {
            return None;
        }
        self.first_idx += 1;
        Some(self.storage[self.first_idx - 1].clone())
    }

    pub fn remove(&mut self, obj: &E) -> bool
    where
        E: Identical + Clone,
    {
        if self.capacity == 0 || self.is_empty() {
            return false;
        }

        let mut found = false;
        let mut new_last = self.first_idx;
        for i in self.first_idx..self.last_idx() {
            if self.storage[i].identical(obj) {
                found = true;
            } else {
                self.storage[new_last] = self.storage[i].clone();
                new_last += 1;
            }
        }
        self.storage.truncate(new_last);
        found
    }

    /// C++'s `removeAll`: frees the elements (C++'s `destroyValues`; here their `Drop`), and
    /// replaces the storage with a fresh one of the same capacity.
    pub fn remove_all(&mut self) {
        self.first_idx = 0;
        if self.capacity != 0 {
            self.storage = Vec::with_capacity(self.capacity);
        }
    }

    pub fn size(&self) -> usize {
        self.last_idx() - self.first_idx
    }

    pub fn get_capacity(&self) -> usize {
        self.capacity
    }

    pub fn sort(&mut self, mut c: impl FnMut(&E, &E) -> i32)
    where
        E: Clone,
    {
        if self.size() > 0 {
            self.sort_range(self.first_idx, self.last_idx() - 1, &mut c);
        }
    }

    fn sort_range(&mut self, i: usize, j: usize, c: &mut impl FnMut(&E, &E) -> i32)
    where
        E: Clone,
    {
        let n = j + 1 - i;
        if n <= 1 {
            return;
        }

        let mut di = self.storage[i].clone();
        let mut dj = self.storage[j].clone();

        if c(&di, &dj) > 0 {
            self.storage.swap(i, j);
            std::mem::swap(&mut di, &mut dj);
        }

        if n > 2 {
            let ij = (i + j) / 2;
            let mut dij = self.storage[ij].clone();

            if c(&di, &dij) <= 0 {
                if c(&dij, &dj) > 0 {
                    self.storage.swap(j, ij);
                    dij = dj;
                }
            } else {
                self.storage.swap(i, ij);
                dij = di;
            }

            if n > 3 {
                let mut k = i;
                let mut l = j - 1;

                loop {
                    while k <= l && c(&dij, &self.storage[l]) <= 0 {
                        l = l.wrapping_sub(1);
                    }

                    k += 1;
                    while k <= l && c(&self.storage[k], &dij) <= 0 {
                        k += 1;
                    }

                    if k > l {
                        break;
                    }
                    self.storage.swap(k, l);
                }

                self.sort_range(i, l, c);
                self.sort_range(k, j, c);
            }
        }
    }
}
