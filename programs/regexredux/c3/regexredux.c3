// The Computer Language Benchmarks Game: regex-redux. Original, written for this benchmark. It mirrors
// the Game's fastest C program (regexredux.gcc-5, Jeremy Zerfas and Zoltan Herczeg) over the same
// library, PCRE2 through extern declarations: each pattern JIT-compiled and matched with
// pcre2_jit_match. C3's own std::encoding::experimental::regex (a POSIX matcher) is not used, because
// the Game's fastest entries all call PCRE2's JIT. Threaded as gcc-5 is with OpenMP: once the
// descriptions and newlines are removed, one thread applies the five substitutions in turn while the
// other threads count the nine variants, each taking the next pattern; each thread has its own match
// context, JIT stack and match data; the counts are printed in pattern order.
module regexredux;
import std::io;
import std::thread;
import std::atomic;
import libc;

typedef Code = void*;
typedef MatchContext = void*;
typedef MatchData = void*;
typedef JitStack = void*;

extern fn Code pcre2_compile(char* pattern, usz length, uint options, CInt* errorcode, usz* erroroffset, void* ccontext) @cname("pcre2_compile_8");
extern fn CInt pcre2_jit_compile(Code code, uint options) @cname("pcre2_jit_compile_8");
extern fn void pcre2_code_free(Code code) @cname("pcre2_code_free_8");
extern fn MatchContext pcre2_match_context_create(void* gcontext) @cname("pcre2_match_context_create_8");
extern fn JitStack pcre2_jit_stack_create(usz startsize, usz maxsize, void* gcontext) @cname("pcre2_jit_stack_create_8");
extern fn void pcre2_jit_stack_assign(MatchContext mcontext, void* callback, void* data) @cname("pcre2_jit_stack_assign_8");
extern fn MatchData pcre2_match_data_create(uint ovecsize, void* gcontext) @cname("pcre2_match_data_create_8");
extern fn usz* pcre2_get_ovector_pointer(MatchData md) @cname("pcre2_get_ovector_pointer_8");
extern fn CInt pcre2_jit_match(Code code, char* subject, usz length, usz startoffset, uint options, MatchData md, MatchContext mcontext) @cname("pcre2_jit_match_8");

const uint PCRE2_JIT_COMPLETE = 1;

struct Matcher
{
	MatchContext mcontext;
	MatchData mdata;
	usz* ovector;
}

fn Matcher new_matcher()
{
	MatchContext mcontext = pcre2_match_context_create(null);
	JitStack stack = pcre2_jit_stack_create(16384, 16384, null);
	pcre2_jit_stack_assign(mcontext, null, (void*)stack);
	MatchData mdata = pcre2_match_data_create(16, null);
	return { mcontext, mdata, pcre2_get_ovector_pointer(mdata) };
}

fn Code compile(String pattern)
{
	CInt errorcode;
	usz erroroffset;
	Code code = pcre2_compile(pattern.ptr, pattern.len, 0, &errorcode, &erroroffset, null);
	pcre2_jit_compile(code, PCRE2_JIT_COMPLETE);
	return code;
}

struct Str
{
	char* data;
	usz capacity;
	usz size;
}

fn void Str.append(&self, char[] bytes)
{
	while (self.size + bytes.len > self.capacity)
	{
		self.capacity *= 2;
		self.data = mem::realloc(self.data, (sz)self.capacity);
	}
	mem::copy(self.data + self.size, bytes.ptr, bytes.len);
	self.size += bytes.len;
}

fn Str new_str(usz capacity) => { mem::malloc((sz)capacity), capacity, 0 };

// Every match of pattern in src replaced by replacement, appended to dst.
fn void replace(String pattern, String replacement, Str* src, Str* dst, Matcher m)
{
	Code code = compile(pattern);
	usz pos = 0;
	while (pcre2_jit_match(code, src.data, src.size, pos, 0, m.mdata, m.mcontext) >= 0)
	{
		dst.append(src.data[pos:m.ovector[0] - pos]);
		dst.append(replacement);
		pos = m.ovector[1];
	}
	pcre2_code_free(code);
	dst.append(src.data[pos:src.size - pos]);
}

String[9] variants = {
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

String[2][5] substs = {
	{ "tHa[Nt]", "<4>" },
	{ "aND|caN|Ha[DS]|WaS", "<3>" },
	{ "a[NSt]|BY", "<2>" },
	{ "<[^>]*>", "|" },
	{ "\\|[^|][^|]*\\|", "-" },
};

int[9] counts;
Atomic{int} next_variant;
Str sequence;
usz subst_size;

fn int count_variants(void* arg)
{
	Matcher m = new_matcher();
	while (true)
	{
		int i = next_variant.add(1);
		if (i >= 9) return 0;
		Code code = compile(variants[i]);
		int n = 0;
		usz pos = 0;
		while (pcre2_jit_match(code, sequence.data, sequence.size, pos, 0, m.mdata, m.mcontext) >= 0)
		{
			n++;
			pos = m.ovector[1];
		}
		pcre2_code_free(code);
		counts[i] = n;
	}
}

fn int substitute(void* arg)
{
	Matcher m = new_matcher();
	Str pre = new_str(sequence.capacity);
	Str post = new_str(sequence.capacity);
	pre.append(sequence.data[:sequence.size]);
	foreach (s : substs)
	{
		replace(s[0], s[1], &pre, &post, m);
		Str t = pre;
		pre = post;
		post = t;
		post.size = 0;
	}
	subst_size = pre.size;
	return 0;
}

fn int main(String[] args)
{
	// Read the whole of standard input.
	Str input = new_str(16384);
	while (true)
	{
		if (input.size == input.capacity)
		{
			input.capacity *= 2;
			input.data = mem::realloc(input.data, (sz)input.capacity);
		}
		long r = libc::read(0, input.data + input.size, input.capacity - input.size);
		if (r <= 0) break;
		input.size += (usz)r;
	}

	Matcher m = new_matcher();
	sequence = new_str(16384);
	replace(">.*\\n|\\n", "", &input, &sequence, m);

	Thread subst_thread;
	subst_thread.create(&substitute, null)!!;
	int cores = max(thread::cpu::native_cpu(), 1);
	int ncount = max(1, min(cores - 1, 9));
	Thread[9] threads;
	for (int k = 0; k < ncount - 1; k++) threads[k].create(&count_variants, null)!!;
	count_variants(null);
	for (int k = 0; k < ncount - 1; k++) (void)threads[k].join();
	for (int i = 0; i < 9; i++) io::printfn("%s %d", variants[i], counts[i]);
	(void)subst_thread.join();

	io::printf("\n%d\n%d\n%d\n", input.size, sequence.size, subst_size);
	return 0;
}
