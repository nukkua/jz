const std = @import("std");

// a lexer == lector, cuando se lee, se lo hace por palabras, pero en codigo se hace por char, por lo tanto
// cada simbolo es un token
const Lexer = struct {
    valid_point: usize = 0,
    content: []const u8,

    pub fn init(content: []const u8) Lexer {
        return .{ .content = content };
    }
    pub fn next_token(self: *Lexer) usize {
        self.skip_whitespace();
    }

    pub fn show(self: *const Lexer) void {
        std.debug.print("{}", .{self.valid_point});
    }

    fn skip_whitespace(self: *Lexer) void {
        while (self.valid_point < self.content.len) {
            switch (self.content[self.valid_point]) {
                ' ', '\n', '\t' => self.valid_point += 1,
                else => break,
            }
        }
    }
};

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

    var lexer = Lexer.init(content);
    lexer.next_token();
    lexer.show();
}

