const std = @import("std");
const Vapor = @import("Vapor.zig");
const Allocator = std.mem.Allocator;
const StyleCompiler = @import("convertStyleCustomWriter.zig");
const getExitAnimationStyle = StyleCompiler.getExitAnimationStyle;
const UINode = @import("UITree.zig").UINode;
const Color = Vapor.Types.Color;
const Shadow = @import("Shadow.zig");

pub const Animation = @This();

pub fn new() void {
    Vapor.animations = std.StringHashMap(Animation).init(Vapor.arena(.persist));
    RemovalQueue.init(Vapor.arena(.persist));
}

// Helper struct for setAll - allows named field syntax
pub const PropSet = struct {
    none: ?f32 = null,
    translateX: ?f32 = null,
    translateY: ?f32 = null,
    translateZ: ?f32 = null,
    scale: ?f32 = null,
    scaleX: ?f32 = null,
    scaleY: ?f32 = null,
    rotate: ?f32 = null,
    rotateX: ?f32 = null,
    rotateY: ?f32 = null,
    rotateZ: ?f32 = null,
    skewX: ?f32 = null,
    skewY: ?f32 = null,
    opacity: ?f32 = null,
    width: ?f32 = null,
    height: ?f32 = null,
    marginTop: ?f32 = null,
    marginBottom: ?f32 = null,
    marginLeft: ?f32 = null,
    marginRight: ?f32 = null,
    paddingTop: ?f32 = null,
    paddingBottom: ?f32 = null,
    paddingLeft: ?f32 = null,
    paddingRight: ?f32 = null,
    top: ?f32 = null,
    bottom: ?f32 = null,
    left: ?f32 = null,
    right: ?f32 = null,
    borderRadius: ?f32 = null,
    borderWidth: ?f32 = null,
    blur: ?f32 = null,
    brightness: ?f32 = null,
    saturate: ?f32 = null,
    strokeDashoffset: ?f32 = null,
};

/// Sets multiple properties at once using struct syntax
/// Usage: .at(20).setAll(.{ .translateX = -8, .skewX = -10, .opacity = 0.9 })
const animation_types = std.enums.values(AnimationType);
pub fn setAll(self: Animation, props: PropSet) Animation {
    var a = self;

    // Use inline for to iterate over struct fields at comptime
    const fields = @typeInfo(PropSet).@"struct".fields;
    inline for (fields, 0..) |field, i| {
        if (@field(props, field.name)) |value| {
            // Convert field name to AnimationType
            const anim_type = animation_types[i];
            a = a.set(anim_type, value);
        }
    }

    return a;
}

/// Resets all properties used in this animation to their default values at 100%
/// Automatically detects which properties were animated and resets them
/// Usage: .at(85).set(.translateX, 3).autoReset()
pub fn autoReset(self: Animation) Animation {
    var a = self.at(100);

    // Collect all unique property types used across all keyframes
    var used_props: [MAX_PROPS_PER_FRAME * MAX_KEYFRAMES]AnimationType = undefined;
    var used_count: u8 = 0;

    for (a.frames) |maybe_frame| {
        if (maybe_frame) |frame| {
            if (frame.percent == 100) continue; // Skip existing 100% frame

            for (frame.props) |maybe_prop| {
                if (maybe_prop) |_prop| {
                    // Check if we already have this prop type
                    var found = false;
                    for (used_props[0..used_count]) |existing| {
                        if (existing == _prop.type) {
                            found = true;
                            break;
                        }
                    }
                    if (!found and used_count < used_props.len) {
                        used_props[used_count] = _prop.type;
                        used_count += 1;
                    }
                }
            }
        }
    }

    // Reset each used property to its default
    for (used_props[0..used_count]) |prop_type| {
        const default_val = getDefaultValue(prop_type);
        a = a.set(prop_type, default_val);
    }

    return a;
}

/// Resets all properties at current keyframe to their default values
/// Usage: .at(100).reset()
pub fn reset(self: Animation) Animation {
    var a = self;

    // Same logic as autoReset but applies to current_percent
    var used_props: [MAX_PROPS_PER_FRAME * MAX_KEYFRAMES]AnimationType = undefined;
    var used_count: u8 = 0;

    for (a.frames) |maybe_frame| {
        if (maybe_frame) |frame| {
            if (frame.percent == a.current_percent) continue;

            for (frame.props) |maybe_prop| {
                if (maybe_prop) |_prop| {
                    var found = false;
                    for (used_props[0..used_count]) |existing| {
                        if (existing == _prop.type) {
                            found = true;
                            break;
                        }
                    }
                    if (!found and used_count < used_props.len) {
                        used_props[used_count] = _prop.type;
                        used_count += 1;
                    }
                }
            }
        }
    }

    for (used_props[0..used_count]) |prop_type| {
        a = a.set(prop_type, getDefaultValue(prop_type));
    }

    return a;
}

/// Clears specific properties to their defaults at the current keyframe
/// Usage: .at(100).clear(&.{ .translateX, .translateY, .skewX })
pub fn clear(self: Animation, prop_types: []const AnimationType) Animation {
    var a = self;

    for (prop_types) |prop_type| {
        a = a.set(prop_type, getDefaultValue(prop_type));
    }

    return a;
}

/// Returns the default/initial value for each property type
fn getDefaultValue(prop_type: AnimationType) f32 {
    return switch (prop_type) {
        // Transforms default to 0
        .translateX, .translateY, .translateZ => 0,
        .rotate, .rotateX, .rotateY, .rotateZ => 0,
        .skewX, .skewY => 0,

        // Scale defaults to 1
        .scale, .scaleX, .scaleY => 1,

        // Opacity defaults to 1 (fully visible)
        .opacity => 1,

        // Filters
        .blur => 0,
        .brightness => 1,
        .saturate => 1,

        // Size/spacing - 0 is a safe default but may not be "initial"
        .width, .height => 0,
        .marginTop, .marginBottom, .marginLeft, .marginRight => 0,
        .paddingTop, .paddingBottom, .paddingLeft, .paddingRight => 0,
        .top, .bottom, .left, .right => 0,
        .borderRadius, .borderWidth => 0,

        // None/unknown
        .none, .backgroundColor, .textShadow => 0,
        .strokeDashoffset => 0,
    };
}

