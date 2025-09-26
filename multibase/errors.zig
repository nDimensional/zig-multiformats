const std = @import("std");

pub const EncodeError = std.io.Writer.Error || std.mem.Allocator.Error || error{MaxLength};
