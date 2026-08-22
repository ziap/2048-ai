const BoardExt = @This();

pub const Moves = EnumMap(Board.Dir, BoardExt);

inline fn reverse20(x: u20) u20 {
  return (
    ((x >> 12) & 0x000f) |
    ((x >>  4) & 0x00f0) |
    ((x <<  4) & 0x0f00) |
    ((x << 12) & 0xf000) |

    ((x >> 3) & 0x10000) |
    ((x >> 1) & 0x20000) |
    ((x << 1) & 0x40000) |
    ((x << 3) & 0x80000)
  );
}

pub const MoveTable = struct {
  const MAX_ROW = 1 << 20;

  const Entry = struct {
    row: u16,
    ext: u4,
  };

  table16: Board.MoveTable,
  forward_table: [MAX_ROW]Entry,
  reverse_table: [MAX_ROW]Entry,

  fn packLine(line: *const [4]u5) Entry {
    var row: u16 = 0;
    var ext: u4 = 0;
    inline for (line, 0..) |cell, idx| {
      if (cell < 16) {
        row |= @as(u16, cell) << @intCast(idx * 4);
      } else {
        row |= 0xf << @intCast(idx * 4);
        ext |= 1 << idx;
      }
    }
    return .{ .row = row, .ext = ext };
  }

  pub fn init(self: *MoveTable) void {
    self.table16.init();

    for (0..MAX_ROW) |row| {
      var line = [_]u5 {
        if ((row >> 16) & 1 == 0) @as(u4, @truncate(row >> 0)) else 16,
        if ((row >> 17) & 1 == 0) @as(u4, @truncate(row >> 4)) else 16,
        if ((row >> 18) & 1 == 0) @as(u4, @truncate(row >> 8)) else 16,
        if ((row >> 19) & 1 == 0) @as(u4, @truncate(row >> 12)) else 16,
      };

      Board.moveLine(u5, &line);
      const reversed = [_]u5 { line[3], line[2], line[1], line[0] };

      self.forward_table[row] = packLine(&line);
      self.reverse_table[reverse20(@intCast(row))] = packLine(&reversed);
    }
  }

  pub fn getMoves(self: *const MoveTable, board: BoardExt) Moves {
    const data = board.clamped.data;
    const ext = board.ext;

    // No 65536, check if the smaller move table is usable
    if (ext == 0) {
      // Invert so 32768 becomes empty tile
      const inverted: Board = .{ .data = ~data };

      // Also no 32768 pair, the small table is safe
      if (@popCount(inverted.emptyPos()) <= 1) {
        const moves16 = self.table16.getMoves(board.clamped);
        var result: Moves = undefined;
        for (&result.values, &moves16.values) |*out, clamped| {
          out.* = .{ .clamped = clamped, .ext = 0 };
        }
        return result;
      }
    }

    const transposed = board.transpose();
    const data_transposed = transposed.clamped.data;
    const ext_transposed = transposed.ext;

    var result: Moves = undefined;

    inline for (0..4) |idx| {
      const shift_data = comptime (3 - idx) * 16;
      const shift_ext = comptime (3 - idx) * 4;

      const row_data: u16 = @truncate(data >> shift_data);
      const col_data: u16 = @truncate(data_transposed >> shift_data);

      const row_ext: u4 = @truncate(ext >> shift_ext);
      const col_ext: u4 = @truncate(ext_transposed >> shift_ext);

      const row = (@as(u20, row_ext) << 16) | row_data;
      const col = (@as(u20, col_ext) << 16) | col_data;

      inline for (&result.values) |*out| {
        out.clamped.data <<= 16;
        out.ext <<= 4;
      }

      result.getMut(.up).clamped.data    |= self.forward_table[col].row;
      result.getMut(.down).clamped.data  |= self.reverse_table[col].row;
      result.getMut(.left).clamped.data  |= self.forward_table[row].row;
      result.getMut(.right).clamped.data |= self.reverse_table[row].row;

      result.getMut(.up).ext    |= self.forward_table[col].ext;
      result.getMut(.down).ext  |= self.reverse_table[col].ext;
      result.getMut(.left).ext  |= self.forward_table[row].ext;
      result.getMut(.right).ext |= self.reverse_table[row].ext;
    }

    result.getMut(.up).* = result.get(.up).transpose();
    result.getMut(.down).* = result.get(.down).transpose();

    return result;
  }
};

clamped: Board,
ext: u16,

fn transpose(self: BoardExt) BoardExt {
  var x = self.ext;
  var b = (x ^ (x >> 3)) & 0x0a0a;
  x ^= b ^ (b << 3);
  b = (x ^ (x >> 6)) & 0x00cc;
  x ^= b ^ (b << 6);

  return .{
    .clamped = self.clamped.transpose(),
    .ext = x,
  };
}

inline fn different(a: BoardExt, b: BoardExt) bool {
  return a.clamped.data != b.clamped.data or a.ext != b.ext;
}

pub fn filterAndClampMoves(self: BoardExt, moves: *const Moves) Board.ValidMoves {
  var result: Board.ValidMoves = .{
    .len = 0,
    .moves = undefined,
    .dirs = undefined,
  };

  const formation: Formation = .get(self.clamped);

  inline for (Moves.keys, moves.values) |dir, move| {
    if (different(self, move) and formation.intact(move.clamped)) {
      result.moves[result.len] = move.clamped;
      result.dirs[result.len] = dir;
      result.len += 1;
    }
  }

  if (result.len > 0) return result;

  inline for (Moves.keys, moves.values) |dir, move| {
    if (different(self, move)) {
      result.moves[result.len] = move.clamped;
      result.dirs[result.len] = dir;
      result.len += 1;
    }
  }

  return result;
}

const Board = @import("Board.zig");
const Formation = @import("Formation.zig");
const EnumMap = @import("utils").EnumMap;
