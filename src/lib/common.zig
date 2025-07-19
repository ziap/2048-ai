pub fn Uint(BITS: comptime_int) type {
  return @Type(.{
    .int = .{
      .signedness = .unsigned,
      .bits = BITS,
    }
  });
}
