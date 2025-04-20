//! Runs a program that might or might not fail and appends to stdout what
//! the actual exit code was, always returning a successful exit code under
//! normal conditions (regardless of the child's exit code).
//!
//! This is useful for snapshot tests where some of which are meant to be
//! successes, while others are meant to be failures.
const std = @import("std");

pub fn main() !void {
    const gpa = std.heap.smp_allocator;
    const args = try std.process.argsAlloc(gpa);

    var cmd = std.process.Child.init(args[1..], gpa);
    cmd.stdout_behavior = .Pipe;
    cmd.stderr_behavior = .Pipe;
    try cmd.spawn();

    // Read and forward stderr
    if (cmd.stderr) |stderr_file| {
        const reader = stderr_file.reader();
        var buffer: [1024]u8 = undefined;
        while (true) {
            const bytes_read = try reader.read(&buffer);
            if (bytes_read == 0) break;
            try std.io.getStdErr().writer().writeAll(buffer[0..bytes_read]);
        }
    }

    // Read and forward stdout
    if (cmd.stdout) |stdout_file| {
        const reader = stdout_file.reader();
        var buffer: [1024]u8 = undefined;
        while (true) {
            const bytes_read = try reader.read(&buffer);
            if (bytes_read == 0) break;
            try std.io.getStdErr().writer().writeAll(buffer[0..bytes_read]);
        }
    }

    const term = try cmd.wait();

    switch (term) {
        .Exited => |code| {
            const fmt = "\n ----- EXIT CODE: {} -----\n";
            std.debug.print(fmt, .{code});
        },
        else => std.debug.panic("child process crashed: {}\n", .{term}),
    }
}
