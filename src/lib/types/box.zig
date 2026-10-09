const types = @import("../types.zig");

pub const Padding = packed struct {
    _top: u8 = 0,
    _bottom: u8 = 0,
    _left: u8 = 0,
    _right: u8 = 0,

    /// `size` pixels on every side.
    pub fn all(size: u8) Padding {
        return Padding{
            ._top = size,
            ._bottom = size,
            ._left = size,
            ._right = size,
        };
    }

    /// `size` pixels on top only.
    pub fn top(size: u8) Padding {
        return Padding{ ._top = size };
    }

    /// `size` pixels at the bottom only.
    pub fn bottom(size: u8) Padding {
        return Padding{ ._bottom = size };
    }

    /// `size` pixels on the left only.
    pub fn left(size: u8) Padding {
        return Padding{ ._left = size };
    }

    /// `size` pixels on the right only.
    pub fn right(size: u8) Padding {
        return Padding{ ._right = size };
    }

    /// Each side in pixels: top, bottom, left, right.
    pub fn tblr(t: u8, b: u8, l: u8, r: u8) Padding {
        return Padding{
            ._top = t,
            ._bottom = b,
            ._left = l,
            ._right = r,
        };
    }

    /// Top and bottom, in pixels.
    pub fn tb(t: u8, b: u8) Padding {
        return Padding{
            ._top = t,
            ._bottom = b,
        };
    }

    /// Left and right, in pixels.
    pub fn lr(l: u8, r: u8) Padding {
        return Padding{
            ._left = l,
            ._right = r,
        };
    }

    /// `size` pixels on the left and right.
    pub fn horizontal(size: u8) Padding {
        return Padding{
            ._left = size,
            ._right = size,
        };
    }

    /// `size` pixels on the top and bottom.
    pub fn vertical(size: u8) Padding {
        return Padding{
            ._top = size,
            ._bottom = size,
        };
    }

    /// `x` pixels on the left and right, `y` on the top and bottom.
    pub fn xy(x: u8, y: u8) Padding {
        return Padding{
            ._top = y,
            ._bottom = y,
            ._left = x,
            ._right = x,
        };
    }

    /// Top and left, in pixels.
    pub fn top_left(t: u8, l: u8) Padding {
        return Padding{
            ._top = t,
            ._left = l,
        };
    }

    /// Top and right, in pixels.
    pub fn top_right(t: u8, r: u8) Padding {
        return Padding{
            ._top = t,
            ._right = r,
        };
    }

    /// Bottom and left, in pixels.
    pub fn bottom_left(b: u8, l: u8) Padding {
        return Padding{
            ._bottom = b,
            ._left = l,
        };
    }

    /// Bottom and right, in pixels.
    pub fn bottom_right(b: u8, r: u8) Padding {
        return Padding{
            ._bottom = b,
            ._right = r,
        };
    }
};

pub const Margin = packed struct {
    top: i16 = 0,
    bottom: i16 = 0,
    left: i16 = 0,
    right: i16 = 0,
    /// `size` pixels on every side; negative pulls the element outward.
    pub fn all(size: i16) Margin {
        return Margin{
            .top = size,
            .bottom = size,
            .left = size,
            .right = size,
        };
    }
    /// Each side in pixels: top, bottom, left, right.
    pub fn tblr(top: i16, bottom: i16, left: i16, right: i16) Margin {
        return Margin{
            .top = top,
            .bottom = bottom,
            .left = left,
            .right = right,
        };
    }
    /// Top and bottom, in pixels.
    pub fn tb(top: i16, bottom: i16) Margin {
        return Margin{
            .top = top,
            .bottom = bottom,
        };
    }
    /// Bottom and right, in pixels.
    pub fn br(bottom: i16, right: i16) Margin {
        return Margin{
            .bottom = bottom,
            .right = right,
        };
    }
    /// Left and right, in pixels.
    pub fn lr(left: i16, right: i16) Margin {
        return Margin{
            .left = left,
            .right = right,
        };
    }
    /// Top only, in pixels.
    pub fn t(top: i16) Margin {
        return Margin{
            .top = top,
        };
    }
    /// Bottom only, in pixels.
    pub fn b(bottom: i16) Margin {
        return Margin{
            .bottom = bottom,
        };
    }
    /// Left only, in pixels.
    pub fn l(left: i16) Margin {
        return Margin{
            .left = left,
        };
    }
    /// Right only, in pixels.
    pub fn r(right: i16) Margin {
        return Margin{
            .right = right,
        };
    }

    /// `size` pixels on the top and bottom.
    pub fn vertical(size: i16) Margin {
        return Margin{
            .top = size,
            .bottom = size,
        };
    }

    /// `x` pixels on the left and right, `y` on the top and bottom.
    pub fn xy(x: i16, y: i16) Margin {
        return Margin{
            .top = y,
            .bottom = y,
            .left = x,
            .right = x,
        };
    }

    /// `size` pixels on the left and right.
    pub fn horizontal(size: i16) Margin {
        return Margin{
            .left = size,
            .right = size,
        };
    }
};

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
    pub fn none_x() Scroll {
        return .{ .x = .hidden };
    }

    /// Clips vertical overflow.
    pub fn none_y() Scroll {
        return .{ .y = .hidden };
    }
    /// Scrolls on both axes.
    pub fn scroll() Scroll {
        return .{ .x = .scroll, .y = .scroll };
    }

    /// Scrolls horizontally.
    pub fn scroll_x() Scroll {
        return .{ .x = .scroll };
    }

    /// Scrolls vertically.
    pub fn scroll_y() Scroll {
        return .{ .y = .scroll };
    }
};

