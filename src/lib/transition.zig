//! CSS transitions: which properties animate, and their timing.

const std = @import("std");
const TimingFunction = @import("Animation.zig").Easing;
const Vapor = @import("vapor.zig");

/// What a transition animates. Each property is its CSS name in snake_case
/// (`.border_radius` is `border-radius`); `.look`, `.layout` and `.all` are
/// groups of them.
pub const TransitionProperty = enum(u8) {
    // Groups
    /// How an element looks, never its size or place: colours, opacity,
    /// shadow, corners, transform and filters. What `.duration(ms)` animates.
    look,
    /// Size, spacing and place: width and height (and their limits),
    /// padding, margin, gap, border width, and top/right/bottom/left.
    layout,
    /// Every property.
    all,

    // How it looks
    color,
    background_color,
    border_color,
    border_radius,
    outline_color,
    outline_width,
    outline_offset,
    text_decoration_color,
    opacity,
    box_shadow,
    transform,
    translate,
    scale,
    rotate,
    filter,
    backdrop_filter,
    clip_path,

    // Size and place
    width,
    height,
    min_width,
    max_width,
    min_height,
    max_height,
    padding,
    margin,
    gap,
    border_width,
    top,
    right,
    bottom,
    left,

    // Text
    font_size,
    line_height,
    letter_spacing,

    // SVG
    fill,
    stroke,
    stroke_width,
    stroke_dasharray,
    stroke_dashoffset,
    cx,
    cy,
    r,
    d,

    // Shorthands
    background,
    border,

    /// Deprecated: the same as `.look`.
    none,
    /// Deprecated: a timing, not a property. The same as `.all`.
    linear,
    /// Deprecated: use `.translate`.
    x_position,
    /// Deprecated: use `.translate`.
    y_position,
    /// Deprecated: use `.rotate`.
    rotation,

    /// The CSS properties this animates: one, or a group's.
    pub fn names(self: TransitionProperty) []const []const u8 {
        return switch (self) {
            .look, .none => &look_properties,
            .layout => &layout_properties,
            .all, .linear => &.{"all"},
            .x_position, .y_position => &.{"translate"},
            .rotation => &.{"rotate"},
            inline else => |p| &.{comptime cssName(@tagName(p))},
        };
    }

    /// Deprecated: use `names`. A group's name is `all`.
    pub fn css(self: TransitionProperty) []const u8 {
        const all = self.names();
        return if (all.len == 1) all[0] else "all";
    }
};

/// `snake_case` to `kebab-case`.
fn cssName(comptime tag: []const u8) []const u8 {
    comptime {
        var name: [tag.len]u8 = tag[0..tag.len].*;
        for (&name) |*c| {
            if (c.* == '_') c.* = '-';
        }
        const final = name;
        return &final;
    }
}

/// What `.look` animates.
pub const look_properties = [_][]const u8{
    "color",           "background-color", "border-color",   "border-radius",
    "outline-color",   "outline-width",    "outline-offset", "text-decoration-color",
    "fill",            "stroke",           "opacity",        "box-shadow",
    "transform",       "translate",        "scale",          "rotate",
    "filter",          "backdrop-filter",
};

/// What `.layout` animates.
pub const layout_properties = [_][]const u8{
    "width",  "height", "min-width", "max-width",    "min-height", "max-height",
    "padding", "margin", "gap",      "border-width", "top",        "right",
    "bottom", "left",
};

pub const TransitionState = packed union {
    opacity: u32,
    x_offset: u32,
    y_offset: u32,
    width_offset: u32,
    height_offset: u32,
    rotation: u32,
    scale: u32,
    // A packed union requires every field to share a bit width, so `none`
    // carries the same u32 as the rest and is simply left at 0.
    none: u32,
};

pub const PackedTransition = packed struct {
    properties_ptr: u32 = 0,
    properties_len: u32 = 0,
    duration: u32 = 300, // default 300ms
    timing: TimingFunction = .ease,
    delay: u32 = 0,

    /// Packs `transition` for a node.
    pub fn set(packed_transition: *PackedTransition, transition: *const Transition) void {
        var slice: []TransitionProperty = Vapor.arena(.frame).alloc(TransitionProperty, transition.properties.len) catch return;
        for (transition.properties, 0..) |property, i| {
            slice[i] = property;
        }
        const count = Vapor.packed_transitions.count() + 1;
        Vapor.packed_transitions.put(count, slice) catch return;
        packed_transition.properties_ptr = count;
        packed_transition.properties_len = @intCast(slice.len);
        packed_transition.duration = transition.duration;
        packed_transition.timing = transition.timing;
        packed_transition.delay = transition.delay;
    }
};

// Main Transition struct - holds all transition data
pub const Transition = struct {
    /// What animates; `.look` unless named.
    properties: []const TransitionProperty = &.{.look},
    duration: u32 = 300, // default 300ms
    timing: TimingFunction = .ease,
    delay: u32 = 0,

    /// No transition.
    pub fn none() Transition {
        return Transition{};
    }

    /// Transitions only `transform`.
    pub fn transform() Transition {
        return .{
            .properties = &.{.transform},
        };
    }
};
