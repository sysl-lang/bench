/*
   The Computer Language Benchmarks Game
   https://salsa.debian.org/benchmarksgame-team/benchmarksgame/

   contributed by Piotr Tarsa

   Adapted for this suite: one thread (the executor's tasks are called in
   turn), and the jextract-generated jextract_pcre2.pcre2_h replaced by the
   hand-written downcalls in the nested class pcre2_h below, which bind the
   same PCRE2 functions through java.lang.foreign.
*/

import java.lang.foreign.Arena;
import java.lang.foreign.FunctionDescriptor;
import java.lang.foreign.Linker;
import java.lang.foreign.MemorySegment;
import java.lang.foreign.SymbolLookup;
import java.lang.invoke.MethodHandle;
import java.nio.charset.StandardCharsets;
import java.util.Arrays;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Map.Entry;
import java.util.concurrent.Callable;
import java.util.function.Consumer;
import java.util.function.Function;

import java.lang.foreign.ValueLayout;

import static java.lang.foreign.ValueLayout.*;

public class regexredux {
    // The part of jextract's pcre2_h this program uses, written out.
    static final class pcre2_h {
        static final ValueLayout.OfLong int64_t = JAVA_LONG;

        static MemorySegment NULL() { return MemorySegment.NULL; }
        static int PCRE2_JIT_COMPLETE() { return 0x00000001; }
        static int PCRE2_SUBSTITUTE_GLOBAL() { return 0x00000100; }
        static int PCRE2_NO_UTF_CHECK() { return 0x40000000; }
        static int PCRE2_ERROR_NOMATCH() { return -1; }

        private static final Linker LINKER = Linker.nativeLinker();
        private static final SymbolLookup LIB = load();

        private static SymbolLookup load() {
            // Homebrew's first: macOS has a libpcre2-8 of its own, built without the JIT.
            String[] names = { "/opt/homebrew/lib/libpcre2-8.dylib", "/usr/local/lib/libpcre2-8.dylib",
                               "libpcre2-8.so.0", "libpcre2-8.dylib" };
            for (String name : names) {
                try {
                    return SymbolLookup.libraryLookup(name, Arena.global());
                } catch (IllegalArgumentException e) {
                    // try the next place
                }
            }
            throw new IllegalStateException("libpcre2-8 not found");
        }

        private static MethodHandle fn(String name, FunctionDescriptor d) {
            return LINKER.downcallHandle(LIB.find(name).orElseThrow(), d);
        }

        private static final MethodHandle COMPILE = fn("pcre2_compile_8",
                FunctionDescriptor.of(ADDRESS, ADDRESS, JAVA_LONG, JAVA_INT, ADDRESS, ADDRESS, ADDRESS));
        private static final MethodHandle JIT_COMPILE = fn("pcre2_jit_compile_8",
                FunctionDescriptor.of(JAVA_INT, ADDRESS, JAVA_INT));
        private static final MethodHandle MATCH_DATA_CREATE = fn("pcre2_match_data_create_8",
                FunctionDescriptor.of(ADDRESS, JAVA_INT, ADDRESS));
        private static final MethodHandle GET_OVECTOR_POINTER = fn("pcre2_get_ovector_pointer_8",
                FunctionDescriptor.of(ADDRESS, ADDRESS));
        private static final MethodHandle JIT_MATCH = fn("pcre2_jit_match_8",
                FunctionDescriptor.of(JAVA_INT, ADDRESS, ADDRESS, JAVA_LONG, JAVA_LONG, JAVA_INT, ADDRESS, ADDRESS));
        private static final MethodHandle SUBSTITUTE = fn("pcre2_substitute_8",
                FunctionDescriptor.of(JAVA_INT, ADDRESS, ADDRESS, JAVA_LONG, JAVA_LONG, JAVA_INT, ADDRESS,
                        ADDRESS, ADDRESS, JAVA_LONG, ADDRESS, ADDRESS));
        private static final MethodHandle GET_ERROR_MESSAGE = fn("pcre2_get_error_message_8",
                FunctionDescriptor.of(JAVA_INT, JAVA_INT, ADDRESS, JAVA_LONG));

        static MemorySegment pcre2_compile_8(MemorySegment pattern, long length, int options,
                MemorySegment errorcode, MemorySegment erroroffset, MemorySegment ccontext) {
            try {
                return (MemorySegment) COMPILE.invokeExact(pattern, length, options, errorcode, erroroffset, ccontext);
            } catch (Throwable t) { throw new AssertionError(t); }
        }

        static int pcre2_jit_compile_8(MemorySegment code, int options) {
            try {
                return (int) JIT_COMPILE.invokeExact(code, options);
            } catch (Throwable t) { throw new AssertionError(t); }
        }

