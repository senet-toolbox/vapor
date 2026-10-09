pub fn RingBuffer(comptime T: type, comptime capacity: usize) type {
    return struct {
        const Self = @This();

        items: [capacity]T = undefined,
        head: usize = 0, // next write position
        count: usize = 0,

        pub fn push(self: *Self, item: T) void {
            self.items[self.head] = item;
            self.head = (self.head + 1) % capacity;
            if (self.count < capacity) {
                self.count += 1;
            }
        }

        pub fn pushSlice(self: *Self, items: []const T) void {
            for (items) |item| {
                self.push(item);
            }
        }

        /// Returns the most recent item, or null if empty.
        pub fn peek(self: *const Self) ?T {
            if (self.count == 0) return null;
            const idx = if (self.head == 0) capacity - 1 else self.head - 1;
            return self.items[idx];
        }

        /// Returns the item at position `i` from oldest to newest.
        pub fn get(self: *const Self, i: usize) ?T {
            if (i >= self.count) return null;
            const start = if (self.count < capacity) 0 else self.head;
            return self.items[(start + i) % capacity];
        }

        /// Copies all entries oldest-to-newest into a caller-provided slice.
        /// Returns the filled portion.
        pub fn snapshot(self: *const Self, buf: []T) []T {
            const ring_len = @min(self.count, buf.len);
            const start = if (self.count < capacity) 0 else self.head;
            for (0..ring_len) |i| {
                buf[i] = self.items[(start + i) % capacity];
            }
            return buf[0..ring_len];
        }

        /// Allocates a snapshot on the given allocator.
        pub fn snapshotAlloc(self: *const Self, allocator: std.mem.Allocator) ![]T {
            const buf = try allocator.alloc(T, self.count);
            return self.snapshot(buf);
        }

        /// Iterates oldest to newest without allocating.
        pub fn iterator(self: *const Self) Iterator {
            return .{
                .ring = self,
                .pos = 0,
            };
        }

        pub const Iterator = struct {
            ring: *const Self,
            pos: usize,

            pub fn next(it: *Iterator) ?T {
                if (it.pos >= it.ring.count) return null;
                const item = it.ring.get(it.pos).?;
                it.pos += 1;
                return item;
            }

            pub fn reset(it: *Iterator) void {
                it.pos = 0;
            }
        };

        pub fn len(self: *const Self) usize {
            return self.count;
        }

        pub fn isFull(self: *const Self) bool {
            return self.count == capacity;
        }

        pub fn clear(self: *Self) void {
            self.head = 0;
            self.count = 0;
        }
    };
}

// ...because BoundedArray is gone from the stdlib
const std = @import("std");
const assert = std.debug.assert;

pub fn BoundedArray(comptime T: type, comptime buffer_capacity: usize) type {
    return struct {
        const Self = @This();
        buffer: [buffer_capacity]T = undefined,
        len: usize = 0,

        pub fn init(len: usize) error{Overflow}!Self {
            if (len > buffer_capacity) return error.Overflow;
            return Self{ .len = len };
        }

        pub fn slice(self: anytype) switch (@TypeOf(&self.buffer)) {
            *[buffer_capacity]T => []T,
            *const [buffer_capacity]T => []const T,
            else => unreachable,
        } {
            return self.buffer[0..self.len];
        }

        pub fn append(self: *Self, item: T) error{Overflow}!void {
            const new_item_ptr = try self.addOne();
            new_item_ptr.* = item;
        }

        pub fn pop(self: *Self) error{OutOfBounds}!T {
            if (self.len == 0) return error.OutOfBounds;
            self.len -= 1;
            return self.buffer[self.len];
        }

        pub fn appendAssumeCapacity(self: *Self, item: T) void {
            const new_item_ptr = self.addOneAssumeCapacity();
            new_item_ptr.* = item;
        }

        pub fn appendSlice(self: *Self, items: []const T) error{Overflow}!void {
            try self.ensureUnusedCapacity(items.len);
            self.appendSliceAssumeCapacity(items);
        }

        pub fn appendSliceAssumeCapacity(self: *Self, items: []const T) void {
            const old_len = self.len;
            self.len += items.len;
            @memcpy(self.slice()[old_len..][0..items.len], items);
        }

        pub fn ensureUnusedCapacity(self: Self, additional_count: usize) error{Overflow}!void {
            if (self.len + additional_count > buffer_capacity) {
                return error.Overflow;
            }
        }

        pub fn addOne(self: *Self) error{Overflow}!*T {
            try self.ensureUnusedCapacity(1);
            return self.addOneAssumeCapacity();
        }

        pub fn addOneAssumeCapacity(self: *Self) *T {
            assert(self.len < buffer_capacity);
            self.len += 1;
            return &self.slice()[self.len - 1];
        }
    };
}
