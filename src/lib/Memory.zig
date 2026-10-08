const Vapor = @import("Vapor.zig");
const ArrayArena = @import("Array.zig").Array;
const std = @import("std");
const utils = @import("utils.zig");

pub fn getFrameAllocator() std.mem.Allocator {
    return arena(.frame);
}

pub const ArenaType = enum {
    frame,
    view,
    persist,
    request,
};

pub const Arena = ArenaType;

pub fn arena(arena_type: ArenaType) std.mem.Allocator {
    if (Vapor.generating) return Vapor.frame_arena.persistentAllocator();
    return switch (arena_type) {
        .frame => Vapor.frame_arena.frameAllocator(),
        .view => Vapor.frame_arena.viewAllocator(),
        .persist => Vapor.frame_arena.persistentAllocator(),
        .request => Vapor.frame_arena.requestAllocator(),
    };
}

pub fn array(comptime T: type, arena_type: ArenaType) Array(T) {
    var array_list: std.array_list.Managed(T) = undefined;
    const allocator = arena(arena_type);
    array_list = std.array_list.Managed(T).init(allocator);
    return array_list;
}

pub const Array = std.array_list.Managed;

/// fmtln is a wrapper around std.fmt.allocPrint that allocates memory from the frame allocator
/// this means that this slice is deallocated on each frame
/// this is useful for formatting ids passed into the style struct
pub fn fmtln(
    comptime fmt: []const u8,
    args: anytype,
) []const u8 {
    const allocator = arena(.frame);
    const buf = std.fmt.allocPrint(allocator, fmt, args) catch |err| {
        Vapor.println("Formatting, Error Could not format argument alloc Error details: {any}\n", .{err});
        return "";
    };
    return buf;
}

pub fn fmtArena(
    comptime fmt: []const u8,
    args: anytype,
    arena_type: ArenaType,
) []const u8 {
    const allocator = arena(arena_type);
    const buf = std.fmt.allocPrint(allocator, fmt, args) catch |err| {
        Vapor.println("Formatting, Error Could not format argument alloc Error details: {any}\n", .{err});
        return "";
    };
    return buf;
}

pub fn dupe(
    args: []const u8,
    allocator_type: ArenaType,
) []const u8 {
    const allocator = arena(allocator_type);
    const buf = allocator.dupe(u8, args) catch |err| {
        Vapor.println("Formatting, Error Could not format argument alloc Error details: {any}\n", .{err});
        return "";
    };
    return buf;
}

pub fn pin(value: []const u8) void {
    _ = Vapor.string_table.intern(value) catch |err| {
        Vapor.printlnErr("pin: could not intern, string stays unpinned: {any}", .{err});
    };
}

pub fn unpin(value: []const u8) void {
    const handle = Vapor.string_table.handleOf(value) orelse return;
    _ = Vapor.string_table.remove(handle);
}

pub fn compact() void {
    Vapor.string_table.compact() catch |err| {
        Vapor.printlnErr("compact: string table left as-is: {any}", .{err});
    };
}

pub fn cloneFrame(
    value: anytype,
) []const u8 {
    const T = @TypeOf(value);
    if (T == []const u8) return fmtln("{s}", .{value});
    const allocator = arena(.frame);
    const memory: *@TypeOf(value) = allocator.create(T) catch |err| {
        Vapor.printlnErr("cloneFrame: could not allocate: {any}", .{err});
        return "";
    };
    memory.* = value;
    return memory.*;
}

