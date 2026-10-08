//! Route table: maps a URL path to the page registered for it.
//!
//! A trie over path segments. Each node has static children keyed by segment
//! text and at most one dynamic child (`:name`). Matching tries static
//! children first and falls back to the dynamic one, backtracking if a static
//! branch dead-ends, so `/users/new` beats `/users/:id`, and `/users/:id/edit`
//! can sit beside `/users/:id`. Matched dynamic values are returned as params.
//!
//! Paths are registered and looked up with vapor's `/root` prefix.

const std = @import("std");
const UITree = @import("UITree.zig");
const RouteFrameArena = @import("FrameAllocator.zig").RouteFrameArena;

const Radix = @This();

allocator: std.mem.Allocator,
root: *Node,
// The last match's pattern and params live here, so a lookup allocates
// nothing; Route slices into them stay valid until the next searchRoute.
pattern_buf: [512]u8 = undefined,
params_buf: [max_params]Param = undefined,

const max_params = 16;

pub const Node = struct {
    children: std.StringHashMap(*Node),
    param_child: ?*Node = null,
    /// A dynamic segment (`:name`); `param_name` is the part after ':'.
    is_param: bool = false,
    param_name: []const u8 = "",
    is_end: bool = false,
    tree: ?*UITree = null,
    page: *const fn () void = undefined,
    route_arena: *RouteFrameArena = undefined,
};

pub const Param = struct {
    name: []const u8,
    value: []const u8,
};

pub const Route = struct {
    ui_tree: *UITree,
    page: *const fn () void,
    is_dynamic: bool,
    /// The registered pattern, e.g. `/root/users/:id`. updateRouteTree takes it.
    path: []const u8,
    route_arena: *RouteFrameArena,
    /// Values of the pattern's dynamic segments, in the frame arena.
    params: []const Param,
};

/// Segments of a path, stopping at the query string or fragment.
const SegmentIterator = struct {
    rest: []const u8,

    fn init(path: []const u8) SegmentIterator {
        const end = std.mem.indexOfAny(u8, path, "?# \x00") orelse path.len;
        return .{ .rest = path[0..end] };
    }

    fn next(self: *SegmentIterator) ?[]const u8 {
        while (self.rest.len > 0 and self.rest[0] == '/') self.rest = self.rest[1..];
        if (self.rest.len == 0) return null;
        const end = std.mem.indexOfScalar(u8, self.rest, '/') orelse self.rest.len;
        const segment = self.rest[0..end];
        self.rest = self.rest[end..];
        return segment;
    }
};

fn createNode(allocator: std.mem.Allocator) !*Node {
    const node = try allocator.create(Node);
    node.* = .{ .children = std.StringHashMap(*Node).init(allocator) };
    return node;
}

pub fn init(target: *Radix, allocator: std.mem.Allocator) !void {
    target.* = .{ .root = try createNode(allocator), .allocator = allocator };
}

pub fn deinit(radix: *Radix) void {
    radix.destroyNode(radix.root);
}

fn destroyNode(radix: *Radix, node: *Node) void {
    var it = node.children.valueIterator();
    while (it.next()) |child| radix.destroyNode(child.*);
    if (node.param_child) |child| radix.destroyNode(child);
    node.children.deinit();
    radix.allocator.destroy(node);
}

/// Registers `page` for `path`. Registering the same pattern again replaces
/// it. Two dynamic segments with different names at the same position
/// (`/u/:id` and `/u/:name`) are `error.ConflictDynamicRoute`.
pub fn addRoute(
    radix: *Radix,
    path: []const u8,
    tree: *UITree,
    page: *const fn () void,
    route_arena: *RouteFrameArena,
) !void {
    var node = radix.root;
    var segments = SegmentIterator.init(path);
    while (segments.next()) |segment| {
        if (segment[0] == ':') {
            const name = segment[1..];
            if (node.param_child) |child| {
                if (!std.mem.eql(u8, child.param_name, name)) return error.ConflictDynamicRoute;
                node = child;
            } else {
                const child = try createNode(radix.allocator);
                child.is_param = true;
                child.param_name = name;
                node.param_child = child;
                node = child;
            }
        } else {
            const entry = try node.children.getOrPut(segment);
            if (!entry.found_existing) entry.value_ptr.* = try createNode(radix.allocator);
            node = entry.value_ptr.*;
        }
    }
    node.is_end = true;
    node.tree = tree;
    node.page = page;
    node.route_arena = route_arena;
}

const max_segments = 64;

