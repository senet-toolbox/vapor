//! Allocator-carrying wrappers around std's unmanaged MemoryPool and
//! AutoHashMap.

const std = @import("std");

// Wrapper that pairs an unmanaged MemoryPool with its allocator
/// A `std.heap.MemoryPool` that keeps its allocator.
pub fn ManagedMemoryPool(comptime T: type) type {
    return struct {
        pool: std.heap.MemoryPool(T) = .empty,
        allocator: std.mem.Allocator,

        const Self = @This();

        /// An empty pool using `allocator`.
        pub fn init(allocator: std.mem.Allocator) Self {
            return .{ .allocator = allocator };
        }

        /// Frees every item.
        pub fn deinit(self: *Self) void {
            self.pool.deinit(self.allocator);
        }

        /// A new item.
        pub fn create(self: *Self) std.mem.Allocator.Error!*T {
            return self.pool.create(self.allocator);
        }

        pub fn destroy(self: *Self, ptr: *T) void {
            // The pool over-aligns its items; `ptr` came from `create`, so it
            // carries that alignment even though `*T` does not say so.
            self.pool.destroy(@alignCast(ptr));
        }
    };
}

// Wrapper that pairs an unmanaged AutoHashMap with its allocator
/// A `std.AutoHashMapUnmanaged` that keeps its allocator.
pub fn ManagedAutoHashMap(comptime K: type, comptime V: type) type {
    return struct {
        map: std.AutoHashMapUnmanaged(K, V) = .empty,
        allocator: std.mem.Allocator,

        const Self = @This();

        /// An empty map using `allocator`.
        pub fn init(allocator: std.mem.Allocator) Self {
            return .{ .allocator = allocator };
        }

        /// Frees the map.
        pub fn deinit(self: *Self) void {
            self.map.deinit(self.allocator);
        }

        /// Inserts or replaces `key`.
        pub fn put(self: *Self, key: K, value: V) std.mem.Allocator.Error!void {
            return self.map.put(self.allocator, key, value);
        }

        /// The value for `key`.
        pub fn get(self: *Self, key: K) ?V {
            return self.map.get(key);
        }

        /// Pointer to the value for `key`.
        pub fn getPtr(self: *Self, key: K) ?*V {
            return self.map.getPtr(key);
        }

        /// Removes `key`; returns whether it was there.
        pub fn remove(self: *Self, key: K) bool {
            return self.map.remove(key);
        }

        /// Whether `key` is present.
        pub fn contains(self: *Self, key: K) bool {
            return self.map.contains(key);
        }

        /// Number of entries.
        pub fn count(self: *Self) usize {
            return self.map.count();
        }
        /// Iterates over the entries.
        pub fn iterator(self: *Self) std.AutoHashMapUnmanaged(K, V).Iterator {
            return self.map.iterator();
        }
        /// Removes every entry, keeping the memory.
        pub fn clearRetainingCapacity(self: *Self) void {
            self.map.clearRetainingCapacity();
        }
    };
}
