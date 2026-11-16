# Findings

Where sysl loses to C, and why. Each finding is one fix item for the compiler or the standard library.

The second sysl column, `sysl-tuned` (its programs still sit in `programs/*/sysl-fast/`), is made
as fast as it can be by hand, workarounds included: the same algorithm as C, but with whatever a
program can do itself to get past a compiler or library gap. **Each workaround is listed under its
program as a "Tuned" line**: what it does, what it bought, and the compiler or library item it
stands for, the change that would make the idiomatic program just as fast. The gap between the two
columns is that list. The "bought" figures are from development runs on a loaded machine and are
approximate; the program totals are from the one exclusive timing run named in the section.
Figures in the older text are from `results/2026-11-13.md` (sysl 0.10.7, wall-clock ratio to C).

| program | sysl-idiomatic |
|---|---:|
| revcomp | 3.67 |
| knucleotide | 1.44 |
| binarytrees | 1.42 |
| fasta | 1.17 |

## 1. revcomp — `read_all` and `Buf.extend` copy byte by byte

On sysl 0.11.5 (`--release -O3 --cpu native`, one `marshal run --exclusive`, 10 runs): **sysl-fast
39.6 ms** (Rust 38.8, C 81.7), **sysl-idiomatic 148.7 ms** (1.82x C).

**sysl-fast is Rust's algorithm**: the input is read straight into one `Buf` (`reserve`, `spare`,
`set_len`), each sequence is reverse-complemented in place by swapping a run from the front with a run
from the back so the newlines never move, and the whole buffer goes out in one `putbytes`. It does the
same work as Rust and runs at Rust's speed. **sysl-idiomatic** reads with `read_all`, finds lines with
`index_of_byte_from`, gathers a sequence with `extend`, then `reverse`, a table loop and `extend` per
60-byte output line. Its time is library code:

| part (idiomatic, `sample`) | share | what the code does |
|---|---:|---|
| `Buf.extend` | 42% | copies a 60-byte run one byte at a time |
| `read_all` and its growth | 32% | pushes every byte of each 4096-byte chunk one at a time |
| `reverse` + complement loop | 24% | scalar; the complement lookup is scalar in C and Rust too |

- **`read_all` pushes byte by byte** (`library/sysl/io/read.sysl`, `for b in got do out.push(b)`): a
  `ldrb`/`strb` loop with the push's capacity test per byte, plus a doubling `grow` that copies element
  by element. sysl-fast with `read_all` in place of its own read loop takes 85.6 ms against 51.2 ms (a
  loaded-machine pair), so the library read costs about 35 ms of 100 MB. **Fix item:** read into the
  buffer's spare room (`reserve` + `read(spare)` + `set_len`), as sysl-fast does.
- **`Buf.extend` does not become a `memcpy` for a short run.** `BufCore.extend` copies with
  `slot_place` per element. LLVM vectorises that loop in 64-byte blocks but always leaves 1 to 64 bytes
  for a scalar tail, so a run under 64 bytes (every FASTA line) is copied entirely one byte at a time.
  The loop also bumps and drops the storage's count on every call. **Fix item:** an element type with
  no count (`AnyBits`) should extend and grow with one `memcpy`.
- **`sysl.slices.reverse` is not vectorised**: one `ldrb`/`strb` pair per end per step.
- `putbytes` is one `fwrite` and costs nothing measurable here.

**sysl-tuned, sysl 0.11.5** (exclusive run, 10 runs): 39.3 → **28.6 ms**, 0.34x C (Rust 0.45x).

- **Tuned: the input is read into `malloc`/`realloc` storage with `read(0, …)`** in place of a `Buf`
  grown by `reserve` + `spare` + `set_len`. Bought ~25% (75 → 56 ms in a loaded dev pair) and halved
  peak memory (227 → 101 MiB). **Item:** `BufCore.grow` allocates fresh storage and copies element by
  element (`slot_place` per element); for an element type with no count it should `realloc`, which
  on Darwin moves a large block by remapping its pages and copies nothing. `read_all` would then
  inherit it.
- **Tuned: `@unchecked` around the swap loop.** No measurable change; kept because both runs are in
  bounds by construction. **Item:** none needed (LLVM already hoists the checks here).

## 2. fasta — generator state goes through memory every symbol

The random generator's state sits behind `*Random`. In sysl 0.10.7's `random_fasta`, every symbol
reloads the pointer from the stack and the state through it, and the state is stored back once per
line:

```
ldr   x8, [sp, #0x38]     ; the *Random, every symbol
ldr   w8, [x8]            ; its state, every symbol
madd  w8, w8, w16, w22    ; state * 3877 + 29573
...
str   w8, [x9]            ; stored back after the line
```

