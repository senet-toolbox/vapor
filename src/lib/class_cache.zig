//! Garbage collection for generated CSS classes. Every render marks the
//! classes its elements use; a class no render has used for `grace_ms` is
//! queued as a tombstone, and the runtime deletes its rules from the
//! stylesheet. The grace period keeps the rules of elements that are still
//! playing an exit animation after leaving the tree.

const std = @import("std");
const Vapor = @import("vapor.zig");
const Wasm = Vapor.Wasm;
const utils = @import("utils.zig");

pub const ClassType = enum {
    layout,
    position,
    margin_padding,
    visual,
    interactive,
    animation,
    defined,
    transform,
    responsive,
    target_visual,
};

pub const ClassCache = struct {
    const Self = @This();

    // The Hash is the key into the map it represent the class name
    const Hash = u32;

    /// How long a class must go unused before its rules are removed.
    pub const grace_ms: f64 = 3000;
    /// Sweeps are at least this far apart, so a burst of renders does not
    /// walk the table each time.
    pub const sweep_interval_ms: f64 = 1000;

    const Class = struct {
        type: ClassType,
        /// The render that last used the class.
        last_render: u32,
        /// When that render started.
        last_seen_ms: f64,
    };

    allocator: std.mem.Allocator,
    /// Generated classes used by a recent render.
    map: std.AutoHashMap(Hash, Class),
    /// Hashes of user-named classes (`.style_id`, hover targets) whose rule
    /// has been written. These are never removed.
    defined: std.AutoHashMap(Hash, void),
    /// Names of classes queued for removal, owned by `allocator`.
    tombstones: std.array_list.Managed([]const u8),
    render: u32 = 0,
    now_ms: f64 = 0,
    last_sweep_ms: f64 = 0,

    /// An empty cache.
    pub fn init(class_cache: *Self, allocator: std.mem.Allocator) !void {
        class_cache.* = .{
            .allocator = allocator,
            .map = std.AutoHashMap(Hash, Class).init(allocator),
            .defined = std.AutoHashMap(Hash, void).init(allocator),
            .tombstones = std.array_list.Managed([]const u8).init(allocator),
        };
    }

    /// Frees the cache.
    pub fn deinit(self: *Self) void {
        self.flushTombstones();
        self.map.deinit();
        self.defined.deinit();
        self.tombstones.deinit();
    }

    /// The class-name prefix for a style group, e.g. "lay" for layout.
    pub fn getClassNameByType(class_type: ClassType) []const u8 {
        return switch (class_type) {
            .layout => "lay",
            .position => "pos",
            .margin_padding => "mapa",
            .visual => "vis",
            .interactive => "intr",
            .animation => "anim",
            .defined => "def",
            .transform => "tran",
            .responsive => "resp",
            .target_visual => "t_vis",
        };
    }

    /// Starts a render at time `now_ms`; classes marked from here on count as
    /// used by it.
    pub fn beginRender(self: *Self, now_ms: f64) void {
        self.render +%= 1;
        self.now_ms = now_ms;
    }

    /// Records that the current render uses the generated class `hash`.
    pub fn markUsed(self: *Self, hash: Hash, class_type: ClassType) !void {
        try self.map.put(hash, .{
            .type = class_type,
            .last_render = self.render,
            .last_seen_ms = self.now_ms,
        });
    }

    /// Whether the generated class `hash` is tracked.
    pub fn contains(self: *Self, hash: Hash) bool {
        return self.map.contains(hash);
    }

    /// Records the user-named class `hash`. Returns true the first time, when
    /// its rule still has to be written.
    pub fn defineOnce(self: *Self, hash: Hash) bool {
        const entry = self.defined.getOrPut(hash) catch return true;
        return !entry.found_existing;
    }

    /// Queues every class unused for `grace_ms` as a tombstone and forgets it.
    /// Runs at most once per `sweep_interval_ms`.
    pub fn sweep(self: *Self) !void {
        if (self.now_ms - self.last_sweep_ms < sweep_interval_ms) return;
        self.last_sweep_ms = self.now_ms;

        var stale: std.array_list.Managed(Hash) = .init(self.allocator);
        defer stale.deinit();
        var it = self.map.iterator();
        while (it.next()) |entry| {
            const class = entry.value_ptr;
            if (class.last_render == self.render) continue;
            if (self.now_ms - class.last_seen_ms < grace_ms) continue;
            try stale.append(entry.key_ptr.*);
        }
        for (stale.items) |hash| {
            const class = self.map.get(hash).?;
            var buf: [6]u8 = undefined;
            const name = try std.fmt.allocPrint(self.allocator, "{s}_{s}", .{
                getClassNameByType(class.type),
                utils.hashToBase62(hash, &buf),
            });
            errdefer self.allocator.free(name);
            try self.tombstones.append(name);
            _ = self.map.remove(hash);
        }
    }

    /// Sweeps, then asks the runtime to delete the rules of the tombstones.
    pub fn batchRemove(self: *Self) void {
        self.sweep() catch |err| {
            Vapor.printlnErr("class cache: sweep failed, unused rules kept: {any}", .{err});
        };
        if (self.tombstones.items.len == 0) return;
        if (Vapor.isWasi) {
            Wasm.batchRemoveTombStonesWasm();
        }
    }

    /// Classes queued for removal.
    pub fn getTombstones(self: *Self) []const []const u8 {
        return self.tombstones.items;
    }

    /// Clears the tombstones, after the runtime removed their rules.
    pub fn flushTombstones(self: *Self) void {
        for (self.tombstones.items) |name| self.allocator.free(name);
        self.tombstones.clearRetainingCapacity();
    }

    /// The class name of the `index`-th tombstone, for the runtime.
    pub fn getTombstoneName(self: *Self, index: usize) ?[]const u8 {
        if (index >= self.tombstones.items.len) return null;
        return self.tombstones.items[index];
    }
};

