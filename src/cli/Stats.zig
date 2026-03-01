const Stats = @This();

total_games: u32,
total_time: f64,
total_score: u64,
total_moves: u64,
best_game: Board,
best_score: u32,
max_tiles: @Vector(16, u32),

pub const empty: Stats = .{
  .total_games = 0,
  .total_time = 0,
  .total_score = 0,
  .total_moves = 0,
  .best_game = .{ .data = 0 },
  .best_score = 0,
  .max_tiles = @splat(0),
};

pub fn fromResult(result: struct {
  final_board: Board,
  four_count: u32,
  total_time: f64,
  total_moves: u64,
}) Stats {
  const score = result.final_board.score(result.four_count);
  return .{
    .total_games = 1,
    .total_time = result.total_time,
    .total_moves = result.total_moves,
    .total_score = score,
    .best_game = result.final_board,
    .best_score = score,
    .max_tiles = max_tiles: {
      var max_tiles: [16]u32 = @splat(0);
      max_tiles[result.final_board.maxTile()] = 1;
      break :max_tiles max_tiles;
    },
  };
}

pub fn combine(self: Stats, other: Stats) Stats {
  const best_game, const best_score = if (other.best_score > self.best_score) .{
    other.best_game,
    other.best_score,
  } else .{
    self.best_game,
    self.best_score,
  };
  return .{
    .total_games = self.total_games + other.total_games,
    .total_time = self.total_time + other.total_time,
    .total_score = self.total_score + other.total_score,
    .total_moves = self.total_moves + other.total_moves,
    .max_tiles = self.max_tiles + other.max_tiles,
    .best_game = best_game,
    .best_score = best_score,
  };
}

pub fn display(self: Stats, out: anytype, comptime detail: bool) !void {
  if (self.total_games == 0) return;

  const total_games: f64 = @floatFromInt(self.total_games);
  const total_time = self.total_time / 1e9;
  const avg_score = @as(f64, @floatFromInt(self.total_score)) / total_games;
  const speed = @as(f64, @floatFromInt(self.total_moves)) / total_time;

  try out.writeAll("=================== STATISTICS ===================\n");
  try out.print("Games Played : {d}\n", .{self.total_games});
  try out.print("Score        : Max {d} | Avg {d:.2}\n", .{ self.best_score, avg_score });
  try out.print("Performance  : {d:.2} moves/s | {d:.3}s cpu time\n", .{ speed, total_time });
  if (comptime detail) {
    try out.writeAll("\n--- Reaching Rate ---\n");
    
    var accumulated: u32 = 0;

    var i: u4 = 15;
    while (accumulated < self.total_games) : (i -= 1) {
      accumulated += self.max_tiles[i];

      if (accumulated > 0) {
        const tile_val = @as(u32, 1) << @intCast(i);
        const percent = @as(f64, @floatFromInt(accumulated)) * 100.0 / total_games;
        try out.print("{d: <5}: {d:.1}%\n", .{ tile_val, percent });
      }
    }

    try out.writeAll("\n--- Best Final State ---\n");
    try self.best_game.display(out);
  } else {
    var i: u4 = 15;
    while (self.max_tiles[i] == 0) : (i -= 1) {}
    const tile_val = @as(u32, 1) << @intCast(i);
    const percent = @as(f64, @floatFromInt(self.max_tiles[i])) * 100.0 / total_games;
    try out.print("Max tile     : {d: <5} | {d:.1}%\n", .{ tile_val, percent });
  }
  try out.writeAll("==================================================\n");
}

const engine = @import("engine");
const Board = engine.Board;
