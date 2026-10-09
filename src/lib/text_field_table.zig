//! Strings bound to text fields, kept stable across renders.

const std = @import("std");
const Vapor = @import("vapor.zig");

/// We need to handle Reallocs
pub const StringTable = struct {
    const Self = @This();

    /// Entry stored in the table - now holds the allocated slice directly
    const Entry = struct {
        data: []const u8,
    };

    /// Map from pointer address to entry index
    index_map: std.AutoHashMap(u32, u32),
    /// List of all entries (index = handle returned to user)
    entries: std.array_list.Managed(Entry),
    /// Allocator used for internal structures
    allocator: std.mem.Allocator,

    /// Special value indicating no string / null
    pub const null_handle: u32 = std.math.maxInt(u32);

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .index_map = std.AutoHashMap(u32, u32).init(allocator),
            .entries = std.array_list.Managed(Entry).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        // Free all allocated strings
        for (self.entries.items) |entry| {
            if (entry.data.len > 0) {
                self.allocator.free(entry.data);
            }
        }
        self.index_map.deinit();
        self.entries.deinit();
    }

    /// Interns a string and returns a stable u32 handle.
    /// If the string already exists, returns the existing handle.
    /// Returns `null_handle` if the input is null or empty.
    pub fn intern(self: *Self, str: ?*const []const u8) !u32 {
        const s = str orelse return null_handle;
        if (s.len == 0) return null_handle;

        const key: u32 = @intCast(@intFromPtr(str));

        // Check if already interned
        if (self.index_map.get(key)) |existing_index| {
            const entry = self.entries.items[existing_index];
            if (std.mem.eql(u8, entry.data, s.*)) {
                return existing_index;
            }
            // Different content at same pointer - shouldn't happen with intern
            // but fall through to add new entry
        }

        // Allocate and copy the string
        const data = try self.allocator.dupe(u8, s.*);

        const index: u32 = @intCast(self.entries.items.len);
        try self.entries.append(.{ .data = data });
        try self.index_map.put(key, index);

        return index;
    }

    /// Replaces the string at an existing handle's pointer key, or adds a new entry.
    /// Frees the old string data if replacing.
    /// Returns the handle (existing or new).
    pub fn replaceOrAdd(self: *Self, str: ?*[]const u8) !u32 {
        const s = str orelse return null_handle;
        if (s.len == 0) return null_handle;

        const key: u32 = @truncate(@intFromPtr(str));

        // Check if this pointer is already tracked
        if (self.index_map.get(key)) |existing_index| {
            const entry = &self.entries.items[existing_index];

            // If content is the same, nothing to do
            if (std.mem.eql(u8, entry.data, s.*)) {
                return existing_index;
            }

            // Free old string
            if (entry.data.len > 0) {
                self.allocator.free(entry.data);
            }

            // Allocate new string
            entry.data = try self.allocator.dupe(u8, s.*);
            s.* = entry.data;

            return existing_index;
        }

        // New pointer - add fresh entry
        const data = try self.allocator.dupe(u8, s.*);

        const index: u32 = @intCast(self.entries.items.len);
        try self.entries.append(.{ .data = data });
        try self.index_map.put(key, index);
        s.* = data;

        return index;
    }

    /// Retrieves a string by its handle.
    /// Returns null if the handle is invalid or null_handle.
    pub fn get(self: *const Self, handle: u32) ?[]const u8 {
        if (handle == null_handle) return null;
        if (handle >= self.entries.items.len) return null;
        return self.entries.items[handle].data;
    }

    /// Returns the number of unique strings stored.
    pub fn count(self: *const Self) u32 {
        return @intCast(self.entries.items.len);
    }

    /// Returns total bytes used for string storage.
    pub fn totalStringBytes(self: *const Self) usize {
        var total: usize = 0;
        for (self.entries.items) |entry| {
            total += entry.data.len;
        }
        return total;
    }

    /// Clears all strings. Existing handles become invalid.
    pub fn clear(self: *Self) void {
        for (self.entries.items) |entry| {
            if (entry.data.len > 0) {
                self.allocator.free(entry.data);
            }
        }
        self.index_map.clearRetainingCapacity();
        self.entries.clearRetainingCapacity();
    }

    pub fn remapPointerRange(
        self: *Self,
        old_base: usize,
        new_base: usize,
        size: usize,
    ) !void {
        // Collect first, mutate after — can't modify a HashMap mid-iteration.
        var to_remap = std.array_list.Managed(struct { old_key: u32, new_key: u32, idx: u32 }).init(self.allocator);
        defer to_remap.deinit();

        var it = self.index_map.iterator();
        while (it.next()) |kv| {
            const k = kv.key_ptr.*;
            if (k >= old_base and k < old_base + size) {
                const new_key: u32 = @intCast(k - old_base + new_base);
                try to_remap.append(.{ .old_key = k, .new_key = new_key, .idx = kv.value_ptr.* });
            }
        }

        for (to_remap.items) |r| {
            _ = self.index_map.remove(r.old_key);
            try self.index_map.put(r.new_key, r.idx);
        }
    }
};
