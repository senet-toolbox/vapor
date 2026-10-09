const Animation = @import("../Animation.zig");
const std = @import("std");
const Vapor = @import("../Vapor.zig");
const Allocator = std.mem.Allocator;
const StyleCompiler = @import("../convertStyleCustomWriter.zig");
const getExitAnimationStyle = StyleCompiler.getExitAnimationStyle;
const UINode = @import("../UITree.zig").UINode;

const AnimationId = u16; // supports 65k unique animations, plenty

const AnimationIntern = struct {
    allocator: Allocator,
    strings: std.array_list.Managed([]const u8),
    lookup: std.StringHashMap(AnimationId),
    ref_counts: std.array_list.Managed(u32),

    pub fn init(allocator: Allocator) AnimationIntern {
        return .{
            .allocator = allocator,
            .strings = std.array_list.Managed([]const u8).init(allocator),
            .lookup = std.StringHashMap(AnimationId).init(allocator),
            .ref_counts = std.array_list.Managed(u32).init(allocator),
        };
    }

    pub fn intern(self: *AnimationIntern, css: []const u8) !AnimationId {
        if (self.lookup.get(css)) |id| {
            self.ref_counts.items[id] += 1;
            return id;
        }

        const owned = try self.allocator.dupe(u8, css);
        const id: AnimationId = @intCast(self.strings.items.len);
        try self.strings.append(owned);
        try self.ref_counts.append(1);
        try self.lookup.put(owned, id);
        return id;
    }

    pub fn get(self: *AnimationIntern, id: AnimationId) ?[]const u8 {
        if (id >= self.strings.items.len) return null;
        return self.strings.items[id];
    }

    pub fn release(self: *AnimationIntern, id: AnimationId) void {
        if (id >= self.ref_counts.items.len) return;
        if (self.ref_counts.items[id] == 0) return;
        self.ref_counts.items[id] -= 1;
        // Optional: cleanup when ref_count hits 0
        // or batch cleanup periodically
    }
};

const PendingRemoval = struct {
    uuid: []const u8,
    node_index: u16,
    animation_id: AnimationId, // 2 bytes instead of duplicated string
    generation: u32, // for staleness detection
};

pub const RemovalQueue = struct {
    allocator: Allocator,
    items: std.array_list.Managed(PendingRemoval),
    animations: AnimationIntern,
    current_generation: u32 = 0,

    pub fn init(allocator: Allocator) void {
        Animation.removal_queue = .{
            .allocator = allocator,
            .items = std.array_list.Managed(PendingRemoval).init(allocator),
            .animations = AnimationIntern.init(allocator),
            .current_generation = 0,
        };
    }

    pub fn enqueue(
        self: *RemovalQueue,
        node: *UINode,
        node_index: usize,
    ) !void {
        const has_exit_animation = node.animation_exit != null;

        const anim_id: AnimationId = if (has_exit_animation) blk: {
            const css_ptr = getExitAnimationStyle(node) orelse {
                Vapor.printErr("Exit Animation not found could not ENQUE, Please make sure to Run .build() on the animation", .{});
                break :blk std.math.maxInt(AnimationId);
            };
            const len = StyleCompiler.getAnimationLen();
            break :blk try self.animations.intern(css_ptr[0..len]);
        } else std.math.maxInt(AnimationId); // sentinel for "no animation"

        try self.items.append(.{
            .uuid = node.uuid,
            .node_index = @intCast(node_index),
            .animation_id = anim_id,
            .generation = self.current_generation,
        });
    }

    pub fn getAnimationCss(self: *RemovalQueue, handle: u32) ?[]const u8 {
        if (handle >= self.items.items.len) return null;
        const item = self.items.items[handle];
        if (item.animation_id == std.math.maxInt(AnimationId)) return null;
        return self.animations.get(item.animation_id);
    }

    pub fn getId(self: *RemovalQueue, handle: u32) ?[]const u8 {
        if (handle >= self.items.items.len) return null;
        const item = self.items.items[handle];
        return item.uuid;
    }

    pub fn release(self: *RemovalQueue, handle: u32) void {
        if (handle >= self.items.items.len) return;
        const item = self.items.items[handle];

        // `uuid` is borrowed from the UINode, not owned by this queue, so there
        // is nothing to free here.

        // Decrement animation ref count
        if (item.animation_id != std.math.maxInt(AnimationId)) {
            self.animations.release(item.animation_id);
        }

        // Mark slot as free (or swap-remove if order doesn't matter)
        self.items.items[handle].uuid = ""; // tombstone
    }

    pub fn nextGeneration(self: *RemovalQueue) void {
        self.current_generation += 1;
    }

    pub fn clearRetainingCapacity(self: *RemovalQueue) void {
        self.items.clearRetainingCapacity();
        self.animations.strings.clearRetainingCapacity();
        self.animations.lookup.clearRetainingCapacity();
        self.animations.ref_counts.clearRetainingCapacity();
        self.current_generation = 0;
    }
};

export fn clearRemovalQueueRetainingCapacity() void {
    Animation.removal_queue.clearRetainingCapacity();
}

pub export fn removalCount() usize {
    return Animation.removal_queue.items.items.len;
}

pub export fn getRemovalAnimationPtr(handle: u32) ?[*]const u8 {
    const css = Animation.removal_queue.getAnimationCss(handle) orelse return null;
    return css.ptr;
}

pub export fn getRemovalAnimationLen(handle: u32) usize {
    const css = Animation.removal_queue.getAnimationCss(handle) orelse return 0;
    return css.len;
}

pub export fn getRemovalIdPtr(handle: u32) ?[*]const u8 {
    const id = Animation.removal_queue.getId(handle) orelse return null;
    return id.ptr;
}

pub export fn getRemovalIdLen(handle: u32) usize {
    const id = Animation.removal_queue.getId(handle) orelse return 0;
    return id.len;
}
