const std = @import("std");
const Vapor = @import("vapor");

const Request = Vapor.Fetch.Request;

fn noop() void {}

test "public API surface used by docs examples compiles" {
    comptime {
        _ = Vapor.init;
        _ = Vapor.Page;
        _ = Vapor.PageFn;
        _ = Vapor.registerLayout;
        _ = Vapor.onMount;
        _ = Vapor.onLayout;
        _ = Vapor.onCommit;
        _ = Vapor.persist;
        _ = Vapor.view;
        _ = Vapor.frame;
        _ = Vapor.arena;
        _ = Vapor.Fetch.Request;
        _ = Vapor.fetch;
        _ = Vapor.TextField;
        _ = Vapor.TextArea;
        _ = Vapor.Style;
        _ = Vapor.Types.ElementType;
        _ = Vapor.IconTokens;

        _ = @TypeOf(Vapor.Text("hello"));
        _ = @TypeOf(Vapor.TextFmt("value: {}", .{42}));
        _ = @TypeOf(Vapor.Button(noop, .{}));
        _ = @TypeOf(Vapor.SubmitButton());
        _ = @TypeOf(Vapor.Stack());
        _ = @TypeOf(Vapor.Row());
        _ = @TypeOf(Vapor.Box());
        _ = @TypeOf(Vapor.Image(.{ .src = "/logo.png", .alt = "Logo" }));
    }
}

fn withFetchRuntime(backing_allocator: std.mem.Allocator) void {
    Vapor.lib.allocator_global = backing_allocator;
    Vapor.lib.frame_arena = @TypeOf(Vapor.lib.frame_arena).init(backing_allocator);
    Request.init();
}

test "fetch coalesces shared requests and separates keyless mutations" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    withFetchRuntime(arena.allocator());
    defer Vapor.lib.frame_arena.deinit();

    const get_a = Vapor.fetch("/api/accounts", .{});
    const get_b = Vapor.fetch("/api/accounts", .{});
    try std.testing.expectEqual(@intFromPtr(get_a), @intFromPtr(get_b));
    try std.testing.expectEqual(@as(?u16, null), get_a.pool_slot);

    const post_a = Vapor.fetch("/api/accounts", .{ .method = .POST });
    const post_b = Vapor.fetch("/api/accounts", .{ .method = .POST });
    try std.testing.expect(@intFromPtr(post_a) != @intFromPtr(post_b));
    try std.testing.expect(post_a.pool_slot != null);
    try std.testing.expect(post_b.pool_slot != null);
}

test "fetch coalesces keyed mutations by explicit key" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    withFetchRuntime(arena.allocator());
    defer Vapor.lib.frame_arena.deinit();

    const keyed_a = Vapor.fetch("/api/sync", .{ .method = .POST, .key = "account-sync" });
    const keyed_b = Vapor.fetch("/api/sync", .{ .method = .POST, .key = "account-sync" });
    const keyed_c = Vapor.fetch("/api/sync", .{ .method = .POST, .key = "other-sync" });

    try std.testing.expectEqual(@intFromPtr(keyed_a), @intFromPtr(keyed_b));
    try std.testing.expect(@intFromPtr(keyed_a) != @intFromPtr(keyed_c));
    try std.testing.expectEqual(@as(?u16, null), keyed_a.pool_slot);
}

const CallbackState = struct {
    calls: usize = 0,
    last_result: ?Vapor.Fetch.Result = null,
};

fn captureFetchResult(result: Vapor.Fetch.Result, state: *CallbackState) void {
    state.calls += 1;
    state.last_result = result;
}

test "fetch mock ok response stores result and invokes callback" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    withFetchRuntime(arena.allocator());
    defer Vapor.lib.frame_arena.deinit();

    const fetch = Vapor.fetch("/api/health", .{});
    fetch.mock = .{ .ok_response = .{
        .status = 200,
        .body = "{\"ok\":true}",
        .headers = null,
        .url = "/api/health",
        .content_type = "application/json",
        .content_length = 11,
        .elapsed_ms = 3,
        .redirected = false,
    } };

    var state = CallbackState{};
    fetch.handle(captureFetchResult, .{&state});

    try std.testing.expectEqual(@as(usize, 1), state.calls);
    try std.testing.expectEqual(Vapor.Fetch.State.ok, fetch.state());
    try std.testing.expect(fetch.response().?.isOk());
    try std.testing.expectEqualStrings("{\"ok\":true}", state.last_result.?.body().?);
}

test "fetch async callback stores parsed response and clears registry" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    withFetchRuntime(arena.allocator());
    defer Vapor.lib.frame_arena.deinit();

    const fetch = Vapor.fetch("/api/profile", .{});
    var state = CallbackState{};
    fetch.handle(captureFetchResult, .{&state});

    const callback_id = fetch.entry.in_flight_id.?;
    try std.testing.expectEqual(Vapor.Fetch.State.loading, fetch.state());
    try std.testing.expectEqual(@as(u32, 1), Vapor.Fetch.fetch_callback_registry.count());

    var wire = "{\"ok\":true,\"status\":200,\"body\":\"profile\",\"url\":\"/api/profile\",\"content_type\":\"text/plain\",\"content_length\":7,\"elapsed_ms\":12,\"redirected\":false}".*;
    Vapor.Fetch.resumecallback(callback_id, &wire);

    try std.testing.expectEqual(@as(usize, 1), state.calls);
    try std.testing.expectEqual(Vapor.Fetch.State.ok, fetch.state());
    try std.testing.expectEqual(@as(u32, 0), Vapor.Fetch.fetch_callback_registry.count());
    try std.testing.expectEqualStrings("profile", state.last_result.?.body().?);
}

test "frame allocator reports empty state before route selection" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var frame_allocator = @TypeOf(Vapor.lib.frame_arena).init(arena.allocator());
    defer frame_allocator.deinit();

    try std.testing.expectEqual(@as(usize, 0), frame_allocator.queryBytesUsed());
    try std.testing.expectEqual(@as(usize, 0), frame_allocator.queryNodes());
    try std.testing.expect(frame_allocator.getStats() == null);
    try std.testing.expect(frame_allocator.nodeAlloc() == null);
}

test "frame allocator tracks current route frame stats" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var frame_allocator = @TypeOf(Vapor.lib.frame_arena).init(arena.allocator());
    defer frame_allocator.deinit();

    const route_arena = frame_allocator.createRouteArena();
    defer {
        route_arena.deinit();
        arena.allocator().destroy(route_arena);
    }

    frame_allocator.setCurrentRoute(route_arena);
    frame_allocator.incrementNodeCount();
    frame_allocator.incrementItemCount();
    frame_allocator.addBytesUsed(128);

    const stats = frame_allocator.getStats().?;
    try std.testing.expectEqual(@as(usize, 1), stats.nodes_allocated);
    try std.testing.expectEqual(@as(usize, 1), stats.items_allocated);
    try std.testing.expectEqual(@as(usize, 128), stats.bytes_used);
    try std.testing.expectEqual(@as(usize, 1), frame_allocator.queryNodes());

    frame_allocator.beginFrame();
    const next_stats = frame_allocator.getStats().?;
    try std.testing.expectEqual(@as(usize, 0), next_stats.nodes_allocated);
    try std.testing.expectEqual(@as(usize, 0), next_stats.items_allocated);
    try std.testing.expectEqual(@as(usize, 0), next_stats.bytes_used);
}

const Reconciler = Vapor.Testing.Reconciler;
const UIContext = Vapor.Testing.UIContext;
const UINode = UIContext.UINode;
const FrameAllocator = Vapor.Testing.FrameAllocator;
const RouteFrameArena = FrameAllocator.RouteFrameArena;

const NodeSpec = struct {
    uuid: []const u8,
    index: usize,
    finger_print: u32,
    props_hash: u32 = 0,
    style_hash: u32 = 0,
    hooks_hash: u32 = 0,
    text: ?[]const u8 = null,
    elem_type: Vapor.Types.ElementType = .Text,
};

fn initReconcilerRuntime(allocator: std.mem.Allocator) *RouteFrameArena {
    Vapor.lib.allocator_global = allocator;
    Vapor.lib.frame_arena = FrameAllocator.init(allocator);
    const route_arena = Vapor.lib.frame_arena.createRouteArena();
    Vapor.lib.frame_arena.setCurrentRoute(route_arena);
    Vapor.lib.has_dirty = false;
    Vapor.lib.rerender_everything = false;
    Vapor.Animation.new();
    Vapor.Animation.removal_queue.clearRetainingCapacity();
    return route_arena;
}

fn deinitReconcilerRuntime(allocator: std.mem.Allocator, route_arena: *RouteFrameArena) void {
    route_arena.deinit();
    allocator.destroy(route_arena);
    Vapor.lib.frame_arena.deinit();
}

fn makeNode(allocator: std.mem.Allocator, spec: NodeSpec) !*UINode {
    const node = try allocator.create(UINode);
    node.* = .{
        .uuid = spec.uuid,
        .index = spec.index,
        .finger_print = spec.finger_print,
        .props_hash = spec.props_hash,
        .style_hash = spec.style_hash,
        .hooks_hash = spec.hooks_hash,
        .text = spec.text,
        .type = spec.elem_type,
    };
    return node;
}

