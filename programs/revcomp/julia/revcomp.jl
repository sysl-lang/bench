# The Computer Language Benchmarks Game: reverse-complement. Same algorithm as the C version:
# each sequence line is complemented through a 256-entry table (characters without an entry are
# dropped) and stored reversed, then the record is written in 60-column lines.

function make_table()
    xtab = zeros(UInt8, 256)
    from = codeunits("ABCDGHKMNRSTVWY")
    to = codeunits("TVGHCDMKNYSABWR")
    for (f, t) in zip(from, to)
        xtab[Int(f)+1] = t
        xtab[Int(f)+33] = t
    end
    return xtab
end

const xtab = make_table()

function emit(io, rec::Vector{UInt8}, rlen::Int, line::Vector{UInt8})
    e = rlen
    while e > 0
        x = min(e, 60)
        for k in 1:x
            line[k] = rec[e-k+1]
        end
        line[x+1] = 0x0a
        unsafe_write(io, pointer(line), x + 1)
        e -= x
    end
end

function main()
    input = read(stdin)
    n = length(input)
    rec = Vector{UInt8}(undef, n + 1)
    line = Vector{UInt8}(undef, 61)
    out = IOBuffer()
    rlen = 0
    pos = 1
    while pos <= n
        e = findnext(==(0x0a), input, pos)
        e = e === nothing ? n + 1 : e
        if e > pos && input[pos] == UInt8('>')
            emit(out, rec, rlen, line)
            rlen = 0
            write(out, view(input, pos:e-1))
            write(out, 0x0a)
        else
            for i in pos:e-1
                c = xtab[Int(input[i])+1]
                if c != 0
                    rlen += 1
                    rec[rlen] = c
                end
            end
        end
        pos = e + 1
    end
    emit(out, rec, rlen, line)
    write(stdout, take!(out))
    flush(stdout)
end

main()
