//! cd.h. Value objects for vectors, motions and aircraft, as in C++; the
//! red-black trees free their nodes from the root, and the voxel map's motion
//! vectors are freed explicitly, including the ones not passed on.

const std = @import("std");
const mem = @import("mem.zig");
const Vector = @import("som/vector.zig").Vector;

const Vector2D = struct {
    x: f64,
    y: f64,

    fn compareNumbers(a: f64, b: f64) i32 {
        if (a == b) return 0;
        if (a < b) return -1;
        if (a > b) return 1;

        // We say that NaN is smaller than non-NaN.
        if (a == a) return 1;
        return -1;
    }

    fn plus(self: Vector2D, other: Vector2D) Vector2D {
        return .{ .x = self.x + other.x, .y = self.y + other.y };
    }

    fn minus(self: Vector2D, other: Vector2D) Vector2D {
        return .{ .x = self.x - other.x, .y = self.y - other.y };
    }

    fn compareTo(self: Vector2D, other: Vector2D) i32 {
        const result = compareNumbers(self.x, other.x);
        if (result != 0) return result;
        return compareNumbers(self.y, other.y);
    }
};

const Vector3D = struct {
    x: f64,
    y: f64,
    z: f64,

    fn plus(self: Vector3D, other: Vector3D) Vector3D {
        return .{ .x = self.x + other.x, .y = self.y + other.y, .z = self.z + other.z };
    }

    fn minus(self: Vector3D, other: Vector3D) Vector3D {
        return .{ .x = self.x - other.x, .y = self.y - other.y, .z = self.z - other.z };
    }

    fn dot(self: Vector3D, other: Vector3D) f64 {
        return self.x * other.x + self.y * other.y + self.z * other.z;
    }

    fn squaredMagnitude(self: Vector3D) f64 {
        return self.dot(self);
    }

    fn magnitude(self: Vector3D) f64 {
        return @sqrt(self.squaredMagnitude());
    }

    fn times(self: Vector3D, amount: f64) Vector3D {
        return .{ .x = self.x * amount, .y = self.y * amount, .z = self.z * amount };
    }
};

