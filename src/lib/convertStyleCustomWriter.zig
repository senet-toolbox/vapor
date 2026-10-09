const std = @import("std");
const mem = std.mem;
const Types = @import("types.zig");
const Alignment = Types.Alignment;
const Direction = Types.Direction;
const PositionType = Types.PositionType;
const FloatType = Types.FloatType;
const UINode = @import("UITree.zig").UINode;
const Sizing = Types.Sizing;
const Transform = Types.Transform;
const TextDecoration = Types.TextDecoration;
const Appearance = Types.Appearance;
const WhiteSpace = Types.WhiteSpace;
const FlexWrap = Types.FlexWrap;
const BoxSizing = Types.BoxSizing;
const Pos = Types.Pos;
const PosType = Types.PosType;
const FlexType = Types.FlexType;
const TransformOrigin = Types.TransformOrigin;
const Vapor = @import("Vapor.zig");
const Animation = Vapor.Animation;
const ListStyle = Types.ListStyle;
const Transition = Types.Transition;
const PackedTransition = Types.PackedTransition;
const TimingFunction = Animation.Easing;
const Outline = Types.Outline;
const Cursor = Types.Cursor;
const Color = Types.Color;
const Writer = @import("Writer.zig");
const Theme = @import("theme");
const StringTable = @import("StringTable.zig").StringTable;
const Edges = @import("Edges.zig").Edges;
const KeyGenerator = @import("Key.zig").KeyGenerator;

pub const writer_t = *Writer;
// Global buffer to store the CSS string for returning to JavaScript
pub var css_buffer: [4096]u8 = undefined;

const ValuesModule = @import("css/values.zig");
pub const writePropValue = ValuesModule.writePropValue;
pub const colorToCSS = ValuesModule.colorToCSS;

pub fn writeStyleField(field: Types.StyleFields, visual: *const Types.PackedVisual, writer: writer_t) void {
    switch (field) {
        .border => {
            if (visual.has_border_thickeness) {
                const border_thickness = visual.border_thickness;
                writePropValue("border-width", .{ .tag = .border, .data = .{ .border = border_thickness } }, writer);
                writer.write("border-style: solid;\n") catch {};
            }
            if (visual.has_border_color) {
                const border_color = visual.border_color;
                writePropValue("border-color", .{ .tag = .color, .data = .{ .color = border_color } }, writer);
            }
            if (visual.has_border_radius) {
                const border_radius = visual.border_radius;
                writePropValue("border-radius", .{ .tag = .border_radius, .data = .{ .border_radius = border_radius } }, writer);
            }
        },
        .text_color => {
            if (visual.text_color.has_color or visual.text_color.has_token) {
                const color = visual.text_color;
                writePropValue("color", .{ .tag = .color, .data = .{ .color = color } }, writer);
            }
        },
        .fill => {
            if (visual.fill.has_color or visual.fill.has_token) {
                const color = visual.fill;
                writePropValue("fill", .{ .tag = .color, .data = .{ .color = color } }, writer);
            }
        },
        .stroke => {
            if (visual.stroke.has_color or visual.stroke.has_token) {
                const color = visual.stroke;
                writePropValue("stroke", .{ .tag = .color, .data = .{ .color = color } }, writer);
            }
        },
        .background => {
            if (visual.background.has_color or visual.background.has_token) {
                const color = visual.background;
                writePropValue("background", .{ .tag = .color, .data = .{ .color = color } }, writer);
            }
        },
        .animation_play_state => {
            if (visual.animation_play_state != .none) {
                writePropValue("animation-play-state", .{ .tag = .animation_play_state, .data = .{ .animation_play_state = visual.animation_play_state } }, writer);
            }
        },
        else => {
            Vapor.printlnErr("StyleField not implemented {any}", .{field});
            @panic("vapor: StyleField not implemented");
        },
    }
}

