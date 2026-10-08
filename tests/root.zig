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
        // Deprecated spelling, kept for existing apps.
        _ = Vapor.Fetch.Fetch;
        _ = Vapor.Kit.HttpReq;
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

test "README examples type-check against the real API" {
    comptime {
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
        _ = Vapor.Arena.request;
        _ = Vapor.Arena.persist;
        _ = Vapor.frame.fmt;
        _ = Vapor.dupe;

        // "Data fetching"
        _ = Vapor.fetch;
        _ = Vapor.Fetch.Request.handle;
        _ = Vapor.Fetch.Options;

        // "Authentication"
        _ = Vapor.KeyStone.signIn;
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
        _ = @TypeOf(Vapor.BuilderClose(.static).Text("x"));
    }
}

// -----------------------------------------------------------------------------
// Keyed diff: middle insertion / deletion
//
// Reconciler.zig carries a TODO saying the different-length keyed paths
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
// convertStyleCustomWriter fills fixed static buffers via Writer. Now that
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

test "style compiler truncates instead of running past its buffer" {
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