fn makeTree(allocator: std.mem.Allocator, specs: []const NodeSpec) !*UINode {
    const root = try makeNode(allocator, .{
        .uuid = "root",
        .index = 0,
        .finger_print = 1,
        .elem_type = .Block,
    });

    for (specs) |spec| {
        const child_node = try makeNode(allocator, spec);
        root.appendChild(child_node);
    }

    return root;
}

fn child(root: *UINode, index: usize) *UINode {
    return root.childAt(index) orelse unreachable;
}

fn expectRemovalId(handle: u32, expected: []const u8) !void {
    const ptr = Vapor.Animation.getRemovalIdPtr(handle) orelse return error.MissingRemoval;
    const len = Vapor.Animation.getRemovalIdLen(handle);
    try std.testing.expectEqualStrings(expected, ptr[0..len]);
}

test "reconciler leaves unchanged same-length children clean" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const route_arena = initReconcilerRuntime(arena.allocator());
    defer deinitReconcilerRuntime(arena.allocator(), route_arena);

    const old_root = try makeTree(arena.allocator(), &.{
        .{ .uuid = "a", .index = 0, .finger_print = 10, .props_hash = 10, .text = "A" },
        .{ .uuid = "b", .index = 1, .finger_print = 20, .props_hash = 20, .text = "B" },
    });
    const new_root = try makeTree(arena.allocator(), &.{
        .{ .uuid = "a", .index = 0, .finger_print = 10, .props_hash = 10, .text = "A" },
        .{ .uuid = "b", .index = 1, .finger_print = 20, .props_hash = 20, .text = "B" },
    });

    Reconciler.traverseNodes(old_root, new_root);

    try std.testing.expect(!Vapor.lib.has_dirty);
    try std.testing.expect(!new_root.dirty);
    try std.testing.expect(!child(new_root, 0).dirty);
    try std.testing.expect(!child(new_root, 1).dirty);
    try std.testing.expectEqual(@as(usize, 0), Vapor.Animation.removalCount());
}

test "reconciler marks text and prop updates dirty without removals" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const route_arena = initReconcilerRuntime(arena.allocator());
    defer deinitReconcilerRuntime(arena.allocator(), route_arena);

    const old_root = try makeTree(arena.allocator(), &.{
        .{ .uuid = "slot-0", .index = 0, .finger_print = 10, .props_hash = 10, .text = "old" },
    });
    const new_root = try makeTree(arena.allocator(), &.{
        .{ .uuid = "slot-0", .index = 0, .finger_print = 11, .props_hash = 11, .text = "new" },
    });

    Reconciler.traverseNodes(old_root, new_root);

    const updated = child(new_root, 0);
    try std.testing.expect(Vapor.lib.has_dirty);
    try std.testing.expect(updated.dirty);
    try std.testing.expect(updated.props_changed);
    try std.testing.expectEqual(@as(usize, 0), Vapor.Animation.removalCount());
}

test "reconciler marks hook updates dirty without structural removals" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const route_arena = initReconcilerRuntime(arena.allocator());
    defer deinitReconcilerRuntime(arena.allocator(), route_arena);

    const old_root = try makeTree(arena.allocator(), &.{
        .{ .uuid = "hooked", .index = 0, .finger_print = 30, .hooks_hash = 1 },
    });
    const new_root = try makeTree(arena.allocator(), &.{
        .{ .uuid = "hooked", .index = 0, .finger_print = 31, .hooks_hash = 2 },
    });

    Reconciler.traverseNodes(old_root, new_root);

    const updated = child(new_root, 0);
    try std.testing.expect(Vapor.lib.has_dirty);
    try std.testing.expect(updated.dirty);
    try std.testing.expect(updated.hooks_changed);
    try std.testing.expectEqual(@as(usize, 0), Vapor.Animation.removalCount());
}

test "reconciler handles keyed same-length reorder without removals" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const route_arena = initReconcilerRuntime(arena.allocator());
    defer deinitReconcilerRuntime(arena.allocator(), route_arena);

    const old_root = try makeTree(arena.allocator(), &.{
        .{ .uuid = "a", .index = 0, .finger_print = 10 },
        .{ .uuid = "b", .index = 1, .finger_print = 20 },
        .{ .uuid = "c", .index = 2, .finger_print = 30 },
    });
    const new_root = try makeTree(arena.allocator(), &.{
        .{ .uuid = "b", .index = 0, .finger_print = 20 },
        .{ .uuid = "a", .index = 1, .finger_print = 10 },
        .{ .uuid = "c", .index = 2, .finger_print = 30 },
    });

    Reconciler.traverseNodes(old_root, new_root);

    try std.testing.expect(Vapor.lib.has_dirty);
    try std.testing.expect(child(new_root, 0).dirty);
    try std.testing.expect(child(new_root, 1).dirty);
    try std.testing.expect(!child(new_root, 2).dirty);
    try std.testing.expectEqual(@as(usize, 0), Vapor.Animation.removalCount());
}

test "reconciler marks keyed tail additions as added" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const route_arena = initReconcilerRuntime(arena.allocator());
    defer deinitReconcilerRuntime(arena.allocator(), route_arena);

    const old_root = try makeTree(arena.allocator(), &.{
        .{ .uuid = "a", .index = 0, .finger_print = 10 },
        .{ .uuid = "b", .index = 1, .finger_print = 20 },
    });
    const new_root = try makeTree(arena.allocator(), &.{
        .{ .uuid = "a", .index = 0, .finger_print = 10 },
        .{ .uuid = "b", .index = 1, .finger_print = 20 },
        .{ .uuid = "c", .index = 2, .finger_print = 30 },
    });

    Reconciler.traverseNodes(old_root, new_root);

    const added = child(new_root, 2);
    try std.testing.expect(Vapor.lib.has_dirty);
    try std.testing.expect(added.dirty);
    try std.testing.expectEqual(Vapor.Types.StateType.added, added.state_type);
    try std.testing.expectEqual(@as(usize, 0), Vapor.Animation.removalCount());
}

test "reconciler queues keyed tail deletions and marks dirty" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const route_arena = initReconcilerRuntime(arena.allocator());
    defer deinitReconcilerRuntime(arena.allocator(), route_arena);

    const old_root = try makeTree(arena.allocator(), &.{
        .{ .uuid = "a", .index = 0, .finger_print = 10 },
        .{ .uuid = "b", .index = 1, .finger_print = 20 },
        .{ .uuid = "c", .index = 2, .finger_print = 30 },
    });
    const new_root = try makeTree(arena.allocator(), &.{
        .{ .uuid = "a", .index = 0, .finger_print = 10 },
        .{ .uuid = "b", .index = 1, .finger_print = 20 },
    });

    Reconciler.traverseNodes(old_root, new_root);

    try std.testing.expect(Vapor.lib.has_dirty);
    try std.testing.expectEqual(@as(usize, 1), Vapor.Animation.removalCount());
    try expectRemovalId(0, "c");
}

test "reconciler replaces same-length keyed children with removal and addition" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const route_arena = initReconcilerRuntime(arena.allocator());
    defer deinitReconcilerRuntime(arena.allocator(), route_arena);

    const old_root = try makeTree(arena.allocator(), &.{
        .{ .uuid = "a", .index = 0, .finger_print = 10 },
        .{ .uuid = "b", .index = 1, .finger_print = 20 },
        .{ .uuid = "c", .index = 2, .finger_print = 30 },
    });
    const new_root = try makeTree(arena.allocator(), &.{
        .{ .uuid = "a", .index = 0, .finger_print = 10 },
        .{ .uuid = "d", .index = 1, .finger_print = 40 },
        .{ .uuid = "c", .index = 2, .finger_print = 30 },
    });

    Reconciler.traverseNodes(old_root, new_root);

    const replacement = child(new_root, 1);
    try std.testing.expect(Vapor.lib.has_dirty);
    try std.testing.expect(replacement.dirty);
    try std.testing.expectEqual(Vapor.Types.StateType.added, replacement.state_type);
    try std.testing.expectEqual(@as(usize, 1), Vapor.Animation.removalCount());
    try expectRemovalId(0, "b");
}

test "reconciler queues all old children when new child list is empty" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const route_arena = initReconcilerRuntime(arena.allocator());
    defer deinitReconcilerRuntime(arena.allocator(), route_arena);

    const old_root = try makeTree(arena.allocator(), &.{
        .{ .uuid = "a", .index = 0, .finger_print = 10 },
        .{ .uuid = "b", .index = 1, .finger_print = 20 },
    });
    const new_root = try makeTree(arena.allocator(), &.{});

    Reconciler.traverseNodes(old_root, new_root);

    try std.testing.expect(Vapor.lib.has_dirty);
    try std.testing.expectEqual(@as(usize, 2), Vapor.Animation.removalCount());
    try expectRemovalId(0, "a");
    try expectRemovalId(1, "b");
}

const RenderVariant = enum { stable, updated, removed };
var render_variant: RenderVariant = .stable;

fn textElement(value: []const u8, element_id: []const u8) void {
    const text_node = Vapor.Text(value).id(element_id);
    text_node.end();
}

fn RenderCyclePage() void {
    const app = Vapor.Stack().id("app");
    app.children({
        switch (render_variant) {
            .stable => {
                textElement("Alpha", "alpha");
                textElement("Beta", "beta");
            },
            .updated => {
                textElement("Alpha changed", "alpha");
                textElement("Beta", "beta");
            },
            .removed => {
                textElement("Alpha changed", "alpha");
            },
        }
    });
}

