const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // These options will receive values from the parent build
    const static_mode = b.option(bool, "static", "Enable static mode") orelse false;
    const enable_atomic = b.option(bool, "atomic", "Enable atomic operations") orelse true;

    // Create build_options module
    const build_options = b.addOptions();
    build_options.addOption(bool, "static_mode", static_mode);
    build_options.addOption(bool, "enable_atomic", enable_atomic); // 2. Create a module from the user's file path only if provided

    var vapor_imports = std.array_list.Managed(std.Build.Module.Import).init(b.allocator);
    const build_options_module = build_options.createModule();
    vapor_imports.append(.{ .name = "build_options", .module = build_options_module }) catch @panic("OOM");

    const mod = b.addModule("vapor", .{
        .root_source_file = b.path("src/comptime.zig"),
        .target = target,
        .optimize = optimize,
        .imports = vapor_imports.items,
    });

    var exe_imports = std.array_list.Managed(std.Build.Module.Import).init(b.allocator);
    exe_imports.append(.{ .name = "vapor", .module = mod }) catch @panic("OOM");

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = exe_imports.items,
    });

    const exe = b.addExecutable(.{
        .name = "vapor",
        .root_module = exe_mod,
    });

    b.installArtifact(exe);

    // The JS runtime the wasm talks to. It ships prebuilt in js/dist so apps
    // need no Node toolchain, and it travels with the Zig source so the two
    // can never come from different versions. Apps install it with:
    //
    //   b.getInstallStep().dependOn(&b.addInstallBinFile(
    //       vapor_dep.namedLazyPath("runtime"), "bundle.min.js").step);
    b.addNamedLazyPath("runtime", b.path("js/dist/bundle.min.js"));

    // Maintainers only: regenerate js/dist/bundle.min.js after editing js/src.
    // The esbuild version is pinned so the committed bundle is reproducible.
    const runtime_step = b.step("runtime", "Rebuild js/dist/bundle.min.js from js/src (needs npx)");
    const esbuild = b.addSystemCommand(&.{
        "npx",                 "--yes",
        "esbuild@0.28.0",      "js/src/main.js",
        "--bundle",            "--minify",
        "--log-level=warning", "--outfile=js/dist/bundle.min.js",
    });
    esbuild.setCwd(b.path("."));
    runtime_step.dependOn(&esbuild.step);

    const test_config_module = b.createModule(.{
        .root_source_file = b.path("tests/support/config.zig"),
        .target = target,
        .optimize = optimize,
    });

    const test_vapor_module = b.createModule(.{
        .root_source_file = b.path("src/comptime.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "build_options", .module = build_options_module },
        },
        .link_libc = true,
    });

    const test_theme_module = b.createModule(.{
        .root_source_file = b.path("tests/support/theme.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "vapor", .module = test_vapor_module },
        },
    });

    test_vapor_module.addImport("config", test_config_module);
    test_vapor_module.addImport("theme", test_theme_module);

    const tests_mod = b.createModule(.{
        .root_source_file = b.path("tests/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "vapor", .module = test_vapor_module },
            .{ .name = "config", .module = test_config_module },
            .{ .name = "theme", .module = test_theme_module },
        },
        .link_libc = true,
    });

    const unit_tests = b.addTest(.{ .name = "vapor-tests", .root_module = tests_mod });
    const run_unit_tests = b.addRunArtifact(unit_tests);

    const string_table_tests = b.addTest(.{
        .name = "string-table-tests",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/lib/StringTable.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_string_table_tests = b.addRunArtifact(string_table_tests);

    const pool_tests = b.addTest(.{
        .name = "pool-tests",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/lib/Pool.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_pool_tests = b.addRunArtifact(pool_tests);

    // Test blocks inside src/lib: see the `test` block in src/comptime.zig.
    const lib_tests = b.addTest(.{ .name = "vapor-lib-tests", .root_module = test_vapor_module });
    const run_lib_tests = b.addRunArtifact(lib_tests);

    const test_step = b.step("test", "Run Vapor unit tests");
    test_step.dependOn(&run_lib_tests.step);
    test_step.dependOn(&run_unit_tests.step);
    test_step.dependOn(&run_string_table_tests.step);
    test_step.dependOn(&run_pool_tests.step);

    // Every extern fn must exist in the shipped runtime, or the browser refuses
    // to load any app that reaches it. See tools/check_abi.zig.
    const abi_tool_mod = b.createModule(.{
        .root_source_file = b.path("tools/check_abi.zig"),
        .target = b.graph.host,
        .optimize = .Debug,
    });
    const abi_tool = b.addExecutable(.{ .name = "check-abi", .root_module = abi_tool_mod });
    const run_abi = b.addRunArtifact(abi_tool);
    run_abi.setCwd(b.path("."));
    run_abi.addArgs(&.{ "src", "js/dist/bundle.min.js" });
    run_abi.addFileInput(b.path("js/dist/bundle.min.js"));
    run_abi.has_side_effects = true;
    const abi_step = b.step("check-abi", "Verify the JS runtime implements every wasm import");
    abi_step.dependOn(&run_abi.step);
    test_step.dependOn(&run_abi.step);
    test_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = abi_tool_mod })).step);

    // End-to-end tests in headless Chrome: builds tests/browser/app against
    // this checkout, then drives it (tests/browser/run.mjs). Needs Node >= 22
    // and Chrome, so it is its own step rather than part of `test`.
    const browser_step = b.step("browser-test", "Run the browser tests (needs Node >= 22 and Chrome)");
    const browser_optimize = b.option(
        std.builtin.OptimizeMode,
        "browser-optimize",
        "Optimize mode for the browser-test app (default Debug; CI also runs ReleaseSmall, what apps ship)",
    ) orelse .Debug;
    const build_app = b.addSystemCommand(&.{
        b.graph.zig_exe,
        "build",
        b.fmt("-Doptimize={s}", .{@tagName(browser_optimize)}),
    });
    build_app.setCwd(b.path("tests/browser/app"));
    build_app.has_side_effects = true;
    const run_browser = b.addSystemCommand(&.{ "node", "tests/browser/run.mjs" });
    run_browser.setCwd(b.path("."));
    run_browser.has_side_effects = true;
    run_browser.step.dependOn(&build_app.step);
    browser_step.dependOn(&run_browser.step);

    const check_step = addCheckStep(b, build_options_module, test_config_module, optimize);

    // src/main.zig is an empty stub, so `zig build` on its own compiles almost
    // none of the library. Hanging the check off the default and test steps is
    // what makes either command a real signal.
    b.getInstallStep().dependOn(check_step);
    test_step.dependOn(check_step);
}