fn RedBlackTree(comptime K: type, comptime V: type) type {
    return struct {
        const Self = @This();

        const Color = enum { red, black };

        const Node = struct {
            key: K,
            value: V,
            left: ?*Node = null,
            right: ?*Node = null,
            parent: ?*Node = null,
            color: Color = .red,

            fn successor(self: *Node) ?*Node {
                var x = self;
                if (x.right) |right| return treeMinimum(right);
                var y = x.parent;
                while (y) |yy| {
                    if (x != yy.right) break;
                    x = yy;
                    y = yy.parent;
                }
                return y;
            }

            /// `delete node`, with the destructor's `delete _left; delete _right`.
            fn destroy(self: *Node) void {
                if (self.left) |left| left.destroy();
                if (self.right) |right| right.destroy();
                mem.destroy(self);
            }
        };

        const InsertResult = struct {
            is_new_entry: bool,
            new_node: ?*Node,
            old_value: V,
        };

        pub const Entry = struct {
            key: K,
            value: V,
        };

        root: ?*Node = null,

        fn deinit(self: *Self) void {
            if (self.root) |root| root.destroy();
        }

        fn treeMinimum(x: *Node) *Node {
            var current = x;
            while (current.left) |left| current = left;
            return current;
        }

        fn treeInsert(self: *Self, key: K, value: V) InsertResult {
            var y: ?*Node = null;
            var x = self.root;

            while (x) |xx| {
                y = xx;
                const comparison_result = key.compareTo(xx.key);
                if (comparison_result < 0) {
                    x = xx.left;
                } else if (comparison_result > 0) {
                    x = xx.right;
                } else {
                    const old_value = xx.value;
                    xx.value = value;
                    return .{ .is_new_entry = false, .new_node = null, .old_value = old_value };
                }
            }

            const z = mem.create(Node, .{ .key = key, .value = value });
            z.parent = y;
            if (y) |yy| {
                if (key.compareTo(yy.key) < 0) {
                    yy.left = z;
                } else {
                    yy.right = z;
                }
            } else {
                self.root = z;
            }
            return .{ .is_new_entry = true, .new_node = z, .old_value = undefined };
        }

        fn leftRotate(self: *Self, x: *Node) *Node {
            const y = x.right.?;

            // Turn y's left subtree into x's right subtree.
            x.right = y.left;
            if (y.left) |yl| yl.parent = x;

            // Link x's parent to y
            y.parent = x.parent;
            if (x.parent) |xp| {
                if (x == xp.left) {
                    xp.left = y;
                } else {
                    xp.right = y;
                }
            } else {
                self.root = y;
            }

            // Put x on y's left.
            y.left = x;
            x.parent = y;

            return y;
        }

        fn rightRotate(self: *Self, y: *Node) *Node {
            const x = y.left.?;

            // Turn x's right subtree into y's left subtree.
            y.left = x.right;
            if (x.right) |xr| xr.parent = y;

            // Link y's parent to x;
            x.parent = y.parent;
            if (y.parent) |yp| {
                if (y == yp.left) {
                    yp.left = x;
                } else {
                    yp.right = x;
                }
            } else {
                self.root = x;
            }

            x.right = y;
            y.parent = x;

            return x;
        }

        fn isBlack(n: ?*Node) bool {
            return n == null or n.?.color == .black;
        }

        fn removeFixup(self: *Self, x_arg: ?*Node, x_parent_arg: ?*Node) void {
            var x = x_arg;
            var x_parent = x_parent_arg;
            while (x != self.root and isBlack(x)) {
                const xp = x_parent.?;
                if (x == xp.left) {
                    // Note: the text points out that w cannot be null. The reason is not
                    // obvious from simply looking at the code; it comes about from the
                    // properties of the red-black tree.
                    var w = xp.right.?;
                    if (w.color == .red) {
                        // Case 1
                        w.color = .black;
                        xp.color = .red;
                        _ = self.leftRotate(xp);
                        w = xp.right.?;
                    }
                    if (isBlack(w.left) and isBlack(w.right)) {
                        // Case 2
                        w.color = .red;
                        x = xp;
                        x_parent = xp.parent;
                    } else {
                        if (isBlack(w.right)) {
                            // Case 3
                            w.left.?.color = .black;
                            w.color = .red;
                            _ = self.rightRotate(w);
                            w = xp.right.?;
                        }
                        // Case 4
                        w.color = xp.color;
                        xp.color = .black;
                        if (w.right) |wr| wr.color = .black;
                        _ = self.leftRotate(xp);
                        x = self.root;
                        x_parent = x.?.parent;
                    }
                } else {
                    // Same as "then" clause with "right" and "left" exchanged.
                    var w = xp.left.?;
                    if (w.color == .red) {
                        // Case 1
                        w.color = .black;
                        xp.color = .red;
                        _ = self.rightRotate(xp);
                        w = xp.left.?;
                    }
                    if (isBlack(w.right) and isBlack(w.left)) {
                        // Case 2
                        w.color = .red;
                        x = xp;
                        x_parent = xp.parent;
                    } else {
                        if (isBlack(w.left)) {
                            // Case 3
                            w.right.?.color = .black;
                            w.color = .red;
                            _ = self.leftRotate(w);
                            w = xp.left.?;
                        }
                        // Case 4
                        w.color = xp.color;
                        xp.color = .black;
                        if (w.left) |wl| wl.color = .black;
                        _ = self.rightRotate(xp);
                        x = self.root;
                        x_parent = x.?.parent;
                    }
                }
            }
            if (x) |xx| xx.color = .black;
        }

        fn put(self: *Self, key: K, value: V) ?V {
            const insertion_result = self.treeInsert(key, value);
            if (!insertion_result.is_new_entry) return insertion_result.old_value;

            var x = insertion_result.new_node.?;

            while (x != self.root and x.parent.?.color == .red) {
                const xp = x.parent.?;
                const xpp = xp.parent.?;
                if (xp == xpp.left) {
                    const y = xpp.right;
                    if (y != null and y.?.color == .red) {
                        // Case 1
                        xp.color = .black;
                        y.?.color = .black;
                        xpp.color = .red;
                        x = xpp;
                    } else {
                        if (x == xp.right) {
                            // Case 2
                            x = xp;
                            _ = self.leftRotate(x);
                        }
                        // Case 3
                        x.parent.?.color = .black;
                        x.parent.?.parent.?.color = .red;
                        _ = self.rightRotate(x.parent.?.parent.?);
                    }
                } else {
                    // Same as "then" clause with "right" and "left" exchanged.
                    const y = xpp.left;
                    if (y != null and y.?.color == .red) {
                        // Case 1
                        xp.color = .black;
                        y.?.color = .black;
                        xpp.color = .red;
                        x = xpp;
                    } else {
                        if (x == xp.left) {
                            // Case 2
                            x = xp;
                            _ = self.rightRotate(x);
                        }
                        // Case 3
                        x.parent.?.color = .black;
                        x.parent.?.parent.?.color = .red;
                        _ = self.leftRotate(x.parent.?.parent.?);
                    }
                }
            }
            self.root.?.color = .black;
            return null;
        }

        /// As in C++, the unlinked node is not freed (and its links are kept).
        fn remove(self: *Self, key: K) ?V {
            const z = self.findNode(key) orelse return null;

            // Y is the node to be unlinked from the tree.
            const y = if (z.left == null or z.right == null) z else z.successor().?;

            // Y is guaranteed to be non-null at this point.
            const x = if (y.left != null) y.left else y.right;
            // X is the child of y which might potentially replace y in the tree. X
            // might be null at this point.
            var x_parent: ?*Node = null;
            if (x) |xx| {
                xx.parent = y.parent;
                x_parent = xx.parent;
            } else {
                x_parent = y.parent;
            }
            if (y.parent) |yp| {
                if (y == yp.left) {
                    yp.left = x;
                } else {
                    yp.right = x;
                }
            } else {
                self.root = x;
            }

            if (y != z) {
                if (y.color == .black) self.removeFixup(x, x_parent);

                y.parent = z.parent;
                y.color = z.color;
                y.left = z.left;
                y.right = z.right;

                if (z.left) |zl| zl.parent = y;
                if (z.right) |zr| zr.parent = y;
                if (z.parent) |zp| {
                    if (zp.left == z) {
                        zp.left = y;
                    } else {
                        zp.right = y;
                    }
                } else {
                    self.root = y;
                }
            } else if (y.color == .black) {
                self.removeFixup(x, x_parent);
            }

            return z.value;
        }

        fn get(self: *Self, key: K) ?*V {
            const node = self.findNode(key) orelse return null;
            return &node.value;
        }

        fn forEach(self: *Self, context: anytype, comptime f: fn (@TypeOf(context), Entry) void) void {
            const root = self.root orelse return;
            var current: ?*Node = treeMinimum(root);
            while (current) |node| {
                f(context, .{ .key = node.key, .value = node.value });
                current = node.successor();
            }
        }

        fn findNode(self: *Self, key: K) ?*Node {
            var current = self.root;
            while (current) |node| {
                const comparison_result = key.compareTo(node.key);
                if (comparison_result == 0) return node;
                if (comparison_result < 0) {
                    current = node.left;
                } else {
                    current = node.right;
                }
            }
            return null;
        }
    };
}

