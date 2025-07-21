const Heuristic = @This();

score_table: [65536]u32,

pub fn new() Heuristic {
  var table: Heuristic = undefined;
  for (&table.score_table, 0..) |*entry, idx| {
    var row = idx;
    var result: u32 = 0;
    var last = last: {
      const tile: u4 = @truncate(row);
      row >>= 4;
      result += @as(u32, tile) << tile;
      break :last tile;
    };

    inline for (0..3) |_| {
      const tile: u4 = @truncate(row);
      row >>= 4;
      if (tile > 0) {
        if (tile <= last) {
          result += @as(u32, tile) << tile;
        }
        last = tile;
      }
    }

    entry.* = result;
  }

  for (&table.score_table, 0..) |*entry, idx| {
    const rev = common.reverse16(@intCast(idx));
    entry.* = @max(entry.*, table.score_table[rev]);
  }

  return table;
}

pub fn evaluate(self: *const Heuristic, board: Board) u32 {
  var data = board.data;
  var transposed = board.transpose().data;
  var score: u32 = 0;

  for (0..4) |_| {
    const row: u16 = @truncate(data);
    const col: u16 = @truncate(transposed);
    data >>= 16;
    transposed >>= 16;

    score += self.score_table[row] + self.score_table[col];
  }

  return score;
}

const Board = @import("Board.zig");
const common = @import("common.zig");
