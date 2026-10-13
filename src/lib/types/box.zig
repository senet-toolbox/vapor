//! Box model values: `Padding`, `Margin`, `BorderThickness`, `BorderRadius`,
//! `Border`, `Scroll`.
//!
//! `Padding`, `Margin` and `BorderThickness` share one shape: a value per
//! side in pixels. Name the sides you set with a literal
//! (`.{ .left = 12, .top = 4 }`); `all`, `xy`, `vertical` and `horizontal`
//! cover the same value on several sides. On a builder, `.pl(12)`, `.mt(8)`,
//! `.padX(16)` and friends change one side and keep the rest.

const types = @import("../types.zig");

/// A value per side, in pixels. `tag` keeps the three uses distinct types.
fn Sides(comptime T: type, comptime tag: @EnumLiteral()) type {
    _ = tag;
    return packed struct {
        top: T = 0,
        bottom: T = 0,
        left: T = 0,
        right: T = 0,

        const Self = @This();

        /// Zero on every side.
        pub const none: Self = .{};

        /// `size` on every side.
        pub fn all(size: T) Self {
            return .{ .top = size, .bottom = size, .left = size, .right = size };
        }

        /// `x` on the left and right, `y` on the top and bottom.
        pub fn xy(x: T, y: T) Self {
            return .{ .top = y, .bottom = y, .left = x, .right = x };
        }

        /// `size` on the top and bottom.
        pub fn vertical(size: T) Self {
            return .{ .top = size, .bottom = size };
        }

        /// `size` on the left and right.
        pub fn horizontal(size: T) Self {
            return .{ .left = size, .right = size };
        }
    };
}

/// Space inside the element's border, per side.
pub const Padding = Sides(u8, .padding);

/// Space outside the element's border, per side; negative pulls the element
/// outward.
pub const Margin = Sides(i16, .margin);

/// Border thickness per side, in pixels. `Border.thickness` takes one.
pub const BorderThickness = Sides(u8, .border_thickness);

pub const Overflow = enum(u8) {
    default,
    scroll,
    hidden,
};

pub const Scroll = packed struct {
    x: Overflow = .default,
    y: Overflow = .default,

    /// Clips overflow on both axes.
    pub fn none() Scroll {
        return .{ .x = .hidden, .y = .hidden };
    }

    /// Clips horizontal overflow.
    pub fn noneX() Scroll {
        return .{ .x = .hidden };
    }

    /// Clips vertical overflow.
    pub fn noneY() Scroll {
        return .{ .y = .hidden };
    }

    /// Scrolls on both axes.
    pub fn scroll() Scroll {
        return .{ .x = .scroll, .y = .scroll };
    }

    /// Scrolls horizontally.
    pub fn scrollX() Scroll {
        return .{ .x = .scroll };
    }

    /// Scrolls vertically.
    pub fn scrollY() Scroll {
        return .{ .y = .scroll };
    }
};

pub const BorderRadius = packed struct {
    top_left: u16 = 0,
    top_right: u16 = 0,
    bottom_left: u16 = 0,
    bottom_right: u16 = 0,

    /// `radius` pixels on every corner.
    pub fn all(radius: u16) BorderRadius {
        return .{ .top_left = radius, .top_right = radius, .bottom_left = radius, .bottom_right = radius };
    }

    /// Each corner in pixels: top-left, top-right, bottom-left, bottom-right.
    pub fn specific(top_left: u16, top_right: u16, bottom_left: u16, bottom_right: u16) BorderRadius {
        return .{ .top_left = top_left, .top_right = top_right, .bottom_left = bottom_left, .bottom_right = bottom_right };
    }

    /// `radius` on both top corners; the bottom stays square.
    pub fn top(radius: u16) BorderRadius {
        return .{ .top_left = radius, .top_right = radius };
    }

    /// `radius` on both bottom corners; the top stays square.
    pub fn bottom(radius: u16) BorderRadius {
        return .{ .bottom_left = radius, .bottom_right = radius };
    }

    /// `radius` on both left corners; the right stays square.
    pub fn left(radius: u16) BorderRadius {
        return .{ .top_left = radius, .bottom_left = radius };
    }

    /// `radius` on both right corners; the left stays square.
    pub fn right(radius: u16) BorderRadius {
        return .{ .top_right = radius, .bottom_right = radius };
    }

    /// `top_radius` on both top corners, `bottom_radius` on both bottom corners.
    pub fn topBottom(top_radius: u16, bottom_radius: u16) BorderRadius {
        return .{ .top_left = top_radius, .top_right = top_radius, .bottom_left = bottom_radius, .bottom_right = bottom_radius };
    }

    /// `left_radius` on both left corners, `right_radius` on both right corners.
    pub fn leftRight(left_radius: u16, right_radius: u16) BorderRadius {
        return .{ .top_left = left_radius, .bottom_left = left_radius, .top_right = right_radius, .bottom_right = right_radius };
    }
};

