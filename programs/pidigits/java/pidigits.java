// The Computer Language Benchmarks Game
// https://salsa.debian.org/benchmarksgame-team/benchmarksgame/
//
// Translated from Mr Ledrug's C program by Jeremy Zerfas.
// GMP through a JNI wrapper replaced by java.math.BigInteger for this suite.

import java.math.BigInteger;

final class pidigits{
    static BigInteger acc=BigInteger.ZERO, den=BigInteger.ONE,
      num=BigInteger.ONE;


    static final long extract_Digit(final long nth){
        return num.multiply(BigInteger.valueOf(nth)).add(acc).divide(den)
          .longValue();
    }


    static final void eliminate_Digit(final long d){
        acc=acc.subtract(den.multiply(BigInteger.valueOf(d)))
          .multiply(BigInteger.TEN);
        num=num.multiply(BigInteger.TEN);
    }


    static final void next_Term(final long k){
        final BigInteger k2=BigInteger.valueOf(k*2+1);
        acc=acc.add(num.shiftLeft(1)).multiply(k2);
        den=den.multiply(k2);
        num=num.multiply(BigInteger.valueOf(k));
    }


    public static final void main(final String[] args){
        final long n=Long.parseLong(args[0]);

        // It's considerably faster to use a StringBuilder to buffer all the
        // output and do one single print() call instead of many print(ln)()
        // calls.
        final StringBuilder results=new StringBuilder();

        for(long i=0, k=0; i<n;){
            next_Term(++k);
            if(num.compareTo(acc)>0)
                continue;

            final long d=extract_Digit(3);
            if(d!=extract_Digit(4))
                continue;

            results.append(d);
            if(++i%10==0)
                results.append("\t:").append(i).append("\n");
            eliminate_Digit(d);
        }

        if(n%10!=0)
            results.append(" ".repeat((int)(10-n%10))).append("\t:").append(n)
              .append("\n");

        System.out.print(results);
    }
}