        static MemorySegment pcre2_match_data_create_8(int ovecsize, MemorySegment gcontext) {
            try {
                return (MemorySegment) MATCH_DATA_CREATE.invokeExact(ovecsize, gcontext);
            } catch (Throwable t) { throw new AssertionError(t); }
        }

        static MemorySegment pcre2_get_ovector_pointer_8(MemorySegment matchData) {
            try {
                return (MemorySegment) GET_OVECTOR_POINTER.invokeExact(matchData);
            } catch (Throwable t) { throw new AssertionError(t); }
        }

        static int pcre2_jit_match_8(MemorySegment code, MemorySegment subject, long length, long startoffset,
                int options, MemorySegment matchData, MemorySegment mcontext) {
            try {
                return (int) JIT_MATCH.invokeExact(code, subject, length, startoffset, options, matchData, mcontext);
            } catch (Throwable t) { throw new AssertionError(t); }
        }

        static int pcre2_substitute_8(MemorySegment code, MemorySegment subject, long length, long startoffset,
                int options, MemorySegment matchData, MemorySegment mcontext, MemorySegment replacement,
                long rlength, MemorySegment outputbuffer, MemorySegment outlengthptr) {
            try {
                return (int) SUBSTITUTE.invokeExact(code, subject, length, startoffset, options, matchData,
                        mcontext, replacement, rlength, outputbuffer, outlengthptr);
            } catch (Throwable t) { throw new AssertionError(t); }
        }

        static int pcre2_get_error_message_8(int errorcode, MemorySegment buffer, long bufflen) {
            try {
                return (int) GET_ERROR_MESSAGE.invokeExact(errorcode, buffer, bufflen);
            } catch (Throwable t) { throw new AssertionError(t); }
        }
    }

    private static final Arena GLOBAL_ARENA = Arena.global();

    public static void main(String[] args) throws Exception {
        final byte[] rawInput = System.in.readAllBytes();
        final int initialLength = rawInput.length;

        final var sequence = GLOBAL_ARENA.allocate(initialLength);
        final int sequenceLength = withArena(arena -> {
            var rawInputBuffer = arena.allocateFrom(JAVA_BYTE, rawInput);
            var compiledPattern = compilePattern(">.*\\n|\\n");
            return substitute(compiledPattern, rawInputBuffer, initialLength,
                    pcre2_h.NULL(), sequence, initialLength, "");
        });

        Callable<Integer> magicRegExpsCount = () -> {
            final Map<String, String> iub = new LinkedHashMap<>();
            iub.put("tHa[Nt]", "<4>");
            iub.put("aND|caN|Ha[DS]|WaS", "<3>");
            iub.put("a[NSt]|BY", "<2>");
            iub.put("<[^>]*>", "|");
            iub.put("\\|[^|][^|]*\\|", "-");

            return withArena(arena -> {
                var currentLength = sequenceLength;
                var bufLength = currentLength * 3 / 2;
                var buf1 = arena.allocate(bufLength);
                var buf2 = arena.allocate(bufLength);
                MemorySegment.copy(sequence, 0, buf1, 0, sequenceLength);
                var flip = false;

                for (Entry<String, String> entry : iub.entrySet()) {
                    var pattern = entry.getKey();
                    var replacement = entry.getValue();

                    var compiledPattern = compilePattern(pattern);
                    currentLength = substitute(compiledPattern,
                            flip ? buf2 : buf1, currentLength,
                            pcre2_h.NULL(),
                            flip ? buf1 : buf2, bufLength,
                            replacement);
                    flip = !flip;
                }
                return currentLength;
            });
        };

        var variants = Arrays.asList("agggtaaa|tttaccct",
                "[cgt]gggtaaa|tttaccc[acg]",
                "a[act]ggtaaa|tttacc[agt]t",
                "ag[act]gtaaa|tttac[agt]ct",
                "agg[act]taaa|ttta[agt]cct",
                "aggg[acg]aaa|ttt[cgt]ccct",
                "agggt[cgt]aa|tt[acg]accct",
                "agggta[cgt]a|t[acg]taccct",
                "agggtaa[cgt]|[acg]ttaccct");

        var tasks = variants.stream().map(variant -> (Callable<String>) () -> {
            var compiledPattern = compilePattern(variant);
            var oVectorSize = 100;
            var matchData = pcre2_h
                    .pcre2_match_data_create_8(oVectorSize, pcre2_h.NULL());
            var oVectorPtr = pcre2_h
                    .pcre2_get_ovector_pointer_8(matchData)
                    .reinterpret(16 * oVectorSize);
            oVectorPtr.setAtIndex(JAVA_LONG, 1, 0);
            long count = 0;
            var result = 1;
            while ((result = pcre2_h.pcre2_jit_match_8(compiledPattern,
                    sequence, sequenceLength,
                    oVectorPtr.getAtIndex(JAVA_LONG, 2L * result - 1), 0,
                    matchData, pcre2_h.NULL())) > 0) count += result;
            if (result != pcre2_h.PCRE2_ERROR_NOMATCH()) {
                showPcre2ErrorIfAny("jit match", result);
            }
            return variant + " " + count;
        }).toList();

        for (var task : tasks) {
            System.out.println(task.call());
        }

        System.out.println();
        System.out.println(initialLength);
        System.out.println(sequenceLength);
        System.out.println(magicRegExpsCount.call());
    }

