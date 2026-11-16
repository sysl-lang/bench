// The Computer Language Benchmarks Game: n-body. A port of the C program (Christoph Bauer's),
// written for this suite: the same pairwise advance of five bodies over an array of structs.
package main

import "core:fmt"
import "core:math"
import "core:os"
import "core:strconv"

PI :: 3.141592653589793
SOLAR_MASS :: 4 * PI * PI
DAYS_PER_YEAR :: 365.24

Planet :: struct {
	x, y, z:    f64,
	vx, vy, vz: f64,
	mass:       f64,
}

advance :: proc(bodies: []Planet, dt: f64) {
	for i in 0 ..< len(bodies) {
		b := &bodies[i]
		for j in i + 1 ..< len(bodies) {
			b2 := &bodies[j]
			dx := b.x - b2.x
			dy := b.y - b2.y
			dz := b.z - b2.z
			distanced := dx * dx + dy * dy + dz * dz
			distance := math.sqrt(distanced)
			mag := dt / (distanced * distance)
			b.vx -= dx * b2.mass * mag
			b.vy -= dy * b2.mass * mag
			b.vz -= dz * b2.mass * mag
			b2.vx += dx * b.mass * mag
			b2.vy += dy * b.mass * mag
			b2.vz += dz * b.mass * mag
		}
	}
	for &b in bodies {
		b.x += dt * b.vx
		b.y += dt * b.vy
		b.z += dt * b.vz
	}
}

energy :: proc(bodies: []Planet) -> f64 {
	e := 0.0
	for i in 0 ..< len(bodies) {
		b := &bodies[i]
		e += 0.5 * b.mass * (b.vx * b.vx + b.vy * b.vy + b.vz * b.vz)
		for j in i + 1 ..< len(bodies) {
			b2 := &bodies[j]
			dx := b.x - b2.x
			dy := b.y - b2.y
			dz := b.z - b2.z
			distance := math.sqrt(dx * dx + dy * dy + dz * dz)
			e -= (b.mass * b2.mass) / distance
		}
	}
	return e
}

offset_momentum :: proc(bodies: []Planet) {
	px, py, pz := 0.0, 0.0, 0.0
	for b in bodies {
		px += b.vx * b.mass
		py += b.vy * b.mass
		pz += b.vz * b.mass
	}
	bodies[0].vx = -px / SOLAR_MASS
	bodies[0].vy = -py / SOLAR_MASS
	bodies[0].vz = -pz / SOLAR_MASS
}

main :: proc() {
	bodies := [5]Planet {
		{0, 0, 0, 0, 0, 0, SOLAR_MASS}, // sun
		{
			4.84143144246472090e+00,
			-1.16032004402742839e+00,
			-1.03622044471123109e-01,
			1.66007664274403694e-03 * DAYS_PER_YEAR,
			7.69901118419740425e-03 * DAYS_PER_YEAR,
			-6.90460016972063023e-05 * DAYS_PER_YEAR,
			9.54791938424326609e-04 * SOLAR_MASS,
		}, // jupiter
		{
			8.34336671824457987e+00,
			4.12479856412430479e+00,
			-4.03523417114321381e-01,
			-2.76742510726862411e-03 * DAYS_PER_YEAR,
			4.99852801234917238e-03 * DAYS_PER_YEAR,
			2.30417297573763929e-05 * DAYS_PER_YEAR,
			2.85885980666130812e-04 * SOLAR_MASS,
		}, // saturn
		{
			1.28943695621391310e+01,
			-1.51111514016986312e+01,
			-2.23307578892655734e-01,
			2.96460137564761618e-03 * DAYS_PER_YEAR,
			2.37847173959480950e-03 * DAYS_PER_YEAR,
			-2.96589568540237556e-05 * DAYS_PER_YEAR,
			4.36624404335156298e-05 * SOLAR_MASS,
		}, // uranus
		{
			1.53796971148509165e+01,
			-2.59193146099879641e+01,
			1.79258772950371181e-01,
			2.68067772490389322e-03 * DAYS_PER_YEAR,
			1.62824170038242295e-03 * DAYS_PER_YEAR,
			-9.51592254519715870e-05 * DAYS_PER_YEAR,
			5.15138902046611451e-05 * SOLAR_MASS,
		}, // neptune
	}
	n, _ := strconv.parse_int(os.args[1])
	offset_momentum(bodies[:])
	fmt.printf("%.9f\n", energy(bodies[:]))
	for _ in 0 ..< n {
		advance(bodies[:], 0.01)
	}
	fmt.printf("%.9f\n", energy(bodies[:]))
}
