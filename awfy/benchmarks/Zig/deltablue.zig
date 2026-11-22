//! deltablue.h and deltablue.cpp.
//!
//! The constraint class hierarchy keeps C++'s dynamic dispatch, as the
//! standard library's interface pattern: AbstractConstraint carries a pointer
//! to a table of functions (C++'s vtable), and each implementation recovers
//! its own type with `@fieldParentPtr`. UnaryConstraint's two subclasses
//! (EditConstraint, StayConstraint) and BinaryConstraint's EqualityConstraint
//! add no fields, so each is its parent struct with its own table;
//! ScaleConstraint embeds BinaryConstraint and adds two fields.
//!
//! `inputsDo` and `inputsHasOne` take a closure (C++ `std::function`), here a
//! context pointer plus a function pointer, since a virtual function cannot be
//! generic over its argument.
//!
//! Variables and constraints are created through the object tracker and freed
//! by `releaseAll`, as in C++. An exception the C++ throws (and nothing
//! catches) is a panic.

const std = @import("std");
const mem = @import("mem.zig");
const ObjectTracker = mem.ObjectTracker;
const Vector = @import("som/vector.zig").Vector;
const IdentityDictionary = @import("som/dictionary.zig").IdentityDictionary;
const initial_capacity = @import("som/dictionary.zig").initial_capacity;

const Direction = enum { forward, backward, none };

const Sym = struct {
    hash: u32,

    pub fn customHash(self: *const Sym) u32 {
        return self.hash;
    }
};

const Strength = struct {
    const absolute_strongest: Sym = .{ .hash = 0 };
    const required_sym: Sym = .{ .hash = 1 };
    const strong_preferred: Sym = .{ .hash = 2 };
    const preferred: Sym = .{ .hash = 3 };
    const strong_default: Sym = .{ .hash = 4 };
    const default: Sym = .{ .hash = 5 };
    const weak_default: Sym = .{ .hash = 6 };
    const absolute_weakest_sym: Sym = .{ .hash = 7 };

    var strength_table: *IdentityDictionary(Sym, i32) = undefined;
    var strength_constant: *IdentityDictionary(Sym, *const Strength) = undefined;
    var absolute_weakest_strength: ?*const Strength = null;
    var required_strength: ?*const Strength = null;

    arithmetic_value: i32,
    symbolic_value: *const Sym,

    fn init(symbolic_value: *const Sym) Strength {
        return .{ .arithmetic_value = strength_table.at(symbolic_value).?.*, .symbolic_value = symbolic_value };
    }

    fn sameAs(self: *const Strength, s: *const Strength) bool {
        return self.arithmetic_value == s.arithmetic_value;
    }

    fn stronger(self: *const Strength, s: *const Strength) bool {
        return self.arithmetic_value < s.arithmetic_value;
    }

    fn weaker(self: *const Strength, s: *const Strength) bool {
        return self.arithmetic_value > s.arithmetic_value;
    }

    fn strongest(self: *const Strength, s: *const Strength) *const Strength {
        return if (s.stronger(self)) s else self;
    }

    fn weakest(self: *const Strength, s: *const Strength) *const Strength {
        return if (s.weaker(self)) s else self;
    }

    fn of(strength: *const Sym) *const Strength {
        return strength_constant.at(strength).?.*;
    }

    fn absoluteWeakest() *const Strength {
        return absolute_weakest_strength.?;
    }

    fn required() *const Strength {
        return required_strength.?;
    }

    fn createStrengthTable() *IdentityDictionary(Sym, i32) {
        const table = mem.create(IdentityDictionary(Sym, i32), .init(initial_capacity));
        table.atPut(&absolute_strongest, -10000);
        table.atPut(&required_sym, -800);
        table.atPut(&strong_preferred, -600);
        table.atPut(&preferred, -400);
        table.atPut(&strong_default, -200);
        table.atPut(&default, 0);
        table.atPut(&weak_default, 500);
        table.atPut(&absolute_weakest_sym, 10000);
        return table;
    }

    fn createStrengthConstants() *IdentityDictionary(Sym, *const Strength) {
        const constants = mem.create(IdentityDictionary(Sym, *const Strength), .init(initial_capacity));
        const keys = strength_table.getKeys();
        keys.forEach(constants, struct {
            fn f(c: *IdentityDictionary(Sym, *const Strength), key: *const Sym) void {
                c.atPut(key, mem.create(Strength, .init(key)));
            }
        }.f);
        keys.destroy();
        return constants;
    }

    fn initializeConstants() void {
        strength_table = createStrengthTable();
        strength_constant = createStrengthConstants();
        absolute_weakest_strength = of(&absolute_weakest_sym);
        required_strength = of(&required_sym);
    }

    fn releaseStrengthConstants() void {
        strength_constant.destroyValues();
        strength_constant.deinit();
        mem.destroy(strength_constant);
    }

    fn releaseConstants() void {
        strength_table.deinit();
        mem.destroy(strength_table);
        releaseStrengthConstants();
        absolute_weakest_strength = null;
        required_strength = null;
    }
};

