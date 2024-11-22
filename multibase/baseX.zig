const std = @import("std");
const Code = @import("code.zig").Code;

fn getBaseMap(comptime alphabet: []const u8) [256]u8 {
    var base_map: [256]u8 = undefined;
    for (&base_map) |*byte| byte.* = 0xff;
    for (alphabet, 0..) |char, i| base_map[char] = i;
    return base_map;
}

pub fn Base(comptime code: Code, comptime alphabet: []const u8) type {
    const leader = alphabet[0];
    const alphabet_len: u32 = @intCast(alphabet.len);

    const factor: comptime_float = @log(@as(f64, alphabet.len)) / @log(@as(f64, 256));
    const i_factor: comptime_float = @log(@as(f64, 256)) / @log(@as(f64, alphabet.len));

    const base_map = getBaseMap(alphabet);

    const max_byte_len: comptime_int = 256;
    const max_buffer_size: comptime_int = @intFromFloat((@as(f64, @floatFromInt(max_byte_len)) * i_factor + 1));

    return struct {
        const Self = @This();
        const prefix: []const u8 = &.{@intFromEnum(code)};

        threadlocal var buffer: [max_buffer_size]u8 = undefined;

        pub inline fn getCode() Code {
            return code;
        }

        pub fn encode(allocator: std.mem.Allocator, bytes: []const u8) ![]const u8 {
            if (bytes.len > max_byte_len) {
                return error.MAX_LENGTH;
            }

            var out = std.ArrayList(u8).init(allocator);
            errdefer out.deinit();

            var writer = out.writer();
            try writer.writeByte(@intFromEnum(code));
            try writeAll(writer.any(), bytes);

            return try out.toOwnedSlice();
        }

        pub fn baseEncode(allocator: std.mem.Allocator, bytes: []const u8) ![]const u8 {
            if (bytes.len > max_byte_len) {
                return error.MAX_LENGTH;
            }

            var out = std.ArrayList(u8).init(allocator);
            errdefer out.deinit();

            var writer = out.writer();
            try writeAll(writer.any(), bytes);

            return try out.toOwnedSlice();
        }

        pub fn writeAll(writer: std.io.AnyWriter, bytes: []const u8) !void {
            try writeAllImpl(writer, bytes);
        }

        fn writeAllImpl(writer: anytype, bytes: []const u8) !void {
            if (bytes.len == 0) {
                return;
            }

            // Skip & count leading zeroes.

            var length: usize = 0;
            var pbegin: usize = 0;
            const pend: usize = bytes.len;

            while (pbegin < pend and bytes[pbegin] == 0) pbegin += 1;

            const zeroes = pbegin;

            // Allocate enough space in big-endian base58 representation.
            const size: usize = @intFromFloat((@as(f64, @floatFromInt(pend - pbegin)) * i_factor + 1));
            // const buffer = try allocator.alloc(u8, size);
            // defer allocator.free(buffer);

            const b = buffer[0..size];
            for (b) |*char| char.* = 0;

            // Process the bytes.
            while (pbegin < pend) : (pbegin += 1) {
                var carry: u32 = bytes[pbegin];

                // Apply "buffer = buffer * 256 + ch".
                var i: usize = 0;
                var it1 = size - 1;
                while ((carry != 0 or i < length)) {
                    carry += (256 * @as(u32, b[it1]));
                    b[it1] = @intCast(carry % alphabet_len);
                    carry = (carry / alphabet_len);

                    i += 1;
                    if (it1 > 0) {
                        it1 -= 1;
                    } else {
                        break;
                    }
                }

                if (carry != 0) {
                    @panic("Non-zero carry");
                }

                length = i;
            }

            // Skip leading zeroes in base-X result.
            var it2 = size - length;
            while (it2 != size and buffer[it2] == 0) {
                it2 += 1;
            }

            // Translate the result into a string.
            // const str = try allocator.alloc(u8, zeroes + (size - it2));
            try writer.writeByteNTimes(leader, zeroes);

            for (0..(size - it2)) |_| {
                if (it2 < b.len) {
                    try writer.writeByte(alphabet[b[it2]]);
                    it2 += 1;
                } else {
                    @panic("index out of range");
                }
            }
        }

        /// Return a Formatter for a []const u8
        pub fn format(bytes: []const u8) std.fmt.Formatter(formatImpl) {
            return .{ .data = bytes };
        }

        fn formatImpl(
            bytes: []const u8,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = fmt;
            _ = options;

            try writeAllImpl(writer, bytes);
        }

        pub fn decode(allocator: std.mem.Allocator, str: []const u8) ![]const u8 {
            if (str.len < 1 or str[0] != @intFromEnum(code)) {
                return error.INVALID_MULTIBASE_PREFIX;
            }

            return try baseDecode(allocator, str[@sizeOf(Code)..]);
        }

        pub fn baseDecode(allocator: std.mem.Allocator, str: []const u8) ![]const u8 {
            var psz: usize = 0;

            var zeroes: usize = 0;
            var length: usize = 0;
            while (psz < str.len and str[psz] == leader) {
                zeroes += 1;
                psz += 1;
            }

            if (psz == str.len) {
                const bytes = try allocator.alloc(u8, zeroes);
                for (bytes) |*byte| byte.* = 0;
                return bytes;
            }

            // Allocate enough space in big-endian base256 representation.
            const size: usize = @intFromFloat(@as(f64, @floatFromInt(str.len - psz)) * factor + 1);
            if (size > max_byte_len) {
                return error.MAX_LENGTH;
            }

            for (&buffer) |*char| char.* = 0;

            // Process the characters.
            while (psz < str.len) : (psz += 1) {
                // Decode character
                var carry: u32 = base_map[str[psz]];

                if (carry == 0xFF) {
                    return error.INVALID_CHARACTER;
                }

                var i: usize = 0;
                var it3: usize = size - 1;
                while (carry != 0 or i < length) {
                    carry += alphabet_len * @as(u32, buffer[it3]);
                    buffer[it3] = @truncate(carry % 256);
                    carry /= 256;
                    i += 1;
                    if (it3 > 0) {
                        it3 -= 1;
                    } else {
                        break;
                    }
                }

                if (carry != 0) {
                    return error.NON_ZERO_CARRY;
                }

                length = i;
            }

            // Skip leading zeroes in buffer.
            var it4 = size - length;
            while (it4 != size and buffer[it4] == 0) {
                it4 += 1;
            }

            const bytes = try allocator.alloc(u8, zeroes + (size - it4));
            for (bytes, 0..) |*byte, j| {
                if (j < zeroes) {
                    byte.* = 0;
                } else {
                    byte.* = buffer[it4];
                    it4 += 1;
                }
            }

            return bytes;
        }
    };
}