pub const AnimationType = enum(u8) {
    none,
    // Position
    translateX,
    translateY,
    translateZ,
    // Scale
    scale,
    scaleX,
    scaleY,
    // Rotation
    rotate,
    rotateX,
    rotateY,
    rotateZ,
    // Skew
    skewX,
    skewY,
    // Visual
    opacity,
    // Size
    width,
    height,
    // Spacing
    marginTop,
    marginBottom,
    marginLeft,
    marginRight,
    paddingTop,
    paddingBottom,
    paddingLeft,
    paddingRight,
    // Position
    top,
    bottom,
    left,
    right,
    // Other
    borderRadius,
    borderWidth,
    blur,
    brightness,
    saturate,
    backgroundColor,

    // NEW: Text shadow for glitch effects
    textShadow, // Offset X of text shadow
    // For chromatic aberration, you'd animate multiple shadows
    strokeDashoffset,

    pub fn isTransform(self: AnimationType) bool {
        return switch (self) {
            .translateX, .translateY, .translateZ, .scale, .scaleX, .scaleY, .rotate, .rotateX, .rotateY, .rotateZ, .skewX, .skewY => true,
            else => false,
        };
    }

    pub fn isFilter(self: AnimationType) bool {
        return switch (self) {
            .blur, .brightness, .saturate => true,
            else => false,
        };
    }

    pub fn toCss(self: AnimationType) []const u8 {
        return switch (self) {
            .none => "",
            .translateX => "translateX",
            .translateY => "translateY",
            .translateZ => "translateZ",
            .scale => "scale",
            .scaleX => "scaleX",
            .scaleY => "scaleY",
            .rotate => "rotate",
            .rotateX => "rotateX",
            .rotateY => "rotateY",
            .rotateZ => "rotateZ",
            .skewX => "skewX",
            .skewY => "skewY",
            .opacity => "opacity",
            .width => "width",
            .height => "height",
            .marginTop => "margin-top",
            .marginBottom => "margin-bottom",
            .marginLeft => "margin-left",
            .marginRight => "margin-right",
            .paddingTop => "padding-top",
            .paddingBottom => "padding-bottom",
            .paddingLeft => "padding-left",
            .paddingRight => "padding-right",
            .top => "top",
            .bottom => "bottom",
            .left => "left",
            .right => "right",
            .borderRadius => "border-radius",
            .borderWidth => "border-width",
            .blur => "blur",
            .brightness => "brightness",
            .saturate => "saturate",
            .backgroundColor => "background-color",
            .textShadow => "text-shadow", // Will need special handling
            .strokeDashoffset => "stroke-dashoffset",
        };
    }

    pub fn isTextShadow(self: AnimationType) bool {
        return switch (self) {
            .textShadow => true,
            else => false,
        };
    }
};

pub const Easing = enum(u8) {
    linear,
    ease,
    easeIn,
    easeOut,
    easeInOut,
    easeInQuad,
    easeOutQuad,
    easeInOutQuad,
    easeInCubic,
    easeOutCubic,
    easeInOutCubic,
    easeInBack,
    easeOutBack,
    easeInOutBack,
    easeOutBounce,

    pub fn toCss(self: Easing) []const u8 {
        return switch (self) {
            .linear => "linear",
            .ease => "ease",
            .easeIn => "ease-in",
            .easeOut => "ease-out",
            .easeInOut => "ease-in-out",
            .easeInQuad => "cubic-bezier(0.55, 0.085, 0.68, 0.53)",
            .easeOutQuad => "cubic-bezier(0.25, 0.46, 0.45, 0.94)",
            .easeInOutQuad => "cubic-bezier(0.455, 0.03, 0.515, 0.955)",
            .easeInCubic => "cubic-bezier(0.55, 0.055, 0.675, 0.19)",
            .easeOutCubic => "cubic-bezier(0.215, 0.61, 0.355, 1)",
            .easeInOutCubic => "cubic-bezier(0.645, 0.045, 0.355, 1)",
            .easeInBack => "cubic-bezier(0.6, -0.28, 0.735, 0.045)",
            .easeOutBack => "cubic-bezier(0.175, 0.885, 0.32, 1.275)",
            .easeInOutBack => "cubic-bezier(0.68, -0.55, 0.265, 1.55)",
            .easeOutBounce => "cubic-bezier(0.175, 0.885, 0.32, 1.275)",
        };
    }
};

pub const FillMode = enum(u8) {
    none,
    forwards,
    backwards,
    both,

    pub fn toCss(self: FillMode) []const u8 {
        return switch (self) {
            .none => "none",
            .forwards => "forwards",
            .backwards => "backwards",
            .both => "both",
        };
    }
};

pub const Direction = enum(u8) {
    normal,
    reverse,
    alternate,
    alternateReverse,

    pub fn toCss(self: Direction) []const u8 {
        return switch (self) {
            .normal => "normal",
            .reverse => "reverse",
            .alternate => "alternate",
            .alternateReverse => "alternate-reverse",
        };
    }
};

pub const Unit = enum(u8) {
    px,
    percent,
    em,
    rem,
    vw,
    vh,
    deg,
    none,

    pub fn toCss(self: Unit) []const u8 {
        return switch (self) {
            .px => "px",
            .percent => "%",
            .em => "em",
            .rem => "rem",
            .vw => "vw",
            .vh => "vh",
            .deg => "deg",
            .none => "",
        };
    }
};

// A single property to animate
pub const Property = struct {
    prop_type: AnimationType,
    from_value: f32,
    to_value: f32,
    unit: Unit,

    pub fn init(prop_type: AnimationType, from_val: f32, to_val: f32) Property {
        const default_unit: Unit = switch (prop_type) {
            .opacity, .scale, .scaleX, .scaleY, .brightness, .saturate => .none,
            .rotate, .rotateX, .rotateY, .rotateZ, .skewX, .skewY => .deg,
            else => .px,
        };

        return Property{
            .prop_type = prop_type,
            .from_value = from_val,
            .to_value = to_val,
            .unit = default_unit,
        };
    }

    pub fn inUnit(self: Property, unit: Unit) Property {
        var p = self;
        p.unit = unit;
        return p;
    }
};
// -- NEW: Value Logic (Handling Numbers vs Colors) --

