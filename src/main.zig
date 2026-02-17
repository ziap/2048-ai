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

  var board: Board, var four_count: u32 = Board.new(&rng);
  try board.display(writer);
  try writer.flush();

  const expectimax, var bfs: Bfs = ctx: {
    const S = struct {
      var heuristic: Heuristic = undefined;
      var expectimax: Expectimax = undefined;
      var bfs_buffer: [400_000]Board = undefined;
    };

    S.heuristic = .new();
    S.expectimax = .new(&move_table, &S.heuristic);

    break :ctx .{
      &S.expectimax,
      .new(&S.bfs_buffer, &move_table),
    };
  };

  var total_time: f64 = 0;
  var total_move: u64 = 0;

  while (true) {
    const moves = move_table.getMoves(board);
    const valid = board.filterMoves(&moves);
    var timer = try std.time.Timer.start();
    const depth = bfs.expand(valid.moves[0..valid.len]).depth + 1;
    const dir = expectimax.search(board, depth) orelse break;
    total_time += @as(f64, @floatFromInt(timer.read()));
    total_move += 1;
    board, const is_four = moves[dir].addTile(&rng);
    four_count += is_four;

    try board.display(writer);
    try writer.print("Search depth: {}\n", .{ depth });
    try writer.flush();
  }

  const stats: Stats = .fromResult(.{
    .final_board = board,
    .four_count = four_count,
    .total_time = total_time,
    .total_moves = total_move,
  });

  try stats.display(writer);
  try writer.flush();
}

const std = @import("std");
const Fmc256 = @import("lib/Fmc256.zig");
const Board = @import("lib/Board.zig");
const Heuristic = @import("lib/Heuristic.zig");
const Bfs = @import("lib/Bfs.zig");
const Expectimax = @import("lib/Expectimax.zig");
const Stats = @import("lib/Stats.zig");
