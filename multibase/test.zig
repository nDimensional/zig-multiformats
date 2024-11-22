const std = @import("std");

const multibase = @import("multibase");

fn testEncode(base: multibase.Base, allocator: std.mem.Allocator, bytes: []const u8, str: []const u8) !void {
    {
        const encoded_str = try base.baseEncode(allocator, bytes);
        defer allocator.free(encoded_str);
        try std.testing.expectEqualSlices(u8, str[1..], encoded_str);

        const decoded_bytes = try base.baseDecode(allocator, encoded_str);
        defer allocator.free(decoded_bytes);
        try std.testing.expectEqualSlices(u8, bytes, decoded_bytes);
    }

    {
        const encoded_str = try base.encode(allocator, bytes);
        defer allocator.free(encoded_str);
        try std.testing.expectEqualSlices(u8, str, encoded_str);

        const decoded_bytes = try base.decode(allocator, encoded_str);
        defer allocator.free(decoded_bytes);
        try std.testing.expectEqualSlices(u8, bytes, decoded_bytes);
    }
}

test "base32 family" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer std.debug.assert(gpa.deinit() == .ok);

    try testEncode(multibase.base32, allocator, "foo", "bmzxw6");
    try testEncode(multibase.base32, allocator, "foobar", "bmzxw6ytboi");
    try testEncode(multibase.base32, allocator, "hello world!", "bnbswy3dpeb3w64tmmqqq");

    try testEncode(multibase.base32hex, allocator, "foo", "vcpnmu");
    try testEncode(multibase.base32hex, allocator, "foobar", "vcpnmuoj1e8");
    try testEncode(multibase.base32hex, allocator, "hello world!", "vd1imor3f41rmusjccggg");

    try testEncode(multibase.base32pad, allocator, "foo", "cmzxw6===");
    try testEncode(multibase.base32pad, allocator, "foobar", "cmzxw6ytboi======");
    try testEncode(multibase.base32pad, allocator, "hello world!", "cnbswy3dpeb3w64tmmqqq====");

    try testEncode(multibase.base32hexpadupper, allocator, "foo", "TCPNMU===");
    try testEncode(multibase.base32hexpadupper, allocator, "foobar", "TCPNMUOJ1E8======");
    try testEncode(multibase.base32hexpadupper, allocator, "hello world!", "TD1IMOR3F41RMUSJCCGGG====");
}

