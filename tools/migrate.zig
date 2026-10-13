//! Rewrites an app's Zig source for the renamed and removed vapor APIs.
//!
//! Usage: migrate [--write] <file or dir>...
//!
//! Without `--write` it only lists what it would change. It edits text, not
//! the syntax tree, so it keeps to forms it can recognise exactly and reports
//! anything else for a person to fix:
//!
//! - Renames: `Vapor.Binded` -> `Vapor.Element`, `.square_px(` ->
//!   `.squarePx(`, `.fontColor(` -> `.textColor(`, `Vapor.printErr(` ->
//!   `Vapor.print(.err, `, ... (see `renames`). `Vapor.Kit.init();` is
//!   removed; `Vapor.init` does its work.
//! - Sides: inside `.padding = `, `.padding(`, `.margin = `, `.margin(`,
//!   `.thickness = ` and a border's first argument, constructors such as
//!   `.left(12)`, `.tb(8, 4)` or `.tblr(1, 0, 1, 1)` become literals
//!   (`.{ .left = 12 }`, ...); a border's one-value `.tb(1)` / `.lr(1)`
//!   become `.vertical(1)` / `.horizontal(1)`.
//! - Visual borders: `.border_thickness`, `.border_color` and
//!   `.border_radius` in a `.visual`, `.hover`, `.focus` or `.focus_within`
//!   block merge into one `.border = .{ ... }`.
//!
//! Strings and comments are left alone. Run `zig fmt` afterwards.

const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const gpa = init.gpa;

    var args = try init.minimal.args.iterateAllocator(gpa);
    defer args.deinit();
    _ = args.next();

    var write = false;
    var paths: std.ArrayList([]const u8) = .empty;
    defer paths.deinit(gpa);
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--write")) {
            write = true;
        } else {
            try paths.append(gpa, arg);
        }
    }
    if (paths.items.len == 0) {
        std.debug.print("usage: migrate [--write] <file or dir>...\n", .{});
        return error.InvalidArguments;
    }

    var totals: Totals = .{};
    const cwd = std.Io.Dir.cwd();
    for (paths.items) |path| {
        const stat = try cwd.statFile(io, path, .{});
        if (stat.kind == .directory) {
            var dir = try cwd.openDir(io, path, .{ .iterate = true });
            defer dir.close(io);
            var walker = try dir.walk(gpa);
            defer walker.deinit();
            while (try walker.next(io)) |entry| {
                if (entry.kind != .file or !std.mem.endsWith(u8, entry.basename, ".zig")) continue;
                if (skipped(entry.path)) continue;
                const shown = try std.fs.path.join(gpa, &.{ path, entry.path });
                defer gpa.free(shown);
                try migrateFile(io, gpa, dir, entry.path, shown, write, &totals);
            }
        } else {
            try migrateFile(io, gpa, cwd, path, path, write, &totals);
        }
    }

    std.debug.print("\n{d} change(s) in {d} file(s){s}; {d} place(s) to fix by hand.\n", .{
        totals.changes,
        totals.files,
        if (write) "" else " (dry run: pass --write to apply)",
        totals.manual,
    });
}

const Totals = struct { changes: usize = 0, files: usize = 0, manual: usize = 0 };

/// Build output and fetched packages are not the app's source.
fn skipped(path: []const u8) bool {
    var parts = std.mem.tokenizeAny(u8, path, "/\\");
    while (parts.next()) |part| {
        if (std.mem.eql(u8, part, ".zig-cache") or std.mem.eql(u8, part, "zig-out") or
            std.mem.eql(u8, part, "zig-pkg")) return true;
    }
    return false;
}

fn migrateFile(io: std.Io, gpa: Allocator, dir: std.Io.Dir, sub_path: []const u8, shown: []const u8, write: bool, totals: *Totals) !void {
    const text = try dir.readFileAlloc(io, sub_path, gpa, .limited(64 * 1024 * 1024));
    defer gpa.free(text);

    var arena_state = std.heap.ArenaAllocator.init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    var report: Report = .{};
    const result = try migrate(arena, text, &report);

    for (report.notes.items) |note| {
        const tag = if (note.manual) "fix by hand" else "change";
        std.debug.print("{s}:{d}: {s}: {s}\n", .{ shown, note.line, tag, note.msg });
        if (note.manual) totals.manual += 1 else totals.changes += 1;
    }
    if (std.mem.eql(u8, result, text)) return;
    totals.files += 1;
    if (write) try dir.writeFile(io, .{ .sub_path = sub_path, .data = result });
}

pub const Note = struct { line: usize, manual: bool, msg: []const u8 };

pub const Report = struct {
    notes: std.ArrayList(Note) = .empty,

    fn add(self: *Report, arena: Allocator, text: []const u8, index: usize, manual: bool, comptime fmt: []const u8, args: anytype) !void {
        const line = std.mem.count(u8, text[0..index], "\n") + 1;
        try self.notes.append(arena, .{ .line = line, .manual = manual, .msg = try std.fmt.allocPrint(arena, fmt, args) });
    }
};

/// Applies every rewrite to `src`. Notes go to `report`; their line numbers
/// refer to the input of the pass that made them, which only the last pass
/// (border merging, which deletes lines) changes.
pub fn migrate(arena: Allocator, src: []const u8, report: *Report) ![]const u8 {
    var text = try applyRenames(arena, src, report);
    text = try applySideLiterals(arena, text, report);
    text = try mergeBorders(arena, text, report);
    return text;
}

// ── Lexing ──────────────────────────────────────────────────────────────────

