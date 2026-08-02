const BFS_BUDGET = 655360;

const MAX_POOL = 31;
const WORKER_STACK = 256 * 1024;

var ctx: struct {
  move_table: Board.MoveTable,
  heuristic: Heuristic,
  searcher: ParallelSearch,

  // The depth this position is searched at, predicted from the position before
  // it. Depth moves by a ply at a time and only as the board fills, so the
  // prediction is almost always right -- and being a move late is what lets the
  // BFS run alongside the search instead of in front of it.
  prev_depth: u8,
} = undefined;

// Called once, by the worker that runs `search`.
export fn init() void {
  ctx.move_table.init();
  ctx.heuristic.init();
  ctx.searcher.init(&ctx.move_table, &ctx.heuristic);
  ctx.prev_depth = 0;
}

fn allocDepth(board: Board) u8 {
  const S = struct {
    var bfs_buffer: [BFS_BUDGET]Board = undefined;
  };
  const moves = ctx.move_table.getMoves(board);
  const valid = board.filterMoves(&moves);
  const buffer = S.bfs_buffer[0..S.bfs_buffer.len];
  var bfs: Bfs = .new(buffer, &ctx.move_table);
  return bfs.expand(valid.moves[0..valid.len]).depth;
}

export fn reset_depth() void {
  ctx.prev_depth = 0;
}

export fn search(board_data: u64) i32 {
  const board: Board = .{ .data = board_data };

  const predicted = ctx.prev_depth;
  const tag = ctx.searcher.request(board, predicted);

  // Runs while the pool is already scoring the frontier, so nothing waits on
  // it -- it settles what depth this move should have had, and predicts the
  // next one.
  const depth = allocDepth(board);
  ctx.prev_depth = depth;

  const dir = ctx.searcher.finalize(tag, depth);
  return dir orelse -1;
}

// Claims a stack and never returns. Nothing here may need a stack frame of its
// own: the prologue that would reserve one runs before the switch below, and
// would take it from the linker's stack, which the searching thread owns.
export fn poolWorker() noreturn {
  const S = struct {
    // Stack per worker in the shared memory
    var stacks: [MAX_POOL][WORKER_STACK]u8 align(16) = undefined;
    var next_slot: u32 = 0;
  };

  const slot = @atomicRmw(u32, &S.next_slot, .Add, 1, .seq_cst);

  // JS must enforce worker limit
  if (slot >= MAX_POOL) unreachable;

  // Stacks grow down, so the pointer starts at the end
  const stack = &S.stacks[slot];
  const stack_ptr = stack[stack.len..].ptr;

  asm volatile (
    \\ local.get %[ptr]
    \\ global.set __stack_pointer
    :
    : [ptr] "r" (stack_ptr),
  );

  ctx.searcher.poolLoop();
}

const engine = @import("engine");
const Board = engine.Board;
const Heuristic = engine.Heuristic;
const Bfs = engine.Bfs;

const ParallelSearch = @import("ParallelSearch.zig");
