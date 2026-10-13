//! Arena-backed containers: `Array` (exported as `Vapor.ArrayArena`), a
//! growable list that never needs `deinit`, and `BoundedArray`, stored inline.

const std = @import("std");
const assert = std.debug.assert;
const Vapor = @import("vapor.zig");

// ============================================================
// Dynamic Array (arena-backed, no deinit needed)
// ============================================================

/// A growable list whose memory comes from one of vapor's arenas, so it
/// needs no `deinit`. Exported as `Vapor.ArrayArena`.
pub fn Array(comptime T: type) type {
    return struct {
        items: []T = &.{},
        capacity: usize = 0,
        arena: Vapor.ArenaType,

        const Self = @This();

        /// An empty list whose memory comes from `arena_type`.
        pub fn init(arena_type: Vapor.ArenaType) Self {
            return .{ .arena = arena_type };
        }

        fn allocator(self: Self) std.mem.Allocator {
            return Vapor.arena(self.arena);
        }

        /// Empties the list, keeping its memory.
        pub fn clearRetainingCapacity(self: *Self) void {
            self.items.len = 0;
        }

        // --- core ---

        /// Appends `item`, growing as needed.
        pub fn append(self: *Self, item: T) void {
            self.ensureCapacity(self.items.len + 1);
            self.items.len += 1;
            self.items[self.items.len - 1] = item;
        }

        /// Appends `item`; there must be room.
        pub fn appendAssumeCapacity(self: *Self, item: T) void {
            assert(self.items.len < self.capacity);
            self.items.len += 1; // expand first
            self.items[self.items.len - 1] = item; // then write
        }

        /// Appends every item of `items`.
        pub fn appendSlice(self: *Self, items: []const T) void {
            self.ensureCapacity(self.items.len + items.len);
            const start = self.items.len;
            self.items.len += items.len;
            @memcpy(self.items[start..], items);
        }

        /// Removes and returns the last item, or `null` if empty.
        pub fn pop(self: *Self) ?T {
            if (self.items.len == 0) return null;
            const val = self.items[self.items.len - 1];
            self.items.len -= 1;
            return val;
        }

        /// The last item, or `null` if empty.
        pub fn last(self: Self) ?T {
            if (self.items.len == 0) return null;
            return self.items[self.items.len - 1];
        }

        /// Inserts `item` at index `i`, shifting later items.
        pub fn insert(self: *Self, i: usize, item: T) void {
            self.ensureCapacity(self.items.len + 1);
            self.items.len += 1;
            std.mem.copyBackwards(T, self.items[i + 1 .. self.items.len], self.items[i .. self.items.len - 1]);
            self.items[i] = item;
        }

        // --- access ---

        /// The item at `i`.
        pub fn get(self: Self, i: usize) T {
            return self.items[i];
        }

        /// Pointer to the item at `i`.
        pub fn getPtr(self: Self, i: usize) *T {
            return &self.items[i];
        }

        /// Replaces the item at `i`.
        pub fn set(self: *Self, i: usize, val: T) void {
            self.items[i] = val;
        }

        /// The items as a slice.
        pub fn slice(self: Self) []T {
            return self.items;
        }

        // --- remove ---

        /// Removes the item at `i` by moving the last item into its place.
        pub fn swapRemove(self: *Self, i: usize) T {
            const val = self.items[i];
            self.items[i] = self.items[self.items.len - 1];
            self.items.len -= 1;
            return val;
        }

        /// Removes the item at `i`, keeping the order.
        pub fn orderedRemove(self: *Self, i: usize) T {
            const val = self.items[i];
            std.mem.copyForwards(T, self.items[i .. self.items.len - 1], self.items[i + 1 .. self.items.len]);
            self.items.len -= 1;
            return val;
        }

        /// Empties the list.
        pub fn clear(self: *Self) void {
            self.items.len = 0;
        }

        // --- query ---

        /// Number of items.
        pub fn len(self: Self) usize {
            return self.items.len;
        }

        /// Whether the list is empty.
        pub fn empty(self: Self) bool {
            return self.items.len == 0;
        }

        // --- search ---

        /// Whether an item equals `needle`.
        pub fn contains(self: Self, needle: T) bool {
            return self.indexOf(needle) != null;
        }

        /// Index of the first item equal to `needle`, or `null`.
        pub fn indexOf(self: Self, needle: T) ?usize {
            for (self.items, 0..) |item, i| {
                if (meta.equal(T, item, needle)) return i;
            }
            return null;
        }

        /// The first item matching `predicate`, or `null`.
        pub fn find(self: Self, predicate: *const fn (T) bool) ?T {
            for (self.items) |item| {
                if (predicate(item)) return item;
            }
            return null;
        }

        /// Pointer to the first item matching `predicate`, or `null`.
        pub fn findPtr(self: Self, predicate: *const fn (T) bool) ?*T {
            for (self.items, 0..) |_, i| {
                if (predicate(self.items[i])) return &self.items[i];
            }
            return null;
        }

        // --- transform (returns new arrays on same arena) ---

        /// A new list with the items matching `predicate`.
        pub fn filter(self: Self, predicate: *const fn (T) bool) Self {
            var result = Self.init(self.arena);
            for (self.items) |item| {
                if (predicate(item)) result.append(item);
            }
            return result;
        }

        /// A new list with `func` applied to each item.
        pub fn map(self: Self, comptime R: type, func: *const fn (T) R) Array(R) {
            var result = Array(R).init(self.arena);
            for (self.items) |item| {
                result.append(func(item));
            }
            return result;
        }

        /// Folds the items into one value with `func`, starting from `initial`.
        pub fn reduce(self: Self, comptime R: type, initial: R, func: *const fn (R, T) R) R {
            var acc = initial;
            for (self.items) |item| {
                acc = func(acc, item);
            }
            return acc;
        }

        // --- bulk operations ---

        /// Whether some item matches `predicate`.
        pub fn any(self: Self, predicate: *const fn (T) bool) bool {
            for (self.items) |item| {
                if (predicate(item)) return true;
            }
            return false;
        }

        /// Whether every item matches `predicate`.
        pub fn all(self: Self, predicate: *const fn (T) bool) bool {
            for (self.items) |item| {
                if (!predicate(item)) return false;
            }
            return true;
        }

        /// How many items match `predicate`.
        pub fn count(self: Self, predicate: *const fn (T) bool) usize {
            var n: usize = 0;
            for (self.items) |item| {
                if (predicate(item)) n += 1;
            }
            return n;
        }

        /// Reverses the items in place.
        pub fn reverse(self: *Self) void {
            if (self.items.len < 2) return;
            var lo: usize = 0;
            var hi: usize = self.items.len - 1;
            while (lo < hi) {
                const tmp = self.items[lo];
                self.items[lo] = self.items[hi];
                self.items[hi] = tmp;
                lo += 1;
                hi -= 1;
            }
        }

        /// A copy in the same arena.
        pub fn clone(self: Self) Self {
            var result = Self.init(self.arena);
            result.appendSlice(self.items);
            return result;
        }

        // --- internals ---

        /// Grows the list to hold at least `min` items.
        pub fn ensureCapacity(self: *Self, min: usize) void {
            if (min <= self.capacity) return;

            const new_cap = @max(min, self.capacity * 2, 8);
            const new_mem = self.allocator().alloc(T, new_cap) catch @panic("Array: out of memory");

            const old_base = @intFromPtr(self.items.ptr);
            const new_base = @intFromPtr(new_mem.ptr);
            const old_byte_size = self.capacity * @sizeOf(T);

            if (self.items.len > 0) {
                @memcpy(new_mem[0..self.items.len], self.items);
            }

            const old_len = self.items.len;
            self.items = new_mem[0..old_len];
            self.capacity = new_cap;

            // Remap *after* the move is complete. Order doesn't actually matter
            // for correctness here (the table only reads its own state), but
            // doing it last keeps the array in a consistent state if remap ever
            // grows side effects.
            Vapor.text_field_table.remapPointerRange(old_base, new_base, old_byte_size) catch @panic("Array: remap failed");
        }
    };
}

