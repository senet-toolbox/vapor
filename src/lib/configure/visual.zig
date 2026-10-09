const Configuration = @import("../Configuration.zig");
const UINode = @import("../UITree.zig").UINode;
const std = @import("std");
const types = @import("../types.zig");
const Vapor = @import("../Vapor.zig");
const utils = @import("../utils.zig");
const hashKey = utils.hashKey;
const StringTable = @import("../StringTable.zig").StringTable;
const Packer = @import("../Packer.zig");

/// Helper to pack a color union (`.Literal` or `.Thematic`) into a PackedColor struct.
fn packColor(source_color: types.Color, packed_color: *types.PackedColor) void {
    switch (source_color) {
        .Literal => |color| {
            packed_color.* = .{ .has_color = true, .color = color };
        },
        .Thematic => |token| {
            packed_color.* = .{ .has_token = true, .token = token };
        },
    }
}

fn createPackedLayer(layer: types.BackgroundLayer, current_hash_v: *u32) types.PackedLayer {
    var hash_v: u32 = current_hash_v.*;
    switch (layer) {
        .Grid => |grid| {
            Configuration.packed_layer = .{ .Grid = .{} };
            Configuration.packed_layer.Grid.size = grid.size;
            Configuration.packed_layer.Grid.thickness = grid.thickness;
            var grid_color = Configuration.packed_layer.Grid.packed_color;
            packColor(grid.color, &grid_color);
            Configuration.packed_layer.Grid.packed_color = grid_color;
            hash_v +%= std.hash.XxHash32.hash(0, std.mem.asBytes(&Configuration.packed_layer));
        },
        .Lines => |lines| {
            Configuration.packed_layer = .{ .Lines = .{} };
            Configuration.packed_layer.Lines.spacing = lines.spacing;
            Configuration.packed_layer.Lines.thickness = lines.thickness;
            Configuration.packed_layer.Lines.direction = lines.direction;
            var lines_color = Configuration.packed_layer.Lines.color;
            packColor(lines.color, &lines_color);
            Configuration.packed_layer.Lines.color = lines_color;
            hash_v +%= std.hash.XxHash32.hash(0, std.mem.asBytes(&Configuration.packed_layer));
        },
        // .Image => {},
        .Dot => |dots| {
            Configuration.packed_layer = .{ .Dot = .{} };
            Configuration.packed_layer.Dot.spacing = dots.spacing;
            Configuration.packed_layer.Dot.radius = dots.radius;
            var dots_color = Configuration.packed_layer.Dot.packed_color;
            packColor(dots.color, &dots_color);
            Configuration.packed_layer.Dot.packed_color = dots_color;
            hash_v +%= std.hash.XxHash32.hash(0, std.mem.asBytes(&Configuration.packed_layer));
        },
        .Gradient => |gradient| blk: {
            Configuration.packed_layer = .{ .Gradient = .{} };
            Configuration.packed_layer.Gradient.type = gradient.type;
            Configuration.packed_layer.Gradient.direction = gradient.direction;
            var gradient_colors = Vapor.arena(.frame).alloc(types.PackedColor, gradient.colors.len) catch |err| {
                Vapor.printlnErr("gradient: could not allocate colours, layer skipped: {any}", .{err});
                break :blk;
            };
            for (gradient.colors, 0..) |color, j| {
                packColor(color, &gradient_colors[j]);
            }
            const count = Vapor.packed_colors.count() + 1;
            Vapor.packed_colors.put(count, gradient_colors) catch |err| {
                Vapor.printlnErr("gradient: could not register colours, layer skipped: {any}", .{err});
                break :blk;
            };
            Configuration.packed_layer.Gradient.colors_ptr = count;
            Configuration.packed_layer.Gradient.colors_len = @intCast(gradient_colors.len);
            Configuration.packed_layer.Gradient.clip = gradient.clip;
            hash_v +%= std.hash.XxHash32.hash(0, std.mem.asBytes(&Configuration.packed_layer));
        },
        else => {
            Vapor.printlnSrcErr("Not implemented yet {any}", .{layer}, @src());
        },
    }
    current_hash_v.* = hash_v;
    return Configuration.packed_layer;
}