/// `true` for each byte of code, `false` inside strings, character literals
/// and comments.
fn codeMask(arena: Allocator, text: []const u8) ![]bool {
    const mask = try arena.alloc(bool, text.len);
    @memset(mask, true);
    var i: usize = 0;
    while (i < text.len) {
        const c = text[i];
        const next: u8 = if (i + 1 < text.len) text[i + 1] else 0;
        if ((c == '/' and next == '/') or (c == '\\' and next == '\\')) {
            while (i < text.len and text[i] != '\n') : (i += 1) mask[i] = false;
        } else if (c == '"' or c == '\'') {
            mask[i] = false;
            i += 1;
            while (i < text.len and text[i] != c and text[i] != '\n') : (i += 1) {
                mask[i] = false;
                if (text[i] == '\\' and i + 1 < text.len) {
                    i += 1;
                    mask[i] = false;
                }
            }
            if (i < text.len) mask[i] = false;
            i += 1;
        } else {
            i += 1;
        }
    }
    return mask;
}

fn isIdent(c: u8) bool {
    return std.ascii.isAlphanumeric(c) or c == '_';
}

/// The index of the `)`, `]` or `}` matching the opener just before `start`,
/// or of the first top-level `stop` byte, whichever comes first.
fn spanEnd(text: []const u8, mask: []const bool, start: usize, stops: []const u8) ?usize {
    var depth: usize = 0;
    var i = start;
    while (i < text.len) : (i += 1) {
        if (!mask[i]) continue;
        const c = text[i];
        if (depth == 0 and std.mem.indexOfScalar(u8, stops, c) != null) return i;
        switch (c) {
            '(', '[', '{' => depth += 1,
            ')', ']', '}' => {
                if (depth == 0) return i;
                depth -= 1;
            },
            else => {},
        }
    }
    return null;
}

/// Splits the arguments between `open + 1` and the matching `)` at top-level
/// commas. Returns null when the call is not closed.
fn callArgs(arena: Allocator, text: []const u8, mask: []const bool, open: usize) !?struct { args: [][]const u8, close: usize } {
    var args: std.ArrayList([]const u8) = .empty;
    var arg_start = open + 1;
    while (true) {
        const end = spanEnd(text, mask, arg_start, ",") orelse return null;
        const arg = std.mem.trim(u8, text[arg_start..end], " \t\r\n");
        if (arg.len > 0) try args.append(arena, arg);
        if (text[end] == ')') return .{ .args = args.items, .close = end };
        if (text[end] != ',') return null;
        arg_start = end + 1;
    }
}

// ── Renames ─────────────────────────────────────────────────────────────────

const Rename = struct {
    from: []const u8,
    to: []const u8,
    /// The match must not run into a longer identifier.
    whole: bool = false,
    /// Only a decl literal (`.border(.simple(c))`), not a call on some other
    /// value (`ToolTip.simple(...)`), for names apps also use.
    literal_only: bool = false,
    /// Only a method call on a value (`Box().hide(true)`, possibly on the
    /// next line), not a decl literal (`.background(.gradient(...))`).
    method_only: bool = false,
    /// Not a field of some other value: `Kit.Response`, not `x.Kit.Response`.
    bare: bool = false,
};

