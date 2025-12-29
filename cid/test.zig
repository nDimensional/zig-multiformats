const std = @import("std");
const CID = @import("cid").CID;
const Codec = @import("multicodec").Codec;

test "CID.parse" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);

    const allocator = gpa.allocator();

    {
        const cid = try CID.parse(allocator, "zb2rhe5P4gXftAwvA4eXQ5HJwsER2owDyS9sKaQRRVQPn93bA");
        defer cid.deinit(allocator);

        try std.testing.expectEqual(CID.Version.cidv1, cid.version);
        try std.testing.expectEqual(Codec.raw, cid.codec);
        try std.testing.expectEqual(Codec.@"sha2-256", cid.digest.code);
    }

    {
        const a = try CID.parse(allocator, "zb2rhe5P4gXftAwvA4eXQ5HJwsER2owDyS9sKaQRRVQPn93bA");
        defer a.deinit(allocator);

        const b = try CID.parse(allocator, "bafkreidon73zkcrwdb5iafqtijxildoonbwnpv7dyd6ef3qdgads2jc4su");
        defer b.deinit(allocator);

        try std.testing.expect(a.eql(b));
    }

    {
        const cid = try CID.parse(allocator, "QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn");
        defer cid.deinit(allocator);

        try std.testing.expectEqual(CID.Version.cidv0, cid.version);
        try std.testing.expectEqual(Codec.@"dag-pb", cid.codec);
        try std.testing.expectEqual(Codec.@"sha2-256", cid.digest.code);
    }
}

test "CID.encode / CID.decode" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);

    const allocator = gpa.allocator();

    const cid = try CID.parse(allocator, "zb2rhe5P4gXftAwvA4eXQ5HJwsER2owDyS9sKaQRRVQPn93bA");
    defer cid.deinit(allocator);

    const bytes = try cid.encode(allocator);
    defer allocator.free(bytes);

    const cid_decoded = try CID.decode(allocator, bytes);
    defer cid_decoded.deinit(allocator);

    try cid.expectEqual(cid_decoded);
}

test "CID.format" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);

    const allocator = gpa.allocator();

    // base32: bafkreidon73zkcrwdb5iafqtijxildoonbwnpv7dyd6ef3qdgads2jc4su
    // base58: zb2rhe5P4gXftAwvA4eXQ5HJwsER2owDyS9sKaQRRVQPn93bA

    const cid = try CID.parse(allocator, "zb2rhe5P4gXftAwvA4eXQ5HJwsER2owDyS9sKaQRRVQPn93bA");
    defer cid.deinit(allocator);

    var buffer: [1024]u8 = undefined;

    {
        var writer = std.Io.Writer.fixed(&buffer);
        try writer.print("my CID: {f}", .{cid.formatBase(.base58btc)});
        try std.testing.expectEqualSlices(
            u8,
            "my CID: zb2rhe5P4gXftAwvA4eXQ5HJwsER2owDyS9sKaQRRVQPn93bA",
            writer.buffered(),
        );
    }

    {
        var writer = std.Io.Writer.fixed(&buffer);
        try writer.print("my CID: {f}", .{cid.formatBase(.base32)});
        try std.testing.expectEqualSlices(
            u8,
            "my CID: bafkreidon73zkcrwdb5iafqtijxildoonbwnpv7dyd6ef3qdgads2jc4su",
            writer.buffered(),
        );
    }

    {
        var writer = std.Io.Writer.fixed(&buffer);
        try writer.print("my CID: {f}", .{cid});
        try std.testing.expectEqualSlices(
            u8,
            "my CID: bafkreidon73zkcrwdb5iafqtijxildoonbwnpv7dyd6ef3qdgads2jc4su",
            writer.buffered(),
        );
    }

    {
        var writer = std.Io.Writer.fixed(&buffer);
        try writer.print("my CID: {f}", .{cid.formatString()});
        try std.testing.expectEqualSlices(
            u8,
            "my CID: base32 - cidv1 - raw - sha2-256-32-6e6ff7950a36187a801613426e858dce686cd7d7e3c0fc42ee0330072d245c95",
            writer.buffered(),
        );
    }
}
