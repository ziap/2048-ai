var move_table: Board.MoveTable = undefined;
var expectimax: Expectimax = undefined;
var bfs: Bfs = undefined;

export fn init() void {
  const S = struct {
    var bfs_buffer: [400_000]Board = undefined;
    var heuristic: Heuristic = undefined;
  };

  move_table = .new();
  S.heuristic = .new();

  expectimax = .new(&move_table, &S.heuristic);
  bfs = .new(&S.bfs_buffer, &move_table);
}

export fn search(board: u64, dir: u32) f32 {
  const moves = move_table.getMoves(.{ .data = board });
  const moved = moves[dir];
  if (moved.data == board) return 0;
  const depth = bfs.expand(&.{ moved }).depth + 1;
  return expectimax.expectNode(moved, depth);
}

const Board = @import("lib/Board.zig");
const Heuristic = @import("lib/Heuristic.zig");
const Bfs = @import("lib/Bfs.zig");
const Expectimax = @import("lib/Expectimax.zig");
