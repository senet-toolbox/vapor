const std = @import("std");
const UINode = @import("UITree.zig").UINode;
const Vapor = @import("Vapor.zig");
const Color = @import("types.zig").Color;
var current_label_len: usize = 0;
pub export fn getAriaLabel(node_ptr: ?*UINode) ?[*]const u8 {
    if (node_ptr == null) {
        return null;
    }
    if (node_ptr.?.aria_label) |label| {
        current_label_len = label.len;
        return label.ptr;
    }
    return null;
}
pub export fn getAriaLabelLen() usize {
    return current_label_len;
}

pub fn isDesktop() bool {
    return !isMobile();
}

pub fn isMobile() bool {
    if (!Vapor.isWasi) return false;
    if (Vapor.browser_width < 786) {
        return true;
    } else {
        return false;
    }
}

pub fn hashKey(key: []const u8) u32 {
    return std.hash.XxHash32.hash(0, key);
}

pub fn hash(value: []const u8) u32 {
    return std.hash.XxHash32.hash(0, value);
}

const base62_chars = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";

pub fn hashToBufferBase62(hash_value: u32, out: []u8) usize {
    var h = hash_value;
    var i: usize = 0;
    if (h == 0) {
        out[0] = '0';
        return 1;
    }
    while (h > 0 and i < 6) : (i += 1) {
        out[i] = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"[h % 62];
        h /= 62;
    }
    return i;
}

pub fn hashToBase62(hash_value: u32, buf: *[6]u8) []const u8 {
    var h = hash_value;
    var i: usize = 0;
    while (h > 0 and i < 6) : (i += 1) {
        buf[i] = base62_chars[@intCast(h % 62)];
        h /= 62;
    }
    return buf[0..@max(i, 1)];
}

const any = *anyopaque;
pub fn cast(comptime T: type, opaque_ptr: any) T {
    return @ptrCast(@alignCast(opaque_ptr));
}

pub fn getUnderlyingType(comptime T: type) type {
    return switch (@typeInfo(T)) {
        .optional => std.meta.Child(T),
        else => T,
    };
}

pub fn getUnderlyingValue(comptime T: type, comptime OT: type, v: OT) T {
    return switch (@typeInfo(OT)) {
        .optional => v.?,
        else => v,
    };
}

// Trim whitespace
pub fn trim(str: []const u8) []const u8 {
    return std.mem.trim(u8, str, " \t\n\r");
}

// Check contains / startsWith / endsWith
pub fn contains(haystack: []const u8, needle: []const u8) bool {
    return std.mem.indexOf(u8, haystack, needle) != null;
}

pub fn startsWith(str: []const u8, prefix: []const u8) bool {
    return std.mem.startsWith(u8, str, prefix);
}

// Clamp a number
pub fn clamp(val: anytype, min_val: anytype, max_val: anytype) @TypeOf(val) {
    return @max(min_val, @min(max_val, val));
}

// Linear interpolation — great for animations
pub fn lerp(a: f64, b: f64, t: f64) f64 {
    return a + (b - a) * clamp(t, 0.0, 1.0);
}

pub fn toLowerCase(str: []const u8, arena_type: Vapor.ArenaType) []const u8 {
    return std.ascii.allocLowerString(Vapor.arena(arena_type), str) catch return str;
}

pub fn toUpperCase(str: []const u8, arena_type: Vapor.ArenaType) []const u8 {
    return std.ascii.allocUpperString(Vapor.arena(arena_type), str) catch return str;
}

pub fn firstLetterToUpper(str: []const u8, arena_type: Vapor.ArenaType) []const u8 {
    const capital = std.ascii.allocUpperString(Vapor.allocator_global, str[0..1]) catch return str;
    defer Vapor.allocator_global.free(capital);
    return std.fmt.allocPrint(Vapor.arena(arena_type), "{s}{s}", .{ capital, str[1..] }) catch return str;
}

pub fn stringReplace(str: []const u8, needle: []const u8, replacement: []const u8, arena_type: Vapor.ArenaType) []const u8 {
    const size = std.mem.replacementSize(u8, str, needle, replacement);
    const buf = Vapor.arena(arena_type).alloc(u8, size) catch return str;
    _ = std.mem.replace(u8, str, needle, replacement, buf);
    return buf;
}

