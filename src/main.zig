const std = @import("std");

const Json = union(enum) {
    object: std.StringHashMap(Json),
    array: std.ArrayList(Json),
    string: []const u8,
    number: usize,
    boolean: bool,
    null_value: void,
};

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

    pub fn get(self: *const Token, content: []const u8) []const u8 {
        return content[self.start..self.end];
    }
};

const Lexer = struct {
    valid_point: usize = 0,
    content: []const u8,

    pub fn init(content: []const u8) Lexer {
        return .{ .content = content };
    }
    pub fn next_token(self: *Lexer) Token {
        self.skip_whitespace();
        if (self.valid_point >= self.content.len)
            return Token{ .start = self.valid_point, .end = self.valid_point, .type = TokenType.eof };

        const start = self.valid_point;

        const token = switch (self.content[self.valid_point]) {
            '{' => {
                self.advance();
                return Token{ .start = start, .end = start, .type = TokenType.object_start };
            },
            '}' => {
                self.advance();
                return Token{ .start = start, .end = start, .type = TokenType.object_end };
            },
            '[' => {
                self.advance();
                return Token{ .start = start, .end = self.valid_point, .type = TokenType.array_start };
            },
            ']' => {
                self.advance();
                return Token{ .start = start, .end = self.valid_point, .type = TokenType.array_end };
            },
            ':' => self.parse_colon(),
            ',' => self.parse_comma(),
            'n' => self.parse_null(),
            '"' => self.parse_string(),
            't', 'f' => self.parse_boolean(),
            '0'...'9' => self.parse_number(),
            else => Token{ .start = start, .end = self.valid_point, .type = TokenType.not_valid },
        };
        return token;
    }
    fn advance(self: *Lexer) void {
        if (self.valid_point >= self.content.len) return;
        self.valid_point += 1;
    }

    fn parse_boolean(self: *Lexer) Token {
        const start = self.valid_point;
        switch (self.content[start]) {
            't' => {
                self.valid_point += 3;
                const end = self.valid_point;
                self.advance();
                return Token{ .start = start, .end = end, .type = TokenType.boolean };
            },

            'f' => {
                self.valid_point += 4;
                const end = self.valid_point;
                self.advance();
                return Token{ .start = start, .end = end, .type = TokenType.boolean };
            },

            else => {
                self.advance();
                return Token{ .start = start, .end = start, .type = TokenType.not_valid };
            },
        }
    }
    fn parse_null(self: *Lexer) Token {
        const start = self.valid_point;

        self.valid_point += 3;

        const end = self.valid_point;
        self.advance();

        return Token{ .start = start, .end = end, .type = TokenType.null_token };
    }
    fn parse_comma(self: *Lexer) Token {
        const start = self.valid_point;
        self.advance();

        return Token{ .start = start, .end = start, .type = TokenType.comma };
    }
    fn parse_colon(self: *Lexer) Token {
        const start = self.valid_point;
        self.advance();

        return Token{ .start = start, .end = start, .type = TokenType.colon };
    }

    fn parse_string(self: *Lexer) Token {
        const start = self.valid_point;
        self.advance();

        while (self.valid_point < self.content.len) : (self.advance()) {
            if (self.content[self.valid_point] == '"') {
                const end = self.valid_point;
                self.advance();
                return Token{ .start = start, .end = end, .type = TokenType.string };
            }
        }

        return Token{ .start = start, .end = start, .type = TokenType.not_valid };
    }

    fn parse_number(self: *Lexer) Token {
        const start = self.valid_point;
        while (self.valid_point < self.content.len) : (self.valid_point += 1) {
            switch (self.content[self.valid_point]) {
                '0'...'9', '.', 'e', 'E', '+', '-' => continue,
                else => break,
            }
        }
        const end = self.valid_point;
        return Token{ .start = start, .end = end, .type = TokenType.number };
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

const ParseError = error{
    UnexpectedToken,
    ExpectedString,
    InvalidNumber,
    OutOfMemory,
    UnexpectedCharacter,
    UnterminatedString,
    InvalidBoolean,
    InvalidNull,
};

const Parser = struct {
    allocator: std.mem.Allocator,
    lexer: *Lexer,
    current_token: Token = undefined,

    pub fn init(allocator: std.mem.Allocator, lexer: *Lexer) Parser {
        return .{
            .allocator = allocator,
            .lexer = lexer,
            .current_token = lexer.next_token(),
        };
    }
    pub fn parse(self: *Parser) ParseError!Json {
        return self.parse_value();
    }
    fn go_to_next_token(self: *Parser) void {
        self.current_token = self.lexer.next_token();
    }

    fn parse_value(self: *Parser) ParseError!Json {
        const value = switch (self.current_token.type) {
            .object_start => try self.store_object(),
            .string => self.store_string(),
            .null_token => self.store_null(),
            .number => self.store_number(),
            .not_valid => ParseError.UnexpectedCharacter,
            else => ParseError.UnexpectedToken,
        };

        return value;
    }
    fn store_string(self: *Parser) Json {
        const token = self.current_token;

        return .{
            .string = token.get(self.lexer.content)[1..],
        };
    }
    fn store_null(_: *const Parser) Json {
        return .{
            .null_value = {},
        };
    }

    fn store_number(self: *Parser) Json {
        const token = self.current_token;
        const token_value = token.get(self.lexer.content);

        var it: usize = 0;
        var value: usize = 0;

        if (token_value.len == 1) value = token_value[0] - '0';

        while (it < token_value.len) : (it += 1) {
            value += std.math.pow(usize, 10, token_value.len - 1 - it) * (token_value[it] - '0');
        }

        return .{
            .number = value,
        };
    }
    fn store_object(self: *Parser) ParseError!Json {
        var object = std.StringHashMap(Json).init(self.allocator);

        while (true) {
            self.go_to_next_token();
            if (self.current_token.type != TokenType.string) return ParseError.ExpectedString;

            const key_token = self.current_token;
            const key = key_token.get(self.lexer.content)[1..];

            self.go_to_next_token();
            if (self.current_token.type != TokenType.colon) return ParseError.UnexpectedToken;

            self.go_to_next_token();

            const value = try self.parse_value();
            try object.put(key, value);

            self.go_to_next_token();

            if (self.current_token.type == TokenType.object_end) {
                break;
            }
            if (self.current_token.type != TokenType.comma) return ParseError.UnexpectedToken;
        }

        return Json{
            .object = object,
        };
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
    var parser = Parser.init(arena_allocator, &lexer);

    const JSON = try parser.parse();
    std.debug.print("{any}", .{JSON.object.get("pancakes").?.number});
}
