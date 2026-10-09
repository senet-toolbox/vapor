const Writer = @import("../Writer.zig");
const Types = @import("../types.zig");
const Alignment = Types.Alignment;
const Direction = Types.Direction;
const PositionType = Types.PositionType;
const Sizing = Types.Sizing;
const Appearance = Types.Appearance;
const WhiteSpace = Types.WhiteSpace;
const FlexWrap = Types.FlexWrap;
const Pos = Types.Pos;
const FlexType = Types.FlexType;
const TransformOrigin = Types.TransformOrigin;
const Vapor = @import("../Vapor.zig");
const ListStyle = Types.ListStyle;
const PackedTransition = Types.PackedTransition;
const Outline = Types.Outline;
const Cursor = Types.Cursor;

pub const PropValue = struct {
    tag: Tag,
    data: Data,

    // Enum to identify the type
    const Tag = enum {
        position_type,
        direction,
        sizing,
        padding,
        cursor,
        appearance,
        transform_type,
        transform_origin,
        margin,
        pos,
        text_decoration,
        white_space,
        flex_wrap,
        alignment,
        text_alignment,
        layer,
        dots,
        color,
        list_style,
        outline,
        transition,
        shadow,
        border,
        border_radius,
        flex_type,
        string_literal, // For values like "flex", "center", etc.
        opacity,
        font_style,
        aspect_ratio,
        gradient,
        layers,
        background_layers,
        caret,
        resize,
        animation_play_state,
    };

    // Union to hold the actual data
    const Data = union(Tag) {
        position_type: Types.PositionType,
        direction: Types.Direction,
        sizing: Types.Sizing,
        padding: Types.Padding,
        cursor: Types.Cursor,
        appearance: Types.Appearance,
        transform_type: Types.PackedTransform,
        transform_origin: Types.TransformOrigin,
        margin: Types.Margin,
        pos: Types.Pos,
        text_decoration: Types.PackedTextDecoration,
        white_space: Types.WhiteSpace,
        flex_wrap: Types.FlexWrap,
        alignment: Types.Alignment,
        text_alignment: Types.Alignment,
        layer: Types.PackedGrid,
        dots: Types.PackedDots,
        color: Types.PackedColor,
        list_style: Types.ListStyle,
        outline: Types.Outline,
        transition: Types.PackedTransition,
        shadow: Types.PackedShadow,
        border: Types.Border,
        border_radius: Types.BorderRadius,
        flex_type: Types.FlexType,
        string_literal: []const u8,
        opacity: f32,
        font_style: Types.FontStyle,
        aspect_ratio: Types.AspectRatio,
        gradient: Types.PackedGradient,
        layers: Types.PackedLayers,
        background_layers: Types.PackedLayers,
        caret: Types.PackedCaret,
        resize: Types.Resize,
        animation_play_state: Types.AnimationPlayState,
    };
};