pub fn generateVisual(visual: *const Types.PackedVisual, writer: writer_t) void {
    // Color color
    if (visual.background.has_color or visual.background.has_token) {
        writePropValue("background-color", .{ .tag = .color, .data = .{ .color = visual.background } }, writer);
    } else if (visual.background_layers.len > 0) {
        writePropValue("background", .{ .tag = .background_layers, .data = .{ .background_layers = visual.background_layers } }, writer);
    }

    if (visual.packed_layers.items_ptr > 0) {
        writePropValue("background-image", .{ .tag = .layers, .data = .{ .layers = visual.packed_layers } }, writer);

        if (visual.is_text_gradient) {
            writer.write("background-clip: text;\n") catch {};
            writer.write("-webkit-background-clip: text;\n") catch {};
            writer.write("-webkit-text-fill-color: transparent;\n") catch {};
        }
    }

    if (visual.blur > 0) {
        writer.write("backdrop-filter:blur(") catch {};
        writer.writeU8Num(visual.blur) catch {};
        writer.write("px);\n") catch {};
    }

    if (visual.cursor != .default) {
        writePropValue("cursor", .{ .tag = .cursor, .data = .{ .cursor = visual.cursor } }, writer);
    }

    // Write font properties
    if (visual.font_size > 0) {
        writer.write("font-size:") catch {};
        writer.writeU8Num(visual.font_size) catch {};
        writer.write("px;\n") catch {};
    }

    if (visual.ellipsis != .none) {
        switch (visual.ellipsis) {
            .dot => {
                writer.write("text-overflow: ellipsis;\n") catch {};
                writer.write("overflow: hidden;\n") catch {};
                writer.write("white-space: nowrap;\n") catch {};
            },
            .dash => {
                writer.write("text-overflow: ---;\n") catch {};
                writer.write("overflow: hidden;\n") catch {};
                writer.write("white-space: nowrap;\n") catch {};
            },
            else => {},
        }
    }

    if (visual.font_family_handle != StringTable.null_handle) {
        const font_family = Vapor.string_table.get(visual.font_family_handle);
        if (font_family) |name| {
            writer.write("font-family:") catch {};
            writer.write(name) catch {};
            writer.write(";\n") catch {};
        }
    }

    if (visual.fill.has_color or visual.fill.has_token) {
        writePropValue("fill", .{ .tag = .color, .data = .{ .color = visual.fill } }, writer);
    }

    if (visual.stroke.has_color or visual.stroke.has_token) {
        writePropValue("stroke", .{ .tag = .color, .data = .{ .color = visual.stroke } }, writer);
    }

    if (visual.font_weight > 0) {
        writer.write("font-weight:") catch {};
        writer.writeU16(visual.font_weight) catch {};
        writer.write(";\n") catch {};
    }

    if (visual.font_style != .default) {
        writePropValue("font-style", .{ .tag = .font_style, .data = .{ .font_style = visual.font_style } }, writer);
    }

    if (visual.has_border_thickeness) {
        const border_thickness = visual.border_thickness;
        writePropValue("border-width", .{ .tag = .border, .data = .{ .border = border_thickness } }, writer);
    }

    if (visual.has_border_color) {
        const border_color = visual.border_color;
        writePropValue("border-color", .{ .tag = .color, .data = .{ .color = border_color } }, writer);
    }
    if (visual.has_border_radius) {
        const border_radius = visual.border_radius;
        writePropValue("border-radius", .{ .tag = .border_radius, .data = .{ .border_radius = border_radius } }, writer);
    }

    if (visual.border_style != .default) {
        writer.write("border-style: ") catch {};
        writer.write(@tagName(visual.border_style)) catch {};
        writer.write(";\n") catch {};
    }

    // Text color
    if (visual.text_color.has_color or visual.text_color.has_token) {
        const color = visual.text_color;
        writePropValue("color", .{ .tag = .color, .data = .{ .color = color } }, writer);
    }

    if (visual.list_style != .default) {
        writePropValue("list-style", .{ .tag = .list_style, .data = .{ .list_style = visual.list_style } }, writer);
    }

    if (visual.outline != .default) {
        writePropValue("outline", .{ .tag = .outline, .data = .{ .outline = visual.outline } }, writer);
    }

    if (visual.has_outline_color) {
        const outline_color = visual.outline_color;
        writePropValue("outline-color", .{ .tag = .color, .data = .{ .color = outline_color } }, writer);
    }

    // Shadow
    // if (visual.shadow.blur > 0 or visual.shadow.spread > 0 or
    //     visual.shadow.top != 0 or visual.shadow.left != 0)
    // {
    //     writePropValue("box-shadow", .{ .tag = .shadow, .data = .{ .shadow = visual.shadow } }, writer);
    // }

    if (visual.text_shadow > 0) blk: {
        const shadow = Vapor.shadows.get(visual.text_shadow) orelse {
            std.log.err("Could not aqurie shadow", .{});
            break :blk;
        };
        writer.write("text-shadow:") catch {};
        shadow.writeCss(writer) catch {};
        writer.write(";") catch {};
    }

    if (visual.new_shadow > 0) blk: {
        const shadow = Vapor.shadows.get(visual.new_shadow) orelse {
            std.log.err("Could not aqurie shadow", .{});
            break :blk;
        };
        writer.write("box-shadow:") catch {};
        shadow.writeCss(writer) catch {};
        writer.write(";") catch {};
    }

    // Text-Deco
    if (visual.text_decoration.type != .default) {
        writePropValue("text-decoration", .{ .tag = .text_decoration, .data = .{ .text_decoration = visual.text_decoration } }, writer);
    }

    // Transform
    if (visual.has_opacity) {
        writePropValue("opacity", .{ .tag = .opacity, .data = .{ .opacity = visual.opacity } }, writer);
    }

    if (visual.has_white_space) {
        writePropValue("white-space", .{ .tag = .white_space, .data = .{ .white_space = visual.white_space } }, writer);
    }

    if (visual.has_transitions and visual.transitions.properties_ptr > 0) {
        writePropValue("transition", .{ .tag = .transition, .data = .{ .transition = visual.transitions } }, writer);
    }

    // There is experimental support for caret type ie block or line
    if (visual.caret.type != .none) {
        writePropValue("caret-color", .{ .tag = .caret, .data = .{ .caret = visual.caret } }, writer);
    }

    if (visual.resize != .default) {
        writePropValue("resize", .{ .tag = .resize, .data = .{ .resize = visual.resize } }, writer);
    }

    if (visual.animation_name_handle != StringTable.null_handle) {
        const animation_name = Vapor.string_table.get(visual.animation_name_handle);
        if (animation_name) |name| {
            writer.write("animation-name:") catch {};
            writer.write(name) catch {};
            writer.write(";\n") catch {};
        }
    }

    if (visual.animation != StringTable.null_handle) blk: {
        if (Vapor.string_table.get(visual.animation)) |name| {
            if (Vapor.animations == null) {
                Vapor.printlnErr("animations map not found, please remember to run Animations.new()", .{});
                break :blk;
            }
            const animation = Vapor.animations.?.get(name) orelse {
                Vapor.printlnSrcErr("Animations stringtable not found, please remember to run .build() on the animation within init, ensure Animations.new() is called before build", .{}, @src());
                return;
            };
            writer.write("animation:") catch {};
            generateAnimation(&animation, writer);
            writer.write(";\n") catch {};
        }
    }

    if (visual.animation_play_state != .none) {
        writePropValue("animation-play-state", .{ .tag = .animation_play_state, .data = .{ .animation_play_state = visual.animation_play_state } }, writer);
    }

    if (visual.color_mix.color_prop != .default) {
        switch (visual.color_mix.color_prop) {
            .text_color => writer.write("color: ") catch {},
            .background_color => writer.write("background-color: ") catch {},
            .border_color => writer.write("border-color: ") catch {},
            .fill_color => writer.write("fill: ") catch {},
            .stroke_color => writer.write("stroke: ") catch {},
            .default => unreachable,
        }
        writer.write("color-mix(in srgb, ") catch {};
        colorToCSS(visual.color_mix.color, writer) catch {};
        writer.write(", black ") catch {};
        writer.writeF32(visual.color_mix.percentage * 100) catch {};
        writer.write("%);\n") catch {};
    }
}

