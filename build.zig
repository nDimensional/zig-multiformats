const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Modules

    const varint = b.addModule("varint", .{
        .root_source_file = b.path("varint/lib.zig"),
    });

    const multibase = b.addModule("multibase", .{
        .root_source_file = b.path("multibase/lib.zig"),
    });

    const multicodec = b.addModule("multicodec", .{
        .root_source_file = b.path("multicodec/lib.zig"),
        .imports = &.{
            .{ .name = "varint", .module = varint },
        },
    });

    const multihash = b.addModule("multihash", .{
        .root_source_file = b.path("multihash/lib.zig"),
        .imports = &.{
            .{ .name = "varint", .module = varint },
            .{ .name = "multibase", .module = multibase },
            .{ .name = "multicodec", .module = multicodec },
        },
    });

    const cid = b.addModule("cid", .{
        .root_source_file = b.path("cid/lib.zig"),
        .imports = &.{
            .{ .name = "varint", .module = varint },
            .{ .name = "multibase", .module = multibase },
            .{ .name = "multicodec", .module = multicodec },
            .{ .name = "multihash", .module = multihash },
        },
    });

    // Tests

    const varint_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .root_source_file = b.path("varint/test.zig"),
            .imports = &.{
                .{ .name = "varint", .module = varint },
            },
        }),
    });

    const run_varint_tests = b.addRunArtifact(varint_tests);
    b.step("test-varint", "Run varint tests").dependOn(&run_varint_tests.step);

    const multibase_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .root_source_file = b.path("multibase/test.zig"),
            .imports = &.{
                .{ .name = "multibase", .module = multibase },
            },
        }),
    });

    const run_multibase_tests = b.addRunArtifact(multibase_tests);
    b.step("test-multibase", "Run multibase tests").dependOn(&run_multibase_tests.step);

    const multihash_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .root_source_file = b.path("multihash/test.zig"),
            .imports = &.{
                .{ .name = "multihash", .module = multihash },
            },
        }),
    });

    const run_multihash_tests = b.addRunArtifact(multihash_tests);
    b.step("test-multihash", "Run multihash tests").dependOn(&run_multihash_tests.step);

    const cid_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .root_source_file = b.path("cid/test.zig"),
            .imports = &.{
                .{ .name = "cid", .module = cid },
                .{ .name = "multicodec", .module = multicodec },
            },
        }),
    });

    const run_cid_tests = b.addRunArtifact(cid_tests);
    b.step("test-cid", "Run cid tests").dependOn(&run_cid_tests.step);

    const tests = b.step("test", "Run unit tests");
    tests.dependOn(&run_varint_tests.step);
    tests.dependOn(&run_multibase_tests.step);
    tests.dependOn(&run_multihash_tests.step);
    tests.dependOn(&run_cid_tests.step);
}
