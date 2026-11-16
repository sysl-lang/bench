// The Computer Language Benchmarks Game: spectral-norm. A port of the C program (Sebastien
// Loisel's), written for this suite: A is computed on the fly, ten rounds of A then A transposed.
import core.stdc.stdio : printf;
import core.stdc.stdlib : atoi;
import core.stdc.math : sqrt;

double evalA(int i, int j)
{
    return 1.0 / ((i + j) * (i + j + 1) / 2 + i + 1);
}

void evalATimesU(const double[] u, double[] au)
{
    foreach (i; 0 .. u.length)
    {
        au[i] = 0;
        foreach (j; 0 .. u.length)
            au[i] += evalA(cast(int) i, cast(int) j) * u[j];
    }
}

void evalAtTimesU(const double[] u, double[] au)
{
    foreach (i; 0 .. u.length)
    {
        au[i] = 0;
        foreach (j; 0 .. u.length)
            au[i] += evalA(cast(int) j, cast(int) i) * u[j];
    }
}

void evalAtATimesU(const double[] u, double[] atau, double[] v)
{
    evalATimesU(u, v);
    evalAtTimesU(v, atau);
}

int main(string[] args)
{
    int n = args.length == 2 ? atoi(args[1].ptr) : 100;
    auto u = new double[n];
    auto v = new double[n];
    auto w = new double[n];
    u[] = 1;
    foreach (_; 0 .. 10)
    {
        evalAtATimesU(u, v, w);
        evalAtATimesU(v, u, w);
    }
    double vBv = 0, vv = 0;
    foreach (i; 0 .. n)
    {
        vBv += u[i] * v[i];
        vv += v[i] * v[i];
    }
    printf("%0.9f\n", sqrt(vBv / vv));
    return 0;
}