pub const persist = struct {
    pub fn dupe(value: []const u8) []const u8 {
        const _allocator = Vapor.arena(.persist);
        const buf = _allocator.dupe(u8, value) catch |err| {
            Vapor.println("Formatting, Error Could not format argument alloc Error details: {any}\n", .{err});
            return "";
        };
        return buf;
    }

    pub fn free(memory: anytype) void {
        const _allocator = Vapor.arena(.persist);
        _allocator.free(memory);
    }

    pub fn alloc(comptime T: type, size: usize) ![]T {
        return Vapor.arena(.persist).alloc(T, size) catch |err| {
            Vapor.println("Formatting, Error Could not format argument alloc Error details: {any}\n", .{err});
            return err;
        };
    }

    pub fn fmt(comptime _fmt: []const u8, args: anytype) []const u8 {
        const _allocator = Vapor.arena(.persist);
        const buf = std.fmt.allocPrint(_allocator, _fmt, args) catch |err| {
            Vapor.println("Formatting, Error Could not format argument alloc Error details: {any}\n", .{err});
            return "";
        };
        return buf;
    }

    pub fn array(comptime T: type) ArrayArena(T) {
        return ArrayArena(T).init(.persist);
    }

    pub fn arena() std.mem.Allocator {
        return Vapor.arena(.persist);
    }

    pub fn allocator() std.mem.Allocator {
        return Vapor.arena(.persist);
    }

    pub fn Array(comptime T: type) ArrayArena(T) {
        return ArrayArena(T).init(.persist);
    }

    // Join slices: &.{"a", "b", "c"} with ", " -> "a, b, c"
    pub fn join(parts: []const []const u8, separator: []const u8) []const u8 {
        const _allocator = Vapor.arena(.persist);
        return std.mem.join(_allocator, separator, parts) catch |err| {
            Vapor.println("join: could not allocate, returning empty. {any}\n", .{err});
            return "";
        };
    }

    // Split string into slice of slices
    pub fn split(str: []const u8, delimiter: []const u8) std.mem.SplitIterator(u8, .sequence) {
        const _allocator = Vapor.arena(.persist);
        var split_buffer = _allocator.alloc(u8, str.len) catch |err| {
            Vapor.println("split: could not allocate, returning empty. {any}\n", .{err});
            return std.mem.splitSequence(u8, "", delimiter);
        };
        @memcpy(split_buffer[0..], str);
        return std.mem.splitSequence(u8, split_buffer[0..], delimiter);
    }

    // Repeat: repeat("ha", 3) -> "hahaha"
    pub fn repeat(str: []const u8, count: usize) []const u8 {
        const _allocator = Vapor.arena(.persist);
        const list = _allocator.alloc([]const u8, count) catch |err| {
            Vapor.println("repeat: could not allocate, returning empty. {any}\n", .{err});
            return "";
        };
        @memset(list, str);
        return std.mem.join(_allocator, "", list) catch |err| {
            Vapor.println("repeat: could not allocate, returning empty. {any}\n", .{err});
            return "";
        };
    }

    pub fn toLowerCase(str: []const u8) []const u8 {
        return utils.toLowerCase(str, .persist);
    }

    pub fn toUpperCase(str: []const u8) []const u8 {
        return utils.toUpperCase(str, .persist);
    }

    pub fn firstLetterToUpper(str: []const u8) []const u8 {
        return utils.firstLetterToUpper(str, .persist);
    }

    pub fn contains(str: []const u8, needle: []const u8) bool {
        return utils.contains(str, needle);
    }

    pub fn startsWith(str: []const u8, prefix: []const u8) bool {
        return utils.startsWith(str, prefix);
    }
};

pub const view = struct {
    pub fn dupe(value: []const u8) []const u8 {
        const allocator = Vapor.arena(.view);
        const buf = allocator.dupe(u8, value) catch |err| {
            Vapor.println("Formatting, Error Could not format argument alloc Error details: {any}\n", .{err});
            return "";
        };
        return buf;
    }
    pub fn fmt(comptime _fmtln: []const u8, args: anytype) []const u8 {
        const allocator = Vapor.arena(.view);
        const buf = std.fmt.allocPrint(allocator, _fmtln, args) catch |err| {
            Vapor.println("Formatting, Error Could not format argument alloc Error details: {any}\n", .{err});
            return "";
        };
        return buf;
    }

    pub fn HashMap(comptime K: type, comptime V: type) std.AutoHashMap(K, V) {
        return std.AutoHashMap(K, V).init(Vapor.view.arena());
    }

    pub fn array(comptime T: type) ArrayArena(T) {
        return ArrayArena(T).init(.view);
    }

    pub fn Array(comptime T: type) ArrayArena(T) {
        return ArrayArena(T).init(.view);
    }

    pub fn arena() std.mem.Allocator {
        return Vapor.arena(.view);
    }

    pub fn toLowerCase(str: []const u8) []const u8 {
        return utils.toLowerCase(str, .view);
    }

    pub fn toUpperCase(str: []const u8) []const u8 {
        return utils.toUpperCase(str, .view);
    }

    pub fn firstLetterToUpper(str: []const u8) []const u8 {
        return utils.firstLetterToUpper(str, .view);
    }

    pub fn contains(str: []const u8, needle: []const u8) bool {
        return utils.contains(str, needle);
    }

    pub fn startsWith(str: []const u8, prefix: []const u8) bool {
        return utils.startsWith(str, prefix);
    }
};