pub fn stringify(value: anytype, arena_type: Vapor.ArenaType) ![]const u8 {
    var writer = std.Io.Writer.Allocating.init(Vapor.arena(arena_type));
    try std.json.Stringify.value(value, .{ .emit_null_optional_fields = true, .escape_unicode = true }, &writer.writer);
    const payload = writer.written();
    return payload;
}

pub fn formatJson(input: []const u8) []const u8 {
    var result = std.array_list.Managed(u8).init(Vapor.arena(.persist));
    var indent_level: usize = 0;
    const indent_str = "  ";
    var in_string = false;
    var escape = false;
    var i: usize = 0;

    while (i < input.len) : (i += 1) {
        const c = input[i];

        if (escape) {
            result.append(c) catch return input;
            escape = false;
            continue;
        }

        if (c == '\\' and in_string) {
            result.append(c) catch return input;
            escape = true;
            continue;
        }

        if (c == '"') {
            in_string = !in_string;
            result.append(c) catch return input;
            continue;
        }

        if (in_string) {
            result.append(c) catch return input;
            continue;
        }

        // Skip existing whitespace outside strings
        if (c == ' ' or c == '\t' or c == '\n' or c == '\r') continue;

        switch (c) {
            '{', '[' => {
                result.append(c) catch return input;
                // Peek ahead: if the matching close is next (empty object/array), keep compact
                const next = skipWhitespace(input, i + 1);
                const close: u8 = if (c == '{') '}' else ']';
                if (next < input.len and input[next] == close) {
                    result.append(close) catch return input;
                    i = next;
                } else {
                    indent_level += 1;
                    result.append('\n') catch return input;
                    appendIndent(&result, indent_level, indent_str);
                }
            },
            '}', ']' => {
                indent_level -|= 1;
                result.append('\n') catch return input;
                appendIndent(&result, indent_level, indent_str);
                result.append(c) catch return input;
            },
            ':' => {
                result.appendSlice(": ") catch return input;
            },
            ',' => {
                result.append(',') catch return input;
                result.append('\n') catch return input;
                appendIndent(&result, indent_level, indent_str);
            },
            else => {
                result.append(c) catch return input;
            },
        }
    }

    return result.toOwnedSlice() catch return input;
}

fn skipWhitespace(input: []const u8, start: usize) usize {
    var pos = start;
    while (pos < input.len and (input[pos] == ' ' or input[pos] == '\t' or input[pos] == '\n' or input[pos] == '\r')) : (pos += 1) {}
    return pos;
}

fn appendIndent(result: *std.array_list.Managed(u8), level: usize, indent_str: []const u8) void {
    for (0..level) |_| {
        // Losing indentation only affects how the JSON looks.
        result.appendSlice(indent_str) catch return;
    }
}

// /// The idea is to get parent ptr recursively
// pub fn getParent(comptime TargetType: type, comptime field: []const u8, field_ptr: *FT) type {
//     @fieldParentPtr(field, field_ptr: *T)
// }

fn isJsonSerializableImpl(comptime T: type, comptime depth: usize) bool {
    if (depth > 32) return false;

    const info = @typeInfo(T);

    return switch (info) {
        .bool, .int, .float, .comptime_int, .comptime_float, .null => true,
        .void => true,

        .pointer => |ptr| {
            if (ptr.size == .slice and ptr.child == u8) return true;
            return false;
        },

        .array => |arr| isJsonSerializableImpl(arr.child, depth + 1),

        .optional => |opt| isJsonSerializableImpl(opt.child, depth + 1),

        .@"enum" => true,

        .@"union" => |u| {
            if (u.tag_type == null) return false;
            inline for (u.fields) |field| {
                if (field.type != void and !isJsonSerializableImpl(field.type, depth + 1)) {
                    return false;
                }
            }
            return true;
        },

        .@"struct" => |s| {
            inline for (s.fields) |field| {
                if (!isJsonSerializableImpl(field.type, depth + 1)) {
                    return false;
                }
            }
            return true;
        },

        else => false,
    };
}

const SerializeConfig = struct {
    max_array_len: usize = 16,
    max_string_len: usize = 256,
    max_depth: usize = 8,
};

