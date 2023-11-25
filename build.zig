const std = @import("std");
const FileSource = std.build.FileSource;
const LazyPath = std.build.LazyPath;

pub fn build(b: *std.build.Builder) void {
    const multibase_tests = b.addTest(.{ .root_source_file = FileSource.relative("src/multibase/test.zig") });
    const run_multibase_tests = b.addRunArtifact(multibase_tests);
    b.step("test-multibase", "Run multibase tests").dependOn(&run_multibase_tests.step);

    const varint_tests = b.addTest(.{ .root_source_file = FileSource.relative("src/varint/test.zig") });
    const run_varint_tests = b.addRunArtifact(varint_tests);
    b.step("test-varint", "Run varint tests").dependOn(&run_varint_tests.step);

    const tests = b.step("test", "Run unit tests");
    tests.dependOn(&run_multibase_tests.step);
    tests.dependOn(&run_multibase_tests.step);
}