// Export this function to be called from JavaScript to get the CSS representation
pub var style_style: []const u8 = "";
pub var show_scrollbar: bool = true;
// 61.8kb before this function
// adds 20kb

pub fn generateLayout(layout_ptr: *const Types.PackedLayout, writer: *Writer) void {
    var parent_direction_row: bool = true;
    if (layout_ptr.parent_direction == .column) {
        parent_direction_row = false;
    }
    const layout = layout_ptr.layout;
    const placement = layout_ptr.placement;
    const direction = layout_ptr.direction;

    if (layout_ptr.flex == .hidden) {
        writePropValue("display", .{ .tag = .flex_type, .data = .{ .flex_type = layout_ptr.flex } }, writer);
        writePropValue("flex-direction", .{ .tag = .direction, .data = .{ .direction = direction } }, writer);
    } else if (layout_ptr.flex != .default) {
        writePropValue("display", .{ .tag = .flex_type, .data = .{ .flex_type = layout_ptr.flex } }, writer);
        writePropValue("flex-direction", .{ .tag = .direction, .data = .{ .direction = direction } }, writer);
    }
    if (layout.x != .none and layout.y != .none) {
        if (direction == .row) {
            writePropValue("justify-content", .{ .tag = .alignment, .data = .{ .alignment = layout.x } }, writer);
            writePropValue("align-items", .{ .tag = .alignment, .data = .{ .alignment = layout.y } }, writer);
        } else {
            writePropValue("align-items", .{ .tag = .alignment, .data = .{ .alignment = layout.x } }, writer);
            writePropValue("justify-content", .{ .tag = .alignment, .data = .{ .alignment = layout.y } }, writer);
        }
    } else if (layout_ptr.text_align.x != .none) {
        writePropValue("text-align", .{ .tag = .text_alignment, .data = .{ .text_alignment = layout_ptr.text_align.x } }, writer);
    }

    if (placement != .none) {
        writer.write("position: fixed; position-area: ") catch {};
        writer.write(placement.toPositionArea()) catch {};
        writer.write("; ") catch {};
    }

    // Alignment
    if (layout_ptr.spacing > 0) {
        writer.write("gap:") catch {};
        writer.writeU8Num(layout_ptr.spacing) catch {};
        writer.write("px;\n") catch {};
    }

    const size = layout_ptr.size;
    if (size.width.type != .none and size.width.type != .grow) {
        if (size.width.type == .clamp_px) {
            writer.write("max-width:") catch {};
            writer.writeF32(size.width.size.max) catch {};
            writer.write("px;\n") catch {};

            writer.write("min-width:") catch {};
            writer.writeF32(size.width.size.min) catch {};
            writer.write("px;\n") catch {};

            writer.write("width: fit-content;\n") catch {};
        } else if (size.width.type == .min_max_vp) {
            writer.write("max-width:") catch {};
            writer.writeF32(size.width.size.max) catch {};
            writer.write("vw;\n") catch {};
            writer.write("min-width:") catch {};
            writer.writeF32(size.width.size.max) catch {};
            writer.write("vw;\n") catch {};
        } else if (size.width.type == .max_px) {
            writer.write("max-width:") catch {};
            writer.writeF32(size.width.size.max) catch {};
            writer.write("px;\n") catch {};
        } else if (size.width.type == .min_percent) {
            writer.write("min-width:") catch {};
            writer.writeF32(size.width.size.min) catch {};
            writer.write("%;\n") catch {};
        } else if (size.width.type == .min_px) {
            writer.write("min-width:") catch {};
            writer.writeF32(size.width.size.min) catch {};
            writer.write("px;\n") catch {};
        } else if (size.width.type == .vp) {
            writer.write("width:") catch {};
            writer.writeF32(size.width.size.min) catch {};
            writer.write("vw;\n") catch {};
        } else if (size.width.type == .elastic_percent) {
            writer.write("max-width:") catch {};
            writer.writeF32(size.width.size.max) catch {};
            writer.write("%;\n") catch {};
            writer.write("min-width:") catch {};
            writer.writeF32(size.width.size.max) catch {};
            writer.write("%;\n") catch {};
        } else if (size.width.type == .elastic) {
            writer.write("max-width:") catch {};
            writer.writeF32(size.width.size.max) catch {};
            writer.write("px;\n") catch {};
            writer.write("min-width:") catch {};
            writer.writeF32(size.width.size.min) catch {};
            writer.write("px;\n") catch {};
        } else {
            if (layout_ptr.column_count > 0) {
                writer.write("flex-shrink: 1; flex-grow: 1; flex-basis: calc(") catch {};
                writer.writeF32(size.width.size.max) catch {};
                writer.write("% - ") catch {};
                writer.writeF32(layout_ptr.column_spacing) catch {};
                writer.write("px);\n") catch {};
            } else {
                writePropValue("width", .{ .tag = .sizing, .data = .{ .sizing = size.width } }, writer);
            }
        }

        if (layout_ptr.flex != .default and layout_ptr.column_count == 0) {
            writer.write("flex-shrink: 0;\n") catch {};
        }
    } else if (size.width.type == .grow) {
        if (parent_direction_row) {
            writer.write("flex: 1;\nmin-width: 0;\n") catch {};
        } else {
            writer.write("align-self: stretch;\n") catch {};
        }
    }

    if (size.height.type != .none and size.height.type != .grow) {
        if (size.height.type == .clamp_px) {
            writer.write("max-height:") catch {};
            writer.writeF32(size.height.size.max) catch {};
            writer.write("px;\n") catch {};
            writer.write("height:") catch {};
            writer.writeF32(size.height.size.preferred) catch {};
            writer.write("px;\n") catch {};
            writer.write("min-height:") catch {};
            writer.writeF32(size.height.size.min) catch {};
            writer.write("px;\n") catch {};
        } else if (size.height.type == .max_px) {
            writer.write("max-height:") catch {};
            writer.writeF32(size.height.size.max) catch {};
            writer.write("px;\n") catch {};
        } else if (size.height.type == .min_percent) {
            writer.write("min-height:") catch {};
            writer.writeF32(size.height.size.min) catch {};
            writer.write("%;\n") catch {};
        } else if (size.height.type == .min_px) {
            writer.write("min-height:") catch {};
            writer.writeF32(size.height.size.min) catch {};
            writer.write("px;\n") catch {};
        } else if (size.height.type == .vp) {
            writer.write("height:") catch {};
            writer.writeF32(size.height.size.min) catch {};
            writer.write("vh;\n") catch {};
        } else if (size.height.type == .min_max_vp) {
            writer.write("min-height:") catch {};
            writer.writeF32(size.height.size.min) catch {};
            writer.write("vh;\n") catch {};
            writer.write("max-height:") catch {};
            writer.writeF32(size.height.size.max) catch {};
            writer.write("vh;\n") catch {};
        } else if (size.height.type == .elastic) {
            writer.write("max-height:") catch {};
            writer.writeF32(size.height.size.max) catch {};
            writer.write("px;\n") catch {};
            writer.write("height: auto;\n") catch {};
            writer.write("min-height:") catch {};
            writer.writeF32(size.height.size.min) catch {};
            writer.write("px;\n") catch {};
        } else {
            writePropValue("height", .{ .tag = .sizing, .data = .{ .sizing = size.height } }, writer);
        }

        if (layout_ptr.flex != .default) {
            writer.write("flex-shrink: 0;\n") catch {};
        }
    } else if (size.height.type == .grow) {
        if (parent_direction_row) {
            writer.write("align-self: stretch;\n") catch {};
        } else {
            writer.write("flex: 1;\nmin-height: 0;\n") catch {};
        }
    }
    const scroll = layout_ptr.scroll;
    switch (scroll.x) {
        .scroll => writer.write("overflow-x:scroll;\n") catch {},
        .hidden => writer.write("overflow-x:hidden;\n") catch {},
        else => {},
    }
    switch (scroll.y) {
        .scroll => writer.write("overflow-y:scroll;\n") catch {},
        .hidden => writer.write("overflow-y:hidden;\n") catch {},
        else => {},
    }
    if (layout_ptr.flex_wrap != .none) {
        writePropValue("flex-wrap", .{ .tag = .flex_wrap, .data = .{ .flex_wrap = layout_ptr.flex_wrap } }, writer);
    }

    if (layout_ptr.aspect_ratio != .none) {
        writePropValue("aspect-ratio", .{ .tag = .aspect_ratio, .data = .{ .aspect_ratio = layout_ptr.aspect_ratio } }, writer);
    }
}