fn initRenderCycleRuntime(route: []const u8) void {
    Vapor.init(.{});
    Vapor.Animation.new();
    Vapor.lib.resetRerender();
    Vapor.Animation.removal_queue.clearRetainingCapacity();
    render_variant = .stable;
    Vapor.Page(.{ .route = route }, RenderCyclePage, null);
}

fn renderRoute(route: []const u8) !*UINode {
    const owned_route = try Vapor.lib.allocator_global.dupeZ(u8, route);
    try Vapor.lib.renderCycle(owned_route.ptr);
    return Vapor.lib.getRenderUINodeRootPtr() orelse error.MissingRenderRoot;
}

fn renderApp(route: []const u8) !*UINode {
    const root = try renderRoute(route);
    try std.testing.expectEqual(@as(usize, 1), Vapor.lib.getUINodeChildrenCount(root));
    return Vapor.lib.getUINodeChild(root, 0) orelse error.MissingAppNode;
}

// Apps call Vapor.fetch from a page's init() with nothing but Vapor.init
// before it. Fetch.init used to be a separate, undocumented call, and without
// it the first fetch() hit an undefined hashmap.
test "Vapor.init alone makes Fetch usable" {
    Vapor.init(.{});
    const a = Vapor.fetch("/api/after-init", .{});
    const b = Vapor.fetch("/api/after-init", .{});
    try std.testing.expectEqual(@intFromPtr(a), @intFromPtr(b));
}

test "renderCycle exposes rendered UINode tree for a registered page" {
    initRenderCycleRuntime("/cycle-tree");

    const app = try renderApp("/root/cycle-tree");
    try std.testing.expectEqual(Vapor.Types.ElementType.FlexBox, app.type);
    try std.testing.expectEqualStrings("app", app.uuid);
    try std.testing.expectEqual(@as(usize, 2), Vapor.lib.getUINodeChildrenCount(app));

    const alpha = Vapor.lib.getUINodeChild(app, 0) orelse return error.MissingAlphaNode;
    const beta = Vapor.lib.getUINodeChild(app, 1) orelse return error.MissingBetaNode;
    try std.testing.expectEqual(Vapor.Types.ElementType.Text, alpha.type);
    try std.testing.expectEqual(Vapor.Types.ElementType.Text, beta.type);
    try std.testing.expectEqualStrings("alpha", alpha.uuid);
    try std.testing.expectEqualStrings("beta", beta.uuid);
    try std.testing.expectEqualStrings("Alpha", alpha.text.?);
    try std.testing.expectEqualStrings("Beta", beta.text.?);
}

var commit_calls: u32 = 0;
fn countCommit() void {
    commit_calls += 1;
}
fn CommitPage() void {
    Vapor.onCommit(countCommit);
    textElement("committed", "committed");
}

// onCommit callbacks were stored and then cleared without ever being called;
// only the onCommitCtx variant ran.
test "onCommit runs its callback once per render" {
    Vapor.init(.{});
    Vapor.Animation.new();
    Vapor.lib.resetRerender();
    Vapor.Animation.removal_queue.clearRetainingCapacity();
    Vapor.Page(.{ .route = "/commit" }, CommitPage, null);
    commit_calls = 0;

    _ = try renderRoute("/root/commit");
    try std.testing.expectEqual(@as(u32, 1), commit_calls);
    _ = try renderRoute("/root/commit");
    try std.testing.expectEqual(@as(u32, 2), commit_calls);
}

const big_svg = "<svg>" ++ ("<g/>" ** 600) ++ "</svg>";
fn BigSvgPage() void {
    Vapor.Svg(.{ .svg = big_svg }).end();
}

// An Svg over the inline limit used to return a builder without its node,
// so .end() panicked with "builder has no node".
test "an oversized Svg renders empty instead of panicking" {
    // The oversized Svg is reported once, as an error.
    Vapor.lib.expected_reports = 1;
    defer std.testing.expectEqual(@as(u32, 0), Vapor.lib.expected_reports) catch @panic("expected error not reported");
    comptime std.debug.assert(big_svg.len > 2048);
    Vapor.init(.{});
    Vapor.Animation.new();
    Vapor.lib.resetRerender();
    Vapor.Animation.removal_queue.clearRetainingCapacity();
    Vapor.Page(.{ .route = "/big-svg" }, BigSvgPage, null);
    _ = try renderRoute("/root/big-svg");
}

fn ItemsPage() void {
    Vapor.Box().id("items-box").items(.{ Vapor.Text("a"), Vapor.Heading(2, "b") });
    Vapor.Box().id("child-box").child(Vapor.Text("c"));
}

// Text and Center return *Builder; items()/child() only finished children
// of type Builder, so a Text passed to them was left unconfigured.
test "items and child finish every child builder, pointers included" {
    Vapor.init(.{});
    Vapor.Animation.new();
    Vapor.lib.resetRerender();
    Vapor.Animation.removal_queue.clearRetainingCapacity();
    Vapor.Page(.{ .route = "/items" }, ItemsPage, null);
    const root = try renderRoute("/root/items");
    const items_box = Vapor.lib.getUINodeChild(root, 0) orelse return error.MissingItemsBox;
    const a = Vapor.lib.getUINodeChild(items_box, 0) orelse return error.MissingA;
    try std.testing.expectEqualStrings("a", a.text orelse return error.TextNotConfigured);
    const child_box = Vapor.lib.getUINodeChild(root, 1) orelse return error.MissingChildBox;
    const c = Vapor.lib.getUINodeChild(child_box, 0) orelse return error.MissingC;
    try std.testing.expectEqualStrings("c", c.text orelse return error.TextNotConfigured);
}

var deinit_calls: u32 = 0;
fn DeinitPageA() void {
    textElement("a", "page-a");
}
fn deinitPageA() void {
    deinit_calls += 1;
}
fn DeinitPageB() void {
    textElement("b", "page-b");
}

// Page's deinit argument went into a map keyed by u32 with a string key (a
// compile error once used) and nothing ever read the map.
test "a page's deinit runs when the app navigates away from it" {
    Vapor.init(.{});
    Vapor.Animation.new();
    Vapor.lib.resetRerender();
    Vapor.Animation.removal_queue.clearRetainingCapacity();
    Vapor.Page(.{ .route = "/deinit-a" }, DeinitPageA, deinitPageA);
    Vapor.Page(.{ .route = "/deinit-b" }, DeinitPageB, null);
    deinit_calls = 0;

    _ = try renderRoute("/root/deinit-a");
    _ = try renderRoute("/root/deinit-a");
    try std.testing.expectEqual(@as(u32, 0), deinit_calls);
    _ = try renderRoute("/root/deinit-b");
    try std.testing.expectEqual(@as(u32, 1), deinit_calls);
    _ = try renderRoute("/root/deinit-b");
    try std.testing.expectEqual(@as(u32, 1), deinit_calls);
}

var view_ptrs: [3]usize = undefined;
var view_ptr_count: usize = 0;
var view_bytes_at_deinit: u8 = 0;
var view_bytes: []u8 = &.{};
fn viewAlloc() void {
    view_bytes = Vapor.arena(.view).alloc(u8, 64) catch unreachable;
    @memset(view_bytes, 7);
    view_ptrs[view_ptr_count] = @intFromPtr(view_bytes.ptr);
    view_ptr_count += 1;
}
fn ViewPageA() void {
    viewAlloc();
    textElement("a", "view-a");
}
fn deinitViewPageA() void {
    view_bytes_at_deinit = view_bytes[0];
    view_bytes = &.{};
}
fn ViewPageB() void {
    viewAlloc();
    textElement("b", "view-b");
}

// `.view` memory was never freed: arena(.view) used an arena nothing reset.
test "view memory lasts while the page is shown and is freed on leaving it" {
    Vapor.init(.{});
    Vapor.Animation.new();
    Vapor.lib.resetRerender();
    Vapor.Animation.removal_queue.clearRetainingCapacity();
    Vapor.Page(.{ .route = "/view-a" }, ViewPageA, deinitViewPageA);
    Vapor.Page(.{ .route = "/view-b" }, ViewPageB, null);
    view_ptr_count = 0;

    _ = try renderRoute("/root/view-a");
    _ = try renderRoute("/root/view-a");
    // A rerender of the same page keeps its view memory.
    try std.testing.expect(view_ptrs[1] != view_ptrs[0]);
    _ = try renderRoute("/root/view-b");
    // The deinit saw the memory intact; the next page reuses it.
    try std.testing.expectEqual(@as(u8, 7), view_bytes_at_deinit);
    try std.testing.expectEqual(view_ptrs[0], view_ptrs[2]);
}

test "renderCycle leaves stable same-route rerenders clean" {
    initRenderCycleRuntime("/cycle-stable");

    _ = try renderApp("/root/cycle-stable");
    Vapor.lib.resetRerender();
    Vapor.Animation.removal_queue.clearRetainingCapacity();

    const app = try renderApp("/root/cycle-stable");
    try std.testing.expectEqual(@as(usize, 2), Vapor.lib.getUINodeChildrenCount(app));
    try std.testing.expect(!Vapor.lib.hasDirty());
    try std.testing.expectEqual(@as(usize, 0), Vapor.Animation.removalCount());
}