// We need a way to store either a Float (for transforms) or a specific String/Color
// Since your previous example used f32, we will stick to that for simplicity,
// but for a true glitch effect (colors), you would ideally use a Union here.
// For this example, I will assume we are just animating the transforms/filters.
// 1. The container for the data (Number OR Color)
pub const Value = union(enum) {
    number: f32,
    color: Color,
    shadow: Shadow, // NEW
};

pub const PropValue = struct {
    type: AnimationType,
    value: Value,
    unit: Unit,

    // Init for Numbers (Transforms, Opacity, etc.)
    pub fn init(t: AnimationType, v: f32) PropValue {
        const u: Unit = switch (t) {
            .rotate, .rotateX, .rotateY, .rotateZ, .skewX, .skewY => .deg,
            .opacity, .scale, .scaleX, .scaleY, .brightness, .saturate => .none,
            .blur => .px, // blur uses pixels: blur(10px)
            else => .px,
        };
        return .{ .type = t, .value = .{ .number = v }, .unit = u };
    }

    // Init for Numbers with explicit Unit
    pub fn initUnit(t: AnimationType, v: f32, u: Unit) PropValue {
        return .{ .type = t, .value = .{ .number = v }, .unit = u };
    }

    // Init for Colors (Background, Border, etc.)
    pub fn initColor(t: AnimationType, c: Color) PropValue {
        return .{ .type = t, .value = .{ .color = c }, .unit = .none };
    }

    // NEW: Init for Shadows
    pub fn initShadow(t: AnimationType, s: Shadow) PropValue {
        return .{ .type = t, .value = .{ .shadow = s }, .unit = .none };
    }
};

// -- NEW: Keyframe Storage --

const MAX_PROPS_PER_FRAME = 8;
const MAX_KEYFRAMES = 10; // 0%, 25%, 35%, 59%, 60%, 100%...

pub const Keyframe = struct {
    percent: f32, // 0 to 100
    props: [MAX_PROPS_PER_FRAME]?PropValue = [_]?PropValue{null} ** MAX_PROPS_PER_FRAME,
    count: u8 = 0,

    pub fn add(self: Keyframe, t: AnimationType, v: f32) Keyframe {
        var k = self;
        if (k.count < MAX_PROPS_PER_FRAME) {
            k.props[k.count] = PropValue.init(t, v);
            k.count += 1;
        }
        return k;
    }

    pub fn addUnit(self: Keyframe, t: AnimationType, v: f32, u: Unit) Keyframe {
        var k = self;
        if (k.count < MAX_PROPS_PER_FRAME) {
            k.props[k.count] = PropValue.initUnit(t, v, u);
            k.count += 1;
        }
        return k;
    }

    // NEW: Helper to add a color property
    pub fn addColor(self: Keyframe, t: AnimationType, c: Color) Keyframe {
        var k = self;
        if (k.count < MAX_PROPS_PER_FRAME) {
            k.props[k.count] = PropValue.initColor(t, c);
            k.count += 1;
        }
        return k;
    }

    // NEW: Helper to add a shadow property
    pub fn addShadow(self: Keyframe, t: AnimationType, s: Shadow) Keyframe {
        var k = self;
        if (k.count < MAX_PROPS_PER_FRAME) {
            k.props[k.count] = PropValue.initShadow(t, s);
            k.count += 1;
        }
        return k;
    }
};

const MAX_PROPERTIES = 8;

frames: [MAX_KEYFRAMES]?Keyframe = [_]?Keyframe{null} ** MAX_KEYFRAMES,
frame_count: u8 = 0,
// Used for the builder chain to know which frame we are editing
current_percent: f32 = 0,

// Core animation fields
_name: []const u8,
properties: [MAX_PROPERTIES]?Property = [_]?Property{null} ** MAX_PROPERTIES,
property_count: u8 = 0,
duration_ms: u32 = 1000,
delay_ms: u32 = 0,
easing_fn: Easing = .linear,
fill_mode: FillMode = .none,
direction: Direction = .normal,
iteration_count: ?u32 = 1,

pub fn init(name: []const u8) Animation {
    return Animation{
        ._name = name,
    };
}

// -- The New "Glitch" Builder API --

/// Sets the current "cursor" to a specific percentage.
/// If a keyframe doesn't exist for this percent, it creates one.
pub fn at(self: Animation, percent: f32) Animation {
    var a = self;
    a.current_percent = percent;

    // Check if frame exists
    for (a.frames) |f| {
        if (f) |frame| {
            if (frame.percent == percent) return a;
        }
    }

    // Create new frame if not found
    if (a.frame_count < MAX_KEYFRAMES) {
        a.frames[a.frame_count] = Keyframe{ .percent = percent };
        a.frame_count += 1;
    }
    return a;
}

/// Adds a property value to the current percentage (set by .at())
pub fn set(self: Animation, prop_type: AnimationType, val: f32) Animation {
    var a = self;
    // Find the frame matching current_percent and add to it
    for (0..a.frame_count) |i| {
        if (a.frames[i]) |*f| {
            if (f.percent == a.current_percent) {
                a.frames[i] = f.add(prop_type, val);
                break;
            }
        }
    }
    return a;
}

/// Adds a property with a specific unit
pub fn setUnit(self: Animation, prop_type: AnimationType, val: f32, unit: Unit) Animation {
    var a = self;
    for (0..a.frame_count) |i| {
        if (a.frames[i]) |*f| {
            if (f.percent == a.current_percent) {
                a.frames[i] = f.addUnit(prop_type, val, unit);
                break;
            }
        }
    }
    return a;
}
// NEW: Builder method for colors
pub fn setColor(self: Animation, prop_type: AnimationType, val: Color) Animation {
    var a = self;
    for (0..a.frame_count) |i| {
        if (a.frames[i]) |*f| {
            if (f.percent == a.current_percent) {
                a.frames[i] = f.addColor(prop_type, val);
                break;
            }
        }
    }
    return a;
}

