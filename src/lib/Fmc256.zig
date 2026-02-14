const Fmc256 = @This();

const MUL = 0xfffff6827807261d;
const endian = @import("builtin").target.cpu.arch.endian();

state: [4]u64,

/// Constructs an RNG from a 256-bit seed, maps them into the algebraic ring
pub fn fromSeed(seed: [4]u64) Fmc256 {
  var state: [4]u64 = undefined;
  var carry = seed[3];
  for (state[0..3], seed[0..3]) |*item, limb| {
    const m = @as(u128, limb) * MUL + carry;
    item.* = @truncate(m);
    carry = @intCast(m >> 64);
  }
  state[3] = carry;

  // Ensure non-zero state
  const v: u256 = @bitCast(state);
  if (v == 0) state[0] = 1;
  var result: Fmc256 = .{ .state = state };

  // Ensure state < MOD
  _ = result.next();
  return result;
}

/// Construct an RNG from an arbitrary length entropy sequence
pub fn fromBytes(data: []const u8) Fmc256 {
  const S = struct {
    inline fn mix(state: *[4]u64, chunk: u64) void {
      const m = @as(u128, state[0]) * MUL + state[3] + chunk;
      state[0] = state[1];
      state[1] = state[2];
      state[2] = @truncate(m);
      state[3] = @intCast(m >> 64);
    }
  };

  var state: [4]u64 = @splat(0);
  const step1 = @sizeOf(u64);
  const step3 = 3 * step1;
  var idx: usize = 0;

  while (idx + step3 <= data.len) : (idx += step3) {
    var chunk: [3]u64 = undefined;
    const chunk_ptr: *[step3]u8 = @ptrCast(&chunk);
    @memcpy(chunk_ptr, data[idx..idx + step3]);

    var carry = state[3];
    inline for (state[0..3], &chunk) |*item, x| {
      const limb = if (comptime endian == .little) x else @byteSwap(x);

      const m = @as(u128, item.*) * MUL + carry + limb;
      item.* = @truncate(m);
      carry = @intCast(m >> 64);
    }
    state[3] = carry;
  }

  duff: switch ((data.len - idx) / step1) {
    inline 1...2 => |x| {
      var chunk: u64 = undefined;
      const chunk_ptr: *[step1]u8 = @ptrCast(&chunk);
      @memcpy(chunk_ptr, data[idx..idx + step1]);
      if (comptime endian != .little) chunk = @byteSwap(chunk);

      S.mix(&state, chunk);
      idx += step1;
      continue :duff comptime x - 1;
    },
    inline 0 => {},
    else => unreachable,
  }

  if (idx < data.len) {
    var chunk: u64 = 0;
    duff: switch (data.len - idx) {
      inline 1...(step1 - 1) => |x| {
        const nx = comptime x - 1;
        chunk = (chunk << 8) | data[idx + nx];
        continue :duff nx;
      },
      inline 0 => {},
      else => unreachable,
    }

    S.mix(&state, chunk);
  }

  const v: u256 = @bitCast(state);
  if (v == 0) state[0] = 1;
  return .{ .state = state };
}

/// Generate the next 64-bit output from the generator and advance state by one
pub inline fn next(self: *Fmc256) u64 {
  const result = self.state[2] ^ self.state[3];
  const m = @as(u128, self.state[0]) * MUL + self.state[3];
  self.state[0] = self.state[1];
  self.state[1] = self.state[2];
  self.state[2] = @truncate(m);
  self.state[3] = @intCast(m >> 64);
  return result;
}

/// Fast but biased bounded number generator using Lemire's reduction
/// In this application the range is usually small so the bias is negligible
pub fn bounded(self: *Fmc256, range: u64) u64 {
  return @truncate((@as(u128, self.next()) * range) >> 64);
}
