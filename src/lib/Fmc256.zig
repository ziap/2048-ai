const Fmc256 = @This();

const MUL = 0xffff1aa1c69c8d92;
const MOD = (MUL << 192) - 1;

pub const JUMP_SMALL = 1 << 128;
pub const JUMP_BIG = 1 << 192;

pub const JUMP_PHI = blk: {
  // Initial approximation: 0.625
  var x = MOD * 5 / 8;
  var dec = false;

  // Newton's method iterations
  while (true) {
    const nx = (MOD * MOD + x * x) / (MOD + 2 * x);
    if (x == nx or (dec and nx > x)) break :blk x;

    dec = nx < x;
    x = nx;
  }
};

state: [3]u64,
carry: u64,

pub fn next(self: *Fmc256) u64 {
  const result = self.state[2] ^ self.carry;
  const m = @as(u128, self.state[0]) * MUL + self.carry;
  self.state[0] = self.state[1];
  self.state[1] = self.state[2];
  self.state[2] = @truncate(m);
  self.carry = @intCast(m >> 64);
  return result;
}

/// Montgomery space for fast modular arithmetic of 256-bit integers
/// Code taken from: https://en.algorithmica.org/hpc/number-theory/montgomery/
/// and adapted to 256-bit
const Montgomery = struct {
  /// Multiplicative inverse of MOD modulo 2^256
  const MOD_INV = common.modinv(u256, MOD);

  /// Multiply two number in Montgomery space, or (rx, ry) -> rxy
  fn multiply(x: u256, y: u256) u256 {
    // Wide multiplication into 512-bit
    const p = @as(u512, x) * @as(u512, y);
    const lo: u256 = @truncate(p);
    const hi: u256 = @intCast(p >> 256);

    // Perform Montgomery reduction
    const q: u256 = lo *% MOD_INV;
    const m: u256 = @intCast((@as(u512, q) * MOD) >> 256);
    if (hi < m) return hi + (MOD - m);
    return hi - m;
  }

  /// Raise a number in Montgomery space to a power of an integer
  fn power(x: u256, n: comptime_int) u256 {
    var a = comptime from(1);
    var b = x;

    var t = n;
    while (t > 0) : (t >>= 1) {
      if (t & 1 != 0) {
        a = multiply(a, b);
      }
      b = multiply(b, b);
    }

    return a;
  }

  /// Convert a number into Montgomery space, or x -> xr
  fn from(x: u256) u256 {
    const r2 = comptime ((1 << 512) % MOD);
    return multiply(x, r2);
  }
};

/// Modular inverse of 2^64 in Montgomery space
/// This is the multiplier of the MCG that the generator simulates
const B_INV = Montgomery.power(Montgomery.from(1 << 64), MOD - 2);

/// Equivalent to advancing the generator N times
pub fn jump(self: *Fmc256, N: comptime_int) void {
  const a = comptime Montgomery.power(B_INV, N);

  const s = (
    (@as(u256, self.state[0]) << 0) |
    (@as(u256, self.state[1]) << 64) |
    (@as(u256, self.state[2]) << 128) |
    (@as(u256, self.carry) << 192)
  );

  const result = Montgomery.multiply(s, a);

  self.state[0] = @truncate(result >> 0);
  self.state[1] = @truncate(result >> 64);
  self.state[2] = @truncate(result >> 128);
  self.carry = @intCast(result >> 192);
}

/// Construct an RNG from a 256-bit seed
pub fn fromSeed(seed: *const [4]u64) Fmc256 {
  // Some requirements for seeding:
  // - The carry must be less than MUL - 1
  // - The state and carry cannot be all zero
  // For simplicity, initialize the state with any 192-bit seed and set the
  // carry to a value between 1 and MUL - 1
  var rng: Fmc256 = .{
    .state = seed[0..3].*,
    .carry = seed[3] % (MUL - 2) + 1,
  };

  rng.jump(JUMP_PHI);
  return rng;
}

/// Fast but biased bounded number generator using Lemire's reduction
/// In this application the range is usually small so the bias is negligible
pub fn bounded(self: *Fmc256, range: u64) u64 {
  return @truncate((@as(u128, self.next()) * range) >> 64);
}

const common = @import("common.zig");