/// Writes a CSS property and its value to the writer.
/// This function uses a tagged union (PropValue) to prevent code bloat from monomorphization.
pub fn writePropValue(prop: []const u8, value: PropValue, writer: *Writer) void {
    writer.write(prop) catch return;
    writer.writeByte(':') catch return;

    switch (value.tag) {
        .position_type => positionTypeToCSS(value.data.position_type, writer) catch {},
        .direction => directionToCSS(value.data.direction, writer) catch {},
        .sizing => sizingTypeToCSS(value.data.sizing, writer) catch {},
        .font_style => fontStyleToCSS(value.data.font_style, writer) catch {},
        .padding => {
            writer.writeU8Num(value.data.padding._top) catch {};
            writer.write("px ") catch {};
            writer.writeU8Num(value.data.padding._right) catch {};
            writer.write("px ") catch {};
            writer.writeU8Num(value.data.padding._bottom) catch {};
            writer.write("px ") catch {};
            writer.writeU8Num(value.data.padding._left) catch {};
            writer.write("px") catch {};
        },
        .cursor => cursorToCSS(value.data.cursor, writer) catch {},
        .appearance => appearanceToCSS(value.data.appearance, writer) catch {},
        .transform_type => {
            const slice = Vapor.packed_transforms.get(value.data.transform_type.type_ptr) orelse return;
            const transform = value.data.transform_type;
            for (slice) |t| {
                switch (t) {
                    .scale => {
                        writer.write("scale(") catch {};
                        writer.writeF32(transform.scale_size) catch {};
                        writer.writeByte(')') catch {};
                    },
                    .scaleY => {
                        writer.write("scaleY(") catch {};
                        writer.writeF32(transform.scale_size) catch {};
                        writer.writeByte(')') catch {};
                    },
                    .scaleX => {
                        writer.write("scaleX(") catch {};
                        writer.writeF32(transform.scale_size) catch {};
                        writer.writeByte(')') catch {};
                    },
                    .translateX => {
                        writer.write("translateX(") catch {};
                        writer.writeF32(transform.trans_x) catch {};
                        if (transform.size_type == .percent) {
                            writer.write("%)") catch {};
                        } else if (transform.size_type == .px) {
                            writer.write("px)") catch {};
                        }
                    },
                    .translateY => {
                        writer.write("translateY(") catch {};
                        writer.writeF32(transform.trans_y) catch {};
                        if (transform.size_type == .percent) {
                            writer.write("%)") catch {};
                        } else if (transform.size_type == .px) {
                            writer.write("px)") catch {};
                        }
                    },
                    .rotate => {
                        writer.write("rotate(") catch {};
                        writer.writeF16(transform.deg) catch {};
                        writer.write("deg)") catch {};
                    },
                    .rotateX => {
                        writer.write("rotateX(") catch {};
                        writer.writeF16(transform.deg) catch {};
                        writer.write("deg)") catch {};
                    },
                    .rotateY => {
                        writer.write("rotateY(") catch {};
                        writer.writeF16(transform.deg) catch {};
                        writer.write("deg)") catch {};
                    },
                    .rotateXYZ => {
                        writer.write("rotateX(") catch {};
                        writer.writeF16(transform.x) catch {};
                        writer.write("deg) ") catch {};
                        writer.write("rotateY(") catch {};
                        writer.writeF16(transform.y) catch {};
                        writer.write("deg) ") catch {};
                        writer.write("rotateZ(") catch {};
                        writer.writeF16(transform.z) catch {};
                        writer.write("deg)") catch {};
                    },
                    .none => {},
                }
                writer.writeByte(' ') catch {};
            }
        },
        .transform_origin => transformOriginToCSS(value.data.transform_origin, writer) catch {},
        .margin => {
            writer.writeI16(value.data.margin.top) catch {};
            writer.write("px ") catch {};
            writer.writeI16(value.data.margin.right) catch {};
            writer.write("px ") catch {};
            writer.writeI16(value.data.margin.bottom) catch {};
            writer.write("px ") catch {};
            writer.writeI16(value.data.margin.left) catch {};
            writer.write("px") catch {};
        },
        .pos => posTypeToCSS(value.data.pos, writer) catch {},
        .text_decoration => textDecoToCSS(value.data.text_decoration, writer) catch {},
        .white_space => whiteSpaceToCSS(value.data.white_space, writer) catch {},
        .flex_wrap => flexWrapToCSS(value.data.flex_wrap, writer) catch {},
        .alignment => alignmentToCSS(value.data.alignment, writer) catch {},
        .text_alignment => textAlignmentToCSS(value.data.text_alignment, writer) catch {},
        .layer => gridToCSS(value.data.layer, writer) catch {},
        .dots => dotsToCSS(value.data.dots, writer) catch {},
        .gradient => gradientToCSS(value.data.gradient, writer) catch {},
        .layers => layersToCSS(value.data.layers, writer) catch {},
        .background_layers => backgroundLayersToCSS(value.data.background_layers, writer) catch {},
        .color => colorToCSS(value.data.color, writer) catch {},
        .list_style => listStyleToCSS(value.data.list_style, writer) catch {},
        .outline => outlineStyleToCSS(value.data.outline, writer) catch {},
        .opacity => writer.writeF32(value.data.opacity) catch {},
        .resize => resizeToCSS(value.data.resize, writer) catch {},
        .transition => transitionStyleToCSS(value.data.transition, writer),
        .shadow => {
            const shadow = value.data.shadow;
            writer.writeI16(shadow.left) catch {};
            writer.write("px ") catch {};
            writer.writeI16(shadow.top) catch {};
            writer.write("px ") catch {};
            writer.writeU8Num(shadow.blur) catch {};
            writer.write("px ") catch {};
            writer.writeU8Num(shadow.spread) catch {};
            writer.write("px ") catch {};
            colorToCSS(shadow.color, writer) catch {};
        },
        .border => {
            const border = value.data.border;
            writer.writeU8Num(border._top) catch {};
            writer.write("px ") catch {};
            writer.writeU8Num(border._right) catch {};
            writer.write("px ") catch {};
            writer.writeU8Num(border._bottom) catch {};
            writer.write("px ") catch {};
            writer.writeU8Num(border._left) catch {};
            writer.write("px") catch {};
        },
        .border_radius => {
            const radius = value.data.border_radius;
            if (radius.top_left == radius.top_right and radius.top_left == radius.bottom_right and radius.top_left == radius.bottom_left) {
                writer.writeU16(radius.top_left) catch {};
                writer.write("px") catch {};
            } else {
                writer.writeU16(radius.top_left) catch {};
                writer.write("px ") catch {};
                writer.writeU16(radius.top_right) catch {};
                writer.write("px ") catch {};
                writer.writeU16(radius.bottom_right) catch {};
                writer.write("px ") catch {};
                writer.writeU16(radius.bottom_left) catch {};
                writer.write("px") catch {};
            }
        },
        .flex_type => flexTypeToCSS(value.data.flex_type, writer) catch {},
        .caret => caretToCSS(value.data.caret, writer) catch {},

        .aspect_ratio => aspectRatioToCSS(value.data.aspect_ratio, writer) catch {},
        // This new case handles simple string values efficiently.
        .string_literal => writer.write(value.data.string_literal) catch {},
        .animation_play_state => {
            writer.write(@tagName(value.data.animation_play_state)) catch {};
        },
    }
    writer.write(";\n") catch {};
}

