fn StringMap(V: type) type {
  return struct {
    key_pool: []const u8,
    values: []const V,

    key_offsets: []const u32,
    value_indices: []const u32,

    min_len: u32,
    max_len: u32,

    fn get(self: @This(), key: []const u8) ?V {
      if (key.len < self.min_len or key.len > self.max_len) {
        return null;
      }

      const bin = key.len - self.min_len;
      const end = self.value_indices[bin + 1];
      var idx = self.value_indices[bin];
      var offset = self.key_offsets[bin];

      while (idx < end) {
        const eql = struct {
          fn eql(a: []const u8, b: []const u8) bool {
            for (a, b) |a_i, b_i| {
              if (a_i != b_i) return false;
            }

            return true;
          }
        }.eql;

        if (eql(key, self.key_pool[offset..offset + key.len])) {
          return self.values[idx];
        }

        idx += 1;
        offset += @intCast(key.len);
      }

      return null;
    }

    inline fn init(comptime kvs: anytype) @This() {
      comptime {
        const type_info = @typeInfo(@TypeOf(kvs));
        const fields = type_info.@"struct".fields;
        
        const min_len, const max_len = range: {
          var min_len = fields[0].name.len;
          var max_len = fields[0].name.len;

          for (fields[1..]) |field| {
            min_len = @min(min_len, field.name.len);
            max_len = @max(max_len, field.name.len);
          }

          break :range .{ min_len, max_len };
        };

        var counts: [max_len + 1 - min_len]u32 = @splat(0);
        for (fields) |field| {
          counts[field.name.len - min_len] += 1;
        }

        var acc = 0;
        for (&counts) |*count| {
          const freq = count.*;
          count.* = acc;
          acc += freq;
        }

        var sorted_keys: [fields.len]union {
          some: []const u8,
          none: void,
        } = @splat(.{ .none = {} });

        var sorted_values: [fields.len]union {
          some: V,
          none: void,
        } = @splat(.{ .none = {} });

        for (fields) |field| {
          const bin = field.name.len - min_len;
          const idx = counts[bin];
          sorted_keys[idx] = .{ .some = field.name };
          sorted_values[idx] = .{ .some = @field(kvs, field.name) };
          counts[bin] += 1;
        }

        const value_indices = .{ 0 } ++ counts;
        var key_pool: []const u8 = &.{};
        var total_length = 0;

        const key_offsets = key_offsets: {
          var key_offsets: [max_len + 1 - min_len]u32 = undefined;
          for (&key_offsets, 0..) |*offset, idx| {
            const l = value_indices[idx];
            const r = value_indices[idx + 1];

            offset.* = total_length;

            for (sorted_keys[l..r]) |key| {
              key_pool = key_pool ++ key.some;
              total_length += key.some.len;
            }
          }

          break :key_offsets key_offsets;
        };

        const values = values: {
          var values: [fields.len]V = undefined;
          for (&values, sorted_values) |*value, sorted_value| {
            value.* = sorted_value.some;
          }
          
          break :values values;
        };

        return .{
          .key_pool = key_pool,
          .values = &values,
          
          .key_offsets = &key_offsets,
          .value_indices = &value_indices,

          .min_len = min_len,
          .max_len = max_len,
        };
      }
    }
  };
}
