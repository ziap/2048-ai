pub fn EnumMap(Key: type, Value: type) type {
  const info = switch(@typeInfo(Key)) {
    .@"enum" => |info| info,
    else => @compileError("key of `EnumMap` must be an enum"),
  };

  for (info.field_values, 0..) |field, value| {
    if (field != value) {
      @compileError("sparse enum not supported");
    }
  }

  return struct {
    const Self = @This();
    pub const len = info.field_values.len;

    pub const keys: [len]Key = blk: {
      var arr: [len]Key = undefined;
      for (&arr, 0..) |*item, key| {
        item.* = @fromBackingInt(key);
      }
      break :blk arr;
    };

    values: [len]Value,

    pub inline fn get(self: *const Self, key: Key) *const Value {
      return &self.values[@backingInt(key)];
    }

    pub inline fn getMut(self: *Self, key: Key) *Value {
      return &self.values[@backingInt(key)];
    }
  };
}