pub const BorderRadius = packed struct {
    top_left: u16 = 0,
    top_right: u16 = 0,
    bottom_left: u16 = 0,
    bottom_right: u16 = 0,
    fn default() BorderRadius {
        return BorderRadius{
            .top_left = 0,
            .top_right = 0,
            .bottom_left = 0,
            .bottom_right = 0,
        };
    }
    /// `radius` pixels on every corner.
    pub fn all(radius: u16) BorderRadius {
        return BorderRadius{
            .top_left = radius,
            .top_right = radius,
            .bottom_left = radius,
            .bottom_right = radius,
        };
    }
    /// Each corner in pixels: top-left, top-right, bottom-left, bottom-right.
    pub fn specific(top_left: u16, top_right: u16, bottom_left: u16, bottom_right: u16) BorderRadius {
        return BorderRadius{
            .top_left = top_left,
            .top_right = top_right,
            .bottom_left = bottom_left,
            .bottom_right = bottom_right,
        };
    }
    /// The top-left and top-right corners; the bottom stays square.
    pub fn toplr(left: u16, right: u16) BorderRadius {
        return BorderRadius{
            .top_left = left,
            .top_right = right,
        };
    }

    /// `top_radius` on both top corners, `bottom_radius` on both bottom corners.
    pub fn top_bottom(top_radius: u16, bottom_radius: u16) BorderRadius {
        return BorderRadius{
            .top_left = top_radius,
            .top_right = top_radius,
            .bottom_left = bottom_radius,
            .bottom_right = bottom_radius,
        };
    }
    /// `radius` on both bottom corners; the top stays square.
    pub fn bottom(radius: u16) BorderRadius {
        return BorderRadius{
            .top_left = 0,
            .top_right = 0,
            .bottom_left = radius,
            .bottom_right = radius,
        };
    }
    /// `radius` on both top corners; the bottom stays square.
    pub fn top(radius: u16) BorderRadius {
        return BorderRadius{
            .top_left = radius,
            .top_right = radius,
            .bottom_left = 0,
            .bottom_right = 0,
        };
    }
    /// `left` on both left corners, `right` on both right corners.
    pub fn left_right(left: u16, right: u16) BorderRadius {
        return BorderRadius{
            .top_left = left,
            .top_right = right,
            .bottom_left = left,
            .bottom_right = right,
        };
    }
};