pub fn generatePositions(position: *const Types.PackedPosition, writer: *Writer) void {
    if (position.position_type != .none) {
        writePropValue("position", .{ .tag = .position_type, .data = .{ .position_type = position.position_type } }, writer);
    }
    if (position.top.type != .none) {
        writePropValue("top", .{ .tag = .pos, .data = .{ .pos = position.top } }, writer);
    }
    if (position.right.type != .none) {
        writePropValue("right", .{ .tag = .pos, .data = .{ .pos = position.right } }, writer);
    }
    if (position.bottom.type != .none) {
        writePropValue("bottom", .{ .tag = .pos, .data = .{ .pos = position.bottom } }, writer);
    }
    if (position.left.type != .none) {
        writePropValue("left", .{ .tag = .pos, .data = .{ .pos = position.left } }, writer);
    }

    if (position.anchor_name_handle != StringTable.null_handle) {
        const anchor_name = Vapor.string_table.get(position.anchor_name_handle);
        if (anchor_name) |name| {
            writer.write("anchor-name:--") catch {};
            writer.write(name) catch {};
            writer.write(";\n") catch {};
        }
    }

    if (position.position_anchor_handle != StringTable.null_handle) {
        const anchor_name = Vapor.string_table.get(position.position_anchor_handle);
        if (anchor_name) |name| {
            writer.write("position-anchor:--") catch {};
            writer.write(name) catch {};
            writer.write(";\n") catch {};
        }
    }

    if (position.z_index > 0) {
        writer.write("z-index:") catch {};
        writer.writeI16(position.z_index) catch {};
        writer.write(";\n") catch {};
    }
}

