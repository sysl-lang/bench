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

## 1. revcomp — the buffer's header is reloaded and stored on every push

`Buf.push` is already inlined in an optimised build: a store, a length bump and a cold out-of-line
`grow_store`. But the loop in `write_reversed` costs about 10 instructions and 4 memory operations per
byte (`ldp cap,len` / cmp / `ldr data` / `strb` / `str len` / `ldr cap` / cmp + branch), where C keeps
a pointer in a register.

- **Cause:** LLVM is not told that the byte store through the element storage cannot alias the
  `BufCore` header, so data, len and cap are reloaded and len is stored back for every byte. The
  `count <= elems.len` re-check after each store (deliberate, `library/sysl/buf/buf.sysl`) cannot fold
  away for the same reason. There is also a bounds check on `seq[i-1-j]`.
- **Fix:** alias information (scoped `!alias.scope`/`!noalias`, or TBAA) that separates a
  container's slot storage from struct-field accesses. This is the same cause as finding 2.
- Writing the output by index into one preallocated array measured 1.65x. It would be pointless once
  `push` keeps its header in registers, so it is a workaround and is not in `sysl-fast`.
- **Done for 0.11 (branch `buf-alias-scope`):** the header and element scopes already marked every
  `BufCore` field and `b[i]`, but the store `push` makes (`slot_place`) carried none. It now carries
  the element scope, so the capacity is no longer read again after each store, and where nothing
  else in the loop branches out, the count and capacity stay in registers. The data pointer is still
  loaded once per element, because LLVM will not reload it after the growth call. Timed under
  `--exclusive`: 295.0 ms before, 289.9 ms after (-1.7%). With the source read `@unchecked` the times
  are 180.1 ms and 162.6 ms (-10%). None of the other seven programs got slower.
- **What is left is the bounds check on `seq[i-1-j]`.** With the same compiler, checked takes 305 ms
  and unchecked 180 ms. The check is a branch out of the loop on every byte. It also stops GVN's load
  PRE from carrying the header across iterations, so the count, capacity and data pointer are read
  again for every byte. Even a check LLVM can prove (`seq[seq.len - 1 - j]`) is folded only after
  GVN has run. This needs its own item: subscript checks folded or hoisted before GVN.

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
here. The gap to Rust (0.37x) is its two-columns-per-step form, which sysl cannot write with vectors
(below).

## Language gaps and diagnostics found while writing the programs

- `const pi = 3.14159...; const c = 4 * pi` is refused with "the value of 'c' is not a constant
  expression"; `4.0 * pi` is accepted.
- `const line_len = 60` does not adapt where a `usize` is expected ("'b' of 'sysl.math.min' is int,
  but usize was given"), although the literal `60` does.
- `val es: Buf[E]; sort_by(es.view_mut(), (a, b) -> a.c > b.c)` reports "'a' has no type here" when
  the real error is `view_mut` on a `val`. With `var`, the closure's parameter types are inferred.
- sysl has no equivalent of `-march=native`, while C and C++ are built with it.
- **A vector has no lane-wise conversion between lane types.** Rust's spectralnorm computes the
  integer denominators of two columns and converts them to two doubles; in sysl that is a `<2>usize`
  to `<2>real`, and neither spelling is accepted:

  ```
  val i: <2>usize = [3, 4]
  val f: <2>real = i      // cannot initialize 'f': declared <2>real but the value is <2>usize
  val g = <2>real(i)      // expression expected
  ```

  The vectors reference page lists no such conversion ("Nothing converts through anything else"), so
  this is a gap rather than a bug. Integer `/` is refused on vectors by design; the halving would be
  `>> 1`. `sysl-fast` spectralnorm stays a copy of the idiomatic program until the conversion exists.
