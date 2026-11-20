//! som/set.h and som/identity_set.h: a set over a Vector, tested by linear search.
//!
//! `contains` compares with `==` for integers and with the element's `equal`
//! for objects, as the C++ does. In C++ IdentitySet declares its own
//! `contains` (pointer equality), but it hides rather than overrides
//! Set::contains, so `add`, the only caller, still uses `equal`. IdentitySet
//! is therefore this same type.

const Vector = @import("vector.zig").Vector;
const initial_size = @import("vector.zig").initial_size;

pub fn Set(comptime E: type) type {
    return struct {
        const Self = @This();

        items: Vector(E),

        pub fn init() Self {
            return .{ .items = .init(initial_size) };
        }

        pub fn deinit(self: *Self) void {
            self.items.deinit();
        }

        pub fn size(self: *const Self) usize {
            return self.items.size();
        }

        pub fn forEach(self: *const Self, context: anytype, comptime f: fn (@TypeOf(context), E) void) void {
            self.items.forEach(context, f);
        }

        pub fn hasSome(self: *const Self, context: anytype, comptime f: fn (@TypeOf(context), E) bool) bool {
            return self.items.hasSome(context, f);
        }

        pub fn add(self: *Self, obj: E) void {
            if (!self.contains(obj)) self.items.append(obj);
        }

        pub fn contains(self: *const Self, obj: E) bool {
            return self.hasSome(obj, struct {
                fn f(o: E, e: E) bool {
                    return if (E == i32) e == o else e.equal(o);
                }
            }.f);
        }

        pub fn removeAll(self: *Self) void {
            self.items.removeAll();
        }
    };
}

pub const IdentitySet = Set;
