pub fn LazyInit(T: type) type {
  return struct {
    inner: T,
    ready: bool,

    pub const uninit: @This() = .{ .inner = undefined, .ready = false, };

    pub fn get(self: *@This()) *T {
      if (self.ready) return &self.inner;
      self.ready = true;
      self.inner.init();
      return &self.inner;
    }
  };
}
