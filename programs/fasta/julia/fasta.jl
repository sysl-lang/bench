# The Computer Language Benchmarks Game: fasta. Same algorithm as the C version
# (linear symbol lookup, LINELEN-wide lines). Output goes through a 64 KiB buffer that is
# written to standard output when full, standing in for the stdio buffering the C version uses.

const IM = UInt32(139968)
const IA = UInt32(3877)
const IC = UInt32(29573)
const LINELEN = 60

mutable struct Out
    buf::Vector{UInt8}
    len::Int
end

function flush!(o::Out)
    unsafe_write(stdout, pointer(o.buf), o.len)
    o.len = 0
end

function put!(o::Out, src::Vector{UInt8}, from::Int, n::Int)
    if o.len + n > length(o.buf)
        flush!(o)
    end
    copyto!(o.buf, o.len + 1, src, from, n)
    o.len += n
end

function putc!(o::Out, c::UInt8)
    if o.len == length(o.buf)
        flush!(o)
    end
    o.len += 1
    o.buf[o.len] = c
end

put!(o::Out, s::String) = (b = Vector{UInt8}(s); put!(o, b, 1, length(b)))

mutable struct Rng
    seed::UInt32
end

@inline function fasta_rand!(r::Rng)
    r.seed = (r.seed * IA + IC) % IM
    return 1.0 * Float64(r.seed) / Float64(IM)
end

const alu = string(
    "GGCCGGGCGCGGTGGCTCACGCCTGTAATCCCAGCACTTTGG",
    "GAGGCCGAGGCGGGCGGATCACCTGAGGTCAGGAGTTCGAGA",
    "CCAGCCTGGCCAACATGGTGAAACCCCGTCTCTACTAAAAAT",
    "ACAAAAATTAGCCGGGCGTGGTGGCGCGCGCCTGTAATCCCA",
    "GCTACTCGGGAGGCTGAGGCAGGAGAATCGCTTGAACCCGGG",
    "AGGCGGAGGTTGCAGTGAGCCGAGATCGCGCCACTGCACTCC",
    "AGCCTGGGCGACAGAGCGAGACTCCGTCTCAAAAA")

const iub = Vector{UInt8}("acgtBDHKMNRSVWY")
const iub_p = [0.27, 0.12, 0.12, 0.27, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02]

const homosapiens = Vector{UInt8}("acgt")
const homosapiens_p = [0.3029549426680, 0.1979883004921, 0.1975473066391, 0.3015094502008]

function repeat_fasta(o::Out, seq::String, n::Int)
    s = Vector{UInt8}(seq)
    len = length(s)
    buffer = vcat(s, s[1:LINELEN])

    t = 0
    whole_lines = n ÷ LINELEN
    for _ in 1:whole_lines
        put!(o, buffer, t % len + 1, LINELEN)
        putc!(o, UInt8('\n'))
        t += LINELEN
    end
    put!(o, buffer, t % len + 1, n - t)
    if n % LINELEN != 0
        putc!(o, UInt8('\n'))
    end
end

@inline function linear_lookup(len::Int, p::Vector{Float64}, v::Float64)
    i = 0
    for j in 1:len-1
        if v > p[j]
            i += 1
        end
    end
    return i
end

function random_fasta(o::Out, r::Rng, symb::Vector{UInt8}, probability::Vector{Float64}, n::Int)
    len = length(symb)
    p = zeros(Float64, len)
    buffer = zeros(UInt8, LINELEN + 1)
    buffer[LINELEN+1] = UInt8('\n')

    p[1] = probability[1]
    for i in 2:len
        p[i] = probability[i] + p[i-1]
    end

    lines = n ÷ LINELEN
    for _ in 1:lines
        for k in 1:LINELEN
            v = fasta_rand!(r)
            buffer[k] = symb[linear_lookup(len, p, v)+1]
        end
        put!(o, buffer, 1, LINELEN + 1)
    end
    remainder = n - lines * LINELEN
    for k in 1:remainder
        v = fasta_rand!(r)
        buffer[k] = symb[linear_lookup(len, p, v)+1]
    end
    put!(o, buffer, 1, remainder)
    if n % LINELEN != 0
        putc!(o, UInt8('\n'))
    end
end

function main(n::Int)
    o = Out(Vector{UInt8}(undef, 1 << 16), 0)
    r = Rng(UInt32(42))

    put!(o, ">ONE Homo sapiens alu\n")
    repeat_fasta(o, alu, n * 2)

    put!(o, ">TWO IUB ambiguity codes\n")
    random_fasta(o, r, iub, iub_p, n * 3)

    put!(o, ">THREE Homo sapiens frequency\n")
    random_fasta(o, r, homosapiens, homosapiens_p, n * 5)

    flush!(o)
end

main(length(ARGS) > 0 ? parse(Int, ARGS[1]) : 1000)
