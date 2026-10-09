//! Style getters the JS runtime calls. Each writes a node's CSS into a
//! shared buffer and returns a pointer; the matching `get*Len` returns its length.

const StyleCompiler = @import("../convertStyleCustomWriter.zig");
const UINode = @import("../UITree.zig").UINode;
const Vapor = @import("../Vapor.zig");
const Writer = @import("../Writer.zig");
const StringTable = @import("../StringTable.zig").StringTable;
const KeyGenerator = @import("../Key.zig").KeyGenerator;
const writePropValue = @import("values.zig").writePropValue;
const generateAnimationsFrames = @import("keyframes.zig").generateAnimationsFrames;

var transform_style: []const u8 = "";

export fn getTransformsStyle(ptr: ?*UINode) ?[*]const u8 {
    const node_ptr = ptr orelse return null;
    const packed_fields = node_ptr.packed_field_ptrs orelse return null;
    const transform_ptr = packed_fields.transforms_ptr orelse return null;
    var writer: Writer = undefined;
    writer.init(&StyleCompiler.css_buffer);
    StyleCompiler.generateTransforms(transform_ptr, &writer);

    // Null-terminate the string
    const len: usize = writer.pos;
    StyleCompiler.css_buffer[len] = 0;
    transform_style = StyleCompiler.css_buffer[0..len];

    // Return a pointer to the CSS string
    return transform_style.ptr;
}

export fn getTransformsLen() usize {
    return transform_style.len;
}

pub export fn getResponsiveStyle(ptr: ?*UINode) ?[*]const u8 {
    const node_ptr = ptr orelse return null;
    const packed_field_ptrs = node_ptr.packed_field_ptrs orelse return null;
    // Use a fixed buffer with a fbs to build the CSS string
    var writer: Writer = undefined;
    writer.init(&StyleCompiler.css_buffer);
    const value_ptr = packed_field_ptrs.responsive_ptr orelse return null;

    var buf: [128]u8 = undefined;
    const common_key = KeyGenerator.generateHashKey(&buf, node_ptr.style_hashes[8], "resp");

    if (value_ptr.flags_layout[0]) {
        writer.write("@media (max-width: 767px) {") catch {};
        writer.writeByte('.') catch {};
        writer.write(common_key) catch {};
        writer.writeByte('{') catch {};
        writer.writeByte('\n') catch {};
        StyleCompiler.generateLayout(&value_ptr.mobile_layout, &writer);

        if (value_ptr.flags_visual[0]) {
            writer.write("\n") catch {};
            StyleCompiler.generateVisual(&value_ptr.mobile_visual, &writer);
        }

        writer.write("}\n") catch {};
        writer.write("}\n") catch {};
    }

    // flag 2 is tablet (applies at tablet and above)
    if (value_ptr.flags_layout[2]) {
        writer.write("@media (min-width: 768px) {") catch {};

        writer.writeByte('.') catch {};
        writer.write(common_key) catch {};
        writer.writeByte('{') catch {};
        writer.writeByte('\n') catch {};

        StyleCompiler.generateLayout(&value_ptr.tablet_layout, &writer);

        if (value_ptr.flags_visual[2]) {
            writer.write("\n") catch {};
            StyleCompiler.generateVisual(&value_ptr.tablet_visual, &writer);
        }

        writer.write("}\n") catch {};
        writer.write("}\n") catch {};
    }
    // flag 1 is desktop (applies at desktop and above)
    if (value_ptr.flags_layout[1]) {
        writer.write("@media (min-width: 1024px) {") catch {};

        writer.writeByte('.') catch {};
        writer.write(common_key) catch {};
        writer.writeByte('{') catch {};
        writer.writeByte('\n') catch {};

        StyleCompiler.generateLayout(&value_ptr.desktop_layout, &writer);

        if (value_ptr.flags_visual[1]) {
            writer.write("\n") catch {};
            StyleCompiler.generateVisual(&value_ptr.desktop_visual, &writer);
        }

        writer.write("}\n") catch {};
        writer.write("}\n") catch {};
    }
    // Return a pointer to the CSS string
    const len: usize = writer.pos;
    StyleCompiler.css_buffer[len] = 0;
    StyleCompiler.style_style = StyleCompiler.css_buffer[0..len];
    return StyleCompiler.style_style.ptr;
}

