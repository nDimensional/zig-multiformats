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

    pub fn parse(allocator: std.mem.Allocator, str: []const u8) !CID {
        if (str.len == 46 and str[0] == 'Q' and str[1] == 'm') {
            const bytes = try multibase.base58btc.baseDecode(allocator, str);
            defer allocator.free(bytes);
            return CID.decodeV0(allocator, bytes);
        } else {
            const bytes = try multibase.decode(allocator, str, null);
            defer allocator.free(bytes);
            return try CID.decodeV1(allocator, bytes);
        }
    }

    pub fn read(allocator: std.mem.Allocator, reader: std.io.AnyReader) !CID {
        const head = try Codec.read(reader);

        if (head == .@"sha2-256") {
            // CIDv0
            const size = try varint.read(reader);
            if (size != 32) {
                return error.INVALID_CID;
            }

            const hash = try allocator.alloc(u8, size);
            errdefer allocator.free(hash);

            try reader.readNoEof(hash);
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
        if (bytes[0] != 1) {
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

    pub fn eql(self: CID, other: CID) bool {
        return self.version == other.version and self.codec == other.codec and
            self.digest.eql(other.digest);
    }

    pub fn write(self: CID, writer: std.io.AnyWriter) !void {
        switch (self.version) {
            .cidv0 => {
                try self.digest.write(writer);
            },
            .cidv1 => {
                try Codec.write(writer, .cidv1);
                try Codec.write(writer, self.codec);
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
                i += Codec.encode(bytes[i..], self.codec);
                i += Codec.encode(bytes[i..], self.digest.code);
                i += varint.encode(bytes[i..], self.digest.hash.len);
                @memcpy(bytes[i .. i + digest_len], self.digest.hash);

                return bytes;
            },
        }
    }

    /// Format a string for a CID
    pub fn format(self: CID, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        const base = switch (self.version) {
            .cidv0 => multibase.Code.base58btc,
            .cidv1 => multibase.Code.base32,
        };

        try formatBaseImpl(.{ .cid = self, .base = base }, fmt, options, writer);
    }

    /// Return a multibase Formatter for a CID
    pub fn formatBase(self: CID, base: multibase.Code) std.fmt.Formatter(formatBaseImpl) {
        return .{ .data = .{ .cid = self, .base = base } };
    }

    fn formatBaseImpl(data: struct { cid: CID, base: multibase.Code }, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;

        if (data.cid.version == .cidv0 and data.base != multibase.Code.base58btc) {
            return error.INVALID_MULTIBASE;
        }

        var stream = std.io.fixedBufferStream(&buffer);
        try data.cid.write(stream.writer().any());
        try multibase.writeAll(writer, buffer[0..stream.pos], data.base, data.cid.version == .cidv1);
    }

    /// Return a human-readable string Formatter for a CID
    pub fn formatString(self: CID) std.fmt.Formatter(formatStringImpl) {
        return .{ .data = self };
    }

    fn formatStringImpl(self: CID, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;

        const base = switch (self.version) {
            .cidv0 => multibase.Code.base58btc,
            .cidv1 => multibase.Code.base32,
        };

        try std.fmt.format(writer, "{s} - {s} - {s} - {any}", .{
            @tagName(base),
            @tagName(self.version),
            @tagName(self.codec),
            self.digest,
        });
    }
};
