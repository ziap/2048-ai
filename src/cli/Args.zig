const Args = @This();

const Param = enum {
  iterations,
  budget,
  threads,
  help,
  seed,
};

const Seed = struct {
  static: ?u256,
  dynamic: []const u8,

  fn parse(input: ?[]const u8) !Seed {
    if (input) |dynamic| {
      return .{
        .static = std.fmt.parseUnsigned(u256, dynamic, 0) catch null,
        .dynamic = dynamic,
      };
    } else {
      var seed: u256 = undefined;
      try std.posix.getrandom(@ptrCast(&seed));
      return .{
        .static = seed,
        .dynamic = "",
      };
    }
  }

  pub fn toRng(self: Seed) Fmc256 {
    if (self.static) |seed| {
      return .fromSeed(Fmc256.toParts(seed));
    } else {
      return .fromBytes(self.dynamic);
    }
  }
};

const paramMap = stringMap.StringMap(Param).init(.{
  .@"--iter" = .iterations,
  .@"--budget" = .budget,
  .@"--threads" = .threads,
  .@"--seed" = .seed,
  .@"--help" = .help,

  .@"-i" = .iterations,
  .@"-b" = .budget,
  .@"-t" = .threads,
  .@"-s" = .seed,
  .@"-h" = .help,
});

iterations: u32,
budget: u32,
threads: u32,
seed: Seed,

fn getValue(arg: []const u8, iter: *std.process.ArgIterator, writer: *std.Io.Writer) ![]const u8 {
  return iter.next() orelse {
    try writer.print("Error: Missing value for parameter '{s}'\n", .{ arg });
    try writer.flush();
    return error.MissingParameterValue;
  };
}

fn getU32(arg: []const u8, iter: *std.process.ArgIterator, writer: *std.Io.Writer) !u32 {
  const value = try getValue(arg, iter, writer);

  const uint = std.fmt.parseUnsigned(u32, value, 10) catch |e| {
    try writer.print("Error: Invalid value '{s}' for parameter '{s}'", .{ value, arg });
    try writer.flush();
    return e;
  };

  return uint;
}

pub fn parse(allocator: std.mem.Allocator) !Args {
  var buffer: [4096]u8 = undefined;
  var stderr = std.fs.File.stderr().writer(&buffer);
  const writer = &stderr.interface;

  var args = try std.process.argsWithAllocator(allocator);
  if (!args.skip()) return error.NoProgramName;

  var iterations: u32 = 1;
  var budget: u32 = 1 << 19;
  var threads: ?u32 = null;
  var seed_input: ?[]const u8 = null;

  while (args.next()) |arg| {
    if (paramMap.get(arg)) |param| {
      switch (param) {
        .iterations => iterations = try getU32(arg, &args, writer),
        .budget => budget = try getU32(arg, &args, writer),
        .threads => threads = try getU32(arg, &args, writer),
        .seed => seed_input = try getValue(arg, &args, writer),
        .help => {
          try writer.print(
            (
              \\Usage: 2048 [options]
              \\
              \\Options:
              \\  -i, --iter <u32>     Number of iterations (default: 1)
              \\  -b, --budget <u32>   Processing budget (default: 524288)
              \\  -t, --threads <u32>  Number of threads (default: auto)
              \\  -s, --seed <bytes>   Seed for the PRNG (default: random)
              \\  -h, --help           Display this help message
              \\
            ), .{}
          );
          try writer.flush();
          return error.HelpIssued;
        },
      }
    } else {
      try writer.print("Error: Unknown parameter '{s}'\n", .{ arg });
      try writer.flush();
      return error.UnknownParameter;
    }
  }

  return .{
    .iterations = iterations,
    .budget = budget,
    .seed = try .parse(seed_input),
    .threads = @max(1, @min(
      threads orelse @as(u32, @intCast(try std.Thread.getCpuCount())),
      iterations,
    )),
  };
}

pub fn display(self: Args, writer: *std.Io.Writer) !void {
  try writer.writeAll("================== CONFIGURATION =================\n");
  try writer.print("Iterations : {d}\n", .{ self.iterations });
  try writer.print("Budget     : {d}\n", .{ self.budget });
  try writer.print("Threads    : {d}\n", .{ self.threads });

  if (self.seed.static) |s| {
    if (self.seed.dynamic.len == 0) {
      // Case 1: Randomly generated seed (print the number in hex)
      try writer.print("Seed:      : 0x{x}\n", .{ s });
    } else {
      // Case 2: User provided a numeric string
      try writer.print("Seed:      : {s}\n", .{ self.seed.dynamic });
    }
  } else {
    // Case 3: User provided a byte string (non-numeric)
    try writer.print("Seed:      : \"{s}\"\n", .{ self.seed.dynamic });
  }

  try writer.writeAll("==================================================\n\n");
  try writer.flush();
}

const std = @import("std");
const stringMap = @import("stringMap.zig");

const engine = @import("engine");
const Fmc256 = engine.Fmc256;

