//! CSS transitions: which properties animate, and their timing.

const std = @import("std");
const TimingFunction = @import("Animation.zig").Easing;
const Vapor = @import("vapor.zig");

pub const TransitionProperty = enum(u8) {
    linear,
    opacity,
    x_position,
    y_position,
    width,
    height,
    rotation,
    scale,
    background_color,
    border_color,
    transform,
    top,
    bottom,
    left,
    right,
    none,
    cx,
    d,
    cy,
    padding,
    background,
    border,
    color,
    /// Every property, size and position included.
    all,

    /// The CSS property name.
    pub fn css(self: TransitionProperty) []const u8 {
        return switch (self) {
            .x_position, .y_position => "translate",
            .rotation => "rotate",
            .background_color => "background-color",
            .border_color => "border-color",
            // Named by no property, what `none` animates is written by the
            // style compiler.
            .none, .linear => "all",
            else => @tagName(self),
        };
    }
};

/// What a transition that names no property (`.duration(ms)`, or
/// `.transition(.{})`) animates: how an element looks, never its size or
/// place. An element reused for other content, or a screen-size change,
/// would otherwise animate its layout. Name the properties, or `.all`, to
/// animate those.
pub const look_properties = [_][]const u8{
    "color",                "background-color", "border-color", "outline-color",
    "text-decoration-color", "fill",            "stroke",       "opacity",
    "box-shadow",           "transform",        "translate",    "scale",
    "rotate",               "filter",           "backdrop-filter",
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
    /// `.none` animates `look_properties`; `.all` animates everything.
    properties: []const TransitionProperty = &.{.none},
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
