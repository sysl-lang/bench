// The Computer Language Benchmarks Game: regex-redux. Original, written for this benchmark. It mirrors
// the Game's fastest C program (regexredux.gcc-5, Jeremy Zerfas and Zoltan Herczeg) over the same
// library, PCRE2 through a foreign import: each pattern JIT-compiled and matched with
// pcre2_jit_match. Odin's own core:text/regex (a backtracking VM) is not used, because the Game's
// fastest entries all call PCRE2's JIT. Threaded as gcc-5 is with OpenMP: once the descriptions and
// newlines are removed, one thread applies the five substitutions in turn while the other threads
// count the nine variants, each taking the next pattern; each thread has its own match context, JIT
// stack and match data; the counts are printed in pattern order.
package main

import "core:c"
import "core:fmt"
import "core:os"
import "core:sync"
import "core:thread"

foreign import pcre2 "system:pcre2-8"

Code :: struct {}
Match_Context :: struct {}
Match_Data :: struct {}
Jit_Stack :: struct {}

@(default_calling_convention = "c")
foreign pcre2 {
	pcre2_compile_8 :: proc(pattern: [^]u8, length: c.size_t, options: u32, errorcode: ^c.int, erroroffset: ^c.size_t, ccontext: rawptr) -> ^Code ---
	pcre2_jit_compile_8 :: proc(code: ^Code, options: u32) -> c.int ---
	pcre2_code_free_8 :: proc(code: ^Code) ---
	pcre2_match_context_create_8 :: proc(gcontext: rawptr) -> ^Match_Context ---
	pcre2_jit_stack_create_8 :: proc(startsize, maxsize: c.size_t, gcontext: rawptr) -> ^Jit_Stack ---
	pcre2_jit_stack_assign_8 :: proc(mcontext: ^Match_Context, callback: rawptr, data: rawptr) ---
	pcre2_match_data_create_8 :: proc(ovecsize: u32, gcontext: rawptr) -> ^Match_Data ---
	pcre2_get_ovector_pointer_8 :: proc(md: ^Match_Data) -> [^]c.size_t ---
	pcre2_jit_match_8 :: proc(code: ^Code, subject: [^]u8, length, startoffset: c.size_t, options: u32, md: ^Match_Data, mcontext: ^Match_Context) -> c.int ---
}

PCRE2_JIT_COMPLETE :: 1

Matcher :: struct {
	mcontext: ^Match_Context,
	mdata:    ^Match_Data,
	ovector:  [^]c.size_t,
}

new_matcher :: proc() -> Matcher {
	mcontext := pcre2_match_context_create_8(nil)
	stack := pcre2_jit_stack_create_8(16384, 16384, nil)
	pcre2_jit_stack_assign_8(mcontext, nil, stack)
	mdata := pcre2_match_data_create_8(16, nil)
	return Matcher{mcontext, mdata, pcre2_get_ovector_pointer_8(mdata)}
}

compile :: proc(pattern: string) -> ^Code {
	errorcode: c.int
	erroroffset: c.size_t
	code := pcre2_compile_8(raw_data(pattern), c.size_t(len(pattern)), 0, &errorcode, &erroroffset, nil)
	pcre2_jit_compile_8(code, PCRE2_JIT_COMPLETE)
	return code
}

// Every match of pattern in src replaced by replacement, appended to dst.
replace :: proc(pattern, replacement: string, src: []u8, dst: ^[dynamic]u8, m: Matcher) {
	code := compile(pattern)
	defer pcre2_code_free_8(code)
	pos := 0
	for pcre2_jit_match_8(code, raw_data(src), c.size_t(len(src)), c.size_t(pos), 0, m.mdata, m.mcontext) >= 0 {
		append(dst, ..src[pos:m.ovector[0]])
		append(dst, replacement)
		pos = int(m.ovector[1])
	}
	append(dst, ..src[pos:])
}

variants := [?]string {
	"agggtaaa|tttaccct",
	"[cgt]gggtaaa|tttaccc[acg]",
	"a[act]ggtaaa|tttacc[agt]t",
	"ag[act]gtaaa|tttac[agt]ct",
	"agg[act]taaa|ttta[agt]cct",
	"aggg[acg]aaa|ttt[cgt]ccct",
	"agggt[cgt]aa|tt[acg]accct",
	"agggta[cgt]a|t[acg]taccct",
	"agggtaa[cgt]|[acg]ttaccct",
}

substs := [?][2]string {
	{"tHa[Nt]", "<4>"},
	{"aND|caN|Ha[DS]|WaS", "<3>"},
	{"a[NSt]|BY", "<2>"},
	{"<[^>]*>", "|"},
	{`\|[^|][^|]*\|`, "-"},
}

counts: [len(variants)]int
next_variant: int

count_variants :: proc(sequence: ^[dynamic]u8) {
	m := new_matcher()
	seq := sequence[:]
	for {
		i := sync.atomic_add(&next_variant, 1)
		if i >= len(variants) {
			return
		}
		code := compile(variants[i])
		n := 0
		pos := 0
		for pcre2_jit_match_8(code, raw_data(seq), c.size_t(len(seq)), c.size_t(pos), 0, m.mdata, m.mcontext) >= 0 {
			n += 1
			pos = int(m.ovector[1])
		}
		pcre2_code_free_8(code)
		counts[i] = n
	}
}

Subst_Job :: struct {
	sequence: ^[dynamic]u8,
	size:     int,
}

substitute :: proc(job: ^Subst_Job) {
	m := new_matcher()
	pre := make([dynamic]u8, 0, cap(job.sequence))
	post := make([dynamic]u8, 0, cap(job.sequence))
	append(&pre, ..job.sequence[:])
	for s in substs {
		replace(s[0], s[1], pre[:], &post, m)
		pre, post = post, pre
		clear(&post)
	}
	job.size = len(pre)
}

main :: proc() {
	data, err := os.read_entire_file(os.stdin, context.allocator)
	assert(err == nil)

	m := new_matcher()
	sequence := make([dynamic]u8, 0, len(data))
	replace(">.*\\n|\\n", "", data, &sequence, m)

	job := Subst_Job{&sequence, 0}
	subst_thread := thread.create_and_start_with_poly_data(&job, substitute)
	cores := max(os.get_processor_core_count(), 1)
	ncount := max(1, min(cores - 1, len(variants)))
	threads: [len(variants)]^thread.Thread
	for k in 0 ..< ncount - 1 {
		threads[k] = thread.create_and_start_with_poly_data(&sequence, count_variants)
	}
	count_variants(&sequence)
	for k in 0 ..< ncount - 1 {
		thread.join(threads[k])
		thread.destroy(threads[k])
	}
	for v, i in variants {
		fmt.printf("%s %d\n", v, counts[i])
	}
	thread.join(subst_thread)
	thread.destroy(subst_thread)

	fmt.printf("\n%d\n%d\n%d\n", len(data), len(sequence), job.size)
}
