const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "yuku",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const lexer_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/lexer_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_lexer_tests = b.addRunArtifact(lexer_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_lexer_tests.step);

    const gen_unicode_id = b.addExecutable(.{
        .name = "generate-unicode-id-table",
        .root_module = b.createModule(.{
            .root_source_file = b.path("scripts/generate-unicode-id-table.zig"),
            .target = b.graph.host,
            .optimize = b.standardOptimizeOption(.{
                .preferred_optimize_mode = std.builtin.OptimizeMode.ReleaseFast,
            }),
        }),
    });
    const run_gen_unicode_id = b.addRunArtifact(gen_unicode_id);
    const gen_unicode_id_step = b.step("generate-unicode-id-table", "Run unicode identifier table generation");
    gen_unicode_id_step.dependOn(&run_gen_unicode_id.step);
}
