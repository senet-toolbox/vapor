//! Generates the ids (keys) the reconciler uses to match nodes across renders.

const std = @import("std");
const Vapor = @import("vapor.zig");
const UINode = @import("UITree.zig").UINode;
const ElementType = @import("types.zig").ElementType;
const Writer = @import("Writer.zig");
const utils = @import("utils.zig");

var buf_128: [128]u8 = undefined;
var writer: Writer = undefined;
pub const KeyGenerator = struct {
    /// Prepares the shared key buffer.
    pub fn initWriter() void {
        writer.init(&buf_128);
    }

    /// A class name from a style hash and a prefix, e.g. "vis-a8Kx3".
    pub fn generateHashKey(
        buf: []u8,
        hash: u32,
        tag: []const u8,
    ) []const u8 {
        var buf_short: [6]u8 = undefined;
        const class_name = utils.hashToBase62(hash, &buf_short);

        writer.reset();
        writer.write(tag) catch {};
        writer.writeByte('_') catch {};
        writer.write(class_name) catch {};
        const key = writer.buffer[0..writer.pos];
        @memcpy(buf[0..key.len], key);
        return buf[0..key.len];
    }

    /// A node's generated id from its type, parent id, depth and index among its
    /// siblings. Position-based, so a moved node gets a new id.
    pub fn generateKey(
        uuid_buf: []u8,
        elem_type: ElementType,
        parent_key: []const u8,
        depth: usize,
        index: usize,
    ) []const u8 {
        var hasher = std.hash.XxHash32.init(0);
        const tag_name = @tagName(elem_type);
        hasher.update(tag_name);
        hasher.update(parent_key);
        const depth_fixed: u32 = @intCast(depth);
        const index_fixed: u32 = @intCast(index);
        hasher.update(std.mem.asBytes(&depth_fixed));
        hasher.update(std.mem.asBytes(&index_fixed));
        const hash_val = hasher.final();

        // 2. Direct Write to Output Buffer
        // Prefix: 4 chars of tag + '_'
        const prefix_len = @min(4, tag_name.len);
        @memcpy(uuid_buf[0..prefix_len], tag_name[0..prefix_len]);
        uuid_buf[prefix_len] = '_';

        // 3. Optimized Base62 Write
        // We pass a slice of the output buffer directly to the hasher
        const base62_len = utils.hashToBufferBase62(hash_val, uuid_buf[prefix_len + 1 ..]);

        // 4. Final Suffix
        const final_pos = prefix_len + 1 + base62_len;
        @memcpy(uuid_buf[final_pos .. final_pos + 3], "-gk");
        return uuid_buf[0 .. final_pos + 3];
    }
};