const direction_map = [_][]const u8{ "column", "row" };

const alignment_map = [_][]const u8{ "none", "center", "flex-start", "flex-end", "flex-start", "flex-end", "space-between", "space-evenly", "flex-start", "anchor-start", "anchor-end", "anchor-center" };

const text_alignment_map = [_][]const u8{ "none", "center", "", "", "left", "right", "", "", "", "", "", "" };

const position_type_map = [_][]const u8{ "none", "relative", "absolute", "fixed", "sticky" };

const transform_origin_map = [_][]const u8{ "default", "top", "bottom", "right", "left", "top center", "bottom center", "right center", "left center" };

/// Indexed by @intFromEnum(Types.TextDecorationType) in writeMappedString, which
/// does not bounds-check. Keep in lockstep with that enum.
const text_decoration_type_map = [_][]const u8{ "default", "none", "overline", "underline", "inherit", "initial", "revert", "unset", "line-through", "blink" };

const text_decoration_style_map = [_][]const u8{ "default", "solid", "double", "dotted", "dashed", "wavy", "inherit", "initial", "revert", "unset" };

const appearance_map = [_][]const u8{ "none", "auto", "button", "textfield", "menulist", "searchfield", "textarea", "checkbox", "radio", "inherit", "initial", "revert", "unset" };

const outline_map = [_][]const u8{ "default", "none", "auto", "dotted", "dashed", "solid", "double", "groove", "ridge", "inset", "outset", "inherit", "initial", "revert", "unset" };

const cursor_map = [_][]const u8{ "default", "pointer", "help", "grab", "zoom-in", "zoom-out", "ew-resize", "ns-resize", "col-resize", "row-resize", "all-scroll", "crosshair", "grabbing" };

const list_style_map = [_][]const u8{ "default", "none", "disc", "circle", "square", "decimal", "decimal-leading-zero", "lower-roman", "upper-roman", "lower-alpha", "upper-alpha", "lower-greek", "armenian", "georgian", "inherit", "initial", "revert", "unset" };

const flex_wrap_map = [_][]const u8{ "none", "nowrap", "wrap", "wrap-reverse", "inherit", "initial", "revert", "unset" };

const white_space_map = [_][]const u8{ "default", "normal", "nowrap", "pre", "pre-wrap", "pre-line", "break-spaces", "inherit", "initial", "revert", "unset" };

const flex_type_map = [_][]const u8{
    "default",
    "flex",
    "inline",
    "block",
    "inline-block",
    "none",
};

const font_style_map = [_][]const u8{ "default", "normal", "italic" };

const aspect_ratio_map = [_][]const u8{ "none", "1 / 1", "3 / 4", "16 / 9" };

const caret_map = [_][]const u8{ "none", "block", "line" };

