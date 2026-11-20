/* The Computer Language Benchmarks Game
 * https://salsa.debian.org/benchmarksgame-team/benchmarksgame/
 *
 * regex-dna program contributed by The Go Authors.
 * modified by Tylor Arndt.
 * modified by Chandra Sekar S to use optimized PCRE binding.
 * modified by Matt Dellandrea.
 * modified by Pavel Griaznov to use PCRE JIT compilation.
 *
 * Adapted for this suite: one goroutine, and the github.com/GRbit/go-pcre
 * module (cgo over the retired PCRE1) replaced by the few cgo calls into
 * PCRE2 below, JIT-compiled and matched with pcre2_jit_match as the C
 * program does.
 */

package main

/*
#cgo pkg-config: libpcre2-8
#define PCRE2_CODE_UNIT_WIDTH 8
#include <pcre2.h>
#include <stdlib.h>
*/
import "C"

import (
    "fmt"
    "io/ioutil"
    "os"
    "unsafe"
)

type regex struct {
    code  *C.pcre2_code_8
    mdata *C.pcre2_match_data_8
    mctx  *C.pcre2_match_context_8
    ov    *C.PCRE2_SIZE
}

func mustCompileJIT(pat string) *regex {
    p := C.CString(pat)
    defer C.free(unsafe.Pointer(p))
    var errcode C.int
    var erroff C.PCRE2_SIZE
    code := C.pcre2_compile_8((*C.uchar)(unsafe.Pointer(p)), C.PCRE2_SIZE(len(pat)), 0, &errcode, &erroff, nil)
    if code == nil {
        panic("bad pattern " + pat)
    }
    if C.pcre2_jit_compile_8(code, C.PCRE2_JIT_COMPLETE) != 0 {
        panic("JIT compile failed")
    }
    mctx := C.pcre2_match_context_create_8(nil)
    stack := C.pcre2_jit_stack_create_8(16384, 16384, nil)
    C.pcre2_jit_stack_assign_8(mctx, nil, unsafe.Pointer(stack))
    mdata := C.pcre2_match_data_create_8(16, nil)
    return &regex{code, mdata, mctx, C.pcre2_get_ovector_pointer_8(mdata)}
}

// Finds the leftmost match at or after pos; answers its start and end, or ok false.
func (r *regex) find(b []byte, pos int) (int, int, bool) {
    if len(b) == 0 {
        return 0, 0, false
    }
    rc := C.pcre2_jit_match_8(r.code, (*C.uchar)(unsafe.Pointer(&b[0])), C.PCRE2_SIZE(len(b)),
        C.PCRE2_SIZE(pos), 0, r.mdata, r.mctx)
    if rc < 0 {
        return 0, 0, false
    }
    ov := (*[2]C.PCRE2_SIZE)(unsafe.Pointer(r.ov))
    return int(ov[0]), int(ov[1]), true
}

func (r *regex) ReplaceAll(b []byte, repl []byte) []byte {
    out := make([]byte, 0, len(b)+len(b)/10)
    pos := 0
    for {
        s, e, ok := r.find(b, pos)
        if !ok {
            break
        }
        out = append(out, b[pos:s]...)
        out = append(out, repl...)
        pos = e
    }
    return append(out, b[pos:]...)
}

func countMatches(pat string, b []byte) int {
    r := mustCompileJIT(pat)
    n := 0
    pos := 0

    for {
        _, e, ok := r.find(b, pos)
        if !ok {
            break
        }
        n++
        pos = e
    }

    return n
}

type substitution struct {
    pattern     string
    replacement string
}

func main() {
    var variants = []string{
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

    var substs = []substitution{
        {"tHa[Nt]", "<4>"},
        {"aND|caN|Ha[DS]|WaS", "<3>"},
        {"a[NSt]|BY", "<2>"},
        {"<[^>]*>", "|"},
        {"\\|[^|][^|]*\\|", "-"},
    }

    b, err := ioutil.ReadAll(os.Stdin)
    if err != nil {
        fmt.Fprintf(os.Stderr, "can't read input: %s\n", err)
        os.Exit(2)
    }

    ilen := len(b)

    // Delete the comment lines and newlines
    b = mustCompileJIT("(>[^\n]*)?\n").ReplaceAll(b, []byte{})
    clen := len(b)

    for i := 0; i < len(variants); i++ {
        fmt.Printf("%s %d\n", variants[i], countMatches(variants[i], b))
    }

    r := b
    for i := 0; i < len(substs); i++ {
        r = mustCompileJIT(substs[i].pattern).ReplaceAll(r, []byte(substs[i].replacement))
    }

    fmt.Printf("\n%d\n%d\n%d\n", ilen, clen, len(r))
}
