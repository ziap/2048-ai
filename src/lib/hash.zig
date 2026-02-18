// MCG multiplier from: <https://arxiv.org/pdf/2001.05304>
pub const MUL = 0xf1357aea2e62a9c5;

fn hash(data: []const u8, range: u64) u64 {
  var h: u64 = @intCast(data.len);
  var idx: usize = 0;
  const step = @sizeOf(u64);

  const S = struct {
    inline fn mix(x: u64, y: u64) u64 {
      const m = (x +% y) *% MUL;
      return m +% ((m << 26) | (m >> 38));
    }
  };

  while (idx + step <= data.len) : (idx += step) {
    var chunk: u64 = undefined;
    const chunk_ptr: *[step]u8 = @ptrCast(&chunk);
    @memcpy(chunk_ptr, data[idx..idx + step]);

    if (comptime endian != .little) chunk = @byteSwap(chunk);
    h = S.mix(h, chunk);
  }
  
  if (idx < data.len) {
    var chunk: u64 = 0;
    duff: switch (data.len - idx) {
      inline 1...(step - 1) => |x| {
        const nx = comptime x - 1;
        chunk = (chunk << 8) | data[idx + nx];
        continue :duff nx;
      },
      inline 0 => {},
      else => unreachable,
    }
    h = S.mix(h, chunk);
  }

  h = S.mix(h, 0);
  return @truncate((@as(u128, h) * range) >> 64);
}

pub fn stringMap(Value: type, kvs: anytype) fn ([]const u8) ?Value {
  const type_info = @typeInfo(@TypeOf(kvs));
  const fields = type_info.@"struct".fields;

  const S = struct {
    const keys = keys: {
      var result: [fields.len + 1][]const u8 = undefined;
      for (fields, result[0..fields.len]) |field, *key| {
        key.* = field.name;
      }
      result[fields.len] = "";
      break :keys result;
    };

    const values = values: {
      var result: [fields.len]Value = undefined;
      for (fields, &result) |field, *value| {
        value.* = @field(kvs, field.name);
      }
      break :values result;
    };

    const table = table: {
      const shift = shift: {
        var shift: comptime_int = 0;
        while ((1 << shift) < fields.len + 1) shift += 1;
        break :shift shift;
      };

      const Index = @Type(.{
        .int = .{
          .signedness = .unsigned,
          .bits = shift,
        },
      });

      const table_size = fields.len * 3 / 2;
      var indices: [table_size]Index = @splat(fields.len);
      var probes: [table_size]comptime_int = @splat(0);
      var max_probe = 0;

      for (0..fields.len) |i| {
        var h = hash(keys[i], table_size);

        var index = i;
        var probe = 0;

        while (indices[h] < fields.len) {
          if (probe > probes[h]) {
            const old_index = indices[h];
            const old_probe = probes[h];
            indices[h] = index;
            probes[h] = probe;

            index = old_index;
            probe = old_probe;
          }

          h = (h + 1) % table_size;
          probe += 1;
          max_probe = @max(max_probe, probe);
        }

        indices[h] = index;
        probes[h] = probe;
      }

      break :table .{
        .size = table_size,
        .indices = indices ++ indices[0..max_probe].*,
        .max_probe = max_probe,
      };
    };

    fn get(key: []const u8) ?Value {
      const h = hash(key, table.size);
      inline for (0..table.max_probe + 1) |probe| {
        const idx = table.indices[h + probe];
        if (mem.eql(u8, key, keys[idx])) {
          return values[idx];
        }
      }
      return null;
    }

    comptime {
      for (keys[0..fields.len], values) |key, value| {
        if (get(key) != value) unreachable;
      }
    }
  };

  return S.get;
}

const endian = @import("builtin").target.cpu.arch.endian();
const mem = @import("std").mem;