// Add a property to animate
pub fn prop(self: Animation, prop_type: AnimationType, from_val: f32, to_val: f32) Animation {
    var a = self;
    if (a.property_count < MAX_PROPERTIES) {
        a.properties[a.property_count] = Property.init(prop_type, from_val, to_val);
        a.property_count += 1;
    }
    return a;
}

// Add a property with custom unit
pub fn propUnit(self: Animation, prop_type: AnimationType, from_val: f32, to_val: f32, unit: Unit) Animation {
    var a = self;
    if (a.property_count < MAX_PROPERTIES) {
        a.properties[a.property_count] = Property.init(prop_type, from_val, to_val).inUnit(unit);
        a.property_count += 1;
    }
    return a;
}

pub fn duration(self: Animation, milliseconds: u32) Animation {
    var a = self;
    a.duration_ms = milliseconds;
    return a;
}

pub fn delay(self: Animation, milliseconds: u32) Animation {
    var a = self;
    a.delay_ms = milliseconds;
    return a;
}

pub fn easing(self: Animation, value: Easing) Animation {
    var a = self;
    a.easing_fn = value;
    return a;
}

pub fn fill(self: Animation, value: FillMode) Animation {
    var a = self;
    a.fill_mode = value;
    return a;
}

pub fn dir(self: Animation, value: Direction) Animation {
    var a = self;
    a.direction = value;
    return a;
}

pub fn iterations(self: Animation, count: u32) Animation {
    var a = self;
    a.iteration_count = count;
    return a;
}

pub fn infinite(self: Animation) Animation {
    var a = self;
    a.iteration_count = null;
    return a;
}

pub fn setShadow(self: Animation, prop_type: AnimationType, shadow: Shadow) Animation {
    var a = self;
    for (0..a.frame_count) |i| {
        if (a.frames[i]) |*f| {
            if (f.percent == a.current_percent) {
                a.frames[i] = f.addShadow(prop_type, shadow);
                break;
            }
        }
    }
    return a;
}

// Convenience presets
pub fn fadeIn(name: []const u8) Animation {
    return init(name)
        .prop(.opacity, 0, 1)
        .duration(150)
        .easing(.easeInOut)
        .fill(.forwards);
}

pub fn fadeOut(name: []const u8) Animation {
    return init(name)
        .prop(.opacity, 1, 0)
        .duration(150)
        .easing(.easeInOut)
        .fill(.forwards);
}

pub fn slideInLeft(name: []const u8, distance: f32) Animation {
    return init(name)
        .prop(.translateX, -distance, 0)
        .prop(.opacity, 0, 1)
        .fill(.forwards);
}

pub fn slideInRight(name: []const u8, distance: f32) Animation {
    return init(name)
        .prop(.translateX, distance, 0)
        .prop(.opacity, 0, 1)
        .fill(.forwards);
}

pub fn slideInUp(name: []const u8, distance: f32) Animation {
    return init(name)
        .prop(.translateY, distance, 0)
        .prop(.opacity, 0, 1)
        .fill(.forwards);
}

pub fn slideInDown(name: []const u8, distance: f32) Animation {
    return init(name)
        .prop(.translateY, -distance, 0)
        .prop(.opacity, 0, 1)
        .fill(.forwards);
}

pub fn slideOutLeft(name: []const u8, distance: f32) Animation {
    return init(name)
        .prop(.translateX, 0, -distance)
        .prop(.opacity, 1, 0)
        .fill(.forwards);
}

pub fn slideOutRight(name: []const u8, distance: f32) Animation {
    return init(name)
        .prop(.translateX, 0, distance)
        .prop(.opacity, 1, 0)
        .fill(.forwards);
}

pub fn slideOutUp(name: []const u8, distance: f32) Animation {
    return init(name)
        .prop(.translateY, 0, -distance)
        .prop(.opacity, 1, 0)
        .fill(.forwards);
}

pub fn slideOutDown(name: []const u8, distance: f32) Animation {
    return init(name)
        .prop(.translateY, 0, distance)
        .prop(.opacity, 1, 0)
        .fill(.forwards);
}

pub fn zoomIn(name: []const u8) Animation {
    return init(name)
        .prop(.scale, 0, 1)
        .prop(.opacity, 0, 1)
        .fill(.forwards);
}

pub fn zoomOut(name: []const u8) Animation {
    return init(name)
        .prop(.scale, 1, 0)
        .prop(.opacity, 1, 0)
        .fill(.forwards);
}

pub fn spin(name: []const u8) Animation {
    return init(name)
        .prop(.rotate, 0, 360)
        .infinite();
}

pub fn pulse(name: []const u8) Animation {
    return init(name)
        .prop(.scale, 1, 1.05)
        .dir(.alternate)
        .infinite();
}

// ============================================
// ATTENTION / EMPHASIS ANIMATIONS
// ============================================

pub fn bounce(name: []const u8) Animation {
    return init(name)
        .at(0).setAll(.{ .translateY = 0 })
        .at(20).setAll(.{ .translateY = -30 })
        .at(40).setAll(.{ .translateY = 0 })
        .at(60).setAll(.{ .translateY = -15 })
        .at(80).setAll(.{ .translateY = 0 })
        .at(100).setAll(.{ .translateY = 0 })
        .easing(.easeOut)
        .fill(.both);
}

pub fn shake(name: []const u8) Animation {
    return init(name)
        .at(0).set(.translateX, 0)
        .at(10).set(.translateX, -10)
        .at(20).set(.translateX, 10)
        .at(30).set(.translateX, -10)
        .at(40).set(.translateX, 10)
        .at(50).set(.translateX, -10)
        .at(60).set(.translateX, 10)
        .at(70).set(.translateX, -10)
        .at(80).set(.translateX, 10)
        .at(90).set(.translateX, -10)
        .at(100).set(.translateX, 0)
        .duration(500);
}

