// The Computer Language Benchmarks Game: n-body. A port of the C program (Christoph Bauer's),
// written for this suite: the same pairwise advance of five bodies over an array of structs.
import core.stdc.stdio : printf;
import core.stdc.stdlib : atoi;
import core.stdc.math : sqrt;

enum double pi = 3.141592653589793;
enum double solarMass = 4 * pi * pi;
enum double daysPerYear = 365.24;

struct Planet
{
    double x, y, z;
    double vx, vy, vz;
    double mass;
}

void advance(Planet[] bodies, double dt)
{
    foreach (i; 0 .. bodies.length)
    {
        Planet* b = &bodies[i];
        foreach (j; i + 1 .. bodies.length)
        {
            Planet* b2 = &bodies[j];
            double dx = b.x - b2.x;
            double dy = b.y - b2.y;
            double dz = b.z - b2.z;
            double distanced = dx * dx + dy * dy + dz * dz;
            double distance = sqrt(distanced);
            double mag = dt / (distanced * distance);
            b.vx -= dx * b2.mass * mag;
            b.vy -= dy * b2.mass * mag;
            b.vz -= dz * b2.mass * mag;
            b2.vx += dx * b.mass * mag;
            b2.vy += dy * b.mass * mag;
            b2.vz += dz * b.mass * mag;
        }
    }
    foreach (ref b; bodies)
    {
        b.x += dt * b.vx;
        b.y += dt * b.vy;
        b.z += dt * b.vz;
    }
}

double energy(Planet[] bodies)
{
    double e = 0.0;
    foreach (i; 0 .. bodies.length)
    {
        Planet* b = &bodies[i];
        e += 0.5 * b.mass * (b.vx * b.vx + b.vy * b.vy + b.vz * b.vz);
        foreach (j; i + 1 .. bodies.length)
        {
            Planet* b2 = &bodies[j];
            double dx = b.x - b2.x;
            double dy = b.y - b2.y;
            double dz = b.z - b2.z;
            double distance = sqrt(dx * dx + dy * dy + dz * dz);
            e -= (b.mass * b2.mass) / distance;
        }
    }
    return e;
}

void offsetMomentum(Planet[] bodies)
{
    double px = 0.0, py = 0.0, pz = 0.0;
    foreach (ref b; bodies)
    {
        px += b.vx * b.mass;
        py += b.vy * b.mass;
        pz += b.vz * b.mass;
    }
    bodies[0].vx = -px / solarMass;
    bodies[0].vy = -py / solarMass;
    bodies[0].vz = -pz / solarMass;
}

Planet[5] bodies = [
    Planet(0, 0, 0, 0, 0, 0, solarMass), // sun
    Planet(4.84143144246472090e+00, -1.16032004402742839e+00, -1.03622044471123109e-01,
        1.66007664274403694e-03 * daysPerYear, 7.69901118419740425e-03 * daysPerYear,
        -6.90460016972063023e-05 * daysPerYear, 9.54791938424326609e-04 * solarMass), // jupiter
    Planet(8.34336671824457987e+00, 4.12479856412430479e+00, -4.03523417114321381e-01,
        -2.76742510726862411e-03 * daysPerYear, 4.99852801234917238e-03 * daysPerYear,
        2.30417297573763929e-05 * daysPerYear, 2.85885980666130812e-04 * solarMass), // saturn
    Planet(1.28943695621391310e+01, -1.51111514016986312e+01, -2.23307578892655734e-01,
        2.96460137564761618e-03 * daysPerYear, 2.37847173959480950e-03 * daysPerYear,
        -2.96589568540237556e-05 * daysPerYear, 4.36624404335156298e-05 * solarMass), // uranus
    Planet(1.53796971148509165e+01, -2.59193146099879641e+01, 1.79258772950371181e-01,
        2.68067772490389322e-03 * daysPerYear, 1.62824170038242295e-03 * daysPerYear,
        -9.51592254519715870e-05 * daysPerYear, 5.15138902046611451e-05 * solarMass), // neptune
];

int main(string[] args)
{
    int n = atoi(args[1].ptr);
    offsetMomentum(bodies[]);
    printf("%.9f\n", energy(bodies[]));
    foreach (_; 0 .. n)
        advance(bodies[], 0.01);
    printf("%.9f\n", energy(bodies[]));
    return 0;
}
