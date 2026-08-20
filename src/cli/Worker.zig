const Worker = @This();

const Expectimax = engine.Expectimax(*const Heuristic, 18);

id: u32,
rng: Fmc256,
write_lock: *std.Io.Mutex,
next_game: *std.atomic.Value(u32),
total_games: u32,
io: std.Io,
move_table: *const Board.MoveTable,
expectimax: Expectimax,
bfs: Bfs,

pub const Shared = struct {
  args: Args,
  move_table: *const Board.MoveTable,
  heuristic: *const Heuristic,
  write_lock: *std.Io.Mutex,
  next_game: *std.atomic.Value(u32),
  arena: std.mem.Allocator,
  io: std.Io,
};

pub fn new(id: u32, shared: *const Shared) !Worker {
  const bfs_buffer = try shared.arena.alloc(Board, shared.args.budget);
  const cache = try shared.arena.create(Expectimax.Cache);

  return .{
    .id = id,
    .rng = shared.args.seed.toRng(),
    .write_lock = shared.write_lock,
    .next_game = shared.next_game,
    .total_games = shared.args.iterations,
    .io = shared.io,
    .move_table = shared.move_table,
    .expectimax = .{
      .move_table = shared.move_table,
      .heuristic = shared.heuristic,
      .cache = cache,
    },
    .bfs = .new(bfs_buffer, shared.move_table),
  };
}

pub fn run_games(self: *Worker, out: *Stats) !void {
  var buffer: [4096]u8 = undefined;
  var stdout: std.Io.File.Writer = .init(.stdout(), self.io, &buffer);
  const writer = &stdout.interface;

  var stats: Stats = .empty;
  var bfs = self.bfs;

  var jumped: u32 = 0;

  while (true) {
    const idx = self.next_game.fetchAdd(1, .monotonic);
    if (idx >= self.total_games) break;
    while (jumped < idx) {
      self.rng.jump(.default);
      jumped += 1;
    }

    var game: Game = .new(self.rng, self.move_table);

    var total_time: f64 = 0;
    var total_move: u64 = 0;

    self.expectimax.clear();

    while (true) {
      const board = game.getBoard();
      const moves = self.move_table.getMoves(board);
      const valid = board.filterMoves(&moves);

      const start_time = std.Io.Timestamp.now(self.io, .awake);

      const depth = bfs.expand(valid.moves[0..valid.len]).depth +| 1;
      const dir = self.expectimax.call(&valid, depth) orelse break;
      const done_time = std.Io.Timestamp.now(self.io, .awake);
      const duration = start_time.durationTo(done_time);

      game.executeMove(dir);
      total_time += @as(f64, @floatFromInt(duration.toNanoseconds()));
      total_move += 1;
    }

    stats = stats.combine(&.fromResult(.{
      .final_state = game.state,
      .total_time = total_time,
      .total_moves = total_move,
    }));

    try writer.print("Thread #{d} report:\n", .{ self.id });
    try stats.display(writer, false);
    try writer.writeAll("\n");

    try self.write_lock.lock(self.io);
    defer self.write_lock.unlock(self.io);
    try writer.flush();
  }

  out.* = stats;
}

const std = @import("std");
const engine = @import("engine");
const Fmc256 = engine.Fmc256;
const Board = engine.Board;
const Game = engine.Game;
const Heuristic = engine.Heuristic;
const Bfs = engine.Bfs;

const Stats = @import("Stats.zig");
const Args = @import("Args.zig");
