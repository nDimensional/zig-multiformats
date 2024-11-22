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
