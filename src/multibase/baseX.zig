const std = @import("std");

fn getBaseMap(comptime alphabet: []const u8) [256]u8 {
    var base_map: [256]u8 = undefined;
    for (&base_map) |*byte| byte.* = 0xff;
    for (alphabet, 0..) |char, i| base_map[char] = i;
    return base_map;
}

pub fn Base(comptime code: []const u8, comptime alphabet: []const u8) type {
    const leader = alphabet[0];

    const factor: f64 = @log(@as(f64, alphabet.len)) / @log(@as(f64, 256));
    const i_factor: f64 = @log(@as(f64, 256)) / @log(@as(f64, alphabet.len));

    const base_map = getBaseMap(alphabet);

    return struct {
        const Self = @This();

        pub fn encode(allocator: std.mem.Allocator, source: []const u8) ![]const u8 {
            return try prefixEncode(allocator, source, code);
        }

        pub fn baseEncode(allocator: std.mem.Allocator, source: []const u8) ![]const u8 {
            return try prefixEncode(allocator, source, &.{});
        }

        fn prefixEncode(allocator: std.mem.Allocator, source: []const u8, prefix: []const u8) ![]const u8 {
            if (source.len == 0) {
                return try allocator.alloc(u8, 0);
            }

            // Skip & count leading zeroes.
            var zeroes: usize = 0;
            var length: usize = 0;
            var pbegin: usize = 0;
            var pend: usize = source.len;

            while (pbegin != pend and source[pbegin] == 0) {
                pbegin += 1;
                zeroes += 1;
            }

            // Allocate enough space in big-endian base58 representation.
            const size: usize = @intFromFloat((@as(f64, @floatFromInt(pend - pbegin)) * i_factor + 1));
            const buffer = try allocator.alloc(u8, size);
            defer allocator.free(buffer);

            for (buffer) |*char| char.* = 0;

            // Process the bytes.
            while (pbegin != pend) {
                var carry: u32 = source[pbegin];

                // Apply "buffer = buffer * 256 + ch".
                var i: usize = 0;
                var it1 = size - 1;
                while ((carry != 0 or i < length)) {
                    carry += (256 * @as(u32, buffer[it1]));
                    buffer[it1] = @intCast(carry % @as(u32, @intCast(alphabet.len)));
                    carry = (carry / @as(u32, @intCast(alphabet.len)));

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
                pbegin += 1;
            }

            // Skip leading zeroes in base-X result.
            var it2 = size - length;
            while (it2 != size and buffer[it2] == 0) {
                it2 += 1;
            }

            // Translate the result into a string.
            const str = try allocator.alloc(u8, prefix.len + zeroes + (size - it2));
            @memcpy(str[0..prefix.len], prefix);
            for (str[prefix.len..], 0..) |*char, i| {
                if (i < zeroes) {
                    char.* = leader;
                } else if (it2 < buffer.len) {
                    char.* = alphabet[buffer[it2]];
                    it2 += 1;
                } else {
                    @panic("index out of range");
                }
            }

            return str;
        }

        pub fn decode(allocator: std.mem.Allocator, source: []const u8) ![]const u8 {
            if (source.len < code.len or !std.mem.eql(u8, code, source[0..code.len])) {
                return error.INVALID_MULTIBASE_PREFIX;
            }

            return try baseDecode(allocator, source[code.len..]);
        }

        pub fn baseDecode(allocator: std.mem.Allocator, source: []const u8) ![]const u8 {
            var psz: usize = 0;

            var zeroes: usize = 0;
            var length: usize = 0;
            while (psz < source.len and source[psz] == leader) {
                zeroes += 1;
                psz += 1;
            }

            if (psz == source.len) {
                const bytes = try allocator.alloc(u8, zeroes);
                for (bytes) |*byte| byte.* = 0;
                return bytes;
            }

            // Allocate enough space in big-endian base256 representation.
            const size: usize = @intFromFloat(@as(f64, @floatFromInt(source.len - psz)) * factor + 1);
            const buffer = try allocator.alloc(u8, size);
            defer allocator.free(buffer);

            for (buffer) |*char| char.* = 0;

            // Process the characters.
            while (psz < source.len) : (psz += 1) {
                // Decode character
                var carry: u32 = base_map[source[psz]];

                if (carry == 0xFF) {
                    return error.INVALID_CHARACTER;
                }

                var i: usize = 0;
                var it3: usize = size - 1;
                while (carry != 0 or i < length) {
                    carry += @as(u32, @intCast(alphabet.len)) * @as(u32, buffer[it3]);
                    buffer[it3] = @intCast(carry % 256);
                    carry = carry / 256;
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
