const Expectimax = struct {
  const Cache = struct {
    const CACHE_BITS = 24;
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

  fn new(move_table: *const Board.MoveTable, heuristic: *const Heuristic) Expectimax {
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

  fn expectNode(self: *Expectimax, board: Board, depth: u8) f32 {
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

  fn searchDepth(board: Board) u8 {
    var hist: u16 = 0;
    var data = board.data;
    inline for (0..16) |_| {
      const tile: u4 = @truncate(data);
      hist |= @as(u16, 1) << tile;
      data >>= 4;
    }

    const count = @popCount(hist);

    return switch (count) {
      0...5 => 3,
      6...9 => 4,
      10...11 => 5,
      12 => 6,
      13 => 8,
      else => 10,
    };
  }

  fn search(self: *Expectimax, board: Board) ?u4 {
    const moves = self.move_table.getMoves(board);
    const depth = searchDepth(board);

    var best_move: ?u4 = null;
    var best_score: f32 = 0;

    inline for (moves, 0..) |next_board, dir| {
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
};

var ctx: Expectimax = undefined;

pub fn main() !void {
  var buffer: [4096]u8 = undefined;
  var stdout = std.fs.File.stdout().writer(&buffer);
  const writer = &stdout.interface;

  // var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
  // defer arena.deinit();
  // const allocator = arena.allocator();

  // var rng: Fmc256 = .fromSeed(&.{ 0, 0, 0, 42 });
  var rng: Fmc256 = rng: {
    var seed: [4]u64 = undefined;
    try std.posix.getrandom(@ptrCast(&seed));
    break :rng .fromSeed(&seed);
  };

  const move_table: Board.MoveTable = .new();
  const heuristic: Heuristic = .new();

  var board: Board, var four_count: u32 = Board.new(&rng);
  try board.display(writer);
  try writer.flush();

  four_count += 1;

  ctx = .new(&move_table, &heuristic);

  var total_time: f64 = 0;
  var total_move: u64 = 0;

  while (true) {
    const moves = move_table.getMoves(board);
    var timer = try std.time.Timer.start();
    const dir = ctx.search(board) orelse break;
    total_time += @as(f64, @floatFromInt(timer.read()));
    total_move += 1;
    board, const is_four = moves[dir].addTile(&rng);
    four_count += is_four;

    try board.display(writer);
    try writer.flush();
  }

  try writer.print("Speed: {d} moves/s\n", .{
    total_move * std.time.ns_per_s / @as(u64, @intFromFloat(total_time)),
  });
  try writer.print("Game over! Max tile: {d} - Score: {d}\n", .{
    @as(u16, 1) << board.maxTile(),
    board.score(four_count),
  });
  try writer.flush();
}

const std = @import("std");
const Fmc256 = @import("lib/Fmc256.zig");
const Board = @import("lib/Board.zig");
const Heuristic = @import("lib/Heuristic.zig");
const common = @import("lib/common.zig");
