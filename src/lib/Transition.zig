// Transition.zig
const std = @import("std");
const TimingFunction = @import("Animation.zig").Easing;
const Vapor = @import("Vapor.zig");

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
    properties: []const TransitionProperty = &.{.none},
    duration: u32 = 300, // default 300ms
    timing: TimingFunction = .ease,
    delay: u32 = 0,

    pub fn none() Transition {
        return Transition{};
    }

    pub fn transform() Transition {
        return .{
            .properties = &.{.transform},
        };
    }
};