pub fn shakeY(name: []const u8) Animation {
    return init(name)
        .at(0).set(.translateY, 0)
        .at(10).set(.translateY, -10)
        .at(20).set(.translateY, 10)
        .at(30).set(.translateY, -10)
        .at(40).set(.translateY, 10)
        .at(50).set(.translateY, -10)
        .at(60).set(.translateY, 10)
        .at(70).set(.translateY, -10)
        .at(80).set(.translateY, 10)
        .at(90).set(.translateY, -10)
        .at(100).set(.translateY, 0)
        .duration(500);
}

pub fn wobble(name: []const u8) Animation {
    return init(name)
        .at(0).setAll(.{ .translateX = 0, .rotate = 0 })
        .at(15).setAll(.{ .translateX = -25, .rotate = -5 })
        .at(30).setAll(.{ .translateX = 20, .rotate = 3 })
        .at(45).setAll(.{ .translateX = -15, .rotate = -3 })
        .at(60).setAll(.{ .translateX = 10, .rotate = 2 })
        .at(75).setAll(.{ .translateX = -5, .rotate = -1 })
        .at(100).setAll(.{ .translateX = 0, .rotate = 0 })
        .duration(800);
}

pub fn jello(name: []const u8) Animation {
    return init(name)
        .at(0).set(.skewX, 0)
        .at(11).set(.skewX, 0)
        .at(22).set(.skewX, -12.5)
        .at(33).set(.skewX, 6.25)
        .at(44).set(.skewX, -3.125)
        .at(55).set(.skewX, 1.5625)
        .at(66).set(.skewX, -0.78125)
        .at(77).set(.skewX, 0.390625)
        .at(88).set(.skewX, -0.1953125)
        .at(100).set(.skewX, 0)
        .duration(900);
}

pub fn heartbeat(name: []const u8) Animation {
    return init(name)
        .at(0).set(.scale, 1)
        .at(14).set(.scale, 1.3)
        .at(28).set(.scale, 1)
        .at(42).set(.scale, 1.3)
        .at(70).set(.scale, 1)
        .duration(1300)
        .easing(.easeInOut);
}

pub fn rubberBand(name: []const u8) Animation {
    return init(name)
        .at(0).setAll(.{ .scaleX = 1, .scaleY = 1 })
        .at(30).setAll(.{ .scaleX = 1.25, .scaleY = 0.75 })
        .at(40).setAll(.{ .scaleX = 0.75, .scaleY = 1.25 })
        .at(50).setAll(.{ .scaleX = 1.15, .scaleY = 0.85 })
        .at(65).setAll(.{ .scaleX = 0.95, .scaleY = 1.05 })
        .at(75).setAll(.{ .scaleX = 1.05, .scaleY = 0.95 })
        .at(100).setAll(.{ .scaleX = 1, .scaleY = 1 })
        .duration(800);
}

pub fn tada(name: []const u8) Animation {
    return init(name)
        .at(0).setAll(.{ .scale = 1, .rotate = 0 })
        .at(10).setAll(.{ .scale = 0.9, .rotate = -3 })
        .at(20).setAll(.{ .scale = 0.9, .rotate = -3 })
        .at(30).setAll(.{ .scale = 1.1, .rotate = 3 })
        .at(40).setAll(.{ .scale = 1.1, .rotate = -3 })
        .at(50).setAll(.{ .scale = 1.1, .rotate = 3 })
        .at(60).setAll(.{ .scale = 1.1, .rotate = -3 })
        .at(70).setAll(.{ .scale = 1.1, .rotate = 3 })
        .at(80).setAll(.{ .scale = 1.1, .rotate = -3 })
        .at(90).setAll(.{ .scale = 1.1, .rotate = 3 })
        .at(100).setAll(.{ .scale = 1, .rotate = 0 })
        .duration(1000);
}

pub fn swing(name: []const u8) Animation {
    return init(name)
        .at(0).set(.rotate, 0)
        .at(20).set(.rotate, 15)
        .at(40).set(.rotate, -10)
        .at(60).set(.rotate, 5)
        .at(80).set(.rotate, -5)
        .at(100).set(.rotate, 0)
        .duration(800)
        .easing(.easeInOut);
}

// ============================================
// ENTRANCE ANIMATIONS
// ============================================

pub fn bounceIn(name: []const u8) Animation {
    return init(name)
        .at(0).setAll(.{ .opacity = 0, .scale = 0.3 })
        .at(20).setAll(.{ .scale = 1.1 })
        .at(40).setAll(.{ .scale = 0.9 })
        .at(60).setAll(.{ .opacity = 1, .scale = 1.03 })
        .at(80).setAll(.{ .scale = 0.97 })
        .at(100).setAll(.{ .opacity = 1, .scale = 1 })
        .duration(750)
        .fill(.both);
}

pub fn bounceInDown(name: []const u8) Animation {
    return init(name)
        .at(0).setAll(.{ .opacity = 0, .translateY = -3000 })
        .at(60).setAll(.{ .opacity = 1, .translateY = 25 })
        .at(75).setAll(.{ .translateY = -10 })
        .at(90).setAll(.{ .translateY = 5 })
        .at(100).setAll(.{ .translateY = 0 })
        .easing(.easeOutCubic)
        .fill(.both);
}

pub fn bounceInUp(name: []const u8) Animation {
    return init(name)
        .at(0).setAll(.{ .opacity = 0, .translateY = 3000 })
        .at(60).setAll(.{ .opacity = 1, .translateY = -25 })
        .at(75).setAll(.{ .translateY = 10 })
        .at(90).setAll(.{ .translateY = -5 })
        .at(100).setAll(.{ .translateY = 0 })
        .easing(.easeOutCubic)
        .fill(.both);
}

pub fn flipIn(name: []const u8) Animation {
    return init(name)
        .at(0).setAll(.{ .opacity = 0, .rotateY = 90 })
        .at(40).setAll(.{ .rotateY = -20 })
        .at(60).setAll(.{ .rotateY = 10 })
        .at(80).setAll(.{ .opacity = 1, .rotateY = -5 })
        .at(100).setAll(.{ .rotateY = 0 })
        .duration(750)
        .easing(.easeInOut)
        .fill(.both);
}

