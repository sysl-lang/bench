// Upstream C++ havlak.h.
//
// Basic blocks, loops and union-find nodes point at each other, as C++'s do: each is one allocation
// made by a `Tracker` (C++'s `new`), referenced by `&` where C++ holds a raw pointer, with its mutable
// fields in `Cell`s and `RefCell`s. Each tracker is freed where C++ frees what it holds: the blocks
// with the control flow graph, a graph's loops with the graph, the union-find nodes with the loop
// finder. The caller declares the tracker beside its owner because a Rust struct cannot hold
// references into its own fields (SOURCES.md, "Rust").

use std::cell::{Cell, Ref, RefCell};
use std::ptr;

use crate::benchmark::Benchmark;
use crate::memory::Tracker;
use crate::som::{CustomHash, IdentityDictionary, IdentitySet, Set, Vector};

pub struct BasicBlock<'t> {
    in_edges: RefCell<Vector<&'t BasicBlock<'t>>>,
    out_edges: RefCell<Vector<&'t BasicBlock<'t>>>,
    name: u32,
}

impl<'t> BasicBlock<'t> {
    fn new(name: i32) -> BasicBlock<'t> {
        BasicBlock {
            in_edges: RefCell::new(Vector::with_capacity(2)),
            out_edges: RefCell::new(Vector::with_capacity(2)),
            name: name as u32,
        }
    }

    fn get_in_edges(&self) -> Ref<'_, Vector<&'t BasicBlock<'t>>> {
        self.in_edges.borrow()
    }

    fn get_out_edges(&self) -> Ref<'_, Vector<&'t BasicBlock<'t>>> {
        self.out_edges.borrow()
    }

    fn get_num_pred(&self) -> i32 {
        self.in_edges.borrow().size() as i32
    }

    fn add_out_edge(&self, to: &'t BasicBlock<'t>) {
        self.out_edges.borrow_mut().append(to);
    }

    fn add_in_edge(&self, from: &'t BasicBlock<'t>) {
        self.in_edges.borrow_mut().append(from);
    }
}

impl CustomHash for BasicBlock<'_> {
    fn custom_hash(&self) -> u32 {
        self.name
    }
}

struct ControlFlowGraph<'t> {
    blocks: &'t Tracker<BasicBlock<'t>>,
    basic_block_map: Vector<Option<&'t BasicBlock<'t>>>,
    start_node: Option<&'t BasicBlock<'t>>,
    edge_list: Vector<Box<BasicBlockEdge<'t>>>,
}

impl<'t> ControlFlowGraph<'t> {
    fn new(blocks: &'t Tracker<BasicBlock<'t>>) -> ControlFlowGraph<'t> {
        ControlFlowGraph { blocks, basic_block_map: Vector::new(), start_node: None, edge_list: Vector::new() }
    }

    fn create_node(&mut self, name: i32) -> &'t BasicBlock<'t> {
        let node = match self.basic_block_map.at(name as usize) {
            Some(node) => node.unwrap(),
            None => {
                let node = self.blocks.track(BasicBlock::new(name));
                self.basic_block_map.at_put(name as usize, Some(node));
                node
            }
        };

        if self.get_num_nodes() == 1 {
            self.start_node = Some(node);
        }
        node
    }

    fn add_edge(&mut self, edge: Box<BasicBlockEdge<'t>>) {
        self.edge_list.append(edge);
    }

    fn get_num_nodes(&self) -> i32 {
        self.basic_block_map.size() as i32
    }

    fn get_start_basic_block(&self) -> Option<&'t BasicBlock<'t>> {
        self.start_node
    }

    fn get_basic_blocks(&self) -> &Vector<Option<&'t BasicBlock<'t>>> {
        &self.basic_block_map
    }
}

struct BasicBlockEdge<'t> {
    #[allow(dead_code)]
    from: &'t BasicBlock<'t>,
    #[allow(dead_code)]
    to: &'t BasicBlock<'t>,
}

impl<'t> BasicBlockEdge<'t> {
    /// C++'s `new BasicBlockEdge(cfg, from, to)`, whose constructor registers it with the graph.
    fn create(cfg: &mut ControlFlowGraph<'t>, from_name: i32, to_name: i32) {
        let from = cfg.create_node(from_name);
        let to = cfg.create_node(to_name);
        from.add_out_edge(to);
        to.add_in_edge(from);

        cfg.add_edge(Box::new(BasicBlockEdge { from, to }));
    }
}

