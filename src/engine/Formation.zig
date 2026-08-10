const Formation = @This();
// The cutoff comparison and the cells it applies to, both kept in the byte
// lanes `atLeast` works in. Storing the mask as the 0x80 flag the comparison
// already produces skips expanding it back to 0xF nibbles, and folding the
// cutoff into `addend` keeps a multiply off a path walked at every node.
even: u64,
odd: u64,
addend: u64,

pub const none: Formation = .{ .even = 0, .odd = 0, .addend = 0 };

// Cells holding a tile of at least `rank`, each marked 0xF
// Adapted from `mask()` in 2048EndgameTablebase's WASM core:
// <https://github.com/game-difficulty/2048EndgameTablebase>
const LANES: u64 = 0x0F0F0F0F0F0F0F0F;

inline fn atLeast(board: Board, rank: u4) u64 {
  const GUARD: u64 = 0x8080808080808080;

  const evens = board.data & LANES;
  const odds = (board.data >> 4) & LANES;
  const addend = (0x80 - @as(u64, rank)) *% 0x0101010101010101;

  const even_hit = (evens +% addend) & GUARD;
  const odd_hit = (odds +% addend) & GUARD;

  const even_cells = (even_hit >> 3) -% (even_hit >> 7);
  const odd_cells = (odd_hit >> 3) -% (odd_hit >> 7);

  return even_cells | (odd_cells << 4);
}

pub inline fn intact(self: Formation, board: Board) bool {
  if (self.even | self.odd == 0) return true;

  const evens = board.data & LANES;
  const odds = (board.data >> 4) & LANES;

  return (evens +% self.addend) & self.even == self.even and
    (odds +% self.addend) & self.odd == self.odd;
}

pub inline fn eql(self: Formation, other: Formation) bool {
  return self.even == other.even and self.odd == other.odd and
    self.addend == other.addend;
}

// Cells are 0xF per selected nibble; bit 0 of each byte lane says whether
// that lane's even nibble is selected, and bit 4 says the same for its odd
// nibble. Shifting either into bit 7 lines them up with the comparison.
fn init(cells: u64, cutoff: u4) Formation {
  const ONES: u64 = 0x0101010101010101;
  return .{
    .even = (cells & ONES) << 7,
    .odd = ((cells >> 4) & ONES) << 7,
    .addend = (0x80 - @as(u64, cutoff)) *% ONES,
  };
}

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

inline fn maskedValue(board: Board, cells: u64) u64 {
  var masked = board.data & cells;
  var total: u64 = 0;

  for (0..16) |_| {
    const tile: u4 = @truncate(masked);
    masked >>= 4;
    total += @as(u64, @intFromBool(tile != 0)) << tile;
  }

  return total;
}

// Largest corner region whose cells all hold a tile at or above the cutoff
pub fn get(board: Board) Formation {
  const MIN_RANK = 9;

  var present: u16 = 0;
  var repeated: u16 = 0;
  var data = board.data;

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

  const big = atLeast(board, cutoff);

  var best: Formation = .none;
  var best_value: u64 = 0;

  for (FORMATIONS) |cells| {
    if (big & cells != cells) continue;

    const value = maskedValue(board, cells);
    if (value <= best_value) continue;

    best_value = value;
    best = .init(cells, cutoff);
  }

  return best;
}

const Board = @import("Board.zig");
