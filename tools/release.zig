//! Finishes a release build of a static site (see `addRelease` in build.zig).
//!
//! Browsers keep a file for as long as the host says it may, so a file that
//! changes under the same name can stay stale in a visitor's cache. A release
//! names every file that changes between builds by a hash of its contents:
//! the wasm, the JS runtime and the generated CSS move to `_vapor/` as e.g.
//! `vapor.3f9a1c7b20.wasm`, and every page is rewritten to load those names.
//! The host can then cache `_vapor/` forever and only has to revalidate the
//! HTML, which is what names them.
//!
//! Usage:
//!   vapor-release clean <site dir>
//!   vapor-release fingerprint <site dir> --wasm=<path> --bundle=<path>
//!       --browser=<path> [--wasm-br=<path>] [--shell=<template.html>]
//!       [--assets=<dir>] [--copy=<path>]...
//!
//! `clean` deletes the site directory so a release holds only what this build
//! wrote. `fingerprint` runs after the static generator has written the pages,
//! or, for a client-rendered site, with `--shell`: the template becomes the
//! site's only page, index.html, and `--assets` is copied beside it (the
//! generator does both when it runs).

const std = @import("std");

/// The directory, under the site root, that holds the hashed files.
pub const hashed_dir = "_vapor";

/// Characters of the hex SHA-256 digest kept in a hashed name.
const hash_len = 10;

const max_file_size = 64 * 1024 * 1024;

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const gpa = init.gpa;

    var args = try init.minimal.args.iterateAllocator(gpa);
    defer args.deinit();
    _ = args.next();
    const command = args.next() orelse return usage();
    const site_path = args.next() orelse return usage();

    const cwd = std.Io.Dir.cwd();

    if (std.mem.eql(u8, command, "clean")) {
        try cwd.deleteTree(io, site_path);
        return;
    }
    if (!std.mem.eql(u8, command, "fingerprint")) return usage();

    var wasm_path: ?[]const u8 = null;
    var wasm_br_path: ?[]const u8 = null;
    var bundle_path: ?[]const u8 = null;
    var browser_path: ?[]const u8 = null;
    var shell_path: ?[]const u8 = null;
    var assets_path: ?[]const u8 = null;
    var copies: std.ArrayList([]const u8) = .empty;
    defer copies.deinit(gpa);
    while (args.next()) |arg| {
        if (option(arg, "--wasm=")) |v| {
            wasm_path = v;
        } else if (option(arg, "--wasm-br=")) |v| {
            wasm_br_path = v;
        } else if (option(arg, "--bundle=")) |v| {
            bundle_path = v;
        } else if (option(arg, "--browser=")) |v| {
            browser_path = v;
        } else if (option(arg, "--shell=")) |v| {
            shell_path = v;
        } else if (option(arg, "--assets=")) |v| {
            assets_path = v;
        } else if (option(arg, "--copy=")) |v| {
            try copies.append(gpa, v);
        } else return usage();
    }

    try cwd.createDirPath(io, site_path);
    var site = try cwd.openDir(io, site_path, .{ .iterate = true });
    defer site.close(io);
    try site.createDirPath(io, hashed_dir);

    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    if (shell_path) |path| {
        try cwd.copyFile(path, site, "index.html", io, .{});
    }
    if (assets_path) |path| {
        try copyTree(io, gpa, cwd, path, site, "assets");
    }

    // The wasm, compressed next to it under the same hashed name when the
    // build made a .br, so a host serving precompressed files finds it.
    const wasm = try readFile(io, cwd, arena, wasm_path orelse return usage());
    const wasm_url = try writeHashed(io, site, arena, "vapor", ".wasm", wasm);
    if (wasm_br_path) |path| {
        const br = try readFile(io, cwd, arena, path);
        try site.writeFile(io, .{ .sub_path = try std.fmt.allocPrint(arena, "{s}.br", .{wasm_url[1..]}), .data = br });
    }
    const bundle_url = try writeHashed(io, site, arena, "bundle", ".js", try readFile(io, cwd, arena, bundle_path orelse return usage()));
    const browser_url = try writeHashed(io, site, arena, "browser", ".js", try readFile(io, cwd, arena, browser_path orelse return usage()));

    // The generator's stylesheets, which pages link from /static/.
    const style_url = try moveHashed(io, site, arena, "static/style.css", "style", ".css");
    const vars_url = try moveHashed(io, site, arena, "static/style_variables.css", "style_variables", ".css");
    // Gone when the stylesheets were all the generator put there.
    site.deleteDir(io, "static") catch {};

    // The generator also copies the runtime unhashed beside the pages; with
    // every page loading the hashed copies, those would only go stale.
    for ([_][]const u8{ "bundle.min.js", "browser.min.js" }) |name| {
        site.deleteFile(io, name) catch |err| switch (err) {
            error.FileNotFound => {},
            else => return err,
        };
    }

    for (copies.items) |path| {
        try cwd.copyFile(path, site, std.fs.path.basename(path), io, .{});
    }

    const urls: Urls = .{
        .wasm = wasm_url,
        .bundle = bundle_url,
        .browser = browser_url,
        .style = style_url,
        .style_variables = vars_url,
    };

    var walker = try site.walk(gpa);
    defer walker.deinit();
    var pages: usize = 0;
    while (try walker.next(io)) |entry| {
        if (entry.kind != .file or !std.mem.endsWith(u8, entry.basename, ".html")) continue;
        const html = try site.readFileAlloc(io, entry.path, arena, .limited(max_file_size));
        const rewritten = rewritePage(arena, html, urls) catch |err| {
            std.debug.print("vapor-release: {s}/{s}: {s}\n", .{ site_path, entry.path, switch (err) {
                error.NoBundleScript => "the page does not load \"/bundle.min.js\"; template.html must load the runtime from there",
                error.NoHtmlTag => "the page has no <html> tag",
                else => @errorName(err),
            } });
            std.process.exit(1);
        };
        try site.writeFile(io, .{ .sub_path = entry.path, .data = rewritten });
        pages += 1;
    }

    std.debug.print("vapor-release: {d} pages now load {s} and {s}\n", .{ pages, wasm_url, bundle_url });
}

