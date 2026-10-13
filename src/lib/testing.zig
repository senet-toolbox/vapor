//! Testing an app without a browser: render its pages natively, read what
//! they show, and fire events at them, inside `zig build test`.
//!
//! ```zig
//! const app_main = @import("main.zig");
//!
//! test "the counter counts" {
//!     var app = try Vapor.testing.App.start(app_main.init);
//!     defer app.deinit();
//!
//!     try app.visit("/");
//!     try app.expectText("count", "0");
//!     try app.click("increment");
//!     try app.expectText("count", "1");
//! }
//! ```
//!
//! Elements are found by their `.id()`, so give the ones a test touches an
//! id. After every event the page renders again, as in the browser. Links and
//! `Vapor.navigate`/`Vapor.back` move the app to the new page.
//!
//! The test module needs libc (`link_libc = true`), as prerendering does.
//! What only a browser has is not simulated: layout and CSS, `fetch`, timers,
//! the DOM itself, and the hooks the runtime runs on the DOM (`onMount`,
//! `onDestroy`, `onLayout`). Event data comes from what the test passes.

const std = @import("std");
const Vapor = @import("vapor.zig");
const UINode = @import("UITree.zig").UINode;
const Event = @import("Event.zig");
const Navigation = @import("navigation.zig");
const HtmlGenerator = @import("html_generator.zig");
const Animation = @import("Animation.zig");
const types = @import("types.zig");

pub const EventData = Event.NativeData;