pub fn searchRoute(radix: *Radix, path: []const u8) ?Route {
    var segments_buf: [max_segments][]const u8 = undefined;
    var count: usize = 0;
    var it = SegmentIterator.init(path);
    while (it.next()) |segment| {
        if (count == segments_buf.len) return null;
        segments_buf[count] = segment;
        count += 1;
    }
    const segments = segments_buf[0..count];

    // chosen[i] is the node that matched segments[i].
    var chosen: [max_segments]*Node = undefined;
    const node = match(radix.root, segments, &chosen, 0) orelse return null;

    var pattern = std.Io.Writer.fixed(&radix.pattern_buf);
    var param_count: usize = 0;
    for (segments, chosen[0..segments.len]) |segment, n| {
        if (n.is_param) {
            if (param_count == max_params) return null;
            pattern.print("/:{s}", .{n.param_name}) catch return null;
            radix.params_buf[param_count] = .{ .name = n.param_name, .value = segment };
            param_count += 1;
        } else {
            pattern.print("/{s}", .{segment}) catch return null;
        }
    }

    return Route{
        .ui_tree = node.tree.?,
        .page = node.page,
        .is_dynamic = param_count > 0,
        .path = pattern.buffered(),
        .route_arena = node.route_arena,
        .params = radix.params_buf[0..param_count],
    };
}

/// Finds the end node for `segments`: static children before the dynamic one,
/// backtracking when a branch dead-ends. Records each step in `chosen`.
fn match(node: *Node, segments: []const []const u8, chosen: *[max_segments]*Node, depth: usize) ?*Node {
    if (depth == segments.len) return if (node.is_end) node else null;
    if (node.children.get(segments[depth])) |child| {
        chosen[depth] = child;
        if (match(child, segments, chosen, depth + 1)) |found| return found;
    }
    if (node.param_child) |child| {
        chosen[depth] = child;
        if (match(child, segments, chosen, depth + 1)) |found| return found;
    }
    return null;
}

/// Replaces the UI tree of the route registered as `pattern` (Route.path).
pub fn updateRouteTree(radix: *Radix, pattern: []const u8, new_tree: *UITree) bool {
    var node = radix.root;
    var segments = SegmentIterator.init(pattern);
    while (segments.next()) |segment| {
        node = if (segment[0] == ':')
            node.param_child orelse return false
        else
            node.children.get(segment) orelse return false;
    }
    if (!node.is_end) return false;
    node.tree = new_tree;
    return true;
}

// ── tests ───────────────────────────────────────────────────────────────────

fn testPage() void {}

const TestTable = struct {
    radix: Radix,
    // The router never dereferences these; distinct addresses are enough.
    trees: [8]u64 = undefined,

    fn tree(self: *TestTable, i: usize) *UITree {
        return @ptrCast(@alignCast(&self.trees[i]));
    }

    fn add(self: *TestTable, path: []const u8, i: usize) !void {
        try self.radix.addRoute(path, self.tree(i), testPage, undefined);
    }

    fn find(self: *TestTable, path: []const u8) ?usize {
        const route = self.radix.searchRoute(path) orelse return null;
        for (0..self.trees.len) |i| if (route.ui_tree == self.tree(i)) return i;
        return null;
    }
};

fn testTable() !TestTable {
    var t = TestTable{ .radix = undefined };
    try Radix.init(&t.radix, std.testing.allocator);
    return t;
}

test "static, dynamic and nested dynamic routes" {
    var t = try testTable();
    defer t.radix.deinit();
    try t.add("/root", 0);
    try t.add("/root/users/:id", 1);
    try t.add("/root/users/:id/edit", 2);
    try t.add("/root/users/new", 3);
    try t.add("/root/about", 4);

    try std.testing.expectEqual(@as(?usize, 0), t.find("/root"));
    try std.testing.expectEqual(@as(?usize, 1), t.find("/root/users/42"));
    try std.testing.expectEqual(@as(?usize, 2), t.find("/root/users/42/edit"));
    // Static beats dynamic at the same position.
    try std.testing.expectEqual(@as(?usize, 3), t.find("/root/users/new"));
    try std.testing.expectEqual(@as(?usize, 4), t.find("/root/about/"));
    try std.testing.expectEqual(@as(?usize, 4), t.find("/root/about?tab=1#top"));
    // Not routes: a registered route's prefix, a longer path, a near miss.
    try std.testing.expectEqual(@as(?usize, null), t.find("/root/users"));
    try std.testing.expectEqual(@as(?usize, null), t.find("/root/users/42/edit/more"));
    try std.testing.expectEqual(@as(?usize, null), t.find("/root/abou"));
    try std.testing.expectEqual(@as(?usize, null), t.find("/root/aboutx"));

    const route = t.radix.searchRoute("/root/users/42/edit").?;
    try std.testing.expectEqualStrings("/root/users/:id/edit", route.path);
    try std.testing.expectEqual(@as(usize, 1), route.params.len);
    try std.testing.expectEqualStrings("id", route.params[0].name);
    try std.testing.expectEqualStrings("42", route.params[0].value);
    try std.testing.expect(route.is_dynamic);

    // A static branch that dead-ends falls back to the dynamic one.
    try t.add("/root/files/new/draft", 5);
    try t.add("/root/files/:name", 6);
    try std.testing.expectEqual(@as(?usize, 6), t.find("/root/files/new"));

    try std.testing.expect(t.radix.updateRouteTree("/root/users/:id/edit", t.tree(7)));
    try std.testing.expectEqual(@as(?usize, 7), t.find("/root/users/9/edit"));

    try std.testing.expectError(error.ConflictDynamicRoute, t.add("/root/users/:name", 0));
}
