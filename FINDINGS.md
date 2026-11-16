# Findings

Where sysl loses to C, and why. Each finding is one fix item for the compiler or the standard library.
A speed-up that only a workaround in the source reaches (one that would be pointless once the
compiler does its job) is recorded here and not written into `sysl-fast`. Figures are from
`results/2026-11-13.md` (sysl 0.10.7, wall-clock ratio to C).

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
it is a workaround for this, so it is not in `sysl-fast`. The `fdiv` per symbol is C's too. Counting
`r > p` over the 14-entry IUB table is vectorized as one 8-wide block plus a scalar tail of 6
compare-and-increment steps, the same work as C's count. Integer thresholds in place of the
floating-point comparison would change the work, so neither form uses them.

- **Suspect:** no noalias/TBAA information separates the pointee from the local `[61]u8` line, so
  LLVM cannot keep `last` in a register.

## 3. knucleotide — two out-of-line map calls per position, and a costly hash

`counts.put(key, counts.get_or(key, 0) + 1)` makes two out-of-line calls per position
(`MapCore.get.ulong.int.owned` and `MapCore.put.ulong.int`), where khash does one inlined probe.

- `Map` has no upsert or entry operation.
- A newtype key with a one-multiply `impl Hash` alone took it from 2.68x to 1.67x, so the library's
  integer mixer, or its distribution on dense keys, is expensive.
- `map_with_capacity` made no difference.
- The newtype key would be pointless with a cheaper library mixer, so it is a workaround and is not in
  `sysl-fast`; neither is decoding the sequence into a preallocated array in place of `Buf.push`
  (finding 1).

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

sysl builds with `--cpu native` (or `--cpu <llvm-name>`, from 0.11.3), the counterpart of C's
`-march=native`; against the generic-target build the geometric mean of `sysl-idiomatic` went from
1.01 to 1.00 and `sysl-fast` from 0.96 to 0.88 (that includes the spectralnorm form above; revcomp
moved from 2.08 to 1.92).

## Language gaps and diagnostics found while writing the programs

- `const pi = 3.14159...; const c = 4 * pi` is refused with "the value of 'c' is not a constant
  expression"; `4.0 * pi` is accepted.
- `const line_len = 60` does not adapt where a `usize` is expected ("'b' of 'sysl.math.min' is int,
  but usize was given"), although the literal `60` does.
- `val es: Buf[E]; sort_by(es.view_mut(), (a, b) -> a.c > b.c)` reports "'a' has no type here" when
  the real error is `view_mut` on a `val`. With `var`, the closure's parameter types are inferred.