C keeps the seed in a register for the whole loop. Writing `state` into a local by hand and returning
it is a workaround for this (now in sysl-tuned, below). The `fdiv` per symbol is C's too. Counting
`r > p` over the 14-entry IUB table is vectorized as one 8-wide block plus a scalar tail of 6
compare-and-increment steps, the same work as C's count. Integer thresholds in place of the
floating-point comparison would change the work, so neither form uses them.

- **Suspect:** no noalias/TBAA information separates the pointee from the local `[61]u8` line, so
  LLVM cannot keep `last` in a register.

**sysl-tuned, sysl 0.11.5** (exclusive run): 670 → **544 ms**, 0.95x C (Rust 1.89x). The per-symbol
time is the generator's dependent chain (multiply-add, remainder by a constant), so what is left to
win is in instructions on that chain and in calls per line.

- **Tuned: the generator state is a local `u32`, passed in and returned**, in place of `*Random`
  and `rng.next()`. **Item:** keep a pointee's field in a register across a loop that writes only
  locals (noalias on a `*T` parameter that nothing else in the function can reach, or TBAA between a
  struct field and a `[N]u8` local). `u32` rather than `int` because C's state is `uint32_t` and the
  unsigned remainder by a constant is one instruction shorter on the chain; that is a choice of
  type, not a compiler item.
- **Tuned: the thresholds are one `<16>real` (IUB) or `<4>real` (sapiens) padded with 2.0**, and the
  index is `(r > below).select(one, 0).sum()`, in place of `count_where` over a slice. Together with
  the local state these bought ~3% in a dev pair. **Item:** `count_where` over a short slice whose
  length is a loop invariant compiles to a serial `fcmp`/`cinc` chain; C's `linear_lookup` gets the
  same, so this is beyond C, not a gap to C.
- **Tuned: lines are gathered into a 1024-line block and written with one `putbytes`**, in both
  `repeat_fasta` (copying each line with `copy`, a `memmove`) and `random_fasta`, in place of a
  `print` or `putbytes` per line. Bought ~20% (784 → 620 ms in a loaded dev run), almost all of it
  in `repeat_fasta`. **Item:** `print` and `putbytes` are an out-of-line call per line into
  `sysl_stdout_write`; a buffered stdout whose append is inlined (as `putc`/`fwrite` into stdio's
  buffer are cheap in C) would make the per-line form as fast.

## 3. knucleotide — two out-of-line map calls per position, and a costly hash

`counts.put(key, counts.get_or(key, 0) + 1)` makes two out-of-line calls per position
(`MapCore.get.ulong.int.owned` and `MapCore.put.ulong.int`), where khash does one inlined probe.

- `Map` has no upsert or entry operation.
- A newtype key with a one-multiply `impl Hash` alone took it from 2.68x to 1.67x, so the library's
  integer mixer, or its distribution on dense keys, is expensive.
- `map_with_capacity` made no difference.
- The newtype key would be pointless with a cheaper library mixer.

**sysl-tuned, sysl 0.11.5** (exclusive run): 1411 → **413 ms**, 0.41x C (Rust 0.85x). Still a hash
table per k, as rule 3 requires.

