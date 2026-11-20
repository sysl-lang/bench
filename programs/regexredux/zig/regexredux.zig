// The Computer Language Benchmarks Game: regex-redux. Original, written for this benchmark. Zig has no
// regular-expression library of its own, so it mirrors the Game's fastest C program (regexredux.gcc-5,
// Jeremy Zerfas and Zoltan Herczeg) over the same library: PCRE2, each pattern JIT-compiled and matched with pcre2_jit_match. Threaded
// as gcc-5 is with OpenMP: once the descriptions and newlines are removed, one thread applies the five
// substitutions in turn while the other threads count the nine variants, each taking the next
// pattern; each thread has its own match context, JIT stack and match data; the counts are printed in
// pattern order.
const std = @import("std");

extern "c" fn printf(fmt: [*:0]const u8, ...) c_int;
extern "c" fn read(fd: c_int, buf: [*]u8, n: usize) isize;
extern "c" fn malloc(n: usize) ?*anyopaque;
extern "c" fn realloc(p: ?*anyopaque, n: usize) ?*anyopaque;
extern "c" fn free(p: ?*anyopaque) void;

const Code = opaque {};
const MatchContext = opaque {};
const MatchData = opaque {};
const JitStack = opaque {};

extern "c" fn pcre2_compile_8(pattern: [*]const u8, length: usize, options: u32, errorcode: *c_int, erroroffset: *usize, ccontext: ?*anyopaque) ?*Code;
extern "c" fn pcre2_jit_compile_8(code: *Code, options: u32) c_int;
extern "c" fn pcre2_code_free_8(code: *Code) void;
extern "c" fn pcre2_match_context_create_8(gcontext: ?*anyopaque) ?*MatchContext;
extern "c" fn pcre2_jit_stack_create_8(startsize: usize, maxsize: usize, gcontext: ?*anyopaque) ?*JitStack;
extern "c" fn pcre2_jit_stack_assign_8(mcontext: *MatchContext, callback: ?*anyopaque, data: ?*anyopaque) void;
extern "c" fn pcre2_match_data_create_8(ovecsize: u32, gcontext: ?*anyopaque) ?*MatchData;
extern "c" fn pcre2_get_ovector_pointer_8(md: *MatchData) [*]usize;
extern "c" fn pcre2_jit_match_8(code: *Code, subject: [*]const u8, length: usize, startoffset: usize, options: u32, md: *MatchData, mcontext: *MatchContext) c_int;

const PCRE2_JIT_COMPLETE: u32 = 1;

const Str = struct {
    data: [*]u8,
    capacity: usize,
    size: usize,

    fn init(capacity: usize) Str {
        return .{ .data = @ptrCast(malloc(capacity).?), .capacity = capacity, .size = 0 };
    }

    fn reserve(self: *Str, extra: usize) void {
        while (self.size + extra > self.capacity) {
            self.capacity *= 2;
            self.data = @ptrCast(realloc(self.data, self.capacity).?);
        }
    }

    fn append(self: *Str, bytes: []const u8) void {
        self.reserve(bytes.len);
        @memcpy(self.data[self.size .. self.size + bytes.len], bytes);
        self.size += bytes.len;
    }
};

const Matcher = struct {
    mcontext: *MatchContext,
    mdata: *MatchData,
    ovector: [*]usize,
};

fn compile(pattern: []const u8) *Code {
    var errorcode: c_int = 0;
    var erroroffset: usize = 0;
    const code = pcre2_compile_8(pattern.ptr, pattern.len, 0, &errorcode, &erroroffset, null).?;
    _ = pcre2_jit_compile_8(code, PCRE2_JIT_COMPLETE);
    return code;
}

// Every match of pattern in src replaced by replacement, appended to dst.
fn replace(pattern: []const u8, replacement: []const u8, src: *const Str, dst: *Str, m: Matcher) void {
    const code = compile(pattern);
    var pos: usize = 0;
    while (pcre2_jit_match_8(code, src.data, src.size, pos, 0, m.mdata, m.mcontext) >= 0) {
        dst.append(src.data[pos..m.ovector[0]]);
        dst.append(replacement);
        pos = m.ovector[1];
    }
    pcre2_code_free_8(code);
    dst.append(src.data[pos..src.size]);
}

