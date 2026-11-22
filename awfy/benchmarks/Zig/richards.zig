//! richards.h and richards.cpp.
//!
//! Every object is created through the object tracker and freed by
//! `releaseAll` at the end of each benchmark call, as in C++.
//!
//! A task's function is a closure in C++ (a lambda capturing the scheduler,
//! held in a `std::function`). Here it is the same closure made explicit: the
//! captured scheduler plus a function pointer, called indirectly from
//! `runTask`. The task's private data record is the C++ `RBObject*`, an
//! `*anyopaque` here; each function casts it back to its record type, where
//! C++ uses `dynamic_cast`.

const mem = @import("mem.zig");
const ObjectTracker = mem.ObjectTracker;

const idler = 0;
const worker = 1;
const handler_a = 2;
const handler_b = 3;
const device_a = 4;
const device_b = 5;
const num_types = 6;

const device_packet_kind = 0;
const work_packet_kind = 1;

const no_work: ?*Packet = null;
const no_task: ?*TaskControlBlock = null;

/// RBObject::append.
fn append(packet: *Packet, queue_head: ?*Packet) *Packet {
    packet.link = no_work;
    const head = queue_head orelse return packet;

    var mouse = head;
    while (mouse.link) |link| mouse = link;
    mouse.link = packet;
    return head;
}

const TaskState = struct {
    packet_pending: bool = false,
    task_waiting: bool = false,
    task_holding: bool = false,

    fn packetPending(self: *TaskState) void {
        self.packet_pending = true;
        self.task_waiting = false;
        self.task_holding = false;
    }

    fn running(self: *TaskState) void {
        self.packet_pending = false;
        self.task_waiting = false;
        self.task_holding = false;
    }

    fn waiting(self: *TaskState) void {
        self.packet_pending = false;
        self.task_holding = false;
        self.task_waiting = true;
    }

    fn waitingWithPacket(self: *TaskState) void {
        self.task_holding = false;
        self.task_waiting = true;
        self.packet_pending = true;
    }

    fn isTaskHoldingOrWaiting(self: *const TaskState) bool {
        return self.task_holding or (!self.packet_pending and self.task_waiting);
    }

    fn isWaitingWithPacket(self: *const TaskState) bool {
        return self.packet_pending and self.task_waiting and !self.task_holding;
    }

    fn createRunning() *TaskState {
        const t = ObjectTracker.new(TaskState, .{});
        t.running();
        return t;
    }

    fn createWaiting() *TaskState {
        const t = ObjectTracker.new(TaskState, .{});
        t.waiting();
        return t;
    }

    fn createWaitingWithPacket() *TaskState {
        const t = ObjectTracker.new(TaskState, .{});
        t.waitingWithPacket();
        return t;
    }
};

const DeviceTaskDataRecord = struct {
    pending: ?*Packet = no_work,
};

const HandlerTaskDataRecord = struct {
    work_in: ?*Packet = no_work,
    device_in: ?*Packet = no_work,

    fn deviceInAdd(self: *HandlerTaskDataRecord, packet: *Packet) void {
        self.device_in = append(packet, self.device_in);
    }

    fn workInAdd(self: *HandlerTaskDataRecord, packet: *Packet) void {
        self.work_in = append(packet, self.work_in);
    }
};

const IdleTaskDataRecord = struct {
    control: i32 = 1,
    count: i32 = 10000,
};

const WorkerTaskDataRecord = struct {
    destination: i32 = handler_a,
    count: i32 = 0,
};

const Packet = struct {
    const data_size = 4;

    link: ?*Packet,
    identity: i32,
    kind: i32,
    datum: i32 = 0,
    data: [data_size]i32 = @splat(0),
};

/// The task's closure: what the C++ lambda captures (the scheduler) and its code.
const TaskFunction = struct {
    scheduler: *Scheduler,
    code: *const fn (*Scheduler, ?*Packet, *anyopaque) ?*TaskControlBlock,

    fn call(self: TaskFunction, work: ?*Packet, word: *anyopaque) ?*TaskControlBlock {
        return self.code(self.scheduler, work, word);
    }
};