pub fn generateMarginsPadding(margin_paddings_ptr: *const Types.PackedMarginsPaddings, writer: *Writer) void {
    writePropValue("padding", .{ .tag = .padding, .data = .{ .padding = margin_paddings_ptr.padding } }, writer);
    writePropValue("margin", .{ .tag = .margin, .data = .{ .margin = margin_paddings_ptr.margin } }, writer);
}

pub fn generateAnimations(animations: *const Types.PackedAnimations, writer: anytype) void {
    if (animations.has_animation_enter) {
        if (Vapor.string_table.get(animations.animation_enter)) |name| anim: {
            const animation = (if (Vapor.animations) |a| a.get(name) else null) orelse {
                Vapor.printlnErr("animation '{s}' is not defined; register it with Vapor.Animation before using it", .{name});
                break :anim;
            };
            writer.write("animation:") catch {};
            generateAnimation(&animation, writer);
            writer.write(";\n") catch {};
        }
    }
}

pub fn generateTransforms(transform_ptr: *const Types.PackedTransforms, writer: anytype) void {
    if (transform_ptr.has_transform and transform_ptr.transform.type_ptr > 0) {
        writePropValue("transform", .{ .tag = .transform_type, .data = .{ .transform_type = transform_ptr.transform } }, writer);
    }

    if (transform_ptr.transform_origin != .default) {
        writePropValue("transform-origin", .{ .tag = .transform_origin, .data = .{ .transform_origin = transform_ptr.transform_origin } }, writer);
    }
}

