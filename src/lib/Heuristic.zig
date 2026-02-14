const Heuristic = @This();

score_table: [65536]f32,

const SCORE_LOST_PENALTY = 200000.0;
const SCORE_MONOTONICITY_POWER = 4.0;
const SCORE_MONOTONICITY_WEIGHT = 47.0;
const SCORE_SUM_POWER = 3.5;
const SCORE_SUM_WEIGHT = 11.0;
const SCORE_MERGES_WEIGHT = 700.0;
const SCORE_EMPTY_WEIGHT = 270.0;

inline fn pow(x: f32, y: comptime_float) f32 {
  return @exp2(@log2(x) * y);
}

pub fn new() Heuristic {
  var table: Heuristic = undefined;
  for (&table.score_table, 0..) |*entry, row| {
    const line = [_]u4 {
      @truncate(row >> 0),
      @truncate(row >> 4),
      @truncate(row >> 8),
      @truncate(row >> 12),
    };

    var sum: f32 = 0;
    var empty: u32 = 0;
    var merges: u32 = 0;

    var prev: u4 = 0;
    var counter: u32 = 0;

    for (line) |rank| {
      sum += pow(@floatFromInt(rank), SCORE_SUM_POWER);

      if (rank == 0) {
        empty += 1;
      } else {
        if (prev == rank) {
          counter += 1;
        } else if (counter > 0) {
          merges += 1 + counter;
          counter = 0;
        }

        prev = rank;
      }
    }

    if (counter > 0) merges += 1 + counter;

    var monotonicity_left: f32 = 0;
    var monotonicity_right: f32 = 0;

    inline for (1..4) |i| {
      const l = pow(@floatFromInt(line[i - 1]), SCORE_MONOTONICITY_POWER);
      const r = pow(@floatFromInt(line[i]), SCORE_MONOTONICITY_POWER);

      if (line[i - 1] > line[i]) {
        monotonicity_left += l - r;
      } else {
        monotonicity_right += r - l;
      }
    }

    entry.* = SCORE_LOST_PENALTY +
      SCORE_EMPTY_WEIGHT * @as(f32, @floatFromInt(empty)) +
      SCORE_MERGES_WEIGHT * @as(f32, @floatFromInt(merges)) -
      SCORE_MONOTONICITY_WEIGHT * @min(monotonicity_left, monotonicity_right) -
      SCORE_SUM_WEIGHT * sum;
  }

  return table;
}

pub fn evaluate(self: *const Heuristic, board: Board) f32 {
  var data = board.data;
  var transposed = board.transpose().data;
  var score: f32 = 0;

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
