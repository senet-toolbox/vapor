//! TextFieldBuilder methods for layout and visual style.

const TextFieldMod = @import("../text_field.zig");
const Self = TextFieldMod.TextFieldBuilder;
const std = @import("std");
const types = @import("../types.zig");
const Vapor = @import("../vapor.zig");
const Color = types.Color;

/// Truncates overflowing text with "…". Text elements only; ignored (with a
/// warning) elsewhere.
pub fn ellipsis(self: *const Self, value: types.Ellipsis) Self {
    if (self._elem_type != .Text) {
        Vapor.printWarn("Ellipsis can only be used on Text, not {any}", .{self._elem_type});
        return self.*;
    }
    var new_self: Self = self.*;
    var visual = new_self._visual orelse types.Visual{};
    visual.ellipsis = value;
    new_self._visual = visual;
    return new_self;
}

/// Overflow behaviour on each axis, e.g. `.scroll(.{ .y = .scroll })`.
pub fn scroll(self: *const Self, scroll_type: types.Scroll) Self {
    var new_self: Self = self.*;
    new_self._scroll = scroll_type;
    return new_self;
}

/// Font weight: 100 to 900.
pub fn fontWeight(self: *const Self, value: u16) Self {
    var n = self.*;
    var v = n._visual orelse types.Visual{};
    v.font_weight = value;
    n._visual = v;
    return n;
}

/// Text colour.
pub fn textColor(self: *const Self, color: ?Color) Self {
    var n = self.*;
    var v = n._visual orelse types.Visual{};
    v.text_color = color;
    n._visual = v;
    return n;
}

/// Font size in pixels.
pub fn fontSize(self: *const Self, font_size: u8) Self {
    var new_self: Self = self.*;
    var visual = new_self._visual orelse types.Visual{};
    visual.font_size = font_size;
    new_self._visual = visual;
    return new_self;
}

/// CSS font family, e.g. `"Inter, sans-serif"`.
pub fn fontFamily(self: *const Self, font_family: []const u8) Self {
    var new_self: Self = self.*;
    new_self._font_family = font_family;
    return new_self;
}

/// Plays the registered animation named `animation_tag` when the element first
/// appears. `null` leaves it unchanged.
pub fn animationEnter(self: *const Self, animation_tag: ?[]const u8) Self {
    if (animation_tag) |_animation| {
        var new_self: Self = self.*;
        new_self._animation_enter = _animation;
        return new_self;
    }
    return self.*;
}

/// Plays the registered animation named `animation_tag` (see `Vapor.Animation`).
/// `null` leaves it unchanged.
pub fn animation(self: *const Self, animation_tag: ?[]const u8) Self {
    if (animation_tag) |_animation| {
        var new_self: Self = self.*;
        var visual = new_self._visual orelse types.Visual{};
        visual.animation = _animation;
        new_self._visual = visual;
        return new_self;
    }
    return self.*;
}

/// Plays the registered animation named `animation_tag` before the element is
/// removed; removal waits for it to finish.
pub fn animationExit(self: *const Self, animation_tag: ?[]const u8) Self {
    var new_self: Self = self.*;
    new_self._animation_exit = animation_tag;
    return new_self;
}

/// Styles for interaction states: hover, focus and focus-within.
pub fn interaction(self: *const Self, interactive: types.Interactive) Self {
    var new_self: Self = self.*;
    new_self._interactive = interactive;
    return new_self;
}

/// How whitespace and line breaks in the text are handled (CSS `white-space`).
pub fn whiteSpace(self: *const Self, value: types.WhiteSpace) Self {
    var n = self.*;
    var v = n._visual orelse types.Visual{};
    v.white_space = value;
    n._visual = v;
    return n;
}

/// This function takes a const pointer to a Style Struct, and returns the body function callback
/// This function is static, so any styles added via chaining methods will not be applied
/// Use baseStyle to keep all chained additions
pub fn style(self: *const Self, style_ptr: *const Vapor.Style) Self {
    var new_self: Self = self.*;
    new_self._style = style_ptr;
    return new_self;
}