test "renderCycle marks updated rendered text dirty without removals" {
    initRenderCycleRuntime("/cycle-update");

    _ = try renderApp("/root/cycle-update");
    Vapor.lib.resetRerender();
    Vapor.Animation.removal_queue.clearRetainingCapacity();

    render_variant = .updated;
    const app = try renderApp("/root/cycle-update");
    const alpha = Vapor.lib.getUINodeChild(app, 0) orelse return error.MissingAlphaNode;
    const beta = Vapor.lib.getUINodeChild(app, 1) orelse return error.MissingBetaNode;

    try std.testing.expect(Vapor.lib.hasDirty());
    try std.testing.expect(alpha.dirty);
    try std.testing.expect(!beta.dirty);
    try std.testing.expectEqualStrings("Alpha changed", alpha.text.?);
    try std.testing.expectEqual(@as(usize, 0), Vapor.Animation.removalCount());
}

test "renderCycle queues removals from rendered child deletions" {
    initRenderCycleRuntime("/cycle-remove");

    render_variant = .updated;
    _ = try renderApp("/root/cycle-remove");
    Vapor.lib.resetRerender();
    Vapor.Animation.removal_queue.clearRetainingCapacity();

    render_variant = .removed;
    const app = try renderApp("/root/cycle-remove");

    try std.testing.expect(Vapor.lib.hasDirty());
    try std.testing.expectEqual(@as(usize, 1), Vapor.lib.getUINodeChildrenCount(app));
    const alpha = Vapor.lib.getUINodeChild(app, 0) orelse return error.MissingAlphaNode;
    try std.testing.expectEqualStrings("alpha", alpha.uuid);
    try std.testing.expectEqual(@as(usize, 1), Vapor.Animation.removalCount());
    try expectRemovalId(0, "beta");
}

// -----------------------------------------------------------------------------
// Writer bounds
//
// Writer fills fixed static buffers (4096/8192 bytes) that are handed to JS as
// C strings. It previously performed no bounds checks at all: the writes were
// plain @memcpy into buffer[pos..pos+len] and the `!void` return type never
// produced an error, so in ReleaseFast/ReleaseSmall an oversized style silently
// wrote past the end of the buffer.
// -----------------------------------------------------------------------------

const Writer = Vapor.Writer;

test "writer reserves a trailing byte so callers can NUL-terminate" {
    var buffer: [16]u8 = undefined;
    var writer: Writer = undefined;
    writer.init(&buffer);

    // Capacity is one short of the buffer, leaving room for the terminator.
    try std.testing.expectEqual(@as(usize, 15), writer.size);

    try writer.write("012345678901234");
    try std.testing.expectEqual(@as(usize, 15), writer.pos);
    try std.testing.expect(!writer.overflowed);

    // The NUL every call site writes at `pos` stays inside the buffer.
    buffer[writer.pos] = 0;
    try std.testing.expectEqual(@as(u8, 0), buffer[15]);
}

test "writer refuses writes past capacity instead of overflowing" {
    // The overflow is reported once, as an error.
    Vapor.lib.expected_reports = 1;
    defer std.testing.expectEqual(@as(u32, 0), Vapor.lib.expected_reports) catch @panic("expected error not reported");
    var buffer: [16]u8 = undefined;
    var writer: Writer = undefined;
    writer.init(&buffer);

    try writer.write("0123456789");
    try std.testing.expectError(error.OutOfSpace, writer.write("way too long to fit"));

    // The rejected write left the cursor and contents untouched.
    try std.testing.expectEqual(@as(usize, 10), writer.pos);
    try std.testing.expectEqualStrings("0123456789", writer.getAll());
    try std.testing.expect(writer.overflowed);

    // A write that still fits after a refusal is accepted.
    try writer.write("abcde");
    try std.testing.expectEqualStrings("0123456789abcde", writer.getAll());
}

test "writer bounds-checks every write entry point" {
    // The overflow is reported once, as an error.
    Vapor.lib.expected_reports = 1;
    defer std.testing.expectEqual(@as(u32, 0), Vapor.lib.expected_reports) catch @panic("expected error not reported");
    var buffer: [4]u8 = undefined;
    var writer: Writer = undefined;
    writer.init(&buffer);
    try std.testing.expectEqual(@as(usize, 3), writer.size);

    try writer.write("abc");
    try std.testing.expectError(error.OutOfSpace, writer.writeByte('x'));
    try std.testing.expectError(error.OutOfSpace, writer.write("x"));
    try std.testing.expectError(error.OutOfSpace, writer.writeU8Num(200));
    try std.testing.expectError(error.OutOfSpace, writer.writeU16(65535));
    try std.testing.expectError(error.OutOfSpace, writer.writeU32(4294967295));
    try std.testing.expectError(error.OutOfSpace, writer.writeUsize(123456));
    try std.testing.expectError(error.OutOfSpace, writer.writeI16(-12345));
    try std.testing.expectError(error.OutOfSpace, writer.writeI32(-1234567));
    try std.testing.expectError(error.OutOfSpace, writer.writeF32(3.14159));
    try std.testing.expectError(error.OutOfSpace, writer.writeF16(2.5));

    // Nothing moved the cursor past what actually fit.
    try std.testing.expectEqual(@as(usize, 3), writer.pos);
    try std.testing.expectEqualStrings("abc", writer.getAll());
}

test "writer reset clears the overflow flag" {
    // The overflow is reported once, as an error.
    Vapor.lib.expected_reports = 1;
    defer std.testing.expectEqual(@as(u32, 0), Vapor.lib.expected_reports) catch @panic("expected error not reported");
    var buffer: [8]u8 = undefined;
    var writer: Writer = undefined;
    writer.init(&buffer);

    try std.testing.expectError(error.OutOfSpace, writer.write("far too long"));
    try std.testing.expect(writer.overflowed);

    writer.reset();
    try std.testing.expect(!writer.overflowed);
    try std.testing.expectEqual(@as(usize, 0), writer.pos);
    try writer.write("ok");
    try std.testing.expectEqualStrings("ok", writer.getAll());
}

test "writer handles a zero-length buffer without underflowing capacity" {
    // The overflow is reported once, as an error.
    Vapor.lib.expected_reports = 1;
    defer std.testing.expectEqual(@as(u32, 0), Vapor.lib.expected_reports) catch @panic("expected error not reported");
    var buffer: [0]u8 = undefined;
    var writer: Writer = undefined;
    writer.init(&buffer);

    try std.testing.expectEqual(@as(usize, 0), writer.size);
    try std.testing.expectError(error.OutOfSpace, writer.writeByte('x'));
}

// -----------------------------------------------------------------------------
// JWT signature length
//
// The decoded signature length comes straight off the wire. verify() used to
// @memcpy it into a fixed-size array without checking, which is illegal
// behaviour in Zig when the lengths differ: a panic under ReleaseSafe, a buffer
// overflow under the ReleaseSmall builds that ship.
// -----------------------------------------------------------------------------

const JWT = Vapor.Testing.JWT;

fn hs256Token(allocator: std.mem.Allocator, signature_b64: []const u8) []const u8 {
    const encoder = std.base64.url_safe_no_pad.Encoder;

    const header = "{\"alg\":\"HS256\",\"typ\":\"JWT\"}";
    const claims = "{\"exp\":99999999999,\"sub\":\"alice\"}";

    const header_b64 = allocator.alloc(u8, encoder.calcSize(header.len)) catch unreachable;
    _ = encoder.encode(header_b64, header);
    const claims_b64 = allocator.alloc(u8, encoder.calcSize(claims.len)) catch unreachable;
    _ = encoder.encode(claims_b64, claims);

    return std.mem.join(allocator, ".", &.{ header_b64, claims_b64, signature_b64 }) catch unreachable;
}

test "jwt rejects signatures that are not the algorithm's length" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const Claims = struct { sub: []const u8 };

    // HS256 expects a 32-byte signature. Each of these decodes to some other
    // length, and every one must be refused rather than crash or overflow.
    const wrong_lengths = [_][]const u8{
        "", // 0 bytes
        "AA", // 1 byte
        "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", // 31 bytes
        "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", // 32 bytes + 1 bit of slack
        "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", // 63 bytes
    };

    for (wrong_lengths) |sig_b64| {
        const token = hs256Token(allocator, sig_b64);
        const result = JWT.decode(allocator, Claims, token, .{ .secret = "test-secret" }, .{});
        try std.testing.expectError(error.InvalidSignature, result);
    }
}

test "jwt still rejects a correct-length but wrong signature" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const Claims = struct { sub: []const u8 };

    // Exactly 32 bytes of zeroes: right length, wrong value. This must fail on
    // the constant-time compare, not on the length guard.
    const encoder = std.base64.url_safe_no_pad.Encoder;
    const zeroes = [_]u8{0} ** 32;
    const sig_b64 = try allocator.alloc(u8, encoder.calcSize(zeroes.len));
    _ = encoder.encode(sig_b64, &zeroes);

    const token = hs256Token(allocator, sig_b64);
    const result = JWT.decode(allocator, Claims, token, .{ .secret = "test-secret" }, .{});
    try std.testing.expectError(error.InvalidSignature, result);
}

// -----------------------------------------------------------------------------
// HTML escaping
//
// The SSR path wrote ui_node.text and attribute values straight into the served
// document, so any string containing markup stopped being content and became
// tags. Vapor.Html(...) and Svg stay raw on purpose; everything else escapes.
// -----------------------------------------------------------------------------

