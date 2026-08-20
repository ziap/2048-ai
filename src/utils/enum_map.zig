pub fn EnumMap(Key: type, Value: type) type {
  const info = switch(@typeInfo(Key)) {
    .@"enum" => |info| info,
    else => @compileError("key of `EnumMap` must be an enum"),
  };

  var size = 0;
  for (info.fields) |field| {
    size = @max(size, field.value);
  }

  if (size + 1 != info.fields.len) {
    @compileError("sparse enum not supported");
  }

  return struct {
    const Self = @This();
    pub const len = info.fields.len;

    pub const keys: [len]Key = blk: {
      var arr: [len]Key = undefined;
      for (&arr, 0..) |*item, key| {
        item.* = @enumFromInt(key);
      }
      break :blk arr;
    };

    values: [len]Value,

    pub inline fn get(self: *const Self, key: Key) *const Value {
      return &self.values[@intFromEnum(key)];
    }

    pub inline fn getMut(self: *Self, key: Key) *Value {
      return &self.values[@intFromEnum(key)];
    }
  };
}
