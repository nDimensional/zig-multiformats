const std = @import("std");

pub const Code = @import("code.zig").Code;

const rfc4648 = @import("rfc4648.zig");
const baseX = @import("baseX.zig");

// Base-X family

pub const base10 = baseX.Base(Code.base10, "0123456789");

pub const base36 = baseX.Base(Code.base36, "0123456789abcdefghijklmnopqrstuvwxyz");
pub const base36upper = baseX.Base(Code.base36upper, "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ");

pub const base58btc = baseX.Base(Code.base58btc, "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz");
pub const base58flickr = baseX.Base(Code.base58flickr, "123456789abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ");

// RFC 4648 family

pub const base2 = rfc4648.Base(Code.base2, "01", 1);

pub const base8 = rfc4648.Base(Code.base8, "01234567", 3);

pub const base16 = rfc4648.Base(Code.base16, "0123456789abcdef", 4);
pub const base16upper = rfc4648.Base(Code.base16upper, "0123456789ABCDEF", 4);

pub const base32 = rfc4648.Base(Code.base32, "abcdefghijklmnopqrstuvwxyz234567", 5);
pub const base32upper = rfc4648.Base(Code.base32upper, "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567", 5);
pub const base32pad = rfc4648.Base(Code.base32pad, "abcdefghijklmnopqrstuvwxyz234567=", 5);
pub const base32padupper = rfc4648.Base(Code.base32padupper, "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567=", 5);

pub const base32hex = rfc4648.Base(Code.base32hex, "0123456789abcdefghijklmnopqrstuv", 5);
pub const base32hexupper = rfc4648.Base(Code.base32hexupper, "0123456789ABCDEFGHIJKLMNOPQRSTUV", 5);
pub const base32hexpad = rfc4648.Base(Code.base32hexpad, "0123456789abcdefghijklmnopqrstuv=", 5);
pub const base32hexpadupper = rfc4648.Base(Code.base32hexpadupper, "0123456789ABCDEFGHIJKLMNOPQRSTUV=", 5);

pub const base32z = rfc4648.Base(Code.base32z, "ybndrfg8ejkmcpqxot1uwisza345h769", 5);

pub const base64 = rfc4648.Base(Code.base64, "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/", 6);
pub const base64pad = rfc4648.Base(Code.base64pad, "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=", 6);
pub const base64url = rfc4648.Base(Code.base64url, "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_", 6);
pub const base64urlpad = rfc4648.Base(Code.base64urlpad, "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_=", 6);

pub const Base = struct {
    code: Code,
    name: []const u8,

    writeAll: *const fn (writer: std.io.AnyWriter, bytes: []const u8) anyerror!void,

    encode: *const fn (allocator: std.mem.Allocator, bytes: []const u8) anyerror![]const u8,
    baseEncode: *const fn (allocator: std.mem.Allocator, bytes: []const u8) anyerror![]const u8,

    decode: *const fn (allocator: std.mem.Allocator, str: []const u8) anyerror![]const u8,
    baseDecode: *const fn (allocator: std.mem.Allocator, str: []const u8) anyerror![]const u8,

    pub fn init(comptime code: Code, comptime impl: type) Base {
        return .{
            .code = code,
            .name = @tagName(code),
            .writeAll = &impl.writeAll,
            .encode = &impl.encode,
            .baseEncode = &impl.baseEncode,
            .decode = &impl.decode,
            .baseDecode = &impl.baseDecode,
        };
    }
};

pub const bases: []const Base = &.{
    Base.init(Code.base10, base10),
    Base.init(Code.base36, base36),
    Base.init(Code.base36upper, base36upper),
    Base.init(Code.base58btc, base58btc),
    Base.init(Code.base58flickr, base58flickr),
    Base.init(Code.base2, base2),
    Base.init(Code.base8, base8),
    Base.init(Code.base16, base16),
    Base.init(Code.base16upper, base16upper),
    Base.init(Code.base32, base32),
    Base.init(Code.base32upper, base32upper),
    Base.init(Code.base32pad, base32pad),
    Base.init(Code.base32padupper, base32padupper),
    Base.init(Code.base32hex, base32hex),
    Base.init(Code.base32hexupper, base32hexupper),
    Base.init(Code.base32hexpad, base32hexpad),
    Base.init(Code.base32hexpadupper, base32hexpadupper),
    Base.init(Code.base32z, base32z),
    Base.init(Code.base64, base64),
    Base.init(Code.base64pad, base64pad),
    Base.init(Code.base64url, base64url),
    Base.init(Code.base64urlpad, base64urlpad),
};

pub fn decode(allocator: std.mem.Allocator, str: []const u8, code: ?*Code) ![]const u8 {
    if (str.len == 0) return error.END_OF_DATA;

    const prefix: u32 = @intCast(str[0]);
    for (bases) |base| {
        if (@intFromEnum(base.code) == prefix) {
            if (code) |ptr| ptr.* = base.code;
            return try base.baseDecode(allocator, str[1..]);
        }
    }

    return error.INVALID_MULTIBASE_PREFIX;
}

pub fn encode(allocator: std.mem.Allocator, bytes: []const u8, code: Code) ![]const u8 {
    for (bases) |base| {
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
