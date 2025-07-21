pub fn Uint(BITS: comptime_int) type {
  return @Type(.{
    .int = .{
      .signedness = .unsigned,
      .bits = BITS,
    }
  });
}

pub fn reverse16(x: u16) u16 {
  return (
    (x >> 12) |
    ((x >> 4) & 0x00f0) |
    ((x << 4) & 0x0f00) |
    (x << 12)
  );
}

pub fn modinv(T: type, x: T) T {
  const iter_count = comptime iter_count: {
    const size = @typeInfo(T).int.bits;

    var iter_count = 0;
    while ((1 << iter_count) < size) {
      iter_count += 1;
    }

    break :iter_count iter_count;
  };

  var res: T = 1;
  inline for (0..iter_count) |_| {
    res *%= 2 -% x *% res;
  }

  if (res *% x != 1) unreachable;
  return res;
}
