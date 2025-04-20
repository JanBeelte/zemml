//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.

const std = @import("std");

/// This imports the separate module containing `root.zig`. Take a look in `build.zig` for details.
const lib = @import("zemml_lib");

const arg_parse = @import("arg_parse.zig");
const tokenizer = @import("tokenizer.zig");

pub fn main() !void {
    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    // std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    // stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.

    var alloc = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = alloc.deinit();
    const gpa = alloc.allocator();
    const args = try std.process.argsAlloc(gpa);
    defer std.process.argsFree(gpa, args);

    const arg_parser = arg_parse.ArgParser.parse(args[1..]);

    std.debug.print("Output Format: {s}\n", .{@tagName(arg_parser.output_format)});

    var input: []u8 = undefined;
    if (arg_parser.input_file_path) |input_file_path| {
        const file = try std.fs.cwd().openFile(input_file_path, .{});
        defer file.close();
        const reader = file.reader();
        input = try reader.readAllAlloc(gpa, std.math.maxInt(usize));
    } else {
        const reader = std.io.getStdIn().reader();
        input = try reader.readAllAlloc(gpa, std.math.maxInt(usize));
    }
    defer gpa.free(input);

    const tokens = try tokenizer.do(gpa, input);
    defer gpa.free(tokens);

    tokenizer.print_tokens(tokens);

    if (arg_parser.output_file_path) |output_file_path| {
        var file = try std.fs.cwd().createFile(output_file_path, .{});
        defer file.close();
        var bw = std.io.bufferedWriter(file.writer());
        const writer = bw.writer();
        try writer.writeAll(input);
        try bw.flush();
    } else {
        const stdout_file = std.io.getStdOut().writer();
        var bw = std.io.bufferedWriter(stdout_file);
        const writer = bw.writer();
        try writer.writeAll(input);
        try bw.flush();
    }
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // Try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

test "use other module" {
    try std.testing.expectEqual(@as(i32, 150), lib.add(100, 50));
}

test "fuzz example" {
    const Context = struct {
        fn testOne(context: @This(), input: []const u8) anyerror!void {
            _ = context;
            // Try passing `--fuzz` to `zig build test` and see if it manages to fail this test case!
            try std.testing.expect(!std.mem.eql(u8, "canyoufindme", input));
        }
    };
    try std.testing.fuzz(Context{}, Context.testOne, .{});
}
