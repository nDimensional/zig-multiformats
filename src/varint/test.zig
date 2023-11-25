const std = @import("std");

const varint = @import("varint");

test "encode and decode" {
    var buf: [varint.MAX_BYTE_LENGTH]u8 = undefined;

    var val: u64 = 0;
    while (val < varint.MAX_VALUE) : (val += 1) {
        const len = varint.encode(&buf, val);
        try std.testing.expectEqual(varint.encodingLength(val), len);
        const result = try varint.decode(&buf);
        try std.testing.expectEqual(varint.encodingLength(val), result.len);
        try std.testing.expectEqual(val, result.val);
    }
}
