//! som/dictionary.h and som/identity_dictionary.h: a chained hash map keyed
//! by object pointers (`const K*`), hashing with the key's `customHash`.
//!
//! The dictionary does not own its keys and values; it owns its entries.
//! In C++ `Entry::match` is virtual so that IdentityDictionary's IdEntry can
//! override it, with a body identical to the base one (hash and pointer
//! equality). Both are this one type here, and `match` is a plain function.

const mem = @import("../mem.zig");
const Vector = @import("vector.zig").Vector;

pub const initial_capacity = 16;

pub fn Dictionary(comptime K: type, comptime V: type) type {
    return struct {
        const Self = @This();

        pub const Entry = struct {
            hash: u32,
            key: *const K,
            value: V,
            next: ?*Entry,

            fn match(self: *const Entry, h: u32, k: *const K) bool {
                return self.hash == h and self.key == k;
            }
        };

        /// The C++ `_buckets` with its `_capacity`.
        buckets: []?*Entry,
        size: u32 = 0,

        pub fn init(capacity: u32) Self {
            const buckets = mem.alloc(?*Entry, capacity);
            @memset(buckets, null);
            return .{ .buckets = buckets };
        }

        pub fn deinit(self: *Self) void {
            self.removeAll();
            mem.free(self.buckets);
        }

        pub fn getSize(self: *const Self) u32 {
            return self.size;
        }

        pub fn isEmpty(self: *const Self) bool {
            return self.size == 0;
        }

        fn hash(key: *const K) u32 {
            const h: u32 = key.customHash();
            return h ^ (h >> 16);
        }

        pub fn containsKey(self: *const Self, key: *const K) bool {
            const h = hash(key);
            var e = self.getBucket(h);
            while (e) |entry| : (e = entry.next) {
                if (entry.match(h, key)) return true;
            }
            return false;
        }

        pub fn at(self: *const Self, key: *const K) ?*V {
            const h = hash(key);
            var e = self.getBucket(h);
            while (e) |entry| : (e = entry.next) {
                if (entry.match(h, key)) return &entry.value;
            }
            return null;
        }

        pub fn atPut(self: *Self, key: *const K, value: V) void {
            const h = hash(key);
            const i = self.getBucketIdx(h);
            if (self.buckets[i]) |current| {
                self.insertBucketEntry(key, value, h, current);
            } else {
                self.buckets[i] = newEntry(key, value, h);
                self.size += 1;
            }
            if (self.size > self.buckets.len) self.resize();
        }

        pub fn removeAll(self: *Self) void {
            for (self.buckets) |*bucket| {
                var current = bucket.*;
                while (current) |to_be_deleted| {
                    current = to_be_deleted.next;
                    mem.destroy(to_be_deleted);
                }
                bucket.* = null;
            }
            self.size = 0;
        }

        pub fn getKeys(self: *const Self) *Vector(*const K) {
            const keys = mem.create(Vector(*const K), .init(0));
            for (self.buckets) |bucket| {
                var current = bucket;
                while (current) |entry| : (current = entry.next) keys.append(entry.key);
            }
            return keys;
        }

        pub fn getValues(self: *const Self) *Vector(V) {
            const values = mem.create(Vector(V), .init(self.size));
            for (self.buckets) |bucket| {
                var current = bucket;
                while (current) |entry| : (current = entry.next) values.append(entry.value);
            }
            return values;
        }

        /// `delete` of every value: V is a pointer.
        pub fn destroyValues(self: *Self) void {
            for (self.buckets) |bucket| {
                var current = bucket;
                while (current) |entry| : (current = entry.next) mem.destroy(entry.value);
            }
        }

        fn newEntry(key: *const K, value: V, h: u32) *Entry {
            return mem.create(Entry, .{ .hash = h, .key = key, .value = value, .next = null });
        }

        fn getBucketIdx(self: *const Self, h: u32) usize {
            return (@as(u32, @intCast(self.buckets.len)) - 1) & h;
        }

        fn getBucket(self: *const Self, h: u32) ?*Entry {
            return self.buckets[self.getBucketIdx(h)];
        }

        fn insertBucketEntry(self: *Self, key: *const K, value: V, h: u32, head: *Entry) void {
            var current = head;
            while (true) {
                if (current.match(h, key)) {
                    current.value = value;
                    return;
                }
                if (current.next) |next| {
                    current = next;
                } else {
                    self.size += 1;
                    current.next = newEntry(key, value, h);
                    return;
                }
            }
        }

        fn resize(self: *Self) void {
            const old_storage = self.buckets;
            const new_storage = mem.alloc(?*Entry, old_storage.len * 2);
            @memset(new_storage, null);
            self.buckets = new_storage;
            self.transferEntries(old_storage);
            mem.free(old_storage);
        }

        fn transferEntries(self: *Self, old_storage: []?*Entry) void {
            const old_capacity: u32 = @intCast(old_storage.len);
            for (old_storage, 0..) |*slot, i| {
                if (slot.*) |current| {
                    slot.* = null;
                    if (current.next == null) {
                        self.buckets[current.hash & (old_capacity - 1)] = current;
                    } else {
                        self.splitBucket(old_capacity, i, current);
                    }
                }
            }
        }

        fn splitBucket(self: *Self, old_capacity: u32, idx: usize, head: *Entry) void {
            var lo_head: ?*Entry = null;
            var lo_tail: ?*Entry = null;
            var hi_head: ?*Entry = null;
            var hi_tail: ?*Entry = null;

            var current: ?*Entry = head;
            while (current) |entry| : (current = entry.next) {
                if ((entry.hash & old_capacity) == 0) {
                    if (lo_tail) |t| t.next = entry else lo_head = entry;
                    lo_tail = entry;
                } else {
                    if (hi_tail) |t| t.next = entry else hi_head = entry;
                    hi_tail = entry;
                }
            }

            if (lo_tail) |t| {
                t.next = null;
                self.buckets[idx] = lo_head;
            }
            if (hi_tail) |t| {
                t.next = null;
                self.buckets[idx + old_capacity] = hi_head;
            }
        }
    };
}

/// som/identity_dictionary.h: the same map (see above).
pub const IdentityDictionary = Dictionary;
