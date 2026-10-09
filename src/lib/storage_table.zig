const std = @import("std");
const ArrayList = std.array_list.Managed;

pub const StorageTable = struct {
    const Self = @This();

    const Entry = struct {
        key: []const u8, // We store the key so we can free it later
        data: []const u8, // The actual content
    };

    index_map: std.AutoHashMap(u32, u32), // Hash -> Index in entries
    entries: ArrayList(Entry),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .index_map = std.AutoHashMap(u32, u32).init(allocator),
            .entries = ArrayList(Entry).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.entries.items) |entry| {
            self.allocator.free(entry.key);
            self.allocator.free(entry.data);
        }
        self.index_map.deinit();
        self.entries.deinit();
    }

    pub fn replaceOrAddStr(self: *Self, key_str: []const u8, new_content: []const u8) !u32 {
        const h = std.hash.XxHash32.hash(0, key_str);

        if (self.index_map.get(h)) |index| {
            const entry = &self.entries.items[index];

            // 1. If content is identical, skip allocation
            if (std.mem.eql(u8, entry.data, new_content)) return index;

            // 2. Free OLD content (only works if using GPA, not Arena)
            self.allocator.free(entry.data);

            // 3. Store NEW content
            entry.data = try self.allocator.dupe(u8, new_content);
            return index;
        }

        // --- NEW ENTRY LOGIC ---

        // We must dupe the KEY because the JS side might reuse that memory
        const owned_key = try self.allocator.dupe(u8, key_str);
        const owned_data = try self.allocator.dupe(u8, new_content);

        const new_idx = @as(u32, @intCast(self.entries.items.len));
        try self.entries.append(.{
            .key = owned_key,
            .data = owned_data,
        });
        try self.index_map.put(h, new_idx);

        return new_idx;
    }

    pub fn getStr(self: Self, handle: u32) ?[]const u8 {
        if (handle >= self.entries.items.len) return null;
        return self.entries.items[handle].data;
    }
};
