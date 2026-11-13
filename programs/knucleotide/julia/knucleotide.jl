# The Computer Language Benchmarks Game: k-nucleotide. Same algorithm as the C version:
# one pass per oligonucleotide length over the encoded sequence, counting 2-bit keys in a hash
# table (here the standard library's Dict), run sequentially.
using Printf

# A=0, C=1, G=2, T=3, for either case.
@inline function code_for_nucleotide(c::UInt8)::UInt8
    m = c & 0x07
    return m == 3 ? 0x01 : m == 7 ? 0x02 : m == 4 ? 0x03 : 0x00
end

function count_all(poly::Vector{UInt8}, len::Int)
    d = Dict{UInt64,UInt32}()
    key = UInt64(0)
    mask = (UInt64(1) << (2 * len)) - UInt64(1)
    for i in 1:len-1
        key = ((key << 2) & mask) | poly[i]
    end
    for i in len:length(poly)
        key = ((key << 2) & mask) | poly[i]
        d[key] = get(d, key, UInt32(0)) + UInt32(1)
    end
    return d
end

function frequencies(poly::Vector{UInt8}, len::Int)
    d = count_all(poly, len)
    elements = collect(d)
    sort!(elements, lt = (a, b) -> a[2] != b[2] ? a[2] > b[2] : a[1] < b[1])

    total = Float32(length(poly) - len + 1)
    for (k, v) in elements
        name = Vector{UInt8}(undef, len)
        key = k
        for j in len:-1:1
            name[j] = UInt8("ACGT"[Int(key & 3)+1])
            key >>= 2
        end
        pct = Float32(100) * Float32(v) / total
        @printf("%s %.3f\n", String(name), Float64(pct))
    end
    println()
end

function count(poly::Vector{UInt8}, oligo::String)
    d = count_all(poly, length(oligo))
    key = UInt64(0)
    for c in codeunits(oligo)
        key = (key << 2) | code_for_nucleotide(c)
    end
    println(get(d, key, UInt32(0)), "\t", oligo)
end

function main()
    input = read(stdin)
    n = length(input)

    # Find the start of the third polynucleotide.
    pos = 1
    three = codeunits(">THREE")
    while pos <= n && !(pos + 5 <= n && view(input, pos:pos+5) == three)
        nl = findnext(==(UInt8('\n')), input, pos)
        pos = nl === nothing ? n + 1 : nl + 1
    end
    nl = findnext(==(UInt8('\n')), input, pos)
    pos = nl === nothing ? n + 1 : nl + 1

    poly = UInt8[]
    sizehint!(poly, max(n - pos + 1, 0))
    while pos <= n && input[pos] != UInt8('>')
        e = findnext(==(UInt8('\n')), input, pos)
        e = e === nothing ? n + 1 : e
        for i in pos:e-1
            push!(poly, code_for_nucleotide(input[i]))
        end
        pos = e + 1
    end

    frequencies(poly, 1)
    frequencies(poly, 2)
    count(poly, "GGT")
    count(poly, "GGTA")
    count(poly, "GGTATT")
    count(poly, "GGTATTTTAATT")
    count(poly, "GGTATTTTAATTTATAGT")
end

main()