pub fn flipInX(name: []const u8) Animation {
    return init(name)
        .at(0).setAll(.{ .opacity = 0, .rotateX = 90 })
        .at(40).setAll(.{ .rotateX = -20 })
        .at(60).setAll(.{ .rotateX = 10 })
        .at(80).setAll(.{ .opacity = 1, .rotateX = -5 })
        .at(100).setAll(.{ .rotateX = 0 })
        .duration(750)
        .easing(.easeInOut)
        .fill(.both);
}

pub fn rotateIn(name: []const u8) Animation {
    return init(name)
        .at(0).setAll(.{ .opacity = 0, .rotate = -200 })
        .at(100).setAll(.{ .opacity = 1, .rotate = 0 })
        .easing(.easeInOut)
        .fill(.both);
}

pub fn rollIn(name: []const u8) Animation {
    return init(name)
        .at(0).setAll(.{ .opacity = 0, .translateX = -100, .rotate = -120 })
        .at(100).setAll(.{ .opacity = 1, .translateX = 0, .rotate = 0 })
        .duration(800)
        .fill(.both);
}

pub fn lightSpeedIn(name: []const u8) Animation {
    return init(name)
        .at(0).setAll(.{ .opacity = 0, .translateX = 100, .skewX = -30 })
        .at(60).setAll(.{ .opacity = 1, .skewX = 20 })
        .at(80).setAll(.{ .skewX = -5 })
        .at(100).setAll(.{ .translateX = 0, .skewX = 0 })
        .easing(.easeOut)
        .fill(.both);
}

pub fn expandIn(name: []const u8) Animation {
    return init(name)
        .at(0).setAll(.{ .opacity = 0, .scaleX = 0, .scaleY = 1 })
        .at(100).setAll(.{ .opacity = 1, .scaleX = 1, .scaleY = 1 })
        .easing(.easeOut)
        .fill(.both);
}

pub fn expandInY(name: []const u8) Animation {
    return init(name)
        .at(0).setAll(.{ .opacity = 0, .scaleX = 1, .scaleY = 0 })
        .at(100).setAll(.{ .opacity = 1, .scaleX = 1, .scaleY = 1 })
        .easing(.easeOut)
        .fill(.both);
}

// ============================================
// EXIT ANIMATIONS
// ============================================

pub fn bounceOut(name: []const u8) Animation {
    return init(name)
        .at(0).setAll(.{ .opacity = 1, .scale = 1 })
        .at(20).setAll(.{ .scale = 0.9 })
        .at(50).setAll(.{ .opacity = 1, .scale = 1.1 })
        .at(55).setAll(.{ .opacity = 1, .scale = 1.1 })
        .at(100).setAll(.{ .opacity = 0, .scale = 0.3 })
        .duration(750)
        .fill(.both);
}

pub fn bounceOutDown(name: []const u8) Animation {
    return init(name)
        .at(0).setAll(.{ .translateY = 0 })
        .at(20).setAll(.{ .translateY = -10 })
        .at(40).setAll(.{ .opacity = 1, .translateY = 20 })
        .at(45).setAll(.{ .opacity = 1, .translateY = 20 })
        .at(100).setAll(.{ .opacity = 0, .translateY = 2000 })
        .fill(.both);
}

pub fn bounceOutUp(name: []const u8) Animation {
    return init(name)
        .at(0).setAll(.{ .translateY = 0 })
        .at(20).setAll(.{ .translateY = 10 })
        .at(40).setAll(.{ .opacity = 1, .translateY = -20 })
        .at(45).setAll(.{ .opacity = 1, .translateY = -20 })
        .at(100).setAll(.{ .opacity = 0, .translateY = -2000 })
        .fill(.both);
}

pub fn flipOut(name: []const u8) Animation {
    return init(name)
        .at(0).setAll(.{ .opacity = 1, .rotateY = 0 })
        .at(30).setAll(.{ .opacity = 1, .rotateY = -20 })
        .at(100).setAll(.{ .opacity = 0, .rotateY = 90 })
        .duration(600)
        .fill(.both);
}

pub fn rotateOut(name: []const u8) Animation {
    return init(name)
        .at(0).setAll(.{ .opacity = 1, .rotate = 0 })
        .at(100).setAll(.{ .opacity = 0, .rotate = 200 })
        .easing(.easeInOut)
        .fill(.both);
}

pub fn rollOut(name: []const u8) Animation {
    return init(name)
        .at(0).setAll(.{ .opacity = 1, .translateX = 0, .rotate = 0 })
        .at(100).setAll(.{ .opacity = 0, .translateX = 100, .rotate = 120 })
        .duration(800)
        .fill(.both);
}

pub fn lightSpeedOut(name: []const u8) Animation {
    return init(name)
        .at(0).setAll(.{ .opacity = 1, .translateX = 0, .skewX = 0 })
        .at(100).setAll(.{ .opacity = 0, .translateX = 100, .skewX = 30 })
        .easing(.easeIn)
        .fill(.both);
}

pub fn shrinkOut(name: []const u8) Animation {
    return init(name)
        .at(0).setAll(.{ .opacity = 1, .scale = 1 })
        .at(100).setAll(.{ .opacity = 0, .scale = 0 })
        .easing(.easeIn)
        .fill(.both);
}

pub fn hinge(name: []const u8) Animation {
    return init(name)
        .at(0).setAll(.{ .opacity = 1, .rotate = 0 })
        .at(20).setAll(.{ .rotate = 80 })
        .at(40).setAll(.{ .rotate = 60 })
        .at(60).setAll(.{ .rotate = 80 })
        .at(80).setAll(.{ .opacity = 1, .rotate = 60, .translateY = 0 })
        .at(100).setAll(.{ .opacity = 0, .rotate = 60, .translateY = 700 })
        .duration(2000)
        .easing(.easeInOut)
        .fill(.both);
}

// ============================================
// BACKGROUND / SPECIAL ANIMATIONS
// ============================================

