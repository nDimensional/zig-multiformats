const std = @import("std");

const N1: u64 = 1 << 7;
const N2: u64 = 1 << 14;
const N3: u64 = 1 << 21;
const N4: u64 = 1 << 28;
const N5: u64 = 1 << 35;
const N6: u64 = 1 << 42;
const N7: u64 = 1 << 49;
const N8: u64 = 1 << 56;
const N9: u64 = 1 << 63;

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

    @panic("internal error - exceeded max byte length");
}

pub fn write(writer: *std.Io.Writer, val: u64) std.Io.Writer.Error!void {
    var i: usize = 0;
    var v = val;
    while (i <= MAX_BYTE_LENGTH) : (i += 1) {
        const byte = @as(u8, @truncate(v)) & REST;

        v >>= 7;
        if (v == 0) {
            try writer.writeByte(byte);
            return;
        } else {
            try writer.writeByte(byte | MSB);
            continue;
        }
    }

    @panic("internal error - exceeded max byte length");
}

pub const MAX_BYTE_LENGTH = 9;
pub const MAX_VALUE: u64 = 1 << 63;

pub fn decode(buf: []const u8, len: ?*usize) !usize {
    var val: u64 = 0;
    var shift: u6 = 0;
    var i: u8 = 0;
    while (i < MAX_BYTE_LENGTH) : (i += 1) {
        if (i >= buf.len) {
            return error.EOD;
        }

        val += @as(u64, @intCast(buf[i] & REST)) << shift;
        if (buf[i] & MSB == 0) {
            if (len) |ptr| ptr.* = i + 1;
            return val;
        } else {
            shift += 7;
        }
    }

    return error.InvalidValue;
}

pub fn read(reader: *std.Io.Reader) !u64 {
    var val: u64 = 0;
    var shift: u6 = 0;
    var i: u8 = 0;
    while (i < MAX_BYTE_LENGTH) : (i += 1) {
        const byte = try reader.takeByte();
        val += @as(u64, @intCast(byte & REST)) << shift;
        if (byte & MSB == 0) {
            return val;
        } else {
            shift += 7;
        }
    }

    return error.InvalidValue;
}
