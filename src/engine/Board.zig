pub const UP: u2 = 0;
pub const RIGHT: u2 = 1;
pub const DOWN: u2 = 2;
pub const LEFT: u2 = 3;

const MULT = 0xf1357aea2e62a9c5;

const Board = @This();
const Fmc256 = @import("Fmc256.zig");

data: u64,

pub fn display(self: Board, out: anytype) !void {
  const first_line = "+-------+-------+-------+-------+\n";
  const line = "|\n" ++ first_line;

  var data = self.data;
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
      data <<= 4;
      try out.writeAll(lut[tile]);
    }
    try out.writeAll(line);
  }
}

pub inline fn emptyPos(self: Board) u64 {
  var b = self.data;
  b |= (b >> 2) & 0x3333333333333333;
  b |= (b >> 1);
  return ~b & 0x1111111111111111;
}

pub fn addTile(self: Board, rng: *Fmc256) struct { Board, u1 } {
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

pub inline fn new(rng: *Fmc256) struct { Board, u2 } {
  const board: Board = .{ .data = 0 };
  const board1, const is_four1 = board.addTile(rng);
  const board2, const is_four2 = board1.addTile(rng);

  return .{ board2, @as(u2, is_four1) + @as(u2, is_four2) };
}

pub inline fn transpose(self: Board) Board {
  var x = self.data;
  var b = (x ^ (x >> 12)) & 0x0000f0f00000f0f0;
  x ^= b ^ (b << 12);
  b = (x ^ (x >> 24)) & 0x00000000ff00ff00;
  x ^= b ^ (b << 24);
  return .{ .data = x };
}

pub inline fn reverse16(x: u16) u16 {
  return (
    (x >> 12) |
    ((x >> 4) & 0x00f0) |
    ((x << 4) & 0x0f00) |
    (x << 12)
  );
}

pub const MoveTable = struct {
  const MAX_ROW = 65536;

  forward_table: [MAX_ROW]u16,
  reverse_table: [MAX_ROW]u16,

  pub fn init(self: *MoveTable) void {
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

      self.forward_table[row] = moved;
      self.reverse_table[reverse16(@intCast(row))] = reverse16(moved);
    }
  }

  pub fn getMoves(self: *const MoveTable, board: Board) [4]Board {
    const data = board.data;
    const transposed = board.transpose().data;

    var result: [4]Board = undefined;

    inline for (0..4) |idx| {
      const shift = comptime (3 - idx) * 16;
      const row: u16 = @truncate(data >> shift);
      const col: u16 = @truncate(transposed >> shift);

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

pub const ValidMoves = struct {
  len: u5,
  moves: [4]Board,
  formation: Formation,
};

pub fn filterMoves(self: Board, moves: *const [4]Board) ValidMoves {
  var result: ValidMoves = .{
    .len = 0,
    .moves = undefined,
    .formation = self.formation(),
  };

  inline for (moves) |move| {
    if (move.data != self.data and result.formation.intact(move)) {
      result.moves[result.len] = move;
      result.len += 1;
    }
  }

  if (result.len > 0) return result;

  inline for (moves) |move| {
    if (move.data != self.data) {
      result.moves[result.len] = move;
      result.len += 1;
    }
  }

  result.formation = .none;
  return result;
}

pub fn maxTile(self: Board) u4 {
  var result: u4 = 0;
  var data = self.data;

  for (0..16) |_| {
    const tile: u4 = @truncate(data);
    result = @max(result, tile);
    data >>= 4;
  }

  return result;
}

pub fn score(self: Board, four_count: u32) u32 {
  var data = self.data;
  var result: u32 = 0;
  for (0..16) |_| {
    const tile: u4 = @truncate(data);
    result += @as(u32, tile -| 1) << tile;
    data >>= 4;
  }
  return result - 4 * four_count;
}

// Lehmer64 PRNG hash function, a very fast but weak hash function that
// comphensate its speed for some extra collisions
pub inline fn hash(self: Board, bits: comptime_int) @Int(.unsigned, bits) {
  // MCG multiplier from: <https://arxiv.org/pdf/2001.05304>
  const h = self.data *% MULT;
  return @intCast(h >> (64 - bits));
}

// Cells holding a tile of at least `rank`, each marked 0xF
// Adapted from `mask()` in 2048EndgameTablebase's WASM core:
// <https://github.com/game-difficulty/2048EndgameTablebase>
pub inline fn atLeast(self: Board, rank: u4) u64 {
  const LANES: u64 = 0x0F0F0F0F0F0F0F0F;
  const GUARD: u64 = 0x8080808080808080;

  const evens = self.data & LANES;
  const odds = (self.data >> 4) & LANES;
  const addend = (0x80 - @as(u64, rank)) *% 0x0101010101010101;

  const even_hit = (evens +% addend) & GUARD;
  const odd_hit = (odds +% addend) & GUARD;

  const even_cells = (even_hit >> 3) -% (even_hit >> 7);
  const odd_cells = (odd_hit >> 3) -% (odd_hit >> 7);

  return even_cells | (odd_cells << 4);
}

pub const Formation = struct {
  cells: u64,
  rank: u4,

  pub const none: Formation = .{ .cells = 0, .rank = 0 };

  pub inline fn intact(self: Formation, board: Board) bool {
    if (self.cells == 0) return true;
    return board.atLeast(self.rank) & self.cells == self.cells;
  }

  pub inline fn salt(self: Formation) u64 {
    return (self.cells *% MULT) ^ self.rank;
  }
};

const FORMATIONS = [_]u64{
  // 2x2 corner block plus one cell extending along the row or down the column
  0x00000000ff00fff0, 0x0fff00ff00000000, 0x0000000f00ff00ff, 0xff00ff00f0000000,
  0xfff0ff0000000000, 0x00ff00ff000f0000, 0x0000f000ff00ff00, 0x0000000000ff0fff,
  // 2x2 corner block
  0xff00ff0000000000, 0x00ff00ff00000000, 0x00000000ff00ff00, 0x0000000000ff00ff,
  // corner L
  0xff00f00000000000, 0x00ff000f00000000, 0x00000000f000ff00, 0x00000000000f00ff,
  // corner plus one neighbour, along the row or down the column
  0xff00000000000000, 0x000f000f00000000, 0x00000000f000f000, 0x00000000000000ff,
  0x000000000000ff00, 0x00ff000000000000, 0x00000000000f000f, 0xf000f00000000000,
};

// Largest corner region whose cells all hold a tile at or above the cutoff
pub fn formation(self: Board) Formation {
  const MIN_RANK = 9;

  var present: u16 = 0;
  var repeated: u16 = 0;
  var data = self.data;

  for (0..16) |_| {
    const tile: u4 = @truncate(data);
    data >>= 4;
    if (tile < MIN_RANK) continue;

    const bit = @as(u16, 1) << tile;
    repeated |= present & bit;
    present |= bit;
  }

  if (present == 0) return .none;

  const cutoff: u4 = @intCast(@min(@as(u32, @ctz(present)) + 1, 15));

  // Two equal tiles at or above the cutoff can still merge
  if (repeated >> cutoff != 0) return .none;

  const big = self.atLeast(cutoff);
  for (FORMATIONS) |cells| {
    if (big & cells == cells) {
      return .{ .cells = cells, .rank = cutoff };
    }
  }

  return .none;
}
