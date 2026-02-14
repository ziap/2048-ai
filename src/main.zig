const Expectimax = struct {
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

  fn searchDepth(self: *const Expectimax, board: Board, buffers: [2][]Board) u8 {
    var current = buffers[0];
    var next = buffers[1];

    var current_len: u32 = 0;

    inline for (self.move_table.getMoves(board)) |next_board| {
      if (next_board.data != board.data) {
        current[current_len] = next_board;
        current_len += 1;
      }
    }

    var depth: u8 = 0;
    while (current_len > 0) {
      std.mem.sort(Board, current[0..current_len], {}, Board.lessThan);

      var next_len: u32 = 0;
      var last: u64 = 0;
      for (current[0..current_len]) |next_board| {
        if (last == next_board.data) continue;
        last = next_board.data;

        var mask = next_board.emptyPos();
        while (mask != 0) {
          const tile = mask & -%mask;
          mask ^= tile;

          const next2: Board = .{ .data = last | tile };
          const next4: Board = .{ .data = last | (tile << 1) };

          for ([_]Board{ next2, next4 }) |spawned| {
            for (self.move_table.getMoves(spawned)) |moved| {
              if (moved.data == spawned.data) continue;
              if (next_len == next.len) return depth;

              next[next_len] = moved;
              next_len += 1;
            }
          }
        }
      }

      const tmp = current;
      current = next;
      current_len = next_len;

      next = tmp;
      depth += 1;
    }

    return depth;
  }

  fn search(self: *Expectimax, board: Board, depth: u8) ?u4 {
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
};

var ctx: Expectimax = undefined;

pub fn main() !void {
  var buffer: [4096]u8 = undefined;
  var stdout = std.fs.File.stdout().writer(&buffer);
  const writer = &stdout.interface;

  var rng: Fmc256 = rng: {
    var seed: [4]u64 = undefined;
    try std.posix.getrandom(@ptrCast(&seed));
    break :rng .fromSeed(seed);
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

  var buffers: [2][200_000]Board = undefined;

  while (true) {
    const moves = move_table.getMoves(board);
    var timer = try std.time.Timer.start();
    const depth = ctx.searchDepth(board, .{ &buffers[0], &buffers[1] }) + 1;
    const dir = ctx.search(board, depth) orelse break;
    total_time += @as(f64, @floatFromInt(timer.read()));
    total_move += 1;
    board, const is_four = moves[dir].addTile(&rng);
    four_count += is_four;

    try board.display(writer);
    try writer.print("Search depth: {}\n", .{ depth });
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
