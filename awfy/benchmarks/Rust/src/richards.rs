// Upstream C++ richards.h and richards.cpp. Every object C++ allocates (each an `RBObject`, so a
// `TrackedObject`) is allocated in an `ObjectTracker` and freed when `benchmark()` ends, as C++'s
// `ObjectTracker::releaseAll()` does (memory.rs). Pointers are `&'a` references, `NO_WORK` and
// `NO_TASK` are `None`, and mutable fields are `Cell`s.
//
// A task's function is a closure that captures the scheduler, as C++'s lambda captures `this`; it is
// allocated in the tracker like C++'s `std::function` target and called through `&dyn Fn`. It
// receives the task's data record as C++'s does (`RBObject* word`); C++ recovers the record's type
// with `dynamic_cast`, Rust by matching the record's enum.

use std::cell::Cell;

use crate::benchmark::Benchmark;
use crate::memory::ObjectTracker;

const IDLER: i32 = 0;
const WORKER: i32 = 1;
const HANDLER_A: i32 = 2;
const HANDLER_B: i32 = 3;
const DEVICE_A: i32 = 4;
const DEVICE_B: i32 = 5;
const NUM_TYPES: usize = 6;

const DEVICE_PACKET_KIND: i32 = 0;
const WORK_PACKET_KIND: i32 = 1;

const DATA_SIZE: usize = 4;

const TRACING: bool = false;

type PacketRef<'a> = Option<&'a Packet<'a>>;
type TaskRef<'a> = Option<&'a TaskControlBlock<'a>>;
type TaskFunction<'a> = &'a dyn Fn(PacketRef<'a>, &'a RBObject<'a>) -> TaskRef<'a>;

// C++ RBObject::append, which uses no state of its object.
fn append<'a>(packet: &'a Packet<'a>, queue_head: PacketRef<'a>) -> PacketRef<'a> {
    packet.set_link(None);
    let Some(head) = queue_head else {
        return Some(packet);
    };

    let mut mouse = head;
    while let Some(link) = mouse.get_link() {
        mouse = link;
    }
    mouse.set_link(Some(packet));
    Some(head)
}

/// The data records a task function receives: C++'s `RBObject*` subclasses that `dynamic_cast`
/// selects between.
enum RBObject<'a> {
    Device(DeviceTaskDataRecord<'a>),
    Handler(HandlerTaskDataRecord<'a>),
    Idle(IdleTaskDataRecord),
    Worker(WorkerTaskDataRecord),
}

#[derive(Default)]
struct TaskState {
    packet_pending: Cell<bool>,
    task_waiting: Cell<bool>,
    task_holding: Cell<bool>,
}

impl TaskState {
    fn is_packet_pending(&self) -> bool {
        self.packet_pending.get()
    }
    fn is_task_holding(&self) -> bool {
        self.task_holding.get()
    }
    fn is_task_waiting(&self) -> bool {
        self.task_waiting.get()
    }
    fn set_task_holding(&self, b: bool) {
        self.task_holding.set(b);
    }
    fn set_task_waiting(&self, b: bool) {
        self.task_waiting.set(b);
    }
    fn set_packet_pending(&self, b: bool) {
        self.packet_pending.set(b);
    }

    fn packet_pending(&self) {
        self.packet_pending.set(true);
        self.task_waiting.set(false);
        self.task_holding.set(false);
    }

    fn running(&self) {
        self.packet_pending.set(false);
        self.task_waiting.set(false);
        self.task_holding.set(false);
    }

    fn waiting(&self) {
        self.packet_pending.set(false);
        self.task_holding.set(false);
        self.task_waiting.set(true);
    }

    fn waiting_with_packet(&self) {
        self.task_holding.set(false);
        self.task_waiting.set(true);
        self.packet_pending.set(true);
    }

    fn is_task_holding_or_waiting(&self) -> bool {
        self.task_holding.get() || (!self.packet_pending.get() && self.task_waiting.get())
    }

    fn is_waiting_with_packet(&self) -> bool {
        self.packet_pending.get() && self.task_waiting.get() && !self.task_holding.get()
    }

    fn create_running(tracker: &ObjectTracker) -> &TaskState {
        let t = tracker.track(TaskState::default());
        t.running();
        t
    }

    fn create_waiting(tracker: &ObjectTracker) -> &TaskState {
        let t = tracker.track(TaskState::default());
        t.waiting();
        t
    }

    fn create_waiting_with_packet(tracker: &ObjectTracker) -> &TaskState {
        let t = tracker.track(TaskState::default());
        t.waiting_with_packet();
        t
    }
}

struct DeviceTaskDataRecord<'a> {
    pending: Cell<PacketRef<'a>>,
}

