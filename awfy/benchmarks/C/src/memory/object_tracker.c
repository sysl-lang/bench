#include "object_tracker.h"

#include <stddef.h>
#include <stdlib.h>
#include <string.h>

// std::vector<TrackedObject*>: storage doubles when full (libc++'s growth),
// moving the elements to the new storage and freeing the old.
static TrackedObject** tracked_objects = NULL;
static size_t tracked_size = 0;
static size_t tracked_capacity = 0;

void ObjectTracker_track(TrackedObject* obj) {
  if (tracked_size == tracked_capacity) {
    const size_t new_capacity = tracked_capacity == 0 ? 1 : tracked_capacity * 2;
    TrackedObject** new_storage =
        (TrackedObject**)malloc(new_capacity * sizeof(TrackedObject*));
    if (tracked_size > 0) {
      memcpy(new_storage, tracked_objects, tracked_size * sizeof(TrackedObject*));
    }
    free(tracked_objects);
    tracked_objects = new_storage;
    tracked_capacity = new_capacity;
  }
  tracked_objects[tracked_size] = obj;
  tracked_size += 1;
}

void ObjectTracker_release_all(void) {
  for (size_t i = 0; i < tracked_size; i += 1) {
    TrackedObject* obj = tracked_objects[i];
    obj->vt->destroy(obj);
  }
  tracked_size = 0;
}
