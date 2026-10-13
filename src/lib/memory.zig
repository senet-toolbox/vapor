//! The memory API: `arena`, `dupe`, `fmtln`, and the `frame`, `view` and
//! `persist` namespaces for allocating with a given lifetime.

const Vapor = @import("vapor.zig");
const ArrayArena = @import("array.zig").Array;
const std = @import("std");
const utils = @import("utils.zig");

/// The allocator for the current render; same as `arena(.frame)`.
pub fn getFrameAllocator() std.mem.Allocator {
    return arena(.frame);
}

pub const ArenaType = enum {
    frame,
    view,
    persist,
};

pub const Arena = ArenaType;

/// The allocator for a lifetime. `.frame`: freed two renders later.
/// `.view`: freed when the app leaves the page on screen (after the page's
/// deinit runs), so allocate it from the page and drop pointers to it in the
/// deinit; state that must outlive a visit belongs in `.persist`.
/// `.persist`: freed only when you free it.
pub fn arena(arena_type: ArenaType) std.mem.Allocator {
    if (Vapor.generating) return Vapor.frame_arena.persistentAllocator();
    return switch (arena_type) {
        .frame => Vapor.frame_arena.frameAllocator(),
        .view => Vapor.frame_arena.viewAllocator(),
        .persist => Vapor.frame_arena.persistentAllocator(),
    };
}

/// An empty growable list whose memory comes from `arena_type`.
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
        Vapor.report.err("format: could not allocate: {any}", .{err});
        return "";
    };
    return buf;
}

/// Formats like `std.fmt` into memory from `arena_type`. Returns "" if out of
/// memory.
pub fn fmtArena(
    comptime fmt: []const u8,
    args: anytype,
    arena_type: ArenaType,
) []const u8 {
    const allocator = arena(arena_type);
    const buf = std.fmt.allocPrint(allocator, fmt, args) catch |err| {
        Vapor.report.err("format: could not allocate: {any}", .{err});
        return "";
    };
    return buf;
}

/// Copies `args` into memory from `allocator_type`. Returns "" if out of memory.
pub fn dupe(
    args: []const u8,
    allocator_type: ArenaType,
) []const u8 {
    const allocator = arena(allocator_type);
    const buf = allocator.dupe(u8, args) catch |err| {
        Vapor.report.err("format: could not allocate: {any}", .{err});
        return "";
    };
    return buf;
}

/// Interns `value` in vapor's string table, where style and anchor names live.
pub fn pin(value: []const u8) void {
    _ = Vapor.string_table.intern(value) catch |err| {
        Vapor.report.err("pin: could not intern, string stays unpinned: {any}", .{err});
    };
}

/// Removes `value` from vapor's string table. Its space comes back with
/// `compact`.
pub fn unpin(value: []const u8) void {
    const handle = Vapor.string_table.handleOf(value) orelse return;
    _ = Vapor.string_table.remove(handle);
}

/// Reclaims the space of strings removed with `unpin`. Invalidates every string
/// handle, so call it only between pages.
pub fn compact() void {
    Vapor.string_table.compact() catch |err| {
        Vapor.report.err("compact: string table left as-is: {any}", .{err});
    };
}

/// Copies a string into frame memory (valid until two renders later).
pub fn cloneFrame(
    value: anytype,
) []const u8 {
    const T = @TypeOf(value);
    if (T == []const u8) return fmtln("{s}", .{value});
    const allocator = arena(.frame);
    const memory: *@TypeOf(value) = allocator.create(T) catch |err| {
        Vapor.report.err("cloneFrame: could not allocate: {any}", .{err});
        return "";
    };
    memory.* = value;
    return memory.*;
}

