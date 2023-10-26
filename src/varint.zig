const std = @import("std");

const N1 = @as(u64, 1 << 7);
const N2 = @as(u64, 1 << 14);
const N3 = @as(u64, 1 << 21);
const N4 = @as(u64, 1 << 28);
const N5 = @as(u64, 1 << 35);
const N6 = @as(u64, 1 << 42);
const N7 = @as(u64, 1 << 49);
const N8 = @as(u64, 1 << 56);
const N9 = @as(u64, 1 << 63);

pub fn encodingLength(val: u64) usize {
    if (val < N1) return 1;
    if (val < N2) return 2;
    if (val < N3) return 3;
    if (val < N4) return 4;
    if (val < N5) return 5;
    if (val < N6) return 6;
    if (val < N7) return 7;
    if (val < N8) return 8;
    if (val < N9) return 9;
    return 10;
}

const REST = @as(u8, 0x7F);
const MSB = @as(u8, 0x80);

pub fn encode(buf: []u8, val: u64) usize {
    var i: usize = 0;
    var v = val;
    while (i <= MAX_BYTE_LENGTH) : (i += 1) {
        buf[i] = @as(u8, @truncate(v)) & REST;
        v >>= 7;
        if (v == 0) {
            return i + 1;
        } else {
            buf[i] |= MSB;
        }
    }

    @panic("insufficient space in buffer");
}

pub const DecodeResult = struct { val: u64, len: usize };

pub const MAX_BYTE_LENGTH = 9;
pub const MAX_VALUE: u64 = 1 << 63;

pub fn decode(buf: []const u8) !DecodeResult {
    var val: u64 = 0;
    var shift: u6 = 0;
    var i: u8 = 0;
    while (i < MAX_BYTE_LENGTH) : (i += 1) {
        val += @as(u64, @intCast(buf[i] & REST)) << shift;
        if (buf[i] & MSB == 0) {
            return .{ .val = val, .len = i + 1 };
        } else {
            shift += 7;
        }
    }

    return error.InvalidValue;
}

// test "encode and decode" {
//     var buf: [MAX_BYTE_LENGTH]u8 = undefined;

//     var val: u64 = 0;
//     while (val < MAX_VALUE) : (val += 1) {
//         const len = encode(&buf, val);
//         try std.testing.expectEqual(encodingLength(val), len);
//         const result = try decode(&buf);
//         try std.testing.expectEqual(encodingLength(val), result.len);
//         try std.testing.expectEqual(val, result.val);
//     }
// }
