const MemoSearch = struct {
  const Cache = struct {
    const CACHE_BITS = 22;
    const CACHE_SIZE = 1 << CACHE_BITS;

    boards: [CACHE_SIZE]u64,
    scores: [CACHE_SIZE]f32,
    depths: [CACHE_SIZE]u8,
    inserts: u32,

    fn new() Cache {
      return .{
        .boards = undefined,
        .scores = undefined,
        .depths = @splat(0),
        .inserts = 0,
      };
    }

    fn insert(self: *Cache, board: Board, depth: u8, score: f32) void {
      const h = board.hash(CACHE_BITS);

      self.boards[h] = board.data;
      self.depths[h] = depth;
      self.scores[h] = score;
      self.inserts += 1;
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

  fn new(move_table: *const Board.MoveTable, heuristic: *const Heuristic) MemoSearch {
    return .{
      .move_table = move_table,
      .heuristic = heuristic,
      .cache = .new(),
    };
  }

  fn expectNode(self: *MemoSearch, board: Board, depth: u8) f32 {
    if (depth == 0) return @floatFromInt(self.heuristic.evaluate(board));

    if (self.cache.query(board, depth)) |score| {
      return score;
    }

    var mask = board.emptyPos();
    const total: f32 = @floatFromInt(@popCount(mask));
    var score: f32 = 0;

    const w2 = 0.1 / total;
    const w4 = 0.9 / total;

    while (mask != 0) {
      const tile = mask & -%mask;
      mask ^= tile;

      score += w2 * self.maxNode(.{ .data = board.data | tile, }, depth);
      score += w4 * self.maxNode(.{ .data = board.data | (tile << 1), }, depth);
    }

    self.cache.insert(board, depth, score);
    return score;
  }

  fn maxNode(self: *MemoSearch, board: Board , depth: u8) f32 {
    const moves = self.move_table.getMoves(board);

    var max_score: f32 = 0;
    inline for (moves) |next_board| {
      if (next_board.data != board.data) {
        max_score = @max(max_score, self.expectNode(next_board, depth - 1));
      }
    }

    return max_score;
  }

  fn searchDepth(board: Board) struct { u8, u32 } {
    const depth_lut: [17]u8 = .{
      3, 3, 3, 3,
      4, 4, 4, 4, 4,
      5, 5, 5,
      6, 6, 6, 6, 6
    };

    var hist: u16 = 0;
    var data = board.data;
    inline for (0..16) |_| {
      const tile: u4 = @truncate(data);
      hist |= @as(u16, 1) << tile;
      data >>= 4;
    }

    const count = @popCount(hist);
    
    return .{
      depth_lut[count], @as(u32, 64) << count,
    };
  }

  fn search(self: *MemoSearch, board: Board) ?u4 {
    const moves = self.move_table.getMoves(board);

    var best_score: f32 = 0;
    var best_move: ?u4 = null;

    var depth, const total_nodes = searchDepth(board);

    var last: u32 = 0;
    while (last < total_nodes) : (depth += 1) {
      self.cache.inserts = 0;
      inline for (moves, 0..) |next_board, dir| {
        if (next_board.data != board.data) {
          const score = self.expectNode(next_board, depth);
          if (score > best_score) {
            best_score = score;
            best_move = dir;
          }
        }
      }

      if (self.cache.inserts > last) {
        last = self.cache.inserts;
      } else {
        break;
      }
    }

    return best_move;
  }
};

const TableSearch = struct {

};

pub fn main() !void {
  var buffer = std.io.bufferedWriter(std.io.getStdOut().writer());
  var writer = buffer.writer();

  // var rng: Fmc256 = .fromSeed(&.{ 0, 0, 0, 42 });
  var rng: Fmc256 = rng: {
    var seed: [4]u64 = undefined;
    try std.posix.getrandom(@ptrCast(&seed));
    break :rng .fromSeed(&seed);
  };

  const move_table: Board.MoveTable = .new();
  const heuristic: Heuristic = .new();

  var board: Board = .new(&rng);
  try board.display(&writer);
  try buffer.flush();

  const ctx = ctx: {
    const S = struct {
      var searcher: MemoSearch = undefined;
    };

    S.searcher = .new(&move_table, &heuristic);
    break :ctx &S.searcher;
  };

  var total_time: f64 = 0;
  var total_move: u64 = 0;

  while (true) {
    const moves = move_table.getMoves(board);
    var timer = try std.time.Timer.start();
    const dir = ctx.search(board) orelse break;
    total_time += @as(f64, @floatFromInt(timer.read()));
    total_move += 1;
    board = moves[dir].addTile(&rng);

    try board.display(&writer);
    try buffer.flush();
  }

  try writer.print("Speed: {d} moves/s\n", .{
    total_move * std.time.ns_per_s / @as(u64, @intFromFloat(total_time)),
  });
  try writer.print("Game over! Max tile: {d}\n", .{
    @as(u16, 1) << board.maxTile(),
  });
  try buffer.flush();
}

const std = @import("std");
const Fmc256 = @import("lib/Fmc256.zig");
const Board = @import("lib/Board.zig");
const Heuristic = @import("lib/Heuristic.zig");
const common = @import("lib/common.zig");