/// Every `from` is matched in code only. Entries ending in `(` are calls, so
/// they cannot match a longer name.
const renames = [_]Rename{
    .{ .from = "Vapor.printErr(", .to = "Vapor.print(.err, " },
    .{ .from = "Vapor.lib.printErr(", .to = "Vapor.print(.err, " },
    .{ .from = "Vapor.printlnErr(", .to = "Vapor.print(.err, " },
    .{ .from = "Vapor.lib.printlnErr(", .to = "Vapor.print(.err, " },
    .{ .from = "Vapor.lib.printWarn(", .to = "Vapor.print(.warn, " },
    .{ .from = "Vapor.lib.printInfo(", .to = "Vapor.print(.info, " },
    .{ .from = "Vapor.lib.printDebug(", .to = "Vapor.print(.debug, " },
    // The request arena was never freed: it was the persistent one.
    .{ .from = "arena(.request)", .to = "arena(.persist)" },
    // onEndCtx became onLayout: once, after the render reaches the page.
    .{ .from = "Vapor.onEndCtx(", .to = "Vapor.onLayout(" },
    // Vapor.init sets up what Kit.init did (the fetch registry).
    .{ .from = "Vapor.Kit.init();", .to = "" },
    .{ .from = "Vapor.transparentizeHex(", .to = "Vapor.Types.Color.transparentize(" },
    .{ .from = ".Binded", .to = ".Element", .whole = true },
    .{ .from = ".BorderGrouped", .to = ".Border", .whole = true },
    .{ .from = "Vapor.PureComponentClose", .to = "Vapor.PureComponent", .whole = true },
    .{ .from = "Vapor.BuilderClose", .to = "Vapor.Builder", .whole = true },
    .{ .from = "Vapor.TextAreaBuilder", .to = "Vapor.TextFieldBuilder", .whole = true },
    .{ .from = "Vapor.IconType", .to = "Vapor.IconTokens", .whole = true },
    .{ .from = "KeyStone.signIn(", .to = "KeyStone.signInWithOauth(" },
    .{ .from = "KeyStone.restoreSession(", .to = "KeyStone.bootstrap(" },
    .{ .from = "KeyStone.getSession(", .to = "KeyStone.getAccessToken(" },
    .{ .from = ".square_px(", .to = ".squarePx(" },
    .{ .from = ".square_percent(", .to = ".squarePercent(" },
    .{ .from = ".hw_px(", .to = ".hwPx(" },
    .{ .from = ".hw_percent(", .to = ".hwPercent(" },
    .{ .from = ".min_max_vp(", .to = ".minMaxVp(" },
    .{ .from = ".mobile_desktop_percent(", .to = ".mobileDesktopPercent(" },
    .{ .from = ".mobile_desktop(", .to = ".mobileDesktop(" },
    .{ .from = ".none_x(", .to = ".noneX(" },
    .{ .from = ".none_y(", .to = ".noneY(" },
    .{ .from = ".scroll_x(", .to = ".scrollX(" },
    .{ .from = ".scroll_y(", .to = ".scrollY(" },
    .{ .from = ".top_bottom(", .to = ".topBottom(" },
    .{ .from = ".left_right(", .to = ".leftRight(" },
    .{ .from = ".direction_scale(", .to = ".directionScale(" },
    .{ .from = ".distAndScale(", .to = ".directionScale(" },
    .{ .from = ".left_percent(", .to = ".leftPercent(" },
    .{ .from = ".top_percent(", .to = ".topPercent(" },
    .{ .from = ".size_weight(", .to = ".sizeWeight(" },
    .{ .from = ".size_color(", .to = ".sizeColor(" },
    .{ .from = ".append_str(", .to = ".appendStr(" },
    .{ .from = ".transparentizeHex(", .to = ".transparentize(" },
    .{ .from = ".fontColor(", .to = ".textColor(" },
    .{ .from = ".baseStyle(", .to = ".style(" },
    .{ .from = ".onMountCtx(", .to = ".onMount(" },
    .{ .from = ".onEventCtx(", .to = ".onEvent(" },
    .{ .from = ".anchorPlacement(", .to = ".placement(" },
    .{ .from = ".simple(", .to = ".thin(", .literal_only = true },
    .{ .from = ".hide(", .to = ".hidden(", .method_only = true },
    .{ .from = ".gradient(", .to = ".background(", .method_only = true },
    .{ .from = ".weight(", .to = ".fontWeight(", .method_only = true },
    .{ .from = ".whitespace(", .to = ".whiteSpace(", .method_only = true },
    .{ .from = ".childGap(", .to = ".spacing(", .method_only = true },
    .{ .from = "FormButton(", .to = "SubmitButton(" },
    .{ .from = ".size(.px(", .to = ".size(.squarePx(" },
    .{ .from = ".size(.percent(", .to = ".size(.squarePercent(" },
    .{ .from = ".size = .px(", .to = ".size = .squarePx(" },
    .{ .from = ".size = .percent(", .to = ".size = .squarePercent(" },
    .{ .from = "Size.px(", .to = "Size.squarePx(" },
    .{ .from = "Size.percent(", .to = "Size.squarePercent(" },
    // A border's one-letter sides took the same arguments as the long ones;
    // tb/lr drew 1 pixel.
    .{ .from = ".border(.t(", .to = ".border(.top(" },
    .{ .from = ".border(.b(", .to = ".border(.bottom(" },
    .{ .from = ".border(.l(", .to = ".border(.left(" },
    .{ .from = ".border(.r(", .to = ".border(.right(" },
    .{ .from = ".border(.tb(", .to = ".border(.vertical(1, " },
    .{ .from = ".border(.lr(", .to = ".border(.horizontal(1, " },
    .{ .from = ".border = .t(", .to = ".border = .top(" },
    .{ .from = ".border = .b(", .to = ".border = .bottom(" },
    .{ .from = ".border = .l(", .to = ".border = .left(" },
    .{ .from = ".border = .r(", .to = ".border = .right(" },
    .{ .from = ".border = .tb(", .to = ".border = .vertical(1, " },
    .{ .from = ".border = .lr(", .to = ".border = .horizontal(1, " },
    // BorderThickness.solid was 1 pixel on every side.
    .{ .from = ".sharp(.solid,", .to = ".sharp(.all(1)," },
    .{ .from = ".thickness = .solid", .to = ".thickness = .all(1)", .whole = true },
    .{ .from = "persist.allocator()", .to = "persist.arena()" },
    .{ .from = "persist.Array(", .to = "persist.array(" },
    .{ .from = "view.Array(", .to = "view.array(" },
    .{ .from = "frame.Array(", .to = "frame.array(" },
    .{ .from = "Fetch.Fetch", .to = "Fetch.Request", .whole = true },
    .{ .from = "Vapor.clearPersitantStorage(", .to = "Vapor.clearPersistentStorage(" },
    .{ .from = "Vapor.batch(", .to = "Vapor.cycle(" },
    .{ .from = "Pool.initGlobalPool(", .to = "Pool.init(" },
    .{ .from = "KeyStone.signout(", .to = "KeyStone.signOut(" },
    .{ .from = "KeyStone.Config", .to = "KeyStone.ClientConfig", .whole = true },
    .{ .from = "Vapor.lib.eventListener(", .to = "Vapor.addGlobalListener(" },
    // The HTTP types moved to Vapor.Fetch in 2.2.0.
    .{ .from = "Vapor.Kit.Response", .to = "Vapor.Fetch.Result", .whole = true },
    .{ .from = "Vapor.Kit.HttpReq", .to = "Vapor.Fetch.Options", .whole = true },
    .{ .from = "Vapor.Kit.Headers", .to = "Vapor.Fetch.Headers", .whole = true },
    .{ .from = "Vapor.Kit.HttpHeader", .to = "Vapor.Fetch.Header", .whole = true },
    .{ .from = "Vapor.Kit.Methods", .to = "Vapor.Fetch.Method", .whole = true },
    .{ .from = "Kit.Response", .to = "Vapor.Fetch.Result", .whole = true, .bare = true },
    .{ .from = "Kit.HttpReq", .to = "Vapor.Fetch.Options", .whole = true, .bare = true },
    .{ .from = "Kit.Headers", .to = "Vapor.Fetch.Headers", .whole = true, .bare = true },
    .{ .from = "Kit.HttpHeader", .to = "Vapor.Fetch.Header", .whole = true, .bare = true },
    .{ .from = "Kit.Methods", .to = "Vapor.Fetch.Method", .whole = true, .bare = true },
};