/// A C++ lambda passed as `std::function<void(Variable*)>`.
const VariableFn = struct {
    context: *anyopaque,
    call: *const fn (*anyopaque, *Variable) void,
};

/// A C++ lambda passed as `std::function<bool(Variable*)>`.
const VariablePredicate = struct {
    context: *anyopaque,
    call: *const fn (*anyopaque, *Variable) bool,
};

const AbstractConstraint = struct {
    vtable: *const VTable,
    strength: *const Strength,
    planner: ?*Planner = null,

    const VTable = struct {
        isInput: *const fn (*AbstractConstraint) bool,
        isSatisfied: *const fn (*AbstractConstraint) bool,
        addToGraph: *const fn (*AbstractConstraint) void,
        removeFromGraph: *const fn (*AbstractConstraint) void,
        chooseMethod: *const fn (*AbstractConstraint, i32) Direction,
        execute: *const fn (*AbstractConstraint) void,
        inputsDo: *const fn (*AbstractConstraint, VariableFn) void,
        inputsHasOne: *const fn (*AbstractConstraint, VariablePredicate) bool,
        markUnsatisfied: *const fn (*AbstractConstraint) void,
        getOutput: *const fn (*AbstractConstraint) *Variable,
        recalculate: *const fn (*AbstractConstraint) void,
    };

    fn init(vtable: *const VTable, strength: *const Sym) AbstractConstraint {
        return .{ .vtable = vtable, .strength = Strength.of(strength) };
    }

    fn isInput(self: *AbstractConstraint) bool {
        return self.vtable.isInput(self);
    }
    fn isSatisfied(self: *AbstractConstraint) bool {
        return self.vtable.isSatisfied(self);
    }
    fn addToGraph(self: *AbstractConstraint) void {
        self.vtable.addToGraph(self);
    }
    fn removeFromGraph(self: *AbstractConstraint) void {
        self.vtable.removeFromGraph(self);
    }
    fn chooseMethod(self: *AbstractConstraint, mark: i32) Direction {
        return self.vtable.chooseMethod(self, mark);
    }
    fn execute(self: *AbstractConstraint) void {
        self.vtable.execute(self);
    }
    fn inputsDo(self: *AbstractConstraint, f: VariableFn) void {
        self.vtable.inputsDo(self, f);
    }
    fn inputsHasOne(self: *AbstractConstraint, f: VariablePredicate) bool {
        return self.vtable.inputsHasOne(self, f);
    }
    fn markUnsatisfied(self: *AbstractConstraint) void {
        self.vtable.markUnsatisfied(self);
    }
    fn getOutput(self: *AbstractConstraint) *Variable {
        return self.vtable.getOutput(self);
    }
    fn recalculate(self: *AbstractConstraint) void {
        self.vtable.recalculate(self);
    }

    fn addConstraint(self: *AbstractConstraint, planner: *Planner) void {
        self.addToGraph();
        planner.incrementalAdd(self);
    }

    fn destroyConstraint(self: *AbstractConstraint, planner: *Planner) void {
        if (self.isSatisfied()) planner.incrementalRemove(self);
        self.removeFromGraph();
    }

    fn inputsKnown(self: *AbstractConstraint, mark: i32) bool {
        var m = mark;
        return !self.inputsHasOne(.{ .context = &m, .call = struct {
            fn f(ctx: *anyopaque, v: *Variable) bool {
                const mk: *const i32 = @ptrCast(@alignCast(ctx));
                return !(v.mark == mk.* or v.stay or v.determined_by == null);
            }
        }.f });
    }

    fn satisfy(self: *AbstractConstraint, mark: i32, planner: *Planner) ?*AbstractConstraint {
        var overridden: ?*AbstractConstraint = null;

        _ = self.chooseMethod(mark);

        if (self.isSatisfied()) {
            var m = mark;
            self.inputsDo(.{ .context = &m, .call = struct {
                fn f(ctx: *anyopaque, in: *Variable) void {
                    const mk: *const i32 = @ptrCast(@alignCast(ctx));
                    in.mark = mk.*;
                }
            }.f });

            const out = self.getOutput();
            overridden = out.determined_by;
            if (overridden) |o| o.markUnsatisfied();
            out.determined_by = self;
            if (!planner.addPropagate(self, mark)) @panic("Cycle encountered");
            out.mark = mark;
        } else {
            overridden = null;
            if (self.strength.sameAs(Strength.required())) @panic("Could not satisfy a required constraint");
        }
        return overridden;
    }
};

