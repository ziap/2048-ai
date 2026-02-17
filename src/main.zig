const RunOpts = struct {
  rng: *Fmc256,
  writer: *std.Io.Writer,
  move_table: *const Board.MoveTable,
  search: struct {
    expectimax: *Expectimax,
    bfs: Bfs,
  },
  out: *?Stats,
  id: u32,
  iter: u32,
};

fn run_games(opt: RunOpts) !void {
  var stats: Stats = .empty;
  var bfs = opt.search.bfs;

  for (0..opt.iter) |_| {
    var board: Board, var four_count: u32 = Board.new(opt.rng);

    var total_time: f64 = 0;
    var total_move: u64 = 0;

    while (true) {
      const moves = opt.move_table.getMoves(board);
      const valid = board.filterMoves(&moves);
      var timer = try std.time.Timer.start();
      const depth = bfs.expand(valid.moves[0..valid.len]).depth + 1;
      const dir = opt.search.expectimax.search(board, depth) orelse break;
      total_time += @as(f64, @floatFromInt(timer.read()));
      total_move += 1;
      board, const is_four = moves[dir].addTile(opt.rng);
      four_count += is_four;
    }

    stats = stats.combine(.fromResult(.{
      .final_board = board,
      .four_count = four_count,
      .total_time = total_time,
      .total_moves = total_move,
    }));
    try opt.writer.print("Thread #{d} report:\n", .{ opt.id });
    try stats.display(opt.writer, false);
    try opt.writer.writeAll("\n");
    try opt.writer.flush();
  }

  opt.out.* = stats;
}

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

  const expectimax, const bfs: Bfs = search: {
    const S = struct {
      var expectimax: Expectimax = undefined;
      var bfs_buffer: [400_000]Board = undefined;
    };

    S.expectimax = .new(&move_table, &heuristic);

    break :search .{
      &S.expectimax,
      .new(&S.bfs_buffer, &move_table),
    };
  };

  var stats: ?Stats = null;

  {
    var thread = try std.Thread.spawn(.{}, run_games, .{
      RunOpts {
        .rng = &rng,
        .move_table = &move_table,
        .writer = writer,
        .search = .{
          .expectimax = expectimax,
          .bfs = bfs,
        },
        .out = &stats,
        .id = 0,
        .iter = 10,
      }
    });

    defer thread.join();
  }

  if (stats) |result| {
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