const HtmlGenerator = Vapor.Testing.HtmlGenerator;

fn escape(buf: []u8, text: []const u8) []const u8 {
    var out = std.Io.Writer.fixed(buf);
    HtmlGenerator.escapeInto(&out, text);
    return out.buffered();
}

test "html escaping neutralises markup in text and attributes" {
    var buf: [512]u8 = undefined;

    // The classic injection: without escaping this closes the element and opens
    // a script tag in the served page.
    try std.testing.expectEqualStrings(
        "&lt;script&gt;alert(1)&lt;/script&gt;",
        escape(&buf, "<script>alert(1)</script>"),
    );

    // Breaking out of a double-quoted attribute value.
    try std.testing.expectEqualStrings(
        "x&quot; onerror=&quot;alert(1)",
        escape(&buf, "x\" onerror=\"alert(1)"),
    );

    // Single quotes matter for single-quoted attributes.
    try std.testing.expectEqualStrings(
        "x&#39; onerror=&#39;alert(1)",
        escape(&buf, "x' onerror='alert(1)"),
    );

    // Ampersand first, so an escape cannot be double-decoded into markup.
    try std.testing.expectEqualStrings("&amp;lt;script&amp;gt;", escape(&buf, "&lt;script&gt;"));
}

fn HeadingListPage() void {
    Vapor.Heading(2, "Title").end();
    Vapor.Text("after").end();
    Vapor.List().children({
        Vapor.ListItem().children({
            Vapor.Text("item").end();
        });
    });
}

// Headings closed with </h> instead of </h2>, so prerendered pages put what
// followed inside the heading; list items opened with a stray quote.
test "prerendered headings and list items are well-formed" {
    Vapor.init(.{});
    Vapor.Animation.new();
    Vapor.lib.resetRerender();
    Vapor.Animation.removal_queue.clearRetainingCapacity();
    Vapor.Page(.{ .route = "/html-shape" }, HeadingListPage, null);
    const root = try renderRoute("/root/html-shape");

    var out: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer out.deinit();
    Vapor.Testing.HtmlGenerator.renderTree(root, &out.writer);
    const html = out.written();
    const close = std.mem.indexOf(u8, html, "</h2>") orelse return error.HeadingNotClosed;
    const after = std.mem.indexOf(u8, html, ">after<") orelse return error.MissingText;
    try std.testing.expect(close < after);
    try std.testing.expect(std.mem.indexOf(u8, html, "</h>") == null);
    try std.testing.expect(std.mem.indexOf(u8, html, "\"\">") == null);
}

test "html escaping leaves ordinary text untouched" {
    var buf: [512]u8 = undefined;

    try std.testing.expectEqualStrings("", escape(&buf, ""));
    try std.testing.expectEqualStrings("Hello, world", escape(&buf, "Hello, world"));
    try std.testing.expectEqualStrings("caf\u{00e9} \u{2014} 100%", escape(&buf, "caf\u{00e9} \u{2014} 100%"));

    // Runs between metacharacters are copied whole, including the boundaries.
    try std.testing.expectEqualStrings("a&lt;b&gt;c", escape(&buf, "a<b>c"));
    try std.testing.expectEqualStrings("&lt;&gt;&amp;", escape(&buf, "<>&"));
    try std.testing.expectEqualStrings("&lt;lead", escape(&buf, "<lead"));
    try std.testing.expectEqualStrings("trail&gt;", escape(&buf, "trail>"));
}

// -----------------------------------------------------------------------------
// README examples
//
// Every construct the README shows is type-checked here, so documentation
// cannot drift away from the API without the build failing. These are comptime
// type queries — nothing renders.
// -----------------------------------------------------------------------------

fn readmeOnClick() void {}
fn docEventHandler(_: *Vapor.Event) void {}
fn docCtxHandler(_: u32, _: *Vapor.Event) void {}
fn docHook(_: u32) void {}

const DocForm = struct { name: []const u8 = "", age: u32 = 0 };
fn docFetched(_: Vapor.Fetch.Result, _: u32) void {}
fn docPlainFetched(_: Vapor.Fetch.Result) void {}
fn docNoArgs() void {}
fn docLayout(_: *const fn () void) void {}

// Never called; taking its address compiles a call to every generic public
// function, which nothing else compiles until an app happens to call it.
fn docGenericApi() !void {
    Vapor.timeout("doc", 100, docHook, .{@as(u32, 1)});
    Vapor.onMount(docHook, .{@as(u32, 1)});
    Vapor.onLayout(docHook, .{@as(u32, 1)});
    _ = Vapor.registerHook("/doc", docNoArgs, .before);
    _ = Vapor.addGlobalListener(.keydown, docEventHandler);
    _ = Vapor.addGlobalListenerCtx(.keydown, docCtxHandler, .{@as(u32, 1)});
    _ = Vapor.removeGlobalListener(.keydown, 1);
    Vapor.store("k", @as(u32, 1));
    Vapor.store("k", @as(i64, -1));
    Vapor.store("k", @as(f32, 1.5));
    Vapor.store("k", true);
    Vapor.store("k", "text");
    Vapor.store("k", Vapor.Arena.frame);
    _ = Vapor.load([]const u8, "k");
    _ = Vapor.load(u32, "k");
    _ = Vapor.load(i64, "k");
    _ = Vapor.load(f32, "k");
    _ = Vapor.load(bool, "k");
    _ = Vapor.array(u32, .frame);
    _ = Vapor.dupe("x", .view);
    _ = Vapor.fmtln("{d}", .{1});
    _ = Vapor.fmtArena("{d}", .{1}, .persist);
    _ = Vapor.cloneFrame(@as([]const u8, "x"));
    _ = Vapor.frame.fmt("{d}", .{1});
    _ = try Vapor.frame.alloc(u8, 4);
    _ = Vapor.frame.HashMap(u32, u32);
    _ = Vapor.frame.array(u32);
    _ = Vapor.view.fmt("{d}", .{1});
    _ = Vapor.view.HashMap(u32, u32);
    _ = Vapor.view.array(u32);
    _ = Vapor.persist.fmt("{d}", .{1});
    _ = try Vapor.persist.alloc(u8, 4);
    _ = Vapor.persist.array(u32);
    var x: u32 = 0;
    _ = Vapor.cast(*u32, @as(*anyopaque, @ptrCast(&x)));
    Vapor.println("{d}", .{1});
    Vapor.print(.info, "{d}", .{1});
    Vapor.print(.err, "{d}", .{1});
    Vapor.printErrSrc("{d}", .{1}, @src());
    Vapor.alert("{d}", .{1});
    const req = Vapor.fetch("/doc", .{});
    req.handle(docFetched, .{@as(u32, 1)});
    req.handle(docPlainFetched, .{});
    var form: DocForm = .{};
    var event: Vapor.Event = undefined;
    _ = event.formData(&form);
    Vapor.Hooks(.{ .mounted = docNoArgs })({});
    try Vapor.registerLayout("/doc", docLayout, .{});
    Vapor.KeyStone.authFetch("/doc", .{}, docPlainFetched);
    Vapor.KeyStone.authFetchWithOptions("/doc", .{}, .{}, docPlainFetched);
    Vapor.KeyStone.validateSession(.github, docPlainFetched);
}

// Never called; taking its address compiles every line.
fn docEventMethods() void {
    // Event methods take callbacks, which makes them generic: neither
    // `zig build check` nor ordinary code reaches their bodies until a
    // call instantiates them. onFocus, onBlur, onChange and
    // attachEventCallback all failed to compile once someone called them.
    const box = Vapor.Box();
    _ = box.onFocus(docEventHandler);
    _ = box.onBlur(docEventHandler);
    _ = box.onChange(docCtxHandler, .{@as(u32, 1)});
    _ = box.onEvent(.click, docCtxHandler, .{@as(u32, 1)});
    _ = box.onEvent(.click, docCtxHandler, .{@as(u32, 1)});
    _ = box.onHover(docCtxHandler, .{@as(u32, 1)});
    _ = box.onLeave(docCtxHandler, .{@as(u32, 1)});
    _ = box.onHoverCtx(docCtxHandler, .{@as(u32, 1)});
    _ = box.ifMouseOver(docCtxHandler, .{@as(u32, 1)});
    _ = box.onDragStart(docEventHandler);
    _ = box.onMount(docHook, .{@as(u32, 1)});
    _ = box.onUpdate(docHook, .{@as(u32, 1)});
    _ = box.onDestroy(docHook, .{@as(u32, 1)});
    _ = box.onEvent(.keydown, docCtxHandler, .{@as(u32, 1)});
    Vapor.Box().child(Vapor.Text("x"));
    Vapor.Row().items(.{ Vapor.Text("a"), Vapor.Text("b") });
    Vapor.Box().children({
        Vapor.Text("a").end();
    });
    const field = Vapor.TextField(.string);
    _ = field.onFocus(docEventHandler);
    _ = field.onBlur(docEventHandler);
    _ = field.onKeyDown(docEventHandler);
    _ = field.onHover(docEventHandler);
    _ = field.onLeave(docEventHandler);
    _ = field.onEvent(.click, docCtxHandler, .{@as(u32, 1)});
    _ = field.onEvent(.click, docCtxHandler, .{@as(u32, 1)});
    _ = field.onMount(docHook, .{@as(u32, 1)});
    _ = field.onChange(docCtxHandler, .{@as(u32, 1)});
    _ = field.onHoverCtx(docCtxHandler, .{@as(u32, 1)});
    _ = field.onScroll(docCtxHandler, .{@as(u32, 1)});
    _ = field.placeholder("Name");
    _ = field.val(@as(u32, 3));
    var text_value: []const u8 = "";
    _ = field.bind(&text_value);
    var number_value: u32 = 0;
    _ = Vapor.TextField(.int).bind(&number_value);
}

