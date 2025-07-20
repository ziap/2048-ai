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