struct SimpleLoop<'l, 't> {
    basic_blocks: RefCell<IdentitySet<&'t BasicBlock<'t>>>,
    children: RefCell<IdentitySet<&'l SimpleLoop<'l, 't>>>,
    parent: Cell<Option<&'l SimpleLoop<'l, 't>>>,
    // Written and never read, in C++ as here.
    #[allow(dead_code)]
    header: Option<&'t BasicBlock<'t>>,
    #[allow(dead_code)]
    is_reducible: bool,
    is_root: Cell<bool>,
    nesting_level: Cell<i32>,
    counter: Cell<i32>,
    depth_level: Cell<i32>,
}

impl<'l, 't> SimpleLoop<'l, 't> {
    fn new(bb: Option<&'t BasicBlock<'t>>, is_reducible: bool) -> SimpleLoop<'l, 't> {
        let mut basic_blocks = IdentitySet::new();
        if let Some(bb) = bb {
            basic_blocks.add(bb);
        }
        SimpleLoop {
            basic_blocks: RefCell::new(basic_blocks),
            children: RefCell::new(IdentitySet::new()),
            parent: Cell::new(None),
            header: bb,
            is_reducible,
            is_root: Cell::new(false),
            nesting_level: Cell::new(0),
            counter: Cell::new(0),
            depth_level: Cell::new(0),
        }
    }

    fn add_child_loop(&self, lp: &'l SimpleLoop<'l, 't>) {
        self.children.borrow_mut().add(lp);
    }

    fn add_node(&self, bb: &'t BasicBlock<'t>) {
        self.basic_blocks.borrow_mut().add(bb);
    }

    fn get_children(&self) -> Ref<'_, IdentitySet<&'l SimpleLoop<'l, 't>>> {
        self.children.borrow()
    }

    fn get_parent(&self) -> Option<&'l SimpleLoop<'l, 't>> {
        self.parent.get()
    }

    fn get_nesting_level(&self) -> i32 {
        self.nesting_level.get()
    }

    fn is_root(&self) -> bool {
        self.is_root.get()
    }

    fn set_parent(&'l self, parent: &'l SimpleLoop<'l, 't>) {
        self.parent.set(Some(parent));
        parent.add_child_loop(self);
    }

    fn set_is_root(&self) {
        self.is_root.set(true);
    }

    fn set_counter(&self, value: i32) {
        self.counter.set(value);
    }

    fn set_nesting_level(&self, level: i32) {
        self.nesting_level.set(level);
        if level == 0 {
            self.set_is_root();
        }
    }

    fn set_depth_level(&self, level: i32) {
        self.depth_level.set(level);
    }
}

struct LoopStructureGraph<'l, 't> {
    loop_objects: &'l Tracker<SimpleLoop<'l, 't>>,
    root: &'l SimpleLoop<'l, 't>,
    loops: RefCell<Vector<&'l SimpleLoop<'l, 't>>>,
    loop_counter: Cell<i32>,
}

impl<'l, 't> LoopStructureGraph<'l, 't> {
    fn new(loop_objects: &'l Tracker<SimpleLoop<'l, 't>>) -> LoopStructureGraph<'l, 't> {
        let lsg = LoopStructureGraph {
            loop_objects,
            root: loop_objects.track(SimpleLoop::new(None, true)),
            loops: RefCell::new(Vector::new()),
            loop_counter: Cell::new(0),
        };
        lsg.root.set_nesting_level(0);
        lsg.root.set_counter(lsg.loop_counter.get());
        lsg.loop_counter.set(lsg.loop_counter.get() + 1);
        lsg.loops.borrow_mut().append(lsg.root);
        lsg
    }

