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
    const table = table: {
      const table_size = fields.len * 3 / 2;
      var indices: [table_size]u32 = @splat(fields.len);
      var probes: [table_size]comptime_int = @splat(0);
      var max_probe = 0;

      for (fields, 0..) |field, i| {
        var h = hash(field.name, table_size);

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

      var wrapped = indices ++ indices[0..max_probe].*;
      var values: [wrapped.len]Value = undefined;

      var pool: []const u8 = &.{};
      var ptr = 0;

      for (&wrapped, &values) |*index, *value| {
        if (index.* < fields.len) {
          const s = fields[index.*].name;
          index.* = ptr;
          value.* = @field(kvs, s);
          pool = pool ++ s;
          ptr += s.len;
        } else {
          index.* = ptr;
        }
      }

      break :table .{
        .pool = pool,
        .size = table_size,
        .values = values,
        .indices = wrapped ++ .{ ptr },
        .max_probe = max_probe,
      };
    };

    fn get(key: []const u8) ?Value {
      const h = hash(key, table.size);
      inline for (0..table.max_probe + 1) |probe| {
        const l = table.indices[h + probe];
        const r = table.indices[h + probe + 1];

        if (mem.eql(u8, key, table.pool[l..r])) {
          return table.values[h + probe];
        }
      }
      return null;
    }

    comptime {
      for (fields) |field| {
        const key = field.name;
        const value = @field(kvs, key);
        if (get(key) != value) unreachable;
      }
    }
  };

  return S.get;
}

const endian = @import("builtin").target.cpu.arch.endian();
const mem = @import("std").mem;
