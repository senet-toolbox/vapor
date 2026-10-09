const std = @import("std");
const Vapor = @import("../vapor.zig");

const json = std.json;

const Json = @This();

/// Parses json
pub fn parse(comptime T: type, json_str: []const u8, arena_type: Vapor.ArenaType) !T {
    const parsed_value = json.parseFromSlice(T, Vapor.arena(arena_type), json_str, .{
        .allocate = .alloc_always,
        .ignore_unknown_fields = true,
    }) catch |err| {
        Vapor.println("Error could not parse json {any}\n", .{err});
        return error.MalformedJson;
    };

    return parsed_value.value;
}