const TaskControlBlock = struct {
    state: TaskState,
    link: ?*TaskControlBlock,
    identity: i32,
    priority: i32,
    input: ?*Packet,
    function: TaskFunction,
    handle: *anyopaque,

    fn addInputAndCheckPriority(self: *TaskControlBlock, packet: *Packet, old_task: *TaskControlBlock) *TaskControlBlock {
        if (no_work == self.input) {
            self.input = packet;
            self.state.packet_pending = true;
            if (self.priority > old_task.priority) return self;
        } else {
            self.input = append(packet, self.input);
        }
        return old_task;
    }

    fn runTask(self: *TaskControlBlock) ?*TaskControlBlock {
        var message: ?*Packet = no_work;

        if (self.state.isWaitingWithPacket()) {
            message = self.input;
            self.input = message.?.link;
            if (no_work == self.input) {
                self.state.running();
            } else {
                self.state.packetPending();
            }
        } else {
            message = no_work;
        }
        return self.function.call(message, self.handle);
    }
};

fn record(comptime T: type, word: *anyopaque) *T {
    return @ptrCast(@alignCast(word));
}

const Scheduler = struct {
    task_list: ?*TaskControlBlock = no_task,
    current_task: ?*TaskControlBlock = no_task,
    current_task_identity: i32 = 0,
    task_table: [num_types]?*TaskControlBlock = @splat(no_task),
    queue_packet_count: i32 = 0,
    hold_count: i32 = 0,

    fn createDevice(self: *Scheduler, identity: i32, priority: i32, work_packet: ?*Packet, state: *TaskState) void {
        const data = ObjectTracker.new(DeviceTaskDataRecord, .{});
        self.createTask(identity, priority, work_packet, state, deviceFunction, data);
    }

    fn deviceFunction(self: *Scheduler, work_arg: ?*Packet, word_arg: *anyopaque) ?*TaskControlBlock {
        const data_record = record(DeviceTaskDataRecord, word_arg);
        const function_work = work_arg orelse {
            const pending = data_record.pending orelse return self.markWaiting();
            data_record.pending = no_work;
            return self.queuePacket(pending);
        };
        data_record.pending = function_work;
        return self.holdSelf();
    }

    fn createHandler(self: *Scheduler, identity: i32, priority: i32, work_packet: ?*Packet, state: *TaskState) void {
        const data = ObjectTracker.new(HandlerTaskDataRecord, .{});
        self.createTask(identity, priority, work_packet, state, handlerFunction, data);
    }

    fn handlerFunction(self: *Scheduler, work: ?*Packet, word: *anyopaque) ?*TaskControlBlock {
        const data_record = record(HandlerTaskDataRecord, word);
        if (work) |w| {
            if (work_packet_kind == w.kind) {
                data_record.workInAdd(w);
            } else {
                data_record.deviceInAdd(w);
            }
        }

        const work_packet = data_record.work_in orelse return self.markWaiting();
        const count = work_packet.datum;
        if (count >= Packet.data_size) {
            data_record.work_in = work_packet.link;
            return self.queuePacket(work_packet);
        }
        const device_packet = data_record.device_in orelse return self.markWaiting();
        data_record.device_in = device_packet.link;
        device_packet.datum = work_packet.data[@intCast(count)];
        work_packet.datum = count + 1;
        return self.queuePacket(device_packet);
    }

    fn createIdler(self: *Scheduler, identity: i32, priority: i32, work: ?*Packet, state: *TaskState) void {
        const data = ObjectTracker.new(IdleTaskDataRecord, .{});
        self.createTask(identity, priority, work, state, idlerFunction, data);
    }

    fn idlerFunction(self: *Scheduler, _: ?*Packet, word_arg: *anyopaque) ?*TaskControlBlock {
        const data_record = record(IdleTaskDataRecord, word_arg);
        data_record.count = data_record.count - 1;
        if (0 == data_record.count) return self.holdSelf();
        if (0 == (data_record.control & 1)) {
            data_record.control = @divTrunc(data_record.control, 2);
            return self.release(device_a);
        }
        data_record.control = @divTrunc(data_record.control, 2) ^ 53256;
        return self.release(device_b);
    }

    fn createPacket(_: *Scheduler, link: ?*Packet, identity: i32, kind: i32) *Packet {
        return ObjectTracker.new(Packet, .{ .link = link, .identity = identity, .kind = kind });
    }

    fn createTask(
        self: *Scheduler,
        identity: i32,
        priority: i32,
        work: ?*Packet,
        state: *TaskState,
        code: *const fn (*Scheduler, ?*Packet, *anyopaque) ?*TaskControlBlock,
        data: *anyopaque,
    ) void {
        const t = ObjectTracker.new(TaskControlBlock, .{
            .state = .{
                .packet_pending = state.packet_pending,
                .task_waiting = state.task_waiting,
                .task_holding = state.task_holding,
            },
            .link = self.task_list,
            .identity = identity,
            .priority = priority,
            .input = work,
            .function = .{ .scheduler = self, .code = code },
            .handle = data,
        });
        self.task_list = t;
        self.task_table[@intCast(identity)] = t;
    }

    fn createWorker(self: *Scheduler, identity: i32, priority: i32, work_packet: ?*Packet, state: *TaskState) void {
        const data_record = ObjectTracker.new(WorkerTaskDataRecord, .{});
        self.createTask(identity, priority, work_packet, state, workerFunction, data_record);
    }

    fn workerFunction(self: *Scheduler, work_arg: ?*Packet, word: *anyopaque) ?*TaskControlBlock {
        const data = record(WorkerTaskDataRecord, word);
        const work = work_arg orelse return self.markWaiting();
        data.destination = if (handler_a == data.destination) handler_b else handler_a;
        work.identity = data.destination;
        work.datum = 0;
        for (&work.data) |*d| {
            data.count = data.count + 1;
            if (data.count > 26) data.count = 1;
            d.* = 65 + data.count - 1;
        }
        return self.queuePacket(work);
    }

    fn start(self: *Scheduler) bool {
        var work_q: ?*Packet = no_work;
        self.createIdler(idler, 0, no_work, TaskState.createRunning());

        work_q = self.createPacket(no_work, worker, work_packet_kind);
        work_q = self.createPacket(work_q, worker, work_packet_kind);
        self.createWorker(worker, 1000, work_q, TaskState.createWaitingWithPacket());

        work_q = self.createPacket(no_work, device_a, device_packet_kind);
        work_q = self.createPacket(work_q, device_a, device_packet_kind);
        work_q = self.createPacket(work_q, device_a, device_packet_kind);
        self.createHandler(handler_a, 2000, work_q, TaskState.createWaitingWithPacket());

        work_q = self.createPacket(no_work, device_b, device_packet_kind);
        work_q = self.createPacket(work_q, device_b, device_packet_kind);
        work_q = self.createPacket(work_q, device_b, device_packet_kind);
        self.createHandler(handler_b, 3000, work_q, TaskState.createWaitingWithPacket());

        self.createDevice(device_a, 4000, no_work, TaskState.createWaiting());
        self.createDevice(device_b, 5000, no_work, TaskState.createWaiting());

        self.schedule();

        return self.queue_packet_count == 23246 and self.hold_count == 9297;
    }

    fn findTask(self: *Scheduler, identity: i32) *TaskControlBlock {
        return self.task_table[@intCast(identity)] orelse @panic("findTask failed");
    }

    fn holdSelf(self: *Scheduler) ?*TaskControlBlock {
        self.hold_count = self.hold_count + 1;
        self.current_task.?.state.task_holding = true;
        return self.current_task.?.link;
    }

    fn queuePacket(self: *Scheduler, packet: *Packet) ?*TaskControlBlock {
        const t = self.findTask(packet.identity);
        self.queue_packet_count = self.queue_packet_count + 1;
        packet.link = no_work;
        packet.identity = self.current_task_identity;
        return t.addInputAndCheckPriority(packet, self.current_task.?);
    }

    fn release(self: *Scheduler, identity: i32) ?*TaskControlBlock {
        const t = self.findTask(identity);
        t.state.task_holding = false;
        if (t.priority > self.current_task.?.priority) return t;
        return self.current_task;
    }

    fn markWaiting(self: *Scheduler) ?*TaskControlBlock {
        self.current_task.?.state.task_waiting = true;
        return self.current_task;
    }

    fn schedule(self: *Scheduler) void {
        self.current_task = self.task_list;
        while (self.current_task) |current| {
            if (current.state.isTaskHoldingOrWaiting()) {
                self.current_task = current.link;
            } else {
                self.current_task_identity = current.identity;
                self.current_task = current.runTask();
            }
        }
    }
};

pub const Richards = struct {
    pub fn verifyResult(_: *Richards, result: bool) bool {
        return result;
    }

    pub fn benchmark(_: *Richards) bool {
        const scheduler = ObjectTracker.new(Scheduler, .{});
        const result = scheduler.start();

        ObjectTracker.releaseAll();
        return result;
    }
};