export fn getTombstoneCount() usize {
    return Vapor.class_cache.tombstones.items.len;
}

export fn getTombstoneClassNamePtr(index: usize) ?[*]const u8 {
    const name = Vapor.class_cache.getTombstoneName(index) orelse return null;
    return name.ptr;
}

export fn getTombstoneClassNameLength(index: usize) usize {
    const name = Vapor.class_cache.getTombstoneName(index) orelse return 0;
    return name.len;
}

export fn clearTombstones() void {
    Vapor.class_cache.flushTombstones();
}

test "a class unused for the grace period becomes a tombstone" {
    var cache: ClassCache = undefined;
    try cache.init(std.testing.allocator);
    defer cache.deinit();

    // Render 1 at t=0 uses both classes.
    cache.beginRender(0);
    try cache.markUsed(1, .layout);
    try cache.markUsed(2, .visual);
    try cache.sweep();

    // Render 2 at t=1000 uses only class 1: class 2 is within its grace.
    cache.beginRender(1000);
    try cache.markUsed(1, .layout);
    try cache.sweep();
    try std.testing.expectEqual(@as(usize, 0), cache.getTombstones().len);

    // Render 3 at t=4000: class 2 has been unused for 4s.
    cache.beginRender(4000);
    try cache.markUsed(1, .layout);
    try cache.sweep();
    try std.testing.expectEqual(@as(usize, 1), cache.getTombstones().len);
    var buf: [6]u8 = undefined;
    const expected = try std.fmt.allocPrint(std.testing.allocator, "vis_{s}", .{utils.hashToBase62(2, &buf)});
    defer std.testing.allocator.free(expected);
    try std.testing.expectEqualStrings(expected, cache.getTombstones()[0]);
    try std.testing.expect(cache.contains(1));
    try std.testing.expect(!cache.contains(2));

    // A class used again after removal is tracked again.
    cache.flushTombstones();
    cache.beginRender(9000);
    try cache.markUsed(2, .visual);
    try cache.sweep();
    try std.testing.expect(cache.contains(2));
    try std.testing.expectEqual(@as(usize, 1), cache.getTombstones().len); // class 1
}

test "a class the current render uses is never removed" {
    var cache: ClassCache = undefined;
    try cache.init(std.testing.allocator);
    defer cache.deinit();

    cache.beginRender(0);
    try cache.markUsed(7, .layout);
    // Same render, much later (a long render): still in use.
    cache.now_ms = 60_000;
    try cache.sweep();
    try std.testing.expectEqual(@as(usize, 0), cache.getTombstones().len);
}

test "defineOnce is true only the first time" {
    var cache: ClassCache = undefined;
    try cache.init(std.testing.allocator);
    defer cache.deinit();
    try std.testing.expect(cache.defineOnce(5));
    try std.testing.expect(!cache.defineOnce(5));
}