impl<'a> DeviceTaskDataRecord<'a> {
    fn new() -> Self {
        DeviceTaskDataRecord { pending: Cell::new(None) }
    }
    fn get_pending(&self) -> PacketRef<'a> {
        self.pending.get()
    }
    fn set_pending(&self, packet: PacketRef<'a>) {
        self.pending.set(packet);
    }
}

struct HandlerTaskDataRecord<'a> {
    work_in: Cell<PacketRef<'a>>,
    device_in: Cell<PacketRef<'a>>,
}

impl<'a> HandlerTaskDataRecord<'a> {
    fn new() -> Self {
        HandlerTaskDataRecord { work_in: Cell::new(None), device_in: Cell::new(None) }
    }
    fn device_in(&self) -> PacketRef<'a> {
        self.device_in.get()
    }
    fn set_device_in(&self, a_packet: PacketRef<'a>) {
        self.device_in.set(a_packet);
    }
    fn device_in_add(&self, packet: &'a Packet<'a>) {
        self.device_in.set(append(packet, self.device_in.get()));
    }
    fn work_in(&self) -> PacketRef<'a> {
        self.work_in.get()
    }
    fn set_work_in(&self, a_work_queue: PacketRef<'a>) {
        self.work_in.set(a_work_queue);
    }
    fn work_in_add(&self, packet: &'a Packet<'a>) {
        self.work_in.set(append(packet, self.work_in.get()));
    }
}

struct IdleTaskDataRecord {
    control: Cell<i32>,
    count: Cell<i32>,
}

impl IdleTaskDataRecord {
    fn new() -> Self {
        IdleTaskDataRecord { control: Cell::new(1), count: Cell::new(10000) }
    }
    fn get_control(&self) -> i32 {
        self.control.get()
    }
    fn set_control(&self, a_number: i32) {
        self.control.set(a_number);
    }
    fn get_count(&self) -> i32 {
        self.count.get()
    }
    fn set_count(&self, a_count: i32) {
        self.count.set(a_count);
    }
}

struct Packet<'a> {
    link: Cell<PacketRef<'a>>,
    identity: Cell<i32>,
    kind: i32,
    datum: Cell<i32>,
    data: [Cell<i32>; DATA_SIZE],
}

impl<'a> Packet<'a> {
    fn new(link: PacketRef<'a>, identity: i32, kind: i32) -> Self {
        Packet {
            link: Cell::new(link),
            identity: Cell::new(identity),
            kind,
            datum: Cell::new(0),
            data: Default::default(),
        }
    }

    fn get_data(&self) -> &[Cell<i32>; DATA_SIZE] {
        &self.data
    }
    fn get_datum(&self) -> i32 {
        self.datum.get()
    }
    fn set_datum(&self, some_data: i32) {
        self.datum.set(some_data);
    }
    fn get_identity(&self) -> i32 {
        self.identity.get()
    }
    fn set_identity(&self, an_identity: i32) {
        self.identity.set(an_identity);
    }
    fn get_kind(&self) -> i32 {
        self.kind
    }
    fn get_link(&self) -> PacketRef<'a> {
        self.link.get()
    }
    fn set_link(&self, a_link: PacketRef<'a>) {
        self.link.set(a_link);
    }
}

struct TaskControlBlock<'a> {
    state: TaskState,
    link: TaskRef<'a>,
    identity: i32,
    priority: i32,
    input: Cell<PacketRef<'a>>,
    function: TaskFunction<'a>,
    handle: &'a RBObject<'a>,
}