pub const Border = packed struct {
    _top: u8 = 0,
    _bottom: u8 = 0,
    _left: u8 = 0,
    _right: u8 = 0,
    pub const solid = Border{ ._top = 1, ._bottom = 1, ._left = 1, ._right = 1 };
    pub const none = Border{ ._top = 0, ._bottom = 0, ._left = 0, ._right = 0 };
    /// No border on any side. Same as `.none`.
    pub fn default() Border {
        return Border{
            ._top = 0,
            ._bottom = 0,
            ._left = 0,
            ._right = 0,
        };
    }
    /// `thickness` pixels on every side.
    pub fn all(thickness: u8) Border {
        return Border{
            ._top = thickness,
            ._bottom = thickness,
            ._left = thickness,
            ._right = thickness,
        };
    }
    /// Each side in pixels: top, bottom, left, right.
    pub fn tblr(top_thickness: u8, bottom_thickness: u8, left_thickness: u8, right_thickness: u8) Border {
        return Border{
            ._top = top_thickness,
            ._bottom = bottom_thickness,
            ._left = left_thickness,
            ._right = right_thickness,
        };
    }

    /// `thickness` pixels on the top and bottom.
    pub fn tb(thickness: u8) Border {
        return Border{
            ._top = thickness,
            ._bottom = thickness,
            ._left = 0,
            ._right = 0,
        };
    }
    /// `thickness` pixels on the left and right.
    pub fn lr(thickness: u8) Border {
        return Border{
            ._top = 0,
            ._bottom = 0,
            ._left = thickness,
            ._right = thickness,
        };
    }

    /// Bottom only, in pixels.
    pub fn bottom(thickness: u8) Border {
        return Border{
            ._top = 0,
            ._bottom = thickness,
            ._left = 0,
            ._right = 0,
        };
    }

    /// Top only, in pixels.
    pub fn top(thickness: u8) Border {
        return Border{
            ._top = thickness,
            ._bottom = 0,
            ._left = 0,
            ._right = 0,
        };
    }

    /// Left only, in pixels.
    pub fn left(thickness: u8) Border {
        return Border{
            ._top = 0,
            ._bottom = 0,
            ._left = thickness,
            ._right = 0,
        };
    }

    /// Right only, in pixels.
    pub fn right(thickness: u8) Border {
        return Border{
            ._top = 0,
            ._bottom = 0,
            ._left = 0,
            ._right = thickness,
        };
    }

    /// Same as `right`.
    pub fn r(thickness: u8) Border {
        return Border{
            ._top = 0,
            ._bottom = 0,
            ._left = 0,
            ._right = thickness,
        };
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

pub const BorderGrouped = struct {
    thickness: Border = .none,
    color: ?types.Color = null,
    radius: ?BorderRadius = null,
    style: BorderStyle = .solid,

    pub const none = BorderGrouped{ .thickness = .all(0) };

    /// Thickness, colour and corner radius.
    pub fn solid(thickness: Border, color: types.Color, radius: BorderRadius) BorderGrouped {
        return .{
            .thickness = thickness,
            .color = color,
            .radius = radius,
        };
    }

    /// Thickness and colour, with square corners.
    pub fn sharp(thickness: Border, color: types.Color) BorderGrouped {
        return .{
            .thickness = thickness,
            .color = color,
            .radius = .all(0),
        };
    }

    /// 1 pixel on every side, in `color`.
    pub fn simple(color: types.Color) BorderGrouped {
        return .{ .color = color, .thickness = .all(1) };
    }

    /// 1 pixel on every side, in `color`. Same as `simple`.
    pub fn thin(color: types.Color) BorderGrouped {
        return .{ .thickness = .all(1), .color = color };
    }

    /// 2 pixels on every side, in `color`.
    pub fn thick(color: types.Color) BorderGrouped {
        return .{ .thickness = .all(2), .color = color };
    }

    // Just thickness, use default color
    /// Only the thickness, in the default colour.
    pub fn width(thickness: Border) BorderGrouped {
        return .{ .thickness = thickness };
    }

    // Rounded variants (common radius values)
    /// 1 pixel in `color`, with corners of `radius`.
    pub fn round(color: types.Color, radius: BorderRadius) BorderGrouped {
        return .{ .color = color, .radius = radius, .thickness = .all(1) };
    }

    /// 1 pixel in `color`, with fully rounded ends.
    pub fn pill(color: types.Color) BorderGrouped {
        return .{ .color = color, .radius = .all(99), .thickness = .all(1) }; // Large radius for pill shape
    }

    // Side-specific shortcuts
    /// `thickness` pixels at the bottom, in `color`.
    pub fn bottom(thickness: u8, color: types.Color) BorderGrouped {
        return .{ .thickness = .bottom(thickness), .color = color };
    }

    /// `thickness` pixels on top, in `color`.
    pub fn top(thickness: u8, color: types.Color) BorderGrouped {
        return .{ .thickness = .top(thickness), .color = color };
    }

    /// `thickness` pixels on the left, in `color`.
    pub fn left(thickness: u8, color: types.Color) BorderGrouped {
        return .{ .thickness = .left(thickness), .color = color };
    }

    /// `thickness` pixels on the right, in `color`.
    pub fn right(thickness: u8, color: types.Color) BorderGrouped {
        return .{ .thickness = .right(thickness), .color = color };
    }

    /// Same as `left`.
    pub fn l(thickness: u8, color: types.Color) BorderGrouped {
        return .{ .thickness = .left(thickness), .color = color };
    }

    /// Same as `right`.
    pub fn r(thickness: u8, color: types.Color) BorderGrouped {
        return .{ .thickness = .right(thickness), .color = color };
    }

    /// Same as `bottom`.
    pub fn b(thickness: u8, color: types.Color) BorderGrouped {
        return .{ .thickness = .bottom(thickness), .color = color };
    }

    /// Same as `top`.
    pub fn t(thickness: u8, color: types.Color) BorderGrouped {
        return .{ .thickness = .top(thickness), .color = color };
    }

    /// 1 pixel on the top and bottom, in `color`.
    pub fn tb(color: types.Color) BorderGrouped {
        return .{ .thickness = .tb(1), .color = color };
    }

    /// 1 pixel on the left and right, in `color`.
    pub fn lr(color: types.Color) BorderGrouped {
        return .{ .thickness = .lr(1), .color = color };
    }
};
