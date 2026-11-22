// Upstream C++ bounce.h.

use crate::benchmark::Benchmark;
use crate::som::Random;

struct Ball {
    x: i32,
    y: i32,
    x_vel: i32,
    y_vel: i32,
}

impl Ball {
    fn new(random: &mut Random) -> Ball {
        let x = random.next() % 500;
        let y = random.next() % 500;
        let x_vel = (random.next() % 300) - 150;
        let y_vel = (random.next() % 300) - 150;
        Ball { x, y, x_vel, y_vel }
    }

    fn bounce(&mut self) -> bool {
        let x_limit = 500;
        let y_limit = 500;
        let mut bounced = false;

        self.x += self.x_vel;
        self.y += self.y_vel;
        if self.x > x_limit {
            self.x = x_limit;
            self.x_vel = 0 - self.x_vel.abs();
            bounced = true;
        }
        if self.x < 0 {
            self.x = 0;
            self.x_vel = self.x_vel.abs();
            bounced = true;
        }
        if self.y > y_limit {
            self.y = y_limit;
            self.y_vel = 0 - self.y_vel.abs();
            bounced = true;
        }
        if self.y < 0 {
            self.y = 0;
            self.y_vel = self.y_vel.abs();
            bounced = true;
        }
        bounced
    }
}

pub struct Bounce;

impl Benchmark for Bounce {
    type Result = i32;

    fn benchmark(&mut self) -> i32 {
        let mut random = Random::new();

        const BALL_COUNT: usize = 100;
        let mut bounces = 0;

        let mut balls: [Ball; BALL_COUNT] = std::array::from_fn(|_| Ball::new(&mut random));

        for _ in 0..50 {
            for ball in balls.iter_mut() {
                if ball.bounce() {
                    bounces += 1;
                }
            }
        }
        bounces
    }

    fn verify_result(&mut self, result: i32) -> bool {
        1331 == result
    }
}
