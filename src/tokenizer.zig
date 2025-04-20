const std = @import("std");

const TokenType = enum {
    ControlSequence, // e.g., \frac, \dot
    EnvironmentBegin, // \begin{...}
    EnvironmentEnd, // \end{...}
    Symbol, // e.g., +, -, =, &, etc.
    GroupOpen, // {
    GroupClose, // }
    Superscript, // ^
    Subscript, // _
    Alignment, // &
    LineBreak, // \\
    Whitespace,
    Text, // Plain text or numbers
    Comment, // %
    Unknown,
};
const Token = struct {
    kind: TokenType,
    lexeme: []const u8,
};

pub fn do(gpa: std.mem.Allocator, input: []const u8) ![]Token {
    var tokens = std.ArrayList(Token).init(gpa);
    var i: usize = 0;

    while (i < input.len) {
        const c = input[i];

        if (c == '\\') {
            // Handle control sequences and line breaks
            const start = i;
            i += 1;
            if (i < input.len and input[i] == '\\') {
                // Line break
                i += 1;
                try tokens.append(Token{ .kind = .LineBreak, .lexeme = input[start..i] });
            } else {
                // Read command name
                const cmd_start = i;
                while (i < input.len and std.ascii.isAlphabetic(input[i])) {
                    i += 1;
                }
                const cmd = input[cmd_start..i];
                if (std.mem.eql(u8, cmd, "begin") or std.mem.eql(u8, cmd, "end")) {
                    // Handle environments
                    while (i < input.len and std.ascii.isWhitespace(input[i])) {
                        i += 1;
                    }
                    if (i < input.len and input[i] == '{') {
                        i += 1;
                        while (i < input.len and input[i] != '}') {
                            i += 1;
                        }
                        if (i < input.len) {
                            i += 1; // Include closing brace
                            const lexeme = input[start..i];
                            var kind: TokenType = undefined;
                            if (std.mem.eql(u8, cmd, "begin")) {
                                kind = TokenType.EnvironmentBegin;
                            } else {
                                kind = TokenType.EnvironmentEnd;
                            }
                            try tokens.append(Token{ .kind = kind, .lexeme = lexeme });
                        } else {
                            // Unclosed environment name
                            try tokens.append(Token{ .kind = .Unknown, .lexeme = input[start..i] });
                        }
                    } else {
                        // Malformed environment
                        try tokens.append(Token{ .kind = .Unknown, .lexeme = input[start..i] });
                    }
                } else {
                    const lexeme = input[start..i];
                    try tokens.append(Token{ .kind = .ControlSequence, .lexeme = lexeme });
                }
            }
        } else if (c == '{') {
            try tokens.append(Token{ .kind = .GroupOpen, .lexeme = input[i .. i + 1] });
            i += 1;
        } else if (c == '}') {
            try tokens.append(Token{ .kind = .GroupClose, .lexeme = input[i .. i + 1] });
            i += 1;
        } else if (c == '^') {
            try tokens.append(Token{ .kind = .Superscript, .lexeme = input[i .. i + 1] });
            i += 1;
        } else if (c == '_') {
            try tokens.append(Token{ .kind = .Subscript, .lexeme = input[i .. i + 1] });
            i += 1;
        } else if (c == '&') {
            try tokens.append(Token{ .kind = .Alignment, .lexeme = input[i .. i + 1] });
            i += 1;
        } else if (std.ascii.isWhitespace(c)) {
            const start = i;
            while (i < input.len and std.ascii.isWhitespace(input[i])) {
                i += 1;
            }
            const lexeme = input[start..i];
            try tokens.append(Token{ .kind = .Whitespace, .lexeme = lexeme });
        } else if (c == '%') {
            // Comment: consume until end of line
            const start = i;
            while (i < input.len and input[i] != '\n') {
                i += 1;
            }
            const lexeme = input[start..i];
            try tokens.append(Token{ .kind = .Comment, .lexeme = lexeme });
        } else if (std.ascii.isDigit(c) or std.ascii.isAlphabetic(c)) {
            // Text or number
            const start = i;
            while (i < input.len and (std.ascii.isDigit(input[i]) or std.ascii.isAlphabetic(input[i]))) {
                i += 1;
            }
            const lexeme = input[start..i];
            try tokens.append(Token{ .kind = .Text, .lexeme = lexeme });
        } else {
            // Other single-character symbols
            try tokens.append(Token{ .kind = .Symbol, .lexeme = input[i .. i + 1] });
            i += 1;
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
