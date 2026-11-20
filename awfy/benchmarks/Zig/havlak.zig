//! havlak.h. Ownership as in C++: the ControlFlowGraph owns its basic blocks
//! and edges, the LoopStructureGraph its loops, the HavlakLoopFinder its
//! tables and union-find nodes; each `deinit` is the C++ destructor.

const std = @import("std");
const mem = @import("mem.zig");
const Vector = @import("som/vector.zig").Vector;
const Set = @import("som/set.zig").Set;
const IdentitySet = @import("som/set.zig").IdentitySet;
const dictionary = @import("som/dictionary.zig");
const IdentityDictionary = dictionary.IdentityDictionary;

const BasicBlock = struct {
    in_edges: Vector(*BasicBlock),
    out_edges: Vector(*BasicBlock),
    name: u32,

    fn new(name: i32) *BasicBlock {
        return mem.create(BasicBlock, .{ .in_edges = .init(2), .out_edges = .init(2), .name = @intCast(name) });
    }

    pub fn deinit(self: *BasicBlock) void {
        self.out_edges.deinit();
        self.in_edges.deinit();
    }

    fn getNumPred(self: *const BasicBlock) i32 {
        return @intCast(self.in_edges.size());
    }

    fn addOutEdge(self: *BasicBlock, to: *BasicBlock) void {
        self.out_edges.append(to);
    }

    fn addInEdge(self: *BasicBlock, from: *BasicBlock) void {
        self.in_edges.append(from);
    }

    pub fn customHash(self: *const BasicBlock) u32 {
        return self.name;
    }

    pub fn equal(self: *const BasicBlock, other: *BasicBlock) bool {
        return self.name == other.name;
    }
};

const ControlFlowGraph = struct {
    basic_block_map: Vector(*BasicBlock) = .init(0),
    start_node: ?*BasicBlock = null,
    edge_list: Vector(*BasicBlockEdge) = .init(0),

    fn deinit(self: *ControlFlowGraph) void {
        self.basic_block_map.destroyValues();
        self.edge_list.destroyValues();
        self.edge_list.deinit();
        self.basic_block_map.deinit();
    }

    fn createNode(self: *ControlFlowGraph, name: i32) *BasicBlock {
        var node: *BasicBlock = undefined;
        if (self.basic_block_map.at(@intCast(name))) |existing| {
            node = existing.*;
        } else {
            node = BasicBlock.new(name);
            self.basic_block_map.atPut(@intCast(name), node);
        }

        if (self.getNumNodes() == 1) self.start_node = node;
        return node;
    }

    fn addEdge(self: *ControlFlowGraph, edge: *BasicBlockEdge) void {
        self.edge_list.append(edge);
    }

    fn getNumNodes(self: *const ControlFlowGraph) i32 {
        return @intCast(self.basic_block_map.size());
    }
};

const BasicBlockEdge = struct {
    from: *BasicBlock,
    to: *BasicBlock,

    /// `new BasicBlockEdge(cfg, from, to)`: the edge registers itself with the graph.
    fn new(cfg: *ControlFlowGraph, from_name: i32, to_name: i32) void {
        const from = cfg.createNode(from_name);
        const to = cfg.createNode(to_name);
        const edge = mem.create(BasicBlockEdge, .{ .from = from, .to = to });
        from.addOutEdge(to);
        to.addInEdge(from);
        cfg.addEdge(edge);
    }
};

const SimpleLoop = struct {
    basic_blocks: IdentitySet(*BasicBlock),
    children: IdentitySet(*SimpleLoop),
    parent: ?*SimpleLoop = null,
    header: ?*BasicBlock,
    is_reducible: bool,
    is_root: bool = false,
    nesting_level: i32 = 0,
    counter: i32 = 0,
    depth_level: i32 = 0,

    fn new(bb: ?*BasicBlock, is_reducible: bool) *SimpleLoop {
        const loop = mem.create(SimpleLoop, .{
            .basic_blocks = .init(),
            .children = .init(),
            .header = bb,
            .is_reducible = is_reducible,
        });
        if (bb) |b| loop.basic_blocks.add(b);
        return loop;
    }

    pub fn deinit(self: *SimpleLoop) void {
        self.children.deinit();
        self.basic_blocks.deinit();
    }

    pub fn equal(self: *const SimpleLoop, other: *SimpleLoop) bool {
        return self == other;
    }

    fn addChildLoop(self: *SimpleLoop, loop: *SimpleLoop) void {
        self.children.add(loop);
    }

    fn addNode(self: *SimpleLoop, bb: *BasicBlock) void {
        self.basic_blocks.add(bb);
    }

    fn setParent(self: *SimpleLoop, parent: *SimpleLoop) void {
        self.parent = parent;
        parent.addChildLoop(self);
    }

    fn setNestingLevel(self: *SimpleLoop, level: i32) void {
        self.nesting_level = level;
        if (level == 0) self.is_root = true;
    }
};

