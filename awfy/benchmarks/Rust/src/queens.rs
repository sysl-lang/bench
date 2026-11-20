// Upstream C++ queens.h. The four arrays are fields allocated and freed on every `queens()`, as
// C++'s `new bool[8]` / `delete[]` are.

use crate::benchmark::Benchmark;

pub struct Queens {
    free_maxs: Box<[bool]>,
    free_rows: Box<[bool]>,
    free_mins: Box<[bool]>,
    queen_rows: Box<[i32]>,
}

impl Queens {
    pub fn new() -> Queens {
        Queens {
            free_maxs: Box::default(),
            free_rows: Box::default(),
            free_mins: Box::default(),
            queen_rows: Box::default(),
        }
    }

    fn queens(&mut self) -> bool {
        self.free_rows = vec![true; 8].into_boxed_slice();
        self.free_maxs = vec![true; 16].into_boxed_slice();
        self.free_mins = vec![true; 16].into_boxed_slice();
        self.queen_rows = vec![-1; 8].into_boxed_slice();

        let result = self.place_queen(0);

        self.free_rows = Box::default();
        self.free_maxs = Box::default();
        self.free_mins = Box::default();
        self.queen_rows = Box::default();

        result
    }

    fn place_queen(&mut self, c: i32) -> bool {
        for r in 0..8 {
            if self.get_row_column(r, c) {
                self.queen_rows[r as usize] = c;
                self.set_row_column(r, c, false);

                if c == 7 {
                    return true;
                }

                if self.place_queen(c + 1) {
                    return true;
                }
                self.set_row_column(r, c, true);
            }
        }
        false
    }

    fn get_row_column(&self, r: i32, c: i32) -> bool {
        self.free_rows[r as usize] && self.free_maxs[(c + r) as usize] && self.free_mins[(c - r + 7) as usize]
    }

    fn set_row_column(&mut self, r: i32, c: i32, v: bool) {
        self.free_rows[r as usize] = v;
        self.free_maxs[(c + r) as usize] = v;
        self.free_mins[(c - r + 7) as usize] = v;
    }
}

impl Benchmark for Queens {
    type Result = bool;

    fn benchmark(&mut self) -> bool {
        let mut result = true;
        for _ in 0..10 {
            result = result && self.queens();
        }
        result
    }

    fn verify_result(&mut self, result: bool) -> bool {
        result
    }
}
