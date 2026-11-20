// The Computer Language Benchmarks Game: spectral-norm. Original, written for this benchmark. It
// mirrors the Game's fastest C program that builds here (spectralnorm.gcc-3, Mr Ledrug): ten rounds of
// A then A transposed applied to a vector, each term u[j] / A's integer denominator, computed on the
// fly; each product's rows split into one contiguous range per core, as its `omp parallel for` splits
// them. Each row is summed in the C program's order, so the result does not depend on the thread
// count.
module spectralnorm;
import std::io;
import std::math;
import std::thread;

// The denominator of A(i, j) = 1 / ((i + j)(i + j + 1)/2 + i + 1), an int, as the C program has it.
fn double a(int i, int j) @inline => (double)((i + j) * (i + j + 1) / 2 + i + 1);

struct Job
{
	double* u;
	double* au;
	int n;
	int first;
	int last;
	bool transpose;
}

fn int rows(void* arg)
{
	Job* job = arg;
	double* u = job.u;
	int n = job.n;
	for (int i = job.first; i < job.last; i++)
	{
		double sum = 0;
		if (job.transpose)
		{
			for (int j = 0; j < n; j++) sum += u[j] / a(j, i);
		}
		else
		{
			for (int j = 0; j < n; j++) sum += u[j] / a(i, j);
		}
		job.au[i] = sum;
	}
	return 0;
}

int nthreads = 1;
Job[256] jobs;
Thread[256] threads;

fn void parallel(int n, double* u, double* au, bool transpose)
{
	int per = (n + nthreads - 1) / nthreads;
	int count = 0;
	for (int first = 0; first < n; first += per)
	{
		jobs[count] = { u, au, n, first, min(first + per, n), transpose };
		count++;
	}
	for (int k = 1; k < count; k++) threads[k].create(&rows, &jobs[k])!!;
	rows(&jobs[0]);
	for (int k = 1; k < count; k++) (void)threads[k].join();
}

fn void eval_ata_times_u(int n, double* u, double* atau, double* v)
{
	parallel(n, u, v, false);
	parallel(n, v, atau, true);
}

fn int main(String[] args)
{
	int n = args.len == 2 ? args[1].to_int()!! : 100;
	nthreads = min(max(thread::cpu::native_cpu(), 1), 256);
	double[] u = mem::new_array(double, n);
	double[] v = mem::new_array(double, n);
	double[] w = mem::new_array(double, n);
	for (int i = 0; i < n; i++) u[i] = 1;
	for (int i = 0; i < 10; i++)
	{
		eval_ata_times_u(n, u.ptr, v.ptr, w.ptr);
		eval_ata_times_u(n, v.ptr, u.ptr, w.ptr);
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
