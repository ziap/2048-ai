const Heuristic = @This();

score_table: [65536]f32,

pub fn new() Heuristic {
  var table: Heuristic = undefined;
  for (&table.score_table, 0..) |*entry, idx| {
    var row = idx;
    var result: i32 = 0;
    var last = last: {
      const tile: u4 = @truncate(row);
      row >>= 4;
      break :last @as(i32, tile) << tile;
    };

    result += last;

    inline for (0..3) |_| {
      const tile: u4 = @truncate(row);
      row >>= 4;

      const curr = @as(i32, tile) << tile;
      if (last >= curr) {
        result += last + curr;
      } else {
        result += (last - curr) * 12;
      }

      if (last == curr) {
        result += curr;
      }

      last = curr;
    }

    entry.* = @floatFromInt(result);
  }

  return table;
}

pub fn new1() Heuristic {
  var table: Heuristic = undefined;
  for (&table.score_table, 0..) |*entry, idx| {
    var row = idx;
    var last, var result = init: {
      const tile: u4 = @truncate(row);
      row >>= 4;
      break :init .{ tile, @as(i32, tile) << tile };
    };

    inline for (0..3) |_| {
      const tile: u4 = @truncate(row);
      row >>= 4;
      if (tile > 0) {
        if (tile <= last) {
          result += @as(i32, tile) << tile;
        }
        last = tile;
      }
    }

    entry.* = @floatFromInt(result);
  }

  for (&table.score_table, 0..) |*entry, idx| {
    const rev = Board.reverse16(@intCast(idx));
    entry.* = @max(entry.*, table.score_table[rev]);
  }

  return table;
}

pub fn evaluate(self: *const Heuristic, board: Board) f32 {
  var data = board.data;
  var transposed = board.transpose().data;
  var score: f32 = 8388608;

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
