//! The arenas behind `Vapor.arena`: a double-buffered frame arena per route,
//! a view arena freed when the app leaves the page on screen, and persistent
//! and request arenas.

const std = @import("std");
const mem = std.mem;
const Allocator = mem.Allocator;
const Arena = std.heap.ArenaAllocator;
const UINode = @import("UITree.zig").UINode;
const Item = @import("UITree.zig").Item;
const Vapor = @import("vapor.zig");

// The FrameAllocator is a simple allocator that allocates memory per render cycle.
// It is used to allocate memory for the render commands and the UI tree, text, and styles, etc.
// It is also used to allocate memory for the persistent arena, which is used to store data that
// should persist across frames.

// For each render cycle, beginFrame() is called to reset the current frame arena and get ready to allocate memory, for
// the next frame. This means we can just deinit a single allocator and there is no need to recurse down the tree.

// This gets attached to each route in your radix tree
pub const RouteFrameArena = struct {
    frames: [NUMBER_OF_FRAMES]FrameData,
    current_frame: usize = 0,

    /// Two frame arenas over `backing_allocator`.
    pub fn init(backing_allocator: Allocator) RouteFrameArena {
        return .{
            .frames = .{
                .{ .arena = Arena.init(backing_allocator) },
                .{ .arena = Arena.init(backing_allocator) },
            },
        };
    }

    /// Frees both frame arenas.
    pub fn deinit(self: *RouteFrameArena) void {
        self.frames[0].arena.deinit();
        self.frames[1].arena.deinit();
    }

    /// The current frame's arena.
    pub fn allocator(self: *RouteFrameArena) Allocator {
        return self.frames[self.current_frame].arena.allocator();
    }

    /// Switches to the other frame arena and resets it, so the previous frame's
    /// memory stays valid for one more render.
    pub fn beginFrame(self: *RouteFrameArena) void {
        const next = (self.current_frame + 1) % 2;
        _ = self.frames[next].arena.reset(.retain_capacity);
        self.frames[next].stats = .{};
        self.current_frame = next;
    }

    /// Allocation statistics for the current frame.
    pub fn getStats(self: *RouteFrameArena) Stats {
        return self.frames[self.current_frame].stats;
    }

    /// Counts a node allocation in the frame statistics.
    pub fn incrementNodeCount(self: *RouteFrameArena) void {
        self.frames[self.current_frame].stats.nodes_memory += @sizeOf(UINode);
        self.frames[self.current_frame].stats.nodes_allocated += 1;
    }
    /// Counts a stack item allocation in the frame statistics.
    pub fn incrementItemCount(self: *RouteFrameArena) void {
        self.frames[self.current_frame].stats.item_memory += @sizeOf(Item);
        self.frames[self.current_frame].stats.items_allocated += 1;
    }

    /// Adds `bytes` to the frame statistics.
    pub fn addBytesUsed(self: *RouteFrameArena, bytes: usize) void {
        self.frames[self.current_frame].stats.bytes_used += bytes;
    }

    /// Bytes allocated in the current frame.
    pub fn queryBytesUsed(self: *RouteFrameArena) usize {
        const current_frame = self.frames[self.current_frame];
        const current_total = current_frame.arena.queryCapacity();
        return current_total;
    }

    /// This is now just a simple, fast create() from the arena
    pub fn nodeAlloc(self: *RouteFrameArena) ?*UINode {
        // This is just a fast pointer bump
        // const node = self.persistentAllocator().create(UINode) catch {
        const node = self.frames[self.current_frame].arena.allocator().create(UINode) catch {
            // This will only fail if you run out of memory (OOM)
            // or the backing allocator fails.
            return null;
        };
        // You could even initialize the node here if needed
        return node;
    }
};

const FrameData = struct {
    arena: Arena,
    stats: Stats = .{},
};

const NUMBER_OF_FRAMES = 2;

pub const Stats = struct {
    nodes_allocated: usize = 0,
    tree_memory: usize = 0,
    command_memory: usize = 0,
    commands_allocated: usize = 0,
    bytes_used: usize = 0,
    nodes_memory: usize = 0,
    item_memory: usize = 0,
    items_allocated: usize = 0,
};

const FrameAllocator = @This();
persistent_arena: Arena,
/// `.view` memory: the page on screen's. Reset by `beginView` when the app
/// leaves that page.
view_arena: Arena,
request_arena: Arena,
scratch_arena: Arena,
// Pointer to current route's frame arena
current_route_arena: ?*RouteFrameArena = null,
backing_allocator: Allocator,

