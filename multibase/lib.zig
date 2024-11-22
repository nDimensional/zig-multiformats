const std = @import("std");

pub const Code = @import("code.zig").Code;

const rfc4648 = @import("rfc4648.zig");
const baseX = @import("baseX.zig");

pub const Base = struct {
    code: Code,
    name: []const u8,
    impl: type,

    pub fn writeAll(self: Base, writer: std.io.AnyWriter, bytes: []const u8) anyerror!void {
        try self.impl.writeAll(writer, bytes);
    }

    pub fn encode(self: Base, allocator: std.mem.Allocator, bytes: []const u8) anyerror![]const u8 {
        return try self.impl.encode(allocator, bytes);
    }

    pub fn baseEncode(self: Base, allocator: std.mem.Allocator, bytes: []const u8) anyerror![]const u8 {
        return try self.impl.baseEncode(allocator, bytes);
    }

    pub fn decode(self: Base, allocator: std.mem.Allocator, str: []const u8) anyerror![]const u8 {
        return try self.impl.decode(allocator, str);
    }

    pub fn baseDecode(self: Base, allocator: std.mem.Allocator, str: []const u8) anyerror![]const u8 {
        return try self.impl.baseDecode(allocator, str);
    }
};


fn initBase(comptime impl: type) Base {
    const code = impl.getCode();
    return .{ .code = code, .name = @tagName(code), .impl = impl };
}

// Base-X family

pub const base10 = initBase(baseX.Base(.base10, "0123456789"));

pub const base36 = initBase(baseX.Base(.base36, "0123456789abcdefghijklmnopqrstuvwxyz"));
pub const base36upper = initBase(baseX.Base(.base36upper, "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"));

pub const base58btc = initBase(baseX.Base(.base58btc, "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"));
pub const base58flickr = initBase(baseX.Base(.base58flickr, "123456789abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ"));

// RFC 4648 family

pub const base2 = initBase(rfc4648.Base(.base2, "01", 1));

pub const base8 = initBase(rfc4648.Base(.base8, "01234567", 3));

pub const base16 = initBase(rfc4648.Base(.base16, "0123456789abcdef", 4));
pub const base16upper = initBase(rfc4648.Base(.base16upper, "0123456789ABCDEF", 4));

pub const base32 = initBase(rfc4648.Base(.base32, "abcdefghijklmnopqrstuvwxyz234567", 5));
pub const base32upper = initBase(rfc4648.Base(.base32upper, "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567", 5));
pub const base32pad = initBase(rfc4648.Base(.base32pad, "abcdefghijklmnopqrstuvwxyz234567=", 5));
pub const base32padupper = initBase(rfc4648.Base(.base32padupper, "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567=", 5));

pub const base32hex = initBase(rfc4648.Base(.base32hex, "0123456789abcdefghijklmnopqrstuv", 5));
pub const base32hexupper = initBase(rfc4648.Base(.base32hexupper, "0123456789ABCDEFGHIJKLMNOPQRSTUV", 5));
pub const base32hexpad = initBase(rfc4648.Base(.base32hexpad, "0123456789abcdefghijklmnopqrstuv=", 5));
pub const base32hexpadupper = initBase(rfc4648.Base(.base32hexpadupper, "0123456789ABCDEFGHIJKLMNOPQRSTUV=", 5));

pub const base32z = initBase(rfc4648.Base(.base32z, "ybndrfg8ejkmcpqxot1uwisza345h769", 5));

pub const base64 = initBase(rfc4648.Base(.base64, "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/", 6));
pub const base64pad = initBase(rfc4648.Base(.base64pad, "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=", 6));
pub const base64url = initBase(rfc4648.Base(.base64url, "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_", 6));
pub const base64urlpad = initBase(rfc4648.Base(.base64urlpad, "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_=", 6));

pub const bases: []const Base = &.{
    base10,
    base36,
    base36upper,
    base58btc,
    base58flickr,
    base2,
    base8,
    base16,
    base16upper,
    base32,
    base32upper,
    base32pad,
    base32padupper,
    base32hex,
    base32hexupper,
    base32hexpad,
    base32hexpadupper,
    base32z,
    base64,
    base64pad,
    base64url,
    base64urlpad,
};

pub const DecodeResult = struct {
    code: Code,
    data: []const u8,
};

pub fn decode(allocator: std.mem.Allocator, str: []const u8) !DecodeResult {
    if (str.len == 0) return error.END_OF_DATA;

    const prefix: u32 = @intCast(str[0]);
    inline for (bases) |base| {
        if (@intFromEnum(base.code) == prefix) {
            const data = try base.baseDecode(allocator, str[1..]);
            return .{ .code = base.code, .data = data};
        }
    }

    return error.INVALID_MULTIBASE_PREFIX;
}

pub fn encode(allocator: std.mem.Allocator, bytes: []const u8, code: Code) ![]const u8 {
    inline for (bases) |base| {
        if (base.code == code) {
            return try base.encode(allocator, bytes);
        }
    }

    @panic("invalid multibase code");
}

pub fn writeAll(writer: std.io.AnyWriter, bytes: []const u8, code: Code, prefix: bool) !void {
    for (bases) |base| {
        if (base.code == code) {
            if (prefix) {
                try writer.writeByte(@intFromEnum(code));
            }
            return try base.writeAll(writer, bytes);
        }
    }
}