// The example in src/root.zig's module docs, verbatim.
fn rootDocExample() void {
    Vapor.Page(.{ .route = "/" }, rootDocRender, null);
}
fn rootDocRender() void {
    Vapor.Box().padding(.all(16)).children({
        Vapor.Text("Hello from Zig").fontSize(24).end();
    });
}

test "README examples type-check against the real API" {
    comptime {
        _ = &rootDocExample;

        // Examples in the builder method docs (src/lib/builder/).
        _ = @TypeOf(Vapor.Box().scroll(.{ .y = .scroll }));
        _ = @TypeOf(Vapor.Box().pos(.{ .type = .absolute, .top = .px(0), .right = .px(0) }));
        _ = @TypeOf(Vapor.Box().layout(.center));
        _ = @TypeOf(Vapor.Box().padding(.all(16)).padding(.{ .top = 8, .bottom = 4 }));
        _ = @TypeOf(Vapor.Box().margin(.all(8)));
        _ = @TypeOf(Vapor.Box().size(.full).size(.squarePx(48)));
        _ = @TypeOf(Vapor.Box().width(.px(320)).width(.percent(50)).width(.expand));
        _ = @TypeOf(Vapor.Heading(2, "Settings"));
        _ = @TypeOf(Vapor.TextFmt("{d} items", .{3}));
        _ = @TypeOf(Vapor.Box().inlineStyle("grid-area: {s};", .{"main"}));
        _ = @TypeOf(Vapor.Box().classFmt("col-{d}", .{2}));
        _ = @TypeOf(Vapor.Text("x").font(16, 600, .black));
        _ = @TypeOf(Vapor.Box().src(@src()));
        _ = @TypeOf(Vapor.Box().role(.button));
        _ = @TypeOf(Vapor.Box().background(.palette(.primary)));
        _ = @TypeOf(Vapor.Box().background(.hex("#4400ff")));

        _ = &docEventMethods;
        _ = &docGenericApi;

        // "A minimal app"
        _ = @TypeOf(Vapor.Center().size(.full));
        _ = @TypeOf(Vapor.Text("Hello, world!"));
        _ = Vapor.Page;
        _ = Vapor.init;
        _ = Vapor.Animation.new;
        _ = Vapor.setGlobalStyleVariables;
        _ = Vapor.ThemeDefinition;

        // "Components"
        _ = @TypeOf(Vapor.Box().size(.full).padding(.all(16)));
        _ = @TypeOf(Vapor.Heading(1, "Title"));
        _ = @TypeOf(Vapor.Button(readmeOnClick, .{}));

        // Every component the README lists as available.
        _ = @TypeOf(Vapor.Box());
        _ = @TypeOf(Vapor.Row());
        _ = @TypeOf(Vapor.Stack());
        _ = @TypeOf(Vapor.Center());
        _ = @TypeOf(Vapor.TextFmt("{d}", .{1}));
        _ = @TypeOf(Vapor.Link(.{ .url = "/docs" }));
        _ = @TypeOf(Vapor.Image(.{ .src = "/logo.png", .alt = "Logo" }));
        _ = @TypeOf(Vapor.List());
        _ = @TypeOf(Vapor.Table());
        _ = @TypeOf(Vapor.Form(readmeOnClick, .{}));
        _ = Vapor.Svg;
        _ = Vapor.Icon;
        _ = Vapor.TextField;
        _ = Vapor.TextArea;

        // "Stable identity"
        _ = @TypeOf(Vapor.Row().id("todo-1"));
        _ = @TypeOf(Vapor.Box().src(@src()));

        // "Pages, layouts and hooks"
        _ = Vapor.registerLayout;
        _ = Vapor.registerHook;

        // "Memory" — the four arenas the table documents.
        _ = Vapor.Arena.frame;
        _ = Vapor.Arena.view;
        _ = Vapor.Arena.persist;
        _ = Vapor.frame.fmt;
        _ = Vapor.dupe;

        // "Data fetching"
        _ = Vapor.fetch;
        _ = Vapor.Fetch.Request.handle;
        _ = Vapor.Fetch.Options;

        // "Authentication"
        _ = Vapor.KeyStone.signInWithOauth;
        _ = Vapor.KeyStone.isAuthenticated;
        _ = Vapor.KeyStone.getAccessToken;

        // "Setup" — the theme fixture mirrors what the README tells users to write.
        _ = Vapor.Types.Color.black;
        _ = Vapor.Types.Color.white;
        _ = Vapor.Types.Color.vapor_blue;
    }
}

test "static components are reachable via the generic builder" {
    // The docs point at Vapor.Builder(.static) now that the old Vapor.Static
    // namespace is gone; keep that path compiling.
    comptime {
        _ = @TypeOf(Vapor.Builder(.static).Box);
        _ = @TypeOf(Vapor.Builder(.static).Text("x"));
    }
}

// -----------------------------------------------------------------------------
// Keyed diff: middle insertion / deletion
//
// reconciler.zig carries a TODO saying the different-length keyed paths
// duplicate a button when a form toggles. These drive those paths directly.
// -----------------------------------------------------------------------------

fn addedCount(root: *UINode) usize {
    var n: usize = 0;
    var it = root.children();
    while (it.next()) |c| {
        if (c.state_type == .added) n += 1;
    }
    return n;
}

test "keyed diff: inserting in the middle adds only the new node" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const route_arena = initReconcilerRuntime(arena.allocator());
    defer deinitReconcilerRuntime(arena.allocator(), route_arena);

    const old_root = try makeTree(arena.allocator(), &.{
        .{ .uuid = "a", .index = 0, .finger_print = 1, .props_hash = 1, .text = "A" },
        .{ .uuid = "b", .index = 1, .finger_print = 2, .props_hash = 2, .text = "B" },
    });
    const new_root = try makeTree(arena.allocator(), &.{
        .{ .uuid = "a", .index = 0, .finger_print = 1, .props_hash = 1, .text = "A" },
        .{ .uuid = "x", .index = 1, .finger_print = 3, .props_hash = 3, .text = "X" },
        .{ .uuid = "b", .index = 2, .finger_print = 2, .props_hash = 2, .text = "B" },
    });

    Reconciler.traverseNodes(old_root, new_root);

    // Only "x" is new. "a" and "b" already exist and must not be re-added,
    // or the DOM ends up with two of them.
    try std.testing.expectEqual(@as(usize, 1), addedCount(new_root));
    try std.testing.expectEqual(Vapor.Types.StateType.added, child(new_root, 1).state_type);
    try std.testing.expectEqual(@as(usize, 0), Vapor.Animation.removalCount());
}

test "keyed diff: deleting from the middle removes only that node" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const route_arena = initReconcilerRuntime(arena.allocator());
    defer deinitReconcilerRuntime(arena.allocator(), route_arena);

    const old_root = try makeTree(arena.allocator(), &.{
        .{ .uuid = "a", .index = 0, .finger_print = 1, .props_hash = 1, .text = "A" },
        .{ .uuid = "x", .index = 1, .finger_print = 3, .props_hash = 3, .text = "X" },
        .{ .uuid = "b", .index = 2, .finger_print = 2, .props_hash = 2, .text = "B" },
    });
    const new_root = try makeTree(arena.allocator(), &.{
        .{ .uuid = "a", .index = 0, .finger_print = 1, .props_hash = 1, .text = "A" },
        .{ .uuid = "b", .index = 1, .finger_print = 2, .props_hash = 2, .text = "B" },
    });

    Reconciler.traverseNodes(old_root, new_root);

    try std.testing.expectEqual(@as(usize, 0), addedCount(new_root));
    try std.testing.expectEqual(@as(usize, 1), Vapor.Animation.removalCount());
    try expectRemovalId(0, "x");
}

test "keyed diff cannot recognise a node that moved (identity is positional)" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const route_arena = initReconcilerRuntime(arena.allocator());
    defer deinitReconcilerRuntime(arena.allocator(), route_arena);

    // KeyGenerator.generateKey hashes the child index into the uuid, so the
    // same Button has a different uuid at index 1 and index 2. This mirrors a
    // form toggling an extra field in above the submit button.
    const old_root = try makeTree(arena.allocator(), &.{
        .{ .uuid = "Swit_a-gk", .index = 0, .finger_print = 1, .props_hash = 1 },
        .{ .uuid = "Butt_1-gk", .index = 1, .finger_print = 2, .props_hash = 2 },
    });
    const new_root = try makeTree(arena.allocator(), &.{
        .{ .uuid = "Swit_a-gk", .index = 0, .finger_print = 1, .props_hash = 1 },
        .{ .uuid = "Text_b-gk", .index = 1, .finger_print = 3, .props_hash = 3 },
        .{ .uuid = "Butt_2-gk", .index = 2, .finger_print = 2, .props_hash = 2 },
    });

    Reconciler.traverseNodes(old_root, new_root);

    // The button did not change, it only moved down one slot. Ideally only the
    // inserted field would be added. Instead the old button is queued for
    // removal and a second one is added, because the uuid it is matched on
    // encodes its position.
    try std.testing.expectEqual(@as(usize, 2), addedCount(new_root));
    try std.testing.expectEqual(@as(usize, 1), Vapor.Animation.removalCount());
    try expectRemovalId(0, "Butt_1-gk");
}

