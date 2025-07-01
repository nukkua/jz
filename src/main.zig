const std = @import("std");

pub fn main() !void {
    // read a file in the heap
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit(); // it will check if some memory is leaked

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const file = try std.fs.cwd().openFile("test.json", .{});
    defer file.close();

    const arena_allocator = arena.allocator();

    const max_bytes: usize = 500 * 2;
    const content = try file.readToEndAlloc(arena_allocator, max_bytes);
    const stand_point = skip_whitespace(content);
    std.debug.print("{}", .{stand_point});
}

// write a function that skips the ws
fn skip_whitespace(content: []u8) usize {
    var stand_point: usize = 0;
    while (stand_point < content.len) {
        switch (content[stand_point]) {
            ' ', '\n', '\t', '\r' => stand_point += 1,
            else => break,
        }
    }

    return stand_point;
}
