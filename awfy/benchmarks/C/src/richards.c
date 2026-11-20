#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "benchmark.h"
#include "memory/object_tracker.h"
#include "som/error.h"

// Every class derives from RBObject, a TrackedObject: each object carries a
// vtable pointer (its virtual destructor) and is registered with the
// ObjectTracker on construction, as in C++. Each class has its own vtable, so
// the vtable pointer identifies the dynamic type; the C++ dynamic_cast of the
// task's private data is a comparison of it (a checked downcast that yields
// NULL on a mismatch, as dynamic_cast does).

enum {
  IDLER = 0,
  WORKER = 1,
  HANDLER_A = 2,
  HANDLER_B = 3,
  DEVICE_A = 4,
  DEVICE_B = 5,
  NUM_TYPES = 6,

  DEVICE_PACKET_KIND = 0,
  WORK_PACKET_KIND = 1,

  DATA_SIZE = 4,
};

#define NO_WORK ((Packet*)NULL)
#define NO_TASK ((TaskControlBlock*)NULL)
#define TRACING false

typedef TrackedObject RBObject;

static void RBObject_destroy(TrackedObject* self) {
  free(self);
}

// One vtable per class; all hold just the (defaulted) virtual destructor.
static const TrackedObjectVtbl TaskState_vtbl = {RBObject_destroy};
static const TrackedObjectVtbl DeviceTaskDataRecord_vtbl = {RBObject_destroy};
static const TrackedObjectVtbl HandlerTaskDataRecord_vtbl = {RBObject_destroy};
static const TrackedObjectVtbl IdleTaskDataRecord_vtbl = {RBObject_destroy};
static const TrackedObjectVtbl Packet_vtbl = {RBObject_destroy};
static const TrackedObjectVtbl TaskControlBlock_vtbl = {RBObject_destroy};
static const TrackedObjectVtbl WorkerTaskDataRecord_vtbl = {RBObject_destroy};
static const TrackedObjectVtbl Scheduler_vtbl = {RBObject_destroy};

// `new T()` for a tracked class: allocate, set the vtable, register.
static void* RBObject_new(size_t size, const TrackedObjectVtbl* vt) {
  RBObject* o = (RBObject*)malloc(size);
  TrackedObject_init(o, vt);
  return o;
}

// dynamic_cast<T*>(o)
#define DYNAMIC_CAST(T, o) ((o)->vt == &T##_vtbl ? (T*)(o) : (T*)NULL)

typedef struct Packet Packet;
typedef struct TaskControlBlock TaskControlBlock;
typedef struct Scheduler Scheduler;

// ---- Packet

struct Packet {
  RBObject base;
  Packet* link;
  int32_t identity;
  int32_t kind;
  int32_t datum;
  int32_t data[DATA_SIZE];
};

static Packet* Packet_new(Packet* link, int32_t identity, int32_t kind) {
  Packet* p = (Packet*)RBObject_new(sizeof(Packet), &Packet_vtbl);
  p->link = link;
  p->identity = identity;
  p->kind = kind;
  p->datum = 0;
  for (int32_t i = 0; i < DATA_SIZE; i += 1) {
    p->data[i] = 0;
  }
  return p;
}

// RBObject::append
static Packet* append(Packet* packet, Packet* queue_head) {
  packet->link = NO_WORK;
  if (NO_WORK == queue_head) {
    return packet;
  }

  Packet* mouse = queue_head;
  Packet* link = NO_WORK;
  while (NO_WORK != (link = mouse->link)) {
    mouse = link;
  }
  mouse->link = packet;
  return queue_head;
}

// ---- TaskState

typedef struct TaskState {
  RBObject base;
  bool packet_pending;
  bool task_waiting;
  bool task_holding;
} TaskState;

static void TaskState_init(TaskState* self) {
  self->packet_pending = false;
  self->task_waiting = false;
  self->task_holding = false;
}

