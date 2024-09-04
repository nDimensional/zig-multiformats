const std = @import("std");
const CID = @import("cid").CID;

test "fjdkslfjdksl" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);

    const allocator = gpa.allocator();

    const cid = try CID.parse(allocator, "zb2rhe5P4gXftAwvA4eXQ5HJwsER2owDyS9sKaQRRVQPn93bA");
    defer cid.deinit(allocator);

    std.log.warn("GOT CID: [{s}]", .{cid.formatString()});
    std.log.warn("GOT CID: [{s}]", .{cid.formatString()});
}