const CallSign = struct {
    value: i32,

    fn compareTo(self: CallSign, other: CallSign) i32 {
        return if (self.value == other.value) 0 else if (self.value < other.value) -1 else 1;
    }
};

const Collision = struct {
    aircraft_a: CallSign,
    aircraft_b: CallSign,
    position: Vector3D,
};

const min_x = 0.0;
const min_y = 0.0;
const max_x = 1000.0;
const max_y = 1000.0;
const min_z = 0.0;
const max_z = 10.0;
const proximity_radius = 1.0;
const good_voxel_size = proximity_radius * 2.0;

const Motion = struct {
    callsign: CallSign,
    pos_one: Vector3D,
    pos_two: Vector3D,

    fn delta(self: *const Motion) Vector3D {
        return self.pos_two.minus(self.pos_one);
    }

    fn findIntersection(self: *const Motion, other: *const Motion) ?Vector3D {
        const init1 = self.pos_one;
        const init2 = other.pos_one;
        const vec1 = self.delta();
        const vec2 = other.delta();
        const radius = proximity_radius;

        // this test is not geometrical 3-d intersection test, it takes the fact
        // that the aircraft move into account ; so it is more like a 4d test (it
        // assumes that both of the aircraft have a constant speed over the tested
        // interval)

        // we thus have two points, each of them moving on its line segment at
        // constant speed ; we are looking for times when the distance between these
        // two points is smaller than r

        // vec1 is vector of aircraft 1
        // vec2 is vector of aircraft 2

        // a = (V2 - V1)^T * (V2 - V1)
        const a = vec2.minus(vec1).squaredMagnitude();

        if (a != 0.0) {
            // we are first looking for instances of time when the planes are exactly
            // r from each other at least one plane is moving ; if the planes are
            // moving in parallel, they do not have constant speed

            // if the planes are moving in parallel, then
            //   if the faster starts behind the slower, we can have 2, 1, or 0
            //   solutions if the faster plane starts in front of the slower, we can
            //   have 0 or 1 solutions

            // if the planes are not moving in parallel, then

            // point P1 = I1 + vV1
            // point P2 = I2 + vV2
            //   - looking for v, such that dist(P1,P2) = || P1 - P2 || = r

            // it follows that || P1 - P2 || = sqrt( < P1-P2, P1-P2 > )
            //   0 = -r^2 + < P1 - P2, P1 - P2 >
            //  from properties of dot product
            //   0 = -r^2 + <I1-I2,I1-I2> + v * 2<I1-I2, V1-V2> + v^2 *<V1-V2,V1-V2>
            //   so we calculate a, b, c - and solve the quadratic equation
            //   0 = c + bv + av^2

            // b = 2 * <I1-I2, V1-V2>
            const b = 2.0 * init1.minus(init2).dot(vec1.minus(vec2));

            // c = -r^2 + (I2 - I1)^T * (I2 - I1)
            const c = -radius * radius + init2.minus(init1).squaredMagnitude();

            const discr = b * b - 4.0 * a * c;
            if (discr < 0.0) return null;

            const v1 = (-b - @sqrt(discr)) / (2.0 * a);
            const v2 = (-b + @sqrt(discr)) / (2.0 * a);

            if (v1 <= v2 and ((v1 <= 1.0 and 1.0 <= v2) or (v1 <= 0.0 and 0.0 <= v2) or
                (0.0 <= v1 and v2 <= 1.0)))
            {
                // Pick a good "time" at which to report the collision.
                var v: f64 = 0.0;
                if (v1 <= 0.0) {
                    // The collision started before this frame. Report it at the start of
                    // the frame.
                    v = 0.0;
                } else {
                    // The collision started during this frame. Report it at that moment.
                    v = v1;
                }

                const result1 = init1.plus(vec1.times(v));
                const result2 = init2.plus(vec2.times(v));

                const result = result1.plus(result2).times(0.5);
                if (result.x >= min_x and result.x <= max_x and
                    result.y >= min_y and result.y <= max_y and
                    result.z >= min_z and result.z <= max_z)
                {
                    return result;
                }
            }

            return null;
        }
        // the planes have the same speeds and are moving in parallel (or they are
        // not moving at all) they  thus have the same distance all the time ; we
        // calculate it from the initial point

        // dist = || i2 - i1 || = sqrt(  ( i2 - i1 )^T * ( i2 - i1 ) )
        const dist = init2.minus(init1).magnitude();
        if (dist <= radius) return init1.plus(init2).times(0.5);

        return null;
    }
};