impl<'a> TaskControlBlock<'a> {
    fn new(
        a_link: TaskRef<'a>,
        an_identity: i32,
        a_priority: i32,
        an_initial_work_queue: PacketRef<'a>,
        an_initial_state: &TaskState,
        a_block: TaskFunction<'a>,
        a_private_data: &'a RBObject<'a>,
    ) -> Self {
        let t = TaskControlBlock {
            state: TaskState::default(),
            link: a_link,
            identity: an_identity,
            priority: a_priority,
            input: Cell::new(an_initial_work_queue),
            function: a_block,
            handle: a_private_data,
        };
        t.state.set_packet_pending(an_initial_state.is_packet_pending());
        t.state.set_task_waiting(an_initial_state.is_task_waiting());
        t.state.set_task_holding(an_initial_state.is_task_holding());
        t
    }

    fn get_identity(&self) -> i32 {
        self.identity
    }
    fn get_link(&self) -> TaskRef<'a> {
        self.link
    }
    fn get_priority(&self) -> i32 {
        self.priority
    }

    fn add_input_and_check_priority(&'a self, packet: &'a Packet<'a>, old_task: &'a TaskControlBlock<'a>) -> TaskRef<'a> {
        if self.input.get().is_none() {
            self.input.set(Some(packet));
            self.state.set_packet_pending(true);
            if self.priority > old_task.get_priority() {
                return Some(self);
            }
        } else {
            self.input.set(append(packet, self.input.get()));
        }
        Some(old_task)
    }

    fn run_task(&self) -> TaskRef<'a> {
        let message;

        if self.state.is_waiting_with_packet() {
            let input = self.input.get().unwrap();
            message = Some(input);
            self.input.set(input.get_link());
            if self.input.get().is_none() {
                self.state.running();
            } else {
                self.state.packet_pending();
            }
        } else {
            message = None;
        }
        (self.function)(message, self.handle)
    }
}

struct WorkerTaskDataRecord {
    destination: Cell<i32>,
    count: Cell<i32>,
}

impl WorkerTaskDataRecord {
    fn new() -> Self {
        WorkerTaskDataRecord { destination: Cell::new(HANDLER_A), count: Cell::new(0) }
    }
    fn get_count(&self) -> i32 {
        self.count.get()
    }
    fn set_count(&self, a_count: i32) {
        self.count.set(a_count);
    }
    fn get_destination(&self) -> i32 {
        self.destination.get()
    }
    fn set_destination(&self, a_handler: i32) {
        self.destination.set(a_handler);
    }
}

struct Scheduler<'a> {
    tracker: &'a ObjectTracker,
    task_list: Cell<TaskRef<'a>>,
    current_task: Cell<TaskRef<'a>>,
    current_task_identity: Cell<i32>,
    task_table: [Cell<TaskRef<'a>>; NUM_TYPES],
    queue_packet_count: Cell<i32>,
    hold_count: Cell<i32>,
    layout: Cell<i32>,
}

impl<'a> Scheduler<'a> {
    fn new(tracker: &'a ObjectTracker) -> Self {
        Scheduler {
            tracker,
            task_list: Cell::new(None),
            current_task: Cell::new(None),
            current_task_identity: Cell::new(0),
            task_table: Default::default(),
            queue_packet_count: Cell::new(0),
            hold_count: Cell::new(0),
            layout: Cell::new(0),
        }
    }

    fn current(&self) -> &'a TaskControlBlock<'a> {
        self.current_task.get().unwrap()
    }

    fn create_device(&'a self, identity: i32, priority: i32, work_packet: PacketRef<'a>, state: &TaskState) {
        let data = self.tracker.track(RBObject::Device(DeviceTaskDataRecord::new()));

        self.create_task(
            identity,
            priority,
            work_packet,
            state,
            self.tracker.track(move |work_arg: PacketRef<'a>, word_arg: &'a RBObject<'a>| -> TaskRef<'a> {
                let RBObject::Device(data_record) = word_arg else { unreachable!() };
                let Some(function_work) = work_arg else {
                    let Some(function_work) = data_record.get_pending() else {
                        return self.mark_waiting();
                    };
                    data_record.set_pending(None);
                    return self.queue_packet(function_work);
                };

                data_record.set_pending(Some(function_work));
                if TRACING {
                    self.trace(function_work.get_datum());
                }
                self.hold_self()
            }),
            data,
        );
    }