/// Size in pixels, weight and colour in one call: `.font(16, 600, .black)`.
pub fn font(self: *const Self, font_size: u8, weight: ?u16, color: ?Color) Self {
    var new_self: Self = self.*;
    var visual = new_self._visual orelse types.Visual{};
    visual.font_size = font_size;
    visual.font_weight = weight;
    visual.text_color = color;
    new_self._visual = visual;
    return new_self;
}

/// Font weight 700.
pub fn bold(self: *const Self) Self {
    var new_self: Self = self.*;
    var visual = new_self._visual orelse types.Visual{};
    visual.font_weight = 700;
    new_self._visual = visual;
    return new_self;
}

/// Positioning: `.pos(.{ .type = .absolute, .top = .px(0), .right = .px(0) })`.
/// Keeps a z-index set with `zIndex`.
pub fn pos(self: *const Self, position: types.Position) Self {
    var new_self: Self = self.*;
    var new_position = new_self._pos orelse types.Position{};
    new_position.top = position.top;
    new_position.right = position.right;
    new_position.bottom = position.bottom;
    new_position.left = position.left;
    new_position.type = position.type;
    new_self._pos = new_position;
    return new_self;
}

/// Stacking order. `null` removes it.
pub fn zIndex(self: *const Self, z_index: ?i16) Self {
    var new_self: Self = self.*;
    var position = new_self._pos orelse types.Position{};
    position.z_index = z_index;
    new_self._pos = position;
    return new_self;
}

/// Gaussian blur radius in pixels. `null` removes it.
pub fn blur(self: *const Self, value: ?u8) Self {
    var new_self: Self = self.*;
    var visual = new_self._visual orelse types.Visual{};
    visual.blur = value;
    new_self._visual = visual;
    return new_self;
}

/// How children are aligned on both axes, e.g. `.layout(.center)`.
pub fn layout(self: *const Self, value: types.Layout) Self {
    var new_self: Self = self.*;
    new_self._layout = value;
    return new_self;
}

/// Centres the children on both axes. Same as `.layout(.center)`.
pub fn center(self: *const Self) Self {
    var new_self: Self = self.*;
    new_self._layout = .center;
    return new_self;
}

/// Background colour: a literal or a theme colour. For a gradient, use `.layer`.
pub fn background(self: *const Self, value: types.Color) Self {
    var new_self: Self = self.*;
    var visual = new_self._visual orelse types.Visual{};
    visual.background = value;
    new_self._visual = visual;
    return new_self;
}

/// Box shadow.
pub fn shadow(self: *const Self, value: types.Shadow) Self {
    var new_self: Self = self.*;
    var visual = new_self._visual orelse types.Visual{};
    visual.shadow = value;
    new_self._visual = visual;
    return new_self;
}

/// A patterned background layer: grid, dots, lines or gradient.
pub fn layer(self: *const Self, value: types.BackgroundLayer) Self {
    var new_self: Self = self.*;
    var visual = new_self._visual orelse types.Visual{};
    visual.layer = value;
    new_self._visual = visual;
    return new_self;
}

/// Whether children wrap onto new lines when they do not fit.
pub fn wrap(self: *const Self, value: types.FlexWrap) Self {
    var new_self: Self = self.*;
    new_self._flex_wrap = value;
    return new_self;
}

/// Underline, overline or line-through, with its style and colour.
pub fn textDecoration(self: *const Self, value: types.TextDecoration) Self {
    var new_self: Self = self.*;
    var visual = new_self._visual orelse types.Visual{};
    visual.text_decoration = value;
    new_self._visual = visual;
    return new_self;
}

/// Grows the element slightly (to 104%) while hovered.
pub fn hoverScale(self: *const Self) Self {
    var new_self: Self = self.*;
    var _interactive = new_self._interactive orelse types.Interactive{};
    var hover = _interactive.hover orelse types.Visual{};
    hover.transform = .scale();
    _interactive.hover = hover;
    new_self._interactive = _interactive;
    return new_self;
}

