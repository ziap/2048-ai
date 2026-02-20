const Expectimax = search.Expectimax(*const Heuristic, true);

var move_table: Board.MoveTable = undefined;
var expectimax: Expectimax = undefined;

export fn init() void {
  const S = struct {
    var heuristic: Heuristic = undefined;
  };

  move_table = .new();
  S.heuristic = .new();

  expectimax = .new(&move_table, &S.heuristic);
}

export fn evaluate(board_data: u64, dir: u32) f32 {
  const S = struct {
    var bfs_buffer: [1 << 19]Board = undefined;
  };
  const board: Board = .{ .data = board_data };
  const moves = move_table.getMoves(board);
  const valid = board.filterMoves(&moves);
  const buffer = S.bfs_buffer[0..S.bfs_buffer.len / valid.len];
  var bfs: Bfs = .new(buffer, &move_table);

  const moved = moves[dir];
  if (moved.data == board_data) return 0;
  const depth = bfs.expand(&.{ moved }).depth + 1;
  return expectimax.expectNode(moved, depth);
}

const Board = @import("lib/Board.zig");
const Heuristic = @import("lib/Heuristic.zig");
const Bfs = @import("lib/Bfs.zig");
const search = @import("lib/search.zig");
