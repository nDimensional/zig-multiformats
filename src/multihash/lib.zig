const std = @import("std");
const varint = @import("varint");
const multibase = @import("multibase");
const multicodec = @import("multicodec");

const Codec = multicodec.Codec;

pub const Digest = struct {
    code: Codec,
    hash: []const u8,

    pub fn decode(allocator: std.mem.Allocator, bytes: []const u8) !Digest {
        var code_len: usize = 0;
        const code = try Codec.decode(bytes, &code_len);

        var size_len: usize = 0;
        const size = try varint.decode(bytes[code_len..], &size_len);
        if (code_len + size_len + size != bytes.len) {
            return error.END_OF_DATA;
        }

        const hash = try allocator.alloc(u8, size);
        @memcpy(hash, bytes[code_len + size_len ..]);

        return .{ .code = code, .hash = hash };
    }

    pub fn read(allocator: std.mem.Allocator, reader: std.io.AnyReader) !Digest {
        const code = try Codec.read(reader);
        const size = try varint.read(reader);

        const hash = try allocator.alloc(u8, size);
        errdefer allocator.free(hash);

        try reader.readNoEof(hash);
        return .{ .code = code, .hash = hash };
    }

    pub fn deinit(self: Digest, allocator: std.mem.Allocator) void {
        allocator.free(self.hash);
    }

    pub fn eql(self: Digest, other: Digest) bool {
        return self.code == other.code and std.mem.eql(u8, self.hash, other.hash);
    }

    pub fn encode(self: Digest, allocator: std.mem.Allocator) ![]const u8 {
        const code_len = Codec.encodingLength(self.code);
        const size_len = varint.encodingLength(self.hash.len);
        const bytes = try allocator.alloc(u8, code_len + size_len + self.hash.len);
        _ = Codec.encode(bytes, self.code);
        _ = varint.encode(bytes[code_len..], self.hash.len);
        @memcpy(bytes[code_len + size_len ..], self.hash);
        return bytes;
    }

    pub fn write(self: Digest, writer: std.io.AnyWriter) !void {
        try Codec.write(writer, self.code);
        try varint.write(writer, self.hash.len);
        try writer.writeAll(self.hash);
    }

    /// Format a human-readable string for a Digest
    pub fn format(self: Digest, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;

        try std.fmt.format(writer, "{s}-{d}-{s}", .{
            @tagName(self.code),
            self.hash.len,
            std.fmt.fmtSliceHexLower(self.hash),
        });
    }
};
