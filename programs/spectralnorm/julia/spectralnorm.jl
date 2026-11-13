# The Computer Language Benchmarks Game: spectral norm. Same algorithm as the C version.
using Printf

@inline eval_A(i::Int32, j::Int32) = 1.0 / Float64(div((i + j) * (i + j + Int32(1)), Int32(2)) + i + Int32(1))

function eval_A_times_u!(Au::Vector{Float64}, u::Vector{Float64})
    n = Int32(length(u))
    for i in Int32(0):n-Int32(1)
        s = 0.0
        for j in Int32(0):n-Int32(1)
            s += eval_A(i, j) * u[j+1]
        end
        Au[i+1] = s
    end
end

function eval_At_times_u!(Au::Vector{Float64}, u::Vector{Float64})
    n = Int32(length(u))
    for i in Int32(0):n-Int32(1)
        s = 0.0
        for j in Int32(0):n-Int32(1)
            s += eval_A(j, i) * u[j+1]
        end
        Au[i+1] = s
    end
end

function eval_AtA_times_u!(AtAu::Vector{Float64}, u::Vector{Float64}, v::Vector{Float64})
    eval_A_times_u!(v, u)
    eval_At_times_u!(AtAu, v)
end

function main(n::Int)
    u = ones(Float64, n)
    v = zeros(Float64, n)
    tmp = zeros(Float64, n)
    for _ in 1:10
        eval_AtA_times_u!(v, u, tmp)
        eval_AtA_times_u!(u, v, tmp)
    end
    vBv = 0.0
    vv = 0.0
    for i in 1:n
        vBv += u[i] * v[i]
        vv += v[i] * v[i]
    end
    @printf("%0.9f\n", sqrt(vBv / vv))
end

main(length(ARGS) == 1 ? parse(Int, ARGS[1]) : 100)
