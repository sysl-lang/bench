//! json.h. The document is a tree and is freed from its root; `true`,
//! `false` and `null` are allocated literal objects, as in C++.
//!
//! The value classes (JsonValue and its five subclasses) are a kind tag in a
//! common header, and each subclass recovers its own type with
//! `@fieldParentPtr` (the pattern of `std.Build.Step`). Their virtual methods
//! in C++ are type tests and casts (`isObject`, `asArray`, ...), which the tag
//! answers; each node is still its own allocation of its own size.
//!
//! Strings. `current` (C++ `_current`, a one-character `std::string` made by
//! `substr` on every `read`) is a one-character slice of the input, compared
//! with `std.mem.eql`. A captured string (a name, a string value, a number)
//! is a slice of the input when it holds no escape and an owned copy when it
//! does, the policy of `std.json`'s default (`.alloc_if_needed`). The input is
//! the program's constant document, which outlives every tree. C++ copies the
//! input into the parser and every captured string into a `std::string`,
//! which for one of 22 characters or fewer is stored inline without an
//! allocation; this document has no escapes.

const std = @import("std");
const mem = @import("mem.zig");
const Vector = @import("som/vector.zig").Vector;
const rap_benchmark_minified = @import("json_data.zig").rap_benchmark_minified;

/// A captured string: borrowed from the input, or owned.
const Str = struct {
    bytes: []const u8,
    owned: bool,

    fn deinit(self: Str) void {
        if (self.owned) mem.free(self.bytes);
    }

    fn isEmpty(self: Str) bool {
        return self.bytes.len == 0;
    }
};

const HashIndexTable = struct {
    hash_table: [32]i32 = @splat(0),

    fn add(self: *HashIndexTable, name: []const u8, index: i32) void {
        const slot = hashSlotFor(name);
        if (index < 0xff) {
            // increment by 1, 0 stands for empty
            self.hash_table[slot] = (index + 1) & 0xff;
        } else {
            self.hash_table[slot] = 0;
        }
    }

    fn get(self: *const HashIndexTable, name: []const u8) i32 {
        const slot = hashSlotFor(name);
        // subtract 1, 0 stands for empty
        return (self.hash_table[slot] & 0xff) - 1;
    }

    fn stringHash(s: []const u8) i32 {
        // this is not a proper hash, but sufficient for the benchmark,
        // and very portable!
        return @as(i32, @intCast(s.len)) *% 1402589;
    }

    fn hashSlotFor(element: []const u8) usize {
        return @intCast(stringHash(element) & (32 - 1));
    }
};

const JsonValue = struct {
    kind: Kind,

    const Kind = enum { array, literal, number, object, string };

    fn isObject(self: *const JsonValue) bool {
        return self.kind == .object;
    }
    fn isArray(self: *const JsonValue) bool {
        return self.kind == .array;
    }
    fn isNumber(self: *const JsonValue) bool {
        return self.kind == .number;
    }
    fn isString(self: *const JsonValue) bool {
        return self.kind == .string;
    }
    fn isBoolean(self: *const JsonValue) bool {
        return self.kind == .literal and JsonLiteral.of(self).isBoolean();
    }
    fn isTrue(self: *const JsonValue) bool {
        return self.kind == .literal and JsonLiteral.of(self).is_true;
    }
    fn isFalse(self: *const JsonValue) bool {
        return self.kind == .literal and JsonLiteral.of(self).is_false;
    }
    fn isNull(self: *const JsonValue) bool {
        return self.kind == .literal and JsonLiteral.of(self).is_null;
    }

    /// The subclass object this header belongs to.
    fn parent(comptime T: type, self: *const JsonValue) *T {
        const p: *const T = @alignCast(@fieldParentPtr("value", self));
        return @constCast(p);
    }

    fn asObject(self: *const JsonValue) *const JsonObject {
        if (self.kind != .object) @panic("Not an object");
        return parent(JsonObject, self);
    }

    fn asArray(self: *const JsonValue) *const JsonArray {
        if (self.kind != .array) @panic("Not an array");
        return parent(JsonArray, self);
    }

    /// `delete value`: the virtual destructor.
    fn destroy(self: *const JsonValue) void {
        switch (self.kind) {
            .array => parent(JsonArray, self).destroy(),
            .literal => mem.destroy(parent(JsonLiteral, self)),
            .number => {
                const n = parent(JsonNumber, self);
                n.string.deinit();
                mem.destroy(n);
            },
            .object => parent(JsonObject, self).destroy(),
            .string => {
                const s = parent(JsonString, self);
                s.string.deinit();
                mem.destroy(s);
            },
        }
    }
};