    fn create_new_loop(&self, bb: Option<&'t BasicBlock<'t>>, is_reducible: bool) -> &'l SimpleLoop<'l, 't> {
        let lp = self.loop_objects.track(SimpleLoop::new(bb, is_reducible));
        lp.set_counter(self.loop_counter.get());
        self.loop_counter.set(self.loop_counter.get() + 1);
        self.loops.borrow_mut().append(lp);
        lp
    }

    fn calculate_nesting_level(&self) {
        // link up all 1st level loops to artificial root node.
        self.loops.borrow().for_each(|liter| {
            if !liter.is_root() {
                if liter.get_parent().is_none() {
                    liter.set_parent(self.root);
                }
            }
        });

        // recursively traverse the tree and assign levels.
        self.calculate_nesting_level_rec(self.root, 0);
    }

    fn calculate_nesting_level_rec(&self, lp: &'l SimpleLoop<'l, 't>, depth: i32) {
        lp.set_depth_level(depth);
        lp.get_children().for_each(|liter| {
            self.calculate_nesting_level_rec(liter, depth + 1);

            lp.set_nesting_level(lp.get_nesting_level().max(1 + liter.get_nesting_level()));
        });
    }

    fn get_num_loops(&self) -> i32 {
        self.loops.borrow().size() as i32
    }
}

struct UnionFindNode<'u, 'l, 't> {
    parent: Cell<Option<&'u UnionFindNode<'u, 'l, 't>>>,
    bb: Cell<Option<&'t BasicBlock<'t>>>,
    lp: Cell<Option<&'l SimpleLoop<'l, 't>>>,
    dfs_number: Cell<i32>,
}

impl<'u, 'l, 't> UnionFindNode<'u, 'l, 't> {
    fn new() -> UnionFindNode<'u, 'l, 't> {
        UnionFindNode { parent: Cell::new(None), bb: Cell::new(None), lp: Cell::new(None), dfs_number: Cell::new(0) }
    }

    fn init_node(&'u self, bb: &'t BasicBlock<'t>, dfs_number: i32) {
        self.parent.set(Some(self));
        self.bb.set(Some(bb));
        self.dfs_number.set(dfs_number);
        self.lp.set(None);
    }

    /// C++'s `_parent`, which is set once a node is initialised.
    fn parent(&self) -> &'u UnionFindNode<'u, 'l, 't> {
        self.parent.get().unwrap()
    }

    fn find_set(&'u self) -> &'u UnionFindNode<'u, 'l, 't> {
        let mut node_list = Vector::new();

        let mut node = self;
        while !ptr::eq(node, node.parent()) {
            if !ptr::eq(node.parent(), node.parent().parent()) {
                node_list.append(node);
            }
            node = node.parent();
        }

        // Path Compression, all nodes' parents point to the 1st level parent.
        node_list.for_each(|iter| iter.union_set(self.parent()));
        node
    }

    fn union_set(&self, basic_block: &'u UnionFindNode<'u, 'l, 't>) {
        self.parent.set(Some(basic_block));
    }

    fn get_bb(&self) -> Option<&'t BasicBlock<'t>> {
        self.bb.get()
    }

    fn get_loop(&self) -> Option<&'l SimpleLoop<'l, 't>> {
        self.lp.get()
    }

    fn get_dfs_number(&self) -> i32 {
        self.dfs_number.get()
    }

    fn set_loop(&self, lp: &'l SimpleLoop<'l, 't>) {
        self.lp.set(Some(lp));
    }
}

#[allow(dead_code)]
#[derive(Clone, Copy, PartialEq, Eq)]
enum BasicBlockClass {
    BbTop,         // uninitialized
    BbNonHeader,   // a regular BB
    BbReducible,   // reducible loop
    BbSelf,        // single BB loop
    BbIrreducible, // irreducible loop
    BbDead,        // a dead BB
    BbLast,        // Sentinel
}

const UNVISITED: i32 = i32::MAX;
const MAXNONBACKPREDS: i32 = 32 * 1024;

type Node<'u, 'l, 't> = UnionFindNode<'u, 'l, 't>;

struct HavlakLoopFinder<'a, 'u, 'l, 't> {
    cfg: &'a ControlFlowGraph<'t>,      // Control Flow Graph
    lsg: &'a LoopStructureGraph<'l, 't>, // Loop Structure Graph
    node_objects: &'u Tracker<Node<'u, 'l, 't>>,

    non_back_preds: Vector<Box<RefCell<Set<i32>>>>,
    back_preds: Vector<Box<RefCell<Vector<i32>>>>,
    number: IdentityDictionary<'t, BasicBlock<'t>, i32>,

