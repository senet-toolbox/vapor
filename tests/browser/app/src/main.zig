//! The app `zig build browser-test` drives in headless Chrome.
//!
//! Each page exercises one behaviour end to end: Zig state -> reconciler ->
//! JS runtime -> DOM, and DOM events back. Elements the runner inspects carry
//! an explicit `.id()`, which vapor also uses as the DOM id.

const std = @import("std");
const Vapor = @import("vapor");
const Box = Vapor.Box;
const Button = Vapor.Button;
const Text = Vapor.Text;
const TextFmt = Vapor.TextFmt;
const TextField = Vapor.TextField;
const Link = Vapor.Link;
const Fetch = Vapor.Fetch.Fetch;

pub export fn init() void {
    Vapor.init(.{});
    Vapor.Page(.{ .route = "/" }, home, null);
    Vapor.Page(.{ .route = "/list" }, list, null);
    Vapor.Page(.{ .route = "/cond" }, cond, null);
    Vapor.Page(.{ .route = "/input" }, input, null);
    Vapor.Page(.{ .route = "/escape" }, escape, null);
    Vapor.Page(.{ .route = "/a" }, pageA, null);
    Vapor.Page(.{ .route = "/b" }, pageB, null);
    Vapor.Page(.{ .route = "/fetch" }, fetchPage, null);
    Vapor.Page(.{ .route = "/storage" }, storagePage, null);
    Vapor.Page(.{ .route = "/urls" }, urls, null);
}

pub const std_options = std.Options{
    .log_level = .info,
    .logFn = Vapor.lib.log,
};

// ── / : events update state, state updates the DOM ─────────────────────────

var count: u32 = 0;

fn increment() void {
    count += 1;
}

fn home() void {
    Box().id("home").children({
        Button(increment, .{}).id("inc").children({
            Text("Increment").end();
        });
        Text(count).id("count").end();
    });
}

// ── /list : keyed children keep their DOM nodes across reorders ────────────

var items_buf: [32]u32 = .{ 1, 2, 3, 4, 5 } ++ .{0} ** 27;
var items_len: usize = 5;
var next_item: u32 = 6;

fn items() []u32 {
    return items_buf[0..items_len];
}

fn reverseItems() void {
    std.mem.reverse(u32, items());
}

fn prependItem() void {
    if (items_len == items_buf.len) return;
    std.mem.copyBackwards(u32, items_buf[1 .. items_len + 1], items_buf[0..items_len]);
    items_buf[0] = next_item;
    next_item += 1;
    items_len += 1;
}

fn removeFirst() void {
    if (items_len == 0) return;
    std.mem.copyForwards(u32, items_buf[0 .. items_len - 1], items_buf[1..items_len]);
    items_len -= 1;
}

fn list() void {
    Box().id("list-page").children({
        Button(reverseItems, .{}).id("reverse").children({
            Text("Reverse").end();
        });
        Button(prependItem, .{}).id("prepend").children({
            Text("Prepend").end();
        });
        Button(removeFirst, .{}).id("remove-first").children({
            Text("Remove first").end();
        });
        Box().id("items").children({
            for (items()) |item| {
                Box().id(Vapor.frame.fmt("item-{d}", .{item})).children({
                    TextFmt("Item {d}", .{item}).end();
                });
            }
        });
    });
}

// ── /cond : a conditional sibling must not disturb what follows it ─────────

var show_banner = false;

fn toggleBanner() void {
    show_banner = !show_banner;
}

fn cond() void {
    Box().id("cond-page").children({
        Button(toggleBanner, .{}).id("toggle").children({
            Text("Toggle").end();
        });
        if (show_banner) {
            Text("Banner").id("banner").end();
        }
        Text("Stable").id("stable").end();
        Text("Unkeyed after").end();
    });
}

// ── /input : typing flows back into Zig state ──────────────────────────────

var name: []const u8 = "";

fn nameChanged(evt: *Vapor.Event) void {
    name = Vapor.dupe(evt.text(), .persist);
}

fn input() void {
    Box().id("input-page").children({
        TextField(.string).id("name").bind(&name).onChange(nameChanged, .{}).end();
        TextFmt("Hello, {s}!", .{name}).id("greeting").end();
    });
}

// ── /escape : text is text, never markup ───────────────────────────────────

fn escape() void {
    Box().id("escape-page").children({
        Text("<img src=x onerror=\"window.__xss = 1\">").id("payload").end();
    });
}

// ── /a and /b : client-side navigation, and memory across route changes ───

fn pageA() void {
    Box().id("page-a").children({
        Text("Page A").end();
        Link(.{ .url = "/b" }).id("to-b").children({
            Text("Go to B").end();
        });
        for (0..50) |i| {
            TextFmt("A row {d}", .{i}).end();
        }
    });
}

fn pageB() void {
    Box().id("page-b").children({
        Text("Page B").end();
        Link(.{ .url = "/a" }).id("to-a").children({
            Text("Go to A").end();
        });
        for (0..50) |i| {
            TextFmt("B row {d}", .{i}).end();
        }
    });
}

// ── /fetch : a request's lifecycle reaches the DOM ─────────────────────────

var request: ?*Fetch = null;
var fetched: []const u8 = "";

fn onFetched(result: Vapor.Fetch.Result) void {
    switch (result) {
        .ok => |response| fetched = Vapor.dupe(response.body, .persist),
        .err => |err| fetched = Vapor.dupe(err.message, .persist),
    }
}

fn fetchPage() void {
    if (request == null) {
        const req = Fetch.fetch("/api/greeting.txt", .{ .method = .GET });
        req.handle(onFetched, .{});
        request = req;
    }
    Box().id("fetch-page").children({
        switch (request.?.state()) {
            .idle, .loading => Text("loading").id("fetch-state").end(),
            .ok => TextFmt("ok:{s}", .{fetched}).id("fetch-state").end(),
            .err => TextFmt("err:{s}", .{fetched}).id("fetch-state").end(),
        }
    });
}

// ── /storage : localStorage round trips, including floats ──────────────────

fn saveValues() void {
    Vapor.store("int", @as(u32, 42));
    Vapor.store("float", @as(f32, 2.5));
    Vapor.store("text", @as([]const u8, "zig"));
}

fn storagePage() void {
    Box().id("storage-page").children({
        Button(saveValues, .{}).id("save").children({
            Text("Save").end();
        });
        TextFmt("int={?d} float={?d} text={?s}", .{
            Vapor.load(u32, "int"),
            Vapor.load(f32, "float"),
            Vapor.load([]const u8, "text"),
        }).id("stored").end();
    });
}

// ── /urls : script URLs are blocked; other origins are not routed ──────────

fn urls() void {
    Box().id("urls-page").children({
        Link(.{ .url = "javascript:window.__pwned = 1" }).id("js-link").children({
            Text("script link").end();
        });
        Link(.{ .url = " JaVa\tScRiPt:window.__pwned = 2" }).id("js-link-obfuscated").children({
            Text("obfuscated script link").end();
        });
        Link(.{ .url = "https://example.com/elsewhere" }).id("external").children({
            Text("external").end();
        });
        Link(.{ .url = "/a" }).id("internal").children({
            Text("internal").end();
        });
    });
}
