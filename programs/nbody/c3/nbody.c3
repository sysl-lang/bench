// The Computer Language Benchmarks Game
// https://salsa.debian.org/benchmarksgame-team/benchmarksgame/
//
// A port of the C program (contributed by Christoph Bauer, modified by
// Danny Angelo Carminati Grein) to C3.
module nbody;
import std::io;
import std::math;

const double PI = 3.141592653589793;
const double SOLAR_MASS = 4 * PI * PI;
const double DAYS_PER_YEAR = 365.24;
const int NBODIES = 5;

struct Planet
{
	double x, y, z;
	double vx, vy, vz;
	double mass;
}

Planet[NBODIES] bodies = {
	{ 0, 0, 0, 0, 0, 0, SOLAR_MASS },
	{
		4.84143144246472090e+00,
		-1.16032004402742839e+00,
		-1.03622044471123109e-01,
		1.66007664274403694e-03 * DAYS_PER_YEAR,
		7.69901118419740425e-03 * DAYS_PER_YEAR,
		-6.90460016972063023e-05 * DAYS_PER_YEAR,
		9.54791938424326609e-04 * SOLAR_MASS
	},
	{
		8.34336671824457987e+00,
		4.12479856412430479e+00,
		-4.03523417114321381e-01,
		-2.76742510726862411e-03 * DAYS_PER_YEAR,
		4.99852801234917238e-03 * DAYS_PER_YEAR,
		2.30417297573763929e-05 * DAYS_PER_YEAR,
		2.85885980666130812e-04 * SOLAR_MASS
	},
	{
		1.28943695621391310e+01,
		-1.51111514016986312e+01,
		-2.23307578892655734e-01,
		2.96460137564761618e-03 * DAYS_PER_YEAR,
		2.37847173959480950e-03 * DAYS_PER_YEAR,
		-2.96589568540237556e-05 * DAYS_PER_YEAR,
		4.36624404335156298e-05 * SOLAR_MASS
	},
	{
		1.53796971148509165e+01,
		-2.59193146099879641e+01,
		1.79258772950371181e-01,
		2.68067772490389322e-03 * DAYS_PER_YEAR,
		1.62824170038242295e-03 * DAYS_PER_YEAR,
		-9.51592254519715870e-05 * DAYS_PER_YEAR,
		5.15138902046611451e-05 * SOLAR_MASS
	}
};

fn void advance(double dt)
{
	for (int i = 0; i < NBODIES; i++)
	{
		Planet* b = &bodies[i];
		for (int j = i + 1; j < NBODIES; j++)
		{
			Planet* b2 = &bodies[j];
			double dx = b.x - b2.x;
			double dy = b.y - b2.y;
			double dz = b.z - b2.z;
			double distanced = dx * dx + dy * dy + dz * dz;
			double distance = math::sqrt(distanced);
			double mag = dt / (distanced * distance);
			b.vx -= dx * b2.mass * mag;
			b.vy -= dy * b2.mass * mag;
			b.vz -= dz * b2.mass * mag;
			b2.vx += dx * b.mass * mag;
			b2.vy += dy * b.mass * mag;
			b2.vz += dz * b.mass * mag;
		}
	}
	for (int i = 0; i < NBODIES; i++)
	{
		Planet* b = &bodies[i];
		b.x += dt * b.vx;
		b.y += dt * b.vy;
		b.z += dt * b.vz;
	}
}

fn double energy()
{
	double e = 0.0;
	for (int i = 0; i < NBODIES; i++)
	{
		Planet* b = &bodies[i];
		e += 0.5 * b.mass * (b.vx * b.vx + b.vy * b.vy + b.vz * b.vz);
		for (int j = i + 1; j < NBODIES; j++)
		{
			Planet* b2 = &bodies[j];
			double dx = b.x - b2.x;
			double dy = b.y - b2.y;
			double dz = b.z - b2.z;
			double distance = math::sqrt(dx * dx + dy * dy + dz * dz);
			e -= (b.mass * b2.mass) / distance;
		}
	}
	return e;
}

fn void offset_momentum()
{
	double px = 0.0;
	double py = 0.0;
	double pz = 0.0;
	for (int i = 0; i < NBODIES; i++)
	{
		px += bodies[i].vx * bodies[i].mass;
		py += bodies[i].vy * bodies[i].mass;
		pz += bodies[i].vz * bodies[i].mass;
	}
	bodies[0].vx = -px / SOLAR_MASS;
	bodies[0].vy = -py / SOLAR_MASS;
	bodies[0].vz = -pz / SOLAR_MASS;
}

fn int main(String[] args)
{
	int n = args[1].to_int()!!;
	offset_momentum();
	io::printfn("%.9f", energy());
	for (int i = 1; i <= n; i++) advance(0.01);
	io::printfn("%.9f", energy());
	return 0;
}
