// Upstream C++ storage.h: a tree of heap arrays, each node's children one array, freed from the
// root (C++'s `delete[]` recursion is Rust's `Drop` of the boxed slices).

use crate::benchmark::Benchmark;
use crate::som::Random;

#[derive(Default)]
struct ArrayTree {
    children: Option<Box<[ArrayTree]>>,
}

fn new_array(length: usize) -> Box<[ArrayTree]> {
    std::iter::repeat_with(ArrayTree::default).take(length).collect()
}

pub struct Storage {
    count: i32,
}

impl Storage {
    pub fn new() -> Storage {
        Storage { count: 0 }
    }

    fn build_tree_depth(&mut self, depth: i32, random: &mut Random) -> Box<[ArrayTree]> {
        self.count += 1;
        if depth == 1 {
            return new_array((random.next() % 10 + 1) as usize);
        }

        let mut arr = new_array(4);
        for tree in arr.iter_mut() {
            tree.children = Some(self.build_tree_depth(depth - 1, random));
        }
        arr
    }
}

impl Benchmark for Storage {
    type Result = i32;

    fn benchmark(&mut self) -> i32 {
        let mut random = Random::new();

        self.count = 0;
        let result = self.build_tree_depth(7, &mut random);
        drop(result);

        self.count
    }

    fn verify_result(&mut self, result: i32) -> bool {
        5461 == result
    }
}
