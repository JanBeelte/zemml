const std = @import("std");

const fatal = @import("fatal.zig");

pub const ArgParser = struct {
    input_file_path: ?[]const u8,
    output_file_path: ?[]const u8,

    pub fn parse(args: []const []const u8) ArgParser {
        var input_file_path: ?[]const u8 = null;
        var output_file_path: ?[]const u8 = null;

        const eql = std.mem.eql;
        const startsWith = std.mem.startsWith;

        var idx: usize = 0;
        while (idx < args.len) : (idx += 1) {
            const arg = args[idx];
            if (eql(u8, arg, "-h") or eql(u8, arg, "--help")) {
                fatal.help();
            } else if (std.mem.eql(u8, arg, "-i") or std.mem.eql(u8, arg, "--input")) {
                idx += 1;
                if (idx >= args.len) fatal.msg(
                    "error: missing argument to '{s}'",
                    .{arg},
                );
                input_file_path = args[idx];
            } else if (startsWith(u8, arg, "--input=")) {
                input_file_path = arg["--input=".len..];
            } else if (std.mem.eql(u8, arg, "-o") or std.mem.eql(u8, arg, "--output")) {
                idx += 1;
                if (idx >= args.len) fatal.msg(
                    "error: missing argument to '{s}'",
                    .{arg},
                );
                output_file_path = args[idx];
            } else if (startsWith(u8, arg, "--output=")) {
                output_file_path = arg["--output=".len..];
            } else {
                fatal.msg("error: unexpected cli argument '{s}'\n", .{arg});
            }
        }

        return .{
            .input_file_path = input_file_path,
            .output_file_path = output_file_path,
        };
    }
};