test "base58.baseEncode" {
    var arena = std.heap.ArenaAllocator.init(std.heap.c_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    try testEncode(multibase.base58btc, allocator, "", "z");
    try testEncode(multibase.base58btc, allocator, &.{0}, "z1");
    try testEncode(multibase.base58btc, allocator, &.{ 0, 0 }, "z11");
    try testEncode(multibase.base58btc, allocator, &.{ 0, 0, 0, 0, 0 }, "z11111");
    try testEncode(multibase.base58btc, allocator, &.{ 0, 0, 0, 0, 0, 1, 2, 3 }, "z11111Ldp");

    try testEncode(multibase.base58btc, allocator, &.{ 0xff, 0xff }, "zLUv");
    try testEncode(multibase.base58btc, allocator, &.{ 0, 0xff, 0xff }, "z1LUv");
    try testEncode(multibase.base58btc, allocator, &.{ 0, 0, 0, 0xff, 0xff }, "z111LUv");

    const buffer = try allocator.alloc(u8, 32);

    // 32 random bytes
    {
        const bytes = try std.fmt.hexToBytes(buffer, "e84b4b0c6a274b85f5b332101b0d65b08b006d122314efdef34c9d4f8a5091b0");
        try testEncode(multibase.base58btc, allocator, bytes, "zGdnBBVHLm9D985m4VgvM5oGxdfRyZxMEnX4hFrDPgrGo");
    }

    // 29 random bytes
    {
        const bytes = try std.fmt.hexToBytes(buffer, "7898a2710dc30bde4ffea2cbe7a2b3c2b22cd72c9d6b49a35a9991a355");
        try testEncode(multibase.base58btc, allocator, bytes, "z6UXvLinjzhDSV3Eydg7bdwtowT4syUfooaJivp5S");
    }

    // 25 random bytes
    {
        const bytes = try std.fmt.hexToBytes(buffer, "b4b4b8de99df9e2555b4d66686fa05cae0b37e94fb087e1983");
        try testEncode(multibase.base58btc, allocator, bytes, "z2FiK9L35AZrLhp6DfNfRkbRHNam4ZixeBbG");
    }

    // 20 random bytes
    {
        const bytes = try std.fmt.hexToBytes(buffer, "3c5cb2605094b95ab80dbdc8d435e4e9719bb11f");
        try testEncode(multibase.base58btc, allocator, bytes, "zqmwYyekSMj6VHfyhXmPtJdCiYZk");
    }
}

test "base58.baseDecode" {
    var arena = std.heap.ArenaAllocator.init(std.heap.c_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    try std.testing.expectEqualSlices(u8, &.{}, try multibase.base58btc.baseDecode(allocator, ""));
    try std.testing.expectEqualSlices(u8, &.{0}, try multibase.base58btc.baseDecode(allocator, "1"));
    try std.testing.expectEqualSlices(u8, &.{ 0, 0 }, try multibase.base58btc.baseDecode(allocator, "11"));
    try std.testing.expectEqualSlices(u8, &.{ 0, 0, 0, 0, 0 }, try multibase.base58btc.baseDecode(allocator, "11111"));
    try std.testing.expectEqualSlices(u8, &.{ 0, 0, 0, 0, 0, 1, 2, 3 }, try multibase.base58btc.baseDecode(allocator, "11111Ldp"));

    try std.testing.expectEqualSlices(u8, &.{ 0xff, 0xff }, try multibase.base58btc.baseDecode(allocator, "LUv"));
    try std.testing.expectEqualSlices(u8, &.{ 0, 0xff, 0xff }, try multibase.base58btc.baseDecode(allocator, "1LUv"));
    try std.testing.expectEqualSlices(u8, &.{ 0, 0, 0, 0xff, 0xff }, try multibase.base58btc.baseDecode(allocator, "111LUv"));

    const buffer = try allocator.alloc(u8, 32);

    // Fixtures

    // 32 random bytes
    try std.testing.expectEqualSlices(
        u8,
        try std.fmt.hexToBytes(buffer, "e84b4b0c6a274b85f5b332101b0d65b08b006d122314efdef34c9d4f8a5091b0"),
        try multibase.base58btc.baseDecode(allocator, "GdnBBVHLm9D985m4VgvM5oGxdfRyZxMEnX4hFrDPgrGo"),
    );

    // 29 random bytes
    try std.testing.expectEqualSlices(
        u8,
        try std.fmt.hexToBytes(buffer, "7898a2710dc30bde4ffea2cbe7a2b3c2b22cd72c9d6b49a35a9991a355"),
        try multibase.base58btc.baseDecode(allocator, "6UXvLinjzhDSV3Eydg7bdwtowT4syUfooaJivp5S"),
    );

    // 25 random bytes
    try std.testing.expectEqualSlices(
        u8,
        try std.fmt.hexToBytes(buffer, "b4b4b8de99df9e2555b4d66686fa05cae0b37e94fb087e1983"),
        try multibase.base58btc.baseDecode(allocator, "2FiK9L35AZrLhp6DfNfRkbRHNam4ZixeBbG"),
    );

    // 20 random bytes
    try std.testing.expectEqualSlices(
        u8,
        try std.fmt.hexToBytes(buffer, "3c5cb2605094b95ab80dbdc8d435e4e9719bb11f"),
        try multibase.base58btc.baseDecode(allocator, "qmwYyekSMj6VHfyhXmPtJdCiYZk"),
    );
}

fn testGeneric(allocator: std.mem.Allocator, code: multibase.Code, bytes: []const u8, str: []const u8) !void {
    {
        // multibase.encode
        const actual = try multibase.encode(allocator, bytes, code);
        defer allocator.free(actual);
        try std.testing.expectEqualSlices(u8, str, actual);
    }

    {
        // multibase.decode
        const result = try multibase.decode(allocator, str);
        defer allocator.free(result.data);
        try std.testing.expectEqual(result.code, code);
        try std.testing.expectEqualSlices(u8, bytes, result.data);
    }
}

test "generic encode/decode" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const buffer = try allocator.alloc(u8, 32);
    defer allocator.free(buffer);

    _ = try std.fmt.hexToBytes(buffer, "e84b4b0c6a274b85f5b332101b0d65b08b006d122314efdef34c9d4f8a5091b0");

    try testGeneric(allocator, .base2, buffer,
        \\011101000010010110100101100001100011010100010011
        ++ \\101001011100001011111010110110011001100100001000
        ++ \\000011011000011010110010110110000100010110000000
        ++ \\001101101000100100010001100010100111011111101111
        ++ \\011110011010011001001110101001111100010100101000
        ++ \\01001000110110000
    );

    try testGeneric(allocator, .base8, buffer,
        \\772045513030650472270276554631020066065455410540033211043051677367464623523705120443300
    );

    try testGeneric(allocator, .base16, buffer, "fe84b4b0c6a274b85f5b332101b0d65b08b006d122314efdef34c9d4f8a5091b0");
    try testGeneric(allocator, .base16upper, buffer, "FE84B4B0C6A274B85F5B332101B0D65B08B006D122314EFDEF34C9D4F8A5091B0");

    try testGeneric(allocator, .base32, buffer, "b5bfuwddke5fyl5ntgiibwdlfwcfqa3isemko7xxtjsou7csqsgya");
    try testGeneric(allocator, .base32upper, buffer, "B5BFUWDDKE5FYL5NTGIIBWDLFWCFQA3ISEMKO7XXTJSOU7CSQSGYA");
    try testGeneric(allocator, .base32pad, buffer, "c5bfuwddke5fyl5ntgiibwdlfwcfqa3isemko7xxtjsou7csqsgya====");
    try testGeneric(allocator, .base32padupper, buffer, "C5BFUWDDKE5FYL5NTGIIBWDLFWCFQA3ISEMKO7XXTJSOU7CSQSGYA====");
    try testGeneric(allocator, .base32hex, buffer, "vt15km33a4t5obtdj6881m3b5m25g0r8i4caevnnj9iekv2igi6o0");
    try testGeneric(allocator, .base32hexupper, buffer, "VT15KM33A4T5OBTDJ6881M3B5M25G0R8I4CAEVNNJ9IEKV2IGI6O0");
    try testGeneric(allocator, .base32hexpad, buffer, "tt15km33a4t5obtdj6881m3b5m25g0r8i4caevnnj9iekv2igi6o0====");
    try testGeneric(allocator, .base32hexpadupper, buffer, "TT15KM33A4T5OBTDJ6881M3B5M25G0R8I4CAEVNNJ9IEKV2IGI6O0====");
    try testGeneric(allocator, .base32z, buffer, "h7bfwsddkr7fam7pugeebsdmfsnfoy5e1rckq9zzuj1qw9n1o1gay");


    try testGeneric(allocator, .base10, buffer, "9105069612366850818172955027443779663331307974886341564945589147424096926077360");
    try testGeneric(allocator, .base36, buffer, "k5sffbvicytc52rk1yfuk3up9pdt3ivvj7u9zbstm6h9wywwvxs");
    try testGeneric(allocator, .base36upper, buffer, "K5SFFBVICYTC52RK1YFUK3UP9PDT3IVVJ7U9ZBSTM6H9WYWWVXS");

    try testGeneric(allocator, .base58btc, buffer, "zGdnBBVHLm9D985m4VgvM5oGxdfRyZxMEnX4hFrDPgrGo");
    try testGeneric(allocator, .base58flickr, buffer, "ZgCMbbuhkL9d985L4uFVm5NgXCEqYyXmeMw4GfRdoFRgN");
}