const ExportsModule = @import("css/exports.zig");
comptime {
    _ = ExportsModule;
}
pub const getResponsiveStyle = ExportsModule.getResponsiveStyle;
pub const getStyle = ExportsModule.getStyle;
pub const getGlobalVariablesPtr = ExportsModule.getGlobalVariablesPtr;
pub const getGlobalVariablesLen = ExportsModule.getGlobalVariablesLen;
pub const getVisualStyle = ExportsModule.getVisualStyle;
pub const getExitAnimationStyle = ExportsModule.getExitAnimationStyle;
pub const getAnimationLen = ExportsModule.getAnimationLen;
pub const getAnimationsPtr = ExportsModule.getAnimationsPtr;
pub const getAnimationsLen = ExportsModule.getAnimationsLen;

pub fn generateStylePass(ptr: ?*UINode, writer: *Writer) void {
    const node_ptr = ptr orelse return;
    const packed_field_ptrs = node_ptr.packed_field_ptrs orelse return;
    // Use a fixed buffer with a fbs to build the CSS string

    if (packed_field_ptrs.layout_ptr) |layout_ptr| {
        generateLayout(layout_ptr, writer);
    }

    if (packed_field_ptrs.position_ptr) |position_ptr| {
        generatePositions(position_ptr, writer);

        if (node_ptr.type == .Anchor) {
            const anchor_name = Vapor.string_table.get(position_ptr.anchor_name_handle);
            if (anchor_name) |name| {
                writer.write("position-anchor:--") catch {};
                writer.write(name) catch {};
                writer.write(";\n") catch {};
            }
        }
    }

    if (packed_field_ptrs.margins_paddings_ptr) |margin_paddings_ptr| {
        generateMarginsPadding(margin_paddings_ptr, writer);
    }

    if (packed_field_ptrs.visual_ptr) |visual_ptr| {
        generateVisual(visual_ptr, writer);
    }
}

