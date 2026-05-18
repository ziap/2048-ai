const Expectimax = engine.Expectimax(*const Heuristic, true);

var ctx: struct {
  move_table: Board.MoveTable,
  heuristic: Heuristic,
  cache: Expectimax.Cache,
} = undefined;

const search_fn = blk: {
  const expectimax: Expectimax = .{
    .move_table = &ctx.move_table,
    .heuristic = &ctx.heuristic,
    .cache = &ctx.cache,
  };
  break :blk expectimax.reset();
};

export fn init() void {
  ctx.move_table.init();
  ctx.heuristic.init();
  _ = search_fn.inner.reset();
}

export fn search(board_data: u64) i32 {
  const S = struct {
    var bfs_buffer: [327680]Board = undefined;
  };
  const board: Board = .{ .data = board_data };
  const moves = ctx.move_table.getMoves(board);
  const valid = board.filterMoves(&moves);
  const buffer = S.bfs_buffer[0..S.bfs_buffer.len];
  var bfs: Bfs = .new(buffer, &ctx.move_table);
  const depth = bfs.expand(valid.moves[0..valid.len]).depth + 1;
  const dir = search_fn.call(board, depth);
  return dir orelse -1;
}

const engine = @import("engine");
const Board = engine.Board;
const Heuristic = engine.Heuristic;
const Bfs = engine.Bfs;
