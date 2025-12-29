# zig-multiformats

Zig modules for [unsigned varints](https://github.com/multiformats/unsigned-varint), [multicodec](https://github.com/multiformats/multicodec), [multibase](https://github.com/multiformats/multibase), [multihash](https://github.com/multiformats/multihash), and [CIDs](https://github.com/multiformats/cid).

## Table of Contents

- [Install](#install)
- [Usage](#usage)
  - [Varints](#varints)
  - [Multibase](#multibase)
  - [Multicodec](#multicodec)
  - [Multihash](#multihash)
  - [CIDs](#cids)

## Install

Add to `build.zig.zon`:

```
zig fetch --save=multiformats \
  https://github.com/nDimensional/zig-multiformats/archive/refs/tags/v0.3.0.tar.gz
```

Then in `build.zig`:

```zig
pub fn build(b: *std.Build) !void {
    // ...
    const multiformats = b.dependency("multiformats", .{});

    const varint = multiformats.module("varint");
    const multicodec = multiformats.module("multicodec");
    const multibase = multiformats.module("multibase");
    const multihash = multiformats.module("multihash");
    const cid = multiformats.module("cid");

    // ... add as imports to exe or lib
}
```

## Usage

### Varints

```zig
pub const MAX_BYTE_LENGTH = 9;
pub const MAX_VALUE: u64 = 1 << 63;

pub fn encodingLength(val: u64) usize

pub fn decode(buf: []const u8, len: ?*usize) !usize
pub fn encode(buf: []u8, val: u64) usize

pub fn read(reader: *std.Io.Reader) !u64
pub fn write(writer: *std.Io.Writer, val: u64) !void
```

The `varint` module has `read`/`write` for usage with streams, and `encode`/`decode` for usage with slices. Trying to `encode` to a buffer that is too small will panic; always check that it has sufficient size using `encodingLength(val)` first.

### Multibase

The different bases are exported as type-erased `Base` interface structs.

```zig
pub const Base = struct {
    code: Code,
    name: []const u8,
    impl: type,

    pub fn writeAll(self: Base, writer: *std.Io.Writer, bytes: []const u8) !void

    pub fn encode(self: Base, allocator: std.mem.Allocator, bytes: []const u8) ![]const u8
    pub fn baseEncode(self: Base, allocator: std.mem.Allocator, bytes: []const u8) ![]const u8
    pub fn decode(self: Base, allocator: std.mem.Allocator, str: []const u8) ![]const u8
    pub fn baseDecode(self: Base, allocator: std.mem.Allocator, str: []const u8) ![]const u8
};

// Base-X family - these are limited to encoding 256 bytes or less
pub const base10: Base;
pub const base36: Base;
pub const base36upper: Base;
pub const base58btc: Base;
pub const base58flickr: Base;

// RFC 4648 family - these are suitable for streaming / arbitrarily long encodings
pub const base2: Base;
pub const base8: Base;
pub const base16: Base;
pub const base16upper: Base;
pub const base32: Base;
pub const base32upper: Base;
pub const base32pad: Base;
pub const base32padupper: Base;
pub const base32hex: Base;
pub const base32hexupper: Base;
pub const base32hexpad: Base;
pub const base32hexpadupper: Base;
pub const base32z: Base;
pub const base64: Base;
pub const base64pad: Base;
pub const base64url: Base;
pub const base64urlpad: Base;
```

Additionally, there are "generic" encode/decode methods that use the `multibase.Code` enum.

```zig
pub const Code = enum {
    base10,
    base36,
    base36upper,
    base58btc,
    base58flickr,
    base2,
    base8,
    base16,
    base16upper,
    base32,
    base32upper,
    base32pad,
    base32padupper,
    base32hex,
    base32hexupper,
    base32hexpad,
    base32hexpadupper,
    base32z,
    base64,
    base64pad,
    base64url,
    base64urlpad,
};

pub const DecodeResult = struct {
    code: Code,
    data: []const u8,
};

pub fn decode(allocator: std.mem.Allocator, str: []const u8) !DecodeResult
pub fn encode(allocator: std.mem.Allocator, bytes: []const u8, code: Code) ![]const u8
```

### Multicodec

`multicodec.Codec` is an enum containing every entry in the [multicodec table](https://github.com/multiformats/multicodec/blob/master/table.csv). The enum type is `u32` and the enum value is the multicodec code. Many of the multicodec names have dashes and thus must be escaped in Zig code like this:

```zig
const multicodec = @import("multicodec");

const code = multicodec.Codec.@"sha2-256";
```

### Multihash

```zig
const std = @import("std");
const varint = @import("varint");
const multibase = @import("multibase");
const multicodec = @import("multicodec");

pub const Digest = struct {
    code: multicodec.Codec,
    hash: []const u8,

    /// decode a binary multihash from bytes
    pub fn decode(allocator: std.mem.Allocator, bytes: []const u8) !Digest;

    /// read a binary multihash from a reader
    pub fn read(allocator: std.mem.Allocator, reader: *std.Io.Reader) !Digest;
    pub fn deinit(self: Digest, allocator: std.mem.Allocator) void;

    pub fn copy(self: Digest, allocator: std.mem.Allocator) !Digest;
    pub fn eql(self: Digest, other: Digest) bool;
    pub fn expectEqual(actual: Digest, expected: Digest) !void;
    pub fn encodingLength(self: Digest) usize;
    pub fn encode(self: Digest, allocator: std.mem.Allocator) ![]const u8;
    pub fn write(self: Digest, writer: *std.Io.Writer) !void;

    /// Format a human-readable {code}-{len}-{hex} string for a Digest
    pub fn format(self: Digest, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void;
};
```

### CIDs

```zig
pub const CID = struct {
    pub const Version = enum { cidv0, cidv1 };

    version: Version,
    codec: Codec,
    digest: Digest,

    /// parse a CID from multibase-encoded string
    pub fn parse(allocator: std.mem.Allocator, str: []const u8) !CID;

    /// read a binary CID from a reader
    pub fn read(allocator: std.mem.Allocator, reader: *std.Io.Reader) !CID;

    /// decode a binary CID from bytes
    pub fn decode(allocator: std.mem.Allocator, bytes: []const u8) !CID;

    pub fn deinit(self: CID, allocator: std.mem.Allocator) void;

    pub fn copy(self: CID, allocator: std.mem.Allocator) !CID;
    pub fn eql(self: CID, other: CID) bool;
    pub fn expectEqual(actual: CID, expected: CID) !void;
    pub fn encodingLength(self: CID) usize;
    pub fn write(self: CID, writer: *std.Io.Writer) !void;
    pub fn encode(self: CID, allocator: std.mem.Allocator) ![]const u8;

    /// Return a multibase Formatter for a CID
    pub fn formatBase(self: CID, base: multibase.Code) std.fmt.Formatter(formatBaseImpl);

    /// Return a human-readable string Formatter for a CID
    pub fn formatString(self: CID) std.fmt.Formatter(formatStringImpl);
};
```