// ============================================================
// Bounded Array (comptime capacity, stack-allocated, no allocator)
// ============================================================

/// A list stored inline with room for `buffer_capacity` items; never allocates.
pub fn BoundedArray(comptime T: type, comptime buffer_capacity: usize) type {
    return struct {
        buffer: [buffer_capacity]T = undefined,
        len: usize = 0,

        const Self = @This();

        /// A bounded array of `initial_len` undefined items; fails if over capacity.
        pub fn init(initial_len: usize) error{Overflow}!Self {
            if (initial_len > buffer_capacity) return error.Overflow;
            return Self{ .len = initial_len };
        }

        /// A bounded array holding `items`; fails if they do not fit.
        pub fn fromSlice(items: []const T) error{Overflow}!Self {
            if (items.len > buffer_capacity) return error.Overflow;
            var self = Self{};
            @memcpy(self.buffer[0..items.len], items);
            self.len = items.len;
            return self;
        }

        // --- core ---

        /// Adds an item and returns a pointer to fill it in.
        pub fn push(self: *Self) error{Overflow}!*T {
            if (self.len >= buffer_capacity) return error.Overflow;
            self.len += 1;
            return &self.buffer[self.len - 1];
        }

        /// Appends `item`; fails when full.
        pub fn append(self: *Self, item: T) error{Overflow}!void {
            const ptr = try self.push();
            ptr.* = item;
        }

        /// Appends `item`; there must be room.
        pub fn appendAssumeCapacity(self: *Self, item: T) void {
            assert(self.len < buffer_capacity);
            self.buffer[self.len] = item;
            self.len += 1;
        }

        /// Appends `items`; fails if they do not fit.
        pub fn appendSlice(self: *Self, items: []const T) error{Overflow}!void {
            if (self.len + items.len > buffer_capacity) return error.Overflow;
            @memcpy(self.buffer[self.len..][0..items.len], items);
            self.len += items.len;
        }

        /// Removes and returns the last item, or `null` if empty.
        pub fn pop(self: *Self) ?T {
            if (self.len == 0) return null;
            self.len -= 1;
            return self.buffer[self.len];
        }

        /// The last item, or `null` if empty.
        pub fn last(self: Self) ?T {
            if (self.len == 0) return null;
            return self.buffer[self.len - 1];
        }

        // --- access ---

        /// The item at `i`.
        pub fn get(self: Self, i: usize) T {
            return self.buffer[i];
        }

        /// Pointer to the item at `i`.
        pub fn getPtr(self: *Self, i: usize) *T {
            return &self.buffer[i];
        }

        /// Replaces the item at `i`.
        pub fn set(self: *Self, i: usize, val: T) void {
            self.buffer[i] = val;
        }

        /// The items as a slice.
        pub fn slice(self: anytype) switch (@TypeOf(&self.buffer)) {
            *[buffer_capacity]T => []T,
            *const [buffer_capacity]T => []const T,
            else => unreachable,
        } {
            return self.buffer[0..self.len];
        }

        // --- remove ---

        /// Removes the item at `i` by moving the last item into its place.
        pub fn swapRemove(self: *Self, i: usize) T {
            const val = self.buffer[i];
            self.buffer[i] = self.buffer[self.len - 1];
            self.len -= 1;
            return val;
        }

        /// Removes the item at `i`, keeping the order.
        pub fn orderedRemove(self: *Self, i: usize) T {
            const val = self.buffer[i];
            std.mem.copyForwards(T, self.buffer[i .. self.len - 1], self.buffer[i + 1 .. self.len]);
            self.len -= 1;
            return val;
        }

        /// Empties the list.
        pub fn clear(self: *Self) void {
            self.len = 0;
        }

        // --- query ---

        /// Whether the list is empty.
        pub fn empty(self: Self) bool {
            return self.len == 0;
        }

        /// Whether no room is left.
        pub fn full(self: Self) bool {
            return self.len == buffer_capacity;
        }

        /// How many more items fit.
        pub fn remaining(self: Self) usize {
            return buffer_capacity - self.len;
        }

        // --- search ---

        /// Whether an item equals `needle`.
        pub fn contains(self: Self, needle: T) bool {
            return self.indexOf(needle) != null;
        }

        /// Index of the first item equal to `needle`, or `null`.
        pub fn indexOf(self: Self, needle: T) ?usize {
            for (self.buffer[0..self.len], 0..) |item, i| {
                if (meta.equal(T, item, needle)) return i;
            }
            return null;
        }

        /// The first item matching `predicate`, or `null`.
        pub fn find(self: Self, predicate: *const fn (T) bool) ?T {
            for (self.buffer[0..self.len]) |item| {
                if (predicate(item)) return item;
            }
            return null;
        }

        // --- transform ---

        /// A copy with the items matching `predicate`.
        pub fn filter(self: Self, predicate: *const fn (T) bool) Self {
            var result = Self{};
            for (self.buffer[0..self.len]) |item| {
                if (predicate(item)) {
                    result.appendAssumeCapacity(item);
                }
            }
            return result;
        }

        /// Whether some item matches `predicate`.
        pub fn any(self: Self, predicate: *const fn (T) bool) bool {
            for (self.buffer[0..self.len]) |item| {
                if (predicate(item)) return true;
            }
            return false;
        }

        /// Whether every item matches `predicate`.
        pub fn all(self: Self, predicate: *const fn (T) bool) bool {
            for (self.buffer[0..self.len]) |item| {
                if (!predicate(item)) return false;
            }
            return true;
        }

        /// How many items match `predicate`.
        pub fn count(self: Self, predicate: *const fn (T) bool) usize {
            var n: usize = 0;
            for (self.buffer[0..self.len]) |item| {
                if (predicate(item)) n += 1;
            }
            return n;
        }

        /// Reverses the items in place.
        pub fn reverse(self: *Self) void {
            if (self.len < 2) return;
            var lo: usize = 0;
            var hi: usize = self.len - 1;
            while (lo < hi) {
                const tmp = self.buffer[lo];
                self.buffer[lo] = self.buffer[hi];
                self.buffer[hi] = tmp;
                lo += 1;
                hi -= 1;
            }
        }
    };
}

// ============================================================
// Meta helpers for generic equality
// ============================================================

const meta = struct {
    fn equal(comptime T: type, a: T, b: T) bool {
        const info = @typeInfo(T);
        return switch (info) {
            .@"struct" => if (@hasDecl(T, "eql")) a.eql(b) else a == b,
            .pointer => |p| if (p.size == .Slice and p.child == u8)
                std.mem.eql(u8, a, b)
            else
                a == b,
            else => a == b,
        };
    }
};
