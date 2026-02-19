// MCG multiplier from: <https://arxiv.org/pdf/2001.05304>
pub const MUL = 0xf1357aea2e62a9c5;

fn hash(data: []const u8) u64 {
  const S = struct {
    inline fn loadLe(T: type, ptr: []const u8) T {
      var chunk: T = undefined;
      const chunk_ptr: *[@sizeOf(T)]u8 = @ptrCast(&chunk);
      @memcpy(chunk_ptr, ptr[0..@sizeOf(T)]);

      if (comptime endian != .little) return @byteSwap(chunk);
      return chunk;
    }

    inline fn mix(x: u64, y: u64) u64 {
      const m = (x +% y) *% MUL;
      return m +% ((m << 26) | (m >> 38));
    }
  };

  const step = @sizeOf(u64);
  var h = S.mix(0x243f6a8885a308d3, data.len);
  var ptr = data;

  while (ptr.len >= step) : (ptr = ptr[step..]) {
    const chunk = S.loadLe(u64, ptr);
    h = S.mix(h, chunk);
  }
  
  if (ptr.len > 0) {
    var chunk: u64 = ptr[ptr.len - 1];
    const mask: usize = comptime @truncate(-2);
    duff: switch (ptr.len & mask) {
      inline 2, 4, 6 => |x| {
        const nx = comptime x - 2;
        chunk = (chunk << 16) | S.loadLe(u16, ptr[nx..]);
        continue :duff nx;
      },
      inline 0 => {},
      else => unreachable,
    }
    h = S.mix(h, chunk);
  }

  return S.mix(h, 0x13198a2e03707345);
}

pub fn stringMap(Value: type, kvs: anytype) fn ([]const u8) ?Value {
  const type_info = @typeInfo(@TypeOf(kvs));
  const fields = type_info.@"struct".fields;

  const S = struct {
    inline fn reduce(h: u64, range: u64) u64 {
      return ((h >> 32) * range) >> 32;
    }

    const table = table: {
      const table_size = fields.len * 3 / 2;
      var indices: [table_size]u32 = @splat(fields.len);
      var probes: [table_size]comptime_int = @splat(0);
      var max_probe = 0;

      for (fields, 0..) |field, i| {
        var h = reduce(hash(field.name), table_size);

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
        }

        indices[h] = index;
        probes[h] = probe;
        max_probe = @max(max_probe, probe);
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

    fn eql(a: []const u8, b: []const u8) bool {
      if (a.len != b.len) return false;

      for (a, b) |a_i, b_i| {
        if (a_i != b_i) return false;
      }

      return true;
    }

    fn get(key: []const u8) ?Value {
      const h = reduce(hash(key), table.size);
      inline for (0..table.max_probe + 1) |probe| {
        const l = table.indices[h + probe];
        const r = table.indices[h + probe + 1];

        if (eql(key, table.pool[l..r])) {
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