pub const persist = struct {
    /// Copies `value` into memory that lasts for the life of the app (until you free it).
    pub fn dupe(value: []const u8) []const u8 {
        const _allocator = Vapor.arena(.persist);
        const buf = _allocator.dupe(u8, value) catch |err| {
            Vapor.report.err("format: could not allocate: {any}", .{err});
            return "";
        };
        return buf;
    }

    /// Frees memory from this arena.
    pub fn free(memory: anytype) void {
        const _allocator = Vapor.arena(.persist);
        _allocator.free(memory);
    }

    /// Allocates `size` items of `T` that last for the life of the app (until you free it).
    pub fn alloc(comptime T: type, size: usize) ![]T {
        return Vapor.arena(.persist).alloc(T, size) catch |err| {
            Vapor.report.err("format: could not allocate: {any}", .{err});
            return err;
        };
    }

    /// Formats like `std.fmt` into memory that lasts for the life of the app (until you free it).
    pub fn fmt(comptime _fmt: []const u8, args: anytype) []const u8 {
        const _allocator = Vapor.arena(.persist);
        const buf = std.fmt.allocPrint(_allocator, _fmt, args) catch |err| {
            Vapor.report.err("format: could not allocate: {any}", .{err});
            return "";
        };
        return buf;
    }

    /// An empty growable list whose memory lasts for the life of the app (until you free it).
    pub fn array(comptime T: type) ArrayArena(T) {
        return ArrayArena(T).init(.persist);
    }

    /// The allocator for memory that lasts for the life of the app (until you free it).
    pub fn arena() std.mem.Allocator {
        return Vapor.arena(.persist);
    }

    /// Joins `parts` with `separator` (`.{ "a", "b" }` and ", " give "a, b"); the result lasts for the life of the app (until you free it).
    pub fn join(parts: []const []const u8, separator: []const u8) []const u8 {
        const _allocator = Vapor.arena(.persist);
        return std.mem.join(_allocator, separator, parts) catch |err| {
            Vapor.report.err("join: could not allocate, returning empty. {any}", .{err});
            return "";
        };
    }

    /// Splits a copy of `str` on `delimiter`; the copy lasts for the life of the app (until you free it).
    pub fn split(str: []const u8, delimiter: []const u8) std.mem.SplitIterator(u8, .sequence) {
        const _allocator = Vapor.arena(.persist);
        var split_buffer = _allocator.alloc(u8, str.len) catch |err| {
            Vapor.report.err("split: could not allocate, returning empty. {any}", .{err});
            return std.mem.splitSequence(u8, "", delimiter);
        };
        @memcpy(split_buffer[0..], str);
        return std.mem.splitSequence(u8, split_buffer[0..], delimiter);
    }

    /// `str` repeated `count` times: `repeat("ha", 3)` is "hahaha".
    pub fn repeat(str: []const u8, count: usize) []const u8 {
        const _allocator = Vapor.arena(.persist);
        const list = _allocator.alloc([]const u8, count) catch |err| {
            Vapor.report.err("repeat: could not allocate, returning empty. {any}", .{err});
            return "";
        };
        @memset(list, str);
        return std.mem.join(_allocator, "", list) catch |err| {
            Vapor.report.err("repeat: could not allocate, returning empty. {any}", .{err});
            return "";
        };
    }

    /// Lowercase copy of `str` (ASCII).
    pub fn toLowerCase(str: []const u8) []const u8 {
        return utils.toLowerCase(str, .persist);
    }

    /// Uppercase copy of `str` (ASCII).
    pub fn toUpperCase(str: []const u8) []const u8 {
        return utils.toUpperCase(str, .persist);
    }

    /// Copy of `str` with its first letter uppercased.
    pub fn firstLetterToUpper(str: []const u8) []const u8 {
        return utils.firstLetterToUpper(str, .persist);
    }

    /// Whether `str` contains `needle`.
    pub fn contains(str: []const u8, needle: []const u8) bool {
        return utils.contains(str, needle);
    }

    /// Whether `str` starts with `prefix`.
    pub fn startsWith(str: []const u8, prefix: []const u8) bool {
        return utils.startsWith(str, prefix);
    }
};

pub const view = struct {
    /// Copies `value` into view memory (see `arena`).
    pub fn dupe(value: []const u8) []const u8 {
        const allocator = Vapor.arena(.view);
        const buf = allocator.dupe(u8, value) catch |err| {
            Vapor.report.err("format: could not allocate: {any}", .{err});
            return "";
        };
        return buf;
    }
    /// Formats like `std.fmt` into view memory (see `arena`).
    pub fn fmt(comptime _fmtln: []const u8, args: anytype) []const u8 {
        const allocator = Vapor.arena(.view);
        const buf = std.fmt.allocPrint(allocator, _fmtln, args) catch |err| {
            Vapor.report.err("format: could not allocate: {any}", .{err});
            return "";
        };
        return buf;
    }

    /// An empty `std.AutoHashMap` in view memory (see `arena`).
    pub fn HashMap(comptime K: type, comptime V: type) std.AutoHashMap(K, V) {
        return std.AutoHashMap(K, V).init(Vapor.view.arena());
    }

    /// An empty growable list in view memory (see `arena`).
    pub fn array(comptime T: type) ArrayArena(T) {
        return ArrayArena(T).init(.view);
    }

    /// The allocator for view memory (see `arena`).
    pub fn arena() std.mem.Allocator {
        return Vapor.arena(.view);
    }

    /// Lowercase copy of `str` (ASCII).
    pub fn toLowerCase(str: []const u8) []const u8 {
        return utils.toLowerCase(str, .view);
    }

    /// Uppercase copy of `str` (ASCII).
    pub fn toUpperCase(str: []const u8) []const u8 {
        return utils.toUpperCase(str, .view);
    }

    /// Copy of `str` with its first letter uppercased.
    pub fn firstLetterToUpper(str: []const u8) []const u8 {
        return utils.firstLetterToUpper(str, .view);
    }

    /// Whether `str` contains `needle`.
    pub fn contains(str: []const u8, needle: []const u8) bool {
        return utils.contains(str, needle);
    }

    /// Whether `str` starts with `prefix`.
    pub fn startsWith(str: []const u8, prefix: []const u8) bool {
        return utils.startsWith(str, prefix);
    }
};

