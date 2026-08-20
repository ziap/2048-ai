const Game = @This();

board: Board,
four_count: u32,
move_table: *const Board.MoveTable,
rng: Fmc256,

fn addTile(self: Board, rng: *Fmc256) struct { Board, u1 } {
  const mask = self.emptyPos();
  const empty_count = @popCount(mask);

  const tile = tile: {
    const idx = rng.bounded(empty_count);
    var t = mask;
    for (0..idx) |_| {
      t &= t - 1;
    }
    break :tile t & -%t;
  };
  const shift: u1 = if (rng.bounded(10) == 0) 1 else 0;

  return .{
    .{ .data = self.data | (tile << shift) },
    shift,
  };
}

pub fn new(rng: Fmc256, move_table: *const Board.MoveTable) Game {
  var local_rng = rng;
  const board: Board = .{ .data = 0 };
  const board1, const is_four1 = addTile(board, &local_rng);
  const board2, const is_four2 = addTile(board1, &local_rng);

  return .{
    .board = board2,
    .four_count = @as(u2, is_four1) + @as(u2, is_four2),
    .move_table = move_table,
    .rng = local_rng,
  };
}

pub inline fn getBoard(self: *const Game) Board {
  return self.board;
}

pub fn executeMove(self: *Game, dir: u2) void {
  const moves = self.move_table.getMoves(self.board);
  const board, const is_four = addTile(moves[dir], &self.rng);
  self.board = board;
  self.four_count += is_four;
}

const Board = @import("Board.zig");
const Fmc256 = @import("Fmc256.zig");