    private static int substitute(
            MemorySegment compiledPattern,
            MemorySegment inputBuffer, int inputLength,
            MemorySegment matchContext,
            MemorySegment outputBuffer, int outputBufferLength,
            String replacement) {
        return withArena(arena -> {
            var replacementBytes =
                    replacement.getBytes(StandardCharsets.US_ASCII);
            var replacementBuffer = arena.allocateFrom(
                    JAVA_BYTE, replacementBytes);
            var outputLengthHolder = arena.allocate(JAVA_LONG);
            outputLengthHolder.setAtIndex(JAVA_LONG, 0, outputBufferLength);
            var options = pcre2_h.PCRE2_SUBSTITUTE_GLOBAL() |
                    pcre2_h.PCRE2_NO_UTF_CHECK();
            var substitutionResult = pcre2_h.pcre2_substitute_8(
                    compiledPattern,
                    inputBuffer, inputLength,
                    0, options, pcre2_h.NULL(),
                    matchContext,
                    replacementBuffer, replacementBytes.length,
                    outputBuffer, outputLengthHolder);
            showPcre2ErrorIfAny("substitutionResult", substitutionResult);
            return substitutionResult < 0 ?
                    0 : outputLengthHolder.getAtIndex(JAVA_INT, 0);
        });
    }

    private static MemorySegment compilePattern(String pattern) {
        return withArena(arena -> {
            var patternBytes = pattern.getBytes(StandardCharsets.US_ASCII);
            var patternLength = patternBytes.length;
            var bufPattern = arena.allocateFrom(JAVA_BYTE, patternBytes);
            var bufErrorCode = arena.allocate(pcre2_h.int64_t);
            var bufErrorOffset = arena.allocate(pcre2_h.int64_t);
            var compiledPattern = pcre2_h.pcre2_compile_8(
                    bufPattern, patternLength, 0,
                    bufErrorCode, bufErrorOffset, pcre2_h.NULL());
            if (compiledPattern.equals(pcre2_h.NULL())) {
                showPcre2Error("pcre2_compile_8 failed at offset " +
                                bufErrorOffset.getAtIndex(JAVA_INT, 0),
                        bufErrorCode.getAtIndex(JAVA_INT, 0));
            }
            var jitCompileResult = pcre2_h.pcre2_jit_compile_8(
                    compiledPattern, pcre2_h.PCRE2_JIT_COMPLETE());
            showPcre2ErrorIfAny("pcre_2jit_compile_8", jitCompileResult);
            return compiledPattern;
        });
    }

    private static void showPcre2ErrorIfAny(
            String description, int resultOrErrorCode) {
        if (resultOrErrorCode < 0) {
            showPcre2Error(description, resultOrErrorCode);
        }
    }

    private static void showPcre2Error(String description, int errorCode) {
        withArena(arena -> {
            var bufSize = 1000;
            var buf = arena.allocate(bufSize);
            var errorMsgLength = pcre2_h.pcre2_get_error_message_8(
                    errorCode, buf, bufSize);
            if (errorMsgLength >= 0) {
                var errorMsgBytes = new byte[errorMsgLength];
                buf.asByteBuffer().get(errorMsgBytes);
                var errorMsg = new String(errorMsgBytes, 0, errorMsgLength,
                        StandardCharsets.US_ASCII);
                new Exception(description + " " + errorCode +
                        " = " + errorMsg).printStackTrace(System.out);
            } else {
                new Exception(description +
                        " Error during getting error message: " +
                        errorMsgLength).printStackTrace(System.out);
            }
        });
    }

    private static void withArena(Consumer<Arena> body) {
        try (var arena = Arena.ofConfined()) {
            body.accept(arena);
        }
    }

    private static <T> T withArena(Function<Arena, T> body) {
        try (var arena = Arena.ofConfined()) {
            return body.apply(arena);
        }
    }
}
