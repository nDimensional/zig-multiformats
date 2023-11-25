const std = @import("std");
const FileSource = std.build.FileSource;
const LazyPath = std.build.LazyPath;

pub fn build(b: *std.build.Builder) void {

    // Modules

    const varint = b.addModule("varint", .{ .source_file = LazyPath.relative("src/varint/lib.zig") });
    const multibase = b.addModule("multibase", .{ .source_file = LazyPath.relative("src/multibase/lib.zig") });

    // Tests

    const multibase_tests = b.addTest(.{ .root_source_file = FileSource.relative("src/multibase/test.zig") });
    multibase_tests.addModule("multibase", multibase);
    const run_multibase_tests = b.addRunArtifact(multibase_tests);
    b.step("test-multibase", "Run multibase tests").dependOn(&run_multibase_tests.step);

    const varint_tests = b.addTest(.{ .root_source_file = FileSource.relative("src/varint/test.zig") });
    varint_tests.addModule("varint", varint);
    const run_varint_tests = b.addRunArtifact(varint_tests);
    b.step("test-varint", "Run varint tests").dependOn(&run_varint_tests.step);

    const tests = b.step("test", "Run unit tests");
    tests.dependOn(&run_multibase_tests.step);
    tests.dependOn(&run_multibase_tests.step);
}
