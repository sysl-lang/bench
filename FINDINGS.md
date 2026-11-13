# Findings

Where idiomatic sysl takes more than 1.2x as long as C, and why. Each finding is one fix item for the
compiler or the standard library. Figures are from `results/2026-11-13.md` (sysl 0.10.6, exclusive
run, wall-clock ratio to C).

| program | sysl-idiomatic | sysl-tuned |
|---|---:|---:|
| revcomp | 3.57 | 1.61 |
| fasta | 3.19 | 1.18 |
| knucleotide | 2.68 | 1.67 |
| binarytrees | 1.65 | 1.77 |
| nbody | 1.57 | 0.91 |

## 1. revcomp — `Buf.push` is a real call per byte

The hot loop `out.push(seq[..])` compiles to `bl _sysl.buf$Buf.push.byte` for every byte. The
standard library is linked as an archive, so none of its functions are inlined; C does a pointer
store.

- **Suspect:** `Buf.push` is not inlined. Make the fast path `@inline` and the growth path
  `@cold @noinline`.
- **Reduction:** `val b: Buf[u8] = buf(); for i in 0..<100000000 do b.push(u8(i))`

## 2. fasta — generator state goes through memory every symbol

The random generator's state sits behind `*Random` and is stored back to memory for every symbol
(`str w9,[x23]`). There is an `fdiv` per symbol, and the lookup is a bounds-checked,
data-dependent `while cumulative[k] < r` loop. C keeps the seed in a register and counts
`v > p[j]` without branches.

- **Suspect:** no noalias/TBAA information separates the pointee from the local `[61]u8` line, so
  LLVM cannot keep `last` in a register.

## 3. knucleotide — two out-of-line map calls per position, and a costly hash

`counts.put(key, counts.get_or(key, 0) + 1)` makes two out-of-line calls per position
(`MapCore.get.ulong.int.owned` and `MapCore.put.ulong.int`), where khash does one inlined probe.

- `Map` has no upsert or entry operation.
- A newtype key with a one-multiply `impl Hash` alone took it from 2.68x to 1.67x, so the library's
  integer mixer, or its distribution on dense keys, is expensive.
- `map_with_capacity` made no difference.

## 4. binarytrees — a 48-byte node and a thread-local read on every drop

Each node is `malloc(48)`, carrying a refcount, a drop-function pointer, a size and a tag, against
C's 16 bytes. The drop goes through `l_arc.reap`, which reads thread-local state. The number of
allocations is the same as C's. The tuned struct form is no faster (1.77x), so the enum is not the
cause.

## 5. nbody — field reloads blocked by possible aliasing

In the inner loop, the fields of `bodies[i]` and `bodies[j].mass` are reloaded on every iteration,
because the stores to `bodies[j]` might alias them. C hoists them and SLP-vectorises the loop (28
instructions against 40). The IR also emits a whole-struct load for every field read.

- **Secondary:** `d2.sqrt()` is `bl _real.sqrt`. The `extern "llvm.sqrt"` intrinsic gave `fsqrt`, but
  no speedup on its own.

## Language gaps and diagnostics found while writing the programs

- `const pi = 3.14159...; const c = 4 * pi` is refused with "the value of 'c' is not a constant
  expression"; `4.0 * pi` is accepted.
- `const line_len = 60` does not adapt where a `usize` is expected ("'b' of 'sysl.math.min' is int,
  but usize was given"), although the literal `60` does.
- `val es: Buf[E]; sort_by(es.view_mut(), (a, b) -> a.c > b.c)` reports "'a' has no type here" when
  the real error is `view_mut` on a `val`. With `var`, the closure's parameter types are inferred.
- sysl has no equivalent of `-march=native`, while C and C++ are built with it.