pub fn flash(name: []const u8) Animation {
    return init(name)
        .at(0).set(.opacity, 1)
        .at(25).set(.opacity, 0)
        .at(50).set(.opacity, 1)
        .at(75).set(.opacity, 0)
        .at(100).set(.opacity, 1)
        .duration(750);
}

pub fn blink(name: []const u8) Animation {
    return init(name)
        .at(0).set(.opacity, 1)
        .at(50).set(.opacity, 0)
        .at(100).set(.opacity, 1)
        .duration(1000)
        .infinite();
}

pub fn glow(name: []const u8) Animation {
    return init(name)
        .at(0).set(.brightness, 1)
        .at(50).set(.brightness, 1.3)
        .at(100).set(.brightness, 1)
        .dir(.alternate)
        .infinite();
}

pub fn float(name: []const u8) Animation {
    return init(name)
        .at(0).set(.translateY, 0)
        .at(50).set(.translateY, -20)
        .at(100).set(.translateY, 0)
        .easing(.easeInOut)
        .dir(.alternate)
        .infinite();
}

pub fn sway(name: []const u8) Animation {
    return init(name)
        .at(0).set(.rotate, -3)
        .at(50).set(.rotate, 3)
        .at(100).set(.rotate, -3)
        .easing(.easeInOut)
        .infinite();
}

pub fn breathe(name: []const u8) Animation {
    return init(name)
        .at(0).set(.scale, 1)
        .at(50).set(.scale, 1.1)
        .at(100).set(.scale, 1)
        .duration(3000)
        .easing(.easeInOut)
        .infinite();
}

pub fn pulseShadow(name: []const u8) Animation {
    return init(name)
        .at(0).set(.blur, 0)
        .at(50).set(.blur, 10)
        .at(100).set(.blur, 0)
        .duration(2000)
        .easing(.easeInOut)
        .infinite();
}

// ============================================
// LOADING / PROGRESS ANIMATIONS
// ============================================

pub fn spinPulse(name: []const u8) Animation {
    return init(name)
        .at(0).setAll(.{ .rotate = 0, .scale = 1 })
        .at(50).setAll(.{ .rotate = 180, .scale = 1.2 })
        .at(100).setAll(.{ .rotate = 360, .scale = 1 })
        .infinite();
}

pub fn pendulum(name: []const u8) Animation {
    return init(name)
        .at(0).set(.rotate, -45)
        .at(50).set(.rotate, 45)
        .at(100).set(.rotate, -45)
        .easing(.easeInOut)
        .infinite();
}

pub fn morphWidth(name: []const u8, from: f32, to: f32) Animation {
    return init(name)
        .at(0).set(.width, from)
        .at(50).set(.width, to)
        .at(100).set(.width, from)
        .easing(.easeInOut)
        .infinite();
}

pub fn progressPulse(name: []const u8) Animation {
    return init(name)
        .at(0).setAll(.{ .opacity = 0.6, .scaleX = 0.8 })
        .at(50).setAll(.{ .opacity = 1, .scaleX = 1 })
        .at(100).setAll(.{ .opacity = 0.6, .scaleX = 0.8 })
        .easing(.easeInOut)
        .infinite();
}

// ============================================
// TEXT ANIMATIONS
// ============================================

pub fn typewriter(name: []const u8, width: f32) Animation {
    return init(name)
        .at(0).set(.width, 0)
        .at(100).set(.width, width)
        .easing(.linear)
        .fill(.forwards);
}

pub fn blur(name: []const u8) Animation {
    return init(name)
        .at(0).setAll(.{ .blur = 0, .opacity = 1 })
        .at(100).setAll(.{ .blur = 10, .opacity = 0 })
        .fill(.forwards);
}

pub fn unblur(name: []const u8) Animation {
    return init(name)
        .at(0).setAll(.{ .blur = 10, .opacity = 0 })
        .at(100).setAll(.{ .blur = 0, .opacity = 1 })
        .fill(.forwards);
}

// ============================================
// 3D-ISH ANIMATIONS
// ============================================

pub fn flip3D(name: []const u8) Animation {
    return init(name)
        .at(0).set(.rotateY, 0)
        .at(100).set(.rotateY, 360)
        .easing(.easeInOut)
        .infinite();
}

pub fn tilt(name: []const u8, deg: f32) Animation {
    return init(name)
        .at(0).setAll(.{ .rotateX = 0, .rotateY = 0 })
        .at(50).setAll(.{ .rotateX = deg, .rotateY = deg })
        .at(100).setAll(.{ .rotateX = 0, .rotateY = 0 })
        .easing(.easeInOut)
        .infinite();
}

pub fn zoomInRotate(name: []const u8) Animation {
    return init(name)
        .at(0).setAll(.{ .scale = 0, .rotate = -180, .opacity = 0 })
        .at(100).setAll(.{ .scale = 1, .rotate = 0, .opacity = 1 })
        .easing(.easeOutBack)
        .fill(.both);
}

pub fn zoomOutRotate(name: []const u8) Animation {
    return init(name)
        .at(0).setAll(.{ .scale = 1, .rotate = 0, .opacity = 1 })
        .at(100).setAll(.{ .scale = 0, .rotate = 180, .opacity = 0 })
        .easing(.easeInBack)
        .fill(.both);
}

pub fn build(self: Animation) void {
    if (Vapor.animations == null) return;
    Vapor.animations.?.put(self._name, self) catch |err| {
        Vapor.println("Could not create animation {any}\n", .{err});
    };
}

// Examples:
test "Animation examples" {
    // Single property
    Animation.init("fadeOut")
        .prop(.opacity, 1, 0)
        .build();
    // Output:
    // @keyframes fadeOut {
    // from { opacity: 1; }
    // to { opacity: 0; }
    // }

    // Multiple transforms + opacity
    Animation.init("slideAndFade")
        .prop(.translateX, -50, 0)
        .prop(.opacity, 0, 1)
        .build();
    // Output:
    // @keyframes slideAndFade {
    // from { transform: translateX(-50px); opacity: 0; }
    // to { transform: translateX(0px); opacity: 1; }
    // }

    // Complex: scale + rotate + opacity
    Animation.init("zoomRotate")
        .prop(.scale, 0.5, 1)
        .prop(.rotate, -45, 0)
        .prop(.opacity, 0, 1)
        .build();
    // Output:
    // @keyframes zoomRotate {
    // from { transform: scale(0.5) rotate(-45deg); opacity: 0; }
    // to { transform: scale(1) rotate(0deg); opacity: 1; }
    // }

    // With filters
    Animation.init("blurIn")
        .prop(.blur, 10, 0)
        .prop(.opacity, 0, 1)
        .build();
    // Output:
    // @keyframes blurIn {
    // from { filter: blur(10px); opacity: 0; }
    // to { filter: blur(0px); opacity: 1; }
    // }
}