fn configureLayers(visual: *const Vapor.Types.Visual, current_hash_v: u32) u32 {
    var hash_v: u32 = current_hash_v;
    var packed_layers: []types.PackedLayer = undefined;
    if (visual.layer) |layer| {
        packed_layers = Vapor.arena(.frame).alloc(types.PackedLayer, 1) catch |err| {
            Vapor.printlnErr("layers: could not allocate, background layer skipped: {any}", .{err});
            return hash_v;
        };
        packed_layers[0] = createPackedLayer(layer, &hash_v);
    } else if (visual.layers) |layers| {
        packed_layers = Vapor.arena(.frame).alloc(types.PackedLayer, layers.len) catch |err| {
            Vapor.printlnErr("layers: could not allocate, background layers skipped: {any}", .{err});
            return hash_v;
        };
        for (layers, 0..) |layer, i| {
            packed_layers[i] = createPackedLayer(layer, &hash_v);
        }
    } else {
        return hash_v;
    }
    const count = Vapor.packed_layers.count() + 1;
    Vapor.packed_layers.put(count, packed_layers) catch |err| {
        Vapor.printlnErr("layers: could not register, background layers skipped: {any}", .{err});
        return hash_v;
    };
    Configuration.packed_visual.packed_layers.items_ptr = count;
    Configuration.packed_visual.packed_layers.len = @intCast(packed_layers.len);
    return hash_v;
}

pub fn configureVisual(ui_node: *UINode, style: *const Vapor.Style) u32 {
    var hash_v: u32 = 0;
    if (ui_node.type == .Button or ui_node.type == .ButtonCycle or ui_node.type == .CtxButton) {
        if (!Configuration.packed_visual.has_border_thickeness) {
            Configuration.packed_visual.has_border_thickeness = true;
            Configuration.packed_visual.border_thickness = .all(0);
            Configuration.packed_visual.background = .{ .color = .{ .a = 0, .r = 0, .g = 0, .b = 0 }, .has_color = true };
        }
    }
    if (ui_node.type == .Link or ui_node.type == .RedirectLink) {
        if (Configuration.packed_visual.text_decoration.type == .default) {
            Configuration.packed_visual.text_decoration.type = .none;
        }
    }

    if (style.visual) |visual| {
        checkVisual(&visual, &Configuration.packed_visual);
        // Inherited color must run after checkVisual as top not use it in the checkVisual for the actual node, it is meant for only the hover effect
        if (visual.background) |background| {
            Configuration.inherited_color = background;
        }
    }

    if (style.list_style) |list_style| Configuration.packed_visual.list_style = list_style;

    hash_v = std.hash.XxHash32.hash(0, std.mem.asBytes(&Configuration.packed_visual));

    if (style.font_family) |font_family| {
        Configuration.packed_visual.font_family_handle = Vapor.string_table.intern(font_family) catch StringTable.null_handle;
        hash_v +%= hashKey(font_family);
    }

    if (style.visual) |visual| {
        if (visual.animation) |animation| {
            Configuration.packed_visual.animation = Vapor.string_table.intern(animation) catch StringTable.null_handle;
            hash_v +%= hashKey(animation);
        }
        if (visual.animation_name) |animation_name| {
            if (animation_name.len > 0) {
                hash_v +%= hashKey(animation_name);
                Configuration.packed_visual.animation_name_handle = Vapor.string_table.intern(animation_name) catch StringTable.null_handle;
            }
        }
        if (visual.edges) |edges| {
            Configuration.packed_visual.edges_handle = Vapor.string_table.intern(edges) catch StringTable.null_handle;
            hash_v +%= hashKey(edges);
        }
    }

    if (style.transition) |transition| {
        Configuration.packed_visual.has_transitions = true;
        Configuration.packed_transition.delay = transition.delay;
        Configuration.packed_transition.duration = transition.duration;
        Configuration.packed_transition.timing = transition.timing;
        Configuration.packed_transition.properties_len = @intCast(transition.properties.len);
        Configuration.packed_transition.properties_ptr = 0;
        Configuration.packed_visual.transitions = Configuration.packed_transition;
        for (transition.properties) |property| {
            hash_v +%= hashKey(@tagName(property));
        }
    }

    if (style.visual) |visual| {
        hash_v = configureLayers(&visual, hash_v);
    }

    if (style.transition) |transition| {
        var local_packed_transition: types.PackedTransition = undefined;
        local_packed_transition.set(&transition);
        Configuration.packed_visual.transitions = local_packed_transition;
    }

    if (Configuration.hash_id) {
        if (Packer.visuals_pool.create()) |packed_visual_ptr| {
            packed_visual_ptr.* = Configuration.packed_visual;
            ui_node.packed_field_ptrs.?.visual_ptr = packed_visual_ptr;
        } else |err| {
            Vapor.printlnErr("style: could not allocate, node renders without this group: {any}", .{err});
        }
        return hash_v;
    }

    if (Configuration.getOrPutAndUpdateHash(
        hash_v,
        types.PackedVisual,
        Configuration.packed_visual,
        &Packer.visuals,
        &Packer.visuals_pool,
    )) |ptr| {
        ui_node.packed_field_ptrs.?.visual_ptr = ptr;
    } else |err| {
        Vapor.printlnErr("style: could not cache, node renders without this group: {any}", .{err});
    }

    return hash_v;
}