const Hint = struct {
    from: []const u8,
    msg: []const u8,
    /// Report only the first occurrence in a file.
    once: bool = false,
};

/// Removed APIs with no mechanical replacement: reported, not rewritten.
const hints = [_]Hint{
    .{ .from = "Vapor.HooksCtx(", .msg = "HooksCtx is gone; use Vapor.Hooks" },
    .{ .from = "Vapor.Kit.Fetch", .msg = "fetch moved: Vapor.fetch(url, .{}).handle(handler, .{ctx}); see Vapor.Fetch" },
    .{ .from = "Vapor.Kit.ErrResponse", .msg = "ErrResponse is gone; a failed request's Vapor.Fetch.Response has the status and body" },
    .{ .from = "Vapor.lib.printlnColor(", .msg = "printlnColor printed nothing and is gone; delete the call or use Vapor.println" },
    .{ .from = "Vapor.lib.printlnWithColor(", .msg = "printlnWithColor printed nothing and is gone; delete the call or use Vapor.println" },
    .{ .from = "Vapor.lib.printlnAllocation(", .msg = "printlnAllocation printed nothing and is gone; delete the call" },
    .{ .from = "Vapor.lib.printlnSrc(", .msg = "printlnSrc printed nothing and is gone; delete the call or use Vapor.println" },
    .{ .from = "Vapor.printlnSrc(", .msg = "printlnSrc printed nothing and is gone; delete the call or use Vapor.println" },
    .{ .from = "Vapor.onPushState(", .msg = "onPushState is gone; its callbacks were never called" },
    .{ .from = "Null2(", .msg = "Null2 is gone; use Vapor.Null()" },
    .{ .from = ".checkmark_style", .msg = "Style.checkmark_style is gone; it never reached the CSS" },
    .{ .from = ".child_styles", .msg = "Style.child_styles is gone; it never reached the CSS" },
    .{ .from = ".will_change", .msg = "Style.will_change is gone; it never reached the CSS" },
    .{ .from = ".btn_id", .msg = "Style.btn_id is gone; it did nothing" },
    .{ .from = ".dialog_id", .msg = "Style.dialog_id is gone; it did nothing" },
    .{ .from = ".addListener(", .msg = "Element.addListener is gone (it lasted until the element's next render); attach the handler with .onEvent(event, cb) where the element is built, or use Vapor.addGlobalListener for the document" },
    .{ .from = ".removeListener(", .msg = "Element.removeListener is gone; render the element without its .onEvent to remove the handler" },
    .{ .from = ".toplr(", .msg = "BorderRadius.toplr is gone; use .{ .top_left = a, .top_right = b }" },
    .{ .from = "Sizing.at(", .msg = "Sizing.at is gone; use .mobileDesktopPercent" },
    .{
        .from = "&IconTokens{",
        .msg = "Icon() takes an IconTokens value: tokens declared as &IconTokens{...} work with Icon(.name) once the & is dropped (and *const IconTokens in your own types becomes IconTokens)",
        .once = true,
    },
};

fn applyRenames(arena: Allocator, text: []const u8, report: *Report) ![]const u8 {
    const mask = try codeMask(arena, text);
    for (hints) |hint| {
        var at: usize = 0;
        while (std.mem.indexOfPos(u8, text, at, hint.from)) |found| : (at = found + hint.from.len) {
            if (!mask[found]) continue;
            try report.add(arena, text, found, true, "{s}", .{hint.msg});
            if (hint.once) break;
        }
    }
    var out: std.ArrayList(u8) = .empty;
    var i: usize = 0;
    outer: while (i < text.len) {
        if (mask[i]) {
            for (renames) |r| {
                if (!std.mem.startsWith(u8, text[i..], r.from)) continue;
                // A name starting the pattern must not continue an identifier.
                if (isIdent(r.from[0]) and i > 0 and isIdent(text[i - 1])) continue;
                if (r.literal_only and i > 0 and (isIdent(text[i - 1]) or text[i - 1] == ')' or text[i - 1] == ']')) continue;
                if (r.method_only and !afterValue(text, i)) continue;
                if (r.bare and i > 0 and text[i - 1] == '.') continue;
                const end = i + r.from.len;
                if (r.whole and end < text.len and isIdent(text[end])) continue;
                try out.appendSlice(arena, r.to);
                try report.add(arena, text, i, false, "{s} -> {s}", .{ r.from, r.to });
                i = end;
                continue :outer;
            }
            // inlineStyleStr("css") is inlineStyle("css", .{}) when the CSS has
            // no braces to escape.
            const inline_str = ".inlineStyleStr(";
            if (std.mem.startsWith(u8, text[i..], inline_str)) {
                const open = i + inline_str.len - 1;
                if (try callArgs(arena, text, mask, open)) |call| {
                    const arg = if (call.args.len == 1) call.args[0] else "";
                    if (arg.len >= 2 and arg[0] == '"' and arg[arg.len - 1] == '"' and
                        std.mem.indexOfAny(u8, arg, "{}") == null)
                    {
                        const replacement = try std.fmt.allocPrint(arena, ".inlineStyle({s}, .{{}})", .{arg});
                        try out.appendSlice(arena, replacement);
                        try report.add(arena, text, i, false, "{s} -> {s}", .{ text[i .. call.close + 1], replacement });
                        i = call.close + 1;
                        continue :outer;
                    }
                }
                try report.add(arena, text, i, true, "inlineStyleStr is gone; use .inlineStyle(css, .{{}}), with braces in the CSS doubled", .{});
            }
            // onEnd(f) is onLayout with no arguments for `f`.
            const on_end = "Vapor.onEnd(";
            if (std.mem.startsWith(u8, text[i..], on_end) and (i == 0 or !isIdent(text[i - 1]))) {
                const open = i + on_end.len - 1;
                if (try callArgs(arena, text, mask, open)) |call| {
                    if (call.args.len == 1) {
                        const replacement = try std.fmt.allocPrint(arena, "Vapor.onLayout({s}, .{{}})", .{call.args[0]});
                        try out.appendSlice(arena, replacement);
                        try report.add(arena, text, i, false, "{s} -> {s}", .{ text[i .. call.close + 1], replacement });
                        i = call.close + 1;
                        continue :outer;
                    }
                }
            }
        }
        try out.append(arena, text[i]);
        i += 1;
    }
    return out.items;
}

