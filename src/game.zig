pub fn main() !void {
  var buffer = std.io.bufferedWriter(std.io.getStdOut().writer());
  var writer = buffer.writer();

  var rng: Fmc256 = rng: {
    var seed: [4]u64 = undefined;
    try std.posix.getrandom(@ptrCast(&seed));
    break :rng .fromSeed(&seed);
  };

  const move_table: Board.MoveTable = .new();
  var board: Board = .new(&rng);
  try board.display(&writer);
  try buffer.flush();

  const stdin = std.io.getStdIn();
  var term = try std.posix.tcgetattr(stdin.handle);
  term.lflag.ICANON = false;
  term.lflag.ECHO = false;
  try std.posix.tcsetattr(stdin.handle, .NOW, term);

  while (true) {
    const moves = move_table.getMoves(board);
    if (board.filterMoves(&moves).len == 0) {
      break;
    }

    const dir = dir: switch (try stdin.reader().readByte()) {
      'w', 'k' => Board.UP,
      'a', 'h' => Board.LEFT,
      's', 'j' => Board.DOWN,
      'd', 'l' => Board.RIGHT,
      'q' => break,
      else => continue :dir try stdin.reader().readByte(),
    };
    const next_board = moves[dir];
    if (board.data == next_board.data) continue;

    board = moves[dir].addTile(&rng);

    try board.display(&writer);
    try buffer.flush();
  }

  try writer.writeAll("\n\nGame over!\n");

  term.lflag.ICANON = true;
  term.lflag.ECHO = true;
  try std.posix.tcsetattr(stdin.handle, .NOW, term);
  try buffer.flush();
}

const std = @import("std");
const Fmc256 = @import("lib/Fmc256.zig");
const Board = @import("lib/Board.zig");
