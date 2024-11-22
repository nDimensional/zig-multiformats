const std = @import("std");

const varint = @import("varint");

var buf: [varint.MAX_BYTE_LENGTH]u8 = undefined;

fn roundTripValue(val: u64) !void {
    const len = varint.encode(&buf, val);
    try std.testing.expectEqual(varint.encodingLength(val), len);
    var result_len: u64 = 0;
    try std.testing.expectEqual(val, try varint.decode(&buf, &result_len));
    try std.testing.expectEqual(varint.encodingLength(val), result_len);
}

fn testWrite(val: u64) !void {
    var stream = std.io.fixedBufferStream(&buf);
    try varint.write(stream.writer().any(), val);
    try std.testing.expectEqual(val, try varint.decode(&buf, null));
}

fn testRead(val: u64) !void {
    _ = varint.encode(&buf, val);
    var stream = std.io.fixedBufferStream(&buf);
    try std.testing.expectEqual(val, try varint.read(stream.reader().any()));
}

test "encode and decode" {
    for (0..12345) |val| {
        try roundTripValue(val);
        try testRead(val);
        try testWrite(val);
    }

    try roundTripValue(varint.MAX_VALUE - 1);
    // try roundTripValue(varint.MAX_VALUE);

    var prng = std.rand.DefaultPrng.init(0x0000000000000000);
    var random = prng.random();

    const n = 10000;
    for (0..n) |_| {
        const val = random.uintLessThan(u64, varint.MAX_VALUE);
        try roundTripValue(val);
        try testRead(val);
        try testWrite(val);
    }
}
