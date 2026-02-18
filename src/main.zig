const Worker = struct {
  id: u32,
  rng: Fmc256,
  write_lock: *std.Thread.Mutex,
  move_table: *const Board.MoveTable,
  search: struct {
    expectimax: *Expectimax,
    bfs: Bfs,
  },

  const Shared = struct {
    move_table: *const Board.MoveTable,
    heuristic: *const Heuristic,
    write_lock: *std.Thread.Mutex,
  };

  fn new(id: u32, rng: *Fmc256, shared: Shared, arena: std.mem.Allocator) !Worker {
    rng.jump(.default);

    const expectimax = try arena.create(Expectimax);
    const bfs_buffer = try arena.alloc(Board, 1 << 19);
    expectimax.* = .new(shared.move_table, shared.heuristic);

    return .{
      .id = id,
      .rng = rng.*,
      .write_lock = shared.write_lock,
      .move_table = shared.move_table,
      .search = .{
        .expectimax = expectimax,
        .bfs = .new(bfs_buffer, shared.move_table),
      },
    };
  }

  fn run_games(self: *Worker, iter: u32, out: *Stats) !void {
    var buffer: [4096]u8 = undefined;
    var stdout = std.fs.File.stdout().writer(&buffer);
    const writer = &stdout.interface;

    var stats: Stats = .empty;
    var bfs = self.search.bfs;

    for (0..iter) |_| {
      var board: Board, var four_count: u32 = Board.new(&self.rng);

      var total_time: f64 = 0;
      var total_move: u64 = 0;

      while (true) {
        const moves = self.move_table.getMoves(board);
        const valid = board.filterMoves(&moves);
        var timer = try std.time.Timer.start();
        const depth = bfs.expand(valid.moves[0..valid.len]).depth + 1;
        const dir = self.search.expectimax.search(board, depth) orelse break;
        total_time += @as(f64, @floatFromInt(timer.read()));
        total_move += 1;
        board, const is_four = moves[dir].addTile(&self.rng);
        four_count += is_four;
      }

      stats = stats.combine(.fromResult(.{
        .final_board = board,
        .four_count = four_count,
        .total_time = total_time,
        .total_moves = total_move,
      }));


      try writer.print("Thread #{d} report:\n", .{ self.id });
      try stats.display(writer, false);
      try writer.writeAll("\n");

      self.write_lock.lock();
      defer self.write_lock.unlock();
      try writer.flush();
    }

    out.* = stats;
  }
};

pub fn main() !void {
  var arena: std.heap.ArenaAllocator = .init(std.heap.page_allocator);
  defer arena.deinit();
  const allocator = arena.allocator();

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

  const total_games: u32 = 100;

  const thread_count: u32 = @intCast(try std.Thread.getCpuCount());
  const bg_threads = thread_count - 1;

  var result: Stats = .empty;

  var write_lock: std.Thread.Mutex = .{};
  const shared: Worker.Shared = .{
    .move_table = &move_table,
    .heuristic = &heuristic,
    .write_lock = &write_lock,
  };

  if (bg_threads > 0) {
    const stats = try allocator.alloc(Stats, bg_threads);
    @memset(stats, .empty);

    _ = {
      const workers = try allocator.alloc(Worker, bg_threads);

      for (workers, 1..) |*worker, id| {
        worker.* = try .new(@intCast(id), &rng, shared, allocator);
      }

      const work_per_thread = total_games / thread_count;
      const remaining = total_games % thread_count;

      const threads = try allocator.alloc(std.Thread, bg_threads);
      for (threads, workers, stats) |*thread, *worker, *stat| {
        thread.* = try std.Thread.spawn(.{}, Worker.run_games, .{
          worker,
          if (worker.id < remaining) work_per_thread + 1 else work_per_thread,
          stat,
        });
      }

      var worker: Worker = try .new(0, &rng, shared, allocator);
      try worker.run_games(if (remaining > 0) work_per_thread + 1 else work_per_thread, &result);

      for (threads) |*thread| thread.join();
    };

    var longest_time = result.total_time;
    for (stats) |stat| {
      result = result.combine(stat);
      longest_time = @max(longest_time, stat.total_time);
    }

    const wall_time = longest_time / 1e9;
    const wall_speed = @as(f64, @floatFromInt(result.total_moves)) / wall_time;

    try result.display(writer, true);
    try writer.print("Wall Speed: {d:.2} moves/s\n", .{ wall_speed });
    try writer.flush();
  } else {
    var worker: Worker = try .new(0, &rng, shared, allocator);
    try worker.run_games(total_games, &result);

    try result.display(writer, true);
    try writer.flush();
  }
}

const std = @import("std");
const Fmc256 = @import("lib/Fmc256.zig");
const Board = @import("lib/Board.zig");
const Heuristic = @import("lib/Heuristic.zig");
const Bfs = @import("lib/Bfs.zig");
const Expectimax = @import("lib/Expectimax.zig");
const Stats = @import("lib/Stats.zig");