const resize_map = [_][]const u8{ "default", "none", "both", "horizontal", "vertical" };

/// Generic helper to write a CSS string from a pre-defined map based on an enum's value.
/// The `string_map` must have its string literals in the same order as the enum declaration.
inline fn writeMappedString(
    comptime EnumType: type,
    value: EnumType,
    string_map: []const []const u8,
    writer: anytype,
) !void {
    try writer.write(string_map[@intFromEnum(value)]);
}

fn directionToCSS(dir: Direction, writer: *Writer) !void {
    try writeMappedString(Direction, dir, &direction_map, writer);
}

fn alignmentToCSS(_align: Alignment, writer: *Writer) !void {
    try writeMappedString(Alignment, _align, &alignment_map, writer);
}

fn textAlignmentToCSS(_align: Alignment, writer: *Writer) !void {
    try writeMappedString(Alignment, _align, &text_alignment_map, writer);
}

fn positionTypeToCSS(pos_type: PositionType, writer: *Writer) !void {
    try writeMappedString(PositionType, pos_type, &position_type_map, writer);
}

fn fontStyleToCSS(font_style: Types.FontStyle, writer: *Writer) !void {
    try writeMappedString(Types.FontStyle, font_style, &font_style_map, writer);
}

fn transformOriginToCSS(origin: TransformOrigin, writer: anytype) !void {
    try writeMappedString(TransformOrigin, origin, &transform_origin_map, writer);
}

fn aspectRatioToCSS(aspect_ratio: Types.AspectRatio, writer: anytype) !void {
    try writeMappedString(Types.AspectRatio, aspect_ratio, &aspect_ratio_map, writer);
}

fn textDecoToCSS(deco: Types.PackedTextDecoration, writer: anytype) !void {
    try writeMappedString(Types.TextDecorationType, deco.type, &text_decoration_type_map, writer);
    if (deco.style != .default) {
        try writer.writeByte(' ');
        try writeMappedString(Types.TextDecorationStyle, deco.style, &text_decoration_style_map, writer);
    }

    if (deco.color.has_color or deco.color.has_token) {
        try writer.writeByte(' ');
        colorToCSS(deco.color, writer) catch {};
    }
}

fn sizingTypeToCSS(sizing: Sizing, writer: *Writer) !void {
    switch (sizing.type) {
        .fit => try writer.write("fit-content"),
        .grow => try writer.write("flex:1"),
        .auto => try writer.write("auto"),
        .percent => {
            try writer.writeF32(sizing.size.min);
            try writer.writeByte('%');
        },
        .fixed => {
            try writer.writeF32(sizing.size.min);
            try writer.write("px");
        },
        .elastic => try writer.write("auto"), // Could also use min/max width/height in separate properties
        .elastic_percent => {
            try writer.writeF32(sizing.size.min);
            try writer.writeByte('%');
        },
        .clamp_px => {
            try writer.write("clamp(");
            try writer.writeF32(sizing.size.min);
            try writer.write("px,");
            try writer.writeF32(sizing.size.preferred);
            try writer.write("px,");
            try writer.writeF32(sizing.size.max);
            try writer.write("px)");
        },
        .clamp_percent => {
            try writer.write("clamp(");
            try writer.writeF32(sizing.size.min);
            try writer.write("%,");
            try writer.writeF32(sizing.size.preferred);
            try writer.write("%,");
            try writer.writeF32(sizing.size.max);
            try writer.write("%)");
        },
        .none => {},
        else => {},
    }
}

fn posTypeToCSS(pos: Pos, writer: *Writer) !void {
    switch (pos.type) {
        .fit => try writer.write("fit-content"),
        .grow => try writer.write("auto"),
        .percent => {
            try writer.writeF32(pos.value);
            try writer.writeByte('%');
        },
        .fixed => {
            try writer.writeF32(pos.value);
            try writer.write("px");
        },
        else => {},
    }
}

pub fn colorToCSS(color: Types.PackedColor, writer: *Writer) !void {
    if (color.has_color) {
        writeRgba(writer, color.color) catch {};
    } else if (color.has_token) {
        writeThematic(writer, color.token) catch {};
    }
}

