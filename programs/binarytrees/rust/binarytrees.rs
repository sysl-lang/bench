// The Computer Language Benchmarks Game
// https://salsa.debian.org/benchmarksgame-team/benchmarksgame/
//
// contributed by the Rust Project Developers
// contributed by TeXitoi
// *reset*
//
// Adapted for this suite: the typed_arena crate and the thread per depth are
// replaced by Box-allocated nodes and a sequential loop.

struct Tree {
    l: Option<Box<Tree>>,
    r: Option<Box<Tree>>,
}

fn item_check(t: &Option<Box<Tree>>) -> i32 {
    match t {
        None => 0,
        Some(b) => 1 + item_check(&b.l) + item_check(&b.r),
    }
}

fn bottom_up_tree(depth: i32) -> Option<Box<Tree>> {
    if depth >= 0 {
        Some(Box::new(Tree {
            l: bottom_up_tree(depth - 1),
            r: bottom_up_tree(depth - 1),
        }))
    } else {
        None
    }
}

fn inner(depth: i32, iterations: i32) -> String {
    let mut chk = 0;
    for _ in 1..iterations + 1 {
        let a = bottom_up_tree(depth);
        chk += item_check(&a);
    }
    format!("{}\t trees of depth {}\t check: {}", iterations, depth, chk)
}

fn main() {
    let n = std::env::args_os().nth(1)
        .and_then(|s| s.into_string().ok())
        .and_then(|n| n.parse().ok())
        .unwrap_or(10);
    let min_depth = 4;
    let max_depth = if min_depth + 2 > n { min_depth + 2 } else { n };

    {
        let depth = max_depth + 1;
        let tree = bottom_up_tree(depth);
        println!("stretch tree of depth {}\t check: {}", depth, item_check(&tree));
    }

    let long_lived_tree = bottom_up_tree(max_depth);

    for depth in (min_depth..max_depth + 1).filter(|&d| d % 2 == 0) {
        let iterations = 1 << ((max_depth - depth + min_depth) as u32);
        println!("{}", inner(depth, iterations));
    }

    println!("long lived tree of depth {}\t check: {}", max_depth, item_check(&long_lived_tree));
}