const LoopStructureGraph = struct {
    root: *SimpleLoop,
    loops: Vector(*SimpleLoop) = .init(0),
    loop_counter: i32 = 0,

    fn init() LoopStructureGraph {
        var lsg: LoopStructureGraph = .{ .root = SimpleLoop.new(null, true) };
        lsg.root.setNestingLevel(0);
        lsg.root.counter = lsg.loop_counter;
        lsg.loop_counter += 1;
        lsg.loops.append(lsg.root);
        return lsg;
    }

    fn deinit(self: *LoopStructureGraph) void {
        self.loops.destroyValues();
        self.loops.deinit();
    }

    fn createNewLoop(self: *LoopStructureGraph, bb: *BasicBlock, is_reducible: bool) *SimpleLoop {
        const loop = SimpleLoop.new(bb, is_reducible);
        loop.counter = self.loop_counter;
        self.loop_counter += 1;
        self.loops.append(loop);
        return loop;
    }

    fn calculateNestingLevel(self: *LoopStructureGraph) void {
        // link up all 1st level loops to artificial root node.
        self.loops.forEach(self, struct {
            fn f(lsg: *LoopStructureGraph, liter: *SimpleLoop) void {
                if (!liter.is_root) {
                    if (liter.parent == null) liter.setParent(lsg.root);
                }
            }
        }.f);

        // recursively traverse the tree and assign levels.
        calculateNestingLevelRec(self.root, 0);
    }

    fn calculateNestingLevelRec(loop: *SimpleLoop, depth: i32) void {
        loop.depth_level = depth;
        const Context = struct { loop: *SimpleLoop, depth: i32 };
        loop.children.forEach(Context{ .loop = loop, .depth = depth }, struct {
            fn f(ctx: Context, liter: *SimpleLoop) void {
                calculateNestingLevelRec(liter, ctx.depth + 1);
                ctx.loop.setNestingLevel(@max(ctx.loop.nesting_level, 1 + liter.nesting_level));
            }
        }.f);
    }

    fn getNumLoops(self: *const LoopStructureGraph) i32 {
        return @intCast(self.loops.size());
    }
};

const UnionFindNode = struct {
    // `new UnionFindNode()` value-initializes, which zeroes these.
    parent: ?*UnionFindNode = null,
    bb: ?*BasicBlock = null,
    loop: ?*SimpleLoop = null,
    dfs_number: i32 = 0,

    fn initNode(self: *UnionFindNode, bb: *BasicBlock, dfs_number: i32) void {
        self.parent = self;
        self.bb = bb;
        self.dfs_number = dfs_number;
        self.loop = null;
    }

    fn findSet(self: *UnionFindNode) *UnionFindNode {
        var node_list: Vector(*UnionFindNode) = .init(0);
        defer node_list.deinit();

        var node = self;
        while (node != node.parent.?) {
            if (node.parent.? != node.parent.?.parent.?) node_list.append(node);
            node = node.parent.?;
        }

        // Path Compression, all nodes' parents point to the 1st level parent.
        node_list.forEach(self, struct {
            fn f(this: *UnionFindNode, iter: *UnionFindNode) void {
                iter.unionSet(this.parent.?);
            }
        }.f);
        return node;
    }

    fn unionSet(self: *UnionFindNode, basic_block: *UnionFindNode) void {
        self.parent = basic_block;
    }
};

const BasicBlockClass = enum {
    top, // uninitialized
    nonheader, // a regular BB
    reducible, // reducible loop
    self_loop, // single BB loop
    irreducible, // irreducible loop
    dead, // a dead BB
    last, // Sentinel
};

