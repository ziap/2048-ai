const BoardExt = @This();

const MoveTable = struct {
  // TODO: implement
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

const Board = @import("Board.zig");
