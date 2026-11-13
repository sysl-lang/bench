# The Computer Language Benchmarks Game: n-body. Same algorithm as the C version.
using Printf

const solar_mass = 4 * pi * pi
const days_per_year = 365.24

mutable struct Planet
    x::Float64
    y::Float64
    z::Float64
    vx::Float64
    vy::Float64
    vz::Float64
    mass::Float64
end

const bodies = [
    Planet(0, 0, 0, 0, 0, 0, solar_mass),
    Planet(4.84143144246472090e+00, -1.16032004402742839e+00, -1.03622044471123109e-01,
           1.66007664274403694e-03 * days_per_year, 7.69901118419740425e-03 * days_per_year,
           -6.90460016972063023e-05 * days_per_year, 9.54791938424326609e-04 * solar_mass),
    Planet(8.34336671824457987e+00, 4.12479856412430479e+00, -4.03523417114321381e-01,
           -2.76742510726862411e-03 * days_per_year, 4.99852801234917238e-03 * days_per_year,
           2.30417297573763929e-05 * days_per_year, 2.85885980666130812e-04 * solar_mass),
    Planet(1.28943695621391310e+01, -1.51111514016986312e+01, -2.23307578892655734e-01,
           2.96460137564761618e-03 * days_per_year, 2.37847173959480950e-03 * days_per_year,
           -2.96589568540237556e-05 * days_per_year, 4.36624404335156298e-05 * solar_mass),
    Planet(1.53796971148509165e+01, -2.59193146099879641e+01, 1.79258772950371181e-01,
           2.68067772490389322e-03 * days_per_year, 1.62824170038242295e-03 * days_per_year,
           -9.51592254519715870e-05 * days_per_year, 5.15138902046611451e-05 * solar_mass),
]

function advance(bodies, dt)
    n = length(bodies)
    for i in 1:n
        b = bodies[i]
        for j in i+1:n
            b2 = bodies[j]
            dx = b.x - b2.x
            dy = b.y - b2.y
            dz = b.z - b2.z
            distanced = dx * dx + dy * dy + dz * dz
            distance = sqrt(distanced)
            mag = dt / (distanced * distance)
            b.vx -= dx * b2.mass * mag
            b.vy -= dy * b2.mass * mag
            b.vz -= dz * b2.mass * mag
            b2.vx += dx * b.mass * mag
            b2.vy += dy * b.mass * mag
            b2.vz += dz * b.mass * mag
        end
    end
    for i in 1:n
        b = bodies[i]
        b.x += dt * b.vx
        b.y += dt * b.vy
        b.z += dt * b.vz
    end
end

function energy(bodies)
    n = length(bodies)
    e = 0.0
    for i in 1:n
        b = bodies[i]
        e += 0.5 * b.mass * (b.vx * b.vx + b.vy * b.vy + b.vz * b.vz)
        for j in i+1:n
            b2 = bodies[j]
            dx = b.x - b2.x
            dy = b.y - b2.y
            dz = b.z - b2.z
            distance = sqrt(dx * dx + dy * dy + dz * dz)
            e -= (b.mass * b2.mass) / distance
        end
    end
    return e
end

function offset_momentum(bodies)
    px = 0.0
    py = 0.0
    pz = 0.0
    for b in bodies
        px += b.vx * b.mass
        py += b.vy * b.mass
        pz += b.vz * b.mass
    end
    bodies[1].vx = -px / solar_mass
    bodies[1].vy = -py / solar_mass
    bodies[1].vz = -pz / solar_mass
end

function main(n)
    offset_momentum(bodies)
    @printf("%.9f\n", energy(bodies))
    for _ in 1:n
        advance(bodies, 0.01)
    end
    @printf("%.9f\n", energy(bodies))
end

main(parse(Int, ARGS[1]))
