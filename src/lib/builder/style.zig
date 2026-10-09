const Components = @import("../Components.zig");
const Self = Components.ComponentBuilder;
const std = @import("std");
const types = @import("../types.zig");
const Vapor = @import("../Vapor.zig");
const Color = types.Color;
const Shadow = @import("../Shadow.zig");

pub fn fontStyle(self: *const Self, font_style: types.FontStyle) Self {
    var n = self.*;
    var v = n._visual orelse types.Visual{};
    v.font_style = font_style;
    n._visual = v;
    return n;
}

pub fn ellipsis(self: *const Self, value: types.Ellipsis) Self {
    if (self._elem_type != .Text and self._elem_type != .TextArea and self._elem_type != .TextField and self._elem_type != .TextFmt) {
        std.log.warn("Ellipsis can only be used on Text, not {any}", .{self._elem_type});
        return self.*;
    }
    var n = self.*;
    var v = n._visual orelse types.Visual{};
    v.ellipsis = value;
    n._visual = v;
    return n;
}

pub fn fill(self: *const Self, value: types.Color) Self {
    var n = self.*;
    var v = n._visual orelse types.Visual{};
    v.fill = value;
    n._visual = v;
    return n;
}

pub fn stroke(self: *const Self, value: types.Color) Self {
    var n = self.*;
    var v = n._visual orelse types.Visual{};
    v.stroke = value;
    n._visual = v;
    return n;
}

pub fn inherit(self: *const Self, fields: []const types.StyleFields) Self {
    var n = self.*;
    n._style_fields = fields;
    return n;
}

pub fn inheritHover(self: *const Self, fields: []const types.StyleFields) Self {
    var n = self.*;
    n._hover_style_fields = fields;
    return n;
}

pub fn bold(self: *const Self) Self {
    var n = self.*;
    var v = n._visual orelse types.Visual{};
    v.font_weight = 700;
    n._visual = v;
    return n;
}

pub fn whiteSpace(self: *const Self, value: types.WhiteSpace) Self {
    var n = self.*;
    var v = n._visual orelse types.Visual{};
    v.white_space = value;
    n._visual = v;
    return n;
}

pub fn inlineStyle(self: *const Self, comptime fmt: []const u8, args: anytype) Self {
    var n = self.*;
    const text = Vapor.frame.fmt(fmt, args);
    n._inlineStyle = text;
    return n;
}

pub fn morph(self: *const Self, m: bool) Self {
    var n = self.*;
    n._morph = m;
    return n;
}

pub fn fontSize(self: *const Self, font_size: u8) Self {
    var n = self.*;
    var v = n._visual orelse types.Visual{};
    v.font_size = font_size;
    n._visual = v;
    return n;
}

pub fn fontWeight(self: *const Self, value: u16) Self {
    var n = self.*;
    var v = n._visual orelse types.Visual{};
    v.font_weight = value;
    n._visual = v;
    return n;
}

pub fn weight(self: *const Self, value: u16) Self {
    var n = self.*;
    var v = n._visual orelse types.Visual{};
    v.font_weight = value;
    n._visual = v;
    return n;
}

pub fn fontFamily(self: *const Self, font_family: []const u8) Self {
    var n = self.*;
    n._font_family = font_family;
    return n;
}

pub fn animationEnter(self: *const Self, animation_tag: ?[]const u8) Self {
    if (animation_tag) |a| {
        var n = self.*;
        n._animation_enter = a;
        return n;
    }
    return self.*;
}

pub fn animation(self: *const Self, animation_tag: ?[]const u8) Self {
    if (animation_tag) |a| {
        var n = self.*;
        var v = n._visual orelse types.Visual{};
        v.animation = a;
        n._visual = v;
        return n;
    }
    return self.*;
}

pub fn animationExit(self: *const Self, animation_tag: ?[]const u8) Self {
    var n = self.*;
    n._animation_exit = animation_tag;
    return n;
}

pub fn class(self: *const Self, class_name: []const u8) Self {
    var n = self.*;
    n._class = class_name;
    return n;
}

pub fn classFmt(self: *const Self, comptime fmt: []const u8, args: anytype) Self {
    var n = self.*;
    const allocator = Vapor.arena(.frame);
    const text = std.fmt.allocPrint(allocator, fmt, args) catch {
        // Vapor.printlnColor(\\Error formatting text: {any}\n"\\FMT: {s}\n"\\ARGS: {any}\n", .{ err, fmt, args }, .hex("#FF3029"));
        return n;
    };
    Vapor.frame_arena.addBytesUsed(text.len);
    n._class = text;
    return n;
}

pub fn transition(self: *const Self, _transition: types.Transition) Self {
    var n = self.*;
    n._transition = _transition;
    return n;
}

pub fn transform(self: *const Self, value: ?types.Transform) Self {
    var n = self.*;
    var v = n._visual orelse types.Visual{};
    v.transform = value;
    n._visual = v;
    return n;
}

pub fn scale(self: *const Self, value: f16) Self {
    var n = self.*;
    var v = n._visual orelse types.Visual{};
    v.transform = .scaleDecimal(value);
    n._visual = v;
    return n;
}

pub fn baseStyle(self: *const Self, style_ptr: *const Vapor.Style) Self {
    var n = self.*;
    n._style = style_ptr;
    return n;
}

pub fn interaction(self: *const Self, interactive: types.Interactive) Self {
    var n = self.*;
    n._interactive = interactive;
    return n;
}

