const types = @import("../types.zig");

pub const Padding = packed struct {
    _top: u8 = 0,
    _bottom: u8 = 0,
    _left: u8 = 0,
    _right: u8 = 0,

    pub fn all(size: u8) Padding {
        return Padding{
            ._top = size,
            ._bottom = size,
            ._left = size,
            ._right = size,
        };
    }

    pub fn top(size: u8) Padding {
        return Padding{ ._top = size };
    }

    pub fn bottom(size: u8) Padding {
        return Padding{ ._bottom = size };
    }

    pub fn left(size: u8) Padding {
        return Padding{ ._left = size };
    }

    pub fn right(size: u8) Padding {
        return Padding{ ._right = size };
    }

    pub fn tblr(t: u8, b: u8, l: u8, r: u8) Padding {
        return Padding{
            ._top = t,
            ._bottom = b,
            ._left = l,
            ._right = r,
        };
    }

    pub fn tb(t: u8, b: u8) Padding {
        return Padding{
            ._top = t,
            ._bottom = b,
        };
    }

    pub fn lr(l: u8, r: u8) Padding {
        return Padding{
            ._left = l,
            ._right = r,
        };
    }

    pub fn horizontal(size: u8) Padding {
        return Padding{
            ._left = size,
            ._right = size,
        };
    }

    pub fn vertical(size: u8) Padding {
        return Padding{
            ._top = size,
            ._bottom = size,
        };
    }

    pub fn xy(x: u8, y: u8) Padding {
        return Padding{
            ._top = y,
            ._bottom = y,
            ._left = x,
            ._right = x,
        };
    }

    pub fn top_left(t: u8, l: u8) Padding {
        return Padding{
            ._top = t,
            ._left = l,
        };
    }

    pub fn top_right(t: u8, r: u8) Padding {
        return Padding{
            ._top = t,
            ._right = r,
        };
    }

    pub fn bottom_left(b: u8, l: u8) Padding {
        return Padding{
            ._bottom = b,
            ._left = l,
        };
    }

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
    pub fn all(size: i16) Margin {
        return Margin{
            .top = size,
            .bottom = size,
            .left = size,
            .right = size,
        };
    }
    pub fn tblr(top: i16, bottom: i16, left: i16, right: i16) Margin {
        return Margin{
            .top = top,
            .bottom = bottom,
            .left = left,
            .right = right,
        };
    }
    pub fn tb(top: i16, bottom: i16) Margin {
        return Margin{
            .top = top,
            .bottom = bottom,
        };
    }
    pub fn br(bottom: i16, right: i16) Margin {
        return Margin{
            .bottom = bottom,
            .right = right,
        };
    }
    pub fn lr(left: i16, right: i16) Margin {
        return Margin{
            .left = left,
            .right = right,
        };
    }
    pub fn t(top: i16) Margin {
        return Margin{
            .top = top,
        };
    }
    pub fn b(bottom: i16) Margin {
        return Margin{
            .bottom = bottom,
        };
    }
    pub fn l(left: i16) Margin {
        return Margin{
            .left = left,
        };
    }
    pub fn r(right: i16) Margin {
        return Margin{
            .right = right,
        };
    }

    pub fn vertical(size: i16) Margin {
        return Margin{
            .top = size,
            .bottom = size,
        };
    }

    pub fn xy(x: u8, y: u8) Margin {
        return Margin{
            .top = y,
            .bottom = y,
            .left = x,
            .right = x,
        };
    }

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

    pub fn none() Scroll {
        return .{ .x = .hidden, .y = .hidden };
    }

    pub fn none_x() Scroll {
        return .{ .x = .hidden };
    }

    pub fn none_y() Scroll {
        return .{ .y = .hidden };
    }
    pub fn scroll() Scroll {
        return .{ .x = .scroll, .y = .scroll };
    }

    pub fn scroll_x() Scroll {
        return .{ .x = .scroll };
    }

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
    pub fn all(radius: u16) BorderRadius {
        return BorderRadius{
            .top_left = radius,
            .top_right = radius,
            .bottom_left = radius,
            .bottom_right = radius,
        };
    }
    pub fn specific(top_left: u16, top_right: u16, bottom_left: u16, bottom_right: u16) BorderRadius {
        return BorderRadius{
            .top_left = top_left,
            .top_right = top_right,
            .bottom_left = bottom_left,
            .bottom_right = bottom_right,
        };
    }
    pub fn toplr(left: u16, right: u16) BorderRadius {
        return BorderRadius{
            .top_left = left,
            .top_right = right,
        };
    }

    pub fn top_bottom(top_radius: u16, bottom_radius: u16) BorderRadius {
        return BorderRadius{
            .top_left = top_radius,
            .top_right = top_radius,
            .bottom_left = bottom_radius,
            .bottom_right = bottom_radius,
        };
    }
    pub fn bottom(radius: u16) BorderRadius {
        return BorderRadius{
            .top_left = 0,
            .top_right = 0,
            .bottom_left = radius,
            .bottom_right = radius,
        };
    }
    pub fn top(radius: u16) BorderRadius {
        return BorderRadius{
            .top_left = radius,
            .top_right = radius,
            .bottom_left = 0,
            .bottom_right = 0,
        };
    }
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
    pub fn default() Border {
        return Border{
            ._top = 0,
            ._bottom = 0,
            ._left = 0,
            ._right = 0,
        };
    }
    pub fn all(thickness: u8) Border {
        return Border{
            ._top = thickness,
            ._bottom = thickness,
            ._left = thickness,
            ._right = thickness,
        };
    }
    pub fn tblr(top_thickness: u8, bottom_thickness: u8, left_thickness: u8, right_thickness: u8) Border {
        return Border{
            ._top = top_thickness,
            ._bottom = bottom_thickness,
            ._left = left_thickness,
            ._right = right_thickness,
        };
    }

    pub fn tb(thickness: u8) Border {
        return Border{
            ._top = thickness,
            ._bottom = thickness,
            ._left = 0,
            ._right = 0,
        };
    }
    pub fn lr(thickness: u8) Border {
        return Border{
            ._top = 0,
            ._bottom = 0,
            ._left = thickness,
            ._right = thickness,
        };
    }

    pub fn bottom(thickness: u8) Border {
        return Border{
            ._top = 0,
            ._bottom = thickness,
            ._left = 0,
            ._right = 0,
        };
    }

    pub fn top(thickness: u8) Border {
        return Border{
            ._top = thickness,
            ._bottom = 0,
            ._left = 0,
            ._right = 0,
        };
    }

    pub fn left(thickness: u8) Border {
        return Border{
            ._top = 0,
            ._bottom = 0,
            ._left = thickness,
            ._right = 0,
        };
    }

    pub fn right(thickness: u8) Border {
        return Border{
            ._top = 0,
            ._bottom = 0,
            ._left = 0,
            ._right = thickness,
        };
    }

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

    pub fn solid(thickness: Border, color: types.Color, radius: BorderRadius) BorderGrouped {
        return .{
            .thickness = thickness,
            .color = color,
            .radius = radius,
        };
    }

    pub fn sharp(thickness: Border, color: types.Color) BorderGrouped {
        return .{
            .thickness = thickness,
            .color = color,
            .radius = .all(0),
        };
    }

    pub fn simple(color: types.Color) BorderGrouped {
        return .{ .color = color, .thickness = .all(1) };
    }

    pub fn thin(color: types.Color) BorderGrouped {
        return .{ .thickness = .all(1), .color = color };
    }

    pub fn thick(color: types.Color) BorderGrouped {
        return .{ .thickness = .all(2), .color = color };
    }

    // Just thickness, use default color
    pub fn width(thickness: Border) BorderGrouped {
        return .{ .thickness = thickness };
    }

    // Rounded variants (common radius values)
    pub fn round(color: types.Color, radius: BorderRadius) BorderGrouped {
        return .{ .color = color, .radius = radius, .thickness = .all(1) };
    }

    pub fn pill(color: types.Color) BorderGrouped {
        return .{ .color = color, .radius = .all(99), .thickness = .all(1) }; // Large radius for pill shape
    }

    // Side-specific shortcuts
    pub fn bottom(thickness: u8, color: types.Color) BorderGrouped {
        return .{ .thickness = .bottom(thickness), .color = color };
    }

    pub fn top(thickness: u8, color: types.Color) BorderGrouped {
        return .{ .thickness = .top(thickness), .color = color };
    }

    pub fn left(thickness: u8, color: types.Color) BorderGrouped {
        return .{ .thickness = .left(thickness), .color = color };
    }

    pub fn right(thickness: u8, color: types.Color) BorderGrouped {
        return .{ .thickness = .right(thickness), .color = color };
    }

    pub fn l(thickness: u8, color: types.Color) BorderGrouped {
        return .{ .thickness = .left(thickness), .color = color };
    }

    pub fn r(thickness: u8, color: types.Color) BorderGrouped {
        return .{ .thickness = .right(thickness), .color = color };
    }

    pub fn b(thickness: u8, color: types.Color) BorderGrouped {
        return .{ .thickness = .bottom(thickness), .color = color };
    }

    pub fn t(thickness: u8, color: types.Color) BorderGrouped {
        return .{ .thickness = .top(thickness), .color = color };
    }

    pub fn tb(color: types.Color) BorderGrouped {
        return .{ .thickness = .tb(1), .color = color };
    }

    pub fn lr(color: types.Color) BorderGrouped {
        return .{ .thickness = .lr(1), .color = color };
    }
};