static void TaskState_packet_pending(TaskState* self) {
  self->packet_pending = true;
  self->task_waiting = false;
  self->task_holding = false;
}

static void TaskState_running(TaskState* self) {
  self->packet_pending = self->task_waiting = self->task_holding = false;
}

static void TaskState_waiting(TaskState* self) {
  self->packet_pending = self->task_holding = false;
  self->task_waiting = true;
}

static void TaskState_waiting_with_packet(TaskState* self) {
  self->task_holding = false;
  self->task_waiting = self->packet_pending = true;
}

static bool TaskState_is_task_holding_or_waiting(const TaskState* self) {
  return self->task_holding || (!self->packet_pending && self->task_waiting);
}

static bool TaskState_is_waiting_with_packet(const TaskState* self) {
  return self->packet_pending && self->task_waiting && !self->task_holding;
}

static TaskState* TaskState_new(void) {
  TaskState* t = (TaskState*)RBObject_new(sizeof(TaskState), &TaskState_vtbl);
  TaskState_init(t);
  return t;
}

static TaskState* TaskState_create_running(void) {
  TaskState* t = TaskState_new();
  TaskState_running(t);
  return t;
}

static TaskState* TaskState_create_waiting(void) {
  TaskState* t = TaskState_new();
  TaskState_waiting(t);
  return t;
}

static TaskState* TaskState_create_waiting_with_packet(void) {
  TaskState* t = TaskState_new();
  TaskState_waiting_with_packet(t);
  return t;
}

// ---- Task data records

typedef struct DeviceTaskDataRecord {
  RBObject base;
  Packet* pending;
} DeviceTaskDataRecord;

typedef struct HandlerTaskDataRecord {
  RBObject base;
  Packet* work_in;
  Packet* device_in;
} HandlerTaskDataRecord;

typedef struct IdleTaskDataRecord {
  RBObject base;
  int32_t control;
  int32_t count;
} IdleTaskDataRecord;

typedef struct WorkerTaskDataRecord {
  RBObject base;
  int32_t destination;
  int32_t count;
} WorkerTaskDataRecord;

// ---- TaskControlBlock

// The task's function: the C++ std::function holding a lambda that captures
// the Scheduler (`this`); in C, a function pointer and that context pointer.
typedef TaskControlBlock* (*TaskFn)(Scheduler* ctx, Packet* work,
                                    RBObject* word);

struct TaskControlBlock {
  TaskState base;
  TaskControlBlock* link;
  int32_t identity;
  int32_t priority;
  Packet* input;
  TaskFn function;
  Scheduler* function_ctx;
  RBObject* handle;
};

static TaskControlBlock* TaskControlBlock_new(TaskControlBlock* a_link,
                                              int32_t an_identity,
                                              int32_t a_priority,
                                              Packet* an_initial_work_queue,
                                              TaskState* an_initial_state,
                                              TaskFn a_block,
                                              Scheduler* a_block_ctx,
                                              RBObject* a_private_data) {
  TaskControlBlock* t = (TaskControlBlock*)RBObject_new(
      sizeof(TaskControlBlock), &TaskControlBlock_vtbl);
  TaskState_init(&t->base);
  t->link = a_link;
  t->identity = an_identity;
  t->priority = a_priority;
  t->input = an_initial_work_queue;
  t->function = a_block;
  t->function_ctx = a_block_ctx;
  t->handle = a_private_data;
  t->base.packet_pending = an_initial_state->packet_pending;
  t->base.task_waiting = an_initial_state->task_waiting;
  t->base.task_holding = an_initial_state->task_holding;
  return t;
}

static TaskControlBlock* TaskControlBlock_add_input_and_check_priority(
    TaskControlBlock* self, Packet* packet, TaskControlBlock* old_task) {
  if (NO_WORK == self->input) {
    self->input = packet;
    self->base.packet_pending = true;
    if (self->priority > old_task->priority) {
      return self;
    }
  } else {
    self->input = append(packet, self->input);
  }
  return old_task;
}