const Variable = struct {
    value: i32 = 0,
    constraints: *Vector(*AbstractConstraint),
    determined_by: ?*AbstractConstraint = null,
    mark: i32 = 0,
    walk_strength: *const Strength,
    stay: bool = true,

    fn new() *Variable {
        return ObjectTracker.new(Variable, .{
            .constraints = mem.create(Vector(*AbstractConstraint), .init(2)),
            .walk_strength = Strength.absoluteWeakest(),
        });
    }

    pub fn deinit(self: *Variable) void {
        self.constraints.destroy();
    }

    fn valueOf(a_value: i32) *Variable {
        const v = new();
        v.value = a_value;
        return v;
    }

    fn addConstraint(self: *Variable, c: *AbstractConstraint) void {
        self.constraints.append(c);
    }

    fn removeConstraint(self: *Variable, c: *AbstractConstraint) void {
        _ = self.constraints.remove(c);
        if (self.determined_by == c) self.determined_by = null;
    }
};

const BinaryConstraint = struct {
    base: AbstractConstraint,
    v1: *Variable,
    v2: *Variable,
    direction: Direction = .none,

    fn of(c: *AbstractConstraint) *BinaryConstraint {
        return @fieldParentPtr("base", c);
    }

    fn init(vtable: *const AbstractConstraint.VTable, var1: *Variable, var2: *Variable, strength: *const Sym) BinaryConstraint {
        return .{ .base = .init(vtable, strength), .v1 = var1, .v2 = var2 };
    }

    fn isInput(_: *AbstractConstraint) bool {
        return false;
    }

    fn isSatisfied(c: *AbstractConstraint) bool {
        return of(c).direction != .none;
    }

    fn addToGraph(c: *AbstractConstraint) void {
        const self = of(c);
        self.v1.addConstraint(c);
        self.v2.addConstraint(c);
        self.direction = .none;
    }

    fn removeFromGraph(c: *AbstractConstraint) void {
        const self = of(c);
        self.v1.removeConstraint(c);
        self.v2.removeConstraint(c);
        self.direction = .none;
    }

    fn chooseMethod(c: *AbstractConstraint, mark: i32) Direction {
        const self = of(c);
        const strength = self.base.strength;
        if (self.v1.mark == mark) {
            if (self.v2.mark != mark and strength.stronger(self.v2.walk_strength)) {
                self.direction = .forward;
                return self.direction;
            }
            self.direction = .none;
            return self.direction;
        }

        if (self.v2.mark == mark) {
            if (self.v1.mark != mark and strength.stronger(self.v1.walk_strength)) {
                self.direction = .backward;
                return self.direction;
            }
            self.direction = .none;
            return self.direction;
        }

        if (self.v1.walk_strength.weaker(self.v2.walk_strength)) {
            if (strength.stronger(self.v1.walk_strength)) {
                self.direction = .backward;
                return self.direction;
            }
            self.direction = .none;
            return self.direction;
        }

        if (strength.stronger(self.v2.walk_strength)) {
            self.direction = .forward;
            return self.direction;
        }

        self.direction = .none;
        return self.direction;
    }

    fn inputsDo(c: *AbstractConstraint, f: VariableFn) void {
        const self = of(c);
        if (self.direction == .forward) {
            f.call(f.context, self.v1);
        } else {
            f.call(f.context, self.v2);
        }
    }

    fn inputsHasOne(c: *AbstractConstraint, f: VariablePredicate) bool {
        const self = of(c);
        if (self.direction == .forward) return f.call(f.context, self.v1);
        return f.call(f.context, self.v2);
    }

    fn markUnsatisfied(c: *AbstractConstraint) void {
        of(c).direction = .none;
    }

    fn getOutput(c: *AbstractConstraint) *Variable {
        const self = of(c);
        return if (self.direction == .forward) self.v2 else self.v1;
    }

    fn recalculate(c: *AbstractConstraint) void {
        const self = of(c);
        var in: *Variable = undefined;
        var out: *Variable = undefined;

        if (self.direction == .forward) {
            in = self.v1;
            out = self.v2;
        } else {
            in = self.v2;
            out = self.v1;
        }

        out.walk_strength = self.base.strength.weakest(in.walk_strength);
        out.stay = in.stay;
        if (out.stay) c.execute();
    }
};

