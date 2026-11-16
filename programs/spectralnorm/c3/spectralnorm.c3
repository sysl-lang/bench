// The Computer Language Benchmarks Game
// https://salsa.debian.org/benchmarksgame-team/benchmarksgame/
//
// A port of the C program (contributed by Sebastien Loisel) to C3.
module spectralnorm;
import std::io;
import std::math;

fn double eval_a(int i, int j) @inline => 1.0 / (double)((i + j) * (i + j + 1) / 2 + i + 1);

fn void eval_a_times_u(int n, double* u, double* au)
{
	for (int i = 0; i < n; i++)
	{
		au[i] = 0;
		for (int j = 0; j < n; j++) au[i] += eval_a(i, j) * u[j];
	}
}

fn void eval_at_times_u(int n, double* u, double* au)
{
	for (int i = 0; i < n; i++)
	{
		au[i] = 0;
		for (int j = 0; j < n; j++) au[i] += eval_a(j, i) * u[j];
	}
}

fn void eval_ata_times_u(int n, double* u, double* atau)
{
	double[] v = mem::new_array(double, n);
	defer mem::free(v);
	eval_a_times_u(n, u, v.ptr);
	eval_at_times_u(n, v.ptr, atau);
}

fn int main(String[] args)
{
	int n = args.len == 2 ? args[1].to_int()!! : 100;
	double[] u = mem::new_array(double, n);
	double[] v = mem::new_array(double, n);
	for (int i = 0; i < n; i++) u[i] = 1;
	for (int i = 0; i < 10; i++)
	{
		eval_ata_times_u(n, u.ptr, v.ptr);
		eval_ata_times_u(n, v.ptr, u.ptr);
	}
	double vbv = 0;
	double vv = 0;
	for (int i = 0; i < n; i++)
	{
		vbv += u[i] * v[i];
		vv += v[i] * v[i];
	}
	io::printfn("%.9f", math::sqrt(vbv / vv));
	return 0;
}