pub const frame = struct {
    /// Copies `value` into memory that lasts for this render (freed two renders later).
    pub fn dupe(value: []const u8) []const u8 {
        const allocator = Vapor.arena(.frame);
        const buf = allocator.dupe(u8, value) catch |err| {
            Vapor.report.err("format: could not allocate: {any}", .{err});
            return "";
        };
        return buf;
    }
    /// Formats like `std.fmt` into memory that lasts for this render (freed two renders later).
    pub fn fmt(comptime _fmtln: []const u8, args: anytype) []const u8 {
        // _ = args;
        // return _fmtln;
        const allocator = Vapor.arena(.frame);
        const buf = std.fmt.allocPrint(allocator, _fmtln, args) catch |err| {
            Vapor.report.err("format: could not allocate: {any}", .{err});
            return "";
        };
        return buf;
    }

    /// Frees memory from this arena.
    pub fn free(memory: anytype) void {
        const _allocator = Vapor.arena(.frame);
        _allocator.free(memory);
    }

    /// Allocates `size` items of `T` that last for this render (freed two renders later).
    pub fn alloc(comptime T: type, size: usize) ![]T {
        return Vapor.arena(.frame).alloc(T, size) catch |err| {
            Vapor.report.err("format: could not allocate: {any}", .{err});
            return err;
        };
    }

    /// An empty `std.AutoHashMap` whose memory lasts for this render (freed two renders later).
    pub fn HashMap(comptime K: type, comptime V: type) std.AutoHashMap(K, V) {
        return std.AutoHashMap(K, V).init(Vapor.frame.arena());
    }

    /// An empty growable list whose memory lasts for this render (freed two renders later).
    pub fn array(comptime T: type) ArrayArena(T) {
        return ArrayArena(T).init(.frame);
    }

    /// The allocator for memory that lasts for this render (freed two renders later).
    pub fn arena() std.mem.Allocator {
        return Vapor.arena(.frame);
    }

    /// Joins `parts` with `separator` (`.{ "a", "b" }` and ", " give "a, b"); the result lasts for this render (freed two renders later).
    pub fn join(parts: []const []const u8, separator: []const u8) []const u8 {
        const allocator = Vapor.arena(.frame);
        return std.mem.join(allocator, separator, parts) catch |err| {
            Vapor.report.err("join: could not allocate, returning empty. {any}", .{err});
            return "";
        };
    }

    /// Splits a copy of `str` on `delimiter`; the copy lasts for this render (freed two renders later).
    pub fn split(str: []const u8, delimiter: []const u8) std.mem.SplitIterator(u8, .sequence) {
        return std.mem.splitSequence(u8, str, delimiter);
    }

    /// `str` repeated `count` times: `repeat("ha", 3)` is "hahaha".
    pub fn repeat(str: []const u8, count: usize) []const u8 {
        const allocator = Vapor.arena(.frame);
        const list = allocator.alloc([]const u8, count) catch |err| {
            Vapor.report.err("repeat: could not allocate, returning empty. {any}", .{err});
            return "";
        };
        @memset(list, str);
        return std.mem.join(allocator, "", list) catch |err| {
            Vapor.report.err("repeat: could not allocate, returning empty. {any}", .{err});
            return "";
        };
    }

    /// Lowercase copy of `str` (ASCII).
    pub fn toLowerCase(str: []const u8) []const u8 {
        return utils.toLowerCase(str, .frame);
    }

    /// Uppercase copy of `str` (ASCII).
    pub fn toUpperCase(str: []const u8) []const u8 {
        return utils.toUpperCase(str, .frame);
    }

    /// Copy of `str` with its first letter uppercased.
    pub fn firstLetterToUpper(str: []const u8) []const u8 {
        return utils.firstLetterToUpper(str, .frame);
    }

    /// Whether `str` contains `needle`.
    pub fn contains(str: []const u8, needle: []const u8) bool {
        return utils.contains(str, needle);
    }

    /// Whether `str` starts with `prefix`.
    pub fn startsWith(str: []const u8, prefix: []const u8) bool {
        return utils.startsWith(str, prefix);
    }
};
