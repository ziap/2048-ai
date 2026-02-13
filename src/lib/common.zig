pub fn Uint(BITS: comptime_int) type {
  return @Type(.{
    .int = .{
      .signedness = .unsigned,
      .bits = BITS,
    }
  });
}

pub fn modinv(T: type, x: T) T {
  const iter_count = comptime iter_count: {
    const size = @typeInfo(T).int.bits;
    const bits = @typeInfo(@TypeOf(size)).int.bits;
    break :iter_count bits - @clz(size) - 1;
  };

  var res: T = 1;
  inline for (0..iter_count) |_| {
    res *%= 2 -% x *% res;
  }

  if (res *% x != 1) unreachable;
  return res;
}
