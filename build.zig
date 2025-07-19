const std = @import("std");

const Board = struct {
  data: u64,
};

pub fn build(b: *std.Build) void {
  const target = b.standardTargetOptions(.{});
  const optimize = b.standardOptimizeOption(.{});
  const strip = optimize == .ReleaseFast or optimize == .ReleaseSmall;

  const game_exe = b.addExecutable(.{
    .name = "game",
    .root_source_file = b.path("src/game.zig"),
    .target = target,
    .optimize = optimize,
    .strip = strip,
  });

  b.installArtifact(game_exe);

  const game_cmd = b.addRunArtifact(game_exe);
  game_cmd.step.dependOn(b.getInstallStep());

  if (b.args) |args| {
    game_cmd.addArgs(args);
  }

  const game_run = b.step("run-game", "Run the game");
  game_run.dependOn(&game_cmd.step);

  const main_exe = b.addExecutable(.{
    .name = "main",
    .root_source_file = b.path("src/main.zig"),
    .target = target,
    .optimize = optimize,
    .strip = strip,
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
