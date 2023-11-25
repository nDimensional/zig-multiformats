const std = @import("std");

const multibase = @import("./lib.zig");

fn testEncode(comptime base: type, allocator: std.mem.Allocator, data: []const u8, expected: []const u8) !void {
    const actual = try base.baseEncode(allocator, data);
    defer allocator.free(actual);
    try std.testing.expectEqualSlices(u8, expected, actual);
}

test "base32 family" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer std.debug.assert(gpa.deinit() == .ok);

    try testEncode(multibase.base32, allocator, "foo", "mzxw6");
    try testEncode(multibase.base32, allocator, "foobar", "mzxw6ytboi");
    try testEncode(multibase.base32, allocator, "hello world!", "nbswy3dpeb3w64tmmqqq");

    try testEncode(multibase.base32hex, allocator, "foo", "cpnmu");
    try testEncode(multibase.base32hex, allocator, "foobar", "cpnmuoj1e8");
    try testEncode(multibase.base32hex, allocator, "hello world!", "d1imor3f41rmusjccggg");

    try testEncode(multibase.base32pad, allocator, "foo", "mzxw6===");
    try testEncode(multibase.base32pad, allocator, "foobar", "mzxw6ytboi======");
    try testEncode(multibase.base32pad, allocator, "hello world!", "nbswy3dpeb3w64tmmqqq====");

    try testEncode(multibase.base32hexpadupper, allocator, "foo", "CPNMU===");
    try testEncode(multibase.base32hexpadupper, allocator, "foobar", "CPNMUOJ1E8======");
    try testEncode(multibase.base32hexpadupper, allocator, "hello world!", "D1IMOR3F41RMUSJCCGGG====");
}

test "base58.baseEncode" {
    var arena = std.heap.ArenaAllocator.init(std.heap.c_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    try testEncode(multibase.base58btc, allocator, "", "");
    try testEncode(multibase.base58btc, allocator, &.{0}, "1");
    try testEncode(multibase.base58btc, allocator, &.{ 0, 0 }, "11");
    try testEncode(multibase.base58btc, allocator, &.{ 0, 0, 0, 0, 0 }, "11111");
    try testEncode(multibase.base58btc, allocator, &.{ 0, 0, 0, 0, 0, 1, 2, 3 }, "11111Ldp");

    try testEncode(multibase.base58btc, allocator, &.{ 0xff, 0xff }, "LUv");
    try testEncode(multibase.base58btc, allocator, &.{ 0, 0xff, 0xff }, "1LUv");
    try testEncode(multibase.base58btc, allocator, &.{ 0, 0, 0, 0xff, 0xff }, "111LUv");

    const buffer = try allocator.alloc(u8, 32);

    // 32 random bytes
    {
        const bytes = try std.fmt.hexToBytes(buffer, "e84b4b0c6a274b85f5b332101b0d65b08b006d122314efdef34c9d4f8a5091b0");
        try testEncode(multibase.base58btc, allocator, bytes, "GdnBBVHLm9D985m4VgvM5oGxdfRyZxMEnX4hFrDPgrGo");
    }

    // 29 random bytes
    {
        const bytes = try std.fmt.hexToBytes(buffer, "7898a2710dc30bde4ffea2cbe7a2b3c2b22cd72c9d6b49a35a9991a355");
        try testEncode(multibase.base58btc, allocator, bytes, "6UXvLinjzhDSV3Eydg7bdwtowT4syUfooaJivp5S");
    }

    // 25 random bytes
    {
        const bytes = try std.fmt.hexToBytes(buffer, "b4b4b8de99df9e2555b4d66686fa05cae0b37e94fb087e1983");
        try testEncode(multibase.base58btc, allocator, bytes, "2FiK9L35AZrLhp6DfNfRkbRHNam4ZixeBbG");
    }

    // 20 random bytes
    {
        const bytes = try std.fmt.hexToBytes(buffer, "3c5cb2605094b95ab80dbdc8d435e4e9719bb11f");
        try testEncode(multibase.base58btc, allocator, bytes, "qmwYyekSMj6VHfyhXmPtJdCiYZk");
    }
}

test "base58.baseDecode" {
    var arena = std.heap.ArenaAllocator.init(std.heap.c_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    try std.testing.expectEqualSlices(u8, &.{}, try multibase.base58btc.baseDecode(allocator, ""));
    try std.testing.expectEqualSlices(u8, &.{0}, try multibase.base58btc.baseDecode(allocator, "1"));
    try std.testing.expectEqualSlices(u8, &.{ 0, 0 }, try multibase.base58btc.baseDecode(allocator, "11"));
    try std.testing.expectEqualSlices(u8, &.{ 0, 0, 0, 0, 0 }, try multibase.base58btc.baseDecode(allocator, "11111"));
    try std.testing.expectEqualSlices(u8, &.{ 0, 0, 0, 0, 0, 1, 2, 3 }, try multibase.base58btc.baseDecode(allocator, "11111Ldp"));

    try std.testing.expectEqualSlices(u8, &.{ 0xff, 0xff }, try multibase.base58btc.baseDecode(allocator, "LUv"));
    try std.testing.expectEqualSlices(u8, &.{ 0, 0xff, 0xff }, try multibase.base58btc.baseDecode(allocator, "1LUv"));
    try std.testing.expectEqualSlices(u8, &.{ 0, 0, 0, 0xff, 0xff }, try multibase.base58btc.baseDecode(allocator, "111LUv"));

    const buffer = try allocator.alloc(u8, 32);

    // Fixtures

    // 32 random bytes
    try std.testing.expectEqualSlices(
        u8,
        try std.fmt.hexToBytes(buffer, "e84b4b0c6a274b85f5b332101b0d65b08b006d122314efdef34c9d4f8a5091b0"),
        try multibase.base58btc.baseDecode(allocator, "GdnBBVHLm9D985m4VgvM5oGxdfRyZxMEnX4hFrDPgrGo"),
    );

    // 29 random bytes
    try std.testing.expectEqualSlices(
        u8,
        try std.fmt.hexToBytes(buffer, "7898a2710dc30bde4ffea2cbe7a2b3c2b22cd72c9d6b49a35a9991a355"),
        try multibase.base58btc.baseDecode(allocator, "6UXvLinjzhDSV3Eydg7bdwtowT4syUfooaJivp5S"),
    );

    // 25 random bytes
    try std.testing.expectEqualSlices(
        u8,
        try std.fmt.hexToBytes(buffer, "b4b4b8de99df9e2555b4d66686fa05cae0b37e94fb087e1983"),
        try multibase.base58btc.baseDecode(allocator, "2FiK9L35AZrLhp6DfNfRkbRHNam4ZixeBbG"),
    );

    // 20 random bytes
    try std.testing.expectEqualSlices(
        u8,
        try std.fmt.hexToBytes(buffer, "3c5cb2605094b95ab80dbdc8d435e4e9719bb11f"),
        try multibase.base58btc.baseDecode(allocator, "qmwYyekSMj6VHfyhXmPtJdCiYZk"),
    );
}
