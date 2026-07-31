const CACHE_BITS = 19;
const BFS_BUDGET = 1 << 19;

const Search = engine.Expectimax(*const Heuristic, CACHE_BITS);
const Split = engine.Expectimax(CaptureEval, 0);
const Combine = engine.Expectimax(ReplayEval, 0);

// 4 root moves * 15 empty cells * 2 spawn values * 4 moves = 480 evaluations,
// worst case, and no dedup happens along the way.
const MAX_FRONTIER = 512;

var ctx: struct {
  move_table: Board.MoveTable,
  heuristic: Heuristic,
  cache: Search.Cache,
} = undefined;

var frontier: [MAX_FRONTIER]u64 = undefined;
var scores: [MAX_FRONTIER]f32 = undefined;
var frontier_len: u32 = 0;
var replay_idx: u32 = 0;

const CaptureEval = struct {
  pub fn evaluate(_: CaptureEval, board: Board) f32 {
    if (frontier_len >= MAX_FRONTIER) unreachable;
    frontier[frontier_len] = board.data;
    frontier_len += 1;
    return 0;
  }
};

const ReplayEval = struct {
  pub fn evaluate(_: ReplayEval, board: Board) f32 {
    if (replay_idx >= frontier_len) unreachable;
    if (frontier[replay_idx] != board.data) unreachable;
    const score = scores[replay_idx];
    replay_idx += 1;
    return score;
  }
};

const search_fn = blk: {
  const expectimax: Search = .{
    .move_table = &ctx.move_table,
    .heuristic = &ctx.heuristic,
    .cache = &ctx.cache,
  };
  break :blk expectimax.reset();
};

const split_fn = blk: {
  const expectimax: Split = .{
    .move_table = &ctx.move_table,
    .heuristic = .{},
    .cache = {},
  };
  break :blk expectimax.reset();
};

const combine_fn = blk: {
  const expectimax: Combine = .{
    .move_table = &ctx.move_table,
    .heuristic = .{},
    .cache = {},
  };
  break :blk expectimax.reset();
};

// Called once, by the worker that runs `search`. The pool parks before it
// touches any of this, and the host holds the first search until every worker
// has reported in.
export fn init() void {
  ctx.move_table.init();
  ctx.heuristic.init();
  _ = search_fn.inner.reset();
}

fn allocDepth(board: Board) u8 {
  const S = struct {
    var bfs_buffer: [BFS_BUDGET]Board = undefined;
  };
  const moves = ctx.move_table.getMoves(board);
  const valid = board.filterMoves(&moves);
  const buffer = S.bfs_buffer[0..S.bfs_buffer.len];
  var bfs: Bfs = .new(buffer, &ctx.move_table);
  return bfs.expand(valid.moves[0..valid.len]).depth + 1;
}

// -- worker pool --------------------------------------------------------------

const MAX_POOL = 31;
const WORKER_STACK = 256 * 1024;
const ALL_WAITERS = ~@as(u32, 0);

// Wasm globals stay per-instance while linear memory does not, so every
// instance's __stack_pointer starts at the same address and they would all push
// frames onto the same region. Pool workers move theirs here; the one running
// `search` keeps the linker's stack.
var stacks: [MAX_POOL][WORKER_STACK]u8 align(16) = undefined;
var next_slot: u32 = 0;

// `epoch` publishes a batch and is what parked workers block on. `cursor` is
// [tag:8][index:24]: the tag stops a worker still draining batch k from taking
// an index out of batch k + 1, since the cursor is reset the moment the last
// task of k completes. `done` counts completed tasks rather than workers, so a
// worker that never woke for this batch can't hold up the move.
var epoch: u32 align(64) = 0;
var batch_count: u32 = 0;
var batch_depth: u32 = 0;
var cursor: u32 align(64) = 0;
var done: u32 align(64) = 0;

