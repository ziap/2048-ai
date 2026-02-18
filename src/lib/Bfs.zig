const Bfs = @This();

current: []Board,
next: []Board,

move_table: *const Board.MoveTable,

pub inline fn new(buffer: []Board, move_table: *const Board.MoveTable) Bfs {
  const mid = buffer.len / 2;
  return .{
    .current = buffer[0..mid],
    .next = buffer[mid..2 * mid],
    .move_table = move_table,
  };
}

fn sort(self: *Bfs, len: u32) void {
  const S = struct {
    inline fn pass(in: []Board, out: []Board, count: *[65536]u32, idx: comptime_int) void {
      const shift = comptime @as(u6, idx) * 16;
      @memset(count, 0);
      for (in) |item| {
        const radix: u16 = @truncate(item.data >> shift);
        count[radix] += 1;
      }
      var acc: u32 = 0;
      for (count) |*item| {
        const old = acc;
        acc += item.*;
        item.* = old;
      }
      for (in) |item| {
        const radix: u16 = @truncate(item.data >> shift);
        out[count[radix]] = item;
        count[radix] += 1;
      }
    }
  };

  var count: [65536]u32 = undefined;
  const items = self.current[0..len];
  const scratch = self.next[0..len];

  S.pass(items, scratch, &count, 0);
  S.pass(scratch, items, &count, 1);
  S.pass(items, scratch, &count, 2);
  S.pass(scratch, items, &count, 3);
}

const Result = struct {
  boards: []const Board,
  depth: u8,
};

pub fn expand(self: *Bfs, initial: []const Board) Result {
  @memcpy(self.current[0..initial.len], initial);
  var current_len: u32 = @intCast(initial.len);

  var depth: u8 = 0;

  search: while (current_len > 0) {
    self.sort(current_len);

    var next_len: u32 = 0;
    var last: u64 = 0;
    for (self.current[0..current_len]) |next_board| {
      if (last == next_board.data) continue;
      last = next_board.data;

      var mask = next_board.emptyPos();
      while (mask != 0) {
        const tile = mask & -%mask;
        mask ^= tile;

        const next2: Board = .{ .data = last | tile };
        const next4: Board = .{ .data = last | (tile << 1) };

        for ([_]Board{ next2, next4 }) |spawned| {
          for (self.move_table.getMoves(spawned)) |moved| {
            if (moved.data == spawned.data) continue;
            if (next_len == self.next.len) break :search;

            self.next[next_len] = moved;
            next_len += 1;
          }
        }
      }
    }

    const tmp = self.current;
    self.current = self.next;
    current_len = next_len;

    self.next = tmp;
    depth += 1;
  }

  return .{
    .boards = self.current[0..current_len],
    .depth = depth,
  };
}

const Board = @import("Board.zig");
