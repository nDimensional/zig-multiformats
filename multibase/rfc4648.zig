const std = @import("std");

const errors = @import("errors.zig");

pub const Code = @import("code.zig").Code;

const PAD = '=';

fn getBaseMap(comptime alphabet: []const u8) [256]u8 {
    var codes: [256]u8 = undefined;
    for (0..256) |char| codes[char] = 0xff;
    for (alphabet, 0..) |char, i| codes[char] = @intCast(i);
    return codes;
}

// https://github.com/multiformats/js-multiformats/blob/360a486dd4d13769ec1ea8b7843fb9552841fb4d/src/bases/base.js

pub fn Base(comptime code: Code, comptime alphabet: []const u8, comptime bits_per_char: u3) type {
    return struct {
        const prefix: []const u8 = &.{@intFromEnum(code)};
        const codes = getBaseMap(alphabet);

        pub inline fn getCode() Code {
            return code;
        }

        pub fn encode(allocator: std.mem.Allocator, bytes: []const u8) errors.EncodeError![]const u8 {
            var out = std.io.Writer.Allocating.init(allocator);
            errdefer out.deinit();

            try out.writer.writeByte(@intFromEnum(code));
            try writeAll(&out.writer, bytes);

            return try out.toOwnedSlice();
        }

        pub fn baseEncode(allocator: std.mem.Allocator, bytes: []const u8) errors.EncodeError![]const u8 {
            var out = std.io.Writer.Allocating.init(allocator);
            errdefer out.deinit();

            try writeAll(&out.writer, bytes);

            return try out.toOwnedSlice();
        }

        pub fn writeAll(writer: *std.io.Writer, bytes: []const u8) std.io.Writer.Error!void {
            // try writeBytes(writer, bytes, alphabet, bits_per_char);
            const pad = alphabet[alphabet.len - 1] == PAD;
            const mask = (@as(u8, 1) << bits_per_char) - 1;

            var char_count: usize = 0;

            var bits: u5 = 0; // Number of bits currently in the buffer
            var buffer: u32 = 0; // Bits waiting to be written out, MSB first
            var i: usize = 0;
            while (i < bytes.len) : (i += 1) {
                // Slurp data into the buffer:
                buffer = (buffer << 8) | bytes[i];
                bits += 8;

                // Write out as much as we can:
                while (bits > bits_per_char) {
                    bits -= bits_per_char;
                    try writer.writeByte(alphabet[mask & (buffer >> bits)]);
                    char_count += 1;
                }
            }

            // Partial character:
            if (bits > 0) {
                try writer.writeByte(alphabet[mask & (buffer << (bits_per_char - bits))]);
                char_count += 1;
            }

            // Add padding characters until we hit a byte boundary:
            if (pad) {
                while ((char_count * bits_per_char) & 7 > 0) {
                    try writer.writeByte(PAD);
                    char_count += 1;
                }
            }
        }

        /// Return a Formatter for a []const u8
        pub fn format(bytes: []const u8) std.fmt.Alt([]const u8, formatFn) {
            return .{ .data = bytes };
        }

        fn formatFn(bytes: []const u8, writer: *std.io.Writer) std.io.Writer.Error!void {
            try writeAll(writer, bytes);
        }

        pub fn decode(allocator: std.mem.Allocator, str: []const u8) ![]u8 {
            if (str.len < 1 or str[0] != @intFromEnum(code))
                return error.INVALID_MULTIBASE_PREFIX;

            return try baseDecode(allocator, str[1..]);
        }

        pub fn baseDecode(allocator: std.mem.Allocator, str: []const u8) ![]u8 {
            var end = str.len;
            while (end > 0 and str[end - 1] == PAD) end -= 1;

            const out = try allocator.alloc(u8, end * bits_per_char / 8);
            errdefer allocator.free(out);

            // Parse the data:
            var bits: u5 = 0; // Number of bits currently in the buffer
            var buffer: u32 = 0; // Bits waiting to be written out, MSB first
            var written: usize = 0; // Next byte to write

            for (str[0..end]) |char| {
                // Read one character from the string:
                const value = codes[char];
                if (value >= alphabet.len or alphabet[value] != char) {
                    return error.INVALID_CHARACTER;
                }

                // Append the bits to the buffer:
                buffer = (buffer << bits_per_char);
                buffer |= value;
                bits += bits_per_char;

                // Write out some bits if the buffer has a byte's worth:
                if (bits >= 8) {
                    bits -= 8;
                    out[written] = @truncate(buffer >> bits);
                    written += 1;
                }
            }

            // Verify that we have received just enough bits:
            if (bits >= bits_per_char or (0xff & (buffer << @intCast(8 - bits))) != 0) {
                return error.END_OF_DATA;
            }

            return out;
        }
    };
}