/// Outline style and colour; unlike a border, it takes no space.
pub fn outline(self: *const Self, value: types.Outline, color: ?Color) Self {
    var new_self: Self = self.*;
    var visual = new_self._visual orelse types.Visual{};
    visual.outline = value;
    visual.outline_color = color;
    new_self._visual = visual;
    return new_self;
}

/// Shape of the text cursor.
pub fn caret(self: *const Self, value: types.Caret) Self {
    var new_self: Self = self.*;
    var visual = new_self._visual orelse types.Visual{};
    visual.caret = value;
    new_self._visual = visual;
    return new_self;
}

/// Whether the user can resize the field: `.none`, `.both`, `.horizontal`,
/// `.vertical`.
pub fn resize(self: *const Self, value: types.Resize) Self {
    var new_self: Self = self.*;
    var visual = new_self._visual orelse types.Visual{};
    visual.resize = value;
    new_self._visual = visual;
    return new_self;
}

/// Background colour while hovered.
pub fn hoverBackground(self: *const Self, color: types.Color) Self {
    var new_self: Self = self.*;
    var _interactive = new_self._interactive orelse types.Interactive{};
    var hover = _interactive.hover orelse types.Visual{};
    hover.background = color;
    _interactive.hover = hover;
    new_self._interactive = _interactive;
    return new_self;
}

/// Pointer cursor, as for something clickable.
pub fn pointer(self: *const Self) Self {
    var new_self: Self = self.*;
    var visual = new_self._visual orelse types.Visual{};
    visual.cursor = .pointer;
    new_self._visual = visual;
    return new_self;
}

/// Removes text decoration, e.g. a link's underline.
pub fn noDecoration(self: *const Self) Self {
    var new_self: Self = self.*;
    var visual = new_self._visual orelse types.Visual{};
    visual.text_decoration = .none;
    new_self._visual = visual;
    return new_self;
}

/// Text colour while hovered.
pub fn hoverText(self: *const Self, color: types.Color) Self {
    var new_self: Self = self.*;
    var _interactive = new_self._interactive orelse types.Interactive{};
    var hover = _interactive.hover orelse types.Visual{};
    hover.text_color = color;
    _interactive.hover = hover;
    new_self._interactive = _interactive;
    return new_self;
}

/// Gap between children, in pixels.
pub fn spacing(self: *const Self, value: u8) Self {
    var new_self: Self = self.*;
    new_self._child_gap = value;
    return new_self;
}

/// Inner spacing: `.padding(.all(16))`, `.padding(.tb(8, 4))`, ...
pub fn padding(self: *const Self, value: types.Padding) Self {
    var new_self: Self = self.*;
    new_self._padding = value;
    return new_self;
}

/// Left padding in pixels; keeps the other sides.
pub fn pl(self: *const Self, value: u8) Self {
    var new_self: Self = self.*;
    if (new_self._padding == null) {
        new_self._padding = .{};
    }
    new_self._padding.?.left = value;
    return new_self;
}

/// Right padding in pixels; keeps the other sides.
pub fn pr(self: *const Self, value: u8) Self {
    var new_self: Self = self.*;
    if (new_self._padding == null) {
        new_self._padding = .{};
    }
    new_self._padding.?.right = value;
    return new_self;
}

/// Top padding in pixels; keeps the other sides.
pub fn pt(self: *const Self, value: u8) Self {
    var new_self: Self = self.*;
    if (new_self._padding == null) {
        new_self._padding = .{};
    }
    new_self._padding.?.top = value;
    return new_self;
}

/// Bottom padding in pixels; keeps the other sides.
pub fn pb(self: *const Self, value: u8) Self {
    var new_self: Self = self.*;
    if (new_self._padding == null) {
        new_self._padding = .{};
    }
    new_self._padding.?.bottom = value;
    return new_self;
}