const AnimationId = u16; // supports 65k unique animations, plenty

const AnimationIntern = struct {
    allocator: Allocator,
    strings: std.array_list.Managed([]const u8),
    lookup: std.StringHashMap(AnimationId),
    ref_counts: std.array_list.Managed(u32),

    pub fn init(allocator: Allocator) AnimationIntern {
        return .{
            .allocator = allocator,
            .strings = std.array_list.Managed([]const u8).init(allocator),
            .lookup = std.StringHashMap(AnimationId).init(allocator),
            .ref_counts = std.array_list.Managed(u32).init(allocator),
        };
    }

    pub fn intern(self: *AnimationIntern, css: []const u8) !AnimationId {
        if (self.lookup.get(css)) |id| {
            self.ref_counts.items[id] += 1;
            return id;
        }

        const owned = try self.allocator.dupe(u8, css);
        const id: AnimationId = @intCast(self.strings.items.len);
        try self.strings.append(owned);
        try self.ref_counts.append(1);
        try self.lookup.put(owned, id);
        return id;
    }

    pub fn get(self: *AnimationIntern, id: AnimationId) ?[]const u8 {
        if (id >= self.strings.items.len) return null;
        return self.strings.items[id];
    }

    pub fn release(self: *AnimationIntern, id: AnimationId) void {
        if (id >= self.ref_counts.items.len) return;
        if (self.ref_counts.items[id] == 0) return;
        self.ref_counts.items[id] -= 1;
        // Optional: cleanup when ref_count hits 0
        // or batch cleanup periodically
    }
};

const PendingRemoval = struct {
    uuid: []const u8,
    node_index: u16,
    animation_id: AnimationId, // 2 bytes instead of duplicated string
    generation: u32, // for staleness detection
};

pub const RemovalQueue = struct {
    allocator: Allocator,
    items: std.array_list.Managed(PendingRemoval),
    animations: AnimationIntern,
    current_generation: u32 = 0,

    pub fn init(allocator: Allocator) void {
        removal_queue = .{
            .allocator = allocator,
            .items = std.array_list.Managed(PendingRemoval).init(allocator),
            .animations = AnimationIntern.init(allocator),
            .current_generation = 0,
        };
    }

    pub fn enqueue(
        self: *RemovalQueue,
        node: *UINode,
        node_index: usize,
    ) !void {
        const has_exit_animation = node.animation_exit != null;

        const anim_id: AnimationId = if (has_exit_animation) blk: {
            const css_ptr = getExitAnimationStyle(node) orelse {
                Vapor.printErr("Exit Animation not found could not ENQUE, Please make sure to Run .build() on the animation", .{});
                break :blk std.math.maxInt(AnimationId);
            };
            const len = StyleCompiler.getAnimationLen();
            break :blk try self.animations.intern(css_ptr[0..len]);
        } else std.math.maxInt(AnimationId); // sentinel for "no animation"

        try self.items.append(.{
            .uuid = node.uuid,
            .node_index = @intCast(node_index),
            .animation_id = anim_id,
            .generation = self.current_generation,
        });
    }

    pub fn getAnimationCss(self: *RemovalQueue, handle: u32) ?[]const u8 {
        if (handle >= self.items.items.len) return null;
        const item = self.items.items[handle];
        if (item.animation_id == std.math.maxInt(AnimationId)) return null;
        return self.animations.get(item.animation_id);
    }

    pub fn getId(self: *RemovalQueue, handle: u32) ?[]const u8 {
        if (handle >= self.items.items.len) return null;
        const item = self.items.items[handle];
        return item.uuid;
    }

    pub fn release(self: *RemovalQueue, handle: u32) void {
        if (handle >= self.items.items.len) return;
        const item = self.items.items[handle];

        // `uuid` is borrowed from the UINode, not owned by this queue, so there
        // is nothing to free here.

        // Decrement animation ref count
        if (item.animation_id != std.math.maxInt(AnimationId)) {
            self.animations.release(item.animation_id);
        }

        // Mark slot as free (or swap-remove if order doesn't matter)
        self.items.items[handle].uuid = ""; // tombstone
    }

    pub fn nextGeneration(self: *RemovalQueue) void {
        self.current_generation += 1;
    }

    pub fn clearRetainingCapacity(self: *RemovalQueue) void {
        self.items.clearRetainingCapacity();
        self.animations.strings.clearRetainingCapacity();
        self.animations.lookup.clearRetainingCapacity();
        self.animations.ref_counts.clearRetainingCapacity();
        self.current_generation = 0;
    }
};

pub var removal_queue: RemovalQueue = undefined;

export fn clearRemovalQueueRetainingCapacity() void {
    removal_queue.clearRetainingCapacity();
}

pub export fn removalCount() usize {
    return removal_queue.items.items.len;
}

pub export fn getRemovalAnimationPtr(handle: u32) ?[*]const u8 {
    const css = removal_queue.getAnimationCss(handle) orelse return null;
    return css.ptr;
}
//
pub export fn getRemovalAnimationLen(handle: u32) usize {
    const css = removal_queue.getAnimationCss(handle) orelse return 0;
    return css.len;
}

pub export fn getRemovalIdPtr(handle: u32) ?[*]const u8 {
    const id = removal_queue.getId(handle) orelse return null;
    return id.ptr;
}

pub export fn getRemovalIdLen(handle: u32) usize {
    const id = removal_queue.getId(handle) orelse return 0;
    return id.len;
}