// -----------------------------------------------------------------------------
// Style compiler
//
// style_compiler.zig fills fixed static buffers via Writer. Now that
// Writer refuses out-of-space writes rather than running off the end, the
// behaviour under pressure is truncation — these pin both the normal output and
// that boundary.
// -----------------------------------------------------------------------------

const StyleCompiler = Vapor.Testing.StyleCompiler;

test "style compiler emits padding and margin declarations" {
    var buf: [256]u8 = undefined;
    var writer: Vapor.Writer = undefined;
    writer.init(&buf);

    const mp = Vapor.Types.PackedMarginsPaddings{ .padding = .all(12) };
    StyleCompiler.generateMarginsPadding(&mp, &writer);

    try std.testing.expectEqualStrings(
        "padding:12px 12px 12px 12px;\nmargin:0px 0px 0px 0px;\n",
        writer.getAll(),
    );
    try std.testing.expect(!writer.overflowed);
}

// min_max_vp and elastic_percent widths wrote min-width from the max value.
test "style compiler keeps min and max apart for vp and elastic widths" {
    var buf: [1024]u8 = undefined;
    var writer: Vapor.Writer = undefined;

    writer.init(&buf);
    const vp = Vapor.Types.PackedLayout{ .size = .{ .width = .minMaxVp(10, 90) } };
    StyleCompiler.generateLayout(&vp, &writer);
    try std.testing.expect(std.mem.indexOf(u8, writer.getAll(), "min-width:10.00vw;") != null);
    try std.testing.expect(std.mem.indexOf(u8, writer.getAll(), "max-width:90.00vw;") != null);

    writer.init(&buf);
    const elastic = Vapor.Types.PackedLayout{ .size = .{ .width = .{ .type = .elastic_percent, .size = .{ .min = 20, .max = 80 } } } };
    StyleCompiler.generateLayout(&elastic, &writer);
    try std.testing.expect(std.mem.indexOf(u8, writer.getAll(), "min-width:20.00%;") != null);
    try std.testing.expect(std.mem.indexOf(u8, writer.getAll(), "max-width:80.00%;") != null);
}

test "style compiler truncates instead of running past its buffer" {
    // The overflow is reported once, as an error.
    Vapor.lib.expected_reports = 1;
    defer std.testing.expectEqual(@as(u32, 0), Vapor.lib.expected_reports) catch @panic("expected error not reported");
    // A generous tail the writer is not allowed to touch. Before Writer was
    // bounds-checked, an oversized style walked straight into it.
    var backing = [_]u8{0xAA} ** 128;
    const capacity = 16;

    var writer: Vapor.Writer = undefined;
    writer.init(backing[0..capacity]);

    const mp = Vapor.Types.PackedMarginsPaddings{ .padding = .all(12) };
    StyleCompiler.generateMarginsPadding(&mp, &writer);

    // Far more CSS than 16 bytes, so it must have given up partway.
    try std.testing.expect(writer.overflowed);
    try std.testing.expect(writer.pos <= capacity - 1);

    // Whatever it did write stays inside the buffer, and the caller can still
    // NUL-terminate at `pos`.
    backing[writer.pos] = 0;
    for (backing[capacity..]) |byte| {
        try std.testing.expectEqual(@as(u8, 0xAA), byte);
    }
}

test "style compiler keeps truncating safely once full" {
    // The overflow is reported once, as an error.
    Vapor.lib.expected_reports = 1;
    defer std.testing.expectEqual(@as(u32, 0), Vapor.lib.expected_reports) catch @panic("expected error not reported");
    var backing = [_]u8{0xAA} ** 96;
    const capacity = 8;
    var writer: Vapor.Writer = undefined;
    writer.init(backing[0..capacity]);

    // Repeatedly generating into an already-full writer must stay in bounds.
    const mp = Vapor.Types.PackedMarginsPaddings{ .padding = .all(255) };
    var i: usize = 0;
    while (i < 50) : (i += 1) {
        StyleCompiler.generateMarginsPadding(&mp, &writer);
    }

    try std.testing.expect(writer.pos <= capacity - 1);
    for (backing[capacity..]) |byte| {
        try std.testing.expectEqual(@as(u8, 0xAA), byte);
    }
}

test "a caller-set id survives a move, so the diff sees no churn" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const route_arena = initReconcilerRuntime(arena.allocator());
    defer deinitReconcilerRuntime(arena.allocator(), route_arena);

    // Same shape as the failing move test, except the button carries a
    // caller-set id. `.id()` writes node.uuid directly and refunds the unkeyed
    // slot, so the uuid no longer encodes position.
    const old_root = try makeTree(arena.allocator(), &.{
        .{ .uuid = "Swit_a-gk", .index = 0, .finger_print = 1, .props_hash = 1 },
        .{ .uuid = "submit-btn", .index = 1, .finger_print = 2, .props_hash = 2 },
    });
    const new_root = try makeTree(arena.allocator(), &.{
        .{ .uuid = "Swit_a-gk", .index = 0, .finger_print = 1, .props_hash = 1 },
        .{ .uuid = "Text_b-gk", .index = 1, .finger_print = 3, .props_hash = 3 },
        .{ .uuid = "submit-btn", .index = 2, .finger_print = 2, .props_hash = 2 },
    });

    Reconciler.traverseNodes(old_root, new_root);

    // Only the inserted field is new; the button is matched through the
    // suffix scan and never removed.
    try std.testing.expectEqual(@as(usize, 1), addedCount(new_root));
    try std.testing.expectEqual(@as(usize, 0), Vapor.Animation.removalCount());
}

// -----------------------------------------------------------------------------
// Unkeyed slot accounting
//
// setUUID gives every auto-named child an "unkeyed" slot number, and .id()/.src()
// hand that slot back so overriding one child's uuid does not renumber the rest.
// The refund must happen exactly once however many times the uuid is overridden.
// -----------------------------------------------------------------------------

test "overriding a uuid refunds its unkeyed slot exactly once" {
    var parent = UINode{ .uuid = "parent" };
    var node = UINode{ .uuid = "Butt_generated-gk", .parent = &parent };
    parent.unkeyed_child_count = 3;

    const builder = Vapor.Builder(.pure){ ._elem_type = .Button, ._ui_node = &node };

    _ = builder.id("submit");
    try std.testing.expectEqual(@as(usize, 2), parent.unkeyed_child_count);
    try std.testing.expectEqualStrings("submit", node.uuid);
    try std.testing.expect(node.uuid_is_user_set);

    // A second override — `.src(...).id(...)`, or just calling .id() twice —
    // must not take another slot off the parent.
    _ = builder.id("submit-again");
    try std.testing.expectEqual(@as(usize, 2), parent.unkeyed_child_count);
    try std.testing.expectEqualStrings("submit-again", node.uuid);
}

test "refunding never underflows the sibling count" {
    var parent = UINode{ .uuid = "parent" };
    var node = UINode{ .uuid = "Butt_generated-gk", .parent = &parent };
    parent.unkeyed_child_count = 0; // nothing was ever taken

    const builder = Vapor.Builder(.pure){ ._elem_type = .Button, ._ui_node = &node };
    _ = builder.id("only-child");

    // usize: a decrement here used to wrap to a huge number in release builds.
    try std.testing.expectEqual(@as(usize, 0), parent.unkeyed_child_count);
}

test "a node whose uuid was never generated takes no refund" {
    var parent = UINode{ .uuid = "parent" };
    var node = UINode{ .parent = &parent }; // setUUID has not run: uuid is ""
    parent.unkeyed_child_count = 2;

    const builder = Vapor.Builder(.pure){ ._elem_type = .Button, ._ui_node = &node };
    _ = builder.id("early");

    try std.testing.expectEqual(@as(usize, 2), parent.unkeyed_child_count);
    try std.testing.expectEqualStrings("early", node.uuid);
}

test "TextField.id keys the node the same way the element builders do" {
    var parent = UINode{ .uuid = "parent" };
    var node = UINode{ .uuid = "Text_generated-gk", .parent = &parent };
    parent.unkeyed_child_count = 3;

    const field = Vapor.TextFieldBuilder(.pure){ ._elem_type = .TextField, ._ui_node = &node };

    _ = field.id("email-field");
    try std.testing.expectEqual(@as(usize, 2), parent.unkeyed_child_count);
    try std.testing.expectEqualStrings("email-field", node.uuid);
    try std.testing.expect(node.uuid_is_user_set);

    // Once-only, exactly as on ComponentBuilder.
    _ = field.id("email-field-2");
    try std.testing.expectEqual(@as(usize, 2), parent.unkeyed_child_count);
}

