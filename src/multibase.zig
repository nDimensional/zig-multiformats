const std = @import("std");

const rfc4648 = @import("rfc4648.zig");

// RFC 4648 family

pub const base2 = rfc4648.Base("01", 1);

pub const base8 = rfc4648.Base("01234567", 3);

pub const base16 = rfc4648.Base("0123456789abcdef", 4);
pub const base16upper = rfc4648.Base("0123456789ABCDEF", 4);

pub const base32 = rfc4648.Base("abcdefghijklmnopqrstuvwxyz234567", 5);
pub const base32upper = rfc4648.Base("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567", 5);
pub const base32pad = rfc4648.Base("abcdefghijklmnopqrstuvwxyz234567=", 5);
pub const base32padupper = rfc4648.Base("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567=", 5);

pub const base32hex = rfc4648.Base("0123456789abcdefghijklmnopqrstuv", 5);
pub const base32hexupper = rfc4648.Base("0123456789ABCDEFGHIJKLMNOPQRSTUV", 5);
pub const base32hexpad = rfc4648.Base("0123456789abcdefghijklmnopqrstuv=", 5);
pub const base32hexpadupper = rfc4648.Base("0123456789ABCDEFGHIJKLMNOPQRSTUV=", 5);

pub const base32z = rfc4648.Base("ybndrfg8ejkmcpqxot1uwisza345h769", 5);

pub const base64 = rfc4648.Base("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/", 6);
pub const base64pad = rfc4648.Base("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=", 6);
pub const base64url = rfc4648.Base("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_", 6);
pub const base64urlpad = rfc4648.Base("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_=", 6);

fn testEncode(comptime base: type, allocator: std.mem.Allocator, data: []const u8, expected: []const u8) !void {
    const actual = try base.baseEncode(allocator, data);
    defer allocator.free(actual);
    try std.testing.expectEqualSlices(u8, expected, actual);
}

test "base32 family" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    try testEncode(base32, allocator, "foo", "mzxw6");
    try testEncode(base32, allocator, "foobar", "mzxw6ytboi");
    try testEncode(base32, allocator, "hello world!", "nbswy3dpeb3w64tmmqqq");

    try testEncode(base32hex, allocator, "foo", "cpnmu");
    try testEncode(base32hex, allocator, "foobar", "cpnmuoj1e8");
    try testEncode(base32hex, allocator, "hello world!", "d1imor3f41rmusjccggg");

    try testEncode(base32pad, allocator, "foo", "mzxw6===");
    try testEncode(base32pad, allocator, "foobar", "mzxw6ytboi======");
    try testEncode(base32pad, allocator, "hello world!", "nbswy3dpeb3w64tmmqqq====");

    try testEncode(base32hexpadupper, allocator, "foo", "CPNMU===");
    try testEncode(base32hexpadupper, allocator, "foobar", "CPNMUOJ1E8======");
    try testEncode(base32hexpadupper, allocator, "hello world!", "D1IMOR3F41RMUSJCCGGG====");
}