pub fn textColor(self: *const Self, color: ?Color) Self {
    var n = self.*;
    var v = n._visual orelse types.Visual{};
    v.text_color = color;
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

pub fn font(self: *const Self, font_size_val: u8, font_weight: ?u16, color: ?Color) Self {
    var n = self.*;
    var v = n._visual orelse types.Visual{};
    v.font_size = font_size_val;
    v.font_weight = font_weight;
    v.text_color = color;
    n._visual = v;
    return n;
}

pub fn blur(self: *const Self, value: ?u8) Self {
    var n = self.*;
    var v = n._visual orelse types.Visual{};
    v.blur = value;
    n._visual = v;
    return n;
}

pub fn background(self: *const Self, value: types.Color) Self {
    var n = self.*;
    var v = n._visual orelse types.Visual{};
    v.background = value;
    n._visual = v;
    return n;
}

pub fn outline(self: *const Self, value: types.Outline, color: ?Color) Self {
    var new_self: Self = self.*;
    var visual = new_self._visual orelse types.Visual{};
    visual.outline = value;
    visual.outline_color = color;
    new_self._visual = visual;
    return new_self;
}

pub fn shadow(self: *const Self, value: ?Shadow) Self {
    if (value == null) return self.*;
    var n = self.*;
    var v = n._visual orelse types.Visual{};
    if (self._elem_type == .Text or self._elem_type == .TextFmt) {
        v.text_shadow = value.?;
    } else {
        v.new_shadow = value.?;
    }
    n._visual = v;
    return n;
}

pub fn layer(self: *const Self, value: ?types.BackgroundLayer) Self {
    if (value == null) return self.*;
    var n = self.*;
    var v = n._visual orelse types.Visual{};
    v.layer = value;
    n._visual = v;
    return n;
}

pub fn layers(self: *const Self, value: ?[]const types.BackgroundLayer) Self {
    if (value == null) return self.*;
    var n = self.*;
    var v = n._visual orelse types.Visual{};
    v.layers = value;
    n._visual = v;
    return n;
}

pub fn gradient(self: *const Self, value: types.Color) Self {
    var n = self.*;
    var v = n._visual orelse types.Visual{};
    v.background = value;
    n._visual = v;
    return n;
}

pub fn textDecoration(self: *const Self, value: types.TextDecoration) Self {
    var n = self.*;
    var v = n._visual orelse types.Visual{};
    v.text_decoration = value;
    n._visual = v;
    return n;
}

pub fn hoverScale(self: *const Self) Self {
    var n = self.*;
    var i = n._interactive orelse types.Interactive{};
    var h = i.hover orelse types.Visual{};
    h.transform = .scale();
    i.hover = h;
    n._interactive = i;
    return n;
}

pub fn hover(self: *const Self, value: types.Visual) Self {
    var n = self.*;
    var i = n._interactive orelse types.Interactive{};
    i.hover = value;
    n._interactive = i;
    return n;
}

pub fn hoverTarget(self: *const Self, target: []const u8, value: types.Visual) Self {
    var n = self.*;
    n._target = target;
    n._target_visual = value;
    return n;
}

pub fn hoverBackground(self: *const Self, color: types.Color) Self {
    var n = self.*;
    var i = n._interactive orelse types.Interactive{};
    var h = i.hover orelse types.Visual{};
    h.background = color;
    i.hover = h;
    n._interactive = i;
    return n;
}

pub fn pointer(self: *const Self) Self {
    var n = self.*;
    var v = n._visual orelse types.Visual{};
    v.cursor = .pointer;
    n._visual = v;
    return n;
}

pub fn noDecoration(self: *const Self) Self {
    var n = self.*;
    var v = n._visual orelse types.Visual{};
    v.text_decoration = .none;
    n._visual = v;
    return n;
}

pub fn opacity(self: *const Self, value: f16) Self {
    var n = self.*;
    var v = n._visual orelse types.Visual{};
    v.opacity = value;
    n._visual = v;
    return n;
}

pub fn hoverText(self: *const Self, color: Color) Self {
    var n = self.*;
    var i = n._interactive orelse types.Interactive{};
    var h = i.hover orelse types.Visual{};
    h.text_color = color;
    i.hover = h;
    n._interactive = i;
    return n;
}

pub fn transformOrigin(self: *const Self, value: types.TransformOrigin) Self {
    var n = self.*;
    n._transform_origin = value;
    return n;
}

pub fn cursor(self: *const Self, value: types.Cursor) Self {
    var n = self.*;
    var v = n._visual orelse types.Visual{};
    v.cursor = value;
    n._visual = v;
    return n;
}

pub fn border(self: *const Self, value: types.BorderGrouped) Self {
    var n = self.*;
    var v = n._visual orelse types.Visual{};
    v.border = value;
    n._visual = v;
    return n;
}

pub fn borderStyle(self: *const Self, value: types.BorderStyle) Self {
    var n = self.*;
    var v = n._visual orelse types.Visual{};
    var b = v.border orelse types.BorderGrouped{ .color = null, .thickness = .all(0) };
    b.style = value;
    v.border = b;
    n._visual = v;
    return n;
}

pub fn radius(self: *const Self, value: types.BorderRadius) Self {
    var n = self.*;
    var v = n._visual orelse types.Visual{};
    var b = v.border orelse types.BorderGrouped{ .color = null, .thickness = .all(0) };
    b.radius = value;
    v.border = b;
    n._visual = v;
    return n;
}

pub fn colorMix(self: *const Self, value: types.ColorMix) Self {
    var n = self.*;
    var v = n._visual orelse types.Visual{};
    v.color_mix = value;
    n._visual = v;
    return n;
}

pub fn duration(self: *const Self, value: u32) Self {
    var n = self.*;
    n._transition = .{ .duration = value };
    return n;
}

pub fn listStyle(self: *const Self, value: types.ListStyle) Self {
    var n = self.*;
    n._list_style = value;
    return n;
}

pub fn style(self: *const Self, style_ptr: *const Vapor.Style) Self {
    var n = self.*;
    n._style = style_ptr;
    return n;
}
