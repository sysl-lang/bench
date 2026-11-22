// Upstream C++ memory/object_tracker.h, the memory strategy upstream's guidelines name for the two
// benchmarks whose objects form cyclic graphs (guidelines.md, "C++": DeltaBlue and Richards "use
// object_tracker"): every object is allocated on its own, referenced by plain pointers while the
// benchmark runs, and freed all together when the tracker is released.
//
// In Rust the pointers are `&'t T` references bounded by the tracker's borrow, and an object's
// mutable fields are `Cell`s, so the graph is checked by the borrow checker and costs nothing at run
// time. Each object is its own heap allocation (`Box`), as C++'s `new` is; dropping the tracker is
// C++'s `ObjectTracker::releaseAll()`.
//
// Two trackers, because Rust's drop checker must be able to see that freeing a graph never reads a
// freed neighbour:
//
// - `Tracker<T>` holds objects of one type and runs their destructors (DeltaBlue's `Variable` owns
//   a vector). Its storage is a `Vec<Box<T>>`, whose drop the checker knows reads no `&'t` inside.
// - `ObjectTracker` holds objects of any type that has no destructor at all (Richards' packets,
//   tasks, records and closures: references, `Cell`s and integers). It frees their memory without
//   running anything, which a compile-time assertion makes the only possible use.
//
// `Tracker<T>` also holds CD's red-black tree nodes and Havlak's blocks, loops and union-find nodes.
// These are the crate's only `unsafe` blocks; each states its proof.

use std::alloc::{dealloc, Layout};
use std::cell::RefCell;
use std::ptr::NonNull;

pub struct Tracker<T> {
    objects: RefCell<Vec<Box<T>>>,
}

impl<T> Tracker<T> {
    pub fn new() -> Tracker<T> {
        Tracker { objects: RefCell::new(Vec::new()) }
    }

    pub fn track(&self, obj: T) -> &T {
        let mut objects = self.objects.borrow_mut();
        objects.push(Box::new(obj));
        let tracked: *const T = &**objects.last().unwrap();
        drop(objects);
        // SAFETY: `tracked` points into a `Box` that this tracker owns. A `Box`'s allocation never
        // moves when the `Vec` holding it grows, no `Box` is removed or mutated before the tracker
        // is dropped, and the returned reference borrows `self`, so it cannot outlive the
        // allocation. Only shared references to the object are ever created.
        unsafe { &*tracked }
    }
}

pub struct ObjectTracker {
    objects: RefCell<Vec<(NonNull<u8>, Layout)>>,
}

impl ObjectTracker {
    pub fn new() -> ObjectTracker {
        ObjectTracker { objects: RefCell::new(Vec::new()) }
    }

    pub fn track<T>(&self, obj: T) -> &T {
        const { assert!(!std::mem::needs_drop::<T>(), "ObjectTracker holds only types without a destructor") };
        let raw = Box::into_raw(Box::new(obj));
        let layout = Layout::new::<T>();
        if layout.size() != 0 {
            self.objects.borrow_mut().push((NonNull::new(raw).unwrap().cast(), layout));
        }
        // SAFETY: `raw` comes from `Box::into_raw`, so it is valid, aligned and uniquely owned by
        // this tracker, which frees it only in `drop`. The returned reference borrows `self`, so it
        // cannot outlive that, and only shared references to the object are ever created.
        unsafe { &*raw }
    }
}

impl Drop for ObjectTracker {
    fn drop(&mut self) {
        for (object, layout) in self.objects.get_mut().drain(..) {
            // SAFETY: each entry is a live allocation made by `Box::new` with exactly this layout,
            // recorded once and freed once, here. Its type has no destructor (asserted at compile
            // time in `track`), so freeing the memory is all a `Box` drop would do; and no reference
            // to it survives, because every one borrowed `self`, which is now exclusively borrowed.
            unsafe { dealloc(object.as_ptr(), layout) };
        }
    }
}