/// Whether the code before `i`, skipping whitespace, ends a value, so a
/// `.name(` at `i` is a method call.
fn afterValue(text: []const u8, i: usize) bool {
    var j = i;
    while (j > 0) {
        j -= 1;
        switch (text[j]) {
            ' ', '\t', '\r', '\n' => continue,
            ')', ']' => return true,
            else => return isIdent(text[j]),
        }
    }
    return false;
}

// ── Sides ───────────────────────────────────────────────────────────────────

const SideContext = enum { spacing, thickness };

const Context = struct {
    pattern: []const u8,
    kind: SideContext,
    /// What ends the expression: an assignment's value ends at a top-level
    /// `,` or `;`, a call's argument at the closing `)`, a border's first
    /// argument at the first `,`.
    stops: []const u8,
};

const contexts = [_]Context{
    .{ .pattern = ".padding = ", .kind = .spacing, .stops = ",;" },
    .{ .pattern = ".margin = ", .kind = .spacing, .stops = ",;" },
    .{ .pattern = ".padding(", .kind = .spacing, .stops = "" },
    .{ .pattern = ".margin(", .kind = .spacing, .stops = "" },
    .{ .pattern = ".thickness = ", .kind = .thickness, .stops = ",;" },
    .{ .pattern = ".border_thickness = ", .kind = .thickness, .stops = ",;" },
    .{ .pattern = ".solid(", .kind = .thickness, .stops = "," },
    .{ .pattern = ".sharp(", .kind = .thickness, .stops = "," },
};

fn applySideLiterals(arena: Allocator, text: []const u8, report: *Report) ![]const u8 {
    const mask = try codeMask(arena, text);
    var out: std.ArrayList(u8) = .empty;
    var i: usize = 0;
    outer: while (i < text.len) {
        if (mask[i]) for (contexts) |ctx| {
            if (!std.mem.startsWith(u8, text[i..], ctx.pattern)) continue;
            const start = i + ctx.pattern.len;
            const end = spanEnd(text, mask, start, ctx.stops) orelse continue;
            try out.appendSlice(arena, text[i..start]);
            try rewriteSpan(arena, text, mask, start, end, ctx.kind, &out, report);
            i = end;
            continue :outer;
        };
        // Elsewhere (a switch prong, a return), a removed side constructor is
        // still a decl literal whose type the arguments give away.
        if (mask[i] and text[i] == '.' and i + 1 < text.len and isIdent(text[i + 1]) and
            (i == 0 or !(isIdent(text[i - 1]) or text[i - 1] == ')' or text[i - 1] == ']')))
        {
            var name_end = i + 1;
            while (name_end < text.len and isIdent(text[name_end])) name_end += 1;
            if (name_end < text.len and text[name_end] == '(' and isLetterSide(text[i + 1 .. name_end])) {
                if (try callArgs(arena, text, mask, name_end)) |call| {
                    const name = text[i + 1 .. name_end];
                    const original = text[i .. call.close + 1];
                    const result: SideResult = if (call.args.len == 2 and longSide(name) != null)
                        .{ .replace = try std.fmt.allocPrint(arena, ".{s}({s}, {s})", .{ longSide(name).?, call.args[0], call.args[1] }) }
                    else if (call.args.len == 1 and (std.mem.eql(u8, name, "tb") or std.mem.eql(u8, name, "lr")))
                        .manual
                    else
                        try sideReplacement(arena, name, call.args, .spacing);
                    switch (result) {
                        .keep => {},
                        .replace => |replacement| {
                            try out.appendSlice(arena, replacement);
                            try report.add(arena, text, i, false, "{s} -> {s}", .{ original, replacement });
                            i = call.close + 1;
                            continue :outer;
                        },
                        .manual => try report.add(arena, text, i, true, "{s}: write the sides as a literal, or use Border.vertical/horizontal(1, color)", .{original}),
                    }
                }
            }
        }
        try out.append(arena, text[i]);
        i += 1;
    }
    return out.items;
}

/// Copies `text[start..end]` to `out`, replacing top-level constructor calls
/// such as `.tb(8, 4)` with their literal.
fn rewriteSpan(arena: Allocator, text: []const u8, mask: []const bool, start: usize, end: usize, kind: SideContext, out: *std.ArrayList(u8), report: *Report) !void {
    var depth: usize = 0;
    var i = start;
    while (i < end) {
        const c = text[i];
        if (mask[i] and depth == 0 and c == '.' and i + 1 < end and isIdent(text[i + 1]) and
            (i == 0 or !(isIdent(text[i - 1]) or text[i - 1] == ')' or text[i - 1] == ']')))
        {
            var name_end = i + 1;
            while (name_end < end and isIdent(text[name_end])) name_end += 1;
            if (name_end < end and text[name_end] == '(') {
                const name = text[i + 1 .. name_end];
                if (try callArgs(arena, text, mask, name_end)) |call| {
                    const original = text[i .. call.close + 1];
                    switch (try sideReplacement(arena, name, call.args, kind)) {
                        .keep => {},
                        .replace => |replacement| {
                            try out.appendSlice(arena, replacement);
                            try report.add(arena, text, i, false, "{s} -> {s}", .{ original, replacement });
                            i = call.close + 1;
                            continue;
                        },
                        .manual => {
                            try report.add(arena, text, i, true, "{s}: write the sides as a literal, e.g. .{{ .top = 8 }}", .{original});
                        },
                    }
                }
            }
        }
        if (mask[i]) switch (c) {
            '(', '[', '{' => depth += 1,
            ')', ']', '}' => depth -|= 1,
            else => {},
        };
        try out.append(arena, c);
        i += 1;
    }
}

