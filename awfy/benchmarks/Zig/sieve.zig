//! sieve.h. The flags live on the stack and are passed by value, as the C++
//! passes its std::array.

pub const Sieve = struct {
    pub fn benchmark(_: *Sieve) i32 {
        const num_flags = 5000;
        var flags: [num_flags]bool = @splat(false);
        @memset(&flags, true);
        return sieve(num_flags, flags, 5000);
    }

    pub fn verifyResult(_: *Sieve, result: i32) bool {
        return 669 == result;
    }

    fn sieve(comptime size: usize, flags_arg: [size]bool, n: i32) i32 {
        var flags = flags_arg;
        var prime_count: i32 = 0;

        var i: i32 = 2;
        while (i <= n) : (i += 1) {
            if (flags[@intCast(i - 1)]) {
                prime_count += 1;
                var k = i + i;
                while (k <= n) {
                    flags[@intCast(k - 1)] = false;
                    k += i;
                }
            }
        }
        return prime_count;
    }
};
