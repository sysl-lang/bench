//! bounce.h. The balls live on the stack, as in C++.

const Random = @import("som/random.zig").Random;

fn abs(x: i32) i32 {
    return @intCast(@abs(x));
}

const Ball = struct {
    x: i32,
    y: i32,
    x_vel: i32,
    y_vel: i32,

    fn init(random: *Random) Ball {
        return .{
            .x = @rem(random.next(), 500),
            .y = @rem(random.next(), 500),
            .x_vel = @rem(random.next(), 300) - 150,
            .y_vel = @rem(random.next(), 300) - 150,
        };
    }

    fn bounce(self: *Ball) bool {
        const x_limit = 500;
        const y_limit = 500;
        var bounced = false;

        self.x += self.x_vel;
        self.y += self.y_vel;
        if (self.x > x_limit) {
            self.x = x_limit;
            self.x_vel = 0 - abs(self.x_vel);
            bounced = true;
        }
        if (self.x < 0) {
            self.x = 0;
            self.x_vel = abs(self.x_vel);
            bounced = true;
        }
        if (self.y > y_limit) {
            self.y = y_limit;
            self.y_vel = 0 - abs(self.y_vel);
            bounced = true;
        }
        if (self.y < 0) {
            self.y = 0;
            self.y_vel = abs(self.y_vel);
            bounced = true;
        }
        return bounced;
    }
};

pub const Bounce = struct {
    pub fn benchmark(_: *Bounce) i32 {
        var random: Random = .{};

        const ball_count = 100;
        var bounces: i32 = 0;

        var balls: [ball_count]Ball = @splat(.{ .x = 0, .y = 0, .x_vel = 0, .y_vel = 0 });
        for (&balls) |*ball| ball.* = .init(&random);

        var j: i32 = 0;
        while (j < 50) : (j += 1) {
            for (&balls) |*ball| {
                if (ball.bounce()) bounces += 1;
            }
        }
        return bounces;
    }

    pub fn verifyResult(_: *Bounce, result: i32) bool {
        return 1331 == result;
    }
};