const SideResult = union(enum) { keep, replace: []const u8, manual };

/// The removed short side constructors. `top`, `left`, ... still exist on
/// `Border` and `BorderRadius`, so they are only rewritten in a context.
fn isLetterSide(name: []const u8) bool {
    for ([_][]const u8{ "t", "b", "l", "r", "tb", "lr", "tblr", "tl", "tr", "bl", "br", "top_left", "top_right", "bottom_left", "bottom_right" }) |n| {
        if (std.mem.eql(u8, name, n)) return true;
    }
    return false;
}

/// `Border`'s one-letter sides took a thickness and a colour, like the long
/// ones.
fn longSide(name: []const u8) ?[]const u8 {
    if (std.mem.eql(u8, name, "t")) return "top";
    if (std.mem.eql(u8, name, "b")) return "bottom";
    if (std.mem.eql(u8, name, "l")) return "left";
    if (std.mem.eql(u8, name, "r")) return "right";
    return null;
}

/// The literal for a deprecated or removed side constructor, or `.keep` when
/// `name` is not one.
fn sideReplacement(arena: Allocator, name: []const u8, args: []const []const u8, kind: SideContext) !SideResult {
    const Spec = struct { name: []const u8, sides: []const []const u8 };
    const specs = [_]Spec{
        .{ .name = "top", .sides = &.{"top"} },
        .{ .name = "bottom", .sides = &.{"bottom"} },
        .{ .name = "left", .sides = &.{"left"} },
        .{ .name = "right", .sides = &.{"right"} },
        .{ .name = "t", .sides = &.{"top"} },
        .{ .name = "b", .sides = &.{"bottom"} },
        .{ .name = "l", .sides = &.{"left"} },
        .{ .name = "r", .sides = &.{"right"} },
        .{ .name = "tb", .sides = &.{ "top", "bottom" } },
        .{ .name = "lr", .sides = &.{ "left", "right" } },
        .{ .name = "tblr", .sides = &.{ "top", "bottom", "left", "right" } },
        .{ .name = "tl", .sides = &.{ "top", "left" } },
        .{ .name = "tr", .sides = &.{ "top", "right" } },
        .{ .name = "bl", .sides = &.{ "bottom", "left" } },
        .{ .name = "br", .sides = &.{ "bottom", "right" } },
        .{ .name = "top_left", .sides = &.{ "top", "left" } },
        .{ .name = "top_right", .sides = &.{ "top", "right" } },
        .{ .name = "bottom_left", .sides = &.{ "bottom", "left" } },
        .{ .name = "bottom_right", .sides = &.{ "bottom", "right" } },
    };
    // A border's tb/lr took one thickness for both sides.
    if (kind == .thickness and args.len == 1) {
        if (std.mem.eql(u8, name, "tb")) return .{ .replace = try std.fmt.allocPrint(arena, ".vertical({s})", .{args[0]}) };
        if (std.mem.eql(u8, name, "lr")) return .{ .replace = try std.fmt.allocPrint(arena, ".horizontal({s})", .{args[0]}) };
    }
    for (specs) |spec| {
        if (!std.mem.eql(u8, name, spec.name)) continue;
        if (args.len != spec.sides.len) return .manual;
        return .{ .replace = try sidesLiteral(arena, spec.sides, args) };
    }
    return .keep;
}

/// `.{ .top = a, .left = b }`, leaving out sides that are `0`, and using
/// `all` / `xy` / `vertical` / `horizontal` when the values allow it.
fn sidesLiteral(arena: Allocator, sides: []const []const u8, args: []const []const u8) ![]const u8 {
    var top: ?[]const u8 = null;
    var bottom: ?[]const u8 = null;
    var left: ?[]const u8 = null;
    var right: ?[]const u8 = null;
    for (sides, args) |side, arg| {
        const value: ?[]const u8 = if (std.mem.eql(u8, arg, "0")) null else arg;
        if (std.mem.eql(u8, side, "top")) top = value;
        if (std.mem.eql(u8, side, "bottom")) bottom = value;
        if (std.mem.eql(u8, side, "left")) left = value;
        if (std.mem.eql(u8, side, "right")) right = value;
    }
    const same = struct {
        fn f(a: ?[]const u8, b: ?[]const u8) bool {
            if (a == null or b == null) return a == null and b == null;
            return std.mem.eql(u8, a.?, b.?);
        }
    }.f;
    const vertical = top != null and same(top, bottom);
    const horizontal = left != null and same(left, right);
    if (vertical and horizontal and same(top, left)) return std.fmt.allocPrint(arena, ".all({s})", .{top.?});
    if (vertical and horizontal) return std.fmt.allocPrint(arena, ".xy({s}, {s})", .{ left.?, top.? });
    if (vertical and left == null and right == null) return std.fmt.allocPrint(arena, ".vertical({s})", .{top.?});
    if (horizontal and top == null and bottom == null) return std.fmt.allocPrint(arena, ".horizontal({s})", .{left.?});

    var out: std.ArrayList(u8) = .empty;
    try out.appendSlice(arena, ".{");
    var first = true;
    inline for (.{ "top", "bottom", "left", "right" }, .{ top, bottom, left, right }) |side, value| {
        if (value) |v| {
            try out.appendSlice(arena, if (first) " ." else ", .");
            try out.appendSlice(arena, side);
            try out.appendSlice(arena, " = ");
            try out.appendSlice(arena, v);
            first = false;
        }
    }
    try out.appendSlice(arena, if (first) "}" else " }");
    if (first) return ".none";
    return out.items;
}