    max_size: i32,
    header: Box<[Cell<i32>]>,
    type_: Box<[Cell<BasicBlockClass>]>,
    last: Box<[i32]>,
    nodes: Box<[Option<&'u Node<'u, 'l, 't>>]>,
}

impl<'a, 'u, 'l, 't> HavlakLoopFinder<'a, 'u, 'l, 't> {
    fn new(
        cfg: &'a ControlFlowGraph<'t>,
        lsg: &'a LoopStructureGraph<'l, 't>,
        node_objects: &'u Tracker<Node<'u, 'l, 't>>,
    ) -> HavlakLoopFinder<'a, 'u, 'l, 't> {
        HavlakLoopFinder {
            cfg,
            lsg,
            node_objects,
            non_back_preds: Vector::new(),
            back_preds: Vector::new(),
            number: IdentityDictionary::new(),
            max_size: 0,
            header: Box::new([]),
            type_: Box::new([]),
            last: Box::new([]),
            nodes: Box::new([]),
        }
    }

    /// C++'s `_nodes[i]`, set for every index before it is read.
    fn node(&self, i: i32) -> &'u Node<'u, 'l, 't> {
        self.nodes[i as usize].unwrap()
    }

    fn find_loops(&mut self) {
        if self.cfg.get_start_basic_block().is_none() {
            return;
        }

        let size = self.cfg.get_num_nodes();

        self.non_back_preds.remove_all();
        self.back_preds.remove_all();
        self.number.remove_all();
        if size > self.max_size {
            let n = size as usize;
            self.header = (0..n).map(|_| Cell::new(0)).collect();
            self.type_ = (0..n).map(|_| Cell::new(BasicBlockClass::BbTop)).collect();
            self.last = vec![0; n].into_boxed_slice();
            self.nodes = vec![None; n].into_boxed_slice();
            self.max_size = size;
        }

        for i in 0..size as usize {
            self.non_back_preds.append(Box::new(RefCell::new(Set::new())));
            self.back_preds.append(Box::new(RefCell::new(Vector::new())));
            self.nodes[i] = Some(self.node_objects.track(UnionFindNode::new()));
        }

        self.init_all_nodes();
        self.identify_edges(size);

        // Start node is root of all other loops.
        self.header[0].set(0);
        for w in (0..size).rev() {
            // this is 'P' in Havlak's paper
            let mut node_pool = Vector::new();

            let node_w = self.node(w).get_bb();
            if let Some(node_w) = node_w {
                self.step_d(w, &mut node_pool);

                // Copy nodePool to workList.
                let mut work_list = Vector::new();
                node_pool.for_each(|niter| work_list.append(*niter));

                if node_pool.size() != 0 {
                    self.type_[w as usize].set(BasicBlockClass::BbReducible);
                }

                // work the list...
                //
                while !work_list.is_empty() {
                    let x = work_list.remove_first().unwrap();

                    let non_back_size = self.non_back_preds.at(x.get_dfs_number() as usize).unwrap().borrow().size() as i32;
                    if non_back_size > MAXNONBACKPREDS {
                        return;
                    }
                    self.step_e_process_non_back_preds(w, &mut node_pool, &mut work_list, x);
                }

                if node_pool.size() > 0 || self.type_[w as usize].get() == BasicBlockClass::BbSelf {
                    let lp = self
                        .lsg
                        .create_new_loop(Some(node_w), self.type_[w as usize].get() != BasicBlockClass::BbIrreducible);
                    self.set_loop_attributes(w, &node_pool, lp);
                }
            }
        } // Step c
    } // findLoops

    fn is_ancestor(&self, w: i32, v: i32) -> bool {
        w <= v && v <= self.last[w as usize]
    }

    fn do_dfs(&mut self, current_node: &'t BasicBlock<'t>, current: i32) -> i32 {
        self.node(current).init_node(current_node, current);
        self.number.at_put(current_node, current);

        let mut last_id = current;
        let outer_blocks = current_node.get_out_edges();

        for i in 0..outer_blocks.size() {
            let target = *outer_blocks.at(i).unwrap();
            if *self.number.at(target).unwrap() == UNVISITED {
                last_id = self.do_dfs(target, last_id + 1);
            }
        }

        self.last[current as usize] = last_id;
        last_id
    }

