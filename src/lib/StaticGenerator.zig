const Vapor = @import("Vapor.zig");
const HtmlGenerator = @import("HtmlGenerator.zig");
const StyleCompiler = @import("convertStyleCustomWriter.zig");
const UIContext = @import("UITree.zig");
const std = @import("std");

pub const release_dir = "release";

/// Aborts static generation with a diagnostic.
///
/// Generation runs in the CLI, not the browser, so failing hard on a bad path
/// or a full disk is right. `unreachable` is the wrong way to say that: it is
/// undefined behaviour under ReleaseFast/ReleaseSmall, and it prints nothing.
/// This names the operation and the path, and aborts identically in every
/// optimize mode.
pub fn generatorFatal(comptime what: []const u8, err: anyerror, path: []const u8) noreturn {
    std.debug.print("vapor: static generation failed: " ++ what ++ ": '{s}': {any}\n", .{ path, err });
    @panic("static generation failed");
}

/// `createDirPath` when the directory already existing is success.
pub fn ensureDir(io: anytype, cwd: std.Io.Dir, path: []const u8) void {
    cwd.createDirPath(io, path) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => generatorFatal("creating directory", err, path),
    };
}

pub fn generate() void {
    Vapor.generating = true;
    const cwd = std.Io.Dir.cwd();
    var threaded: std.Io.Threaded = .init_single_threaded;
    const io = threaded.io();

    // Create release/ and release/static/
    ensureDir(io, cwd, release_dir);
    const static_dir = std.fmt.allocPrint(Vapor.allocator_global, "{s}/static", .{release_dir}) catch |err|
        generatorFatal("building the static/ path", err, release_dir);
    ensureDir(io, cwd, static_dir);

    // CSS variables into release/static/
    const css_vars_path = std.fmt.allocPrint(Vapor.allocator_global, "{s}/static/style_variables.css", .{release_dir}) catch |err|
        generatorFatal("building the style_variables.css path", err, release_dir);
    var css_variables = cwd.createFile(io, css_vars_path, .{}) catch |err|
        generatorFatal("creating file", err, css_vars_path);
    css_variables.writePositionalAll(io, StyleCompiler.global_style, 0) catch |err|
        generatorFatal("writing file", err, css_vars_path);

    // The client-rendered shell, for paths no prerendered page covers:
    // dynamic routes and unknown paths (which render the /error page). Point
    // the host's fallback for unmatched paths at it.
    const shell_path = std.fmt.allocPrint(Vapor.allocator_global, "{s}/app.html", .{release_dir}) catch |err|
        generatorFatal("building the app.html path", err, release_dir);
    cwd.copyFile("template.html", cwd, shell_path, io, .{}) catch |err|
        generatorFatal("copying template.html to", err, shell_path);

    var page_itr = Vapor.page_map.iterator();
    while (page_itr.next()) |entry| {
        Vapor.writer = std.Io.Writer.fixed(&Vapor.buffer);
        const route = entry.key_ptr.*;

        // A dynamic route has no single page to prerender; it renders on the
        // client from app.html. (Writing it out produced literal `:id`
        // directories that no URL maps to.)
        if (std.mem.indexOf(u8, route, "/:") != null) {
            std.debug.print("client-rendered only (dynamic): {s}\n", .{route[@min(route.len, 5)..]});
            continue;
        }

        // Strip "/root" — "/root/components" becomes "/components"
        const stripped = if (route.len > 5) route[5..] else "/";
        const dir = if (stripped.len > 1) stripped[1..] else "";

        // Create nested dirs under release/
        if (dir.len > 0) {
            var sub_dirs = std.mem.tokenizeScalar(u8, dir, '/');
            var current_dir: []const u8 = release_dir;
            while (sub_dirs.next()) |sub_dir| {
                current_dir = std.fmt.allocPrint(Vapor.allocator_global, "{s}/{s}", .{
                    current_dir,
                    sub_dir,
                }) catch |err| generatorFatal("building a route directory path", err, sub_dir);
                ensureDir(io, cwd, current_dir);
            }
        }

        // release/index.html or release/components/index.html
        const path = if (dir.len == 0)
            std.fmt.allocPrint(Vapor.allocator_global, "{s}/index.html", .{release_dir}) catch |err|
                generatorFatal("building the index.html path", err, release_dir)
        else
            std.fmt.allocPrint(Vapor.allocator_global, "{s}/{s}/index.html", .{ release_dir, dir }) catch |err|
                generatorFatal("building the index.html path", err, dir);
        defer Vapor.allocator_global.free(path);

        Vapor.generated_file = cwd.createFile(io, path, .{}) catch |err|
            generatorFatal("creating file", err, path);
        defer Vapor.generated_file.close(io);

        generateHtml(route, dir);
        _ = Vapor.generated_file.writePositionalAll(io, Vapor.writer.buffer[0..Vapor.writer.end], 0) catch |err|
            generatorFatal("writing file", err, path);
    }
    const assets_dest = std.fmt.allocPrint(Vapor.allocator_global, "{s}/assets", .{release_dir}) catch |err|
        generatorFatal("building the assets/ path", err, release_dir);
    copyDirRecursive(io, cwd, "assets", assets_dest);

    // Copy the JS runtime into release/. The build installs the copy that
    // ships with this vapor version to zig-out/bin/, which is the one that
    // matches the wasm; the other locations are for projects that predate it.
    var dest_dir = cwd.openDir(io, release_dir, .{}) catch return;
    defer dest_dir.close(io);
    // browser.min.js (optional browser-API bindings) is loaded from beside the
    // core bundle, so it goes along when the build installed it.
    cwd.copyFile("zig-out/bin/browser.min.js", dest_dir, "browser.min.js", io, .{}) catch {};
    const bundle_sources = [_][]const u8{ "zig-out/bin/bundle.min.js", "bundle.min.js", "static/bundle.min.js" };
    const copied = for (bundle_sources) |src| {
        cwd.copyFile(src, dest_dir, "bundle.min.js", io, .{}) catch continue;
        break true;
    } else false;
    if (!copied) {
        if (dest_dir.access(io, "bundle.min.js", .{})) |_| {} else |_| {
            std.debug.print("warning: no bundle.min.js found (looked in zig-out/bin/, ./ and static/); {s}/ will not load\n", .{release_dir});
        }
    }

    Vapor.generating = false;
}