pub const Outline = enum(u8) {
    default,
    none, // No outline
    auto, // Default outline (typically browser-specific)
    dotted, // Dotted outline
    dashed, // Dashed outline
    solid, // Solid outline
    double, // Two parallel solid lines
    groove, // 3D grooved effect
    ridge, // 3D ridged effect
    inset, // 3D inset effect
    outset, // 3D outset effect
    inherit, // Inherits from the parent element
    initial, // Resets to the default value
    revert, // Reverts to the inherited value if explicitly changed
    unset, // Resets to inherited or initial value
};

pub const BorderStyle = enum(u8) {
    default,
    solid,
    dashed,
};

/// An element's border: thickness per side, colour, corner radius and line
/// style. `.border(.thin(.palette(.border)))`, or a literal:
/// `.{ .thickness = .{ .bottom = 1 }, .color = .hex("#E4E4E4") }`.
pub const Border = struct {
    thickness: ?BorderThickness = null,
    color: ?types.Color = null,
    radius: ?BorderRadius = null,
    /// Solid when a thickness is given and this is left null.
    style: ?BorderStyle = null,

    /// No border: zero thickness on every side.
    pub const none = Border{ .thickness = .none };

    /// Thickness, colour and corner radius.
    pub fn solid(thickness: BorderThickness, color: types.Color, radius: BorderRadius) Border {
        return .{ .thickness = thickness, .color = color, .radius = radius };
    }

    /// Thickness and colour, with square corners.
    pub fn sharp(thickness: BorderThickness, color: types.Color) Border {
        return .{ .thickness = thickness, .color = color, .radius = .all(0) };
    }

    /// 1 pixel on every side, in `color`.
    pub fn thin(color: types.Color) Border {
        return .{ .thickness = .all(1), .color = color };
    }

    /// 2 pixels on every side, in `color`.
    pub fn thick(color: types.Color) Border {
        return .{ .thickness = .all(2), .color = color };
    }

    /// Only the thickness, in the default colour.
    pub fn width(thickness: BorderThickness) Border {
        return .{ .thickness = thickness };
    }

    /// 1 pixel in `color`, with corners of `radius`.
    pub fn round(color: types.Color, radius: BorderRadius) Border {
        return .{ .color = color, .radius = radius, .thickness = .all(1) };
    }

    /// 1 pixel in `color`, with fully rounded ends.
    pub fn pill(color: types.Color) Border {
        return .{ .color = color, .radius = .all(99), .thickness = .all(1) };
    }

    /// `thickness` pixels on top, in `color`.
    pub fn top(thickness: u8, color: types.Color) Border {
        return .{ .thickness = .{ .top = thickness }, .color = color };
    }

    /// `thickness` pixels at the bottom, in `color`.
    pub fn bottom(thickness: u8, color: types.Color) Border {
        return .{ .thickness = .{ .bottom = thickness }, .color = color };
    }

    /// `thickness` pixels on the left, in `color`.
    pub fn left(thickness: u8, color: types.Color) Border {
        return .{ .thickness = .{ .left = thickness }, .color = color };
    }

    /// `thickness` pixels on the right, in `color`.
    pub fn right(thickness: u8, color: types.Color) Border {
        return .{ .thickness = .{ .right = thickness }, .color = color };
    }

    /// `thickness` pixels on the top and bottom, in `color`.
    pub fn vertical(thickness: u8, color: types.Color) Border {
        return .{ .thickness = .vertical(thickness), .color = color };
    }

    /// `thickness` pixels on the left and right, in `color`.
    pub fn horizontal(thickness: u8, color: types.Color) Border {
        return .{ .thickness = .horizontal(thickness), .color = color };
    }
};