/// An app under test. Only one exists at a time: vapor's state is global.
pub const App = struct {
    arena: std.heap.ArenaAllocator,
    /// Visited paths, newest last; `back` pops it.
    history: std.ArrayList([]const u8) = .empty,
    /// Print why a call failed (which id was missing, which event had no
    /// handler). Turn off around calls a test expects to fail.
    report_failures: bool = true,

    /// Starts the app by calling `init`, the function the app exports to the
    /// runtime (it calls `Vapor.init` and registers the pages). Renders
    /// nothing yet; `visit` a page first.
    pub fn start(init: anytype) !App {
        Navigation.native_request = .none;
        Event.native_data = .{};
        @call(.auto, init, .{});
        Animation.new();
        Vapor.resetRerender();
        Animation.removal_queue.clearRetainingCapacity();
        return .{ .arena = std.heap.ArenaAllocator.init(std.heap.page_allocator) };
    }

    /// Frees what the harness allocated. Vapor's own state stays until the
    /// next `start`.
    pub fn deinit(self: *App) void {
        self.arena.deinit();
        Navigation.native_request = .none;
        Event.native_data = .{};
    }

    /// Renders the page at `path` ("/", "/users/42"), as if the user
    /// navigated there.
    pub fn visit(self: *App, page_path: []const u8) !void {
        try self.history.append(self.arena.allocator(), try self.arena.allocator().dupe(u8, page_path));
        try self.render();
    }

    /// The path of the page on screen.
    pub fn path(self: *const App) []const u8 {
        if (self.history.items.len == 0) return "";
        return self.history.items[self.history.items.len - 1];
    }

    /// Renders the current page again, e.g. after changing app state from the
    /// test.
    pub fn rerender(self: *App) !void {
        try self.render();
    }

    fn render(self: *App) !void {
        // Navigation from inside a render (or a handler) is followed, a few
        // hops at most, so a redirect loop fails the test instead of hanging.
        var hops: usize = 0;
        while (true) : (hops += 1) {
            if (hops == 8) return error.NavigationLoop;
            const current = self.path();
            if (current.len == 0) return error.NoPageVisited;
            const route = if (std.mem.eql(u8, current, "/"))
                try Vapor.allocator_global.dupeZ(u8, "/root")
            else
                try std.fmt.allocPrintSentinel(Vapor.allocator_global, "/root{s}", .{current}, 0);
            // renderCycle owns the route from here and frees it later.
            try Vapor.renderCycle(route.ptr);
            if (!try self.followNavigation()) return;
        }
    }

    /// Applies a pending `navigate`/`back`; true if the page changed.
    fn followNavigation(self: *App) !bool {
        const request = Navigation.native_request;
        Navigation.native_request = .none;
        switch (request) {
            .none => return false,
            .navigate => |to| {
                try self.history.append(self.arena.allocator(), try self.arena.allocator().dupe(u8, to));
                return true;
            },
            .back => {
                if (self.history.items.len < 2) return false;
                _ = self.history.pop();
                return true;
            },
        }
    }

    fn root() ?*UINode {
        return Vapor.getRenderUINodeRootPtr();
    }

    /// The element with id `id` on the page, if any.
    pub fn find(_: *const App, id: []const u8) ?Node {
        const node = findIn(root() orelse return null, id) orelse return null;
        return .{ .node = node };
    }

    fn findIn(node: *UINode, id: []const u8) ?*UINode {
        if (std.mem.eql(u8, node.uuid, id)) return node;
        var child = node.first_child;
        while (child) |c| : (child = c.next_sibling) {
            if (findIn(c, id)) |found| return found;
        }
        return null;
    }

    /// Whether an element with id `id` is on the page.
    pub fn exists(self: *const App, id: []const u8) bool {
        return self.find(id) != null;
    }

    fn get(self: *const App, id: []const u8) !*UINode {
        const found = self.find(id) orelse {
            if (self.report_failures) std.debug.print("vapor testing: no element with id \"{s}\" on {s}\n", .{ id, self.path() });
            return error.ElementNotFound;
        };
        return found.node;
    }

    /// The text of the element `id` and everything inside it, like the DOM's
    /// `textContent`. Lives until the app is deinitialized.
    pub fn text(self: *App, id: []const u8) ![]const u8 {
        const node = try self.get(id);
        var out: std.ArrayList(u8) = .empty;
        try appendText(self.arena.allocator(), &out, node);
        return out.items;
    }

    fn appendText(allocator: std.mem.Allocator, out: *std.ArrayList(u8), node: *UINode) !void {
        if (node.text) |t| try out.appendSlice(allocator, t);
        var child = node.first_child;
        while (child) |c| : (child = c.next_sibling) try appendText(allocator, out, c);
    }

    /// Fails unless the element `id` shows exactly `expected`.
    pub fn expectText(self: *App, id: []const u8, expected: []const u8) !void {
        try std.testing.expectEqualStrings(expected, try self.text(id));
    }

    /// Clicks the element `id`. Like a click in the browser, it reaches the
    /// element's handlers and then its ancestors': a `Button`'s callback, an
    /// `.onEvent(.click, ...)`, or a `Link`, which navigates. Fails with
    /// `error.NothingHandledClick` when none of them reacts.
    pub fn click(self: *App, id: []const u8) !void {
        var target: ?*UINode = try self.get(id);
        var handled = false;
        while (target) |node| : (target = node.parent) {
            if (Vapor.button_callbacks.get(node.hash)) |callback| {
                callback.call();
                handled = true;
            }
            if (dispatch(node, .click, .{})) handled = true;
            if (node.type == .Link) {
                if (node.href) |href| {
                    if (href.len > 0 and href[0] == '/') {
                        Navigation.navigate(href);
                        handled = true;
                    }
                }
            }
        }
        if (!handled) {
            if (self.report_failures) std.debug.print("vapor testing: clicking \"{s}\" reached no handler\n", .{id});
            return error.NothingHandledClick;
        }
        try self.afterEvent();
    }

    /// Types `value` into the text field `id`: fires its `input` event with
    /// `value` as the field's value.
    pub fn input(self: *App, id: []const u8, value: []const u8) !void {
        try self.fire(id, .input, .{ .value = value });
    }

    /// Fires `event_type` at the element `id` with `data` as what the
    /// handler's event reads (value, key, modifiers, coordinates). Only the
    /// element's own handlers run. Fails with `error.NoHandler` when it has
    /// none for `event_type`.
    pub fn fire(self: *App, id: []const u8, event_type: types.EventType, data: EventData) !void {
        const node = try self.get(id);
        if (!dispatch(node, event_type, data)) {
            if (self.report_failures) std.debug.print("vapor testing: \"{s}\" has no {s} handler\n", .{ id, @tagName(event_type) });
            return error.NoHandler;
        }
        try self.afterEvent();
    }

    fn dispatch(node: *UINode, event_type: types.EventType, data: EventData) bool {
        const handlers = node.event_handlers orelse return false;
        for (handlers.handlers.items) |handler| {
            if (handler.event_type != event_type) continue;
            Event.native_data = data;
            defer Event.native_data = .{};
            var event: Event = .{ .id = Vapor.hashKey(node.uuid) +% @intFromEnum(event_type), .type = event_type };
            handler.call(&event);
            return true;
        }
        return false;
    }

    /// The browser rerenders after a handler; so does the harness, following
    /// any navigation the handler asked for.
    fn afterEvent(self: *App) !void {
        _ = try self.followNavigation();
        try self.render();
    }

    /// The page as HTML, the way prerendering writes it; for snapshots.
    /// Caller owns the result.
    pub fn html(_: *const App, allocator: std.mem.Allocator) ![]u8 {
        const node = root() orelse return error.NoPageVisited;
        var out: std.Io.Writer.Allocating = .init(allocator);
        defer out.deinit();
        HtmlGenerator.renderTree(node, &out.writer);
        return out.toOwnedSlice();
    }
};

/// An element on the rendered page.
pub const Node = struct {
    node: *UINode,

    /// The element's id.
    pub fn id(self: Node) []const u8 {
        return self.node.uuid;
    }

    /// What kind of element it is: `.Text`, `.Button`, `.Link`, ...
    pub fn elementType(self: Node) types.ElementType {
        return self.node.type;
    }

    /// The element's own text, without its children's.
    pub fn ownText(self: Node) ?[]const u8 {
        return self.node.text;
    }

    /// A link's target.
    pub fn href(self: Node) ?[]const u8 {
        return self.node.href;
    }

    /// The element's children, in order.
    pub fn children(self: Node) ChildIterator {
        return .{ .next_node = self.node.first_child };
    }

    pub const ChildIterator = struct {
        next_node: ?*UINode,

        pub fn next(self: *ChildIterator) ?Node {
            const node = self.next_node orelse return null;
            self.next_node = node.next_sibling;
            return .{ .node = node };
        }
    };
};