const Aircraft = struct {
    callsign: CallSign,
    position: Vector3D,
};

const VoxelMap = RedBlackTree(Vector2D, *Vector(Motion));

const CollisionDetector = struct {
    state: RedBlackTree(CallSign, Vector3D) = .{},

    const horizontal: Vector2D = .{ .x = good_voxel_size, .y = 0.0 };
    const vertical: Vector2D = .{ .x = 0.0, .y = good_voxel_size };

    fn deinit(self: *CollisionDetector) void {
        self.state.deinit();
    }

    fn isInVoxel(voxel: Vector2D, motion: *const Motion) bool {
        if (voxel.x > max_x or voxel.x < min_x or voxel.y > max_y or voxel.y < min_y) return false;

        const init = motion.pos_one;
        const fin = motion.pos_two;

        const v_s = good_voxel_size;
        const r = proximity_radius / 2.0;

        const v_x = voxel.x;
        const x0 = init.x;
        const xv = fin.x - init.x;

        const v_y = voxel.y;
        const y0 = init.y;
        const yv = fin.y - init.y;

        var low_x = (v_x - r - x0) / xv;
        var high_x = (v_x + v_s + r - x0) / xv;

        if (xv < 0.0) {
            const tmp = low_x;
            low_x = high_x;
            high_x = tmp;
        }

        var low_y = (v_y - r - y0) / yv;
        var high_y = (v_y + v_s + r - y0) / yv;

        if (yv < 0.0) {
            const tmp = low_y;
            low_y = high_y;
            high_y = tmp;
        }

        return (((xv == 0.0 and v_x <= x0 + r and
            x0 - r <= v_x + v_s) // no motion in x
        or (low_x <= 1.0 and 1.0 <= high_x) or
            (low_x <= 0.0 and 0.0 <= high_x) or (0.0 <= low_x and high_x <= 1.0)) and
            ((yv == 0.0 and v_y <= y0 + r and
                y0 - r <= v_y + v_s) // no motion in y
            or
                ((low_y <= 1.0 and 1.0 <= high_y) or (low_y <= 0.0 and 0.0 <= high_y) or
                    (0.0 <= low_y and high_y <= 1.0))) and
            (xv == 0.0 or yv == 0.0 or // no motion in x or y or both
                (low_y <= high_x and high_x <= high_y) or
                (low_y <= low_x and low_x <= high_y) or
                (low_x <= low_y and high_y <= high_x)));
    }

    fn putIntoMap(voxel_map: *VoxelMap, voxel: Vector2D, motion: *const Motion) void {
        if (voxel_map.get(voxel)) |array| {
            array.*.append(motion.*);
        } else {
            const arr = mem.create(Vector(Motion), .init(0));
            arr.append(motion.*);
            _ = voxel_map.put(voxel, arr);
        }
    }

    fn recurse(self: *CollisionDetector, voxel_map: *VoxelMap, seen: *RedBlackTree(Vector2D, bool), next_voxel: Vector2D, motion: *const Motion) void {
        if (!isInVoxel(next_voxel, motion)) return;
        if (seen.put(next_voxel, true) == true) return;
        putIntoMap(voxel_map, next_voxel, motion);

        self.recurse(voxel_map, seen, next_voxel.minus(horizontal), motion);
        self.recurse(voxel_map, seen, next_voxel.plus(horizontal), motion);
        self.recurse(voxel_map, seen, next_voxel.minus(vertical), motion);
        self.recurse(voxel_map, seen, next_voxel.plus(vertical), motion);
        self.recurse(voxel_map, seen, next_voxel.minus(horizontal).minus(vertical), motion);
        self.recurse(voxel_map, seen, next_voxel.minus(horizontal).plus(vertical), motion);
        self.recurse(voxel_map, seen, next_voxel.plus(horizontal).minus(vertical), motion);
        self.recurse(voxel_map, seen, next_voxel.plus(horizontal).plus(vertical), motion);
    }

    fn reduceCollisionSet(self: *CollisionDetector, motions: *Vector(Motion)) *Vector(*Vector(Motion)) {
        var voxel_map: VoxelMap = .{};
        defer voxel_map.deinit();
        const Context = struct { detector: *CollisionDetector, voxel_map: *VoxelMap };
        motions.forEach(Context{ .detector = self, .voxel_map = &voxel_map }, struct {
            fn f(ctx: Context, motion: Motion) void {
                ctx.detector.drawMotionOnVoxelMap(ctx.voxel_map, motion);
            }
        }.f);

        const result = mem.create(Vector(*Vector(Motion)), .init(0));

        voxel_map.forEach(result, struct {
            fn f(r: *Vector(*Vector(Motion)), e: VoxelMap.Entry) void {
                if (e.value.size() > 1) {
                    r.append(e.value);
                } else {
                    e.value.destroy();
                }
            }
        }.f);
        return result;
    }

    fn voxelHash(_: *CollisionDetector, position: Vector3D) Vector2D {
        const x_div: i32 = @intFromFloat(position.x / good_voxel_size);
        const y_div: i32 = @intFromFloat(position.y / good_voxel_size);

        var x = good_voxel_size * @as(f64, @floatFromInt(x_div));
        var y = good_voxel_size * @as(f64, @floatFromInt(y_div));

        if (position.x < 0) x -= good_voxel_size;
        if (position.y < 0) y -= good_voxel_size;

        return .{ .x = x, .y = y };
    }

    fn drawMotionOnVoxelMap(self: *CollisionDetector, voxel_map: *VoxelMap, motion: Motion) void {
        var seen: RedBlackTree(Vector2D, bool) = .{};
        defer seen.deinit();
        self.recurse(voxel_map, &seen, self.voxelHash(motion.pos_one), &motion);
    }

    fn handleNewFrame(self: *CollisionDetector, frame: *Vector(Aircraft)) *Vector(Collision) {
        var motions: Vector(Motion) = .init(0);
        defer motions.deinit();
        var seen: RedBlackTree(CallSign, bool) = .{};
        defer seen.deinit();

        const FrameContext = struct { detector: *CollisionDetector, seen: *RedBlackTree(CallSign, bool), motions: *Vector(Motion) };
        frame.forEach(FrameContext{ .detector = self, .seen = &seen, .motions = &motions }, struct {
            fn f(ctx: FrameContext, aircraft: Aircraft) void {
                var old_position = ctx.detector.state.put(aircraft.callsign, aircraft.position);
                const new_position = aircraft.position;
                _ = ctx.seen.put(aircraft.callsign, true);
                if (old_position == null) {
                    // Treat newly introduced aircraft as if they were stationary.
                    old_position = new_position;
                }
                ctx.motions.append(.{ .callsign = aircraft.callsign, .pos_one = old_position.?, .pos_two = new_position });
            }
        }.f);

        var to_remove: Vector(CallSign) = .init(0);
        defer to_remove.deinit();
        const StateContext = struct { seen: *RedBlackTree(CallSign, bool), to_remove: *Vector(CallSign) };
        self.state.forEach(StateContext{ .seen = &seen, .to_remove = &to_remove }, struct {
            fn f(ctx: StateContext, e: RedBlackTree(CallSign, Vector3D).Entry) void {
                const was_seen = ctx.seen.get(e.key);
                if (was_seen == null or !was_seen.?.*) ctx.to_remove.append(e.key);
            }
        }.f);

        to_remove.forEach(self, struct {
            fn f(detector: *CollisionDetector, e: CallSign) void {
                _ = detector.state.remove(e);
            }
        }.f);

        const all_reduced = self.reduceCollisionSet(&motions);
        const collisions = mem.create(Vector(Collision), .init(0));

        all_reduced.forEach(collisions, struct {
            fn f(cs: *Vector(Collision), reduced: *Vector(Motion)) void {
                var i: usize = 0;
                while (i < reduced.size()) : (i += 1) {
                    const motion1 = reduced.at(i).?;
                    var j = i + 1;
                    while (j < reduced.size()) : (j += 1) {
                        const motion2 = reduced.at(j).?;
                        if (motion1.findIntersection(motion2)) |collision| {
                            cs.append(.{ .aircraft_a = motion1.callsign, .aircraft_b = motion2.callsign, .position = collision });
                        }
                    }
                }
            }
        }.f);
        all_reduced.destroyValues();
        all_reduced.destroy();
        return collisions;
    }
};