test "both builders refund identically, so keying is consistent across them" {
    var parent_a = UINode{ .uuid = "pa" };
    var node_a = UINode{ .uuid = "Butt_gen-gk", .parent = &parent_a };
    parent_a.unkeyed_child_count = 4;
    _ = (Vapor.Builder(.pure){ ._elem_type = .Button, ._ui_node = &node_a }).id("x");

    var parent_b = UINode{ .uuid = "pb" };
    var node_b = UINode{ .uuid = "Text_gen-gk", .parent = &parent_b };
    parent_b.unkeyed_child_count = 4;
    _ = (Vapor.TextFieldBuilder(.pure){ ._elem_type = .TextField, ._ui_node = &node_b }).id("x");

    try std.testing.expectEqual(parent_a.unkeyed_child_count, parent_b.unkeyed_child_count);
    try std.testing.expectEqualStrings(node_a.uuid, node_b.uuid);
}

test "Padding, Margin and BorderThickness build the same way" {
    const T = Vapor.Types;
    try std.testing.expectEqual(T.Padding{ .top = 8, .bottom = 8, .left = 16, .right = 16 }, T.Padding.xy(16, 8));
    try std.testing.expectEqual(T.Margin{ .top = -2, .bottom = -2 }, T.Margin.vertical(-2));
    try std.testing.expectEqual(T.BorderThickness{ .left = 1, .right = 1 }, T.BorderThickness.horizontal(1));

    const border: T.Border = .bottom(2, .white);
    try std.testing.expectEqual(T.BorderThickness{ .bottom = 2 }, border.thickness);
    try std.testing.expectEqual(T.BorderThickness{ .top = 1, .bottom = 1 }, T.Border.vertical(1, .white).thickness);
    try std.testing.expectEqual(T.BorderRadius{ .top_left = 4, .bottom_left = 4 }, T.BorderRadius.left(4));
}

fn visualCss(visual: Vapor.Types.Visual, buf: []u8) ![]const u8 {
    var packed_visual: Vapor.Types.PackedVisual = .{};
    Vapor.Testing.ConfigureVisual.checkVisual(&visual, &packed_visual);
    var writer: Vapor.Writer = undefined;
    writer.init(buf);
    StyleCompiler.generateVisual(&packed_visual, &writer);
    return writer.getAll();
}

// Visual had border_radius/border_thickness/border_color fields beside
// `border` that never reached the CSS, and a `border` always wrote a width
// (zero by default), so a hover could not change only the colour.
test "each part of a border is written only when given" {
    var buf: [1024]u8 = undefined;

    const rounded = try visualCss(.{ .border = .{ .radius = .all(8) } }, &buf);
    try std.testing.expect(std.mem.indexOf(u8, rounded, "border-radius") != null);
    try std.testing.expect(std.mem.indexOf(u8, rounded, "border-width") == null);
    try std.testing.expect(std.mem.indexOf(u8, rounded, "border-style") == null);

    const recolour = try visualCss(.{ .border = .{ .color = .white } }, &buf);
    try std.testing.expect(std.mem.indexOf(u8, recolour, "border-color") != null);
    try std.testing.expect(std.mem.indexOf(u8, recolour, "border-width") == null);

    const thin = try visualCss(.{ .border = .thin(.white) }, &buf);
    try std.testing.expect(std.mem.indexOf(u8, thin, "border-width:1px") != null);
    try std.testing.expect(std.mem.indexOf(u8, thin, "border-style: solid") != null);

    const dashed = try visualCss(.{ .border = .{ .thickness = .all(2), .style = .dashed } }, &buf);
    try std.testing.expect(std.mem.indexOf(u8, dashed, "border-style: dashed") != null);
}

fn SpacingPage() void {
    Vapor.Box().id("spaced").padding(.all(8)).padX(16).pt(2).margin(.{ .top = 4 }).mx(-3).children({});
    Vapor.TextField(.string).id("spaced-field").padY(6).pl(1).mb(9).mx(2).end();
}

// The one-side shorthands change only their sides, on top of `.padding`.
test "padding and margin shorthands keep the sides they do not set" {
    Vapor.init(.{});
    Vapor.Animation.new();
    Vapor.lib.resetRerender();
    Vapor.Animation.removal_queue.clearRetainingCapacity();
    Vapor.Page(.{ .route = "/spacing" }, SpacingPage, null);
    const root = try renderRoute("/root/spacing");
    const T = Vapor.Types;

    const box = Vapor.lib.getUINodeChild(root, 0) orelse return error.MissingBox;
    const box_mp = box.packed_field_ptrs.?.margins_paddings_ptr.?;
    try std.testing.expectEqual(T.Padding{ .top = 2, .bottom = 8, .left = 16, .right = 16 }, box_mp.padding);
    try std.testing.expectEqual(T.Margin{ .top = 4, .left = -3, .right = -3 }, box_mp.margin);

    const field = Vapor.lib.getUINodeChild(root, 1) orelse return error.MissingField;
    const field_mp = field.packed_field_ptrs.?.margins_paddings_ptr.?;
    try std.testing.expectEqual(T.Padding{ .top = 6, .bottom = 6, .left = 1 }, field_mp.padding);
    try std.testing.expectEqual(T.Margin{ .bottom = 9, .left = 2, .right = 2 }, field_mp.margin);
}

var cache_width: f32 = 100;
fn CachePage() void {
    Vapor.Box().id("cached").width(.px(cache_width)).height(.px(10)).children({});
}

// The packed style data and class strings behind a class used to live for
// the life of the app; the class sweep now frees them, and an element that
// uses the style again gets fresh copies.
test "style data unused past the grace period is freed and rebuilt on use" {
    Vapor.init(.{});
    Vapor.Animation.new();
    Vapor.lib.resetRerender();
    Vapor.Animation.removal_queue.clearRetainingCapacity();
    Vapor.Page(.{ .route = "/cache" }, CachePage, null);
    const Packer = Vapor.Testing.Packer;
    const cache = &Vapor.lib.class_cache;

    cache_width = 100;
    var root = try renderRoute("/root/cache");
    const first_layout = (Vapor.lib.getUINodeChild(root, 0) orelse return error.MissingBox).style_hashes[1];
    cache_width = 101;
    root = try renderRoute("/root/cache");
    const second_layout = (Vapor.lib.getUINodeChild(root, 0) orelse return error.MissingBox).style_hashes[1];
    try std.testing.expect(first_layout != second_layout);
    try std.testing.expect(Packer.layouts.contains(first_layout));

    // Native renders do not advance the clock; move it past the grace period
    // with no element marking anything, then sweep.
    cache.beginRender(cache.now_ms + 10_000);
    cache.last_sweep_ms = -10_000;
    try cache.sweep();
    cache.flushTombstones();
    try std.testing.expect(!Packer.layouts.contains(first_layout));
    try std.testing.expect(!Packer.layouts.contains(second_layout));

    root = try renderRoute("/root/cache");
    const box = Vapor.lib.getUINodeChild(root, 0) orelse return error.MissingBox;
    try std.testing.expect(Packer.layouts.contains(second_layout));
    try std.testing.expectEqual(Packer.layouts.get(second_layout).?, box.packed_field_ptrs.?.layout_ptr.?);
    try std.testing.expect(std.mem.indexOf(u8, box.class.?, "lay_") != null);
}

var list_len: usize = 0;
var list_refs: [40]Vapor.Element = undefined;
fn ListPage() void {
    Vapor.Stack().id("list").children({
        for (0..list_len) |i| {
            var buf: [16]u8 = undefined;
            const id = std.fmt.bufPrint(&buf, "row-{d}", .{i}) catch unreachable;
            Vapor.Box().id(Vapor.fmtln("{s}", .{id})).ariaLabel("row").ref(&list_refs[i]).children({
                Vapor.Text("item").id(Vapor.fmtln("{s}-text", .{id})).end();
            });
        }
    });
}

// The per-element tables (ARIA attributes, persisted text, `.ref()` handles)
// kept an entry for every element id ever rendered, so a list that changed
// its rows grew them forever.
test "per-element tables drop elements that left the page" {
    Vapor.init(.{});
    Vapor.Animation.new();
    Vapor.lib.resetRerender();
    Vapor.Animation.removal_queue.clearRetainingCapacity();
    Vapor.Page(.{ .route = "/list" }, ListPage, null);
    const a11y = &Vapor.Testing.Accessibility.a11y_map;
    const texts = &Vapor.Testing.Components.text_string_table;
    const refs = &Vapor.lib.element_registry;

    list_len = 40;
    _ = try renderRoute("/root/list");
    const a11y_full = a11y.count();
    const texts_full = texts.count();
    const refs_full = refs.count();
    try std.testing.expect(a11y_full >= 40 and texts_full >= 40 and refs_full >= 40);

    // The previous render's elements are kept for one more render.
    list_len = 2;
    _ = try renderRoute("/root/list");
    try std.testing.expectEqual(a11y_full, a11y.count());
    _ = try renderRoute("/root/list");
    try std.testing.expectEqual(a11y_full - 38, a11y.count());
    try std.testing.expectEqual(texts_full - 38, texts.count());
    try std.testing.expectEqual(refs_full - 38, refs.count());

    // Elements still on the page keep their entries across many renders.
    for (0..5) |_| _ = try renderRoute("/root/list");
    try std.testing.expectEqual(a11y_full - 38, a11y.count());
    try std.testing.expectEqual(texts_full - 38, texts.count());
    try std.testing.expectEqual(refs_full - 38, refs.count());
    try std.testing.expect(refs.get(Vapor.lib.hashKey("row-1")) != null);
}
