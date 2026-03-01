const Worker = @This();

const Expectimax = engine.Expectimax(*const Heuristic, true);

id: u32,
rng: Fmc256,
write_lock: *std.Thread.Mutex,
move_table: *const Board.MoveTable,
expectimax: *Expectimax,
bfs: Bfs,

pub const Shared = struct {
  move_table: *const Board.MoveTable,
  heuristic: *const Heuristic,
  write_lock: *std.Thread.Mutex,
  budget: u32,
};

pub fn new(id: u32, rng: *Fmc256, shared: Shared, arena: std.mem.Allocator) !Worker {
  rng.jump(.default);

  const expectimax = try arena.create(Expectimax);
  const bfs_buffer = try arena.alloc(Board, shared.budget);
  expectimax.* = .new(shared.move_table, shared.heuristic);

  return .{
    .id = id,
    .rng = rng.*,
    .write_lock = shared.write_lock,
    .move_table = shared.move_table,
    .expectimax = expectimax,
    .bfs = .new(bfs_buffer, shared.move_table),
  };
}

pub fn run_games(self: *Worker, iter: u32, out: *Stats) !void {
  var buffer: [4096]u8 = undefined;
  var stdout = std.fs.File.stdout().writer(&buffer);
  const writer = &stdout.interface;

  var stats: Stats = .empty;
  var bfs = self.bfs;

  for (0..iter) |_| {
    var board: Board, var four_count: u32 = Board.new(&self.rng);

    var total_time: f64 = 0;
    var total_move: u64 = 0;

    while (true) {
      const moves = self.move_table.getMoves(board);
      const valid = board.filterMoves(&moves);
      var timer = try std.time.Timer.start();
      const depth = bfs.expand(valid.moves[0..valid.len]).depth + 1;
      const dir = self.expectimax.search(board, depth) orelse break;
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

const std = @import("std");
const engine = @import("engine");
const Fmc256 = engine.Fmc256;
const Board = engine.Board;
const Heuristic = engine.Heuristic;
const Bfs = engine.Bfs;

const Stats = @import("Stats.zig");
