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

/// Convenience presets, defined in animation/presets.zig.
const PresetsModule = @import("animation/presets.zig");
pub const fadeIn = PresetsModule.fadeIn;
pub const fadeOut = PresetsModule.fadeOut;
pub const slideInLeft = PresetsModule.slideInLeft;
pub const slideInRight = PresetsModule.slideInRight;
pub const slideInUp = PresetsModule.slideInUp;
pub const slideInDown = PresetsModule.slideInDown;
pub const slideOutLeft = PresetsModule.slideOutLeft;
pub const slideOutRight = PresetsModule.slideOutRight;
pub const slideOutUp = PresetsModule.slideOutUp;
pub const slideOutDown = PresetsModule.slideOutDown;
pub const zoomIn = PresetsModule.zoomIn;
pub const zoomOut = PresetsModule.zoomOut;
pub const spin = PresetsModule.spin;
pub const pulse = PresetsModule.pulse;
pub const bounce = PresetsModule.bounce;
pub const shake = PresetsModule.shake;
pub const shakeY = PresetsModule.shakeY;
pub const wobble = PresetsModule.wobble;
pub const jello = PresetsModule.jello;
pub const heartbeat = PresetsModule.heartbeat;
pub const rubberBand = PresetsModule.rubberBand;
pub const tada = PresetsModule.tada;
pub const swing = PresetsModule.swing;
pub const bounceIn = PresetsModule.bounceIn;
pub const bounceInDown = PresetsModule.bounceInDown;
pub const bounceInUp = PresetsModule.bounceInUp;
pub const flipIn = PresetsModule.flipIn;
pub const flipInX = PresetsModule.flipInX;
pub const rotateIn = PresetsModule.rotateIn;
pub const rollIn = PresetsModule.rollIn;
pub const lightSpeedIn = PresetsModule.lightSpeedIn;
pub const expandIn = PresetsModule.expandIn;
pub const expandInY = PresetsModule.expandInY;
pub const bounceOut = PresetsModule.bounceOut;
pub const bounceOutDown = PresetsModule.bounceOutDown;
pub const bounceOutUp = PresetsModule.bounceOutUp;
pub const flipOut = PresetsModule.flipOut;
pub const rotateOut = PresetsModule.rotateOut;
pub const rollOut = PresetsModule.rollOut;
pub const lightSpeedOut = PresetsModule.lightSpeedOut;
pub const shrinkOut = PresetsModule.shrinkOut;
pub const hinge = PresetsModule.hinge;
pub const flash = PresetsModule.flash;
pub const blink = PresetsModule.blink;
pub const glow = PresetsModule.glow;
pub const float = PresetsModule.float;
pub const sway = PresetsModule.sway;
pub const breathe = PresetsModule.breathe;
pub const pulseShadow = PresetsModule.pulseShadow;
pub const spinPulse = PresetsModule.spinPulse;
pub const pendulum = PresetsModule.pendulum;
pub const morphWidth = PresetsModule.morphWidth;
pub const progressPulse = PresetsModule.progressPulse;
pub const typewriter = PresetsModule.typewriter;
pub const blur = PresetsModule.blur;
pub const unblur = PresetsModule.unblur;
pub const flip3D = PresetsModule.flip3D;
pub const tilt = PresetsModule.tilt;
pub const zoomInRotate = PresetsModule.zoomInRotate;
pub const zoomOutRotate = PresetsModule.zoomOutRotate;

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

const RemovalModule = @import("animation/removal.zig");
comptime {
    _ = RemovalModule;
}
pub const getRemovalAnimationLen = RemovalModule.getRemovalAnimationLen;
pub const getRemovalAnimationPtr = RemovalModule.getRemovalAnimationPtr;
pub const getRemovalIdLen = RemovalModule.getRemovalIdLen;
pub const getRemovalIdPtr = RemovalModule.getRemovalIdPtr;
pub const removalCount = RemovalModule.removalCount;
pub const RemovalQueue = RemovalModule.RemovalQueue;
pub var removal_queue: RemovalQueue = undefined;
