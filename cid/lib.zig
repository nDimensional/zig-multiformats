const std = @import("std");
const varint = @import("varint");
const multicodec = @import("multicodec");
const multihash = @import("multihash");
const multibase = @import("multibase");

const Codec = multicodec.Codec;
const Digest = multihash.Digest;

const DEFAULT_BASE = multibase.Code.base32;

const max_byte_len = 256;
threadlocal var buffer: [max_byte_len]u8 = undefined;

pub const CID = struct {
    pub const Version = enum { cidv0, cidv1 };

    version: Version,
    codec: Codec,
    digest: Digest,

    /// parse a CID from multibase-encoded string
    pub fn parse(allocator: std.mem.Allocator, str: []const u8) !CID {
        if (str.len == 46 and str[0] == 'Q' and str[1] == 'm') {
            const bytes = try multibase.base58btc.baseDecode(allocator, str);
            defer allocator.free(bytes);
            return CID.decodeV0(allocator, bytes);
        } else {
            const result = try multibase.decode(allocator, str);
            defer allocator.free(result.data);
            return try CID.decodeV1(allocator, result.data);
        }
    }

    /// read a binary CID from a reader
    pub fn read(allocator: std.mem.Allocator, reader: *std.io.Reader) !CID {
        const head = try Codec.read(reader);

        if (head == .@"sha2-256") {
            // CIDv0
            const size = try varint.read(reader);
            if (size != 32) {
                return error.INVALID_CID;
            }

            const hash = try allocator.alloc(u8, size);
            errdefer allocator.free(hash);

            try reader.readSliceAll(hash);
            return .{ .code = head, .hash = hash };
        } else {
            // CIDv1
            try switch (head) {
                .cidv1 => {},
                .cidv2 => error.UNSUPPORTED_CID_VERSION,
                .cidv3 => error.UNSUPPORTED_CID_VERSION,
                else => error.INVALID_CID,
            };

            const codec = try Codec.read(reader);
            const digest = try Digest.read(allocator, reader);
            return .{ .version = .v1, .codec = codec, .digest = digest };
        }
    }

    pub fn decode(allocator: std.mem.Allocator, bytes: []const u8) !CID {
        if (bytes.len < 2) return error.INVALID_CID;
        if (bytes.len == 34 and bytes[0] == 0x12 and bytes[1] == 0x20) {
            return CID.decodeV0(allocator, bytes);
        } else {
            return CID.decodeV1(allocator, bytes);
        }
    }

    fn decodeV0(allocator: std.mem.Allocator, bytes: []const u8) !CID {
        const digest = try Digest.decode(allocator, bytes);
        return .{ .version = .cidv0, .codec = .@"dag-pb", .digest = digest };
    }

    fn decodeV1(allocator: std.mem.Allocator, bytes: []const u8) !CID {
        if (bytes.len == 0 or bytes[0] != 1) {
            return error.INVALID_CID;
        }

        var codec_len: usize = 0;
        const codec = try Codec.decode(bytes[1..], &codec_len);

        const digest = try Digest.decode(allocator, bytes[1 + codec_len ..]);
        return .{ .version = .cidv1, .codec = codec, .digest = digest };
    }

    pub fn deinit(self: CID, allocator: std.mem.Allocator) void {
        self.digest.deinit(allocator);
    }

    pub fn copy(self: CID, allocator: std.mem.Allocator) !CID {
        const digest = try self.digest.copy(allocator);
        return .{ .version = self.version, .codec = self.codec, .digest = digest };
    }

    pub fn eql(self: CID, other: CID) bool {
        return self.version == other.version and self.codec == other.codec and
            self.digest.eql(other.digest);
    }

    pub fn expectEqual(actual: CID, expected: CID) !void {
        try std.testing.expectEqual(actual.version, expected.version);
        try std.testing.expectEqual(actual.codec, expected.codec);
        try actual.digest.expectEqual(expected.digest);
    }

    pub fn encodingLength(self: CID) usize {
        return switch (self.version) {
            .cidv0 => self.digest.encodingLength(),
            .cidv1 => Codec.encodingLength(.cidv1) + Codec.encodingLength(self.codec) + self.digest.encodingLength(),
        };
    }

    pub fn write(self: CID, writer: *std.io.Writer) std.io.Writer.Error!void {
        switch (self.version) {
            .cidv0 => {
                try self.digest.write(writer);
            },
            .cidv1 => {
                try Codec.cidv1.write(writer);
                try self.codec.write(writer);
                try self.digest.write(writer);
            },
        }
    }

    pub fn encode(self: CID, allocator: std.mem.Allocator) ![]const u8 {
        switch (self.version) {
            .cidv0 => return try self.digest.encode(allocator),
            .cidv1 => {
                const version_len = 1;
                const codec_len = Codec.encodingLength(self.codec);

                const digest_code_len = Codec.encodingLength(self.digest.code);
                const digest_size_len = varint.encodingLength(self.digest.hash.len);
                const digest_len = self.digest.hash.len;

                const n = version_len + codec_len + digest_code_len + digest_size_len + digest_len;
                const bytes = try allocator.alloc(u8, n);

                bytes[0] = 1; // CID version

                var i: usize = 1;
                i += self.codec.encode(bytes[i..]);
                i += self.digest.code.encode(bytes[i..]);
                i += varint.encode(bytes[i..], self.digest.hash.len);
                @memcpy(bytes[i .. i + digest_len], self.digest.hash);

                return bytes;
            },
        }
    }

    /// Format a string for a CID
    pub fn format(self: CID, writer: *std.io.Writer) error{WriteFailed}!void {
        const base = switch (self.version) {
            .cidv0 => multibase.Code.base58btc,
            .cidv1 => multibase.Code.base32,
        };

        try formatBaseFn(.{ .cid = self, .base = base }, writer);
    }

    const FormatBaseData = struct { cid: CID, base: multibase.Code };

    /// Return a multibase Formatter for a CID
    pub fn formatBase(self: CID, base: multibase.Code) std.fmt.Alt(FormatBaseData, formatBaseFn) {
        return .{ .data = .{ .cid = self, .base = base } };
    }

    fn formatBaseFn(data: FormatBaseData, writer: *std.io.Writer) std.io.Writer.Error!void {
        if (data.cid.version == .cidv0 and data.base != multibase.Code.base58btc) {
            return error.WriteFailed;
        }

        var w = std.io.Writer.fixed(&buffer);
        try data.cid.write(&w);
        try multibase.writeAll(writer, w.buffered(), data.base, data.cid.version == .cidv1);
    }

    /// Return a human-readable string Formatter for a CID
    pub fn formatString(self: CID) std.fmt.Alt(CID, formatStringFn) {
        return .{ .data = self };
    }

    fn formatStringFn(self: CID, writer: *std.io.Writer) !void {
        const base = switch (self.version) {
            .cidv0 => multibase.Code.base58btc,
            .cidv1 => multibase.Code.base32,
        };

        try writer.print("{s} - {s} - {s} - {f}", .{
            @tagName(base),
            @tagName(self.version),
            @tagName(self.codec),
            self.digest,
        });
    }
};