const UnaryConstraint = struct {
    base: AbstractConstraint,
    output: *Variable,
    satisfied: bool = false,

    fn of(c: *AbstractConstraint) *UnaryConstraint {
        return @fieldParentPtr("base", c);
    }

    fn init(vtable: *const AbstractConstraint.VTable, v: *Variable, strength: *const Sym) UnaryConstraint {
        return .{ .base = .init(vtable, strength), .output = v };
    }

    fn isInput(_: *AbstractConstraint) bool {
        return false;
    }

    fn isSatisfied(c: *AbstractConstraint) bool {
        return of(c).satisfied;
    }

    fn addToGraph(c: *AbstractConstraint) void {
        const self = of(c);
        self.output.addConstraint(c);
        self.satisfied = false;
    }

    fn removeFromGraph(c: *AbstractConstraint) void {
        const self = of(c);
        self.output.removeConstraint(c);
        self.satisfied = false;
    }

    fn chooseMethod(c: *AbstractConstraint, mark: i32) Direction {
        const self = of(c);
        self.satisfied = (self.output.mark != mark) and self.base.strength.stronger(self.output.walk_strength);
        return .none;
    }

    fn inputsDo(_: *AbstractConstraint, _: VariableFn) void {}

    fn inputsHasOne(_: *AbstractConstraint, _: VariablePredicate) bool {
        return false;
    }

    fn markUnsatisfied(c: *AbstractConstraint) void {
        of(c).satisfied = false;
    }

    fn getOutput(c: *AbstractConstraint) *Variable {
        return of(c).output;
    }

    fn recalculate(c: *AbstractConstraint) void {
        const self = of(c);
        self.output.walk_strength = self.base.strength;
        self.output.stay = !c.isInput();
        if (self.output.stay) c.execute();
    }
};

/// UnaryConstraint's table with `isInput` and `execute` replaced.
fn unaryVTable(comptime is_input: fn (*AbstractConstraint) bool, comptime execute: fn (*AbstractConstraint) void) AbstractConstraint.VTable {
    return .{
        .isInput = is_input,
        .isSatisfied = UnaryConstraint.isSatisfied,
        .addToGraph = UnaryConstraint.addToGraph,
        .removeFromGraph = UnaryConstraint.removeFromGraph,
        .chooseMethod = UnaryConstraint.chooseMethod,
        .execute = execute,
        .inputsDo = UnaryConstraint.inputsDo,
        .inputsHasOne = UnaryConstraint.inputsHasOne,
        .markUnsatisfied = UnaryConstraint.markUnsatisfied,
        .getOutput = UnaryConstraint.getOutput,
        .recalculate = UnaryConstraint.recalculate,
    };
}

const EditConstraint = struct {
    const vtable = unaryVTable(isInput, execute);

    fn new(v: *Variable, strength: *const Sym, planner: *Planner) *AbstractConstraint {
        const c = ObjectTracker.new(UnaryConstraint, .init(&vtable, v, strength));
        c.base.addConstraint(planner);
        return &c.base;
    }

    fn isInput(_: *AbstractConstraint) bool {
        return true;
    }

    fn execute(_: *AbstractConstraint) void {
        // Edit constraints do nothing.
    }
};

const StayConstraint = struct {
    const vtable = unaryVTable(UnaryConstraint.isInput, execute);

    fn new(v: *Variable, strength: *const Sym, planner: *Planner) *AbstractConstraint {
        const c = ObjectTracker.new(UnaryConstraint, .init(&vtable, v, strength));
        c.base.addConstraint(planner);
        return &c.base;
    }

    fn execute(_: *AbstractConstraint) void {
        // StayConstraints do nothing.
    }
};

