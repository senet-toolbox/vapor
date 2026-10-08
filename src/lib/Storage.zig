const Vapor = @import("Vapor.zig");
const Wasm = @import("WASM.zig");
const std = @import("std");

pub fn clearPersitantStorage() void {
    if (Vapor.isWasi) {
        Wasm.clearLocalStorageWasm();
    } else {}
}

pub fn store(key: []const u8, value: anytype) void {
    if (!Vapor.isWasi) return;
    switch (@typeInfo(@TypeOf(value))) {
        // Numbers and bools go through the string binding: localStorage holds
        // strings anyway, and the number binding takes a u32, so negative,
        // 64-bit and float values could not round-trip through it.
        .int, .comptime_int, .float, .comptime_float, .bool => {
            var buf: [64]u8 = undefined;
            const text = std.fmt.bufPrint(&buf, "{}", .{value}) catch |err| {
                Vapor.printlnErr("store: could not format '{s}': {any}", .{ key, err });
                return;
            };
            Wasm.setLocalStorageStringWasm(key.ptr, key.len, text.ptr, text.len);
        },
        .pointer => |ptr| {
            switch (ptr.size) {
                .slice => {
                    Wasm.setLocalStorageStringWasm(key.ptr, key.len, value.ptr, value.len);
                },
                else => {
                    Wasm.setLocalStorageStringWasm(key.ptr, key.len, value.ptr, value.len);
                },
            }
        },
        .@"enum" => {
            const string = @tagName(value);
            Wasm.setLocalStorageStringWasm(key.ptr, key.len, string.ptr, string.len);
        },
        else => {
            Vapor.printlnErr("Cannot store non string or int float types TYPE: {any}", .{@TypeOf(value)});
        },
    }
}

pub fn getStore(comptime T: type, key: []const u8) ?T {
    if (!Vapor.isWasi) return null;
    switch (T) {
        []const u8 => {
            const string = Wasm.getLocalStorageStringWasm(key.ptr, key.len) orelse return null;
            const value = std.mem.span(string);
            const handle = Vapor.storage_table.replaceOrAddStr(key, value) catch |err| {
                Vapor.printlnErr("getStore: could not intern '{s}': {any}", .{ key, err });
                return null;
            };
            const stored_value = Vapor.storage_table.getStr(handle) orelse return null;
            return stored_value;
        },
        else => switch (@typeInfo(T)) {
            // A missing key is null, not 0: the old u32 binding could not
            // tell "never stored" from "stored zero".
            .int, .float, .bool => {
                const string = Wasm.getLocalStorageStringWasm(key.ptr, key.len) orelse return null;
                return parseStored(T, std.mem.span(string));
            },
            else => if (@typeInfo(T) == .@"enum") {
                const string = Wasm.getLocalStorageStringWasm(key.ptr, key.len) orelse return null;
                const value = std.mem.span(string);
                const handle = Vapor.storage_table.replaceOrAddStr(key, value) catch |err| {
                    Vapor.printlnErr("getStore: could not intern '{s}': {any}", .{ key, err });
                    return null;
                };
                const stored_value = Vapor.storage_table.getStr(handle) orelse return null;
                return std.meta.stringToEnum(T, stored_value);
            } else {
                return null;
            },
        },
    }
}

/// Parses a localStorage value written by `store`. Anything else (a value
/// another script wrote, a type change between versions) reads as null.
pub fn parseStored(comptime T: type, text: []const u8) ?T {
    return switch (@typeInfo(T)) {
        .int => std.fmt.parseInt(T, text, 10) catch null,
        .float => std.fmt.parseFloat(T, text) catch null,
        .bool => if (std.mem.eql(u8, text, "true")) true else if (std.mem.eql(u8, text, "false")) false else null,
        else => @compileError("parseStored: unsupported type " ++ @typeName(T)),
    };
}

test parseStored {
    try std.testing.expectEqual(@as(?u32, 42), parseStored(u32, "42"));
    try std.testing.expectEqual(@as(?i64, -9_000_000_000), parseStored(i64, "-9000000000"));
    try std.testing.expectEqual(@as(?u8, null), parseStored(u8, "300"));
    try std.testing.expectEqual(@as(?f32, 2.5), parseStored(f32, "2.5"));
    try std.testing.expectEqual(@as(?bool, true), parseStored(bool, "true"));
    try std.testing.expectEqual(@as(?u32, null), parseStored(u32, "zig"));
}

pub fn setCookie(cookie: []const u8) void {
    if (!Vapor.isWasi) return;
    Wasm.setCookieWasm(cookie.ptr, cookie.len);
}

pub fn getCookies() []const u8 {
    const cookie = Wasm.getCookiesWasm();
    return std.mem.span(cookie);
}

pub fn getCookie(name: []const u8) ?[]const u8 {
    if (!Vapor.isWasi) return null;
    const cookie = Wasm.getCookieWasm(name.ptr, name.len);
    if (cookie == null) return null;
    return std.mem.span(cookie);
}