pub const frame = struct {
    pub fn dupe(value: []const u8) []const u8 {
        const allocator = Vapor.arena(.frame);
        const buf = allocator.dupe(u8, value) catch |err| {
            Vapor.println("Formatting, Error Could not format argument alloc Error details: {any}\n", .{err});
            return "";
        };
        return buf;
    }
    pub fn fmt(comptime _fmtln: []const u8, args: anytype) []const u8 {
        // _ = args;
        // return _fmtln;
        const allocator = Vapor.arena(.frame);
        const buf = std.fmt.allocPrint(allocator, _fmtln, args) catch |err| {
            Vapor.println("Formatting, Error Could not format argument alloc Error details: {any}\n", .{err});
            return "";
        };
        return buf;
    }

    pub fn free(memory: anytype) void {
        const _allocator = Vapor.arena(.frame);
        _allocator.free(memory);
    }

    pub fn alloc(comptime T: type, size: usize) ![]T {
        return Vapor.arena(.frame).alloc(T, size) catch |err| {
            Vapor.println("Formatting, Error Could not format argument alloc Error details: {any}\n", .{err});
            return err;
        };
    }

    pub fn HashMap(comptime K: type, comptime V: type) std.AutoHashMap(K, V) {
        return std.AutoHashMap(K, V).init(Vapor.frame.arena());
    }

    pub fn array(comptime T: type) ArrayArena(T) {
        return ArrayArena(T).init(.frame);
    }

    pub fn Array(comptime T: type) ArrayArena(T) {
        return ArrayArena(T).init(.frame);
    }

    pub fn arena() std.mem.Allocator {
        return Vapor.arena(.frame);
    }

    // Join slices: &.{"a", "b", "c"} with ", " -> "a, b, c"
    pub fn join(parts: []const []const u8, separator: []const u8) []const u8 {
        const allocator = Vapor.arena(.frame);
        return std.mem.join(allocator, separator, parts) catch |err| {
            Vapor.println("join: could not allocate, returning empty. {any}\n", .{err});
            return "";
        };
    }

    // Split string into slice of slices
    pub fn split(str: []const u8, delimiter: []const u8) std.mem.SplitIterator(u8, .sequence) {
        return std.mem.splitSequence(u8, str, delimiter);
    }

    // Repeat: repeat("ha", 3) -> "hahaha"
    pub fn repeat(str: []const u8, count: usize) []const u8 {
        const allocator = Vapor.arena(.frame);
        const list = allocator.alloc([]const u8, count) catch |err| {
            Vapor.println("repeat: could not allocate, returning empty. {any}\n", .{err});
            return "";
        };
        @memset(list, str);
        return std.mem.join(allocator, "", list) catch |err| {
            Vapor.println("repeat: could not allocate, returning empty. {any}\n", .{err});
            return "";
        };
    }

    pub fn toLowerCase(str: []const u8) []const u8 {
        return utils.toLowerCase(str, .frame);
    }

    pub fn toUpperCase(str: []const u8) []const u8 {
        return utils.toUpperCase(str, .frame);
    }

    pub fn firstLetterToUpper(str: []const u8) []const u8 {
        return utils.firstLetterToUpper(str, .frame);
    }

    pub fn contains(str: []const u8, needle: []const u8) bool {
        return utils.contains(str, needle);
    }

    pub fn startsWith(str: []const u8, prefix: []const u8) bool {
        return utils.startsWith(str, prefix);
    }
};