    fn init_all_nodes(&mut self) {
        let cfg = self.cfg;
        cfg.get_basic_blocks().for_each(|bb| {
            self.number.at_put(bb.unwrap(), UNVISITED);
        });
        self.do_dfs(cfg.get_start_basic_block().unwrap(), 0);
    }

    fn identify_edges(&self, size: i32) {
        for w in 0..size {
            self.header[w as usize].set(0);
            self.type_[w as usize].set(BasicBlockClass::BbNonHeader);

            let node_w = self.node(w).get_bb();
            match node_w {
                None => self.type_[w as usize].set(BasicBlockClass::BbDead),
                Some(node_w) => self.process_edges(node_w, w),
            }
        }
    }

    fn process_edges(&self, node_w: &'t BasicBlock<'t>, w: i32) {
        if node_w.get_num_pred() > 0 {
            node_w.get_in_edges().for_each(|node_v| {
                let v = *self.number.at(node_v).unwrap();
                if v != UNVISITED {
                    if self.is_ancestor(w, v) {
                        self.back_preds.at(w as usize).unwrap().borrow_mut().append(v);
                    } else {
                        self.non_back_preds.at(w as usize).unwrap().borrow_mut().add(v);
                    }
                }
            });
        }
    }

    fn step_e_process_non_back_preds(
        &self,
        w: i32,
        node_pool: &mut Vector<&'u Node<'u, 'l, 't>>,
        work_list: &mut Vector<&'u Node<'u, 'l, 't>>,
        x: &'u Node<'u, 'l, 't>,
    ) {
        self.non_back_preds.at(x.get_dfs_number() as usize).unwrap().borrow().for_each(|&iter| {
            let y = self.node(iter);
            let ydash = y.find_set();

            if !self.is_ancestor(w, ydash.get_dfs_number()) {
                self.type_[w as usize].set(BasicBlockClass::BbIrreducible);
                self.non_back_preds.at(w as usize).unwrap().borrow_mut().add(ydash.get_dfs_number());
            } else {
                #[allow(clippy::collapsible_if)]
                if ydash.get_dfs_number() != w {
                    if !node_pool.has_some(|e| ptr::eq(*e, ydash)) {
                        work_list.append(ydash);
                        node_pool.append(ydash);
                    }
                }
            }
        });
    }

    fn set_loop_attributes(&self, w: i32, node_pool: &Vector<&'u Node<'u, 'l, 't>>, lp: &'l SimpleLoop<'l, 't>) {
        self.node(w).set_loop(lp);

        node_pool.for_each(|node| {
            self.header[node.get_dfs_number() as usize].set(w);
            node.union_set(self.node(w));

            // Nested loops are not added, but linked together.
            match node.get_loop() {
                Some(node_loop) => node_loop.set_parent(lp),
                None => lp.add_node(node.get_bb().unwrap()),
            }
        });
    }

    fn step_d(&self, w: i32, node_pool: &mut Vector<&'u Node<'u, 'l, 't>>) {
        self.back_preds.at(w as usize).unwrap().borrow().for_each(|&v| {
            if v != w {
                node_pool.append(self.node(v).find_set());
            } else {
                self.type_[w as usize].set(BasicBlockClass::BbSelf);
            }
        });
    }
}

struct LoopTesterApp<'t, 'l> {
    cfg: ControlFlowGraph<'t>,
    lsg: LoopStructureGraph<'l, 't>,
}

impl<'t, 'l> LoopTesterApp<'t, 'l> {
    fn new(blocks: &'t Tracker<BasicBlock<'t>>, loops: &'l Tracker<SimpleLoop<'l, 't>>) -> LoopTesterApp<'t, 'l> {
        let mut app = LoopTesterApp { cfg: ControlFlowGraph::new(blocks), lsg: LoopStructureGraph::new(loops) };
        app.cfg.create_node(0);
        app
    }

    fn build_diamond(&mut self, start: i32) -> i32 {
        let bb0 = start;
        BasicBlockEdge::create(&mut self.cfg, bb0, bb0 + 1);
        BasicBlockEdge::create(&mut self.cfg, bb0, bb0 + 2);
        BasicBlockEdge::create(&mut self.cfg, bb0 + 1, bb0 + 3);
        BasicBlockEdge::create(&mut self.cfg, bb0 + 2, bb0 + 3);

        bb0 + 3
    }

