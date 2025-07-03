const std = @import("std");

// a lexer == lector, cuando se lee, se lo hace por palabras, pero en codigo se hace por char, por lo tanto
// cada simbolo es un token
//
const TokenType = enum {
    object_start,
    object_end,
    array_start,
    array_end,
    string,
    number,
    boolean,
    null_token,
    colon,
    comma,
    eof,
    not_valid,
    attr,
};

const Token = struct {
    start: usize,
    end: usize,
    type: TokenType,
};

const Lexer = struct {
    valid_point: usize = 0,
    content: []const u8,

    pub fn init(content: []const u8) Lexer {
        return .{ .content = content };
    }
    pub fn next_token(self: *Lexer) Token {
        self.skip_whitespace();
        if (self.valid_point >= self.content.len) return Token{ .start = self.valid_point, .end = self.valid_point, .type = TokenType.eof };

        const start = self.valid_point;

        const token = switch (self.content[self.valid_point]) {
            '{' => Token{ .start = start, .end = self.valid_point, .type = TokenType.object_start },
            '}' => Token{ .start = start, .end = self.valid_point, .type = TokenType.object_end },
            '[' => Token{ .start = start, .end = self.valid_point, .type = TokenType.array_start },
            ']' => Token{ .start = start, .end = self.valid_point, .type = TokenType.array_end },
            ':' => {
                self.advance();
                return Token{ .start = start, .end = start, .type = TokenType.colon };
            },
            ',' => Token{ .start = start, .end = self.valid_point, .type = TokenType.comma },
            'n' => Token{ .start = start, .end = self.valid_point, .type = TokenType.null_token },

            '"' => self.parse_string(),
            '0'...'9' => Token{ .start = start, .end = undefined, .type = TokenType.number },
            else => Token{ .start = start, .end = self.valid_point, .type = TokenType.not_valid },
        };

        return token;
    }
    fn advance(self: *Lexer) void {
        if (self.valid_point >= self.content.len) return;
        self.valid_point += 1;
    }

    fn parse_string(self: *Lexer) Token {
        const start = self.valid_point;
        self.advance();

        while (self.valid_point <= self.content.len) : (self.advance()) {
            if (self.content[self.valid_point] == '"') {
                const end = self.valid_point;
                self.advance();
                return Token{ .start = start, .end = end, .type = TokenType.string };
            }
        }

        return Token{ .start = start, .end = start, .type = TokenType.not_valid };
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

    const last_token = lexer.next_token();
    std.debug.print("{any}", .{last_token});

    const last_token_2 = lexer.next_token();
    std.debug.print("{any}", .{last_token_2});

    const last_token_3 = lexer.next_token();
    std.debug.print("{any}", .{last_token_3});
}
