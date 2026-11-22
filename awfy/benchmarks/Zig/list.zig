//! list.h. Each list is freed through its own links (the C++ Element
//! destructor deletes `next`). The element value is an `i32`; C++ holds it
//! in a `std::any`, upstream's Java in an `Object`.

const mem = @import("mem.zig");

const Element = struct {
    val: i32,
    next: ?*Element = null,

    fn create(v: i32) *Element {
        return mem.create(Element, .{ .val = v });
    }

    /// `delete e`, with the destructor's recursive `delete next`.
    fn destroy(self: *Element) void {
        if (self.next) |next| next.destroy();
        mem.destroy(self);
    }

    fn length(self: *const Element) i32 {
        const next = self.next orelse return 1;
        return 1 + next.length();
    }
};

pub const List = struct {
    pub fn benchmark(self: *List) i32 {
        const x = self.makeList(15);
        const y = self.makeList(10);
        const z = self.makeList(6);

        const result = self.tail(x, y, z);
        const l = result.?.length();

        x.?.destroy();
        y.?.destroy();
        z.?.destroy();
        return l;
    }

    fn makeList(self: *List, length: i32) ?*Element {
        if (length == 0) return null;
        const e = Element.create(length);
        e.next = self.makeList(length - 1);
        return e;
    }

    fn isShorterThan(_: *List, x: ?*Element, y: ?*Element) bool {
        var x_tail = x;
        var y_tail = y;
        while (y_tail) |yt| {
            const xt = x_tail orelse return true;
            x_tail = xt.next;
            y_tail = yt.next;
        }
        return false;
    }

    fn tail(self: *List, x: ?*Element, y: ?*Element, z: ?*Element) ?*Element {
        if (self.isShorterThan(y, x)) {
            return self.tail(
                self.tail(x.?.next, y, z),
                self.tail(y.?.next, z, x),
                self.tail(z.?.next, x, y),
            );
        }
        return z;
    }

    pub fn verifyResult(_: *List, result: i32) bool {
        return 10 == result;
    }
};
