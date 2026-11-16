// The Computer Language Benchmarks Game
// https://salsa.debian.org/benchmarksgame-team/benchmarksgame/
//
// A port of the C program (contributed by Ledrug Katz) to C3.
module fannkuchredux;
import std::io;

int[16] s;
int[16] t;
int maxflips = 0;
int max_n;
int odd = 0;
int checksum = 0;

fn int flip()
{
	for (int k = 0; k < max_n; k++) t[k] = s[k];
	int i = 1;
	do
	{
		int x = 0;
		int y = t[0];
		while (x < y)
		{
			int c = t[x];
			t[x++] = t[y];
			t[y--] = c;
		}
		i++;
	}
	while (t[t[0]] != 0);
	return i;
}

fn void rotate(int n) @inline
{
	int c = s[0];
	for (int i = 1; i <= n; i++) s[i - 1] = s[i];
	s[n] = c;
}

// Tompkin-Paige iterative perm generation
fn void tk(int n)
{
	int i = 0;
	int[16] c;
	while (i < n)
	{
		rotate(i);
		if (c[i] >= i)
		{
			c[i++] = 0;
			continue;
		}

		c[i]++;
		i = 1;
		odd = ~odd;
		if (s[0] != 0)
		{
			int f = s[s[0]] != 0 ? flip() : 1;
			if (f > maxflips) maxflips = f;
			checksum += odd != 0 ? -f : f;
		}
	}
}

fn int main(String[] args)
{
	max_n = args[1].to_int()!!;
	for (int i = 0; i < max_n; i++) s[i] = i;
	tk(max_n);
	io::printfn("%d\nPfannkuchen(%d) = %d", checksum, max_n, maxflips);
	return 0;
}
