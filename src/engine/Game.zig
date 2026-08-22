const Game = @This();

pub const State = struct {
  board: BoardExt,
  four_count: u32,

  pub const empty: State = .{
    .board = .{
      .clamped = .{ .data = 0, },
      .ext = 0,
    },
    .four_count = 0,
  };

  pub fn display(self: State, out: anytype) !void {
    const first_line = "+-------+-------+-------+-------+\n";
    const line = "|\n" ++ first_line;

    var data = self.board.clamped.data;
    var ext = self.board.ext;

    try out.writeAll(first_line);

    for (0..4) |_| {
      for (0..4) |_| {
        const lut = comptime lut: {
          const tiles = &.{
            "     ", "    2", "    4", "    8",
            "   16", "   32", "   64", "  128",
            "  256", "  512", " 1024", " 2048",
            " 4096", " 8192", "16384", "32768",
          };

          var lut: [tiles.len][]const u8 = undefined;
          for (&lut, tiles) |*entry, tile| {
            entry.* = "| " ++ tile ++ " ";
          }

          break :lut lut;
        };

        const tile = data >> 60;
        try out.writeAll(if ((ext >> 15) == 0) lut[tile] else "| 65536 ");

        data <<= 4;
        ext <<= 1;
      }
      try out.writeAll(line);
    }
  }

  pub fn score(self: State) u32 {
    var data = self.board.clamped.data;
    var ext = self.board.ext;

    var result: u32 = 0;
    for (0..16) |_| {
      const tile: u5 = if (ext & 1 == 0) @as(u4, @truncate(data)) else 16;
      result += @as(u32, tile -| 1) << tile;
      data >>= 4;
      ext >>= 1;
    }
    return result - 4 * self.four_count;
  }

  pub fn maxTile(self: State) u5 {
    if (self.board.ext > 0) return 16;

    var result: u4 = 0;
    var data = self.board.clamped.data;

    for (0..16) |_| {
      const tile: u4 = @truncate(data);
      result = @max(result, tile);
      data >>= 4;
    }

    return result;
  }
};

state: State,
move_table: *const BoardExt.MoveTable,
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

pub fn new(rng: Fmc256, move_table: *const BoardExt.MoveTable) Game {
  var local_rng = rng;
  const board: Board = .{ .data = 0 };
  const board1, const is_four1 = addTile(board, &local_rng);
  const board2, const is_four2 = addTile(board1, &local_rng);

  return .{
    .state = .{
      .board = .{ .clamped = board2, .ext = 0 },
      .four_count = @as(u2, is_four1) + @as(u2, is_four2),
    },
    .move_table = move_table,
    .rng = local_rng,
  };
}

pub fn executeMove(self: *Game, moved: BoardExt) void {
  const board, const is_four = addTile(moved.clamped, &self.rng);
  self.state.board = .{ .clamped = board, .ext = moved.ext };
  self.state.four_count += is_four;
}

const Board = @import("Board.zig");
const BoardExt = @import("BoardExt.zig");
const Fmc256 = @import("utils").Fmc256;
