// The Computer Language Benchmarks Game
// https://salsa.debian.org/benchmarksgame-team/benchmarksgame/
//
// contributed by the Rust Project Developers
// contributed by TeXitoi
// *reset*
//
// Tuned for this suite: a tree is checked and freed in one walk (moving each
// node out of its Box frees the Box, then its children are walked), where
// the plain program walks it to check and walks it again to drop it. Every
// node is still its own Box allocation and its own free.

struct Tree {
    l: Option<Box<Tree>>,
    r: Option<Box<Tree>>,
}

fn bottom_up_tree(depth: i32) -> Box<Tree> {
    if depth > 0 {
        Box::new(Tree { l: Some(bottom_up_tree(depth - 1)), r: Some(bottom_up_tree(depth - 1)) })
    } else {
        Box::new(Tree { l: None, r: None })
    }
}

// Counts the nodes of the tree, freeing each one.
fn check_and_drop(t: Box<Tree>) -> i32 {
    let Tree { l, r } = *t;
    match (l, r) {
        (Some(l), Some(r)) => 1 + check_and_drop(l) + check_and_drop(r),
        _ => 1,
    }
}

fn main() {
    let n = std::env::args_os().nth(1)
        .and_then(|s| s.into_string().ok())
        .and_then(|n| n.parse().ok())
        .unwrap_or(10);
    let min_depth = 4;
    let max_depth = if min_depth + 2 > n { min_depth + 2 } else { n };

    let depth = max_depth + 1;
    println!("stretch tree of depth {}\t check: {}", depth, check_and_drop(bottom_up_tree(depth)));

    let long_lived_tree = bottom_up_tree(max_depth);

    let mut depth = min_depth;
    while depth <= max_depth {
        let iterations = 1 << ((max_depth - depth + min_depth) as u32);
        let mut chk = 0;
        for _ in 0..iterations {
            chk += check_and_drop(bottom_up_tree(depth));
        }
        println!("{}\t trees of depth {}\t check: {}", iterations, depth, chk);
        depth += 2;
    }

    println!("long lived tree of depth {}\t check: {}", max_depth, check_and_drop(long_lived_tree));
}
