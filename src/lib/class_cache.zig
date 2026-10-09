//! Reference counts for generated CSS classes, so a rule is removed from the
//! stylesheet once no element uses it.

// The ClassCache is a simple cache for reference counting of the number of element that share the same class
const std = @import("std");
const Vapor = @import("vapor.zig");
const Wasm = Vapor.Wasm;

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
};

pub const ClassCache = struct {
    const Self = @This();

    // The Hash is the key into the map it represent the class name
    const Hash = u32;

    const Class = struct {
        name: []const u8,
        type: ClassType,
        count: u32,
        tombstone: bool = false,
    };

    map: std.AutoHashMap(Hash, Class),
    scratch_arena: std.heap.ArenaAllocator,
    tombstones: Vapor.Array(Hash) = undefined,

    /// An empty cache.
    pub fn init(class_cache: *Self, allocator: std.mem.Allocator) !void {
        class_cache.* = Self{
            .map = undefined,
            .scratch_arena = std.heap.ArenaAllocator.init(allocator),
            .tombstones = undefined,
        };
        const map = std.AutoHashMap(Hash, Class).init(class_cache.scratch_arena.allocator());
        class_cache.map = map;
        class_cache.tombstones = Vapor.Array(Hash).init(class_cache.scratch_arena.allocator());
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
        };
    }

    /// The cached class for `hash`, if any.
    pub fn get(self: *Self, hash: Hash) ?Class {
        return self.map.get(hash);
    }

    /// Records a use of the class `hash`, creating it on first use.
    pub fn set(self: *Self, hash: Hash, class_type: ClassType) !void {
        // 1. Check existence FIRST to avoid allocation
        if (self.map.getPtr(hash)) |class| {
            class.count += 1;
            return;
        }

        // 2. Only allocate if it's actually new
        const class_type_as_str = getClassNameByType(class_type);
        const full_class = try std.fmt.allocPrint(self.scratch_arena.allocator(), "{s}_{any}", .{ class_type_as_str, hash });

        try self.map.put(hash, .{
            .name = full_class,
            .type = class_type,
            .count = 1,
        });
    }

    /// Drops one use of `hash`; at zero it becomes a tombstone.
    pub fn decrement(self: *Self, hash: Hash) !void {
        const class_ptr = self.map.getPtr(hash) orelse return error.ClassNotFound;

        // Safety check to prevent double-free logic
        if (class_ptr.count == 0) return;

        class_ptr.count -= 1;

        if (class_ptr.count == 0) {
            // Queue the HASH for deletion, don't store the whole Class copy
            try self.tombstones.append(hash);
        }
    }

    /// Classes whose count reached zero.
    pub fn getTombstones(self: *Self) []Hash {
        return self.tombstones.items[0..];
    }

    /// Asks the runtime to delete the CSS rules of classes no element uses.
    ///
    /// Deliberately disabled: the guard below returns whenever there is work
    /// to do. The refcounts are not reliable yet. A class shared by several
    /// elements is counted once (configuration only calls `set` when the class
    /// is missing), and removing an element never decrements its classes. So a
    /// count can reach zero while elements still use the rule. Until both are
    /// fixed, rules are kept and the stylesheet only grows.
    pub fn batchRemove(self: *Self) void {
        if (self.tombstones.items.len > 0) return;
        if (Vapor.isWasi) {
            Wasm.batchRemoveTombStonesWasm();
        }
    }

    /// The `index`-th tombstone.
    pub fn getTombstone(self: *Self, index: usize) Hash {
        return self.tombstones.items[index];
    }

    // Call this AFTER the JS side has read the tombstones and removed CSS classes
    /// Clears the tombstones and the whole cache, after the runtime removed them.
    pub fn flushTombstones(self: *Self) void {
        // Reset the list
        self.tombstones.clearRetainingCapacity();
        self.map.clearRetainingCapacity();
        const did = self.scratch_arena.reset(.retain_capacity);
        if (!did) {
            Vapor.printlnSrcErr("Failed to ClassCache reset arena\nPlease report bug to maintainer", .{}, @src());
        }
    }

    /// The class name of the `index`-th tombstone, for the runtime.
    pub fn getTombstoneName(self: *Self, index: usize) ?[]const u8 {
        if (index >= self.tombstones.items.len) return null;
        const hash = self.tombstones.items[index];
        const class = self.map.get(hash) orelse return null;
        return class.name;
    }
};

export fn getTombstoneCount() usize {
    return Vapor.class_cache.tombstones.items.len;
}

export fn getTombstoneClassNamePtr(index: usize) ?[*]const u8 {
    if (index >= Vapor.class_cache.tombstones.items.len) return null;
    const name = Vapor.class_cache.getTombstoneName(index) orelse return null;
    Vapor.println("Tombstone: {s}\n", .{name});
    return name.ptr;
}

export fn getTombstoneClassNameLength(index: usize) usize {
    if (index >= Vapor.class_cache.tombstones.items.len) return 0;
    const name = Vapor.class_cache.getTombstoneName(index) orelse return 0;
    return name.len;
}

export fn clearTombstones() void {
    Vapor.class_cache.flushTombstones();
}
