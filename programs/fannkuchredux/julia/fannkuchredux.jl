# The Computer Language Benchmarks Game: fannkuch-redux. Same algorithm as the C version
# (Tompkin-Paige iterative permutation generation). Arrays are 1-based here, so a permutation
# element e is stored as e and used as the index e + 1.

mutable struct State
    s::Vector{Int32}
    t::Vector{Int32}
    c::Vector{Int32}
    maxflips::Int32
    odd::Bool
    checksum::Int32
end

function flip(st::State, max_n::Int)
    s = st.s
    t = st.t
    for k in 1:max_n
        t[k] = s[k]
    end
    i = Int32(1)
    while true
        x = 1
        y = Int(t[1]) + 1
        while x < y
            c = t[x]
            t[x] = t[y]
            t[y] = c
            x += 1
            y -= 1
        end
        i += Int32(1)
        t[Int(t[1])+1] == 0 && break
    end
    return i
end

@inline function rotate!(s::Vector{Int32}, n::Int)
    c = s[1]
    for i in 1:n
        s[i] = s[i+1]
    end
    s[n+1] = c
end

function tk(st::State, n::Int)
    s = st.s
    c = st.c
    i = 0
    while i < n
        rotate!(s, i)
        if c[i+1] >= i
            c[i+1] = 0
            i += 1
            continue
        end
        c[i+1] += Int32(1)
        i = 1
        st.odd = !st.odd
        if s[1] != 0
            f = s[Int(s[1])+1] != 0 ? flip(st, n) : Int32(1)
            f > st.maxflips && (st.maxflips = f)
            st.checksum += st.odd ? -f : f
        end
    end
end

function main(n::Int)
    if n < 3 || n > 15
        exit(1)
    end
    st = State(Int32.(0:15), zeros(Int32, 16), zeros(Int32, 16), 0, false, 0)
    for i in 1:n
        st.s[i] = Int32(i - 1)
    end
    tk(st, n)
    println(st.checksum, "\nPfannkuchen(", n, ") = ", st.maxflips)
end

main(parse(Int, ARGS[1]))
