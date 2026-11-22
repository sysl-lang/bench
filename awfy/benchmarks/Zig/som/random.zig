//! som/random.h.

pub const Random = struct {
    seed: i32 = 74755,

    pub fn next(self: *Random) i32 {
        self.seed = ((self.seed * 1309) + 13849) & 65535;
        return self.seed;
    }
};
