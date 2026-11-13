# The Computer Language Benchmarks Game: reverse-complement. Same algorithm as the C version:
# each sequence line is complemented through a 256-entry table (characters without an entry are
# dropped) and the record is stored reversed, then written in 60-column lines. Input is read in
# bulk, each record is compacted and reversed in place, and the output is built in one buffer.

function make_table()
    xtab = zeros(UInt8, 256)
    from = codeunits("ABCDGHKMNRSTVWY")
    to = codeunits("TVGHCDMKNYSABWR")
    for i in eachindex(from)
        xtab[Int(from[i])+1] = to[i]
        xtab[Int(from[i])+33] = to[i]
    end
    return xtab
end

const xtab = make_table()

# Appends the reversed record s[1:n] to out at position o, 60 columns per line.
function emit!(out::Vector{UInt8}, o::Int, s::Vector{UInt8}, n::Int)
    e = n
    while e > 0
        x = min(e, 60)
        for k in 1:x
            @inbounds out[o+k] = s[e-k+1]
        end
        o += x + 1
        @inbounds out[o] = 0x0a
        e -= x
    end
    return o
end

function main()
    # read(::IO) is not inferred on this Julia, so the assertion keeps everything below type-stable.
    input = read(stdin)::Vector{UInt8}
    n = length(input)
    out = Vector{UInt8}(undef, n + n ÷ 60 + 64)
    rec = Vector{UInt8}(undef, n + 1)
    o = 0
    rlen = 0
    pos = 1
    while pos <= n
        e = pos
        while e <= n && @inbounds(input[e]) != 0x0a
            e += 1
        end
        if e > pos && @inbounds(input[pos]) == UInt8('>')
            o = emit!(out, o, rec, rlen)
            rlen = 0
            len = e - pos
            copyto!(out, o + 1, input, pos, len)
            o += len
            o += 1
            @inbounds out[o] = 0x0a
        else
            for i in pos:e-1
                @inbounds c = xtab[Int(input[i])+1]
                if c != 0
                    rlen += 1
                    @inbounds rec[rlen] = c
                end
            end
        end
        pos = e + 1
    end
    o = emit!(out, o, rec, rlen)
    unsafe_write(stdout, pointer(out), o)
    flush(stdout)
end

main()