// ── Visual borders ──────────────────────────────────────────────────────────

const BorderPart = enum { thickness, color, radius };

const Candidate = struct { line: usize, part: BorderPart, value: []const u8 };

fn mergeBorders(arena: Allocator, text: []const u8, report: *Report) ![]const u8 {
    const mask = try codeMask(arena, text);
    var lines: std.ArrayList([]const u8) = .empty;
    var line_starts: std.ArrayList(usize) = .empty;
    {
        var start: usize = 0;
        var it = std.mem.splitScalar(u8, text, '\n');
        while (it.next()) |line| {
            try lines.append(arena, line);
            try line_starts.append(arena, start);
            start += line.len + 1;
        }
    }

    // The innermost block each line starts in, and whether it holds a Visual.
    const Block = struct { id: usize, visual: bool };
    const line_block = try arena.alloc(Block, lines.items.len);
    var stack: std.ArrayList(Block) = .empty;
    try stack.append(arena, .{ .id = 0, .visual = false });
    var next_id: usize = 1;
    for (lines.items, line_starts.items, 0..) |line, line_start, n| {
        line_block[n] = stack.items[stack.items.len - 1];
        for (line, 0..) |c, k| {
            if (!mask[line_start + k]) continue;
            switch (c) {
                '{' => {
                    try stack.append(arena, .{ .id = next_id, .visual = opensVisual(line[0..k]) });
                    next_id += 1;
                },
                '}' => {
                    if (stack.items.len > 1) _ = stack.pop();
                },
                else => {},
            }
        }
    }

    // Group the border fields of each Visual block.
    var groups: std.AutoArrayHashMapUnmanaged(usize, std.ArrayList(Candidate)) = .empty;
    var has_border: std.AutoHashMapUnmanaged(usize, void) = .empty;
    for (lines.items, 0..) |line, n| {
        const block = line_block[n];
        if (!block.visual) continue;
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (std.mem.startsWith(u8, trimmed, ".border = ")) try has_border.put(arena, block.id, {});
        const part: BorderPart = if (std.mem.startsWith(u8, trimmed, ".border_thickness = "))
            .thickness
        else if (std.mem.startsWith(u8, trimmed, ".border_color = "))
            .color
        else if (std.mem.startsWith(u8, trimmed, ".border_radius = "))
            .radius
        else
            continue;
        const eq = std.mem.indexOf(u8, trimmed, " = ").? + 3;
        const value: ?[]const u8 = if (std.mem.endsWith(u8, trimmed, ",")) trimmed[eq .. trimmed.len - 1] else null;
        if (value == null or !balanced(value.?)) {
            try report.add(arena, text, line_starts.items[n], true, "{s}: move it into `.border = .{{ ... }}`", .{trimmed});
            continue;
        }
        const entry = try groups.getOrPut(arena, block.id);
        if (!entry.found_existing) entry.value_ptr.* = .empty;
        try entry.value_ptr.append(arena, .{ .line = n, .part = part, .value = value.? });
    }

    const drop = try arena.alloc(bool, lines.items.len);
    @memset(drop, false);
    const replace = try arena.alloc(?[]const u8, lines.items.len);
    @memset(replace, null);
    var it = groups.iterator();
    while (it.next()) |entry| {
        const candidates = entry.value_ptr.items;
        if (has_border.contains(entry.key_ptr.*)) {
            for (candidates) |cand| {
                try report.add(arena, text, line_starts.items[cand.line], true, ".border_{s} beside .border: merge it into the .border value", .{@tagName(cand.part)});
            }
            continue;
        }
        var merged: std.ArrayList(u8) = .empty;
        const first_line = lines.items[candidates[0].line];
        const indent = first_line[0 .. first_line.len - std.mem.trimStart(u8, first_line, " \t").len];
        try merged.appendSlice(arena, indent);
        try merged.appendSlice(arena, ".border = .{");
        var first = true;
        for ([_]BorderPart{ .thickness, .color, .radius }) |part| {
            for (candidates) |cand| {
                if (cand.part != part) continue;
                try merged.appendSlice(arena, if (first) " ." else ", .");
                try merged.appendSlice(arena, @tagName(part));
                try merged.appendSlice(arena, " = ");
                try merged.appendSlice(arena, cand.value);
                first = false;
            }
        }
        try merged.appendSlice(arena, " },");
        replace[candidates[0].line] = merged.items;
        for (candidates[1..]) |cand| drop[cand.line] = true;
        try report.add(arena, text, line_starts.items[candidates[0].line], false, "border fields -> {s}", .{std.mem.trim(u8, merged.items, " \t")});
    }

    var out: std.ArrayList(u8) = .empty;
    for (lines.items, 0..) |line, n| {
        if (drop[n]) continue;
        try out.appendSlice(arena, replace[n] orelse line);
        if (n + 1 < lines.items.len) try out.append(arena, '\n');
    }
    return out.items;
}

/// Whether the `{` after `before` opens a `Visual` literal: a `.visual`,
/// `.hover`, `.focus` or `.focus_within` field, or a `...Visual{`.
fn opensVisual(before: []const u8) bool {
    const t = std.mem.trimEnd(u8, before, " \t");
    if (std.mem.endsWith(u8, t, "Visual")) return true;
    if (!std.mem.endsWith(u8, t, "= .")) return false;
    const field = std.mem.trimEnd(u8, t[0 .. t.len - 3], " \t");
    for ([_][]const u8{ ".visual", ".hover", ".focus", ".focus_within" }) |name| {
        if (std.mem.endsWith(u8, field, name)) return true;
    }
    return false;
}

