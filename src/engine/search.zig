// `cache_bits` sizes the transposition table; 0 disables it entirely.
pub fn Expectimax(Eval: type, comptime cache_bits: comptime_int) type {
  return struct {
    const transposition = cache_bits > 0;

    pub const Cache = if (transposition) struct {
      const CACHE_SIZE = 1 << cache_bits;

      const Data = packed struct(u38) {
        depth: u6,
        score: f32,
      };

      const Entry = struct {
        key: u64,
        data: Data,
      };

      entries: [CACHE_SIZE]Entry align(64),

      fn empty(self: *Cache) void {
        @memset(&self.entries, .{
          .key = 0,
          .data = .{ .depth = 0, .score = 0 },
        });
      }

      inline fn mix(data: Data) u64 {
        return @as(u38, @bitCast(data));
      }

      fn insert(self: *Cache, board: Board, depth: u6, score: f32) void {
        const data: Data = .{ .depth = depth, .score = score };
        // Volatile so both halves are written exactly once, in this order.
        const entry: *volatile Entry = &self.entries[board.hash(cache_bits)];

        entry.key = board.data ^ mix(data);
        entry.data = data;
      }

      fn query(self: *Cache, board: Board, depth: u6) ?f32 {
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

    pub fn call(self: *const Self, valid: *const Board.ValidMoves, depth: u6) ?u2 {
      var best_move: ?u2 = null;
      var best_score: f32 = 0;

      for (valid.moves[0..valid.len], valid.dirs[0..valid.len]) |move, dir| {
        const score = self.scoreFrontier(move, depth);
        if (score > best_score) {
          best_score = score;
          best_move = dir;
        }
      }

      return best_move;
    }

    // Callers empty the table when starting a game, so that its result never
    // depends on what the same worker played before it. Nothing else invalidates
    // an entry.
    pub fn clear(self: Self) void {
      if (transposition and !@inComptime()) self.cache.empty();
    }

    pub fn new(move_table: *const Board.MoveTable, heuristic: Eval, cache: if (transposition) *Cache else void) @This() {
      return .{
        .move_table = move_table,
        .heuristic = heuristic,
        .cache = cache,
      };
    }

    pub fn scoreFrontier(self: *const Self, board: Board, depth: u6) f32 {
      return self.expectNode(board, depth, .get(board));
    }

    fn expectNode(self: *const Self, board: Board, depth: u6, formation: Formation) f32 {
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

      // Spawning a 2 or a 4 cannot change which cells hold a large tile, so one
      // update here covers every child below.
      const nextFormation = formation.update(board);

      while (mask != 0) {
        const tile = mask & -%mask;
        mask ^= tile;

        score += w2 * self.maxNode(.{ .data = board.data | tile, }, depth, nextFormation);
        score += w4 * self.maxNode(.{ .data = board.data | (tile << 1), }, depth, nextFormation);
      }

      if (transposition) {
        self.cache.insert(board, depth, score);
      }
      return score;
    }

    fn maxNode(self: *const Self, board: Board, depth: u6, formation: Formation) f32 {
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
const Formation = @import("Formation.zig");