/// Mouse cursor shown over the element.
pub fn cursor(self: *const Self, value: types.Cursor) Self {
    var new_self: Self = self.*;
    var visual = new_self._visual orelse types.Visual{};
    visual.cursor = value;
    new_self._visual = visual;
    return new_self;
}

/// Outer spacing: `.margin(.all(8))`, ...
pub fn margin(self: *const Self, value: types.Margin) Self {
    var new_self: Self = self.*;
    new_self._margin = value;
    return new_self;
}

/// Width and height together: `.size(.full)`, `.size(.squarePx(48))`.
pub fn size(self: *const Self, dim: types.Size) Self {
    var new_self: Self = self.*;
    new_self._size = dim;
    return new_self;
}

/// Height, then width.
pub fn hw(self: *const Self, height_value: types.Sizing, width_value: types.Sizing) Self {
    var new_self: Self = self.*;
    if (new_self._size == null) {
        new_self._size = .{ .width = width_value, .height = height_value };
    } else {
        new_self._size.?.width = width_value;
        new_self._size.?.height = height_value;
    }
    return new_self;
}

/// Width: `.width(.px(320))`, `.width(.percent(50))`, `.width(.expand)` (fill the
/// available space), ...
pub fn width(self: *const Self, length: types.Sizing) Self {
    var new_self: Self = self.*;
    if (new_self._size == null) {
        new_self._size = .{ .width = length };
    } else {
        new_self._size.?.width = length;
    }
    return new_self;
}

/// Height, with the same sizes as `width`.
pub fn height(self: *const Self, length: types.Sizing) Self {
    var new_self: Self = self.*;
    if (new_self._size == null) {
        new_self._size = .{ .height = length };
    } else {
        new_self._size.?.height = length;
    }
    return new_self;
}

/// Border thickness, colour, radius and style together.
pub fn border(self: *const Self, value: types.Border) Self {
    var new_self: Self = self.*;
    var visual = new_self._visual orelse types.Visual{};
    visual.border = value;
    new_self._visual = visual;
    return new_self;
}

/// Corner radius; keeps the other border settings.
pub fn radius(self: *const Self, value: types.BorderRadius) Self {
    var new_self: Self = self.*;
    var visual = new_self._visual orelse types.Visual{};
    var b = visual.border orelse types.Border{};
    b.radius = value;
    visual.border = b;
    new_self._visual = visual;
    return new_self;
}

/// Transition duration in milliseconds. Replaces any `.transition(...)`.
pub fn duration(self: *const Self, value: u32) Self {
    var new_self: Self = self.*;
    new_self._transition = .{ .duration = value };
    return new_self;
}

/// Main axis for the children: `.row` or `.column`.
pub fn direction(self: *const Self, value: types.Direction) Self {
    var new_self: Self = self.*;
    new_self._direction = value;
    return new_self;
}

/// Adds a CSS class, for rules you inject yourself.
pub fn class(self: *const Self, class_name: []const u8) Self {
    var n = self.*;
    n._class = class_name;
    return n;
}

/// Raw CSS for the element's `style` attribute, formatted like `std.fmt`:
/// `.inlineStyle("grid-area: {s};", .{area})`. Prefer the typed methods; this is
/// the escape hatch.
pub fn inlineStyle(self: *const Self, comptime fmt: []const u8, args: anytype) Self {
    var new_self: Self = self.*;
    const allocator = Vapor.arena(.frame);
    const text = std.fmt.allocPrint(allocator, fmt, args) catch |err| {
        Vapor.printlnColor(
            \\Error formatting text: {any}\n"
            \\FMT: {s}\n"
            \\ARGS: {any}\n"
        , .{ err, fmt, args }, .hex("#FF3029"));
        return new_self;
    };
    Vapor.frame_arena.addBytesUsed(text.len);
    new_self._inlineStyle = text;
    return new_self;
}
