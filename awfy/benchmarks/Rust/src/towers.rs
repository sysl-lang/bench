// Upstream C++ towers.h. Each pile owns its top disk, and a disk the one beneath it (`Box`), as
// C++'s destructor deletes `next`.

use std::process::exit;

use crate::benchmark::Benchmark;

struct TowersDisk {
    size: i32,
    next: Option<Box<TowersDisk>>,
}

impl TowersDisk {
    fn new(size: i32) -> TowersDisk {
        TowersDisk { size, next: None }
    }

    fn get_size(&self) -> i32 {
        self.size
    }
}

pub struct Towers {
    piles: [Option<Box<TowersDisk>>; 3],
    moves_done: i32,
}

impl Towers {
    pub fn new() -> Towers {
        Towers { piles: [None, None, None], moves_done: 0 }
    }

    fn push_disk(&mut self, mut disk: Box<TowersDisk>, pile: i32) {
        let top = self.piles[pile as usize].take();
        if let Some(top) = &top {
            if disk.get_size() >= top.get_size() {
                eprint!("Cannot put a big disk on a smaller one");
                exit(1);
            }
        }

        disk.next = top;
        self.piles[pile as usize] = Some(disk);
    }

    fn pop_disk_from(&mut self, pile: i32) -> Box<TowersDisk> {
        let Some(mut top) = self.piles[pile as usize].take() else {
            eprint!("Attempting to remove a disk from an empty pile");
            exit(1);
        };

        self.piles[pile as usize] = top.next.take();
        top
    }

    fn move_top_disk(&mut self, from_pile: i32, to_pile: i32) {
        let disk = self.pop_disk_from(from_pile);
        self.push_disk(disk, to_pile);
        self.moves_done += 1;
    }

    fn build_tower_at(&mut self, pile: i32, disks: i32) {
        for i in (0..=disks).rev() {
            self.push_disk(Box::new(TowersDisk::new(i)), pile);
        }
    }

    fn move_disks(&mut self, disks: i32, from_pile: i32, to_pile: i32) {
        if disks == 1 {
            self.move_top_disk(from_pile, to_pile);
        } else {
            let other_pile = (3 - from_pile) - to_pile;
            self.move_disks(disks - 1, from_pile, other_pile);
            self.move_top_disk(from_pile, to_pile);
            self.move_disks(disks - 1, other_pile, to_pile);
        }
    }
}

impl Benchmark for Towers {
    type Result = i32;

    fn benchmark(&mut self) -> i32 {
        self.piles = [None, None, None];
        self.build_tower_at(0, 13);
        self.moves_done = 0;
        self.move_disks(13, 0, 1);

        self.piles = [None, None, None];

        self.moves_done
    }

    fn verify_result(&mut self, result: i32) -> bool {
        8191 == result
    }
}
