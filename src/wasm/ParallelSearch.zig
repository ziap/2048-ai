const ParallelSearch = @This();

const CACHE_BITS = 20;

// 4 root moves * 15 empty cells * 2 spawn values * 4 moves = 480 evaluations,
// worst case, and no dedup happens along the way.
const MAX_FRONTIER = 512;

const ALL_WAITERS = ~@as(u32, 0);

const Search = engine.Expectimax(*const Heuristic, CACHE_BITS);
const Split = engine.Expectimax(CaptureEval, 0);
const Combine = engine.Expectimax(ReplayEval, 0);

move_table: *const Board.MoveTable,
heuristic: *const Heuristic,
cache: Search.Cache,

board: Board,
formation: Board.Formation,

// Written by `request`, read by every worker; the scores go back the
// other way. Publishing the epoch releases the first, the completion
// count releases the second.
frontier: [MAX_FRONTIER]u64,
scores: [MAX_FRONTIER]f32,
frontier_len: u32,
replay_idx: u32,

// `epoch` publishes a batch and is what parked workers block on. `cursor` is
// [tag:8][index:24]: the tag stops a worker still draining batch k from taking
// an index out of batch k + 1, since the cursor is reset the moment the last
// task of k completes. `done` counts completed tasks rather than workers, so a
// worker that never woke for this batch can't hold up the move.
epoch: u32 align(64),
batch_count: u32,
batch_depth: u32,
cursor: u32 align(64),
done: u32 align(64),

const CaptureEval = struct {
  owner: *ParallelSearch,

  pub fn evaluate(self: CaptureEval, board: Board) f32 {
    const owner = self.owner;
    if (owner.frontier_len >= MAX_FRONTIER) unreachable;

    owner.frontier[owner.frontier_len] = board.data;
    owner.frontier_len += 1;
    return 0;
  }
};

const ReplayEval = struct {
  owner: *ParallelSearch,

  pub fn evaluate(self: ReplayEval, board: Board) f32 {
    const owner = self.owner;
    if (owner.replay_idx >= owner.frontier_len) unreachable;
    if (owner.frontier[owner.replay_idx] != board.data) unreachable;

    const score = owner.scores[owner.replay_idx];
    owner.replay_idx += 1;
    return score;
  }
};

inline fn searcher(self: *ParallelSearch) Search {
  return .{
    .move_table = self.move_table,
    .heuristic = self.heuristic,
    .cache = &self.cache,
  };
}

inline fn splitter(self: *ParallelSearch) Split.Fn {
  const expectimax: Split = .{
    .move_table = self.move_table,
    .heuristic = .{ .owner = self },
    .cache = {},
  };
  return expectimax.reset(self.formation);
}

inline fn combiner(self: *ParallelSearch) Combine.Fn {
  const expectimax: Combine = .{
    .move_table = self.move_table,
    .heuristic = .{ .owner = self },
    .cache = {},
  };
  return expectimax.reset(self.formation);
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

fn grab(self: *ParallelSearch, tag: u8, count: u32) ?u32 {
  while (true) {
    const cur = @atomicLoad(u32, &self.cursor, .seq_cst);
    if (@as(u8, @truncate(cur >> 24)) != tag) return null;

    const idx = cur & 0xffffff;
    if (idx >= count) return null;

    if (@cmpxchgWeak(u32, &self.cursor, cur, cur + 1, .seq_cst, .seq_cst) == null) return idx;
  }
}

fn runTasks(self: *ParallelSearch, tag: u8) void {
  const count = @atomicLoad(u32, &self.batch_count, .seq_cst);
  const depth: u8 = @intCast(@atomicLoad(u32, &self.batch_depth, .seq_cst));
  const search = self.searcher();

  const formation = self.formation;

  while (self.grab(tag, count)) |idx| {
    // Plain accesses: the epoch this worker acquired published the frontier,
    // the formation and the depth, and the counter below publishes the score.
    self.scores[idx] = search.expectNode(.{ .data = self.frontier[idx] }, depth, formation);
    if (@atomicRmw(u32, &self.done, .Add, 1, .seq_cst) + 1 >= count) notify(&self.done, 1);
  }
}

fn publish(self: *ParallelSearch, depth: u8) u8 {
  const next = @atomicLoad(u32, &self.epoch, .seq_cst) +% 1;
  const tag: u8 = @truncate(next);

  @atomicStore(u32, &self.batch_count, self.frontier_len, .seq_cst);
  @atomicStore(u32, &self.batch_depth, depth, .seq_cst);
  @atomicStore(u32, &self.done, 0, .seq_cst);
  @atomicStore(u32, &self.cursor, @as(u32, tag) << 24, .seq_cst);
  @atomicStore(u32, &self.epoch, next, .seq_cst);
  notify(&self.epoch, ALL_WAITERS);

  return tag;
}

fn awaitBatch(self: *ParallelSearch, count: u32) void {
  while (true) {
    const finished = @atomicLoad(u32, &self.done, .seq_cst);
    if (finished >= count) break;
    wait(&self.done, finished);
  }
}

pub fn init(self: *ParallelSearch, move_table: *const Board.MoveTable, heuristic: *const Heuristic) void {
  self.move_table = move_table;
  self.heuristic = heuristic;

  self.frontier_len = 0;
  self.replay_idx = 0;
  self.formation = .none;

  self.epoch = 0;
  self.batch_count = 0;
  self.batch_depth = 0;
  self.cursor = 0;
  self.done = 0;

  // Clears the transposition table
  _ = self.searcher().reset(null);
}

// Builds the frontier for `board` and hands it to the pool at `depth`,
// Returns the batch tag for `finalize`. The pool is already working
// when this returns.
pub fn request(self: *ParallelSearch, board: Board, formation: Board.Formation, depth: u8) u8 {
  self.board = board;
  self.frontier_len = 0;

  self.formation = formation;
  _ = self.searcher().reset(formation);

  const split = self.splitter();
  _ = split.call(board, 1);

  // A position with no legal move produces no frontier, and nothing to
  // hand out
  if (self.frontier_len == 0) return 0;

  return self.publish(depth);
}

// Waits out the batch `request` handed over, re-running it if `depth`
// came out / deeper than what was predicted, and returns the move the
// scores choose.
pub fn finalize(self: *ParallelSearch, tag: u8, depth: u8) ?u2 {
  const count = self.frontier_len;

  if (count > 0) {
    // The caller is a worker too, so it drains whatever the pool has
    // left before waiting on whoever is still busy.
    self.runTasks(tag);
    self.awaitBatch(count);

    // The prediction was short: score the same frontier again, deeper,
    // overwriting the scores the replay reads.
    if (depth > self.batch_depth) {
      const deeper = self.publish(depth);
      self.runTasks(deeper);
      self.awaitBatch(count);
    }
  }

  self.replay_idx = 0;
  const combine = self.combiner();
  return combine.call(self.board, 1);
}

// Parks until there is a batch, works it, parks again.
// `noinline` to avoid creating a stack frame
pub noinline fn poolLoop(self: *ParallelSearch) noreturn {
  var seen = @atomicLoad(u32, &self.epoch, .seq_cst);
  while (true) {
    wait(&self.epoch, seen);
    seen = @atomicLoad(u32, &self.epoch, .seq_cst);
    self.runTasks(@truncate(seen));
  }
}

const engine = @import("engine");
const Board = engine.Board;
const Heuristic = engine.Heuristic;