const JsonArray = struct {
    value: JsonValue = .{ .kind = .array },
    values: Vector(*const JsonValue) = .init(0),

    fn new() *JsonArray {
        return mem.create(JsonArray, .{});
    }

    fn destroy(self: *JsonArray) void {
        for (self.values.storage[self.values.first_idx..self.values.last_idx]) |v| v.destroy();
        self.values.deinit();
        mem.destroy(self);
    }

    fn add(self: *JsonArray, value: *const JsonValue) void {
        self.values.append(value);
    }

    fn size(self: *const JsonArray) usize {
        return self.values.size();
    }

    fn get(self: *const JsonArray, index: usize) *const JsonValue {
        return self.values.at(index).?.*;
    }
};

const JsonLiteral = struct {
    value: JsonValue = .{ .kind = .literal },
    string: []const u8,
    is_null: bool,
    is_true: bool,
    is_false: bool,

    fn of(v: *const JsonValue) *const JsonLiteral {
        return JsonValue.parent(JsonLiteral, v);
    }

    fn isBoolean(self: *const JsonLiteral) bool {
        return self.is_true or self.is_false;
    }

    fn createNull() *JsonLiteral {
        return mem.create(JsonLiteral, .{ .string = "null", .is_null = true, .is_true = false, .is_false = false });
    }

    fn createTrue() *JsonLiteral {
        return mem.create(JsonLiteral, .{ .string = "true", .is_null = false, .is_true = true, .is_false = false });
    }

    fn createFalse() *JsonLiteral {
        return mem.create(JsonLiteral, .{ .string = "false", .is_null = false, .is_true = false, .is_false = true });
    }
};

const JsonNumber = struct {
    value: JsonValue = .{ .kind = .number },
    string: Str,

    fn new(string: Str) *JsonNumber {
        if (string.isEmpty()) @panic("value is null");
        return mem.create(JsonNumber, .{ .string = string });
    }
};

const JsonObject = struct {
    value: JsonValue = .{ .kind = .object },
    names: Vector(Str) = .init(0),
    values: Vector(*const JsonValue) = .init(0),
    table: HashIndexTable = .{},

    fn new() *JsonObject {
        return mem.create(JsonObject, .{});
    }

    fn destroy(self: *JsonObject) void {
        for (self.values.storage[self.values.first_idx..self.values.last_idx]) |v| v.destroy();
        for (self.names.storage[self.names.first_idx..self.names.last_idx]) |n| n.deinit();
        self.values.deinit();
        self.names.deinit();
        mem.destroy(self);
    }

    fn indexOf(self: *const JsonObject, name: []const u8) i32 {
        const index = self.table.get(name);
        if (index != -1 and std.mem.eql(u8, name, self.names.at(@intCast(index)).?.bytes)) return index;
        @panic("not yet implemented, not relevant for the benchmark");
    }

    fn add(self: *JsonObject, name: Str, value: *const JsonValue) void {
        if (name.isEmpty()) @panic("name is null");
        self.table.add(name.bytes, @intCast(self.names.size()));
        self.names.append(name);
        self.values.append(value);
    }

    fn get(self: *const JsonObject, name: []const u8) ?*const JsonValue {
        if (name.len == 0) @panic("name is null");
        const index = self.indexOf(name);
        return if (index == -1) null else self.values.at(@intCast(index)).?.*;
    }

    fn size(self: *const JsonObject) usize {
        return self.names.size();
    }

    fn isEmpty(self: *const JsonObject) bool {
        return self.names.isEmpty();
    }
};

const JsonString = struct {
    value: JsonValue = .{ .kind = .string },
    string: Str,

    fn new(string: Str) *JsonString {
        return mem.create(JsonString, .{ .string = string });
    }
};