fn usage() error{InvalidArguments} {
    std.debug.print(
        \\usage: vapor-release clean <site dir>
        \\       vapor-release fingerprint <site dir> --wasm=<path> --bundle=<path> --browser=<path>
        \\           [--wasm-br=<path>] [--shell=<template.html>] [--assets=<dir>] [--copy=<path>]...
        \\
    , .{});
    return error.InvalidArguments;
}

/// Copies the directory `src_path` to `dest_name` in `dest`, if it exists.
fn copyTree(io: std.Io, gpa: std.mem.Allocator, cwd: std.Io.Dir, src_path: []const u8, dest: std.Io.Dir, dest_name: []const u8) !void {
    var src = cwd.openDir(io, src_path, .{ .iterate = true }) catch |err| switch (err) {
        error.FileNotFound => return,
        else => return err,
    };
    defer src.close(io);
    try dest.createDirPath(io, dest_name);
    var out = try dest.openDir(io, dest_name, .{});
    defer out.close(io);

    var walker = try src.walk(gpa);
    defer walker.deinit();
    while (try walker.next(io)) |entry| switch (entry.kind) {
        .directory => try out.createDirPath(io, entry.path),
        .file => try src.copyFile(entry.path, out, entry.path, io, .{}),
        else => {},
    };
}

fn option(arg: []const u8, comptime prefix: []const u8) ?[]const u8 {
    if (!std.mem.startsWith(u8, arg, prefix)) return null;
    return arg[prefix.len..];
}

fn readFile(io: std.Io, dir: std.Io.Dir, arena: std.mem.Allocator, path: []const u8) ![]u8 {
    return dir.readFileAlloc(io, path, arena, .limited(max_file_size)) catch |err| {
        std.debug.print("vapor-release: reading {s}: {s}\n", .{ path, @errorName(err) });
        return err;
    };
}

/// `<stem>.<hash><ext>`, the name a file with `data` gets.
pub fn hashedName(arena: std.mem.Allocator, stem: []const u8, ext: []const u8, data: []const u8) ![]const u8 {
    var digest: [std.crypto.hash.sha2.Sha256.digest_length]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(data, &digest, .{});
    const hex = std.fmt.bytesToHex(digest, .lower);
    return std.fmt.allocPrint(arena, "{s}.{s}{s}", .{ stem, hex[0..hash_len], ext });
}

/// Writes `data` to `_vapor/` under its hashed name and returns its URL.
fn writeHashed(io: std.Io, site: std.Io.Dir, arena: std.mem.Allocator, stem: []const u8, ext: []const u8, data: []const u8) ![]const u8 {
    const name = try hashedName(arena, stem, ext, data);
    const sub_path = try std.fmt.allocPrint(arena, hashed_dir ++ "/{s}", .{name});
    try site.writeFile(io, .{ .sub_path = sub_path, .data = data });
    return std.fmt.allocPrint(arena, "/{s}", .{sub_path});
}