pub export fn getStyle(ptr: ?*UINode) ?[*]const u8 {
    const node_ptr = ptr orelse return null;
    const packed_field_ptrs = node_ptr.packed_field_ptrs orelse return null;
    // Use a fixed buffer with a fbs to build the CSS string
    var writer: Writer = undefined;
    writer.init(&StyleCompiler.css_buffer);

    if (packed_field_ptrs.layout_ptr) |layout_ptr| {
        StyleCompiler.generateLayout(layout_ptr, &writer);
    }

    if (packed_field_ptrs.position_ptr) |position_ptr| {
        StyleCompiler.generatePositions(position_ptr, &writer);

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
        StyleCompiler.generateMarginsPadding(margin_paddings_ptr, &writer);
    }

    if (packed_field_ptrs.animations_ptr) |animations_ptr| {
        if (animations_ptr.has_animation_enter) {
            if (Vapor.string_table.get(animations_ptr.animation_enter)) |name| anim: {
                const animation = (if (Vapor.animations) |a| a.get(name) else null) orelse {
                    Vapor.printlnErr("animation '{s}' is not defined; register it with Vapor.Animation before using it", .{name});
                    break :anim;
                };
                writer.write("animation:") catch {};
                StyleCompiler.generateAnimation(&animation, &writer);
                writer.write(";\n") catch {};
            }
        }
    }

    if (packed_field_ptrs.visual_ptr) |visual_ptr| {
        StyleCompiler.generateVisual(visual_ptr, &writer);
    }

    if (packed_field_ptrs.transforms_ptr) |transforms_ptr| {
        StyleCompiler.generateTransforms(transforms_ptr, &writer);
    }

    // Return a pointer to the CSS string
    const len: usize = writer.pos;
    StyleCompiler.css_buffer[len] = 0;
    StyleCompiler.style_style = StyleCompiler.css_buffer[0..len];
    return StyleCompiler.style_style.ptr;
}

pub export fn getGlobalVariablesPtr() [*]const u8 {
    return StyleCompiler.global_style.ptr;
}

pub export fn getGlobalVariablesLen() usize {
    return StyleCompiler.global_style.len;
}

export fn showScrollBar() bool {
    return StyleCompiler.show_scrollbar;
}

export fn getStyleLen() usize {
    return StyleCompiler.style_style.len;
}

var visual_style: []const u8 = "";

pub export fn getVisualStyle(ptr: ?*UINode, visual_type: u8) ?[*]const u8 {
    const node_ptr = ptr orelse return null;
    const packed_fields = node_ptr.packed_field_ptrs orelse return null;

    var writer: Writer = undefined;
    writer.init(&StyleCompiler.css_buffer);
    if (visual_type == 3) {
        const visual = packed_fields.visual_ptr orelse return null;
        StyleCompiler.generateVisual(visual, &writer);

        // Null-terminate the string
        const len: usize = writer.pos;
        StyleCompiler.css_buffer[len] = 0;
        visual_style = StyleCompiler.css_buffer[0..len];

        return visual_style.ptr;
    }

    const interactive = packed_fields.interactive_ptr orelse return null;
    if (visual_type == 0) {
        const hover = interactive.hover;
        StyleCompiler.generateVisual(&hover, &writer);
        const hover_position = interactive.hover_position;
        if (interactive.has_hover_position) {
            StyleCompiler.generatePositions(&hover_position, &writer);
        }
        if (interactive.has_hover_transform) {
            writePropValue("transform", .{ .tag = .transform_type, .data = .{ .transform_type = interactive.hover_transform } }, &writer);
        }
    } else if (visual_type == 1) {
        const focus = interactive.focus;
        StyleCompiler.generateVisual(&focus, &writer);
    } else if (visual_type == 2) {
        const focus_within = interactive.focus_within;
        StyleCompiler.generateVisual(&focus_within, &writer);
    }
    // Null-terminate the string
    const len: usize = writer.pos;
    StyleCompiler.css_buffer[len] = 0;
    visual_style = StyleCompiler.css_buffer[0..len];

    // Return a pointer to the CSS string
    return visual_style.ptr;
}

export fn getVisualLen() usize {
    return visual_style.len;
}

var inherited_style: []const u8 = "";