fn balanced(value: []const u8) bool {
    var depth: isize = 0;
    for (value) |c| switch (c) {
        '(', '[', '{' => depth += 1,
        ')', ']', '}' => depth -= 1,
        else => {},
    };
    return depth == 0;
}

// ── Tests ───────────────────────────────────────────────────────────────────

fn expectMigrated(input: []const u8, expected: []const u8) !void {
    var arena_state = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_state.deinit();
    var report: Report = .{};
    const result = try migrate(arena_state.allocator(), input, &report);
    try std.testing.expectEqualStrings(expected, result);
}

test "renames calls and types, not strings or comments" {
    try expectMigrated(
        \\const e: *Vapor.Binded = x; // Vapor.Binded
        \\Vapor.printErr("{d} .square_px(", .{1});
        \\_ = Box().fontColor(.white).size(.square_px(4));
        \\const BindedThing = 1;
        \\ToolTip.simple("a", "b");
        \\Box().border(.simple(.white)).end();
        \\Box().inlineStyleStr("view-transition-name: a").end();
        \\Vapor.onEnd(reinit);
        \\Vapor.onEndCtx(scrollTo, .{id});
        \\_ = Box().hide(true).gradient(.white)
        \\    .hide(false).end();
        \\Box().background(.gradient(.linear, .right, &cs)).end();
        \\.border = .tb(.white),
        \\.border = .sharp(.solid, .black),
        \\Box().border(.l(1, .black)).size(.px(4)).end();
        \\var list = Vapor.persist.Array(u8).init(Vapor.persist.allocator());
        \\const r = Vapor.Fetch.Fetch.fetch(url, .{});
        \\fn done(a: Vapor.Kit.Response, b: Kit.Response, c: Kit.HttpReq) void {}
    ,
        \\const e: *Vapor.Element = x; // Vapor.Binded
        \\Vapor.print(.err, "{d} .square_px(", .{1});
        \\_ = Box().textColor(.white).size(.squarePx(4));
        \\const BindedThing = 1;
        \\ToolTip.simple("a", "b");
        \\Box().border(.thin(.white)).end();
        \\Box().inlineStyle("view-transition-name: a", .{}).end();
        \\Vapor.onLayout(reinit, .{});
        \\Vapor.onLayout(scrollTo, .{id});
        \\_ = Box().hidden(true).background(.white)
        \\    .hidden(false).end();
        \\Box().background(.gradient(.linear, .right, &cs)).end();
        \\.border = .vertical(1, .white),
        \\.border = .sharp(.all(1), .black),
        \\Box().border(.left(1, .black)).size(.squarePx(4)).end();
        \\var list = Vapor.persist.array(u8).init(Vapor.persist.arena());
        \\const r = Vapor.Fetch.Request.fetch(url, .{});
        \\fn done(a: Vapor.Fetch.Result, b: Vapor.Fetch.Result, c: Vapor.Fetch.Options) void {}
    );
}

test "side constructors become literals in padding, margin and thickness" {
    try expectMigrated(
        \\.padding = .left(12),
        \\.padding = if (deep) .left(16) else .all(0),
        \\Box().padding(.tb(8, 4)).margin(.tblr(1, 2, 3, 4)).end();
        \\.margin = .t(6),
        \\.padding = .tblr(0, 0, 8, 8),
        \\.padding = .tblr(4, 4, 4, 4),
        \\.thickness = .lr(1),
        \\.border = .sharp(.left(1), .black),
        \\.radius = .top(8),
        \\.padding = .all(8),
        \\.top => .b(2),
        \\return .l(1, .black);
        \\_ = Box().pl(4).l(3);
    ,
        \\.padding = .{ .left = 12 },
        \\.padding = if (deep) .{ .left = 16 } else .all(0),
        \\Box().padding(.{ .top = 8, .bottom = 4 }).margin(.{ .top = 1, .bottom = 2, .left = 3, .right = 4 }).end();
        \\.margin = .{ .top = 6 },
        \\.padding = .horizontal(8),
        \\.padding = .all(4),
        \\.thickness = .horizontal(1),
        \\.border = .sharp(.{ .left = 1 }, .black),
        \\.radius = .top(8),
        \\.padding = .all(8),
        \\.top => .{ .bottom = 2 },
        \\return .left(1, .black);
        \\_ = Box().pl(4).l(3);
    );
}

test "visual border fields merge into one border" {
    try expectMigrated(
        \\.visual = .{
        \\    .background = .white,
        \\    .border_thickness = .all(1),
        \\    .border_radius = .all(8),
        \\    .border_color = c,
        \\},
        \\.theme = .{
        \\    .border_color = .hex("#fff"),
        \\},
    ,
        \\.visual = .{
        \\    .background = .white,
        \\    .border = .{ .thickness = .all(1), .color = c, .radius = .all(8) },
        \\},
        \\.theme = .{
        \\    .border_color = .hex("#fff"),
        \\},
    );
}

test "a visual with both border and border_radius is left for a person" {
    const input =
        \\.visual = .{
        \\    .border = .thin(.black),
        \\    .border_radius = .all(4),
        \\},
    ;
    var arena_state = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_state.deinit();
    var report: Report = .{};
    const result = try migrate(arena_state.allocator(), input, &report);
    try std.testing.expectEqualStrings(input, result);
    try std.testing.expectEqual(@as(usize, 1), report.notes.items.len);
    try std.testing.expect(report.notes.items[0].manual);
}
