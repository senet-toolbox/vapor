const std = @import("std");

/// A string interning table that stores unique strings and returns stable u32 indices.
/// Useful for replacing pointers in packed structs to ensure consistent hashing across platforms.
pub const StringTable = struct {
    const Self = @This();

    /// Entry stored in the table
    const Entry = struct {
        offset: u32,
        len: u32,
    };

    /// Sentinel value for removed entries
    const removed_offset: u32 = std.math.maxInt(u32);

    /// Backing storage for all string data
    string_data: std.array_list.Managed(u8),
    /// Map from string hash to entry index
    index_map: std.AutoHashMap(u64, u32),
    /// List of all entries (index = handle returned to user)
    entries: std.array_list.Managed(Entry),
    /// Allocator used for internal structures
    allocator: std.mem.Allocator,

    /// Special value indicating no string / null
    pub const null_handle: u32 = std.math.maxInt(u32);

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .string_data = std.array_list.Managed(u8).init(allocator),
            .index_map = std.AutoHashMap(u64, u32).init(allocator),
            .entries = std.array_list.Managed(Entry).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.string_data.deinit();
        self.index_map.deinit();
        self.entries.deinit();
    }

    /// Interns a string and returns a stable u32 handle.
    /// If the string already exists, returns the existing handle.
    /// Returns `null_handle` if the input is null or empty.
    pub fn intern(self: *Self, str: ?[]const u8) !u32 {
        const s = str orelse return null_handle;
        if (s.len == 0) return null_handle;

        const hash = std.hash.Wyhash.hash(0, s);

        // Check if already interned
        if (self.index_map.get(hash)) |existing_index| {
            // Verify it's actually the same string (hash collision check)
            const entry = self.entries.items[existing_index];
            const existing = self.string_data.items[entry.offset..][0..entry.len];
            if (std.mem.eql(u8, existing, s)) {
                return existing_index;
            }
            // Hash collision - fall through to add new entry
        }

        // Add new string
        const offset: u32 = @intCast(self.string_data.items.len);
        try self.string_data.appendSlice(s);

        const index: u32 = @intCast(self.entries.items.len);
        try self.entries.append(.{
            .offset = offset,
            .len = @intCast(s.len),
        });

        try self.index_map.put(hash, index);

        return index;
    }

    /// Looks up the handle for an already-interned string, without interning it.
    /// Returns null if the string is not present.
    pub fn handleOf(self: *const Self, str: []const u8) ?u32 {
        if (str.len == 0) return null;

        const hash = std.hash.Wyhash.hash(0, str);
        const index = self.index_map.get(hash) orelse return null;
        const entry = self.entries.items[index];
        if (entry.len == 0) return null; // removed

        const existing = self.string_data.items[entry.offset..][0..entry.len];
        if (!std.mem.eql(u8, existing, str)) return null; // hash collision
        return index;
    }

    /// Retrieves a string by its handle.
    /// Returns null if the handle is invalid, removed, or null_handle.
    pub fn get(self: *const Self, handle: u32) ?[]const u8 {
        if (handle == null_handle) return null;
        if (handle >= self.entries.items.len) return null;

        const entry = self.entries.items[handle];
        if (entry.offset == removed_offset) return null;
        return self.string_data.items[entry.offset..][0..entry.len];
    }

    /// Removes a pinned string by handle. The entry is marked as dead
    /// and the index_map slot is freed, but the bytes in string_data
    /// remain until `compact()` or `clear()` is called.
    /// Returns true if the handle was valid and removed.
    pub fn remove(self: *Self, handle: u32) bool {
        if (handle == null_handle) return false;
        if (handle >= self.entries.items.len) return false;

        const entry = &self.entries.items[handle];
        if (entry.offset == removed_offset) return false;

        // Remove from index_map
        const str = self.string_data.items[entry.offset..][0..entry.len];
        const hash = std.hash.Wyhash.hash(0, str);
        _ = self.index_map.remove(hash);

        // Mark entry as dead
        entry.offset = removed_offset;
        entry.len = 0;

        return true;
    }

    /// Returns true if the handle is valid and currently alive (not removed).
    pub fn isValid(self: *const Self, handle: u32) bool {
        if (handle == null_handle) return false;
        if (handle >= self.entries.items.len) return false;
        return self.entries.items[handle].offset != removed_offset;
    }

    /// Returns the number of unique strings stored (including removed slots).
    pub fn count(self: *const Self) u32 {
        return @intCast(self.entries.items.len);
    }

    /// Returns total bytes used for string storage (including dead bytes).
    pub fn totalStringBytes(self: *const Self) usize {
        return self.string_data.items.len;
    }

    /// Compacts string_data by removing dead entry bytes and rebuilding.
    /// WARNING: This invalidates ALL existing handles. Only call at
    /// scope boundaries (page teardown, etc).
    pub fn compact(self: *Self) !void {
        var new_data = std.array_list.Managed(u8).init(self.allocator);
        var new_entries = std.array_list.Managed(Entry).init(self.allocator);
        self.index_map.clearRetainingCapacity();

        errdefer {
            new_data.deinit();
            new_entries.deinit();
        }

        for (self.entries.items) |entry| {
            if (entry.offset == removed_offset) {
                // Preserve slot to keep indices stable
                try new_entries.append(.{ .offset = removed_offset, .len = 0 });
                continue;
            }

            const str = self.string_data.items[entry.offset..][0..entry.len];
            const new_offset: u32 = @intCast(new_data.items.len);
            try new_data.appendSlice(str);

            const idx: u32 = @intCast(new_entries.items.len);
            try new_entries.append(.{ .offset = new_offset, .len = entry.len });

            const hash = std.hash.Wyhash.hash(0, str);
            try self.index_map.put(hash, idx);
        }

        self.string_data.deinit();
        self.entries.deinit();
        self.string_data = new_data;
        self.entries = new_entries;
    }

    /// Clears all strings. Existing handles become invalid.
    pub fn clear(self: *Self) void {
        self.string_data.clearRetainingCapacity();
        self.index_map.clearRetainingCapacity();
        self.entries.clearRetainingCapacity();
    }
};