const HavlakLoopFinder = struct {
    const unvisited = std.math.maxInt(i32);
    const max_non_back_preds = 32 * 1024;

    cfg: *ControlFlowGraph,
    lsg: *LoopStructureGraph,

    non_back_preds: Vector(*Set(i32)) = .init(0),
    back_preds: Vector(*Vector(i32)) = .init(0),
    number: IdentityDictionary(BasicBlock, i32),

    max_size: i32 = 0,
    header: []i32 = &.{},
    bb_type: []BasicBlockClass = &.{},
    last: []i32 = &.{},
    nodes: []*UnionFindNode = &.{},

    fn deinit(self: *HavlakLoopFinder) void {
        self.non_back_preds.destroyValues();
        self.back_preds.destroyValues();
        if (self.header.len != 0) mem.free(self.header);
        if (self.bb_type.len != 0) mem.free(self.bb_type);
        if (self.last.len != 0) mem.free(self.last);

        for (self.nodes[0..@intCast(self.max_size)]) |node| mem.destroy(node);
        if (self.nodes.len != 0) mem.free(self.nodes);

        self.number.deinit();
        self.back_preds.deinit();
        self.non_back_preds.deinit();
    }

    fn findLoops(self: *HavlakLoopFinder) void {
        if (self.cfg.start_node == null) return;

        const size = self.cfg.getNumNodes();
        const usize_size: usize = @intCast(size);

        self.non_back_preds.removeAll();
        self.back_preds.removeAll();
        self.number.removeAll();
        if (size > self.max_size) {
            self.header = mem.alloc(i32, usize_size);
            self.bb_type = mem.alloc(BasicBlockClass, usize_size);
            self.last = mem.alloc(i32, usize_size);
            self.nodes = mem.alloc(*UnionFindNode, usize_size);
            self.max_size = size;
        }

        for (0..usize_size) |i| {
            self.non_back_preds.append(mem.create(Set(i32), .init()));
            self.back_preds.append(mem.create(Vector(i32), .init(0)));
            self.nodes[i] = mem.create(UnionFindNode, .{});
        }

        self.initAllNodes();
        self.identifyEdges(size);

        // Start node is root of all other loops.
        self.header[0] = 0;
        var w: i32 = size - 1;
        while (w >= 0) : (w -= 1) {
            const uw: usize = @intCast(w);
            // this is 'P' in Havlak's paper
            var node_pool: Vector(*UnionFindNode) = .init(0);
            defer node_pool.deinit();

            if (self.nodes[uw].bb) |node_w| {
                self.stepD(w, &node_pool);

                // Copy nodePool to workList.
                var work_list: Vector(*UnionFindNode) = .init(0);
                defer work_list.deinit();
                node_pool.forEach(&work_list, struct {
                    fn f(wl: *Vector(*UnionFindNode), niter: *UnionFindNode) void {
                        wl.append(niter);
                    }
                }.f);

                if (node_pool.size() != 0) self.bb_type[uw] = .reducible;

                // work the list...
                while (!work_list.isEmpty()) {
                    const x = work_list.removeFirst().?;

                    const non_back_size: i32 = @intCast(self.non_back_preds.at(@intCast(x.dfs_number)).?.*.size());
                    if (non_back_size > max_non_back_preds) return;
                    self.stepEProcessNonBackPreds(w, &node_pool, &work_list, x);
                }

                if (node_pool.size() > 0 or self.bb_type[uw] == .self_loop) {
                    const loop = self.lsg.createNewLoop(node_w, self.bb_type[uw] != .irreducible);
                    self.setLoopAttributes(w, &node_pool, loop);
                }
            }
        } // Step c
    } // findLoops

    fn isAncestor(self: *const HavlakLoopFinder, w: i32, v: i32) bool {
        return w <= v and v <= self.last[@intCast(w)];
    }

    fn doDFS(self: *HavlakLoopFinder, current_node: *BasicBlock, current: i32) i32 {
        self.nodes[@intCast(current)].initNode(current_node, current);
        self.number.atPut(current_node, current);

        var last_id = current;
        const outer_blocks = &current_node.out_edges;

        var i: i32 = 0;
        while (i < @as(i32, @intCast(outer_blocks.size()))) : (i += 1) {
            const target = outer_blocks.at(@intCast(i)).?.*;
            if (self.number.at(target).?.* == unvisited) last_id = self.doDFS(target, last_id + 1);
        }

        self.last[@intCast(current)] = last_id;
        return last_id;
    }

    fn initAllNodes(self: *HavlakLoopFinder) void {
        self.cfg.basic_block_map.forEach(self, struct {
            fn f(finder: *HavlakLoopFinder, bb: *BasicBlock) void {
                finder.number.atPut(bb, unvisited);
            }
        }.f);
        _ = self.doDFS(self.cfg.start_node.?, 0);
    }

    fn identifyEdges(self: *HavlakLoopFinder, size: i32) void {
        var w: i32 = 0;
        while (w < size) : (w += 1) {
            const uw: usize = @intCast(w);
            self.header[uw] = 0;
            self.bb_type[uw] = .nonheader;

            if (self.nodes[uw].bb) |node_w| {
                self.processEdges(node_w, w);
            } else {
                self.bb_type[uw] = .dead;
            }
        }
    }

    fn processEdges(self: *HavlakLoopFinder, node_w: *BasicBlock, w: i32) void {
        if (node_w.getNumPred() > 0) {
            const Context = struct { finder: *HavlakLoopFinder, w: i32 };
            node_w.in_edges.forEach(Context{ .finder = self, .w = w }, struct {
                fn f(ctx: Context, node_v: *BasicBlock) void {
                    const finder = ctx.finder;
                    const v = finder.number.at(node_v).?.*;
                    if (v != unvisited) {
                        if (finder.isAncestor(ctx.w, v)) {
                            finder.back_preds.at(@intCast(ctx.w)).?.*.append(v);
                        } else {
                            finder.non_back_preds.at(@intCast(ctx.w)).?.*.add(v);
                        }
                    }
                }
            }.f);
        }
    }

    fn stepEProcessNonBackPreds(
        self: *HavlakLoopFinder,
        w: i32,
        node_pool: *Vector(*UnionFindNode),
        work_list: *Vector(*UnionFindNode),
        x: *UnionFindNode,
    ) void {
        const Context = struct {
            finder: *HavlakLoopFinder,
            w: i32,
            node_pool: *Vector(*UnionFindNode),
            work_list: *Vector(*UnionFindNode),
        };
        self.non_back_preds.at(@intCast(x.dfs_number)).?.*.forEach(Context{
            .finder = self,
            .w = w,
            .node_pool = node_pool,
            .work_list = work_list,
        }, struct {
            fn f(ctx: Context, iter: i32) void {
                const finder = ctx.finder;
                const y = finder.nodes[@intCast(iter)];
                const ydash = y.findSet();

                if (!finder.isAncestor(ctx.w, ydash.dfs_number)) {
                    finder.bb_type[@intCast(ctx.w)] = .irreducible;
                    finder.non_back_preds.at(@intCast(ctx.w)).?.*.add(ydash.dfs_number);
                } else {
                    if (ydash.dfs_number != ctx.w) {
                        if (!ctx.node_pool.hasSome(ydash, struct {
                            fn g(yd: *UnionFindNode, e: *UnionFindNode) bool {
                                return e == yd;
                            }
                        }.g)) {
                            ctx.work_list.append(ydash);
                            ctx.node_pool.append(ydash);
                        }
                    }
                }
            }
        }.f);
    }

    fn setLoopAttributes(self: *HavlakLoopFinder, w: i32, node_pool: *Vector(*UnionFindNode), loop: *SimpleLoop) void {
        self.nodes[@intCast(w)].loop = loop;

        const Context = struct { finder: *HavlakLoopFinder, w: i32, loop: *SimpleLoop };
        node_pool.forEach(Context{ .finder = self, .w = w, .loop = loop }, struct {
            fn f(ctx: Context, node: *UnionFindNode) void {
                ctx.finder.header[@intCast(node.dfs_number)] = ctx.w;
                node.unionSet(ctx.finder.nodes[@intCast(ctx.w)]);

                // Nested loops are not added, but linked together.
                if (node.loop) |node_loop| {
                    node_loop.setParent(ctx.loop);
                } else {
                    ctx.loop.addNode(node.bb.?);
                }
            }
        }.f);
    }

    fn stepD(self: *HavlakLoopFinder, w: i32, node_pool: *Vector(*UnionFindNode)) void {
        const Context = struct { finder: *HavlakLoopFinder, w: i32, node_pool: *Vector(*UnionFindNode) };
        self.back_preds.at(@intCast(w)).?.*.forEach(Context{ .finder = self, .w = w, .node_pool = node_pool }, struct {
            fn f(ctx: Context, v: i32) void {
                if (v != ctx.w) {
                    ctx.node_pool.append(ctx.finder.nodes[@intCast(v)].findSet());
                } else {
                    ctx.finder.bb_type[@intCast(ctx.w)] = .self_loop;
                }
            }
        }.f);
    }
};

