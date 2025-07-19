const Cache = struct {
  const CACHE_BITS = 22;
  const CACHE_SIZE = 1 << CACHE_BITS;

  boards: [CACHE_SIZE]u64,
  scores: [CACHE_SIZE]f32,
  depths: [CACHE_SIZE]u8,

  fn init(cache: *Cache) void {
    @memset(&cache.boards, 0);
  }

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

const Heuristic = struct {
  score_table: [65536]i32,

  fn new() Heuristic {
    var table: Heuristic = undefined;
    for (&table.score_table, 0..) |*entry, idx| {
      var row = idx;
      var result: i32 = 0;
      var last = last: {
        const tile: u4 = @truncate(row);
        row >>= 4;
        result += @as(i32, tile) << tile;
        break :last tile;
      };

      inline for (0..3) |_| {
        const tile: u4 = @truncate(row);
        row >>= 4;
        if (tile > 0) {
          if (tile <= last) {
            result += @as(i32, tile) << tile;
          }
          last = tile;
        }
      }

      entry.* = result;
    }

    const S = struct {
      fn reverse(x: u16) u16 {
        return (
          (x >> 12) |
          ((x >> 4) & 0x00f0) |
          ((x << 4) & 0x0f00) |
          (x << 12)
        );
      }
    };

    for (&table.score_table, 0..) |*entry, idx| {
      entry.* = @max(entry.*, table.score_table[S.reverse(@intCast(idx))]);
    }

    return table;
  }

  fn evaluate(self: *const Heuristic, board: Board) i32 {
    var data = board.data;
    var transposed = board.transpose().data;
    var score: i32 = 0;

    for (0..4) |_| {
      const row: u16 = @truncate(data);
      const col: u16 = @truncate(transposed);
      data >>= 16;
      transposed >>= 16;

      score += self.score_table[row] + self.score_table[col];
    }

    return score;
  }
};

const SearchContext = struct {
  move_table: *const Board.MoveTable,
  heuristic: *const Heuristic,
  cache: *Cache,
};

fn expectNode(board: Board, ctx: SearchContext, depth: u8) f32 {
  if (depth == 0) return @floatFromInt(ctx.heuristic.evaluate(board));

  if (ctx.cache.query(board, depth)) |score| {
    return score;
  }

  var mask = board.emptyPos();
  const total: f32 = @floatFromInt(@popCount(mask));

  const weight2 = 0.9 / total;
  const weight4 = 0.1 / total;

  var score: f32 = 0;

  while (mask != 0) {
    const tile = mask & -%mask;
    mask ^= tile;

    score += weight2 * maxNode(.{
      .data = board.data | tile,
    }, ctx, depth);

    score += weight4 * maxNode(.{
      .data = board.data | (tile << 1),
    }, ctx, depth);
  }

  ctx.cache.insert(board, depth, score);
  return score;
}

fn maxNode(board: Board, ctx: SearchContext, depth: u8) f32 {
  const moves = ctx.move_table.getMoves(board);

  var max_score: f32 = 0;
  inline for (moves) |next_board| {
    if (next_board.data != board.data) {
      max_score = @max(max_score, expectNode(next_board, ctx, depth - 1));
    }
  }

  return max_score;
}

fn expectimax(board: Board, ctx: SearchContext, depth: u8) ?u4 {
  const moves = ctx.move_table.getMoves(board);

  var best_score: f32 = 0;
  var best_move: ?u4 = null;

  inline for (moves, 0..) |next_board, dir| {
    if (next_board.data != board.data) {
      const score = expectNode(next_board, ctx, depth - 1);
      if (score > best_score) {
        best_score = score;
        best_move = dir;
      }
    }
  }

  return best_move;
}

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

  const S = struct {
    var cache: Cache = undefined;
  };
  S.cache.init();

  const ctx: SearchContext = .{
    .move_table = &move_table,
    .heuristic = &heuristic,
    .cache = &S.cache,
  };

  var total_time: f64 = 0;
  var total_move: u32 = 0;

  while (true) {
    const moves = move_table.getMoves(board);
    var timer = try std.time.Timer.start();
    const dir = expectimax(board, ctx, 5) orelse break;
    total_time += @as(f64, @floatFromInt(timer.read())) / std.time.ns_per_ms;
    total_move += 1;
    board = moves[dir].addTile(&rng);

    try board.display(&writer);
    try buffer.flush();
  }

  try writer.print("Speed: {d} moves/s\n", .{
    total_move * 1000 / @as(u32, @intFromFloat(total_time)),
  });
  try writer.print("Game over! Max tile: {d}\n", .{
    @as(u16, 1) << board.maxTile(),
  });
  try buffer.flush();
}

const std = @import("std");
const Fmc256 = @import("lib/Fmc256.zig");
const Board = @import("lib/Board.zig");
