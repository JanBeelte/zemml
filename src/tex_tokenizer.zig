const std = @import("std");

pub const TokenType = enum {
    ControlSequence,
    EnvironmentBegin,
    EnvironmentEnd,
    Symbol,
    GroupOpen,
    GroupClose,
    Superscript,
    Subscript,
    MathInlineToggle,
    MathDisplayToggle,
    Alignment,
    NewlineCommand,
    Comment,
    Whitespace,
    Text,
    OptionalArgOpen, // [
    OptionalArgClose, // ]
    TextMode, // content inside \text{...}
    Unknown,
};

pub const Token = struct {
    kind: TokenType,
    lexeme: []const u8,
};

pub fn do(gpa: std.mem.Allocator, input: []const u8) ![]Token {
    var tokens = std.ArrayList(Token).init(gpa);
    var i: usize = 0;

    while (i < input.len) {
        const c = input[i];

        switch (c) {
            '\\' => {
                const start = i;
                i += 1;

                if (i < input.len and input[i] == '\\') {
                    i += 1;
                    try tokens.append(Token{ .kind = .NewlineCommand, .lexeme = input[start..i] });
                    continue;
                }

                if (i < input.len and std.ascii.isAlphabetic(input[i])) {
                    const cmd_start = i;
                    while (i < input.len and std.ascii.isAlphabetic(input[i])) i += 1;
                    const cmd = input[cmd_start..i];

                    if (std.mem.eql(u8, cmd, "begin") or std.mem.eql(u8, cmd, "end")) {
                        if (i < input.len and input[i] == '{') {
                            var depth: usize = 1;
                            i += 1;
                            while (i < input.len and depth > 0) {
                                if (input[i] == '{') {
                                    depth += 1;
                                } else if (input[i] == '}') {
                                    depth -= 1;
                                }
                                i += 1;
                            }
                            const kind: TokenType = blk: {
                                if (std.mem.eql(u8, cmd, "begin")) {
                                    break :blk TokenType.EnvironmentBegin;
                                } else if (std.mem.eql(u8, cmd, "end")) {
                                    break :blk TokenType.EnvironmentEnd;
                                }
                                break :blk TokenType.Unknown;
                            };
                            try tokens.append(Token{ .kind = kind, .lexeme = input[start..i] });
                            continue;
                        }
                    } else if (std.mem.eql(u8, cmd, "text")) {
                        var lexeme = input[start..i];
                        if (i < input.len and input[i] == '{') {
                            var depth: usize = 1;
                            i += 1;
                            const lex_start = i;
                            while (i < input.len and depth > 0) {
                                if (input[i] == '{') {
                                    depth += 1;
                                } else if (input[i] == '}') {
                                    depth -= 1;
                                }
                                i += 1;
                            }
                            lexeme = input[lex_start .. i - 1];
                            try tokens.append(Token{ .kind = .TextMode, .lexeme = lexeme });
                            continue;
                        }
                    }

                    try tokens.append(Token{ .kind = .ControlSequence, .lexeme = input[start..i] });
                } else {
                    if (i < input.len) i += 1;
                    try tokens.append(Token{ .kind = .ControlSequence, .lexeme = input[start..i] });
                }
            },
            '{' => {
                try tokens.append(Token{ .kind = .GroupOpen, .lexeme = input[i .. i + 1] });
                i += 1;
            },
            '}' => {
                try tokens.append(Token{ .kind = .GroupClose, .lexeme = input[i .. i + 1] });
                i += 1;
            },
            '[' => {
                try tokens.append(Token{ .kind = .OptionalArgOpen, .lexeme = input[i .. i + 1] });
                i += 1;
            },
            ']' => {
                try tokens.append(Token{ .kind = .OptionalArgClose, .lexeme = input[i .. i + 1] });
                i += 1;
            },
            '^' => {
                try tokens.append(Token{ .kind = .Superscript, .lexeme = input[i .. i + 1] });
                i += 1;
            },
            '_' => {
                try tokens.append(Token{ .kind = .Subscript, .lexeme = input[i .. i + 1] });
                i += 1;
            },
            '$' => {
                const start = i;
                i += 1;
                if (i < input.len and input[i] == '$') {
                    i += 1;
                    try tokens.append(Token{ .kind = .MathDisplayToggle, .lexeme = input[start..i] });
                } else {
                    try tokens.append(Token{ .kind = .MathInlineToggle, .lexeme = input[start..i] });
                }
            },
            '%' => {
                const start = i;
                while (i < input.len and input[i] != '\n') i += 1;
                try tokens.append(Token{ .kind = .Comment, .lexeme = input[start..i] });
            },
            '&' => {
                try tokens.append(Token{ .kind = .Alignment, .lexeme = input[i .. i + 1] });
                i += 1;
            },
            else => {
                if (std.ascii.isWhitespace(c)) {
                    const start = i;
                    while (i < input.len and std.ascii.isWhitespace(input[i])) i += 1;
                    try tokens.append(Token{ .kind = .Whitespace, .lexeme = input[start..i] });
                } else if (std.ascii.isAlphanumeric(c)) {
                    const start = i;
                    while (i < input.len and std.ascii.isAlphanumeric(input[i])) i += 1;
                    try tokens.append(Token{ .kind = .Text, .lexeme = input[start..i] });
                } else {
                    try tokens.append(Token{ .kind = .Symbol, .lexeme = input[i .. i + 1] });
                    i += 1;
                }
            },
        }
    }

    return tokens.toOwnedSlice();
}

pub fn print_tokens(tokens: []const Token) void {
    std.debug.print("Tokens:\n", .{});
    for (tokens) |token| {
        if (token.kind == .Whitespace) continue;
        std.debug.print("{s}({s})\n", .{ @tagName(token.kind), token.lexeme });
    }
}