static TaskControlBlock* TaskControlBlock_run_task(TaskControlBlock* self) {
  Packet* message = NO_WORK;

  if (TaskState_is_waiting_with_packet(&self->base)) {
    message = self->input;
    self->input = message->link;
    if (NO_WORK == self->input) {
      TaskState_running(&self->base);
    } else {
      TaskState_packet_pending(&self->base);
    }
  } else {
    message = NO_WORK;
  }
  return self->function(self->function_ctx, message, self->handle);
}

// ---- Scheduler

struct Scheduler {
  RBObject base;
  TaskControlBlock* task_list;
  TaskControlBlock* current_task;
  int32_t current_task_identity;
  TaskControlBlock* task_table[NUM_TYPES];
  int32_t queue_packet_count;
  int32_t hold_count;
  int32_t layout;
};

static Scheduler* Scheduler_new(void) {
  Scheduler* s = (Scheduler*)RBObject_new(sizeof(Scheduler), &Scheduler_vtbl);
  s->task_list = NO_TASK;
  s->current_task = NO_TASK;
  s->current_task_identity = 0;
  for (int32_t i = 0; i < NUM_TYPES; i += 1) {
    s->task_table[i] = NO_TASK;
  }
  s->queue_packet_count = 0;
  s->hold_count = 0;
  s->layout = 0;
  return s;
}

static void Scheduler_trace(Scheduler* self, int32_t id) {
  self->layout = self->layout - 1;
  if (0 >= self->layout) {
    printf("\n");
    self->layout = 50;
  }
  printf("%d\n", id);
}

static TaskControlBlock* Scheduler_find_task(Scheduler* self,
                                             int32_t identity) {
  TaskControlBlock* t = self->task_table[identity];
  if (NO_TASK == t) {
    error("findTask failed");
  }
  return t;
}

static TaskControlBlock* Scheduler_hold_self(Scheduler* self) {
  self->hold_count = self->hold_count + 1;
  self->current_task->base.task_holding = true;
  return self->current_task->link;
}

static TaskControlBlock* Scheduler_queue_packet(Scheduler* self,
                                                Packet* packet) {
  TaskControlBlock* t = Scheduler_find_task(self, packet->identity);
  if (NO_TASK == t) {
    return NO_TASK;
  }

  self->queue_packet_count = self->queue_packet_count + 1;

  packet->link = NO_WORK;
  packet->identity = self->current_task_identity;
  return TaskControlBlock_add_input_and_check_priority(t, packet,
                                                       self->current_task);
}

static TaskControlBlock* Scheduler_release(Scheduler* self, int32_t identity) {
  TaskControlBlock* t = Scheduler_find_task(self, identity);
  if (NO_TASK == t) {
    return NO_TASK;
  }
  t->base.task_holding = false;
  if (t->priority > self->current_task->priority) {
    return t;
  }
  return self->current_task;
}

static TaskControlBlock* Scheduler_mark_waiting(Scheduler* self) {
  self->current_task->base.task_waiting = true;
  return self->current_task;
}

static void Scheduler_create_task(Scheduler* self, int32_t identity,
                                  int32_t priority, Packet* work,
                                  TaskState* state, TaskFn a_block,
                                  RBObject* data) {
  TaskControlBlock* t = TaskControlBlock_new(
      self->task_list, identity, priority, work, state, a_block, self, data);
  self->task_list = t;
  self->task_table[identity] = t;
}

static TaskControlBlock* device_fn(Scheduler* self, Packet* work_arg,
                                   RBObject* word_arg) {
  DeviceTaskDataRecord* data_record =
      DYNAMIC_CAST(DeviceTaskDataRecord, word_arg);
  Packet* function_work = work_arg;
  if (NO_WORK == function_work) {
    function_work = data_record->pending;
    if (NO_WORK == function_work) {
      return Scheduler_mark_waiting(self);
    }
    data_record->pending = NO_WORK;
    return Scheduler_queue_packet(self, function_work);
  }

  data_record->pending = function_work;
  if (TRACING) {
    Scheduler_trace(self, function_work->datum);
  }
  return Scheduler_hold_self(self);
}

