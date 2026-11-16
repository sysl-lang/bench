// The Computer Language Benchmarks Game
// https://salsa.debian.org/benchmarksgame-team/benchmarksgame/
//
// A port of the C program (contributed by Greg Buchholz) to C3.
module mandelbrot;
import std::io;
import libc;

fn int main(String[] args)
{
	int bit_num = 0;
	char byte_acc = 0;
	int iter = 50;
	double limit = 2.0;
	int w = args[1].to_int()!!;
	int h = w;

	io::printf("P4\n%d %d\n", w, h);
	libc::CFile out = libc::stdout();

	for (double y = 0; y < h; ++y)
	{
		for (double x = 0; x < w; ++x)
		{
			double zr = 0.0;
			double zi = 0.0;
			double tr = 0.0;
			double ti = 0.0;
			double cr = 2.0 * x / w - 1.5;
			double ci = 2.0 * y / h - 1.0;

			for (int i = 0; i < iter && (tr + ti <= limit * limit); ++i)
			{
				zi = 2.0 * zr * zi + ci;
				zr = tr - ti + cr;
				tr = zr * zr;
				ti = zi * zi;
			}

			byte_acc <<= 1;
			if (tr + ti <= limit * limit) byte_acc |= 0x01;

			++bit_num;

			if (bit_num == 8)
			{
				libc::putc(byte_acc, out);
				byte_acc = 0;
				bit_num = 0;
			}
			else if (x == (double)(w - 1))
			{
				byte_acc <<= (8 - w % 8);
				libc::putc(byte_acc, out);
				byte_acc = 0;
				bit_num = 0;
			}
		}
	}
	libc::fflush(out);
	return 0;
}
