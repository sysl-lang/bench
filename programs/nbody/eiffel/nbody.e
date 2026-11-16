note
	description: "N-body simulation of the Jovian planets: a port of the Benchmarks Game C program (Christoph Bauer, Danny Angelo Carminati Grein) to Eiffel."

class NBODY

inherit
	DOUBLE_MATH

	ARGUMENTS_32

create
	make

feature {NONE} -- Initialization

	make
			-- Simulate the number of steps given as the first argument, printing the energy before and after.
		local
			n, i: INTEGER
		do
			n := argument (1).to_integer
			solar_mass := 4.0 * pi_value * pi_value
			create x.make_filled (0.0, 0, bodies_count - 1)
			create y.make_filled (0.0, 0, bodies_count - 1)
			create z.make_filled (0.0, 0, bodies_count - 1)
			create vx.make_filled (0.0, 0, bodies_count - 1)
			create vy.make_filled (0.0, 0, bodies_count - 1)
			create vz.make_filled (0.0, 0, bodies_count - 1)
			create mass.make_filled (0.0, 0, bodies_count - 1)
			set_body (0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, solar_mass)
			set_body (1,
				4.84143144246472090e+00,
				-1.16032004402742839e+00,
				-1.03622044471123109e-01,
				1.66007664274403694e-03 * days_per_year,
				7.69901118419740425e-03 * days_per_year,
				-6.90460016972063023e-05 * days_per_year,
				9.54791938424326609e-04 * solar_mass)
			set_body (2,
				8.34336671824457987e+00,
				4.12479856412430479e+00,
				-4.03523417114321381e-01,
				-2.76742510726862411e-03 * days_per_year,
				4.99852801234917238e-03 * days_per_year,
				2.30417297573763929e-05 * days_per_year,
				2.85885980666130812e-04 * solar_mass)
			set_body (3,
				1.28943695621391310e+01,
				-1.51111514016986312e+01,
				-2.23307578892655734e-01,
				2.96460137564761618e-03 * days_per_year,
				2.37847173959480950e-03 * days_per_year,
				-2.96589568540237556e-05 * days_per_year,
				4.36624404335156298e-05 * solar_mass)
			set_body (4,
				1.53796971148509165e+01,
				-2.59193146099879641e+01,
				1.79258772950371181e-01,
				2.68067772490389322e-03 * days_per_year,
				1.62824170038242295e-03 * days_per_year,
				-9.51592254519715870e-05 * days_per_year,
				5.15138902046611451e-05 * solar_mass)
			offset_momentum
			print_energy
			from
				i := 1
			invariant
				step_in_range: i >= 1 and i <= n + 1
			variant
				n + 1 - i
			until
				i > n
			loop
				advance (0.01)
				i := i + 1
			end
			print_energy
		end

feature {NONE} -- Constants

	bodies_count: INTEGER = 5

	pi_value: REAL_64 = 3.141592653589793

	days_per_year: REAL_64 = 365.24

feature {NONE} -- Access

	solar_mass: REAL_64

	x, y, z, vx, vy, vz, mass: ARRAY [REAL_64]
			-- Position, velocity and mass of each body, indexed 0 to `bodies_count' - 1.

feature {NONE} -- Basic operations

	set_body (i: INTEGER; px, py, pz, pvx, pvy, pvz, pmass: REAL_64)
			-- Store body `i'.
		require
			index_valid: i >= 0 and i < bodies_count
		do
			x.put (px, i)
			y.put (py, i)
			z.put (pz, i)
			vx.put (pvx, i)
			vy.put (pvy, i)
			vz.put (pvz, i)
			mass.put (pmass, i)
		end

	advance (dt: REAL_64)
			-- Move the system on by `dt'.
		require
			step_positive: dt > 0.0
		local
			i, j: INTEGER
			dx, dy, dz, distanced, distance, mag: REAL_64
		do
			from
				i := 0
			invariant
				i_in_range: i >= 0 and i <= bodies_count
			variant
				bodies_count - i
			until
				i >= bodies_count
			loop
				from
					j := i + 1
				invariant
					j_in_range: j > i and j <= bodies_count
				variant
					bodies_count - j
				until
					j >= bodies_count
				loop
					dx := x.item (i) - x.item (j)
					dy := y.item (i) - y.item (j)
					dz := z.item (i) - z.item (j)
					distanced := dx * dx + dy * dy + dz * dz
					distance := sqrt (distanced)
					mag := dt / (distanced * distance)
					vx.put (vx.item (i) - dx * mass.item (j) * mag, i)
					vy.put (vy.item (i) - dy * mass.item (j) * mag, i)
					vz.put (vz.item (i) - dz * mass.item (j) * mag, i)
					vx.put (vx.item (j) + dx * mass.item (i) * mag, j)
					vy.put (vy.item (j) + dy * mass.item (i) * mag, j)
					vz.put (vz.item (j) + dz * mass.item (i) * mag, j)
					j := j + 1
				end
				i := i + 1
			end
			from
				i := 0
			invariant
				i_in_range: i >= 0 and i <= bodies_count
			variant
				bodies_count - i
			until
				i >= bodies_count
			loop
				x.put (x.item (i) + dt * vx.item (i), i)
				y.put (y.item (i) + dt * vy.item (i), i)
				z.put (z.item (i) + dt * vz.item (i), i)
				i := i + 1
			end
		end

	energy: REAL_64
			-- Total kinetic and potential energy.
		local
			i, j: INTEGER
			dx, dy, dz, distance: REAL_64
		do
			from
				i := 0
			invariant
				i_in_range: i >= 0 and i <= bodies_count
			variant
				bodies_count - i
			until
				i >= bodies_count
			loop
				Result := Result + 0.5 * mass.item (i) * (vx.item (i) * vx.item (i) + vy.item (i) * vy.item (i) + vz.item (i) * vz.item (i))
				from
					j := i + 1
				invariant
					j_in_range: j > i and j <= bodies_count
				variant
					bodies_count - j
				until
					j >= bodies_count
				loop
					dx := x.item (i) - x.item (j)
					dy := y.item (i) - y.item (j)
					dz := z.item (i) - z.item (j)
					distance := sqrt (dx * dx + dy * dy + dz * dz)
					Result := Result - (mass.item (i) * mass.item (j)) / distance
					j := j + 1
				end
				i := i + 1
			end
		end

	offset_momentum
			-- Give the sun the momentum that makes the system's total momentum zero.
		local
			i: INTEGER
			px, py, pz: REAL_64
		do
			from
				i := 0
			invariant
				i_in_range: i >= 0 and i <= bodies_count
			variant
				bodies_count - i
			until
				i >= bodies_count
			loop
				px := px + vx.item (i) * mass.item (i)
				py := py + vy.item (i) * mass.item (i)
				pz := pz + vz.item (i) * mass.item (i)
				i := i + 1
			end
			vx.put (-px / solar_mass, 0)
			vy.put (-py / solar_mass, 0)
			vz.put (-pz / solar_mass, 0)
		end

	print_energy
			-- Print `energy' with nine decimals.
		local
			format: FORMAT_DOUBLE
			text: STRING
		do
			create format.make (20, 9)
			format.left_justify
			text := format.formatted (energy)
			text.right_adjust
			io.put_string (text)
			io.put_new_line
		end

invariant
	arrays_sized: x.count = bodies_count and y.count = bodies_count and z.count = bodies_count and vx.count = bodies_count and vy.count = bodies_count and vz.count = bodies_count and mass.count = bodies_count

end
