pub const UP: u4 = 0;
pub const RIGHT: u4 = 1;
pub const DOWN: u4 = 2;
pub const LEFT: u4 = 3;

const Board = @This();
const Fmc256 = @import("Fmc256.zig");

data: u64,

pub fn display(self: Board, out: anytype) !void {
  const first_line = "+-------+-------+-------+-------+\n";
  const line = "|\n" ++ first_line;

  var data = self.data;
  try out.writeAll(first_line);

  inline for (0..4) |_| {
    inline for (0..4) |_| {
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
      data <<= 4;
      try out.writeAll(lut[tile]);
    }
    try out.writeAll(line);
  }
}

pub fn emptyPos(self: Board) u64 {
  var b = self.data;
  b |= (b >> 2) & 0x3333333333333333;
  b |= (b >> 1);
  return ~b & 0x1111111111111111;
}

pub fn addTile(self: Board, rng: *Fmc256) Board {
  const mask = self.emptyPos();
  const empty_count = @popCount(mask);

  const tile = tile: {
    const idx = rng.bounded(empty_count);
    var t = mask;
    for (0..idx) |_| {
      t &= t - 1;
    }
    break :tile t & -% t;
  };
  const shift: u1 = if (rng.bounded(10) == 0) 1 else 0;

  return .{
    .data = self.data | (tile << shift)
  };
}

pub fn new(rng: *Fmc256) Board {
  const board: Board = .{ .data = 0 };
  return board.addTile(rng).addTile(rng);
}

pub fn transpose(self: Board) Board {
  var x = self.data;
  var b = (x ^ (x >> 12)) & 0x0000f0f00000f0f0;
  x ^= b ^ (b << 12);
  b = (x ^ (x >> 24)) & 0x00000000ff00ff00;
  x ^= b ^ (b << 24);
  return .{ .data = x };
}

pub const MoveTable = struct {
  const MAX_ROW = 65536;

  forward_table: [MAX_ROW]u16,
  reverse_table: [MAX_ROW]u16,

  pub fn new() MoveTable {
    var table: MoveTable = undefined;

    for (0..MAX_ROW) |row| {
      var line = [_]u4 {
        @truncate(row >> 0),
        @truncate(row >> 4),
        @truncate(row >> 8),
        @truncate(row >> 12),
      };

      var furthest: u3 = 4;
      var merged = false;

      var i: u3 = 3;
      while (i < 4) : (i -%= 1) {
        if (line[i] == 0) continue;

        if (!merged and furthest < 4 and line[i] == line[furthest]) {
          line[furthest] = line[furthest] +| 1;
          line[i] = 0;
          merged = true;
        } else if (furthest == i + 1) {
          furthest = i;
        } else {
          furthest -= 1;
          line[furthest] = line[i];
          line[i] = 0;
          merged = false;
        }
      }

      const moved = moved: {
        var moved: u16 = 0;
        inline for (line, 0..) |cell, idx| {
          moved |= @as(u16, cell) << @intCast(idx * 4);
        }

        break :moved moved;
      };

      table.forward_table[row] = moved;
      table.reverse_table[common.reverse16(@intCast(row))] = common.reverse16(moved);
    }

    return table;
  }

  pub fn getMoves(self: MoveTable, board: Board) [4]Board {
    var data = board.data;
    var transposed = board.transpose().data;

    var result: [4]Board = undefined;

    inline for (0..4) |_| {
      const row = data >> 48;
      const col = transposed >> 48;
      data <<= 16;
      transposed <<= 16;

      inline for (0..4) |dir| {
        result[dir].data <<= 16;
      }

      result[UP].data    |= self.forward_table[col];
      result[DOWN].data  |= self.reverse_table[col];
      result[LEFT].data  |= self.forward_table[row];
      result[RIGHT].data |= self.reverse_table[row];
    }

    result[UP] = result[UP].transpose();
    result[DOWN] = result[DOWN].transpose();

    return result;
  }
};

const ValidMoves = struct {
  len: u5,
  moves: [4]Board,
};

pub fn filterMoves(self: Board, moves: *const [4]Board) ValidMoves {
  var result: ValidMoves = .{
    .len = 0,
    .moves = undefined,
  };

  inline for (moves) |move| {
    if (move.data != self.data) {
      result.moves[result.len] = move;
      result.len += 1;
    }
  }

  return result;
}

pub fn maxTile(self: Board) u4 {
  var result: u4 = 0;
  var data = self.data;

  inline for (0..16) |_| {
    const tile: u4 = @truncate(data);
    result = @max(result, tile);
    data >>= 4;
  }

  return result;
}

pub const lessThan = struct {
  pub fn inner(_: void, a: Board, b: Board) bool {
    return a.data < b.data;
  }
}.inner;

pub const HASH_MUL = 0xf1357aea2e62a9c5;

// Lehmer64 PRNG hash function, a very fast but weak hash function that
// comphensate its speed for some extra collisions
pub fn hash(self: Board, bits: comptime_int) common.Uint(bits) {
  // MCG multiplier from: <https://arxiv.org/pdf/2001.05304>
  const h = self.data *% HASH_MUL;

  // I use shift instead of truncation because the high bits have better
  // statistical quality
  return @intCast(h >> (64 - bits));
}

const common = @import("common.zig");
