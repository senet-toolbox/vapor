const TextFieldMod = @import("../TextField.zig");
const Self = TextFieldMod.TextFieldBuilder;
const std = @import("std");
const types = @import("../types.zig");
const Vapor = @import("../Vapor.zig");
const Color = types.Color;

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

pub fn scroll(self: *const Self, scroll_type: types.Scroll) Self {
    var new_self: Self = self.*;
    new_self._scroll = scroll_type;
    return new_self;
}

pub fn fontWeight(self: *const Self, value: u16) Self {
    var n = self.*;
    var v = n._visual orelse types.Visual{};
    v.font_weight = value;
    n._visual = v;
    return n;
}

pub fn fontColor(self: *const Self, color: ?Color) Self {
    var n = self.*;
    var v = n._visual orelse types.Visual{};
    v.text_color = color;
    n._visual = v;
    return n;
}

pub fn whitespace(self: *const Self, value: types.WhiteSpace) Self {
    var new_self: Self = self.*;
    var visual = new_self._visual orelse types.Visual{};
    visual.white_space = value;
    new_self._visual = visual;
    return new_self;
}

pub fn fontSize(self: *const Self, font_size: u8) Self {
    var new_self: Self = self.*;
    var visual = new_self._visual orelse types.Visual{};
    visual.font_size = font_size;
    new_self._visual = visual;
    return new_self;
}

pub fn fontFamily(self: *const Self, font_family: []const u8) Self {
    var new_self: Self = self.*;
    new_self._font_family = font_family;
    return new_self;
}

pub fn animationEnter(self: *const Self, animation_tag: ?[]const u8) Self {
    if (animation_tag) |_animation| {
        var new_self: Self = self.*;
        new_self._animation_enter = _animation;
        return new_self;
    }
    return self.*;
}

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

pub fn animationExit(self: *const Self, animation_tag: ?[]const u8) Self {
    var new_self: Self = self.*;
    new_self._animation_exit = animation_tag;
    return new_self;
}

pub fn baseStyle(self: *const Self, style_ptr: *const Vapor.Style) Self {
    var new_self: Self = self.*;
    new_self._style = style_ptr;
    return new_self;
}

pub fn interaction(self: *const Self, interactive: types.Interactive) Self {
    var new_self: Self = self.*;
    new_self._interactive = interactive;
    return new_self;
}

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

pub fn font(self: *const Self, font_size: u8, weight: ?u16, color: ?Color) Self {
    var new_self: Self = self.*;
    var visual = new_self._visual orelse types.Visual{};
    visual.font_size = font_size;
    visual.font_weight = weight;
    visual.text_color = color;
    new_self._visual = visual;
    return new_self;
}

pub fn bold(self: *const Self) Self {
    var new_self: Self = self.*;
    var visual = new_self._visual orelse types.Visual{};
    visual.font_weight = 700;
    new_self._visual = visual;
    return new_self;
}

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

pub fn zIndex(self: *const Self, z_index: ?i16) Self {
    var new_self: Self = self.*;
    var position = new_self._pos orelse types.Position{};
    position.z_index = z_index;
    new_self._pos = position;
    return new_self;
}

pub fn blur(self: *const Self, value: ?u8) Self {
    var new_self: Self = self.*;
    var visual = new_self._visual orelse types.Visual{};
    visual.blur = value;
    new_self._visual = visual;
    return new_self;
}

pub fn layout(self: *const Self, value: types.Layout) Self {
    var new_self: Self = self.*;
    new_self._layout = value;
    return new_self;
}

pub fn center(self: *const Self) Self {
    var new_self: Self = self.*;
    new_self._layout = .center;
    return new_self;
}

pub fn background(self: *const Self, value: types.Color) Self {
    var new_self: Self = self.*;
    var visual = new_self._visual orelse types.Visual{};
    visual.background = value;
    new_self._visual = visual;
    return new_self;
}

pub fn shadow(self: *const Self, value: types.Shadow) Self {
    var new_self: Self = self.*;
    var visual = new_self._visual orelse types.Visual{};
    visual.shadow = value;
    new_self._visual = visual;
    return new_self;
}

pub fn layer(self: *const Self, value: types.BackgroundLayer) Self {
    var new_self: Self = self.*;
    var visual = new_self._visual orelse types.Visual{};
    visual.layer = value;
    new_self._visual = visual;
    return new_self;
}

pub fn wrap(self: *const Self, value: types.FlexWrap) Self {
    var new_self: Self = self.*;
    new_self._flex_wrap = value;
    return new_self;
}

pub fn textDecoration(self: *const Self, value: types.TextDecoration) Self {
    var new_self: Self = self.*;
    var visual = new_self._visual orelse types.Visual{};
    visual.text_decoration = value;
    new_self._visual = visual;
    return new_self;
}

pub fn hoverScale(self: *const Self) Self {
    var new_self: Self = self.*;
    var _interactive = new_self._interactive orelse types.Interactive{};
    var hover = _interactive.hover orelse types.Visual{};
    hover.transform = .scale();
    _interactive.hover = hover;
    new_self._interactive = _interactive;
    return new_self;
}