// ============================================================================
// Tests
// ============================================================================

test "basic intern and retrieve" {
    var table = StringTable.init(std.testing.allocator);
    defer table.deinit();

    const handle1 = try table.intern("hello");
    const handle2 = try table.intern("world");
    const handle3 = try table.intern("hello"); // duplicate

    try std.testing.expect(handle1 != handle2);
    try std.testing.expectEqual(handle1, handle3); // same string = same handle

    try std.testing.expectEqualStrings("hello", table.get(handle1).?);
    try std.testing.expectEqualStrings("world", table.get(handle2).?);
}

test "null and empty strings" {
    var table = StringTable.init(std.testing.allocator);
    defer table.deinit();

    const null_h = try table.intern(null);
    const empty_h = try table.intern("");

    try std.testing.expectEqual(StringTable.null_handle, null_h);
    try std.testing.expectEqual(StringTable.null_handle, empty_h);
    try std.testing.expectEqual(@as(?[]const u8, null), table.get(StringTable.null_handle));
}

test "invalid handle" {
    var table = StringTable.init(std.testing.allocator);
    defer table.deinit();

    try std.testing.expectEqual(@as(?[]const u8, null), table.get(999));
}

test "remove and get returns null" {
    var table = StringTable.init(std.testing.allocator);
    defer table.deinit();

    const handle = try table.intern("goodbye");
    try std.testing.expectEqualStrings("goodbye", table.get(handle).?);

    try std.testing.expect(table.remove(handle));
    try std.testing.expectEqual(@as(?[]const u8, null), table.get(handle));

    // Double remove returns false
    try std.testing.expect(!table.remove(handle));
}

test "remove does not affect other handles" {
    var table = StringTable.init(std.testing.allocator);
    defer table.deinit();

    const h1 = try table.intern("alpha");
    const h2 = try table.intern("beta");
    const h3 = try table.intern("gamma");

    try std.testing.expect(table.remove(h2));

    try std.testing.expectEqualStrings("alpha", table.get(h1).?);
    try std.testing.expectEqual(@as(?[]const u8, null), table.get(h2));
    try std.testing.expectEqualStrings("gamma", table.get(h3).?);
}

test "isValid" {
    var table = StringTable.init(std.testing.allocator);
    defer table.deinit();

    const handle = try table.intern("test");
    try std.testing.expect(table.isValid(handle));
    try std.testing.expect(!table.isValid(StringTable.null_handle));
    try std.testing.expect(!table.isValid(999));

    _ = table.remove(handle);
    try std.testing.expect(!table.isValid(handle));
}

test "re-intern after remove creates new handle" {
    var table = StringTable.init(std.testing.allocator);
    defer table.deinit();

    const h1 = try table.intern("reuse");
    _ = table.remove(h1);

    const h2 = try table.intern("reuse");
    try std.testing.expect(h1 != h2); // new slot, old one is dead
    try std.testing.expectEqualStrings("reuse", table.get(h2).?);
}

test "compact reclaims bytes" {
    var table = StringTable.init(std.testing.allocator);
    defer table.deinit();

    _ = try table.intern("keep");
    const h_remove = try table.intern("removeme");
    _ = try table.intern("also_keep");

    const bytes_before = table.totalStringBytes();
    _ = table.remove(h_remove);
    try table.compact();
    const bytes_after = table.totalStringBytes();

    // Should have reclaimed "removeme" (8 bytes)
    try std.testing.expect(bytes_after < bytes_before);
    try std.testing.expectEqual(bytes_before - 8, bytes_after);
}
