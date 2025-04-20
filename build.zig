const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) !void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    // This creates a "module", which represents a collection of source files alongside
    // some compilation options, such as optimization mode and linked system libraries.
    // Every executable or library we compile will be based on one or more modules.
    const lib_mod = b.createModule(.{
        // `root_source_file` is the Zig "entry point" of the module. If a module
        // only contains e.g. external object files, you can make this `null`.
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    // We will also create a module for our other entry point, 'main.zig'.
    const exe_mod = b.createModule(.{
        // `root_source_file` is the Zig "entry point" of the module. If a module
        // only contains e.g. external object files, you can make this `null`.
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Modules can depend on one another using the `std.Build.Module.addImport` function.
    // This is what allows Zig source code to use `@import("foo")` where 'foo' is not a
    // file path. In this case, we set up `exe_mod` to import `lib_mod`.
    exe_mod.addImport("zemml_lib", lib_mod);

    // Now, we will create a static library based on the module we created above.
    // This creates a `std.Build.Step.Compile`, which is the build step responsible
    // for actually invoking the compiler.
    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "zemml",
        .root_module = lib_mod,
    });

    // This declares intent for the library to be installed into the standard
    // location when the user invokes the "install" step (the default step when
    // running `zig build`).
    b.installArtifact(lib);

    // This creates another `std.Build.Step.Compile`, but this one builds an executable
    // rather than a static library.
    const zemml_exe = b.addExecutable(.{
        .name = "zemml",
        .root_module = exe_mod,
    });

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.installArtifact(zemml_exe);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(zemml_exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_zemml = b.step("run", "Run zemml");
    run_zemml.dependOn(&run_cmd.step);

    try setupSnapshotTesting(b, target, zemml_exe);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    // const lib_unit_tests = b.addTest(.{
    //     .root_module = lib_mod,
    // });

    // const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    // const exe_unit_tests = b.addTest(.{
    //     .root_module = exe_mod,
    // });

    // const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    // const test_step = b.step("test", "Run unit tests");
    // test_step.dependOn(&run_lib_unit_tests.step);
    // test_step.dependOn(&run_exe_unit_tests.step);
}

fn setupSnapshotTesting(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    zemml_exe: *std.Build.Step.Compile,
) !void {
    var arena_allocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_allocator.deinit();

    const test_step = b.step("test", "build snapshot tests and diff the results");

    const camera = b.addExecutable(.{
        .name = "camera",
        .root_source_file = b.path("src/build/camera.zig"),
        .target = target,
        .optimize = .ReleaseFast,
    });

    const diff = b.addSystemCommand(&.{
        "git",
        "diff",
        "--cached",
        "--exit-code",
    });
    diff.addDirectoryArg(b.path("tests"));
    diff.setName("git diff tests/");
    test_step.dependOn(&diff.step);

    // We need to stage all of tests/ in order for untracked files to show up in
    // the diff. It's also not a bad automatism since it avoids the problem of
    // forgetting to stage new snapshot files.
    const git_add = b.addSystemCommand(&.{ "git", "add" });
    git_add.addDirectoryArg(b.path("tests/"));
    git_add.setName("git add tests/");
    diff.step.dependOn(&git_add.step);

    try setupSnapshotTestFolder(
        &arena_allocator,
        b,
        camera,
        zemml_exe,
        git_add,
        "tests/parse_ast",
        "--format=ast",
    );
    try setupSnapshotTestFolder(
        &arena_allocator,
        b,
        camera,
        zemml_exe,
        git_add,
        "tests/mathml",
        "--format=mathml",
    );
}

fn setupSnapshotTestFolder(
    arena: *std.heap.ArenaAllocator,
    b: *std.Build,
    camera: *std.Build.Step.Compile,
    zemml_exe: *std.Build.Step.Compile,
    git_add: *std.Build.Step.Run,
    test_path: []const u8,
    format_arg: []const u8,
) !void {
    const tests_dir = try b.build_root.handle.openDir(test_path, .{
        .iterate = true,
    });

    var it = tests_dir.iterateAssumeFirstIteration();
    while (try it.next()) |entry| {
        if (entry.kind != .file) continue;
        const src_path = b.pathJoin(&.{ test_path, entry.name });

        _ = arena.reset(.retain_capacity);

        const snap_name = try std.fmt.allocPrint(arena.allocator(), "{s}.snapshot.txt", .{entry.name});
        const snap_path = b.pathJoin(&.{ test_path, "snapshots", snap_name });
        const input_arg = try std.fmt.allocPrint(arena.allocator(), "--input={s}", .{src_path});
        // const output_arg = try std.fmt.allocPrint(arena.allocator(), "--output={s}", .{snap_path});

        const run_camera = b.addRunArtifact(camera);
        run_camera.addArtifactArg(zemml_exe);
        run_camera.addArg(input_arg);
        run_camera.addArg(format_arg);
        // run_camera.addArg(output_arg);
        run_camera.has_side_effects = true;

        const stdout = run_camera.captureStdErr();
        const update_snap = b.addUpdateSourceFiles();
        update_snap.addCopyFileToSource(stdout, snap_path);

        update_snap.step.dependOn(&run_camera.step);
        git_add.step.dependOn(&update_snap.step);
    }
}