pub fn outline(self: *const Self, value: types.Outline, color: ?Color) Self {
    var new_self: Self = self.*;
    var visual = new_self._visual orelse types.Visual{};
    visual.outline = value;
    visual.outline_color = color;
    new_self._visual = visual;
    return new_self;
}

pub fn caret(self: *const Self, value: types.Caret) Self {
    var new_self: Self = self.*;
    var visual = new_self._visual orelse types.Visual{};
    visual.caret = value;
    new_self._visual = visual;
    return new_self;
}

pub fn resize(self: *const Self, value: types.Resize) Self {
    var new_self: Self = self.*;
    var visual = new_self._visual orelse types.Visual{};
    visual.resize = value;
    new_self._visual = visual;
    return new_self;
}

pub fn hoverBackground(self: *const Self, color: types.Color) Self {
    var new_self: Self = self.*;
    var _interactive = new_self._interactive orelse types.Interactive{};
    var hover = _interactive.hover orelse types.Visual{};
    hover.background = color;
    _interactive.hover = hover;
    new_self._interactive = _interactive;
    return new_self;
}

pub fn pointer(self: *const Self) Self {
    var new_self: Self = self.*;
    var visual = new_self._visual orelse types.Visual{};
    visual.cursor = .pointer;
    new_self._visual = visual;
    return new_self;
}

pub fn noDecoration(self: *const Self) Self {
    var new_self: Self = self.*;
    var visual = new_self._visual orelse types.Visual{};
    visual.text_decoration = .none;
    new_self._visual = visual;
    return new_self;
}

pub fn hoverText(self: *const Self, color: types.Color) Self {
    var new_self: Self = self.*;
    var _interactive = new_self._interactive orelse types.Interactive{};
    var hover = _interactive.hover orelse types.Visual{};
    hover.text_color = color;
    _interactive.hover = hover;
    new_self._interactive = _interactive;
    return new_self;
}

pub fn childGap(self: *const Self, value: u8) Self {
    var new_self: Self = self.*;
    new_self._child_gap = value;
    return new_self;
}

pub fn spacing(self: *const Self, value: u8) Self {
    var new_self: Self = self.*;
    new_self._child_gap = value;
    return new_self;
}

pub fn padding(self: *const Self, value: types.Padding) Self {
    var new_self: Self = self.*;
    new_self._padding = value;
    return new_self;
}

pub fn pl(self: *const Self, value: u8) Self {
    var new_self: Self = self.*;
    if (new_self._padding == null) {
        new_self._padding = .{};
    }
    new_self._padding.?._left = value;
    return new_self;
}

pub fn pr(self: *const Self, value: u8) Self {
    var new_self: Self = self.*;
    if (new_self._padding == null) {
        new_self._padding = .{};
    }
    new_self._padding.?._right = value;
    return new_self;
}

pub fn pt(self: *const Self, value: u8) Self {
    var new_self: Self = self.*;
    if (new_self._padding == null) {
        new_self._padding = .{};
    }
    new_self._padding.?._top = value;
    return new_self;
}

pub fn pb(self: *const Self, value: u8) Self {
    var new_self: Self = self.*;
    if (new_self._padding == null) {
        new_self._padding = .{};
    }
    new_self._padding.?._bottom = value;
    return new_self;
}

pub fn cursor(self: *const Self, value: types.Cursor) Self {
    var new_self: Self = self.*;
    var visual = new_self._visual orelse types.Visual{};
    visual.cursor = value;
    new_self._visual = visual;
    return new_self;
}

pub fn margin(self: *const Self, value: types.Margin) Self {
    var new_self: Self = self.*;
    new_self._margin = value;
    return new_self;
}

pub fn size(self: *const Self, dim: types.Size) Self {
    var new_self: Self = self.*;
    new_self._size = dim;
    return new_self;
}

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

pub fn width(self: *const Self, length: types.Sizing) Self {
    var new_self: Self = self.*;
    if (new_self._size == null) {
        new_self._size = .{ .width = length };
    } else {
        new_self._size.?.width = length;
    }
    return new_self;
}

pub fn height(self: *const Self, length: types.Sizing) Self {
    var new_self: Self = self.*;
    if (new_self._size == null) {
        new_self._size = .{ .height = length };
    } else {
        new_self._size.?.height = length;
    }
    return new_self;
}

pub fn border(self: *const Self, value: types.BorderGrouped) Self {
    var new_self: Self = self.*;
    var visual = new_self._visual orelse types.Visual{};
    visual.border = value;
    new_self._visual = visual;
    return new_self;
}

pub fn radius(self: *const Self, value: types.BorderRadius) Self {
    var new_self: Self = self.*;
    var visual = new_self._visual orelse types.Visual{};
    visual.border_radius = value;
    new_self._visual = visual;
    return new_self;
}

pub fn duration(self: *const Self, value: u32) Self {
    var new_self: Self = self.*;
    new_self._transition = .{ .duration = value };
    return new_self;
}

pub fn direction(self: *const Self, value: types.Direction) Self {
    var new_self: Self = self.*;
    new_self._direction = value;
    return new_self;
}

pub fn class(self: *const Self, class_name: []const u8) Self {
    var n = self.*;
    n._class = class_name;
    return n;
}

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