inline fn setStackPointer(addr: [*]u8) void {
  asm volatile (
    \\ local.get %[ptr]
    \\ global.set __stack_pointer
    :
    : [ptr] "r" (addr),
  );
}

inline fn wait(ptr: *const u32, expected: u32) void {
  _ = asm volatile (
    \\ local.get %[ptr]
    \\ local.get %[expected]
    \\ i64.const -1 # infinite
    \\ memory.atomic.wait32 0
    \\ local.set %[ret]
    : [ret] "=r" (-> u32),
    : [ptr] "r" (ptr),
      [expected] "r" (expected),
  );
}

inline fn notify(ptr: *const u32, waiters: u32) void {
  asm volatile (
    \\ local.get %[ptr]
    \\ local.get %[waiters]
    \\ memory.atomic.notify 0
    \\ drop # no need to know the waiter count
    :
    : [ptr] "r" (ptr),
      [waiters] "r" (waiters),
  );
}

fn grab(tag: u8, count: u32) ?u32 {
  while (true) {
    const cur = @atomicLoad(u32, &cursor, .seq_cst);
    if (@as(u8, @truncate(cur >> 24)) != tag) return null;

    const idx = cur & 0xffffff;
    if (idx >= count) return null;

    if (@cmpxchgWeak(u32, &cursor, cur, cur + 1, .seq_cst, .seq_cst) == null) return idx;
  }
}

fn runTasks(tag: u8) void {
  const count = @atomicLoad(u32, &batch_count, .seq_cst);
  const depth: u8 = @intCast(@atomicLoad(u32, &batch_depth, .seq_cst));

  while (grab(tag, count)) |idx| {
    // Plain accesses: the epoch this worker acquired published the frontier,
    // and the counter below publishes the score.
    scores[idx] = search_fn.inner.expectNode(.{ .data = frontier[idx] }, depth);
    if (@atomicRmw(u32, &done, .Add, 1, .seq_cst) + 1 >= count) notify(&done, 1);
  }
}

// Claims a stack and never returns -- the calling worker parks here between
// batches instead of going back to its event loop.
export fn poolWorker() void {
  const slot = @atomicRmw(u32, &next_slot, .Add, 1, .seq_cst);
  if (slot >= MAX_POOL) return;

  setStackPointer(@ptrFromInt(@intFromPtr(&stacks[slot]) + WORKER_STACK));

  var seen = @atomicLoad(u32, &epoch, .seq_cst);
  while (true) {
    wait(&epoch, seen);
    seen = @atomicLoad(u32, &epoch, .seq_cst);
    runTasks(@truncate(seen));
  }
}

export fn search(board_data: u64) i32 {
  const board: Board = .{ .data = board_data };
  const depth = allocDepth(board);

  frontier_len = 0;
  _ = split_fn.call(board, 1);
  const count = frontier_len;

  if (count > 0) {
    const next = @atomicLoad(u32, &epoch, .seq_cst) +% 1;
    const tag: u8 = @truncate(next);

    @atomicStore(u32, &batch_count, count, .seq_cst);
    @atomicStore(u32, &batch_depth, depth - 1, .seq_cst);
    @atomicStore(u32, &done, 0, .seq_cst);
    @atomicStore(u32, &cursor, @as(u32, tag) << 24, .seq_cst);
    @atomicStore(u32, &epoch, next, .seq_cst);
    notify(&epoch, ALL_WAITERS);

    // This thread is a worker too, so it drains the same queue before waiting
    // on whoever is still busy.
    runTasks(tag);

    while (true) {
      const finished = @atomicLoad(u32, &done, .seq_cst);
      if (finished >= count) break;
      wait(&done, finished);
    }
  }

  replay_idx = 0;
  const dir = combine_fn.call(board, 1);
  return dir orelse -1;
}

const engine = @import("engine");
const Board = engine.Board;
const Heuristic = engine.Heuristic;
const Bfs = engine.Bfs;