export fn getInheritedStyle(ptr: ?*UINode) ?[*]const u8 {
    const node = ptr orelse return null;
    const packed_fields = node.packed_field_ptrs orelse return null;

    var writer: Writer = undefined;
    writer.init(&StyleCompiler.css_buffer);
    var did_write: bool = false;

    // This area checks if the current node has a hover style
    // if it does, we then check if the children of the node inherit the hover style
    if (packed_fields.interactive_ptr) |interactive_ptr| {
        if (interactive_ptr.has_hover) {
            if (node.children_count > 0) {
                const hover = interactive_ptr.hover;
                writer.writeByte('.') catch {};
                writer.write(node.class.?) catch {};
                writer.write(":hover") catch {};
                var children = node.children();
                while (children.next()) |child| {
                    if (child.hover_style_fields) |fields| {
                        if (child.class) |class| {
                            did_write = true;
                            writer.writeByte(' ') catch {};
                            writer.writeByte('.') catch {};
                            writer.write(class) catch {};

                            writer.write("{\n") catch {};
                            for (fields.*) |field| {
                                StyleCompiler.writeStyleField(field, &hover, &writer);
                            }
                            writer.writeByte('}') catch {};
                            writer.writeByte('\n') catch {};
                        }
                    }
                }
            }
        }
    }

    if (!did_write) {
        return null;
    }
    // Null-terminate the string
    const len: usize = writer.pos;
    StyleCompiler.css_buffer[len] = 0;
    inherited_style = StyleCompiler.css_buffer[0..len];

    // Return a pointer to the CSS string
    return inherited_style.ptr;
}

export fn getInheritedLen() usize {
    return inherited_style.len;
}

var position_style: []const u8 = "";

export fn getPositionStyle(ptr: ?*UINode) ?[*]const u8 {
    const node_ptr = ptr orelse return null;
    const packed_fields = node_ptr.packed_field_ptrs orelse return null;
    const packed_position = packed_fields.position_ptr orelse return null;
    var writer: Writer = undefined;
    writer.init(&StyleCompiler.css_buffer);
    StyleCompiler.generatePositions(packed_position, &writer);

    if (node_ptr.type == .Anchor) {
        if (packed_position.anchor_name_handle != StringTable.null_handle) {
            const anchor_name = Vapor.string_table.get(packed_position.anchor_name_handle);
            if (anchor_name) |name| {
                writer.write("position-anchor:--") catch {};
                writer.write(name) catch {};
                writer.write(";\n") catch {};
            }
        }
    }

    // Null-terminate the string
    const len: usize = writer.pos;
    StyleCompiler.css_buffer[len] = 0;
    position_style = StyleCompiler.css_buffer[0..len];

    // Return a pointer to the CSS string
    return position_style.ptr;
}

export fn getPositionLen() usize {
    return position_style.len;
}

var layout_style: []const u8 = "";

export fn getLayoutStyle(ptr: ?*UINode) ?[*]const u8 {
    const node_ptr = ptr orelse return null;
    const packed_fields = node_ptr.packed_field_ptrs orelse return null;
    const packed_layout = packed_fields.layout_ptr orelse return null;
    var writer: Writer = undefined;
    writer.init(&StyleCompiler.css_buffer);
    StyleCompiler.generateLayout(packed_layout, &writer);

    // Null-terminate the string
    const len: usize = writer.pos;
    StyleCompiler.css_buffer[len] = 0;
    layout_style = StyleCompiler.css_buffer[0..len];

    // Return a pointer to the CSS string
    return layout_style.ptr;
}

export fn getLayoutLen() usize {
    return layout_style.len;
}

var mapa_style: []const u8 = "";

export fn getMapaStyle(ptr: ?*UINode) ?[*]const u8 {
    const node_ptr = ptr orelse return null;
    const packed_fields = node_ptr.packed_field_ptrs orelse return null;
    const packed_margin_paddings = packed_fields.margins_paddings_ptr orelse return null;
    var writer: Writer = undefined;
    writer.init(&StyleCompiler.css_buffer);
    StyleCompiler.generateMarginsPadding(packed_margin_paddings, &writer);

    // Null-terminate the string
    const len: usize = writer.pos;
    StyleCompiler.css_buffer[len] = 0;
    mapa_style = StyleCompiler.css_buffer[0..len];

    // Return a pointer to the CSS string
    return mapa_style.ptr;
}

export fn getMapaLen() usize {
    return mapa_style.len;
}

var animations_style: []const u8 = "";