    fn create_handler(&'a self, identity: i32, priority: i32, work_paket: PacketRef<'a>, state: &TaskState) {
        let data = self.tracker.track(RBObject::Handler(HandlerTaskDataRecord::new()));

        self.create_task(
            identity,
            priority,
            work_paket,
            state,
            self.tracker.track(move |work: PacketRef<'a>, word: &'a RBObject<'a>| -> TaskRef<'a> {
                let RBObject::Handler(data_record) = word else { unreachable!() };
                if let Some(work) = work {
                    if WORK_PACKET_KIND == work.get_kind() {
                        data_record.work_in_add(work);
                    } else {
                        data_record.device_in_add(work);
                    }
                }

                let Some(work_packet) = data_record.work_in() else {
                    return self.mark_waiting();
                };
                let count = work_packet.get_datum();
                if count >= DATA_SIZE as i32 {
                    data_record.set_work_in(work_packet.get_link());
                    return self.queue_packet(work_packet);
                }
                let Some(device_packet) = data_record.device_in() else {
                    return self.mark_waiting();
                };
                data_record.set_device_in(device_packet.get_link());
                device_packet.set_datum(work_packet.get_data()[count as usize].get());
                work_packet.set_datum(count + 1);
                self.queue_packet(device_packet)
            }),
            data,
        );
    }

    fn create_idler(&'a self, identity: i32, priority: i32, work: PacketRef<'a>, state: &TaskState) {
        let data = self.tracker.track(RBObject::Idle(IdleTaskDataRecord::new()));

        self.create_task(
            identity,
            priority,
            work,
            state,
            self.tracker.track(move |_: PacketRef<'a>, word_arg: &'a RBObject<'a>| -> TaskRef<'a> {
                let RBObject::Idle(data_record) = word_arg else { unreachable!() };
                data_record.set_count(data_record.get_count() - 1);
                if 0 == data_record.get_count() {
                    return self.hold_self();
                }
                if 0 == (data_record.get_control() & 1) {
                    data_record.set_control(data_record.get_control() / 2);
                    return self.release(DEVICE_A);
                }
                data_record.set_control((data_record.get_control() / 2) ^ 53256);
                self.release(DEVICE_B)
            }),
            data,
        );
    }

    fn create_packet(&self, link: PacketRef<'a>, identity: i32, kind: i32) -> &'a Packet<'a> {
        self.tracker.track(Packet::new(link, identity, kind))
    }

    fn create_task(
        &self,
        identity: i32,
        priority: i32,
        work: PacketRef<'a>,
        state: &TaskState,
        a_block: TaskFunction<'a>,
        data: &'a RBObject<'a>,
    ) {
        let t = self.tracker.track(TaskControlBlock::new(self.task_list.get(), identity, priority, work, state, a_block, data));
        self.task_list.set(Some(t));
        self.task_table[identity as usize].set(Some(t));
    }

    fn create_worker(&'a self, identity: i32, priority: i32, work_paket: PacketRef<'a>, state: &TaskState) {
        let data_record = self.tracker.track(RBObject::Worker(WorkerTaskDataRecord::new()));

        self.create_task(
            identity,
            priority,
            work_paket,
            state,
            self.tracker.track(move |work: PacketRef<'a>, word: &'a RBObject<'a>| -> TaskRef<'a> {
                let RBObject::Worker(data) = word else { unreachable!() };
                let Some(work) = work else {
                    return self.mark_waiting();
                };
                data.set_destination(if HANDLER_A == data.get_destination() { HANDLER_B } else { HANDLER_A });
                work.set_identity(data.get_destination());
                work.set_datum(0);
                for i in 0..DATA_SIZE {
                    data.set_count(data.get_count() + 1);
                    if data.get_count() > 26 {
                        data.set_count(1);
                    }
                    work.get_data()[i].set(65 + data.get_count() - 1);
                }
                self.queue_packet(work)
            }),
            data_record,
        );
    }

