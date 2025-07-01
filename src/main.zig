const std = @import("std");

pub fn main() !void {
    // read a file in the heap
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit(); // it will check if some memory is leaked

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const arena_allocator = arena.allocator();
    const max_bytes: usize = 500 * 2;

    const file = try std.fs.cwd().openFile("test.json", .{});
    defer file.close();

    const content = try file.readToEndAlloc(arena_allocator, max_bytes);
    std.debug.print("{s}", .{content});
}