const EqualityConstraint = struct {
    const vtable: AbstractConstraint.VTable = .{
        .isInput = BinaryConstraint.isInput,
        .isSatisfied = BinaryConstraint.isSatisfied,
        .addToGraph = BinaryConstraint.addToGraph,
        .removeFromGraph = BinaryConstraint.removeFromGraph,
        .chooseMethod = BinaryConstraint.chooseMethod,
        .execute = execute,
        .inputsDo = BinaryConstraint.inputsDo,
        .inputsHasOne = BinaryConstraint.inputsHasOne,
        .markUnsatisfied = BinaryConstraint.markUnsatisfied,
        .getOutput = BinaryConstraint.getOutput,
        .recalculate = BinaryConstraint.recalculate,
    };

    fn new(var1: *Variable, var2: *Variable, strength: *const Sym, planner: *Planner) *AbstractConstraint {
        const c = ObjectTracker.new(BinaryConstraint, .init(&vtable, var1, var2, strength));
        c.base.addConstraint(planner);
        return &c.base;
    }

    fn execute(c: *AbstractConstraint) void {
        const self = BinaryConstraint.of(c);
        if (self.direction == .forward) {
            self.v2.value = self.v1.value;
        } else {
            self.v1.value = self.v2.value;
        }
    }
};

/// Plan: a Vector of constraints with `execute`.
const Plan = struct {
    vector: Vector(*AbstractConstraint),

    fn new() *Plan {
        return mem.create(Plan, .{ .vector = .init(15) });
    }

    fn destroy(self: *Plan) void {
        self.vector.deinit();
        mem.destroy(self);
    }

    fn execute(self: *Plan) void {
        self.vector.forEach({}, struct {
            fn f(_: void, c: *AbstractConstraint) void {
                c.execute();
            }
        }.f);
    }
};

const ScaleConstraint = struct {
    binary: BinaryConstraint,
    scale: *Variable,
    offset: *Variable,

    const vtable: AbstractConstraint.VTable = .{
        .isInput = BinaryConstraint.isInput,
        .isSatisfied = BinaryConstraint.isSatisfied,
        .addToGraph = addToGraph,
        .removeFromGraph = removeFromGraph,
        .chooseMethod = BinaryConstraint.chooseMethod,
        .execute = execute,
        .inputsDo = inputsDo,
        .inputsHasOne = BinaryConstraint.inputsHasOne,
        .markUnsatisfied = BinaryConstraint.markUnsatisfied,
        .getOutput = BinaryConstraint.getOutput,
        .recalculate = recalculate,
    };

    fn of(c: *AbstractConstraint) *ScaleConstraint {
        return @fieldParentPtr("binary", BinaryConstraint.of(c));
    }

    fn new(src: *Variable, scale: *Variable, offset: *Variable, dest: *Variable, strength: *const Sym, planner: *Planner) *AbstractConstraint {
        const c = ObjectTracker.new(ScaleConstraint, .{
            .binary = .init(&vtable, src, dest, strength),
            .scale = scale,
            .offset = offset,
        });
        c.binary.base.addConstraint(planner);
        return &c.binary.base;
    }

    fn addToGraph(c: *AbstractConstraint) void {
        const self = of(c);
        self.binary.v1.addConstraint(c);
        self.binary.v2.addConstraint(c);
        self.scale.addConstraint(c);
        self.offset.addConstraint(c);
        self.binary.direction = .none;
    }

    fn removeFromGraph(c: *AbstractConstraint) void {
        const self = of(c);
        self.binary.v1.removeConstraint(c);
        self.binary.v2.removeConstraint(c);
        self.scale.removeConstraint(c);
        self.offset.removeConstraint(c);
        self.binary.direction = .none;
    }

    fn execute(c: *AbstractConstraint) void {
        const self = of(c);
        const b = &self.binary;
        if (b.direction == .forward) {
            b.v2.value = b.v1.value * self.scale.value + self.offset.value;
        } else {
            b.v1.value = @divTrunc(b.v2.value - self.offset.value, self.scale.value);
        }
    }

    fn inputsDo(c: *AbstractConstraint, f: VariableFn) void {
        const self = of(c);
        if (self.binary.direction == .forward) {
            f.call(f.context, self.binary.v1);
            f.call(f.context, self.scale);
            f.call(f.context, self.offset);
        } else {
            f.call(f.context, self.binary.v2);
            f.call(f.context, self.scale);
            f.call(f.context, self.offset);
        }
    }

    fn recalculate(c: *AbstractConstraint) void {
        const self = of(c);
        var in: *Variable = undefined;
        var out: *Variable = undefined;

        if (self.binary.direction == .forward) {
            in = self.binary.v1;
            out = self.binary.v2;
        } else {
            out = self.binary.v1;
            in = self.binary.v2;
        }

        out.walk_strength = self.binary.base.strength.weakest(in.walk_strength);
        out.stay = in.stay and self.scale.stay and self.offset.stay;
        if (out.stay) c.execute(); // stay optimization
    }
};

