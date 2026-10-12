//! Tables of per-element data keyed by the element's hash (its ARIA
//! attributes, its persisted text, its `Element` handle). Every render
//! writes the entries of the elements it renders, so an entry no render has
//! written lately belongs to an element that left the page. `prune` drops
//! those after each render; without it the tables grew by one entry per
//! element id ever shown.

const std = @import("std");

/// The current render, bumped by `beginRender`.
pub var render: u32 = 0;

/// Starts a render; entries written from here on count as written by it.
pub fn beginRender() void {
    render +%= 1;
}

/// A table of `V` per element hash whose entries are dropped once no render
/// writes them.
pub fn NodeTable(comptime V: type) type {
    return struct {
        const Self = @This();

        const Entry = struct {
            value: V,
            /// The render that last wrote the entry.
            last_render: u32,
        };

        pub const KV = struct { key: u32, value: V };

        map: std.AutoHashMap(u32, Entry),

        /// An empty table.
        pub fn init(allocator: std.mem.Allocator) Self {
            return .{ .map = std.AutoHashMap(u32, Entry).init(allocator) };
        }

        /// Frees the table, not the values.
        pub fn deinit(self: *Self) void {
            self.map.deinit();
        }

        /// Sets the entry for `key`, written by the current render.
        pub fn put(self: *Self, key: u32, value: V) !void {
            try self.map.put(key, .{ .value = value, .last_render = render });
        }

        /// The entry for `key`.
        pub fn get(self: *const Self, key: u32) ?V {
            const entry = self.map.get(key) orelse return null;
            return entry.value;
        }

        /// Removes the entry for `key` and returns it.
        pub fn fetchRemove(self: *Self, key: u32) ?KV {
            const kv = self.map.fetchRemove(key) orelse return null;
            return .{ .key = kv.key, .value = kv.value.value };
        }

        /// The number of entries.
        pub fn count(self: *const Self) usize {
            return self.map.count();
        }

        /// Drops every entry written by neither this render nor the previous
        /// one, calling `drop` on its value first. The previous render's
        /// entries stay because its tree is still alive until the next one.
        pub fn prune(self: *Self, comptime drop: ?fn (V) void) void {
            var it = self.map.iterator();
            while (it.next()) |entry| {
                if (render -% entry.value_ptr.last_render < 2) continue;
                if (drop) |f| f(entry.value_ptr.value);
                // Removing the current entry keeps the iterator valid.
                self.map.removeByPtr(entry.key_ptr);
            }
        }
    };
}

test "an entry no render writes is pruned after a render's grace" {
    var table = NodeTable(u8).init(std.testing.allocator);
    defer table.deinit();

    beginRender();
    try table.put(1, 10);
    try table.put(2, 20);
    table.prune(null);

    // Render 2 writes only 1; 2 was written by the previous render, so stays.
    beginRender();
    try table.put(1, 11);
    table.prune(null);
    try std.testing.expectEqual(@as(?u8, 20), table.get(2));

    // Render 3 writes only 1: 2 is gone.
    beginRender();
    try table.put(1, 12);
    table.prune(null);
    try std.testing.expectEqual(@as(?u8, null), table.get(2));
    try std.testing.expectEqual(@as(?u8, 12), table.get(1));
    try std.testing.expectEqual(@as(usize, 1), table.count());
}

var dropped_sum: u32 = 0;
fn sumDrop(value: u8) void {
    dropped_sum += value;
}

test "prune hands each dropped value to drop" {
    var table = NodeTable(u8).init(std.testing.allocator);
    defer table.deinit();
    dropped_sum = 0;

    beginRender();
    for (0..50) |i| try table.put(@intCast(i), 1);
    beginRender();
    beginRender();
    table.prune(sumDrop);
    try std.testing.expectEqual(@as(u32, 50), dropped_sum);
    try std.testing.expectEqual(@as(usize, 0), table.count());
}