static void Scheduler_create_device(Scheduler* self, int32_t identity,
                                    int32_t priority, Packet* work_packet,
                                    TaskState* state) {
  DeviceTaskDataRecord* data = (DeviceTaskDataRecord*)RBObject_new(
      sizeof(DeviceTaskDataRecord), &DeviceTaskDataRecord_vtbl);
  data->pending = NO_WORK;

  Scheduler_create_task(self, identity, priority, work_packet, state,
                        device_fn, &data->base);
}

static TaskControlBlock* handler_fn(Scheduler* self, Packet* work,
                                    RBObject* word) {
  HandlerTaskDataRecord* data_record =
      DYNAMIC_CAST(HandlerTaskDataRecord, word);
  if (NO_WORK != work) {
    if (WORK_PACKET_KIND == work->kind) {
      data_record->work_in = append(work, data_record->work_in);
    } else {
      data_record->device_in = append(work, data_record->device_in);
    }
  }

  Packet* work_packet = data_record->work_in;
  if (NO_WORK == work_packet) {
    return Scheduler_mark_waiting(self);
  }
  const int32_t count = work_packet->datum;
  if (count >= DATA_SIZE) {
    data_record->work_in = work_packet->link;
    return Scheduler_queue_packet(self, work_packet);
  }
  Packet* device_packet = data_record->device_in;
  if (NO_WORK == device_packet) {
    return Scheduler_mark_waiting(self);
  }
  data_record->device_in = device_packet->link;
  device_packet->datum = work_packet->data[count];
  work_packet->datum = count + 1;
  return Scheduler_queue_packet(self, device_packet);
}

static void Scheduler_create_handler(Scheduler* self, int32_t identity,
                                     int32_t priority, Packet* work_paket,
                                     TaskState* state) {
  HandlerTaskDataRecord* data = (HandlerTaskDataRecord*)RBObject_new(
      sizeof(HandlerTaskDataRecord), &HandlerTaskDataRecord_vtbl);
  data->work_in = NO_WORK;
  data->device_in = NO_WORK;

  Scheduler_create_task(self, identity, priority, work_paket, state,
                        handler_fn, &data->base);
}

static TaskControlBlock* idler_fn(Scheduler* self, Packet* work,
                                  RBObject* word_arg) {
  (void)work;
  IdleTaskDataRecord* data_record = DYNAMIC_CAST(IdleTaskDataRecord, word_arg);
  data_record->count = data_record->count - 1;
  if (0 == data_record->count) {
    return Scheduler_hold_self(self);
  }
  if (0 == (data_record->control & 1)) {
    data_record->control = data_record->control / 2;
    return Scheduler_release(self, DEVICE_A);
  }
  data_record->control = (data_record->control / 2) ^ 53256;
  return Scheduler_release(self, DEVICE_B);
}

static void Scheduler_create_idler(Scheduler* self, int32_t identity,
                                   int32_t priority, Packet* work,
                                   TaskState* state) {
  IdleTaskDataRecord* data = (IdleTaskDataRecord*)RBObject_new(
      sizeof(IdleTaskDataRecord), &IdleTaskDataRecord_vtbl);
  data->control = 1;
  data->count = 10000;

  Scheduler_create_task(self, identity, priority, work, state, idler_fn,
                        &data->base);
}

