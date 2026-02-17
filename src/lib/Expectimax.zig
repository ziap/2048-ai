const Expectimax = @This();

const Cache = struct {
  const CACHE_BITS = 17;
  const CACHE_SIZE = 1 << CACHE_BITS;

  depths: [CACHE_SIZE]u8,
  boards: [CACHE_SIZE]u64,
  scores: [CACHE_SIZE]f32,

  fn insert(self: *Cache, board: Board, depth: u8, score: f32) void {
    const h = board.hash(CACHE_BITS);

    self.boards[h] = board.data;
    self.depths[h] = depth;
    self.scores[h] = score;
  }

  fn query(self: *Cache, board: Board, depth: u8) ?f32 {
    const h = board.hash(CACHE_BITS);
    if (self.boards[h] != board.data or self.depths[h] < depth) return null;
    return self.scores[h];
  }
};

move_table: *const Board.MoveTable,
heuristic: *const Heuristic,
cache: Cache,

pub fn new(move_table: *const Board.MoveTable, heuristic: *const Heuristic) Expectimax {
  return .{
    .move_table = move_table,
    .heuristic = heuristic,
    .cache = .{
      .boards = @splat(0),
      .depths = undefined,
      .scores = undefined,
    },
  };
}

pub fn expectNode(self: *Expectimax, board: Board, depth: u8) f32 {
  if (depth == 0) {
    return self.heuristic.evaluate(board);
  }

  if (self.cache.query(board, depth)) |score| {
    return score;
  }

  var mask = board.emptyPos();
  const total: f32 = @floatFromInt(@popCount(mask));
  var score: f32 = 0;

  const w2 = 0.9 / total;
  const w4 = 0.1 / total;

  while (mask != 0) {
    const tile = mask & -%mask;
    mask ^= tile;

    score += w2 * self.maxNode(.{ .data = board.data | tile, }, depth);
    score += w4 * self.maxNode(.{ .data = board.data | (tile << 1), }, depth);
  }

  self.cache.insert(board, depth, score);
  return score;
}

fn maxNode(self: *Expectimax, board: Board , depth: u8) f32 {
  const moves = self.move_table.getMoves(board);

  var max_score: f32 = 0;
  inline for (moves) |next_board| {
    if (next_board.data != board.data) {
      max_score = @max(max_score, self.expectNode(next_board, depth - 1));
    }
  }

  return max_score;
}

pub fn search(self: *Expectimax, board: Board, depth: u8) ?u4 {
  var best_move: ?u4 = null;
  var best_score: f32 = 0;

  inline for (self.move_table.getMoves(board), 0..) |next_board, dir| {
    if (next_board.data != board.data) {
      const score = self.expectNode(next_board, depth);
      if (score > best_score) {
        best_score = score;
        best_move = dir;
      }
    }
  }

  return best_move;
}

const Board = @import("Board.zig");
const Heuristic = @import("Heuristic.zig");