pub fn serializeArgs(allocator: std.mem.Allocator, value: anytype, config: SerializeConfig) ![]const u8 {
    var buf = Vapor.Array(u8).init(allocator);
    errdefer buf.deinit();
    try serializeValue(buf.writer(), value, config, 0);
    return buf.toOwnedSlice();
}

fn serializeValue(writer: anytype, value: anytype, config: SerializeConfig, depth: usize) !void {
    if (depth > config.max_depth) {
        try writer.writeAll("\"<max depth>\"");
        return;
    }

    const T = @TypeOf(value);
    const info = @typeInfo(T);

    switch (info) {
        .bool => try writer.writeAll(if (value) "true" else "false"),

        .int, .comptime_int, .float, .comptime_float => try writer.print("{d}", .{value}),

        .null => try writer.writeAll("null"),

        .void => try writer.writeAll("null"),

        .pointer => |ptr| {
            if (ptr.size == .slice and ptr.child == u8) {
                // String - truncate if needed
                try writer.writeByte('"');
                const len = @min(value.len, config.max_string_len);
                for (value[0..len]) |c| {
                    switch (c) {
                        '"' => try writer.writeAll("\\\""),
                        '\\' => try writer.writeAll("\\\\"),
                        '\n' => try writer.writeAll("\\n"),
                        '\r' => try writer.writeAll("\\r"),
                        '\t' => try writer.writeAll("\\t"),
                        else => {
                            if (c < 0x20) {
                                try std.fmt.format(writer, "\\u{x:0>4}", .{c});
                            } else {
                                try writer.writeByte(c);
                            }
                        },
                    }
                }
                if (value.len > config.max_string_len) {
                    try std.fmt.format(writer, "...<truncated {d} chars>", .{value.len - config.max_string_len});
                }
                try writer.writeByte('"');
            } else if (@typeInfo(ptr.child) == .int or @typeInfo(ptr.child) == .float) {
                try writer.print("{d}", .{value.*});
            } else {
                try writer.writeAll("\"<pointer>\"");
            }
        },

        .array => |arr| {
            try writer.writeByte('[');
            const len = @min(arr.len, config.max_array_len);
            for (0..len) |i| {
                if (i > 0) try writer.writeByte(',');
                try serializeValue(writer, value[i], config, depth + 1);
            }
            if (arr.len > config.max_array_len) {
                try std.fmt.format(writer, ",\"...<{d} more>\"", .{arr.len - config.max_array_len});
            }
            try writer.writeByte(']');
        },

        .optional => {
            if (value) |v| {
                try serializeValue(writer, v, config, depth + 1);
            } else {
                try writer.writeAll("null");
            }
        },

        .@"enum" => {
            try writer.writeByte('"');
            try writer.writeAll(@tagName(value));
            try writer.writeByte('"');
        },

        .@"union" => |u| {
            if (u.tag_type == null) {
                try writer.writeAll("\"<untagged union>\"");
                return;
            }
            try writer.writeAll("{\"");
            try writer.writeAll(@tagName(value));
            try writer.writeAll("\":");
            inline for (u.fields) |field| {
                if (std.mem.eql(u8, @tagName(value), field.name)) {
                    if (field.type == void) {
                        try writer.writeAll("null");
                    } else {
                        try serializeValue(writer, @field(value, field.name), config, depth + 1);
                    }
                }
            }
            try writer.writeByte('}');
        },

        .@"struct" => |s| {
            if (s.is_tuple) {
                try writer.writeByte('[');
                inline for (s.fields, 0..) |field, i| {
                    if (i > 0) try writer.writeByte(',');
                    try serializeValue(writer, @field(value, field.name), config, depth + 1);
                }
                try writer.writeByte(']');
            } else {
                try writer.writeByte('{');
                var first = true;
                inline for (s.fields) |field| {
                    if (!first) try writer.writeByte(',');
                    first = false;
                    try writer.writeByte('"');
                    try writer.writeAll(field.name);
                    try writer.writeAll("\":");
                    try serializeValue(writer, @field(value, field.name), config, depth + 1);
                }
                try writer.writeByte('}');
            }
        },

        else => try writer.writeAll("\"<unsupported>\""),
    }
}