const Planner = struct {
    current_mark: i32 = 1,

    fn incrementalAdd(self: *Planner, c: *AbstractConstraint) void {
        const mark = self.newMark();
        var overridden = c.satisfy(mark, self);
        while (overridden) |o| overridden = o.satisfy(mark, self);
    }

    fn incrementalRemove(self: *Planner, c: *AbstractConstraint) void {
        const out = c.getOutput();
        c.markUnsatisfied();
        c.removeFromGraph();

        const unsatisfied = self.removePropagateFrom(out);
        unsatisfied.forEach(self, struct {
            fn f(planner: *Planner, u: *AbstractConstraint) void {
                planner.incrementalAdd(u);
            }
        }.f);
        unsatisfied.destroy();
    }

    fn extractPlanFromConstraints(self: *Planner, constraints: *Vector(*AbstractConstraint)) *Plan {
        var sources: Vector(*AbstractConstraint) = .init(0);
        defer sources.deinit();
        constraints.forEach(&sources, struct {
            fn f(s: *Vector(*AbstractConstraint), c: *AbstractConstraint) void {
                if (c.isInput() and c.isSatisfied()) s.append(c);
            }
        }.f);
        return self.makePlan(&sources);
    }

    fn makePlan(self: *Planner, sources: *Vector(*AbstractConstraint)) *Plan {
        const mark = self.newMark();
        const plan = Plan.new();
        const todo = sources;

        while (!todo.isEmpty()) {
            const c = todo.removeFirst().?;
            if (c.getOutput().mark != mark and c.inputsKnown(mark)) {
                plan.vector.append(c);
                c.getOutput().mark = mark;
                self.addConstraintsConsumingTo(c.getOutput(), todo);
            }
        }
        return plan;
    }

    fn addConstraintsConsumingTo(_: *Planner, v: *Variable, coll: *Vector(*AbstractConstraint)) void {
        const Context = struct { coll: *Vector(*AbstractConstraint), determining_c: ?*AbstractConstraint };
        v.constraints.forEach(Context{ .coll = coll, .determining_c = v.determined_by }, struct {
            fn f(ctx: Context, c: *AbstractConstraint) void {
                if (c != ctx.determining_c and c.isSatisfied()) ctx.coll.append(c);
            }
        }.f);
    }

    fn addPropagate(self: *Planner, c: *AbstractConstraint, mark: i32) bool {
        const todo = Vector(*AbstractConstraint).with(c);

        while (!todo.isEmpty()) {
            const d = todo.removeFirst().?;

            if (d.getOutput().mark == mark) {
                self.incrementalRemove(c);
                todo.destroy();
                return false;
            }

            d.recalculate();
            self.addConstraintsConsumingTo(d.getOutput(), todo);
        }

        todo.destroy();
        return true;
    }

    fn change(self: *Planner, v: *Variable, new_value: i32) void {
        const edit_c = EditConstraint.new(v, &Strength.preferred, self);
        const edit_v = Vector(*AbstractConstraint).with(edit_c);
        const plan = self.extractPlanFromConstraints(edit_v);

        var i: i32 = 0;
        while (i < 10) : (i += 1) {
            v.value = new_value;
            plan.execute();
        }

        edit_c.destroyConstraint(self);
        plan.destroy();
        edit_v.destroy();
    }

    fn constraintsConsuming(_: *Planner, v: *Variable, context: anytype, comptime f: fn (@TypeOf(context), *AbstractConstraint) void) void {
        const Context = struct { inner: @TypeOf(context), determining_c: ?*AbstractConstraint };
        v.constraints.forEach(Context{ .inner = context, .determining_c = v.determined_by }, struct {
            fn each(ctx: Context, c: *AbstractConstraint) void {
                if (c != ctx.determining_c and c.isSatisfied()) f(ctx.inner, c);
            }
        }.each);
    }

    fn newMark(self: *Planner) i32 {
        self.current_mark += 1;
        return self.current_mark;
    }

    fn removePropagateFrom(self: *Planner, out: *Variable) *Vector(*AbstractConstraint) {
        const unsatisfied = mem.create(Vector(*AbstractConstraint), .init(0));

        out.determined_by = null;
        out.walk_strength = Strength.absoluteWeakest();
        out.stay = true;

        var todo = Vector(*Variable).with(out);

        while (!todo.isEmpty()) {
            const v = todo.removeFirst().?;

            v.constraints.forEach(unsatisfied, struct {
                fn f(u: *Vector(*AbstractConstraint), c: *AbstractConstraint) void {
                    if (!c.isSatisfied()) u.append(c);
                }
            }.f);

            self.constraintsConsuming(v, &todo, struct {
                fn f(t: **Vector(*Variable), c: *AbstractConstraint) void {
                    c.recalculate();
                    t.*.append(c.getOutput());
                }
            }.f);
        }
        todo.destroy();

        unsatisfied.sort({}, struct {
            fn f(_: void, c1: *AbstractConstraint, c2: *AbstractConstraint) i32 {
                return if (c1.strength.stronger(c2.strength)) -1 else 1;
            }
        }.f);

        return unsatisfied;
    }

    fn chainTest(n: i32) void {
        Strength.initializeConstants();
        var planner: Planner = .{};
        const count: usize = @intCast(n + 1);
        const vars = mem.alloc(*Variable, count);
        for (vars) |*v| v.* = Variable.new();
        var i: usize = 0;
        while (i < count - 1) : (i += 1) {
            const v1 = vars[i];
            const v2 = vars[i + 1];
            _ = EqualityConstraint.new(v1, v2, &Strength.required_sym, &planner);
        }
        _ = StayConstraint.new(vars[count - 1], &Strength.strong_default, &planner);

        const edit_c = EditConstraint.new(vars[0], &Strength.preferred, &planner);
        const edit_v = Vector(*AbstractConstraint).with(edit_c);
        const plan = planner.extractPlanFromConstraints(edit_v);
        edit_v.destroy();

        var j: i32 = 0;
        while (j < 100) : (j += 1) {
            vars[0].value = j;
            plan.execute();
            if (vars[count - 1].value != j) @panic("Chain test failed!");
        }
        edit_c.destroyConstraint(&planner);
        plan.destroy();
        mem.free(vars);
        ObjectTracker.releaseAll();
    }

    fn projectionTest(n: i32) void {
        var planner: Planner = .{};
        var dests: Vector(*Variable) = .init(0);
        defer dests.deinit();

        const scale = Variable.valueOf(10);
        const offset = Variable.valueOf(1000);

        var src: *Variable = undefined;
        var dst: *Variable = undefined;
        var i: i32 = 1;
        while (i <= n) : (i += 1) {
            src = Variable.valueOf(i);
            dst = Variable.valueOf(i);
            dests.append(dst);
            _ = StayConstraint.new(src, &Strength.default, &planner);
            _ = ScaleConstraint.new(src, scale, offset, dst, &Strength.required_sym, &planner);
        }

        planner.change(src, 17);
        if (dst.value != 1170) @panic("Projection test 1 failed!");

        planner.change(dst, 1050);
        if (src.value != 5) @panic("Projection test 2 failed!");

        planner.change(scale, 5);
        var k: i32 = 0;
        while (k < n - 1) : (k += 1) {
            const di = dests.at(@intCast(k)).?.*;
            if (di.value != (k + 1) * 5 + 1000) @panic("Projection test 3 failed!");
        }

        planner.change(offset, 2000);
        k = 0;
        while (k < n - 1) : (k += 1) {
            const di = dests.at(@intCast(k)).?.*;
            if (di.value != (k + 1) * 5 + 2000) @panic("Projection test 4 failed!");
        }
        ObjectTracker.releaseAll();
        Strength.releaseConstants();
    }
};

pub const DeltaBlue = struct {
    pub fn innerBenchmarkLoop(_: *DeltaBlue, inner_iterations: i32) bool {
        Planner.chainTest(inner_iterations);
        Planner.projectionTest(inner_iterations);
        return true;
    }
};