static TaskControlBlock* worker_fn(Scheduler* self, Packet* work,
                                   RBObject* word) {
  WorkerTaskDataRecord* data = DYNAMIC_CAST(WorkerTaskDataRecord, word);
  if (NO_WORK == work) {
    return Scheduler_mark_waiting(self);
  }
  data->destination = (HANDLER_A == data->destination) ? HANDLER_B : HANDLER_A;
  work->identity = data->destination;
  work->datum = 0;
  for (int32_t i = 0; i < DATA_SIZE; i += 1) {
    data->count = data->count + 1;
    if (data->count > 26) {
      data->count = 1;
    }
    work->data[i] = 65 + data->count - 1;
  }
  return Scheduler_queue_packet(self, work);
}

static void Scheduler_create_worker(Scheduler* self, int32_t identity,
                                    int32_t priority, Packet* work_paket,
                                    TaskState* state) {
  WorkerTaskDataRecord* data_record = (WorkerTaskDataRecord*)RBObject_new(
      sizeof(WorkerTaskDataRecord), &WorkerTaskDataRecord_vtbl);
  data_record->destination = HANDLER_A;
  data_record->count = 0;

  Scheduler_create_task(self, identity, priority, work_paket, state,
                        worker_fn, &data_record->base);
}

static void Scheduler_schedule(Scheduler* self) {
  self->current_task = self->task_list;
  while (NO_TASK != self->current_task) {
    if (TaskState_is_task_holding_or_waiting(&self->current_task->base)) {
      self->current_task = self->current_task->link;
    } else {
      self->current_task_identity = self->current_task->identity;
      if (TRACING) {
        Scheduler_trace(self, self->current_task_identity);
      }
      self->current_task = TaskControlBlock_run_task(self->current_task);
    }
  }
}

static bool Scheduler_start(Scheduler* self) {
  Packet* work_q = NO_WORK;
  Scheduler_create_idler(self, IDLER, 0, NO_WORK, TaskState_create_running());

  work_q = Packet_new(NO_WORK, WORKER, WORK_PACKET_KIND);
  work_q = Packet_new(work_q, WORKER, WORK_PACKET_KIND);
  Scheduler_create_worker(self, WORKER, 1000, work_q,
                          TaskState_create_waiting_with_packet());

  work_q = Packet_new(NO_WORK, DEVICE_A, DEVICE_PACKET_KIND);
  work_q = Packet_new(work_q, DEVICE_A, DEVICE_PACKET_KIND);
  work_q = Packet_new(work_q, DEVICE_A, DEVICE_PACKET_KIND);
  Scheduler_create_handler(self, HANDLER_A, 2000, work_q,
                           TaskState_create_waiting_with_packet());

  work_q = Packet_new(NO_WORK, DEVICE_B, DEVICE_PACKET_KIND);
  work_q = Packet_new(work_q, DEVICE_B, DEVICE_PACKET_KIND);
  work_q = Packet_new(work_q, DEVICE_B, DEVICE_PACKET_KIND);
  Scheduler_create_handler(self, HANDLER_B, 3000, work_q,
                           TaskState_create_waiting_with_packet());

  Scheduler_create_device(self, DEVICE_A, 4000, NO_WORK,
                          TaskState_create_waiting());
  Scheduler_create_device(self, DEVICE_B, 5000, NO_WORK,
                          TaskState_create_waiting());

  Scheduler_schedule(self);

  return self->queue_packet_count == 23246 && self->hold_count == 9297;
}

// ---- Richards

static Result Richards_benchmark(Benchmark* self) {
  (void)self;
  Scheduler* scheduler = Scheduler_new();
  const bool result = Scheduler_start(scheduler);

  ObjectTracker_release_all();
  return (Result){.b = result};
}

static bool Richards_verify_result(Benchmark* self, Result result) {
  (void)self;
  return result.b;
}

static const BenchmarkVtbl Richards_vtbl = {
    Benchmark_destroy, Richards_benchmark, Richards_verify_result,
    Benchmark_inner_benchmark_loop};

Benchmark* Richards_new(void) {
  return Benchmark_alloc(sizeof(Benchmark), &Richards_vtbl);
}