const Simulator = struct {
    aircraft: Vector(CallSign),

    fn init(num_aircraft: i32) Simulator {
        var sim: Simulator = .{ .aircraft = .init(0) };
        var i: i32 = 0;
        while (i < num_aircraft) : (i += 1) sim.aircraft.append(.{ .value = i });
        return sim;
    }

    fn deinit(self: *Simulator) void {
        self.aircraft.deinit();
    }

    fn simulate(self: *Simulator, time: f64) Vector(Aircraft) {
        var frame: Vector(Aircraft) = .init(0);

        var i: usize = 0;
        while (i < self.aircraft.size()) : (i += 2) {
            frame.append(.{
                .callsign = self.aircraft.at(i).?.*,
                .position = .{ .x = time, .y = @cos(time) * 2 + @as(f64, @floatFromInt(i)) * 3, .z = 10 },
            });
            frame.append(.{
                .callsign = self.aircraft.at(i + 1).?.*,
                .position = .{ .x = time, .y = @sin(time) * 2 + @as(f64, @floatFromInt(i)) * 3, .z = 10 },
            });
        }
        return frame;
    }
};

pub const CD = struct {
    fn benchmark(num_aircrafts: i32) usize {
        const num_frames = 200;

        var simulator: Simulator = .init(num_aircrafts);
        defer simulator.deinit();
        var detector: CollisionDetector = .{};
        defer detector.deinit();
        var actual_collisions: usize = 0;

        var i: i32 = 0;
        while (i < num_frames) : (i += 1) {
            const time = @as(f64, @floatFromInt(i)) / 10.0;
            var frame = simulator.simulate(time);
            const collisions = detector.handleNewFrame(&frame);
            actual_collisions += collisions.size();
            collisions.destroy();
            frame.deinit();
        }

        return actual_collisions;
    }

    pub fn innerBenchmarkLoop(_: *CD, inner_iterations: i32) bool {
        return verifyResult(benchmark(inner_iterations), inner_iterations);
    }

    fn verifyResult(actual_collisions: usize, num_aircrafts: i32) bool {
        if (num_aircrafts == 1000) return actual_collisions == 14484;
        if (num_aircrafts == 500) return actual_collisions == 14484;
        if (num_aircrafts == 250) return actual_collisions == 10830;
        if (num_aircrafts == 200) return actual_collisions == 8655;
        if (num_aircrafts == 100) return actual_collisions == 4305;
        if (num_aircrafts == 10) return actual_collisions == 390;
        if (num_aircrafts == 2) return actual_collisions == 42;

        std.debug.print("No verification result for {d} found\n", .{num_aircrafts});
        std.debug.print("Result is: {d}\n", .{actual_collisions});
        return false;
    }
};
