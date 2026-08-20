const Stats = @This();

total_games: u32,
total_time: f64,
total_score: u64,
total_moves: u64,
best_game: Game.State,
max_tiles: @Vector(16, u32),

pub const empty: Stats = .{
  .total_games = 0,
  .total_time = 0,
  .total_score = 0,
  .total_moves = 0,
  .best_game = .empty,
  .max_tiles = @splat(0),
};

pub fn fromResult(result: struct {
  final_state: Game.State,
  total_time: f64,
  total_moves: u64,
}) Stats {
  return .{
    .total_games = 1,
    .total_time = result.total_time,
    .total_moves = result.total_moves,
    .total_score = result.final_state.score(),
    .best_game = result.final_state,
    .max_tiles = max_tiles: {
      var max_tiles: [16]u32 = @splat(0);
      max_tiles[result.final_state.maxTile()] = 1;
      break :max_tiles max_tiles;
    },
  };
}

pub fn combine(self: *const Stats, other: *const Stats) Stats {
  const best_game = if (other.best_game.score() > self.best_game.score())
    other.best_game
  else
    self.best_game;

  return .{
    .total_games = self.total_games + other.total_games,
    .total_time = self.total_time + other.total_time,
    .total_score = self.total_score + other.total_score,
    .total_moves = self.total_moves + other.total_moves,
    .max_tiles = self.max_tiles + other.max_tiles,
    .best_game = best_game,
  };
}

pub fn display(self: *const Stats, out: anytype, comptime detail: bool) !void {
  if (self.total_games == 0) return;

  const total_games: f64 = @floatFromInt(self.total_games);
  const total_time = self.total_time / 1e9;
  const avg_score = @as(f64, @floatFromInt(self.total_score)) / total_games;
  const speed = @as(f64, @floatFromInt(self.total_moves)) / total_time;

  try out.writeAll("=================== STATISTICS ===================\n");
  try out.print("Games Played : {d}\n", .{self.total_games});
  try out.print("Score        : Max {d} | Avg {d:.2}\n", .{ self.best_game.score(), avg_score });
  try out.print("Performance  : {d:.2} moves/s | {d:.3}s cpu time\n", .{ speed, total_time });
  const max_tiles: [16]u32 = self.max_tiles;
  if (comptime detail) {
    try out.writeAll("\n--- Reaching Rate ---\n");
    
    var accumulated: u32 = 0;

    var i: u4 = 15;
    while (accumulated < self.total_games) : (i -= 1) {
      accumulated += max_tiles[i];

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
    while (max_tiles[i] == 0) : (i -= 1) {}
    const tile_val = @as(u32, 1) << @intCast(i);
    const percent = @as(f64, @floatFromInt(max_tiles[i])) * 100.0 / total_games;
    try out.print("Max tile     : {d: <5} | {d:.1}%\n", .{ tile_val, percent });
  }
  try out.writeAll("==================================================\n");
}

const engine = @import("engine");
const Game = engine.Game;