const JsonPureStringParser = struct {
    input: []const u8,
    index: usize = std.math.maxInt(usize),
    line: i32 = 1,
    column: i32 = 0,
    current: []const u8 = "",
    capture_buffer: std.ArrayList(u8) = .empty,
    capture_start: usize = std.math.maxInt(usize),

    fn init(string: []const u8) JsonPureStringParser {
        return .{ .input = string };
    }

    fn deinit(self: *JsonPureStringParser) void {
        self.capture_buffer.deinit(mem.gpa);
    }

    fn is(self: *const JsonPureStringParser, ch: []const u8) bool {
        return std.mem.eql(u8, self.current, ch);
    }

    fn readValue(self: *JsonPureStringParser) *const JsonValue {
        if (self.is("n")) return self.readNull();
        if (self.is("t")) return self.readTrue();
        if (self.is("f")) return self.readFalse();
        if (self.is("\"")) return self.readString();
        if (self.is("[")) return &self.readArray().value;
        if (self.is("{")) return &self.readObject().value;
        if (self.is("-") or self.is("0") or self.is("1") or
            self.is("2") or self.is("3") or self.is("4") or
            self.is("5") or self.is("6") or self.is("7") or
            self.is("8") or self.is("9"))
        {
            return self.readNumber();
        }
        self.expected("value");
    }

    fn readObject(self: *JsonPureStringParser) *JsonObject {
        self.read();
        const object = JsonObject.new();
        self.skipWhiteSpace();
        if (self.readChar("}")) return object;
        while (true) {
            self.skipWhiteSpace();
            const name = self.readName();
            self.skipWhiteSpace();
            if (!self.readChar(":")) self.expected("':'");
            self.skipWhiteSpace();

            object.add(name, self.readValue());
            self.skipWhiteSpace();
            if (!self.readChar(",")) break;
        }
        if (!self.readChar("}")) self.expected("',' or '}'");
        return object;
    }

    fn readName(self: *JsonPureStringParser) Str {
        if (!self.is("\"")) self.expected("name");
        return self.readStringInternal();
    }

    fn readArray(self: *JsonPureStringParser) *JsonArray {
        self.read();
        const array = JsonArray.new();
        self.skipWhiteSpace();
        if (self.readChar("]")) return array;
        while (true) {
            self.skipWhiteSpace();
            array.add(self.readValue());
            self.skipWhiteSpace();
            if (!self.readChar(",")) break;
        }
        if (!self.readChar("]")) self.expected("',' or ']'");
        return array;
    }

    fn readNull(self: *JsonPureStringParser) *const JsonValue {
        self.read();
        self.readRequiredChar("u");
        self.readRequiredChar("l");
        self.readRequiredChar("l");
        return &JsonLiteral.createNull().value;
    }

    fn readTrue(self: *JsonPureStringParser) *const JsonValue {
        self.read();
        self.readRequiredChar("r");
        self.readRequiredChar("u");
        self.readRequiredChar("e");
        return &JsonLiteral.createTrue().value;
    }

    fn readFalse(self: *JsonPureStringParser) *const JsonValue {
        self.read();
        self.readRequiredChar("a");
        self.readRequiredChar("l");
        self.readRequiredChar("s");
        self.readRequiredChar("e");
        return &JsonLiteral.createFalse().value;
    }

    fn readRequiredChar(self: *JsonPureStringParser, ch: []const u8) void {
        if (!self.readChar(ch)) self.expected(ch);
    }

    fn readString(self: *JsonPureStringParser) *const JsonValue {
        return &JsonString.new(self.readStringInternal()).value;
    }

    fn readStringInternal(self: *JsonPureStringParser) Str {
        self.read();
        self.startCapture();
        while (!self.is("\"")) {
            if (self.is("\\")) {
                self.pauseCapture();
                self.readEscape();
                self.startCapture();
            } else {
                self.read();
            }
        }
        const string = self.endCapture();
        self.read();
        return string;
    }

    fn appendCapture(self: *JsonPureStringParser, bytes: []const u8) void {
        self.capture_buffer.appendSlice(mem.gpa, bytes) catch @panic("out of memory");
    }

    fn readEscape(self: *JsonPureStringParser) void {
        self.read();
        if (self.is("\"") or self.is("/") or self.is("\\")) {
            self.appendCapture(self.current);
        } else if (self.is("b")) {
            self.appendCapture("\x08");
        } else if (self.is("f")) {
            self.appendCapture("\x0c");
        } else if (self.is("n")) {
            self.appendCapture("\n");
        } else if (self.is("r")) {
            self.appendCapture("\r");
        } else if (self.is("t")) {
            self.appendCapture("\t");
        } else {
            self.expected("valid escape sequence");
        }
        self.read();
    }

    fn readNumber(self: *JsonPureStringParser) *const JsonValue {
        self.startCapture();
        _ = self.readChar("-");
        const first_digit = self.current;
        if (!self.readDigit()) self.expected("digit");
        if (!std.mem.eql(u8, first_digit, "0")) {
            while (self.readDigit()) {}
        }
        _ = self.readFraction();
        _ = self.readExponent();
        return &JsonNumber.new(self.endCapture()).value;
    }

    fn readFraction(self: *JsonPureStringParser) bool {
        if (!self.readChar(".")) return false;
        if (!self.readDigit()) self.expected("digit");
        while (self.readDigit()) {}
        return true;
    }

    fn readExponent(self: *JsonPureStringParser) bool {
        if (!self.readChar("e") and !self.readChar("E")) return false;
        if (!self.readChar("+")) _ = self.readChar("-");
        if (!self.readDigit()) self.expected("digit");
        while (self.readDigit()) {}
        return true;
    }

    fn readChar(self: *JsonPureStringParser, ch: []const u8) bool {
        if (!self.is(ch)) return false;
        self.read();
        return true;
    }

    fn readDigit(self: *JsonPureStringParser) bool {
        if (!self.isDigit()) return false;
        self.read();
        return true;
    }

    fn skipWhiteSpace(self: *JsonPureStringParser) void {
        while (self.isWhiteSpace()) self.read();
    }

    fn read(self: *JsonPureStringParser) void {
        if (self.is("\n")) {
            self.line += 1;
            self.column = 0;
        }
        self.index +%= 1;
        if (self.index < self.input.len) {
            self.current = self.input[self.index..][0..1];
        } else {
            self.current = "";
        }
    }

    fn startCapture(self: *JsonPureStringParser) void {
        self.capture_start = self.index;
    }

    fn captureEnd(self: *const JsonPureStringParser) usize {
        return if (self.current.len == 0) self.index else self.index - 1;
    }

    fn pauseCapture(self: *JsonPureStringParser) void {
        self.appendCapture(self.input[self.capture_start .. self.captureEnd() + 1]);
        self.capture_start = std.math.maxInt(usize);
    }

    fn endCapture(self: *JsonPureStringParser) Str {
        const end = self.captureEnd();
        var captured: Str = undefined;
        if (self.capture_buffer.items.len == 0) {
            captured = .{ .bytes = self.input[self.capture_start .. end + 1], .owned = false };
        } else {
            self.appendCapture(self.input[self.capture_start .. end + 1]);
            const owned = mem.alloc(u8, self.capture_buffer.items.len);
            @memcpy(owned, self.capture_buffer.items);
            captured = .{ .bytes = owned, .owned = true };
            self.capture_buffer.clearRetainingCapacity();
        }
        self.capture_start = std.math.maxInt(usize);
        return captured;
    }

    /// `throw expected(...)`: a ParseException nothing catches.
    fn expected(self: *const JsonPureStringParser, what: []const u8) noreturn {
        @branchHint(.cold);
        if (self.isEndOfText()) std.debug.panic("Unexpected end of input at {d}:{d}", .{ self.line, self.column - 1 });
        std.debug.panic("Expected {s} at {d}:{d}", .{ what, self.line, self.column - 1 });
    }

    fn isWhiteSpace(self: *const JsonPureStringParser) bool {
        return self.is(" ") or self.is("\t") or self.is("\n") or self.is("\r");
    }

    fn isDigit(self: *const JsonPureStringParser) bool {
        return self.is("0") or self.is("1") or self.is("2") or
            self.is("3") or self.is("4") or self.is("5") or
            self.is("6") or self.is("7") or self.is("8") or
            self.is("9");
    }

    fn isEndOfText(self: *const JsonPureStringParser) bool {
        return self.current.len == 0;
    }

    fn parse(self: *JsonPureStringParser) *const JsonValue {
        self.read();
        self.skipWhiteSpace();
        const result = self.readValue();
        self.skipWhiteSpace();
        if (!self.isEndOfText()) @panic("Unexpected character");
        return result;
    }
};

pub const Json = struct {
    pub fn benchmark(_: *Json) *const JsonValue {
        var parser: JsonPureStringParser = .init(rap_benchmark_minified);
        defer parser.deinit();
        return parser.parse();
    }

    fn hasExpectedContent(_: *Json, result: *const JsonValue) bool {
        if (!result.isObject()) return false;
        const result_object = result.asObject();
        if (!result_object.get("head").?.isObject()) return false;
        if (!result_object.get("operations").?.isArray()) return false;
        const result_array = result_object.get("operations").?.asArray();
        return result_array.size() == 156;
    }

    pub fn verifyResult(self: *Json, result: *const JsonValue) bool {
        const does_verify = self.hasExpectedContent(result);
        result.destroy();
        return does_verify;
    }
};