    fn build_connect(&mut self, start: i32, end: i32) {
        BasicBlockEdge::create(&mut self.cfg, start, end);
    }

    fn build_straight(&mut self, start: i32, n: i32) -> i32 {
        for i in 0..n {
            self.build_connect(start + i, start + i + 1);
        }
        start + n
    }

    fn build_base_loop(&mut self, from: i32) -> i32 {
        let header = self.build_straight(from, 1);
        let diamond1 = self.build_diamond(header);
        let d11 = self.build_straight(diamond1, 1);
        let diamond2 = self.build_diamond(d11);
        let mut footer = self.build_straight(diamond2, 1);
        self.build_connect(diamond2, d11);
        self.build_connect(diamond1, header);
        self.build_connect(footer, from);
        footer = self.build_straight(footer, 1);
        footer
    }

    fn construct_simple_cfg(&mut self) {
        self.cfg.create_node(0);
        self.build_base_loop(0);
        self.cfg.create_node(1);

        BasicBlockEdge::create(&mut self.cfg, 0, 2);
    }

    fn main(
        &mut self,
        num_dummy_loops: i32,
        find_loop_iterations: i32,
        par_loops: i32,
        ppar_loops: i32,
        pppar_loops: i32,
    ) -> [i32; 2] {
        self.construct_simple_cfg();
        self.add_dummy_loops(num_dummy_loops);
        self.construct_cfg(par_loops, ppar_loops, pppar_loops);
        self.find_loops(&self.lsg);
        for _ in 0..find_loop_iterations {
            let loop_objects = Tracker::new();
            let l = LoopStructureGraph::new(&loop_objects);
            self.find_loops(&l);
        }

        self.lsg.calculate_nesting_level();
        [self.lsg.get_num_loops(), self.cfg.get_num_nodes()]
    }

    fn construct_cfg(&mut self, par_loops: i32, ppar_loops: i32, pppar_loops: i32) {
        let mut n = 2;

        for _ in 0..par_loops {
            self.cfg.create_node(n + 1);
            self.build_connect(2, n + 1);
            n += 1;

            for _ in 0..ppar_loops {
                let top = n;
                n = self.build_straight(n, 1);
                for _ in 0..pppar_loops {
                    n = self.build_base_loop(n);
                }
                let bottom = self.build_straight(n, 1);
                self.build_connect(n, top);
                n = bottom;
            }
            self.build_connect(n, 1);
        }
    }

    fn add_dummy_loops(&self, num_dummy_loops: i32) {
        for _ in 0..num_dummy_loops {
            self.find_loops(&self.lsg);
        }
    }

    fn find_loops(&self, loop_structure: &LoopStructureGraph<'_, 't>) {
        let node_objects = Tracker::new();
        let mut finder = HavlakLoopFinder::new(&self.cfg, loop_structure, &node_objects);
        finder.find_loops();
    }
}

pub struct Havlak;

impl Havlak {
    fn verify(r: [i32; 2], inner_iterations: i32) -> bool {
        if inner_iterations == 15000 {
            return r[0] == 46602 && r[1] == 5213;
        }
        if inner_iterations == 1500 {
            return r[0] == 6102 && r[1] == 5213;
        }
        if inner_iterations == 150 {
            return r[0] == 2052 && r[1] == 5213;
        }
        if inner_iterations == 15 {
            return r[0] == 1647 && r[1] == 5213;
        }
        if inner_iterations == 1 {
            return r[0] == 1605 && r[1] == 5213;
        }

        println!("No verification result for {inner_iterations} found");
        println!("Result is: {}, {}", r[0], r[1]);

        false
    }
}

impl Benchmark for Havlak {
    type Result = ();

    fn benchmark(&mut self) {
        unreachable!("Should never be reached");
    }

    fn verify_result(&mut self, _result: ()) -> bool {
        unreachable!("Should never be reached");
    }

    fn inner_benchmark_loop(&mut self, inner_iterations: i32) -> bool {
        let blocks = Tracker::new();
        let loops = Tracker::new();
        let result = LoopTesterApp::new(&blocks, &loops).main(inner_iterations, 50, 10 /* was 100 */, 10, 5);
        Havlak::verify(result, inner_iterations)
    }
}
