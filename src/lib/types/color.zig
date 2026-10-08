const types = @import("../types.zig");
const ThemeTokens = @import("theme").ThemeTokens;
const Vapor = @import("../Vapor.zig");

pub const Thematic = packed struct {
    token: ThemeTokens,
    alpha: f32 = -1,
    darken: bool = false,
};

pub const Rgba = packed struct { r: u8 = 0, g: u8 = 0, b: u8 = 0, a: f32 = 0 };

pub const Color = union(enum) {
    Literal: Rgba, // A hardcoded, specific color
    Thematic: Thematic, // A token name, like "primaryText" or "accentColor"

    pub const transparent = Color{ .Literal = .{ .r = 0, .g = 0, .b = 0, .a = 0 } };
    pub const white = Color{ .Literal = .{ .r = 255, .g = 255, .b = 255, .a = 1 } };
    pub const black = Color{ .Literal = .{ .r = 0, .g = 0, .b = 0, .a = 1 } };
    pub const grey = Color{ .Literal = .{ .r = 128, .g = 128, .b = 128, .a = 1 } };
    pub const red = Color{ .Literal = .{ .r = 255, .g = 0, .b = 0, .a = 1 } };
    pub const green = Color{ .Literal = .{ .r = 0, .g = 255, .b = 0, .a = 1 } };
    pub const blue = Color{ .Literal = .{ .r = 0, .g = 0, .b = 255, .a = 1 } };
    pub const yellow = Color{ .Literal = .{ .r = 255, .g = 255, .b = 0, .a = 1 } };
    pub const cyan = Color{ .Literal = .{ .r = 0, .g = 255, .b = 255, .a = 1 } };
    pub const magenta = Color{ .Literal = .{ .r = 255, .g = 0, .b = 255, .a = 1 } };
    pub const vapor_blue = Color.hex("#4400FF");
    pub fn palette(thematic: ThemeTokens) Color {
        return .{ .Thematic = .{ .token = thematic } };
    }
    pub fn hex(hex_str: []const u8) Color {
        const rgba_arr = Vapor.hexToRgba(hex_str);
        return .{ .Literal = .{
            .r = @as(u8, @intFromFloat(rgba_arr[0])),
            .g = @as(u8, @intFromFloat(rgba_arr[1])),
            .b = @as(u8, @intFromFloat(rgba_arr[2])),
            .a = rgba_arr[3],
        } };
    }

    // // Function to lighten a hex color string by a percentage and return Color struct
    pub fn lighten(hex_str: []const u8, percentage: f32) Color {
        if (percentage < 0.0 or percentage > 100.0) {
            @panic("Percentage must be between 0 and 100");
        }

        const rgba_arr = Vapor.hexToRgba(hex_str);
        const factor = percentage / 100.0;

        return .{
            .Literal = .{
                // hexToRgba already returns [4]f32, so the channels only need
                // narrowing back to u8 on the way out.
                .r = @intFromFloat(rgba_arr[0] + (255.0 - rgba_arr[0]) * factor),
                .g = @intFromFloat(rgba_arr[1] + (255.0 - rgba_arr[1]) * factor),
                .b = @intFromFloat(rgba_arr[2] + (255.0 - rgba_arr[2]) * factor),
                .a = rgba_arr[3], // Keep alpha unchanged
            },
        };
    }
    pub fn rgba(r: u8, g: u8, b: u8, a: f32) Color {
        return .{ .Literal = .{
            .r = r,
            .g = g,
            .b = b,
            .a = a,
        } };
    }
    pub fn rgb(r: u8, g: u8, b: u8) Color {
        return .{ .Literal = .{
            .r = r,
            .g = g,
            .b = b,
            .a = 1,
        } };
    }
    pub fn transparentize(color: Color, alpha: f32) Color {
        if (color == .Thematic) return Color{ .Thematic = .{
            .token = color.Thematic.token,
            .alpha = alpha,
        } };
        const r = color.Literal.r;
        const g = color.Literal.g;
        const b = color.Literal.b;
        return .{ .Literal = .{
            .r = r,
            .g = g,
            .b = b,
            .a = alpha,
        } };
    }

    pub fn transparentizeHex(color: Color, alpha: f32) Color {
        if (color == .Thematic) return Color{ .Thematic = .{
            .token = color.Thematic.token,
            .alpha = alpha,
        } };
        const r = color.Literal.r;
        const g = color.Literal.g;
        const b = color.Literal.b;
        return .{ .Literal = .{
            .r = r,
            .g = g,
            .b = b,
            .a = alpha,
        } };
    }

    pub fn toCss(self: Color, writer: anytype) !void {
        switch (self) {
            .Thematic => |thematic| {
                if (thematic.alpha > -1) {
                    try writer.write("rgba(");
                    try writer.write("var(--");
                    try writer.write(@tagName(thematic.token));
                    try writer.write("), ");
                    try writer.writeF32(thematic.alpha);
                    try writer.writeByte(')');
                } else {
                    try writer.write("rgb(var(--");
                    try writer.write(@tagName(thematic.token));
                    try writer.write("))");
                }
            },
            .Literal => |_rgba| {
                if (_rgba.a == 1) {
                    try writer.write("rgb(");
                    try writer.writeU8Num(_rgba.r);
                    try writer.writeByte(',');
                    try writer.writeU8Num(_rgba.g);
                    try writer.writeByte(',');
                    try writer.writeU8Num(_rgba.b);
                    try writer.writeByte(')');
                } else {
                    try writer.write("rgba(");
                    try writer.writeU8Num(_rgba.r);
                    try writer.writeByte(',');
                    try writer.writeU8Num(_rgba.g);
                    try writer.writeByte(',');
                    try writer.writeU8Num(_rgba.b);
                    try writer.writeByte(',');
                    try writer.writeF32(_rgba.a);
                    try writer.writeByte(')');
                }
            },
        }
    }
    pub fn darken(color: Color, percentage: f32) Color {
        switch (color) {
            .Thematic => |thematic| {
                return .{ .Thematic = .{
                    .token = thematic.token,
                    .alpha = percentage,
                    .darken = true,
                } };
            },
            else => return color,
        }
    }
};

pub const ColorProp = enum(u8) {
    default,
    text_color,
    background_color,
    border_color,
    fill_color,
    stroke_color,
};

pub const ColorMix = struct {
    color: ?Color = null,
    color_prop: ColorProp = .default,
    percentage: f32 = 0,
    pub fn darken(color_prop: ColorProp, color: ?Color, percentage: f32) ColorMix {
        return .{ .color_prop = color_prop, .color = color, .percentage = percentage };
    }
};

pub const PackedColorMix = packed struct {
    color: PackedColor = .{},
    color_prop: ColorProp = .default,
    percentage: f32 = 0,
};

pub const PackedColor = packed struct {
    has_token: bool = false,
    has_color: bool = false,
    color: Rgba = undefined,
    token: Thematic = undefined,
};
