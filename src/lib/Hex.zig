const std = @import("std");

// Make sure this function is not evaluated at compile time
/// Parses a CSS hex colour: `#rgb`, `#rgba`, `#rrggbb` or `#rrggbbaa`.
/// Returns 0-255 channels and alpha in 0-1. Anything else is opaque black,
/// as before; previously only `#rrggbb` was understood, so `#fff` was black
/// and alpha digits were ignored.
pub fn hexToRgba(hex_str: []const u8) [4]f32 {
    const black = [4]f32{ 0, 0, 0, 1 };
    if (hex_str.len < 1 or hex_str[0] != '#') return black;
    const digits = hex_str[1..];

    var channels = [4]u8{ 0, 0, 0, 255 };
    switch (digits.len) {
        3, 4 => for (digits, 0..) |c, i| {
            const v = charToHex(c) catch return black;
            channels[i] = v * 17; // 0xf -> 0xff
        },
        6, 8 => for (0..digits.len / 2) |i| {
            channels[i] = parseHexByte(digits[i * 2 ..][0..2]) catch return black;
        },
        else => return black,
    }
    return .{
        @floatFromInt(channels[0]),
        @floatFromInt(channels[1]),
        @floatFromInt(channels[2]),
        @as(f32, @floatFromInt(channels[3])) / 255.0,
    };
}

test hexToRgba {
    const eq = std.testing.expectEqual;
    try eq([4]f32{ 5, 55, 148, 1 }, hexToRgba("#053794"));
    try eq([4]f32{ 255, 255, 255, 1 }, hexToRgba("#fff"));
    try eq([4]f32{ 0, 0, 0, 0.4 }, hexToRgba("#0006"));
    try eq([4]f32{ 255, 0, 0, 0.5019608 }, hexToRgba("#ff000080"));
    try eq([4]f32{ 0, 0, 0, 1 }, hexToRgba("#12345")); // invalid length
    try eq([4]f32{ 0, 0, 0, 1 }, hexToRgba("#zzzzzz")); // invalid digit
    try eq([4]f32{ 0, 0, 0, 1 }, hexToRgba("fff")); // no '#'
}

pub fn parseHexByte(hex: []const u8) !u8 {
    if (hex.len != 2) return error.InvalidLength;

    const high = try charToHex(hex[0]);
    const low = try charToHex(hex[1]);

    return (high << 4) | low;
}

pub fn charToHex(c: u8) !u8 {
    return switch (c) {
        '0'...'9' => c - '0',
        'a'...'f' => c - 'a' + 10,
        'A'...'F' => c - 'A' + 10,
        else => error.InvalidCharacter,
    };
}
