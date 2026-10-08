//! Fails when the wasm declares an import the JS runtime does not provide.
//!
//! Every `extern fn` in vapor becomes a wasm import from module "env", and the
//! browser refuses to instantiate the module (LinkError) if any one of them is
//! missing from the runtime — for every app that reaches that function, not
//! just the one that calls it. Zig cannot see the JS side, so nothing else
//! catches the drift.
//!
//! Usage: check_abi <src dir> <bundle.min.js>
//!
//! The check is textual: an import counts as provided if its name appears in
//! the bundle as an identifier. Object keys survive minification, so this is
//! reliable for the runtime's `env` table.

const std = @import("std");

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const gpa = init.gpa;

    var args = try init.minimal.args.iterateAllocator(gpa);
    defer args.deinit();
    _ = args.next();
    const src_path = args.next() orelse return usage();
    const bundle_path = args.next() orelse return usage();

    const cwd = std.Io.Dir.cwd();
    const bundle = try cwd.readFileAlloc(io, bundle_path, gpa, .limited(16 * 1024 * 1024));
    defer gpa.free(bundle);

    var src_dir = try cwd.openDir(io, src_path, .{ .iterate = true });
    defer src_dir.close(io);

    var walker = try src_dir.walk(gpa);
    defer walker.deinit();

    var missing: usize = 0;
    var total: usize = 0;
    while (try walker.next(io)) |entry| {
        if (entry.kind != .file or !std.mem.endsWith(u8, entry.basename, ".zig")) continue;
        const text = try src_dir.readFileAlloc(io, entry.path, gpa, .limited(16 * 1024 * 1024));
        defer gpa.free(text);

        var lines = std.mem.splitScalar(u8, text, '\n');
        var line_no: usize = 0;
        while (lines.next()) |line| {
            line_no += 1;
            const name = externName(line) orelse continue;
            total += 1;
            if (!containsIdentifier(bundle, name)) {
                missing += 1;
                std.debug.print("{s}/{s}:{d}: extern fn {s} has no implementation in {s}\n", .{
                    src_path, entry.path, line_no, name, bundle_path,
                });
            }
        }
    }

    if (missing > 0) {
        std.debug.print("\n{d} of {d} wasm imports are missing from the JS runtime.\n", .{ missing, total });
        std.process.exit(1);
    }
}

fn usage() error{InvalidArguments} {
    std.debug.print("usage: check_abi <src dir> <bundle.min.js>\n", .{});
    return error.InvalidArguments;
}

/// The function name of an `extern fn` declaration on this line, if any.
/// Commented-out declarations are skipped.
fn externName(line: []const u8) ?[]const u8 {
    const trimmed = std.mem.trimStart(u8, line, " \t");
    if (std.mem.startsWith(u8, trimmed, "//")) return null;

    var rest = trimmed;
    if (std.mem.startsWith(u8, rest, "pub ")) rest = rest["pub ".len..];
    if (!std.mem.startsWith(u8, rest, "extern ")) return null;
    rest = rest["extern ".len..];

    // An explicit library other than "env" is not a JS import.
    if (rest.len > 0 and rest[0] == '"') {
        if (!std.mem.startsWith(u8, rest, "\"env\" ")) return null;
        rest = rest["\"env\" ".len..];
    }
    if (!std.mem.startsWith(u8, rest, "fn ")) return null;
    rest = rest["fn ".len..];

    var end: usize = 0;
    while (end < rest.len and isIdentChar(rest[end])) end += 1;
    if (end == 0) return null;
    return rest[0..end];
}

fn isIdentChar(c: u8) bool {
    return std.ascii.isAlphanumeric(c) or c == '_' or c == '$';
}

fn containsIdentifier(haystack: []const u8, name: []const u8) bool {
    var from: usize = 0;
    while (std.mem.indexOfPos(u8, haystack, from, name)) |at| {
        const before_ok = at == 0 or !isIdentChar(haystack[at - 1]);
        const after = at + name.len;
        const after_ok = after == haystack.len or !isIdentChar(haystack[after]);
        if (before_ok and after_ok) return true;
        from = at + 1;
    }
    return false;
}

test externName {
    try std.testing.expectEqualStrings("foo", externName("pub extern fn foo(a: u32) void;").?);
    try std.testing.expectEqualStrings("bar", externName("    extern \"env\" fn bar() void;").?);
    try std.testing.expectEqual(null, externName("// pub extern fn commented() void;"));
    try std.testing.expectEqual(null, externName("extern \"c\" fn write(fd: i32) isize;"));
    try std.testing.expectEqual(null, externName("pub fn notExtern() void {}"));
}

test containsIdentifier {
    try std.testing.expect(containsIdentifier("{tick:()=>1}", "tick"));
    try std.testing.expect(!containsIdentifier("{ticker:()=>1}", "tick"));
    try std.testing.expect(!containsIdentifier("{_tick:()=>1}", "tick"));
}