pub fn generateAnimation(animation: *const Animation, writer: *Writer) void {
    writer.write(animation._name) catch {};
    writer.writeByte(' ') catch {};
    writer.writeU32(animation.duration_ms) catch {};
    writer.write("ms ") catch {};
    writer.write(animation.easing_fn.toCss()) catch {};
    writer.writeByte(' ') catch {};
    writer.write(animation.direction.toCss()) catch {};
    writer.writeByte(' ') catch {};
    if (animation.iteration_count) |count| {
        writer.writeByte(' ') catch {};
        writer.writeU32(count) catch {};
    } else {
        writer.write(" infinite") catch {};
    }

    if (animation.delay_ms > 0) {
        writer.writeByte(' ') catch {};
        writer.writeU32(animation.delay_ms) catch {};
        writer.write("ms ") catch {};
    }
}

pub const Catalog = struct {
    themes: []const Types.ThemeDefinition,
};

pub var global_style: []const u8 = "";
var global_buffer: [4096]u8 = undefined;
var has_default: bool = false;
pub fn setGlobalStyleVariables(catalog: Catalog) void {
    const theme_fields = @typeInfo(Theme.Colors).@"struct".fields;
    var writer: Writer = undefined;
    writer.init(&global_buffer);

    for (catalog.themes) |theme_def| {
        const name = theme_def.name;
        const theme = theme_def.theme;
        if (theme_def.default and has_default) {
            Vapor.printlnErr("Theme {s} is default, but another theme is also default", .{name});
            return;
        }
        if (theme_def.default) {
            has_default = true;
            writer.write(":root") catch {};
        } else {
            // here we write the root theme
            writer.write("[data-theme=") catch {};
            writer.writeByte('"') catch {};
            writer.write(name) catch {};
            writer.writeByte('"') catch {};
            writer.write("]") catch {};
        }
        writer.write(" {\n") catch {};

        inline for (theme_fields) |field| {
            const field_value = @field(theme, field.name);
            const field_name = field.name;
            const field_type = field.type;
            switch (field_type) {
                []const u8 => {
                    writer.write("--") catch {};
                    writer.write(field_name) catch {};
                    writer.writeByte(':') catch {};
                    writer.write(field_value) catch {};
                    writer.write(";\n") catch {};
                },
                Color => {
                    writer.write("--") catch {};
                    writer.write(field_name) catch {};
                    writer.writeByte(':') catch {};
                    writer.writeU8Num(field_value.Literal.r) catch {};
                    writer.writeByte(',') catch {};
                    writer.writeU8Num(field_value.Literal.g) catch {};
                    writer.writeByte(',') catch {};
                    writer.writeU8Num(field_value.Literal.b) catch {};
                    writer.writeByte(';') catch {};
                    writer.write(";\n") catch {};
                },
                else => {},
            }
        }
        writer.write("}\n") catch {};
    }
    const len: usize = writer.pos;
    global_buffer[len] = 0;
    global_style = global_buffer[0..len];
}

pub var animations_str: []const u8 = "";

const KeyframesModule = @import("css/keyframes.zig");
pub const generateAnimationsFrames = KeyframesModule.generateAnimationsFrames;
