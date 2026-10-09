const types = @import("../types.zig");

// Represents a single background image source and its properties.
pub const Image = struct {
    url: []const u8,
    // TODO: Add other CSS properties like repeat, size, position
    // repeat: enum { repeat, no_repeat, repeat_x, repeat_y } = .repeat,
    // size: union(enum) { auto, cover, contain, explicit: struct { w: f32, h: f32 } } = .auto,
};

// Represents a generated grid pattern.
pub const Grid = struct {
    size: u8 = 0,
    color: types.Color = .transparent,
    thickness: u8 = 1,
};

pub const Dot = struct {
    radius: f16 = 0,
    spacing: u8 = 0,
    color: types.Color = .transparent,
};

pub const GradientDirection = packed struct {
    type: types.DirectionType = .none,
    angle: f32 = 0,
    pub const to_top = GradientDirection{ .type = .to_top };
    pub const to_bottom = GradientDirection{ .type = .to_bottom };
    pub const to_left = GradientDirection{ .type = .to_left };
    pub const to_right = GradientDirection{ .type = .to_right };
    pub const to_top_left = GradientDirection{ .type = .to_top_left };
    pub const to_top_right = GradientDirection{ .type = .to_top_right };
    pub fn deg(value: f32) GradientDirection {
        return .{ .angle = value, .type = .angle };
    }
};

pub const GradientType = enum(u8) {
    none,
    linear,
    radial,
};

pub const Lines = struct {
    direction: LinesDirection,
    color: types.Color,
    thickness: u8 = 1,
    spacing: u8 = 10,
};

pub const LinesDirection = enum(u8) {
    horizontal,
    vertical,
    diagonal_up,
    diagonal_down,
};

// A BackgroundLayer can be one of several mutually exclusive types,
// like an image or a generated pattern. This is a perfect use for a union.
pub const BackgroundLayer = union(enum) {
    Image: Image,
    Grid: Grid,
    Dot: Dot,
    Gradient: Gradient,
    Lines: Lines,

    /// Creates a background with a grid pattern on top of a transparent color.
    pub fn grid(size: u8, thickness: u8, color: types.Color) BackgroundLayer {
        return .{
            .Grid = .{
                .size = size,
                .thickness = thickness,
                .color = color,
            },
        };
    }

    pub fn dot(radius: f16, spacing: u8, color: types.Color) BackgroundLayer {
        return .{
            .Dot = .{
                .radius = radius,
                .spacing = spacing,
                .color = color,
            },
        };
    }

    pub fn gradient(gradient_type: GradientType, dir: GradientDirection, colors: []const types.Color) BackgroundLayer {
        return .{
            .Gradient = .{
                .type = gradient_type,
                .direction = dir,
                .colors = colors,
            },
        };
    }

    pub fn line(thickness: u8, spacing: u8, dir: LinesDirection, color: types.Color) BackgroundLayer {
        return .{
            .Lines = .{
                .thickness = thickness,
                .spacing = spacing,
                .direction = dir,
                .color = color,
            },
        };
    }
};

pub const BackgroundClip = enum(u8) {
    none,
    borderBox,
    paddingBox,
    contentBox,

    pub fn toCss(self: BackgroundClip) []const u8 {
        return switch (self) {
            .none => "border-box",
            .borderBox => "border-box",
            .paddingBox => "padding-box",
            .contentBox => "content-box",
        };
    }
};

pub const Gradient = struct {
    type: GradientType,
    direction: GradientDirection,
    colors: []const types.Color,
    clip: BackgroundClip = .borderBox, // NEW: default to border-box
};
