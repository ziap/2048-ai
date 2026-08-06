const Bfs = @This();

current: []Board,
next: []Board,

move_table: *const Board.MoveTable,
formation: Board.Formation = .none,

pub inline fn new(buffer: []Board, move_table: *const Board.MoveTable) Bfs {
  const mid = buffer.len / 2;
  return .{
    .current = buffer[0..mid],
    .next = buffer[mid..2 * mid],
    .move_table = move_table,
  };
}

// TODO(zig 0.17): delete `clear` and go back to a plain `@memset(count, 0)`.
//
// Zig 0.16 stopped linking musl's memset in favour of a Zig implementation in
// compiler_rt that compiles to a byte-at-a-time loop (ziglang/zig#32091, fixed
// in the 0.17 milestone). Clearing these 256 KiB of buckets twice per sort()
// call is the hottest thing in the program, so it alone costs ~1.5x
// end-to-end.
//
// Wasm is excluded deliberately, bulk_memory lowers @memset to a single
// memory.fill, and forcing the loop there replaces it with a v128.store loop.
inline fn clear(count: *align(64) [65536]u32) void {
  if (comptime builtin.target.cpu.arch.isWasm()) {
    @memset(count, 0);
    return;
  }

  const V = @Vector(16, u32);
  const vectors: *volatile [count.len / 16]V = @ptrCast(count);
  for (vectors) |*v| v.* = @splat(0);
}

// Sort by 32-bit hash to improve speed at the cost of duplication
fn sort(self: *Bfs, len: u32) void {
  const S = struct {
    inline fn pass(in: []Board, out: []Board, count: *align(64) [65536]u32, idx: comptime_int) void {
      const shift = comptime @as(u5, idx) * 16;
      clear(count);
      for (in) |item| {
        const radix: u16 = @truncate(item.hash(32) >> shift);
        count[radix] += 1;
      }
      var acc: u32 = 0;
      for (count) |*item| {
        const old = acc;
        acc += item.*;
        item.* = old;
      }
      for (in) |item| {
        const radix: u16 = @truncate(item.hash(32) >> shift);
        out[count[radix]] = item;
        count[radix] += 1;
      }
    }
  };

  var count: [65536]u32 align(64) = undefined;
  const items = self.current[0..len];
  const scratch = self.next[0..len];

  S.pass(items, scratch, &count, 0);
  S.pass(scratch, items, &count, 1);
}

const OVERFLOW_MARGIN = 2;

const Result = struct {
  boards: []const Board,
  depth: u8,
};

pub fn expand(self: *Bfs, initial: []const Board) Result {
  @memcpy(self.current[0..initial.len], initial);
  var current_len: u32 = @intCast(initial.len);

  var depth: u8 = 0;
  var prev_len: u32 = 1;

  search: while (current_len > 0) {
    self.sort(current_len);

    const estimate = @as(u64, current_len) * current_len / prev_len;
    if (estimate > @as(u64, self.next.len) * OVERFLOW_MARGIN) break :search;

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
            if (!self.formation.intact(moved)) continue;
            if (next_len == self.next.len) break :search;

            self.next[next_len] = moved;
            next_len += 1;
          }
        }
      }
    }

    const tmp = self.current;
    self.current = self.next;
    prev_len = current_len;
    current_len = next_len;

    self.next = tmp;
    depth += 1;
  }

  return .{
    .boards = self.current[0..current_len],
    .depth = depth,
  };
}

const builtin = @import("builtin");
const Board = @import("Board.zig");
