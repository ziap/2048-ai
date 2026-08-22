const Board = @This();

pub const Dir = enum {
  up,
  right,
  down,
  left,
};

pub const Moves = EnumMap(Dir, Board);

data: u64,

pub inline fn emptyPos(self: Board) u64 {
  var b = self.data;
  b |= (b >> 2) & 0x3333333333333333;
  b |= (b >> 1);
  return ~b & 0x1111111111111111;
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

pub fn moveLine(T: type, line: *[4]T) void {
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
}

pub const MoveTable = struct {
  const MAX_ROW = 1 << 16;

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

      moveLine(u4, &line);

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

  pub fn getMoves(self: *const MoveTable, board: Board) Moves {
    const data = board.data;
    const data_transposed = board.transpose().data;

    var result: Moves = undefined;

    inline for (0..4) |idx| {
      const shift = comptime (3 - idx) * 16;
      const row: u16 = @truncate(data >> shift);
      const col: u16 = @truncate(data_transposed >> shift);

      inline for (&result.values) |*value| {
        value.data <<= 16;
      }

      result.getMut(.up).data    |= self.forward_table[col];
      result.getMut(.down).data  |= self.reverse_table[col];
      result.getMut(.left).data  |= self.forward_table[row];
      result.getMut(.right).data |= self.reverse_table[row];
    }

    result.getMut(.up).* = result.get(.up).transpose();
    result.getMut(.down).* = result.get(.down).transpose();

    return result;
  }
};

pub const ValidMoves = struct {
  len: u5,
  moves: [Moves.len]Board,
  dirs: [Moves.len]Dir,
};

pub fn filterMoves(self: Board, moves: *const Moves) ValidMoves {
  var result: ValidMoves = .{ .len = 0, .moves = undefined, .dirs = undefined };
  const formation: Formation = .get(self);

  inline for (Moves.keys, moves.values) |dir, move| {
    if (move.data != self.data and formation.intact(move)) {
      result.moves[result.len] = move;
      result.dirs[result.len] = dir;
      result.len += 1;
    }
  }

  if (result.len > 0) return result;

  inline for (Moves.keys, moves.values) |dir, move| {
    if (move.data != self.data) {
      result.moves[result.len] = move;
      result.dirs[result.len] = dir;
      result.len += 1;
    }
  }

  return result;
}

// Lehmer64 PRNG hash function, a very fast but weak hash function that
// comphensate its speed for some extra collisions
pub inline fn hash(self: Board, bits: comptime_int) @Int(.unsigned, bits) {
  // MCG multiplier from: <https://arxiv.org/pdf/2001.05304>
  const h = self.data *% 0xf1357aea2e62a9c5;
  return @intCast(h >> (64 - bits));
}

const Formation = @import("Formation.zig");
const EnumMap = @import("utils").EnumMap;