pub fn generateHtml(route: []const u8, dir: []const u8) void {
    _ = dir;
    const cwd = std.Io.Dir.cwd();
    var threaded: std.Io.Threaded = .init_single_threaded;
    const io = threaded.io();

    Vapor.status = .{};
    Vapor.frame_arena.beginFrame(); // For double-buffered approach
    Vapor.frame_arena.resetScratchArena();

    if (!std.mem.eql(u8, Vapor.current_route, route)) {
        Vapor.changed_route = true;
        // We need to start a new route allocator
        // otherwise we are on the same route
        Vapor.frame_arena.beginView();
    }

    Vapor.current_route = route;
    Vapor.added_nodes.clearRetainingCapacity();
    Vapor.dirty_nodes.clearRetainingCapacity();
    Vapor.nodes_with_events.clearRetainingCapacity();

    const old_route_op = Vapor.router.searchRoute(route) orelse blk: {
        Vapor.printlnSrcErr("No Route found", .{}, @src());
        break :blk Vapor.router.searchRoute("/root/error") orelse {
            Vapor.printlnSrcErr("No Error Route found", .{}, @src());
            Vapor.status.valid_url = false;
            break :blk null;
        };
    };
    if (old_route_op) |old_route| {
        Vapor.render_page = old_route.page;
        Vapor.route_params = old_route.params;
    } else {
        Vapor.render_page = Vapor.DefaultPage;
        Vapor.route_params = &.{};
    }

    const old_ctx = Vapor.current_ctx;
    // Create new context
    const new_ctx: *UIContext = Vapor.arena(.frame).create(UIContext) catch {
        Vapor.status.render_cycle = false;
        Vapor.println("Failed to allocate UIContext\n", .{});
        return;
    };

    UIContext.initContext(new_ctx) catch |err| {
        Vapor.status.render_cycle = false;
        Vapor.println("Allocator ran out of space {any}\n", .{err});
        new_ctx.deinit();
        Vapor.allocator_global.destroy(new_ctx);
        return;
    };

    new_ctx.root.?.uuid = old_ctx.root.?.uuid;

    Vapor.current_ctx = new_ctx;
    var route_itr = std.mem.tokenizeScalar(u8, route, '/');
    var count: usize = 0;
    while (route_itr.next()) |_| {
        count += 1;
    }
    Vapor.route_segments = Vapor.allocator_global.alloc([]const u8, count) catch return;
    count = 0;
    route_itr.reset();
    while (route_itr.next()) |route_token| {
        Vapor.route_segments[count] = route_token;
        count += 1;
    }

    // Init the generator
    Vapor.generator.init();
    Vapor.next_layout_path_to_check = "";
    Vapor.findResetLayout();
    // This calls the render tree, with render_page as the root function call
    // First it traverses the layouts calling them in order, and then it calls the render_page
    Vapor.callNestedLayouts(); // 4.5ms

    Vapor.changed_route = false;
    Vapor.generator.writeAllStyles();
    const css = Vapor.generator.getCSS();
    const frames = Vapor.generator.getAnimations();

    // Write CSS to release/static/
    const style_fs_path = std.fmt.allocPrint(Vapor.allocator_global, "{s}/static/style.css", .{release_dir}) catch |err|
        generatorFatal("building the style.css path", err, release_dir);

    var generated_css = cwd.createFile(io, style_fs_path, .{}) catch |err|
        generatorFatal("creating file", err, style_fs_path);
    defer generated_css.close(io);
    generated_css.writePositionalAll(io, css, 0) catch |err|
        generatorFatal("writing css", err, style_fs_path);
    const stat = generated_css.stat(io) catch |err|
        generatorFatal("stat", err, style_fs_path);
    generated_css.writePositionalAll(io, frames, stat.size) catch |err|
        generatorFatal("writing keyframes", err, style_fs_path);

    // Browser URL — not filesystem path
    HtmlGenerator.generate(new_ctx.root.?, &Vapor.writer, "/static/style.css");
}

pub fn copyDirRecursive(io: anytype, cwd: std.Io.Dir, src: []const u8, dest: []const u8) void {
    // Ensure destination exists
    ensureDir(io, cwd, dest);

    var src_dir = cwd.openDir(io, src, .{ .iterate = true }) catch return;
    defer src_dir.close(io);

    var dest_dir = cwd.openDir(io, dest, .{}) catch return;
    defer dest_dir.close(io);

    var iter = src_dir.iterate();
    while (iter.next(io) catch return) |entry| {
        switch (entry.kind) {
            .directory => {
                const src_path = std.fmt.allocPrint(Vapor.allocator_global, "{s}/{s}", .{ src, entry.name }) catch |err|
                    generatorFatal("building a source path", err, src);
                const dest_path = std.fmt.allocPrint(Vapor.allocator_global, "{s}/{s}", .{ dest, entry.name }) catch |err|
                    generatorFatal("building a destination path", err, dest);
                copyDirRecursive(io, cwd, src_path, dest_path);
            },
            .file => {
                src_dir.copyFile(entry.name, dest_dir, entry.name, io, .{}) catch |err| {
                    std.debug.print("Copy error: {any} {s}/{s}\n", .{ err, src, entry.name });
                };
            },
            else => {},
        }
    }
}
