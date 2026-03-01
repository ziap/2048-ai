const std = @import("std");

pub fn build(b: *std.Build) void {
  const target = b.standardTargetOptions(.{});
  const optimize = b.standardOptimizeOption(.{});
  const strip = optimize == .ReleaseFast or optimize == .ReleaseSmall;

  const engine = b.addModule("engine", .{
    .root_source_file = b.path("src/engine/main.zig"),
  });

  const main_exe = b.addExecutable(.{
    .name = "2048",
    .root_module = b.createModule(.{
      .root_source_file = b.path("src/cli/main.zig"),
      .target = target,
      .optimize = optimize,
      .strip = strip,
      .imports = &.{
        .{
          .name = "engine",
          .module = engine,
        },
      },
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

  const wasm_target = b.resolveTargetQuery(.{
    .cpu_arch = .wasm32,
    .os_tag = .freestanding,
    .cpu_features_add = std.Target.wasm.featureSet(&.{
      .atomics,
      .bulk_memory,
      .extended_const,
      .multivalue,
      .nontrapping_fptoint,
      .sign_ext,
      .simd128,
      .tail_call,
    }),
  });

  const wasm_main = b.addExecutable(.{
    .name = "main",
    .root_module = b.createModule(.{
      .root_source_file = b.path("src/wasm/main.zig"),
      .target = wasm_target,
      .optimize = optimize,
      .strip = strip,
      .imports = &.{
        .{
          .name = "engine",
          .module = engine,
        },
      },
    }),
  });

  wasm_main.rdynamic = true;
  wasm_main.entry = .disabled;
  const bin = wasm_main.getEmittedBin();
  const artifact = b.addInstallFile(bin, "main.wasm");

  b.getInstallStep().dependOn(&artifact.step);
}