/// Moves the site file `sub_path` to `_vapor/` under its hashed name and
/// returns its URL, or null when the build did not write it.
fn moveHashed(io: std.Io, site: std.Io.Dir, arena: std.mem.Allocator, sub_path: []const u8, stem: []const u8, ext: []const u8) !?Moved {
    const data = site.readFileAlloc(io, sub_path, arena, .limited(max_file_size)) catch |err| switch (err) {
        error.FileNotFound => return null,
        else => return err,
    };
    const url = try writeHashed(io, site, arena, stem, ext, data);
    try site.deleteFile(io, sub_path);
    return .{ .from = try std.fmt.allocPrint(arena, "/{s}", .{sub_path}), .to = url };
}

const Moved = struct { from: []const u8, to: []const u8 };

pub const Urls = struct {
    wasm: []const u8,
    bundle: []const u8,
    browser: []const u8,
    style: ?Moved = null,
    style_variables: ?Moved = null,
};

/// The page `html` loading the hashed files: the runtime script and the wasm
/// preload point at their new names, the stylesheets too, and <html> says
/// where the runtime finds the wasm and the browser bindings.
pub fn rewritePage(arena: std.mem.Allocator, html: []const u8, urls: Urls) ![]const u8 {
    if (std.mem.indexOf(u8, html, "\"/bundle.min.js\"") == null) return error.NoBundleScript;

    var page = html;
    page = try replaceQuoted(arena, page, "/bundle.min.js", urls.bundle);
    page = try replaceQuoted(arena, page, "/zig-out/bin/vapor.wasm", urls.wasm);
    for ([_]?Moved{ urls.style, urls.style_variables }) |moved| {
        if (moved) |m| page = try replaceQuoted(arena, page, m.from, m.to);
    }

    const html_tag = std.mem.indexOf(u8, page, "<html") orelse return error.NoHtmlTag;
    const at = html_tag + "<html".len;
    return std.fmt.allocPrint(arena, "{s} data-vapor-wasm=\"{s}\" data-vapor-browser=\"{s}\"{s}", .{
        page[0..at], urls.wasm, urls.browser, page[at..],
    });
}

/// `text` with every `"from"` (in double quotes) replaced by `"to"`.
fn replaceQuoted(arena: std.mem.Allocator, text: []const u8, from: []const u8, to: []const u8) ![]const u8 {
    const quoted_from = try std.fmt.allocPrint(arena, "\"{s}\"", .{from});
    const quoted_to = try std.fmt.allocPrint(arena, "\"{s}\"", .{to});
    return std.mem.replaceOwned(u8, arena, text, quoted_from, quoted_to);
}

test "a hashed name changes with the contents and keeps the extension" {
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const a = try hashedName(arena, "vapor", ".wasm", "one");
    const b = try hashedName(arena, "vapor", ".wasm", "two");
    try std.testing.expect(!std.mem.eql(u8, a, b));
    try std.testing.expectEqualStrings(a, try hashedName(arena, "vapor", ".wasm", "one"));
    try std.testing.expect(std.mem.startsWith(u8, a, "vapor."));
    try std.testing.expect(std.mem.endsWith(u8, a, ".wasm"));
    try std.testing.expectEqual("vapor.".len + hash_len + ".wasm".len, a.len);
}

test "a page is pointed at the hashed files" {
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const html =
        \\<!doctype html>
        \\<html lang="en">
        \\<head>
        \\  <link rel="preload" href="/zig-out/bin/vapor.wasm" as="fetch" />
        \\  <script type="module" src="/bundle.min.js"></script>
        \\  <!-- <script src="/web/bundle.min.js"></script> -->
        \\  <link rel="stylesheet" href="/static/style.css" />
        \\</head>
        \\</html>
    ;
    const out = try rewritePage(arena, html, .{
        .wasm = "/_vapor/vapor.aaaa.wasm",
        .bundle = "/_vapor/bundle.bbbb.js",
        .browser = "/_vapor/browser.cccc.js",
        .style = .{ .from = "/static/style.css", .to = "/_vapor/style.dddd.css" },
    });
    try std.testing.expect(std.mem.indexOf(u8, out, "<html data-vapor-wasm=\"/_vapor/vapor.aaaa.wasm\" data-vapor-browser=\"/_vapor/browser.cccc.js\" lang=\"en\">") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "src=\"/_vapor/bundle.bbbb.js\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "href=\"/_vapor/vapor.aaaa.wasm\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "href=\"/_vapor/style.dddd.css\"") != null);
    // Only the exact quoted URL is replaced.
    try std.testing.expect(std.mem.indexOf(u8, out, "\"/web/bundle.min.js\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "\"/bundle.min.js\"") == null);
}

test "a page that does not load the runtime is refused" {
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    try std.testing.expectError(error.NoBundleScript, rewritePage(arena_state.allocator(), "<html><script src=\"/app.js\"></script></html>", .{
        .wasm = "w",
        .bundle = "b",
        .browser = "r",
    }));
}