pub fn writeThematic(writer: anytype, thematic: Types.Thematic) !void {
    if (thematic.alpha > -1) {
        if (thematic.darken) {
            writer.write("color-mix(in srgb, ") catch {};

            try writer.write("rgb(var(--");
            try writer.write(@tagName(thematic.token));
            try writer.write("))");

            writer.write(", black ") catch {};
            writer.writeF32(thematic.alpha * 100) catch {};
            writer.write("%);\n") catch {};
        } else {
            try writer.write("rgba(");
            try writer.write("var(--");
            try writer.write(@tagName(thematic.token));
            try writer.write("), ");
            try writer.writeF32(thematic.alpha);
            try writer.writeByte(')');
        }
    } else {
        try writer.write("rgb(var(--");
        try writer.write(@tagName(thematic.token));
        try writer.write("))");
    }
}

pub fn writeRgba(writer: anytype, rgba: Types.Rgba) !void {
    if (rgba.a == 1) {
        try writer.write("rgb(");
        try writer.writeU8Num(rgba.r);
        try writer.writeByte(',');
        try writer.writeU8Num(rgba.g);
        try writer.writeByte(',');
        try writer.writeU8Num(rgba.b);
        try writer.writeByte(')');
    } else {
        try writer.write("rgba(");
        try writer.writeU8Num(rgba.r);
        try writer.writeByte(',');
        try writer.writeU8Num(rgba.g);
        try writer.writeByte(',');
        try writer.writeU8Num(rgba.b);
        try writer.writeByte(',');
        try writer.writeF32(rgba.a);
        try writer.writeByte(')');
    }
}

const BackgroundModule = @import("background.zig");
const gridToCSS = BackgroundModule.gridToCSS;
const dotsToCSS = BackgroundModule.dotsToCSS;
const gradientToCSS = BackgroundModule.gradientToCSS;
const backgroundLayersToCSS = BackgroundModule.backgroundLayersToCSS;
const layersToCSS = BackgroundModule.layersToCSS;

fn appearanceToCSS(appearance: Appearance, writer: anytype) !void {
    try writeMappedString(Appearance, appearance, &appearance_map, writer);
}

fn outlineStyleToCSS(outline: Outline, writer: anytype) !void {
    try writeMappedString(Outline, outline, &outline_map, writer);
}

fn transitionStyleToCSS(style: PackedTransition, writer: *Writer) void {
    const properties = Vapor.packed_transitions.get(style.properties_ptr) orelse return;
    for (properties, 0..) |p, i| {
        switch (p) {
            .none => {
                writer.writeU32(style.duration) catch return;
                writer.write("ms ") catch return;
                // try writeMappedString(TimingFunction, style.timing, &timing_function_map, writer);
                const css = style.timing.toCss();
                writer.write(css) catch return;
            },
            else => {
                const tag_name = @tagName(p);
                writer.write(tag_name) catch return;
                writer.write(" ") catch return;
                writer.writeU32(style.duration) catch return;
                writer.write("ms ") catch return;
                // try writeMappedString(TimingFunction, style.timing, &timing_function_map, writer);
                const css = style.timing.toCss();
                writer.write(css) catch return;
            },
        }
        if (i < properties.len - 1) {
            writer.write(", ") catch return;
        }
    }
}

fn cursorToCSS(cursor_type: Cursor, writer: anytype) !void {
    try writeMappedString(Cursor, cursor_type, &cursor_map, writer);
}

fn caretToCSS(caret: Types.PackedCaret, writer: anytype) !void {
    colorToCSS(caret.color, writer) catch {};
    writer.write(";\n") catch {};

    writer.write("caret-shape: ") catch {};
    try writeMappedString(Types.CaretType, caret.type, &caret_map, writer);
    writer.write(";\n") catch {};
}

fn resizeToCSS(resize: Types.Resize, writer: anytype) !void {
    try writeMappedString(Types.Resize, resize, &resize_map, writer);
}

fn listStyleToCSS(list_style: ListStyle, writer: anytype) !void {
    try writeMappedString(ListStyle, list_style, &list_style_map, writer);
}

fn flexWrapToCSS(flex_wrap: FlexWrap, writer: anytype) !void {
    try writeMappedString(FlexWrap, flex_wrap, &flex_wrap_map, writer);
}

fn whiteSpaceToCSS(white_space: WhiteSpace, writer: anytype) !void {
    try writeMappedString(WhiteSpace, white_space, &white_space_map, writer);
}

fn flexTypeToCSS(flex_type: FlexType, writer: anytype) !void {
    try writeMappedString(FlexType, flex_type, &flex_type_map, writer);
}
