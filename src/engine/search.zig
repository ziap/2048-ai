// `cache_bits` sizes the transposition table; 0 disables it entirely.
pub fn Expectimax(Eval: type, comptime cache_bits: comptime_int) type {
  return struct {
    const transposition = cache_bits > 0;

    pub const Cache = if (transposition) struct {
      const CACHE_SIZE = 1 << cache_bits;

      const Data = packed struct(u40) {
        depth: u8,
        score: f32,
      };

      const Entry = struct {
        key: u64,
        data: Data,
      };

      comptime {
        if (@sizeOf(Entry) != 16) @compileError("entry must stay a 16-byte pair");
      }

      entries: [CACHE_SIZE]Entry align(64),
      formation: Board.Formation,

      fn adopt(self: *Cache, formation: ?Board.Formation) void {
        if (formation) |wanted| {
          if (self.formation.eql(wanted)) return;
          self.formation = wanted;
        } else {
          self.formation = .none;
        }

        @memset(&self.entries, .{
          .key = 0,
          .data = .{ .depth = 0, .score = 0 },
        });
      }

      inline fn mix(data: Data) u64 {
        return @as(u40, @bitCast(data));
      }

      fn insert(self: *Cache, board: Board, depth: u8, score: f32) void {
        const data: Data = .{ .depth = depth, .score = score };
        // Volatile so both halves are written exactly once, in this order.
        const entry: *volatile Entry = &self.entries[board.hash(cache_bits)];

        entry.key = board.data ^ mix(data);
        entry.data = data;
      }

      fn query(self: *Cache, board: Board, depth: u8) ?f32 {
        // Volatile so neither half can be reloaded after the check below.
        const entry: *volatile Entry = &self.entries[board.hash(cache_bits)];

        const key = entry.key;
        const data = entry.data;

        if (key ^ mix(data) != board.data) return null;
        if (data.depth < depth) return null;

        return data.score;
      }
    } else void;

    const Self = @This();

    move_table: *const Board.MoveTable,
    heuristic: Eval,
    cache: if (transposition) *Cache else void,

    pub const Fn = struct {
      inner: Self,
      formation: Board.Formation,

      pub fn call(self: *const Fn, board: Board, depth: u8) ?u2 {
        var best_move: ?u2 = null;
        var best_score: f32 = 0;

        inline for (self.inner.move_table.getMoves(board), 0..) |next_board, dir| {
          if (next_board.data != board.data and self.formation.intact(next_board)) {
            const score = self.inner.expectNode(next_board, depth, self.formation);
            if (score > best_score) {
              best_score = score;
              best_move = dir;
            }
          }
        }

        return best_move;
      }
    };

    pub fn reset(self: Self, formation: ?Board.Formation) Fn {
      if (transposition and !@inComptime()) {
        self.cache.adopt(formation);
      }

      return .{ .inner = self, .formation = formation orelse .none };
    }

    pub fn new(move_table: *const Board.MoveTable, heuristic: Eval, cache: if (transposition) *Cache else void) @This() {
      return .{
        .move_table = move_table,
        .heuristic = heuristic,
        .cache = cache,
      };
    }

    pub fn expectNode(self: *const Self, board: Board, depth: u8, formation: Board.Formation) f32 {
      if (depth == 0) {
        return self.heuristic.evaluate(board);
      }

      if (transposition) {
        if (self.cache.query(board, depth)) |score| {
          return score;
        }
      }

      var mask = board.emptyPos();
      const total: f32 = @floatFromInt(@popCount(mask));
      var score: f32 = 0;

      const w2 = 0.9 / total;
      const w4 = 0.1 / total;

      while (mask != 0) {
        const tile = mask & -%mask;
        mask ^= tile;

        score += w2 * self.maxNode(.{ .data = board.data | tile, }, depth, formation);
        score += w4 * self.maxNode(.{ .data = board.data | (tile << 1), }, depth, formation);
      }

      if (transposition) {
        self.cache.insert(board, depth, score);
      }
      return score;
    }

    fn maxNode(self: *const Self, board: Board, depth: u8, formation: Board.Formation) f32 {
      const moves = self.move_table.getMoves(board);

      var max_score: f32 = 0;
      inline for (moves) |next_board| {
        if (next_board.data != board.data and formation.intact(next_board)) {
          max_score = @max(max_score, self.expectNode(next_board, depth - 1, formation));
        }
      }

      return max_score;
    }
  };
}

const Board = @import("Board.zig");
