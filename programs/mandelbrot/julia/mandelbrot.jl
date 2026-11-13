# The Computer Language Benchmarks Game: mandelbrot. Same algorithm as the C version.
# The packed bitmap is collected in memory and written to standard output in one call at the end.

function main(w::Int)
    h = w
    iter = 50
    limit = 2.0
    bit_num = 0
    byte_acc = UInt8(0)
    out = UInt8[]
    sizehint!(out, cld(w, 8) * h)

    wf = Float64(w)
    hf = Float64(h)
    y = 0.0
    while y < hf
        x = 0.0
        while x < wf
            Zr = 0.0
            Zi = 0.0
            Tr = 0.0
            Ti = 0.0
            Cr = 2.0 * x / wf - 1.5
            Ci = 2.0 * y / hf - 1.0

            i = 0
            while i < iter && (Tr + Ti <= limit * limit)
                Zi = 2.0 * Zr * Zi + Ci
                Zr = Tr - Ti + Cr
                Tr = Zr * Zr
                Ti = Zi * Zi
                i += 1
            end

            byte_acc <<= 1
            if Tr + Ti <= limit * limit
                byte_acc |= 0x01
            end
            bit_num += 1

            if bit_num == 8
                push!(out, byte_acc)
                byte_acc = UInt8(0)
                bit_num = 0
            elseif x == wf - 1
                byte_acc <<= (8 - w % 8)
                push!(out, byte_acc)
                byte_acc = UInt8(0)
                bit_num = 0
            end
            x += 1
        end
        y += 1
    end
    write(stdout, "P4\n$w $h\n")
    write(stdout, out)
    flush(stdout)
end

main(parse(Int, ARGS[1]))