export fn getAnimationStyle(ptr: ?*UINode) ?[*]const u8 {
    const node_ptr = ptr orelse return null;
    const packed_fields = node_ptr.packed_field_ptrs orelse return null;
    const packed_animations = packed_fields.animations_ptr orelse return null;
    var writer: Writer = undefined;
    writer.init(&StyleCompiler.css_buffer);
    if (packed_animations.has_animation_enter) {
        if (Vapor.string_table.get(packed_animations.animation_enter)) |name| {
            const animation = Vapor.animations.?.get(name) orelse {
                Vapor.printErr("Animation not found in animations.zig; Please make sure to Run .build() on the animation", .{});
                return null;
            };
            writer.write("animation:") catch {};
            StyleCompiler.generateAnimation(&animation, &writer);
            writer.write(";\n") catch {};
        }
    }
    // Null-terminate the string
    const len: usize = writer.pos;
    StyleCompiler.css_buffer[len] = 0;
    animations_style = StyleCompiler.css_buffer[0..len];

    // Return a pointer to the CSS string
    return animations_style.ptr;
}

pub export fn getExitAnimationStyle(ptr: ?*UINode) ?[*]const u8 {
    const node_ptr = ptr orelse return null;
    const packed_fields = node_ptr.packed_field_ptrs orelse return null;
    const packed_animations = packed_fields.animations_ptr orelse return null;
    var writer: Writer = undefined;
    writer.init(&StyleCompiler.css_buffer);
    if (packed_animations.has_animation_exit) {
        if (Vapor.string_table.get(packed_animations.animation_exit)) |name| {
            const animation = Vapor.animations.?.get(name) orelse {
                Vapor.printErr("Exit Animation not found in animations.zig; Please make sure to Run .build() on the animation", .{});
                return null;
            };
            StyleCompiler.generateAnimation(&animation, &writer);
        }
    }
    // Null-terminate the string
    const len: usize = writer.pos;
    StyleCompiler.css_buffer[len] = 0;
    animations_style = StyleCompiler.css_buffer[0..len];

    // Return a pointer to the CSS string
    return animations_style.ptr;
}

pub export fn getAnimationLen() usize {
    return animations_style.len;
}

fn generateEdges(writer: *Writer) void {
    if (Vapor.edges_table) |table| {
        var it = table.iterator();
        while (it.next()) |entry| {
            const edges = entry.value_ptr.*;
            edges.writeCss(writer);
        }
    }
}

var edges_str: []const u8 = "";

export fn getEdgesPtr() ?[*]const u8 {
    if (Vapor.edges_table == null) return null;
    // Reset writer cursor
    var writer: Writer = undefined;
    var buffer: [8192]u8 = undefined;
    writer.init(&buffer);

    // Generate the CSS
    generateEdges(&writer);

    const len: usize = writer.pos;
    buffer[len] = 0;
    edges_str = buffer[0..len];
    return edges_str.ptr;
}

export fn getEdgesLen() usize {
    return edges_str.len;
}

fn generatePolygons(writer: *Writer) void {
    if (Vapor.polygons_table) |table| {
        var it = table.iterator();
        while (it.next()) |entry| {
            const polygons = entry.value_ptr.*;
            polygons.writeCss(writer);
        }
    }
}

var polygons_str: []const u8 = "";

export fn getPolygonsPtr() ?[*]const u8 {
    if (Vapor.polygons_table == null) return null;
    // Reset writer cursor
    var writer: Writer = undefined;
    var buffer: [8192]u8 = undefined;
    writer.init(&buffer);

    // Generate the CSS
    generatePolygons(&writer);
    const len: usize = writer.pos;
    buffer[len] = 0;
    polygons_str = buffer[0..len];
    return polygons_str.ptr;
}

export fn getPolygonsLen() usize {
    return polygons_str.len;
}

pub export fn getAnimationsPtr() ?[*]const u8 {
    if (Vapor.animations == null) return null;
    // Reset writer cursor
    var writer: Writer = undefined;
    var buffer: [8192 * 4]u8 = undefined;
    writer.init(&buffer);

    // Generate the CSS
    generateAnimationsFrames(&writer);
    const len: usize = writer.pos;
    buffer[len] = 0;
    StyleCompiler.animations_str = buffer[0..len];
    return StyleCompiler.animations_str.ptr;
}

pub export fn getAnimationsLen() usize {
    return StyleCompiler.animations_str.len;
}

export fn getInlineStyle(node_ptr: ?*UINode) ?[*]const u8 {
    const node = node_ptr orelse return null;
    const inline_style = node.inlineStyle orelse return null;
    return inline_style.ptr;
}

export fn getInlineStyleLen(node_ptr: ?*UINode) usize {
    const node = node_ptr orelse return 0;
    const inline_style = node.inlineStyle orelse return 0;
    return inline_style.len;
}