/// The arenas over `backing_allocator`.
pub fn init(backing_allocator: Allocator) FrameAllocator {
    return .{
        .persistent_arena = Arena.init(backing_allocator),
        .view_arena = Arena.init(backing_allocator),
        .request_arena = Arena.init(backing_allocator),
        .scratch_arena = Arena.init(backing_allocator),
        .backing_allocator = backing_allocator,
    };
}

/// Frees the shared arenas; route arenas belong to the router.
pub fn deinit(self: *FrameAllocator) void {
    self.persistent_arena.deinit();
    self.view_arena.deinit();
    self.request_arena.deinit();
    self.scratch_arena.deinit();
    // Note: route arenas are owned by the radix tree, not us
}

// Call this to create a new RouteFrameArena for a route
/// A new arena set for one registered page.
pub fn createRouteArena(self: *FrameAllocator) *RouteFrameArena {
    // Returns *RouteFrameArena, so there is no value to degrade to. @panic at
    // least aborts identically in every optimize mode and says why.
    const route_arena = self.backing_allocator.create(RouteFrameArena) catch |err| {
        Vapor.printlnErr("createRouteArena: allocation failed: {any}", .{err});
        @panic("vapor: out of memory creating a route arena");
    };
    route_arena.* = RouteFrameArena.init(self.backing_allocator);
    return route_arena;
}

// Call this when switching routes
/// Makes `route_arena` the one frame allocations come from.
pub fn setCurrentRoute(self: *FrameAllocator, route_arena: *RouteFrameArena) void {
    self.current_route_arena = route_arena;
}

// Get the current route's frame allocator
/// The current route's frame arena; panics before any page is registered.
pub fn frameAllocator(self: *FrameAllocator) Allocator {
    if (self.current_route_arena) |route| {
        return route.allocator();
    }
    // Vapor.printErr("Cannot access the frame allocator, first create the Route via Page() then proceed with initliazation", .{});
    // return self.persistentAllocator();
    @panic("No route set - call setCurrentRoute first");
}

// Begin frame on the current route
/// Starts a new frame on the current route.
pub fn beginFrame(self: *FrameAllocator) void {
    if (self.current_route_arena) |route| {
        route.beginFrame();
    }
}

/// Frees all `.view` memory. The render loop calls it when the app leaves a
/// page, after that page's deinit has run.
pub fn beginView(self: *FrameAllocator) void {
    _ = self.view_arena.reset(.retain_capacity);
}

/// The backing allocator: `.persist` memory, freed individually.
pub fn persistentAllocator(self: *FrameAllocator) Allocator {
    return self.backing_allocator;
}

/// The request arena; never reset at present.
pub fn requestAllocator(self: *FrameAllocator) Allocator {
    return self.request_arena.allocator();
}

/// Frees the scratch arena.
pub fn resetScratchArena(self: *FrameAllocator) void {
    _ = self.scratch_arena.reset(.free_all);
}

/// The arena `Vapor.arena(.view)` uses.
pub fn viewAllocator(self: *FrameAllocator) Allocator {
    return self.view_arena.allocator();
}

/// Counts a node allocation on the current route.
pub fn incrementNodeCount(self: *FrameAllocator) void {
    if (self.current_route_arena) |route| {
        route.incrementNodeCount();
    }
}

/// Counts a stack item allocation on the current route.
pub fn incrementItemCount(self: *FrameAllocator) void {
    if (self.current_route_arena) |route| {
        route.incrementItemCount();
    }
}

/// Adds `bytes` to the current route's statistics.
pub fn addBytesUsed(self: *FrameAllocator, bytes: usize) void {
    if (self.current_route_arena) |route| {
        route.addBytesUsed(bytes);
    }
}

/// Bytes allocated in the current route's frame.
pub fn queryBytesUsed(self: *FrameAllocator) usize {
    if (self.current_route_arena) |route| {
        return route.queryBytesUsed();
    }
    return 0;
}

/// Nodes allocated in the current route's frame.
pub fn queryNodes(self: *FrameAllocator) usize {
    if (self.current_route_arena) |route| {
        return route.getStats().nodes_allocated;
    }
    return 0;
}

/// This is now just a simple, fast create() from the arena
pub fn nodeAlloc(self: *FrameAllocator) ?*UINode {
    if (self.current_route_arena) |route| {
        return route.nodeAlloc();
    }
    return null;
}

/// Get stats for current frame
pub fn getStats(self: *FrameAllocator) ?Stats {
    if (self.current_route_arena) |route| {
        return route.getStats();
    }
    return null;
}

/// Does nothing.
pub fn printPrevStats(_: *FrameAllocator) void {}

/// Does nothing.
pub fn printStats(_: *FrameAllocator) void {}