pub fn checkVisual(visual: *const types.Visual, packet_visual: *types.PackedVisual) void {
    // Refactored to use the packColor helper
    if (visual.background) |background| {
        var background_color = packet_visual.background;
        packColor(background, &background_color);
        packet_visual.background = background_color;
    }

    if (visual.color_mix) |color_mix| {
        if (color_mix.color) |color| {
            Configuration.inherited_color = color;
        }
        if (Configuration.inherited_color) |in| {
            packet_visual.color_mix = .{ .color_prop = color_mix.color_prop, .percentage = color_mix.percentage };
            var mix_color = packet_visual.color_mix.color;
            packColor(in, &mix_color);
            packet_visual.color_mix.color = mix_color;
        }
    }

    if (visual.fill) |fill| {
        var fill_color = packet_visual.fill;
        packColor(fill, &fill_color);
        packet_visual.fill = fill_color;
    }

    if (visual.stroke) |stroke| {
        var stroke_color = packet_visual.stroke;
        packColor(stroke, &stroke_color);
        packet_visual.stroke = stroke_color;
    }

    if (visual.border) |border| {
        packet_visual.border_thickness = border.thickness;
        packet_visual.has_border_thickeness = true;
        if (border.color) |color| {
            packet_visual.has_border_color = true;
            var border_color = packet_visual.border_color;
            packColor(color, &border_color);
            packet_visual.border_color = border_color;
        }
        if (border.radius) |radius| {
            packet_visual.has_border_radius = true;
            packet_visual.border_radius = radius;
        }
        packet_visual.border_style = border.style;
    }

    if (visual.font_size) |font_size| {
        packet_visual.font_size = font_size;
    }
    if (visual.font_weight) |font_weight| {
        packet_visual.font_weight = font_weight;
    }

    if (visual.outline) |outline| {
        packet_visual.outline = outline;
    }

    if (visual.outline_color) |color| {
        packet_visual.has_outline_color = true;
        var outline_color = packet_visual.outline_color;
        packColor(color, &outline_color);
        packet_visual.outline_color = outline_color;
    }

    if (visual.font_style) |font_style| {
        packet_visual.font_style = font_style;
    }

    if (visual.text_color) |color| {
        var text_color = packet_visual.text_color;
        packColor(color, &text_color);
        packet_visual.text_color = text_color;
    }
    if (visual.opacity) |opacity| {
        packet_visual.has_opacity = true;
        packet_visual.opacity = opacity;
    }

    if (visual.ellipsis) |ellipsis| {
        packet_visual.ellipsis = ellipsis;
    }

    if (visual.animation_play_state) |animation_play_state| {
        packet_visual.animation_play_state = animation_play_state;
    }

    if (visual.cursor) |cursor| {
        packet_visual.cursor = cursor;
    }

    if (visual.text_decoration) |text_decoration| {
        packet_visual.text_decoration = .{
            .type = text_decoration.type,
            .style = text_decoration.style,
        };

        if (text_decoration.color) |color| {
            var text_decoration_color = packet_visual.text_decoration.color;
            packColor(color, &text_decoration_color);
            packet_visual.text_decoration.color = text_decoration_color;
        }
    }

    if (visual.blur) |blur| {
        packet_visual.blur = blur;
    }

    if (visual.caret) |caret| {
        packet_visual.caret = .{
            .type = caret.type,
        };
        if (caret.color == null) return;
        var caret_color = packet_visual.caret.color;
        packColor(caret.color.?, &caret_color);
        packet_visual.caret.color = caret_color;
    }

    if (visual.white_space) |white_space| {
        packet_visual.has_white_space = true;
        packet_visual.white_space = white_space;
    }

    if (visual.resize) |resize| {
        packet_visual.resize = resize;
    }

    if (visual.text_shadow) |text_shadow| {
        var count = Vapor.shadows.count();
        count += 1;
        packet_visual.text_shadow = count;
        Vapor.shadows.put(count, text_shadow) catch |err| {
            Vapor.printlnErr("shadow: could not register, shadow skipped: {any}", .{err});
            packet_visual.text_shadow = 0;
        };
    }

    if (visual.new_shadow) |new_shadow| {
        var count = Vapor.shadows.count();
        count += 1;
        packet_visual.new_shadow = count;
        Vapor.shadows.put(count, new_shadow) catch |err| {
            Vapor.printlnErr("shadow: could not register, shadow skipped: {any}", .{err});
            packet_visual.new_shadow = 0;
        };
    }
}
