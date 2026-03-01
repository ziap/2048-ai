const Heuristic = @This();

score_table: [65536]f32,

const LOST_PENALTY = 200000.0;
const MONO_POWER = 4.0;
const MONO_WEIGHT = 47.0;
const SUM_POWER = 3.5;
const SUM_WEIGHT = 11.0;
const MERGES_WEIGHT = 700.0;
const EMPTY_WEIGHT = 270.0;

pub fn new() Heuristic {
  const pow_tables = comptime pow_tables: {
    var sum_pow_table: [16]f32 = undefined;
    var mono_pow_table: [16]f32 = undefined;

    for (1..16) |idx| {
      const fidx: f32 = @floatFromInt(idx);
      sum_pow_table[idx] = @exp2(@log2(fidx) * SUM_POWER);
      mono_pow_table[idx] = @exp2(@log2(fidx) * MONO_POWER);
    }

    sum_pow_table[0] = 0;
    mono_pow_table[0] = 0;

    break :pow_tables .{
      .sum = sum_pow_table,
      .mono = mono_pow_table,
    };
  };

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

    inline for (line) |rank| {
      sum += pow_tables.sum[rank];

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

    var mono_left: f32 = 0;
    var mono_right: f32 = 0;

    inline for (1..4) |i| {
      const l = pow_tables.mono[line[i - 1]];
      const r = pow_tables.mono[line[i]];

      if (line[i - 1] > line[i]) {
        mono_left += l - r;
      } else {
        mono_right += r - l;
      }
    }

    entry.* = LOST_PENALTY +
      EMPTY_WEIGHT * @as(f32, @floatFromInt(empty)) +
      MERGES_WEIGHT * @as(f32, @floatFromInt(merges)) -
      MONO_WEIGHT * @min(mono_left, mono_right) -
      SUM_WEIGHT * sum;
  }

  return table;
}

pub fn evaluate(self: *const Heuristic, board: Board) f32 {
  const data = board.data;
  const transposed = board.transpose().data;
  var score: f32 = 0;

  inline for (0..4) |idx| {
    const shift = comptime idx * 16;
    const row: u16 = @truncate(data >> shift);
    const col: u16 = @truncate(transposed >> shift);

    score += self.score_table[row] + self.score_table[col];
  }

  return score;
}

const Board = @import("Board.zig");