/// Zig analyses declarations lazily, so `zig build` and `zig build test` only
/// type-check the code they happen to reach. `src/check.zig` references every
/// public declaration in the library; compiling it is what turns the build into
/// a real gate.
fn addCheckStep(
    b: *std.Build,
    build_options_module: *std.Build.Module,
    config_module: *std.Build.Module,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Step {
    const check_step = b.step("check", "Type-check every source file in the library");

    verifyCheckRootIsComplete(b, check_step);

    // wasm32-wasi is what ships, and it alone catches target-specific breakage
    // such as invalid `export` signatures. The host target is checked too
    // because the SSR path in HtmlGenerator and File only builds there.
    //
    // Native hosts need two things wasm does not:
    //
    //   link_libc  the SSR path reaches std.heap's C allocator, which is a
    //              compile error without it. macOS links libc implicitly, so
    //              omitting this only fails on Linux — i.e. only in CI.
    //   pic        WASM.zig declares its imports as `extern "env"`. On
    //              x86_64-linux that is a dynamic-library dependency and needs
    //              position-independent code.
    const CheckTarget = struct {
        name: []const u8,
        query: std.Target.Query,
        native_host: bool,
    };
    const targets = [_]CheckTarget{
        .{
            .name = "vapor-check-wasm",
            .query = .{ .cpu_arch = .wasm32, .os_tag = .wasi },
            .native_host = false,
        },
        .{
            .name = "vapor-check-host",
            .query = .{},
            .native_host = true,
        },
        // Explicit Linux, so a macOS developer sees what CI sees.
        .{
            .name = "vapor-check-linux",
            .query = .{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .gnu },
            .native_host = true,
        },
    };

    for (targets) |check_target| {
        const target = b.resolveTargetQuery(check_target.query);
        const name = check_target.name;
        const theme_module = b.createModule(.{
            .root_source_file = b.path("tests/support/theme.zig"),
            .target = target,
            .optimize = optimize,
        });

        const check_module = b.createModule(.{
            .root_source_file = b.path("src/check.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "build_options", .module = build_options_module },
                .{ .name = "config", .module = config_module },
                .{ .name = "theme", .module = theme_module },
            },
            .link_libc = if (check_target.native_host) true else null,
            .pic = if (check_target.native_host) true else null,
        });

        // tests/support/theme.zig imports "vapor" by name; point it at the same
        // sources the check is compiling so both see one copy of every type.
        theme_module.addImport("vapor", check_module);

        const check_obj = b.addObject(.{
            .name = name,
            .root_module = check_module,
        });

        check_step.dependOn(&check_obj.step);
    }

    return check_step;
}

/// Fails the check if a file under `src/` is missing from `src/check.zig`,
/// so a new module cannot silently opt out of type-checking.
fn verifyCheckRootIsComplete(b: *std.Build, check_step: *std.Build.Step) void {
    const io = b.graph.io;
    const root = b.build_root.handle;

    const contents = root.readFileAlloc(io, "src/check.zig", b.allocator, .limited(1 << 20)) catch |err| {
        std.debug.panic("check: cannot read src/check.zig: {t}", .{err});
    };

    var src_dir = root.openDir(io, "src", .{ .iterate = true }) catch |err| {
        std.debug.panic("check: cannot open src/: {t}", .{err});
    };
    defer src_dir.close(io);

    var walker = src_dir.walk(b.allocator) catch @panic("OOM");
    defer walker.deinit();

    var missing = std.array_list.Managed([]const u8).init(b.allocator);

    while (walker.next(io) catch @panic("walk failed")) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.path, ".zig")) continue;
        if (std.mem.eql(u8, entry.path, "check.zig")) continue;

        // Zig import paths use forward slashes regardless of host.
        const import_path = b.allocator.dupe(u8, entry.path) catch @panic("OOM");
        std.mem.replaceScalar(u8, import_path, std.fs.path.sep, '/');

        const needle = b.fmt("@import(\"{s}\")", .{import_path});
        if (std.mem.indexOf(u8, contents, needle) == null) {
            missing.append(import_path) catch @panic("OOM");
        }
    }

    if (missing.items.len == 0) return;

    var message = std.array_list.Managed(u8).init(b.allocator);
    message.appendSlice(b.fmt(
        "{d} source file(s) under src/ are not listed in src/check.zig, so nothing " ++
            "type-checks them. Add each to `modules` (or to `host_only_modules` if it " ++
            "cannot build for wasm):\n",
        .{missing.items.len},
    )) catch @panic("OOM");
    for (missing.items) |path| {
        message.appendSlice(b.fmt("    @import(\"{s}\"),\n", .{path})) catch @panic("OOM");
    }

    const fail = b.addFail(message.items);
    check_step.dependOn(&fail.step);
}
