pub fn main() !void {
  var arena: std.heap.ArenaAllocator = .init(std.heap.page_allocator);
  defer arena.deinit();
  const allocator = arena.allocator();

  const args = Args.parse(allocator) catch return;
  if (args.iterations == 0) return;

  var buffer: [4096]u8 = undefined;
  var stdout = std.fs.File.stdout().writer(&buffer);
  const writer = &stdout.interface;

  try args.display(writer);
  var rng = args.seed.toRng();

  const move_table: Board.MoveTable = .new();
  const heuristic: Heuristic = .new();

  const bg_threads = args.threads - 1;

  var result: Stats = .empty;

  var write_lock: std.Thread.Mutex = .{};
  const shared: Worker.Shared = .{
    .move_table = &move_table,
    .heuristic = &heuristic,
    .write_lock = &write_lock,
    .budget = args.budget,
  };

  if (bg_threads > 0) {
    const stats = try allocator.alloc(Stats, bg_threads);
    @memset(stats, .empty);

    _ = {
      const workers = try allocator.alloc(Worker, bg_threads);

      for (workers, 1..) |*worker, id| {
        worker.* = try .new(@intCast(id), &rng, shared, allocator);
      }

      const work_per_thread = args.iterations / args.threads;
      const remaining = args.iterations % args.threads;

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
    try worker.run_games(args.iterations, &result);

    try result.display(writer, true);
    try writer.flush();
  }
}

const std = @import("std");
const Board = @import("lib/Board.zig");
const Heuristic = @import("lib/Heuristic.zig");

const Args = @import("cli/Args.zig");
const Worker = @import("cli/Worker.zig");
const Stats = @import("cli/Stats.zig");
