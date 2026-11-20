#pragma once

// memory/object_tracker.h of the C++ port.
//
// A TrackedObject is the base of every class that registers itself on
// construction. Its C++ destructor is virtual, so every tracked object has a
// vtable whose first entry is that destructor: in C, each tracked struct
// starts with a TrackedObject, whose vt points at the first member of the
// class's own vtable struct (a TrackedObjectVtbl), as in CPython's
// PyObject/PyTypeObject.

typedef struct TrackedObject TrackedObject;

typedef struct TrackedObjectVtbl {
  void (*destroy)(TrackedObject* self);
} TrackedObjectVtbl;

struct TrackedObject {
  const TrackedObjectVtbl* vt;
};

// ObjectTracker::track: append to the tracked list.
void ObjectTracker_track(TrackedObject* obj);

// ObjectTracker::releaseAll: delete every tracked object through its virtual
// destructor, then clear the list (its storage is kept, as std::vector's
// clear() keeps its capacity).
void ObjectTracker_release_all(void);

// The TrackedObject constructor: set the vtable and register.
static inline void TrackedObject_init(TrackedObject* self,
                                      const TrackedObjectVtbl* vt) {
  self->vt = vt;
  ObjectTracker_track(self);
}
