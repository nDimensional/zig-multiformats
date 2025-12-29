const std = @import("std");

pub const EncodeError = std.Io.Writer.Error || std.mem.Allocator.Error || error{MaxLength};
