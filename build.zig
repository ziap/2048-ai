const std = @import("std");

pub fn build(b: *std.Build) void {
  const target = b.standardTargetOptions(.{});
  const optimize = b.standardOptimizeOption(.{});
  const strip = optimize == .ReleaseFast or optimize == .ReleaseSmall;

  const main_exe = b.addExecutable(.{
    .name = "main",
    .root_module = b.createModule(.{
      .root_source_file = b.path("src/main.zig"),
      .target = target,
      .optimize = optimize,
      .strip = strip,
    }),
  });

  b.installArtifact(main_exe);

  const main_cmd = b.addRunArtifact(main_exe);
  main_cmd.step.dependOn(b.getInstallStep());

  if (b.args) |args| {
    main_cmd.addArgs(args);
  }

  const main_run = b.step("run", "Run the main application");
  main_run.dependOn(&main_cmd.step);
}