- **Tuned: the program's own open-addressing table** (`Counts`: a `[]u64` of keys with an
  all-ones empty marker, a `[]int` of counts, linear probing, doubled at half full), probed inline
  in the counting loop, with the slot taken from the top bits of `key *% 0x9E3779B97F4A7C15`
  (Rust's k-mer hasher). This is nearly all of the 3.4x. **Items:** (a) `Map`'s probe is out of line
  (`MapCore.get…`/`put…`, now `upsert`), where khash's and this one are inlined into the loop;
  (b) the library's integer mixer is expensive and spreads dense keys badly, where one multiply and
  the top bits do; (c) `Map` keeps a separate occupancy representation where an integer key with a
  spare value could mark empties itself.
- **Tuned: the input is read into `realloc` storage** and decoded by index into a preallocated
  `[]u8` (`@unchecked`), in place of `read_all` and `Buf.push` per base. Peak memory 231 → 161 MiB.
  **Items:** finding 1's `read_all` and `grow`.

## 4. binarytrees — a 48-byte node, and two hook calls and a thread-local read per freed object

Each node is `malloc(48)`: a 24-byte header (strong count, drop hook, weak count) and a 24-byte enum
(tag and two references), against C's 16 bytes. The number of allocations is the same as C's. A
struct form with `Option[&Node]` children is no faster (1.50x), so the enum is not the cause.

Measured on sysl 0.10.7 at size 18 (exclusive run):

- **The size is worth about 4%, and the header cannot reach it.** C with `malloc(16)`, `malloc(32)` and
  `malloc(48)` takes 562, 606 and 643 ms. Packing the two counts into one word makes the box 40 bytes,
  which Darwin's malloc rounds to the same 48. Reaching 32 needs the hook pointer gone, and a
  type-erased release (a view's owner, a `&Trait`) has nothing else to find the destructor through.
- **The drop machinery was the rest.** Every child a hook let go of went through `arc.release` and
  `arc.reap` (a call and a thread-local ask, to find the drain already running), and an empty leaf
  then took two more hook calls to be freed.
- **Fixed on sysl dev (branch `header-shrink`, for 0.11):** the hook is handed the drain's slot and
  queues what it lets go of there, and a box with nothing in it to tear down (here every leaf) is freed
  on the spot. binarytrees went from 917.5 to 752.2 ms (-18%). The other programs did not move.
- **Left:** two counts in one word would pay on glibc, where a 48-byte box is a 64-byte chunk, but it
  changes the documented three-word header. That is a user decision.
- **Measured on sysl 0.11.0** (`results/2026-11-14.md`): 754 ms (1.19x C), against 893 ms (1.42x) on
  0.10.7, which matches the 752 ms the fix measured on dev.

**sysl-tuned, sysl 0.11.5** (exclusive run): 743 → **625 ms**, 1.02x C (Rust 1.19x).

- **Tuned: C's node.** `struct Node { left: *Node, right: *Node }`, allocated with an `extern
  malloc(sizeof(Node))` and given back by a recursive `delete` calling `extern free`: 16 bytes per
  node and no counting, the same allocations and frees as C. Peak memory 50 → 18 MiB. **Items:** the
  three-word counted header (32 bytes of overhead on a 16-byte payload, rounded to a 48-byte box)
  and the release path per freed node; the point above about two counts in one word is the first
  step, and a tree type whose nodes are never shared (unique ownership, no header) is the end of it.

## 5. nbody — no fix item left at 0.10.7

Idiomatic nbody runs at 0.91x C. Two workarounds were measured against it in the same run and are
not in `sysl-fast`:

- **Hoisting `bodies[i]`'s fields into locals by hand** before the inner loop, with the velocity
  accumulated in locals: 0.90x, so the reloads that possible aliasing between `bodies[i]` and
  `bodies[j]` forces cost nothing measurable now.
- **`extern "llvm.sqrt"` in place of `.sqrt()`**: not needed. `.sqrt()` compiles to `fsqrt` inline
  (ten `fsqrt` in the binary, no `bl` to a sqrt function).

The gap to Rust (0.58x) and C++ (0.71x) is their vectorized layouts, which `sysl-fast` expresses with
`<3>real` position and velocity.

**sysl-tuned, sysl 0.11.5** (exclusive run): **878 ms, unchanged**, 0.60x C (Rust 0.58x). One tuning
was tried and measured slower, so the program is the `<3>real` one above:

- **Tried: Rust's three passes** (the ten pair differences and squared distances into local arrays,
  then the ten magnitudes, then the velocities) over a constant body count, `@unchecked`. With
  `.sqrt()` the ten roots stayed scalar; with `extern "llvm.sqrt"` written as a scalar loop they
  stayed scalar too; only an explicit `<2>real` loop with `[root(s[0]), root(s[1])]` reached
  `fsqrt.2d`/`fdiv.2d`. It measured 912 ms against 878 (+4%) in the exclusive run. **Items:**
  (a) `real.sqrt` is an out-of-line call to the library, inlined only at the link, after LLVM's SLP
  vectorizer has run, so Rust's form cannot vectorize its roots in sysl; (b) a vector has no
  lane-wise `sqrt` (`type '<2>real' has no method 'sqrt'`), and `extern "llvm.sqrt"` with a vector
  type is refused ("takes and returns one floating-point type").

## 6. spectralnorm — the loop is C's, and the hand strength reduction changed the arithmetic

Idiomatic spectralnorm runs at 0.97x C, and its inner loop is C's instruction for instruction:

```
sysl                              C
sub   x17, x14, #0x1              sub   w15, w13, #0x1
mul   x17, x14, x17               mul   w15, w13, w15
add   x17, x13, x17, lsr #1       add   w15, w11, w15, lsr #1
ucvtf d2, x17                     scvtf d2, w15
fdiv  d2, d0, d2                  fdiv  d2, d0, d2
ldr   d3, [x15], #0x8             ldr   d3, [x14], #0x8
fmadd d1, d2, d3, d1              fmadd d1, d2, d3, d1
```

The `A^T` loop is already strength-reduced by LLVM in sysl (an `add` per column in place of the
`mul`). A hand-written form that advances the denominator by addition and divides `v[j] / d` measured
0.74x, but the speed comes from computing `v[j] / d` in place of `(1 / d) * v[j]`, one rounding fewer
and different arithmetic from C's, not from anything the compiler missed. There is no compiler item
here. Rust's 0.37x is its two-columns-per-step form. `sysl-fast` writes the same arithmetic: each
step loads two elements as a `<2>real` and divides them by the two columns' denominators in one
two-lane `fdiv`, and runs at 0.40x C. The denominators stay scalar integer arithmetic, as Rust's do:
its `usizex2` is a struct of two `usize`, which LLVM keeps in general registers. Computing them as a
`<2>usize` measured 0.57x, because NEON has no 64-bit lane multiply: every step moved both lanes out
to general registers for the `mul` and back, and the vector induction variable kept LLVM from
strength-reducing the `A^T` loop. clang emits the same loop for the same `vector_size(16)` C, so that
is the form, not the compiler.

**sysl-tuned, sysl 0.11.5** (exclusive run): 352 → **350 ms**, 0.39x C (Rust 0.37x).

- **Tuned: `@unchecked` around both products.** It removes a compare and branch per two columns
  (the `v.load(2 * j)` run check); ~8% in a dev pair, within noise in the exclusive run. **Item:**
  the check of `v.load(2 * j)` is not hoisted out of `for j in 0..<v.len / 2`, though `2 * j + 2 <=
  v.len` follows from the bound.

sysl builds with `--cpu native` (or `--cpu <llvm-name>`, from 0.11.3), the counterpart of C's
`-march=native`; against the generic-target build the geometric mean of `sysl-idiomatic` went from
1.01 to 1.00 and `sysl-fast` from 0.96 to 0.88 (that includes the spectralnorm form above; revcomp
moved from 2.08 to 1.92).

## 7. fannkuchredux — a flip is one shuffle, if the shuffle can be chosen at run time

**sysl-tuned, sysl 0.11.5** (exclusive run): 1323 → **1160 ms**, 0.79x C (Rust 0.97x).

- **Tuned: the permutation is a `<16>u8` and a flip of the first k + 1 is one constant shuffle**,
  built by a `const` function `reversal(K)` and reached through `flip(p, k)`, a 15-arm `match` on k
  to `flipped[K]`. Flips run until 0 leads (one more reversal per permutation than the scalar trick
  of counting the last flip without making it, since a lane cannot be read at a computed index), and
  the counting loop is `@unchecked`. Bought 12%. **Items:** (a) **a run-time lane selection** (AArch64
  `tbl`, x86 `pshufb`): the fastest form indexes a table of 16 reversal masks with k and does one
  `tbl`, where the `match` is an indirect branch per flip. `vectors.md` says it is deliberately absent
  ("keep the values in an array and index it"); this program is the case for it. (b) A lane read at a
  computed index (`v[k]`) is refused for the same reason.

## 8. mandelbrot — the escape test

**sysl-tuned, sysl 0.11.5** (exclusive run): 280 → **243 ms**, 0.27x C (Rust 0.41x).

- **Tuned: the escape test runs every fifth iteration** (ten groups of five, still at most 50). An
  escaped pixel only grows, or overflows to infinity or NaN, which fail `<= 4.0` as well, so the
  image is the same (verified). Bought 13%. **Item:** none; it is a choice of schedule no compiler
  makes, and the C++ entries make it by hand too.

## Language gaps and diagnostics found while writing the programs

- **A scalar on the LEFT of a vector operator is refused where nothing gives the expression a type**
  (sysl 0.11.5), though `vectors.md` says either side may be a scalar that broadcasts. `val m = dt / v`
  with `dt: real` and `v: <2>real` reports "'/' needs matching types, got real and <2>real", and so
  does `dt * v`; `v * dt`, `-> <2>real = dt / v` and `val m: <2>real = dt / v` are accepted. The same
  holds inside `xs.store(i, dt / v)`. An array literal on the right (`v * [2.0, 3.0]`) is refused the
  same way in a `store` argument ("got <2>real and [2]real"), though `sum += top / [a, b]` is
  accepted. A bug, by the page's own words.

- `const pi = 3.14159...; const c = 4 * pi` is refused with "the value of 'c' is not a constant
  expression"; `4.0 * pi` is accepted.
- `const line_len = 60` does not adapt where a `usize` is expected ("'b' of 'sysl.math.min' is int,
  but usize was given"), although the literal `60` does.
- `val es: Buf[E]; sort_by(es.view_mut(), (a, b) -> a.c > b.c)` reports "'a' has no type here" when
  the real error is `view_mut` on a `val`. With `var`, the closure's parameter types are inferred.
