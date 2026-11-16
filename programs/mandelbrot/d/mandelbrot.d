// The Computer Language Benchmarks Game: mandelbrot. A port of the C program (Greg Buchholz's),
// written for this suite: up to 50 iterations per pixel, eight pixels packed into each output byte.
import core.stdc.stdio : printf, putc, stdout;
import core.stdc.stdlib : atoi;

int main(string[] args)
{
    int w = atoi(args[1].ptr);
    int h = w;
    int bitNum = 0;
    ubyte byteAcc = 0;
    enum int iter = 50;
    enum double limit = 2.0;

    printf("P4\n%d %d\n", w, h);

    for (double y = 0; y < h; ++y)
    {
        for (double x = 0; x < w; ++x)
        {
            double zr = 0.0, zi = 0.0, tr = 0.0, ti = 0.0;
            double cr = 2.0 * x / w - 1.5;
            double ci = 2.0 * y / h - 1.0;

            for (int i = 0; i < iter && (tr + ti <= limit * limit); ++i)
            {
                zi = 2.0 * zr * zi + ci;
                zr = tr - ti + cr;
                tr = zr * zr;
                ti = zi * zi;
            }

            byteAcc <<= 1;
            if (tr + ti <= limit * limit)
                byteAcc |= 0x01;

            ++bitNum;

            if (bitNum == 8)
            {
                putc(byteAcc, stdout);
                byteAcc = 0;
                bitNum = 0;
            }
            else if (x == w - 1)
            {
                byteAcc <<= (8 - w % 8);
                putc(byteAcc, stdout);
                byteAcc = 0;
                bitNum = 0;
            }
        }
    }
    return 0;
}
