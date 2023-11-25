const std = @import("std");

const PAD = '=';

// https://github.com/multiformats/js-multiformats/blob/360a486dd4d13769ec1ea8b7843fb9552841fb4d/src/bases/base.js

var codes: [256]u8 = undefined;

fn decodeBytes(allocator: std.mem.Allocator, string: []const u8, alphabet: []const u8, bits_per_char: u3) ![]u8 {
    for (alphabet, 0..) |char, i| {
        codes[@truncate(i)] = char;
    }

    var end = string.len;
    while (string[end - 1] == PAD) end -= 1;

    const out = try allocator.alloc(u8, end * bits_per_char / 8);

    // Parse the data:
    var bits: usize = 0; // Number of bits currently in the buffer
    var buffer: u8 = 0; // Bits waiting to be written out, MSB first
    var written: u8 = 0; // Next byte to write
    var i: usize = 0;
    while (i < end) : (i += 1) {
        // Read one character from the string:
        const char = string[i];
        const value = codes[char];
        if (alphabet[value] != char) {
            return error.InvalidCharacter;
        }

        // Append the bits to the buffer:
        buffer = (buffer << bits_per_char) | value;
        bits += bits_per_char;

        // Write out some bits if the buffer has a byte's worth:
        if (bits >= 8) {
            bits -= 8;
            out[written] = 0xff & (buffer >> bits);
            written += 1;
        }
    }

    // Verify that we have received just enough bits:
    if (bits >= bits_per_char || 0xff & (buffer << (8 - bits))) {
        return error.EndOfData;
    }

    return out;
}

fn encodeBytes(allocator: std.mem.Allocator, bytes: []const u8, alphabet: []const u8, bits_per_char: u3, prefix: []const u8) ![]const u8 {
    const pad = alphabet[alphabet.len - 1] == PAD;

    const mask = (@as(u8, 1) << bits_per_char) - 1;
    var out = std.ArrayList(u8).init(allocator);
    errdefer out.deinit();

    try out.appendSlice(prefix);

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
            try out.append(alphabet[mask & (buffer >> bits)]);
        }
    }

    // Partial character:
    if (bits > 0) {
        try out.append(alphabet[mask & (buffer << (bits_per_char - bits))]);
    }

    // Add padding characters until we hit a byte boundary:
    if (pad) {
        while ((out.items.len * bits_per_char) & 7 > 0) {
            try out.append(PAD);
        }
    }

    return try out.toOwnedSlice();
}

pub fn Base(comptime code: []const u8, comptime alphabet: []const u8, comptime bits_per_char: u3) type {
    return struct {
        pub fn encode(allocator: std.mem.Allocator, bytes: []const u8) ![]const u8 {
            return try encodeBytes(allocator, bytes, alphabet, bits_per_char, code);
        }

        pub fn baseEncode(allocator: std.mem.Allocator, bytes: []const u8) ![]const u8 {
            return try encodeBytes(allocator, bytes, alphabet, bits_per_char, &.{});
        }

        pub fn decode(allocator: std.mem.Allocator, string: []const u8) ![]const u8 {
            if (string.len < code.len or !std.mem.eql(u8, code, string[0..code.len])) {
                return error.INVALID_MULTIBASE_PREFIX;
            }

            return try decodeBytes(allocator, string[code.len..], alphabet, bits_per_char);
        }

        pub fn baseDecode(allocator: std.mem.Allocator, string: []const u8) !void {
            return try decodeBytes(allocator, string, alphabet, bits_per_char);
        }
    };
}