fn newMatcher() Matcher {
    const mcontext = pcre2_match_context_create_8(null).?;
    const stack = pcre2_jit_stack_create_8(16384, 16384, null).?;
    pcre2_jit_stack_assign_8(mcontext, null, stack);
    const mdata = pcre2_match_data_create_8(16, null).?;
    return .{ .mcontext = mcontext, .mdata = mdata, .ovector = pcre2_get_ovector_pointer_8(mdata) };
}

const variants = [_][:0]const u8{
        "agggtaaa|tttaccct",
        "[cgt]gggtaaa|tttaccc[acg]",
        "a[act]ggtaaa|tttacc[agt]t",
        "ag[act]gtaaa|tttac[agt]ct",
        "agg[act]taaa|ttta[agt]cct",
        "aggg[acg]aaa|ttt[cgt]ccct",
        "agggt[cgt]aa|tt[acg]accct",
        "agggta[cgt]a|t[acg]taccct",
        "agggtaa[cgt]|[acg]ttaccct",
};
const substs = [_][2][]const u8{
        .{ "tHa[Nt]", "<4>" },
        .{ "aND|caN|Ha[DS]|WaS", "<3>" },
        .{ "a[NSt]|BY", "<2>" },
        .{ "<[^>]*>", "|" },
    .{ "\\|[^|][^|]*\\|", "-" },
};

var counts: [variants.len]c_int = undefined;
var next_variant = std.atomic.Value(usize).init(0);

fn countVariants(sequences: *const Str) void {
    const m = newMatcher();
    while (true) {
        const i = next_variant.fetchAdd(1, .monotonic);
        if (i >= variants.len) return;
        const code = compile(variants[i]);
        var count: c_int = 0;
        var pos: usize = 0;
        while (pcre2_jit_match_8(code, sequences.data, sequences.size, pos, 0, m.mdata, m.mcontext) >= 0) {
            count += 1;
            pos = m.ovector[1];
        }
        pcre2_code_free_8(code);
        counts[i] = count;
    }
}

fn substitute(sequences: *const Str, result: *usize) void {
    const m = newMatcher();
    var pre = Str.init(sequences.capacity);
    var post = Str.init(sequences.capacity);
    pre.append(sequences.data[0..sequences.size]);
    for (substs) |s| {
        replace(s[0], s[1], &pre, &post, m);
        const t = pre;
        pre = post;
        post = t;
        post.size = 0;
    }
    result.* = pre.size;
}

pub export fn main() c_int {

    // Read the whole of standard input.
    var input = Str.init(16384);
    while (true) {
        input.reserve(1);
        const r = read(0, input.data + input.size, input.capacity - input.size);
        if (r <= 0) break;
        input.size += @intCast(r);
    }

    const m = newMatcher();

    // Remove the descriptions and the newlines.
    var sequences = Str.init(16384);
    replace(">.*\\n|\\n", "", &input, &sequences, m);
    const input_size = input.size;
    free(input.data);

    // One thread substitutes; the others (as many as there are cores, at most one per pattern) count.
    var subst_size: usize = 0;
    const subst_thread = std.Thread.spawn(.{}, substitute, .{ &sequences, &subst_size }) catch unreachable;
    const cores = std.Thread.getCpuCount() catch 1;
    const ncount = @max(1, @min(cores - 1, variants.len));
    var threads: [variants.len]std.Thread = undefined;
    for (threads[0 .. ncount - 1]) |*th| th.* = std.Thread.spawn(.{}, countVariants, .{&sequences}) catch unreachable;
    countVariants(&sequences);
    for (threads[0 .. ncount - 1]) |*th| th.join();
    for (variants, 0..) |v, i| _ = printf("%s %d\n", v.ptr, counts[i]);
    subst_thread.join();

    _ = printf("\n%d\n%d\n%d\n", @as(c_int, @intCast(input_size)), @as(c_int, @intCast(sequences.size)), @as(c_int, @intCast(subst_size)));
    return 0;
}