    fn start(&'a self) -> bool {
        let mut work_q: PacketRef<'a>;
        self.create_idler(IDLER, 0, None, TaskState::create_running(self.tracker));

        work_q = Some(self.create_packet(None, WORKER, WORK_PACKET_KIND));
        work_q = Some(self.create_packet(work_q, WORKER, WORK_PACKET_KIND));
        self.create_worker(WORKER, 1000, work_q, TaskState::create_waiting_with_packet(self.tracker));

        work_q = Some(self.create_packet(None, DEVICE_A, DEVICE_PACKET_KIND));
        work_q = Some(self.create_packet(work_q, DEVICE_A, DEVICE_PACKET_KIND));
        work_q = Some(self.create_packet(work_q, DEVICE_A, DEVICE_PACKET_KIND));
        self.create_handler(HANDLER_A, 2000, work_q, TaskState::create_waiting_with_packet(self.tracker));

        work_q = Some(self.create_packet(None, DEVICE_B, DEVICE_PACKET_KIND));
        work_q = Some(self.create_packet(work_q, DEVICE_B, DEVICE_PACKET_KIND));
        work_q = Some(self.create_packet(work_q, DEVICE_B, DEVICE_PACKET_KIND));
        self.create_handler(HANDLER_B, 3000, work_q, TaskState::create_waiting_with_packet(self.tracker));

        self.create_device(DEVICE_A, 4000, None, TaskState::create_waiting(self.tracker));
        self.create_device(DEVICE_B, 5000, None, TaskState::create_waiting(self.tracker));

        self.schedule();

        self.queue_packet_count.get() == 23246 && self.hold_count.get() == 9297
    }

    fn find_task(&self, identity: i32) -> &'a TaskControlBlock<'a> {
        let Some(t) = self.task_table[identity as usize].get() else {
            panic!("findTask failed");
        };
        t
    }

    fn hold_self(&self) -> TaskRef<'a> {
        self.hold_count.set(self.hold_count.get() + 1);
        self.current().state.set_task_holding(true);
        self.current().get_link()
    }

    fn queue_packet(&self, packet: &'a Packet<'a>) -> TaskRef<'a> {
        let t = self.find_task(packet.get_identity());

        self.queue_packet_count.set(self.queue_packet_count.get() + 1);

        packet.set_link(None);
        packet.set_identity(self.current_task_identity.get());
        t.add_input_and_check_priority(packet, self.current())
    }

    fn release(&self, identity: i32) -> TaskRef<'a> {
        let t = self.find_task(identity);
        t.state.set_task_holding(false);
        if t.get_priority() > self.current().get_priority() {
            return Some(t);
        }
        self.current_task.get()
    }

    fn trace(&self, id: i32) {
        self.layout.set(self.layout.get() - 1);
        if 0 >= self.layout.get() {
            println!();
            self.layout.set(50);
        }
        println!("{id}");
    }

    fn mark_waiting(&self) -> TaskRef<'a> {
        self.current().state.set_task_waiting(true);
        self.current_task.get()
    }

    fn schedule(&self) {
        self.current_task.set(self.task_list.get());
        while let Some(current_task) = self.current_task.get() {
            if current_task.state.is_task_holding_or_waiting() {
                self.current_task.set(current_task.get_link());
            } else {
                self.current_task_identity.set(current_task.get_identity());
                if TRACING {
                    self.trace(self.current_task_identity.get());
                }
                self.current_task.set(current_task.run_task());
            }
        }
    }
}

pub struct Richards;

impl Benchmark for Richards {
    type Result = bool;

    fn verify_result(&mut self, result: bool) -> bool {
        result
    }

    fn benchmark(&mut self) -> bool {
        let tracker = ObjectTracker::new();
        let scheduler = tracker.track(Scheduler::new(&tracker));
        let result = scheduler.start();

        drop(tracker);
        result
    }
}