const LoopTesterApp = struct {
    cfg: ControlFlowGraph,
    lsg: LoopStructureGraph,

    fn init(self: *LoopTesterApp) void {
        self.* = .{ .cfg = .{}, .lsg = .init() };
        _ = self.cfg.createNode(0);
    }

    fn deinit(self: *LoopTesterApp) void {
        self.lsg.deinit();
        self.cfg.deinit();
    }

    fn buildDiamond(self: *LoopTesterApp, start: i32) i32 {
        const bb0 = start;
        BasicBlockEdge.new(&self.cfg, bb0, bb0 + 1);
        BasicBlockEdge.new(&self.cfg, bb0, bb0 + 2);
        BasicBlockEdge.new(&self.cfg, bb0 + 1, bb0 + 3);
        BasicBlockEdge.new(&self.cfg, bb0 + 2, bb0 + 3);
        return bb0 + 3;
    }

    fn buildConnect(self: *LoopTesterApp, start: i32, end: i32) void {
        BasicBlockEdge.new(&self.cfg, start, end);
    }

    fn buildStraight(self: *LoopTesterApp, start: i32, n: i32) i32 {
        var i: i32 = 0;
        while (i < n) : (i += 1) self.buildConnect(start + i, start + i + 1);
        return start + n;
    }

    fn buildBaseLoop(self: *LoopTesterApp, from: i32) i32 {
        const header = self.buildStraight(from, 1);
        const diamond1 = self.buildDiamond(header);
        const d11 = self.buildStraight(diamond1, 1);
        const diamond2 = self.buildDiamond(d11);
        var footer = self.buildStraight(diamond2, 1);
        self.buildConnect(diamond2, d11);
        self.buildConnect(diamond1, header);
        self.buildConnect(footer, from);
        footer = self.buildStraight(footer, 1);
        return footer;
    }

    fn constructSimpleCFG(self: *LoopTesterApp) void {
        _ = self.cfg.createNode(0);
        _ = self.buildBaseLoop(0);
        _ = self.cfg.createNode(1);
        BasicBlockEdge.new(&self.cfg, 0, 2);
    }

    fn main(self: *LoopTesterApp, num_dummy_loops: i32, find_loop_iterations: i32, par_loops: i32, ppar_loops: i32, pppar_loops: i32) [2]i32 {
        self.constructSimpleCFG();
        self.addDummyLoops(num_dummy_loops);
        self.constructCFG(par_loops, ppar_loops, pppar_loops);
        self.findLoops(&self.lsg);
        var i: i32 = 0;
        while (i < find_loop_iterations) : (i += 1) {
            var l: LoopStructureGraph = .init();
            defer l.deinit();
            self.findLoops(&l);
        }

        self.lsg.calculateNestingLevel();
        return .{ self.lsg.getNumLoops(), self.cfg.getNumNodes() };
    }

    fn constructCFG(self: *LoopTesterApp, par_loops: i32, ppar_loops: i32, pppar_loops: i32) void {
        var n: i32 = 2;

        var parlooptrees: i32 = 0;
        while (parlooptrees < par_loops) : (parlooptrees += 1) {
            _ = self.cfg.createNode(n + 1);
            self.buildConnect(2, n + 1);
            n += 1;

            var i: i32 = 0;
            while (i < ppar_loops) : (i += 1) {
                const top = n;
                n = self.buildStraight(n, 1);
                var j: i32 = 0;
                while (j < pppar_loops) : (j += 1) n = self.buildBaseLoop(n);
                const bottom = self.buildStraight(n, 1);
                self.buildConnect(n, top);
                n = bottom;
            }
            self.buildConnect(n, 1);
        }
    }

    fn addDummyLoops(self: *LoopTesterApp, num_dummy_loops: i32) void {
        var dummyloop: i32 = 0;
        while (dummyloop < num_dummy_loops) : (dummyloop += 1) self.findLoops(&self.lsg);
    }

    fn findLoops(self: *LoopTesterApp, loop_structure: *LoopStructureGraph) void {
        var finder: HavlakLoopFinder = .{
            .cfg = &self.cfg,
            .lsg = loop_structure,
            .number = .init(dictionary.initial_capacity),
        };
        defer finder.deinit();
        finder.findLoops();
    }
};

pub const Havlak = struct {
    pub fn innerBenchmarkLoop(self: *Havlak, inner_iterations: i32) bool {
        var app: LoopTesterApp = undefined;
        app.init();
        defer app.deinit();
        return self.verifyResult(app.main(inner_iterations, 50, 10, 10, 5), inner_iterations);
    }

    fn verifyResult(_: *Havlak, r: [2]i32, inner_iterations: i32) bool {
        if (inner_iterations == 15000) return r[0] == 46602 and r[1] == 5213;
        if (inner_iterations == 1500) return r[0] == 6102 and r[1] == 5213;
        if (inner_iterations == 150) return r[0] == 2052 and r[1] == 5213;
        if (inner_iterations == 15) return r[0] == 1647 and r[1] == 5213;
        if (inner_iterations == 1) return r[0] == 1605 and r[1] == 5213;

        std.debug.print("No verification result for {d} found\n", .{inner_iterations});
        std.debug.print("Result is: {d}, {d}\n", .{ r[0], r[1] });
        return false;
    }
};
