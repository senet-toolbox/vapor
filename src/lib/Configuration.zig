const UINode = @import("UITree.zig").UINode;
const std = @import("std");
const UIContext = @import("UITree.zig").UIContext;
const types = @import("types.zig");
const ElemDecl = types.ElementDeclaration;
const Vapor = @import("Vapor.zig");
const utils = @import("utils.zig");
const Shadow = @import("Shadow.zig");
const hashKey = utils.hashKey;
const Reconciler = @import("Reconciler.zig");
pub var packed_layout: types.PackedLayout = .{};
pub var packed_position: types.PackedPosition = .{};
pub var packed_margins_paddings: types.PackedMarginsPaddings = .{};
pub var packed_visual: types.PackedVisual = .{};
pub var target_packed_visual: types.PackedVisual = .{};
pub var packed_animations: types.PackedAnimations = .{};
pub var packed_interactive: types.PackedInteractive = .{};
pub var packed_transition: types.PackedTransition = .{};
pub var packed_layer: types.PackedLayer = .{ .Grid = .{} };
pub var packed_transforms: types.PackedTransforms = .{};
pub var packed_responsive: types.PackedResponsive = .{};
const hashStyle = @import("HashStyle.zig").hashStyle;
const StringTable = @import("StringTable.zig").StringTable;

const PackedFieldPtrs = @import("UITree.zig").PackedFieldPtrs;
const Packer = @import("Packer.zig");
const buildClassString = @import("UITree.zig").buildClassString;

const Accessibility = @import("Accessibility.zig");

fn hashPacked(comptime T: type, value: *const T) u32 {
    const is_wasm = @import("builtin").target.cpu.arch == .wasm32;
    if (!is_wasm) {
        // Native: fast path, hash raw bytes
        return std.hash.XxHash32.hash(0, std.mem.asBytes(value));
    }
    // WASM: hash each field individually
    var hasher = std.hash.XxHash32.init(0);
    inline for (std.meta.fields(T)) |field| {
        const field_value = @field(value.*, field.name);
        const bytes = std.mem.asBytes(&field_value);
        hasher.update(bytes);
    }
    return hasher.final();
}

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

fn getOrPutAndUpdateHash(hash: u32, comptime T: type, data: T, cache: anytype, pool: anytype) !*const T {
    if (cache.get(hash)) |ptr| {
        // 1. The Logic: Value Identity vs. Memory Identity
        // Two things can be "Value Identical" but "Memory Distinct."
        //
        // Value Identity (The Hash): The definition of the style hasn't changed
        // (e.g., it's still "Red Button with 10px Padding"). The hash is the same.
        //
        // Memory Identity (The Pointers): The underlying data (e.g., the slice of transitions or the string name)
        // lives in the frame arena. Since the arena is wiped every frame, the address of that data changes every
        // single frame (e.g., from 0xAAAA in Frame 1 to 0xBBBB in Frame 2).
        //
        // If you returned the cached pointer without updating the data, your frameent ptr would point to 0xAAAA (Frame 1's memory), which is now garbage/overwritten.
        // "Stable Container, Volatile Content" (or "Flyweight with Frame-Local Backing").
        // We replace the current value with the new generated one, as during transition creation we only allcoate on the frame,
        // so if we create a new style with new transition, then the old one will be used if we do not update the data
        // Imagine we have frame 1, have a transition packed visual, then frame 2 deallocates this sicne it uses the frame arena,
        // then we check in the cache if the hash exists, it does since it's the same style, but we must update the ptr value data, with the new data
        // event though its the same since teh transition allocation is on this frame now.
        ptr.* = data;
        return ptr;
    }

    const new_ptr = try pool.create();
    new_ptr.* = data;
    try cache.put(hash, new_ptr);

    return new_ptr;
}

fn configureLayouts(ui_node: *UINode, style: *const Vapor.Style) u32 {
    var hash_l: u32 = 0;

    if (ui_node.parent) |parent| {
        if (parent.direction == .column) {
            packed_layout.parent_direction = .column;
        }
        if (parent.column_count) |count| {
            if (parent.spacing) |spacing| {
                packed_layout.column_count = count;
                if (spacing > count) {
                    packed_layout.column_spacing = @as(f32, @floatFromInt(spacing)) / @as(f32, @floatFromInt(count));
                } else {}
            }
        }
    }

    if (style.flex_type == .hidden) {
        packed_layout.flex = .hidden;
    } else if (style.layout) |layout| {
        if (layout.x == .in_line and layout.y == .in_line) {
            packed_layout.flex = .flow;
            packed_layout.layout = layout;
        } else if (ui_node.text != null) {
            packed_layout.text_align = layout;
        } else {
            packed_layout.flex = .flex;
            packed_layout.layout = layout;
        }
    } else if (ui_node.type == .FlexBox) {
        packed_layout.flex = .flex;
    }

    if (style.placement) |placement| packed_layout.placement = placement;
    if (style.size) |size| packed_layout.size = size;
    if (style.child_gap) |child_gap| packed_layout.spacing = child_gap;
    if (style.spacing) |spacing| packed_layout.spacing = spacing;
    if (style.direction) |direction| packed_layout.direction = direction;
    if (style.flex_wrap) |flex_wrap| packed_layout.flex_wrap = flex_wrap;
    if (style.scroll) |scroll| packed_layout.scroll = scroll;
    if (style.aspect_ratio) |aspect_ratio| packed_layout.aspect_ratio = aspect_ratio;

    hash_l = std.hash.XxHash32.hash(0, std.mem.asBytes(&packed_layout));

    if (hash_id) {
        if (Packer.layouts_pool.create()) |packed_layout_ptr| {
            packed_layout_ptr.* = packed_layout;
            ui_node.packed_field_ptrs.?.layout_ptr = packed_layout_ptr;
        } else |err| {
            Vapor.printlnErr("style: could not allocate, node renders without this group: {any}", .{err});
        }
        return hash_l;
    }
    if (getOrPutAndUpdateHash(
        hash_l,
        types.PackedLayout,
        packed_layout,
        &Packer.layouts,
        &Packer.layouts_pool,
    )) |ptr| {
        ui_node.packed_field_ptrs.?.layout_ptr = ptr;
    } else |err| {
        Vapor.printlnErr("style: could not cache, node renders without this group: {any}", .{err});
    }
    return hash_l;
}

fn configureResponsive(ui_node: *UINode, style: *const Vapor.Style) u32 {
    var hash_r: u32 = 0;

    const responsive = style.responsive orelse return hash_r;
    if (responsive.mobile) |s| {
        if (ui_node.parent) |parent| {
            if (parent.direction == .column) {
                packed_responsive.mobile_layout.parent_direction = .column;
            }
            if (parent.column_count) |count| {
                if (parent.spacing) |spacing| {
                    packed_responsive.mobile_layout.column_count = count;
                    if (spacing > count) {
                        packed_responsive.mobile_layout.column_spacing = @as(f32, @floatFromInt(spacing)) / @as(f32, @floatFromInt(count));
                    } else {}
                }
            }
        }

        if (s.flex_type == .hidden) {
            packed_responsive.mobile_layout.flex = .hidden;
        } else if (s.layout) |layout| {
            if (layout.x == .in_line and layout.y == .in_line) {
                packed_responsive.mobile_layout.flex = .flow;
                packed_responsive.mobile_layout.layout = layout;
            } else if (ui_node.text != null) {
                packed_responsive.mobile_layout.text_align = layout;
            } else {
                packed_responsive.mobile_layout.flex = .flex;
                packed_responsive.mobile_layout.layout = layout;
            }
        } else if (ui_node.type == .FlexBox) {
            packed_responsive.mobile_layout.flex = .flex;
        }

        if (s.placement) |placement| packed_responsive.mobile_layout.placement = placement;
        if (s.size) |size| packed_responsive.mobile_layout.size = size;
        if (s.child_gap) |child_gap| packed_responsive.mobile_layout.spacing = child_gap;
        if (s.spacing) |spacing| packed_responsive.mobile_layout.spacing = spacing;
        if (s.direction) |direction| packed_responsive.mobile_layout.direction = direction;
        if (s.flex_wrap) |flex_wrap| packed_responsive.mobile_layout.flex_wrap = flex_wrap;
        if (s.scroll) |scroll| packed_responsive.mobile_layout.scroll = scroll;
        if (s.aspect_ratio) |aspect_ratio| packed_responsive.mobile_layout.aspect_ratio = aspect_ratio;
        packed_responsive.flags_layout[0] = true;

        if (s.visual) |visual| {
            if (ui_node.type == .Button or ui_node.type == .ButtonCycle or ui_node.type == .CtxButton) {
                if (!packed_responsive.mobile_visual.has_border_thickeness) {
                    packed_responsive.mobile_visual.has_border_thickeness = true;
                    packed_responsive.mobile_visual.border_thickness = .all(0);
                    packed_responsive.mobile_visual.background = .{ .color = .{ .a = 0, .r = 0, .g = 0, .b = 0 }, .has_color = true };
                }
            }
            checkVisual(&visual, &packed_responsive.mobile_visual);
            packed_responsive.flags_visual[0] = true;
        }
    }

    if (responsive.desktop) |s| {
        if (ui_node.parent) |parent| {
            if (parent.direction == .column) {
                packed_responsive.desktop_layout.parent_direction = .column;
            }
            if (parent.column_count) |count| {
                if (parent.spacing) |spacing| {
                    packed_responsive.desktop_layout.column_count = count;
                    if (spacing > count) {
                        packed_responsive.desktop_layout.column_spacing = @as(f32, @floatFromInt(spacing)) / @as(f32, @floatFromInt(count));
                    } else {}
                }
            }
        }

        if (s.flex_type == .hidden) {
            packed_responsive.desktop_layout.flex = .hidden;
        } else if (s.layout) |layout| {
            if (layout.x == .in_line and layout.y == .in_line) {
                packed_responsive.desktop_layout.flex = .flow;
                packed_responsive.desktop_layout.layout = layout;
            } else if (ui_node.text != null) {
                packed_responsive.desktop_layout.text_align = layout;
            } else {
                packed_responsive.desktop_layout.flex = .flex;
                packed_responsive.desktop_layout.layout = layout;
            }
        } else if (ui_node.type == .FlexBox) {
            packed_responsive.desktop_layout.flex = .flex;
        }

        if (s.placement) |placement| packed_responsive.desktop_layout.placement = placement;
        if (s.size) |size| packed_responsive.desktop_layout.size = size;
        if (s.child_gap) |child_gap| packed_responsive.desktop_layout.spacing = child_gap;
        if (s.spacing) |spacing| packed_responsive.desktop_layout.spacing = spacing;
        if (s.direction) |direction| packed_responsive.desktop_layout.direction = direction;
        if (s.flex_wrap) |flex_wrap| packed_responsive.desktop_layout.flex_wrap = flex_wrap;
        if (s.scroll) |scroll| packed_responsive.desktop_layout.scroll = scroll;
        if (s.aspect_ratio) |aspect_ratio| packed_responsive.desktop_layout.aspect_ratio = aspect_ratio;
        packed_responsive.flags_layout[1] = true;

        if (s.visual) |visual| {
            if (ui_node.type == .Button or ui_node.type == .ButtonCycle or ui_node.type == .CtxButton) {
                if (!packed_responsive.desktop_visual.has_border_thickeness) {
                    packed_responsive.desktop_visual.has_border_thickeness = true;
                    packed_responsive.desktop_visual.border_thickness = .all(0);
                    packed_responsive.desktop_visual.background = .{ .color = .{ .a = 0, .r = 0, .g = 0, .b = 0 }, .has_color = true };
                }
            }

            checkVisual(&visual, &packed_responsive.desktop_visual);
            packed_responsive.flags_visual[1] = true;
        }
    }

    hash_r = std.hash.XxHash32.hash(0, std.mem.asBytes(&packed_responsive));

    if (hash_id) {
        if (Packer.responsive_pool.create()) |packed_responsive_ptr| {
            packed_responsive_ptr.* = packed_responsive;
            ui_node.packed_field_ptrs.?.responsive_ptr = packed_responsive_ptr;
        } else |err| {
            Vapor.printlnErr("style: could not allocate, node renders without this group: {any}", .{err});
        }
        return hash_r;
    }

    if (getOrPutAndUpdateHash(
        hash_r,
        types.PackedResponsive,
        packed_responsive,
        &Packer.responsives,
        &Packer.responsive_pool,
    )) |ptr| {
        ui_node.packed_field_ptrs.?.responsive_ptr = ptr;
    } else |err| {
        Vapor.printlnErr("style: could not cache, node renders without this group: {any}", .{err});
    }

    return hash_r;
}

fn configureTransforms(ui_node: *UINode, style: *const Vapor.Style) u32 {
    var hash_t: u32 = 0;
    if (style.transform_origin) |transform_origin| {
        packed_transforms.transform_origin = transform_origin;
    }

    if (style.visual) |visual| {
        if (visual.transform) |transform| {
            packed_transforms.has_transform = true;
            packed_transforms.transform = handleTransform(transform, &hash_t);
        }
    }

    hash_t +%= std.hash.XxHash32.hash(0, std.mem.asBytes(&packed_transforms));

    if (style.visual) |visual| {
        if (visual.transform) |transform| {
            var packed_transform: types.PackedTransform = undefined;
            // I updated this so that it is the frame allocator
            packed_transform.set(&transform);
            packed_transforms.transform = packed_transform;
        }
    }
    // Early exit if nothing to store
    if (!packed_transforms.has_transform and style.transform_origin == null) {
        return hash_t;
    }

    if (hash_id) {
        if (Packer.transforms_pool.create()) |packed_transforms_ptr| {
            packed_transforms_ptr.* = packed_transforms;
            ui_node.packed_field_ptrs.?.transforms_ptr = packed_transforms_ptr;
        } else |err| {
            Vapor.printlnErr("style: could not allocate, node renders without this group: {any}", .{err});
        }
        return hash_t;
    }
    if (getOrPutAndUpdateHash(
        hash_t,
        types.PackedTransforms,
        packed_transforms,
        &Packer.transforms,
        &Packer.transforms_pool,
    )) |ptr| {
        ui_node.packed_field_ptrs.?.transforms_ptr = ptr;
    } else |err| {
        Vapor.printlnErr("style: could not cache, node renders without this group: {any}", .{err});
    }
    return hash_t;
}

fn createPackedLayer(layer: types.BackgroundLayer, current_hash_v: *u32) types.PackedLayer {
    var hash_v: u32 = current_hash_v.*;
    switch (layer) {
        .Grid => |grid| {
            packed_layer = .{ .Grid = .{} };
            packed_layer.Grid.size = grid.size;
            packed_layer.Grid.thickness = grid.thickness;
            var grid_color = packed_layer.Grid.packed_color;
            packColor(grid.color, &grid_color);
            packed_layer.Grid.packed_color = grid_color;
            hash_v +%= std.hash.XxHash32.hash(0, std.mem.asBytes(&packed_layer));
        },
        .Lines => |lines| {
            packed_layer = .{ .Lines = .{} };
            packed_layer.Lines.spacing = lines.spacing;
            packed_layer.Lines.thickness = lines.thickness;
            packed_layer.Lines.direction = lines.direction;
            var lines_color = packed_layer.Lines.color;
            packColor(lines.color, &lines_color);
            packed_layer.Lines.color = lines_color;
            hash_v +%= std.hash.XxHash32.hash(0, std.mem.asBytes(&packed_layer));
        },
        // .Image => {},
        .Dot => |dots| {
            packed_layer = .{ .Dot = .{} };
            packed_layer.Dot.spacing = dots.spacing;
            packed_layer.Dot.radius = dots.radius;
            var dots_color = packed_layer.Dot.packed_color;
            packColor(dots.color, &dots_color);
            packed_layer.Dot.packed_color = dots_color;
            hash_v +%= std.hash.XxHash32.hash(0, std.mem.asBytes(&packed_layer));
        },
        .Gradient => |gradient| blk: {
            packed_layer = .{ .Gradient = .{} };
            packed_layer.Gradient.type = gradient.type;
            packed_layer.Gradient.direction = gradient.direction;
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
            packed_layer.Gradient.colors_ptr = count;
            packed_layer.Gradient.colors_len = @intCast(gradient_colors.len);
            packed_layer.Gradient.clip = gradient.clip;
            hash_v +%= std.hash.XxHash32.hash(0, std.mem.asBytes(&packed_layer));
        },
        else => {
            Vapor.printlnSrcErr("Not implemented yet {any}", .{layer}, @src());
        },
    }
    current_hash_v.* = hash_v;
    return packed_layer;
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
    packed_visual.packed_layers.items_ptr = count;
    packed_visual.packed_layers.len = @intCast(packed_layers.len);
    return hash_v;
}

var inherited_color: ?Vapor.Types.Color = null;
fn configureVisual(ui_node: *UINode, style: *const Vapor.Style) u32 {
    var hash_v: u32 = 0;
    if (ui_node.type == .Button or ui_node.type == .ButtonCycle or ui_node.type == .CtxButton) {
        if (!packed_visual.has_border_thickeness) {
            packed_visual.has_border_thickeness = true;
            packed_visual.border_thickness = .all(0);
            packed_visual.background = .{ .color = .{ .a = 0, .r = 0, .g = 0, .b = 0 }, .has_color = true };
        }
    }
    if (ui_node.type == .Link or ui_node.type == .RedirectLink) {
        if (packed_visual.text_decoration.type == .default) {
            packed_visual.text_decoration.type = .none;
        }
    }

    if (style.visual) |visual| {
        checkVisual(&visual, &packed_visual);
        // Inherited color must run after checkVisual as top not use it in the checkVisual for the actual node, it is meant for only the hover effect
        if (visual.background) |background| {
            inherited_color = background;
        }
    }

    if (style.list_style) |list_style| packed_visual.list_style = list_style;

    hash_v = std.hash.XxHash32.hash(0, std.mem.asBytes(&packed_visual));

    if (style.font_family) |font_family| {
        packed_visual.font_family_handle = Vapor.string_table.intern(font_family) catch StringTable.null_handle;
        hash_v +%= hashKey(font_family);
    }

    if (style.visual) |visual| {
        if (visual.animation) |animation| {
            packed_visual.animation = Vapor.string_table.intern(animation) catch StringTable.null_handle;
            hash_v +%= hashKey(animation);
        }
        if (visual.animation_name) |animation_name| {
            if (animation_name.len > 0) {
                hash_v +%= hashKey(animation_name);
                packed_visual.animation_name_handle = Vapor.string_table.intern(animation_name) catch StringTable.null_handle;
            }
        }
        if (visual.edges) |edges| {
            packed_visual.edges_handle = Vapor.string_table.intern(edges) catch StringTable.null_handle;
            hash_v +%= hashKey(edges);
        }
    }

    if (style.transition) |transition| {
        packed_visual.has_transitions = true;
        packed_transition.delay = transition.delay;
        packed_transition.duration = transition.duration;
        packed_transition.timing = transition.timing;
        packed_transition.properties_len = @intCast(transition.properties.len);
        packed_transition.properties_ptr = 0;
        packed_visual.transitions = packed_transition;
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
        packed_visual.transitions = local_packed_transition;
    }

    if (hash_id) {
        if (Packer.visuals_pool.create()) |packed_visual_ptr| {
            packed_visual_ptr.* = packed_visual;
            ui_node.packed_field_ptrs.?.visual_ptr = packed_visual_ptr;
        } else |err| {
            Vapor.printlnErr("style: could not allocate, node renders without this group: {any}", .{err});
        }
        return hash_v;
    }

    if (getOrPutAndUpdateHash(
        hash_v,
        types.PackedVisual,
        packed_visual,
        &Packer.visuals,
        &Packer.visuals_pool,
    )) |ptr| {
        ui_node.packed_field_ptrs.?.visual_ptr = ptr;
    } else |err| {
        Vapor.printlnErr("style: could not cache, node renders without this group: {any}", .{err});
    }

    return hash_v;
}

fn configurePositions(ui_node: *UINode, style: *const Vapor.Style) u32 {
    var hash_p: u32 = 0;
    if (style.anchor) |anchor| {
        if (ui_node.type == .Anchor) {
            packed_position.position_anchor_handle = Vapor.string_table.intern(anchor) catch StringTable.null_handle;
            hash_p +%= hashKey(anchor);
        } else {
            packed_position.anchor_name_handle = Vapor.string_table.intern(anchor) catch StringTable.null_handle;
            hash_p +%= hashKey(anchor);
        }
    }

    if (style.position) |position| {
        // ** Packed Position **
        packed_position.position_type = position.type;
        if (position.top) |top| packed_position.top = .{ .type = top.type, .value = top.value };
        if (position.right) |right| packed_position.right = .{ .type = right.type, .value = right.value };
        if (position.bottom) |bottom| packed_position.bottom = .{ .type = bottom.type, .value = bottom.value };
        if (position.left) |left| packed_position.left = .{ .type = left.type, .value = left.value };
        if (position.z_index) |z_index| packed_position.z_index = z_index;
    }

    hash_p = std.hash.XxHash32.hash(0, std.mem.asBytes(&packed_position));

    if (hash_id) {
        if (Packer.positions_pool.create()) |packed_position_ptr| {
            packed_position_ptr.* = packed_position;
            ui_node.packed_field_ptrs.?.position_ptr = packed_position_ptr;
        } else |err| {
            Vapor.printlnErr("style: could not allocate, node renders without this group: {any}", .{err});
        }
        return hash_p;
    }
    if (getOrPutAndUpdateHash(
        hash_p,
        types.PackedPosition,
        packed_position,
        &Packer.positions,
        &Packer.positions_pool,
    )) |ptr| {
        ui_node.packed_field_ptrs.?.position_ptr = ptr;
    } else |err| {
        Vapor.printlnErr("style: could not cache, node renders without this group: {any}", .{err});
    }
    return hash_p;
}

fn configureMarginsPaddings(ui_node: *UINode, style: *const Vapor.Style) u32 {
    var hash_mp: u32 = 0;
    // ** Packed Margins and Padding **
    if (style.padding) |padding| packed_margins_paddings.padding = padding;
    if (style.margin) |margin| packed_margins_paddings.margin = margin;

    // This is an expensive operation, since the the visual hash is quite large
    hash_mp = std.hash.XxHash32.hash(0, std.mem.asBytes(&packed_margins_paddings));
    if (hash_id) {
        if (Packer.margins_paddings_pool.create()) |packed_margin_paddings_ptr| {
            packed_margin_paddings_ptr.* = packed_margins_paddings;
            ui_node.packed_field_ptrs.?.margins_paddings_ptr = packed_margin_paddings_ptr;
        } else |err| {
            Vapor.printlnErr("style: could not allocate, node renders without this group: {any}", .{err});
        }
        return hash_mp;
    }
    if (getOrPutAndUpdateHash(
        hash_mp,
        types.PackedMarginsPaddings,
        packed_margins_paddings,
        &Packer.margins_paddings,
        &Packer.margins_paddings_pool,
    )) |ptr| {
        ui_node.packed_field_ptrs.?.margins_paddings_ptr = ptr;
    } else |err| {
        Vapor.printlnErr("style: could not cache, node renders without this group: {any}", .{err});
    }
    return hash_mp;
}

fn handleTransform(transform: types.Transform, hash: *u32) types.PackedTransform {
    var packed_transform: types.PackedTransform = undefined;
    packed_transform.size_type = transform.size_type;
    packed_transform.scale_size = transform.scale_size;
    packed_transform.trans_x = transform.trans_x;
    packed_transform.trans_y = transform.trans_y;
    packed_transform.deg = transform.deg;
    packed_transform.x = transform.x;
    packed_transform.y = transform.y;
    packed_transform.z = transform.z;
    packed_transform.opacity = transform.opacity;
    packed_transform.type_ptr = 0;
    packed_transform.type_len = transform.type.len;
    for (transform.type) |property| {
        hash.* +%= @intFromEnum(property);
    }
    return packed_transform;
}

fn configureAnimations(ui_node: *UINode, elem_decl: ElemDecl) u32 {
    const has_animation = elem_decl.animation_enter != null or elem_decl.animation_exit != null;
    if (!has_animation) return 0;

    var hash_a: u32 = 0;

    if (elem_decl.animation_enter) |animation_enter| {
        packed_animations.has_animation_enter = true;
        packed_animations.animation_enter = Vapor.string_table.intern(animation_enter) catch StringTable.null_handle;
        hash_a +%= hashKey(animation_enter);
    }

    if (elem_decl.animation_exit) |animation_exit| {
        ui_node.animation_exit = animation_exit;
        packed_animations.has_animation_exit = true;
        packed_animations.animation_exit = Vapor.string_table.intern(animation_exit) catch StringTable.null_handle;
        hash_a +%= hashKey(animation_exit);
    }

    if (!packed_animations.has_animation_enter and !packed_animations.has_animation_exit) return 0;

    hash_a = std.hash.XxHash32.hash(0, std.mem.asBytes(&packed_animations));

    if (hash_id) {
        if (Packer.animations_pool.create()) |packed_animations_ptr| {
            packed_animations_ptr.* = packed_animations;
            ui_node.packed_field_ptrs.?.animations_ptr = packed_animations_ptr;
        } else |err| {
            Vapor.printlnErr("style: could not allocate, node renders without this group: {any}", .{err});
        }
        return hash_a;
    }

    if (getOrPutAndUpdateHash(
        hash_a,
        types.PackedAnimations,
        packed_animations,
        &Packer.animations,
        &Packer.animations_pool,
    )) |ptr| {
        ui_node.packed_field_ptrs.?.animations_ptr = ptr;
    } else |err| {
        Vapor.printlnErr("style: could not cache, node renders without this group: {any}", .{err});
    }
    return hash_a;
}

fn configureInteractive(ui_node: *UINode, style: *const Vapor.Style) u32 {
    var hash_i: u32 = 0;
    const interactive = style.interactive orelse return hash_i;
    if (interactive.hover) |hover| {
        var packed_hover: types.PackedVisual = .{};
        checkVisual(&hover, &packed_hover);

        packed_interactive.has_hover = true;
        packed_interactive.hover = packed_hover;

        if (hover.transform) |transform| {
            packed_interactive.has_hover_transform = true;
            packed_interactive.hover_transform = handleTransform(transform, &hash_i);
        }
    }

    if (interactive.hover_position) |hover_position| {
        packed_interactive.has_hover_position = true;
        packed_interactive.hover_position = .{};
        packed_interactive.hover_position.position_type = hover_position.type;
        if (hover_position.top) |top| packed_interactive.hover_position.top = .{ .type = top.type, .value = top.value };
        if (hover_position.right) |right| packed_interactive.hover_position.right = .{ .type = right.type, .value = right.value };
        if (hover_position.bottom) |bottom| packed_interactive.hover_position.bottom = .{ .type = bottom.type, .value = bottom.value };
        if (hover_position.left) |left| packed_interactive.hover_position.left = .{ .type = left.type, .value = left.value };
        if (hover_position.z_index) |z_index| packed_interactive.hover_position.z_index = z_index;
    }

    if (interactive.focus) |focus| {
        var packed_focus: types.PackedVisual = .{};
        checkVisual(&focus, &packed_focus);
        packed_interactive.has_focus = true;
        packed_interactive.focus = packed_focus;
    }

    hash_i = std.hash.XxHash32.hash(0, std.mem.asBytes(&packed_interactive));

    if (interactive.hover) |hover| {
        if (hover.animation) |animation| {
            packed_interactive.hover.animation = Vapor.string_table.intern(animation) catch StringTable.null_handle;
            hash_i +%= hashKey(animation);
        }

        if (hover.animation_name) |animation_name| {
            if (animation_name.len > 0) {
                hash_i +%= hashKey(animation_name);
                packed_interactive.hover.animation_name_handle = Vapor.string_table.intern(animation_name) catch StringTable.null_handle;
            }
        }

        if (hover.transform) |transform| {
            var packed_transform: types.PackedTransform = undefined;
            packed_transform.set(&transform);
            packed_interactive.hover_transform = packed_transform;
        }
    }

    if (hash_id) {
        if (Packer.interactives_pool.create()) |packed_interactive_ptr| {
            packed_interactive_ptr.* = packed_interactive;
            ui_node.packed_field_ptrs.?.interactive_ptr = packed_interactive_ptr;
        } else |err| {
            Vapor.printlnErr("style: could not allocate, node renders without this group: {any}", .{err});
        }
        return hash_i;
    }

    if (getOrPutAndUpdateHash(
        hash_i,
        types.PackedInteractive,
        packed_interactive,
        &Packer.interactives,
        &Packer.interactives_pool,
    )) |ptr| {
        ui_node.packed_field_ptrs.?.interactive_ptr = ptr;
    } else |err| {
        Vapor.printlnErr("style: could not cache, node renders without this group: {any}", .{err});
    }
    return hash_i;
}

var hash_id: bool = false;
const style_hash_null: u32 = 2316552965;
pub fn configure(ui_ctx: *UIContext, elem_decl: ElemDecl) *UINode {
    hash_id = false;
    const stack = ui_ctx.stack orelse unreachable;
    const current_open = stack.ptr orelse unreachable;
    const parent = current_open.parent orelse unreachable;
    const style = elem_decl.style;

    // Early exit if style hasn't changed

    if (elem_decl.elem_type == .ListItem) {
        if (parent.type != .List) {
            Vapor.printlnErr("ListItem must be a child of a List, Otherwise reconciliation will fail\n", .{});
        }
    }

    if (style != null and style.?.id != null) {
        current_open.uuid = style.?.id.?;
    }
    current_open.finger_print +%= parent.finger_print;
    current_open.finger_print +%= @intFromEnum(current_open.type);
    if (elem_decl.elem_type == .Svg) {
        current_open.text = elem_decl.svg;
        current_open.finger_print +%= hashKey(elem_decl.svg);
    } else if (elem_decl.text) |text| {
        current_open.text = text;
        current_open.finger_print +%= hashKey(text);
    }

    if (elem_decl.hover_style_fields) |fields| {
        const hover_style_fields = Vapor.arena(.frame).create([]const types.StyleFields) catch |err| blk_hover: {
            Vapor.printlnErr("hover style: could not allocate, hover styles skipped: {any}", .{err});
            break :blk_hover null;
        } orelse return current_open;
        hover_style_fields.* = fields;
        current_open.hover_style_fields = hover_style_fields;
    }

    if (elem_decl.target) |target| {
        current_open.target = target;
        current_open.finger_print +%= hashKey(target);
    }

    if (elem_decl.text_field_params) |params| blk_tfp: {
        const text_field_params = Vapor.arena(.frame).create(types.TextFieldParams) catch |err| {
            Vapor.printlnErr("text field: could not allocate params, field renders without them: {any}", .{err});
            break :blk_tfp;
        };
        text_field_params.* = params;
        current_open.text_field_params = text_field_params;
        switch (params) {
            .string => |string| {
                var value: []const u8 = "";
                if (string.value_ptr) |ptr| {
                    value = ptr[0..string.value_len];
                }
                var default_value: []const u8 = "";
                if (string.default_ptr) |ptr| {
                    default_value = ptr[0..string.default_len];
                }
                current_open.finger_print +%= hashKey(value);
                current_open.finger_print +%= hashKey(default_value);
                // current_open.finger_print +%= hashKey(string.default orelse "");
                current_open.finger_print +%= @intFromEnum(string.type);
            },
            else => {},
        }
    }

    if (elem_decl.accessibility) |accessibility| {
        Accessibility.a11y_map.put(hashKey(current_open.uuid), accessibility) catch |err| {
            std.log.err("Error adding accessibility {any}\n", .{err});
        };
        current_open.accessibility = true;
        current_open.finger_print +%= hashKey(Accessibility.toAttributeString(accessibility));
    }

    current_open.href = elem_decl.href;
    current_open.type = elem_decl.elem_type;
    current_open.name = elem_decl.name;
    current_open.morph = elem_decl.morph;

    if (current_open.href) |href| {
        current_open.finger_print +%= hashKey(href);
    }

    if (elem_decl.inlineStyle) |inlineStyle| {
        if (inlineStyle.len > 0) {
            current_open.inlineStyle = inlineStyle;
            current_open.style_hash +%= hashKey(inlineStyle);
        }
    }

    if (elem_decl.video) |video| {
        current_open.video = video;
        if (video.src) |src| {
            current_open.finger_print +%= hashKey(src);
        }
        current_open.finger_print +%= @intFromBool(video.autoplay);
        current_open.finger_print +%= @intFromBool(video.muted);
        current_open.finger_print +%= @intFromBool(video.loop);
        current_open.finger_print +%= @intFromBool(video.controls);
    }

    if (current_open.event_handlers) |handlers| {
        for (handlers.handlers.items) |handler| {
            current_open.finger_print +%= @intFromEnum(handler.event_type);
        }
    }

    current_open.props_hash = current_open.finger_print;
    // current_open.finger_print +%= hashKey(current_open.uuid);

    // this adds 60ms
    if (style) |s| outer_style: {
        var hash_l: u32 = 0;
        var hash_v: u32 = 0;
        var hash_p: u32 = 0;
        var hash_mp: u32 = 0;
        var hash_i: u32 = 0;
        var hash_a: u32 = 0;
        var hash_t: u32 = 0;
        var hash_r: u32 = 0;
        var hash_tv: u32 = 0;

        packed_position = .{};
        packed_layout = .{};
        packed_margins_paddings = .{};
        packed_visual = .{};
        packed_animations = .{};
        packed_interactive = .{};
        packed_transition = .{};
        packed_layer = .{ .Grid = .{} };
        packed_transforms = .{};
        packed_responsive = .{};
        target_packed_visual = .{};

        current_open.packed_field_ptrs = PackedFieldPtrs{};
        if (s.style_id != null) {
            hash_id = true;
            current_open.class = s.style_id.?;
        }

        var additonal_classes: ?[]const u8 = null;

        if (s.visual) |visual| {
            if (visual.edges) |e| {
                additonal_classes = e;
            }
        }

        hash_l = configureLayouts(current_open, s);
        hash_v = configureVisual(current_open, s);

        if (s.target_visual) |visual| {
            checkVisual(&visual, &target_packed_visual);
            hash_tv = std.hash.XxHash32.hash(0, std.mem.asBytes(&target_packed_visual));
        }

        hash_p = configurePositions(current_open, s);
        hash_mp = configureMarginsPaddings(current_open, s);
        hash_i = configureInteractive(current_open, s);
        hash_a = configureAnimations(current_open, elem_decl);
        hash_t = configureTransforms(current_open, s);
        hash_r = configureResponsive(current_open, s);

        // ** Packed Animations and Interactive **

        current_open.style_hash +%= hash_l;
        current_open.style_hash +%= hash_p;
        current_open.style_hash +%= hash_mp;
        current_open.style_hash +%= hash_v;
        current_open.style_hash +%= hash_a;
        current_open.style_hash +%= hash_i;
        current_open.style_hash +%= hash_t;
        current_open.style_hash +%= hash_r;
        current_open.style_hash +%= hash_tv;

        // This adds 40ms for 10000 rows
        if (current_open.target) |target| {
            const class = Vapor.frame.fmt("t_vis-{s}", .{target});
            const new_class_hash = hashKey(class);
            _ = Vapor.class_cache.get(new_class_hash) orelse {
                Vapor.class_cache.set(new_class_hash, .defined) catch |err| {
                    Vapor.printlnErr("class cache: not recorded, rule may be re-emitted: {any}", .{err});
                };
                Vapor.generator.writeTargetStyle(current_open, hash_tv, &target_packed_visual);
            };
        }

        if (s.style_id != null) {
            const class = current_open.class.?;
            const new_class_hash = hashKey(class);
            _ = Vapor.class_cache.get(new_class_hash) orelse {
                Vapor.class_cache.set(new_class_hash, .defined) catch |err| {
                    Vapor.printlnErr("class cache: not recorded, rule may be re-emitted: {any}", .{err});
                };
                Vapor.generator.writeNodeStyle(current_open);
            };
        } else {
            if (2316552965 == current_open.style_hash) {
                current_open.class = "";
                current_open.style_hash = 0;
                break :outer_style;
            }
            // This adds 2ms for 10000 nodes
            buildClassString(
                &current_open.packed_field_ptrs.?,
                current_open,
                hash_l,
                hash_p,
                hash_mp,
                hash_v,
                hash_a,
                hash_i,
                hash_t,
                hash_r,
                hash_tv,
                additonal_classes,
            ) catch |err| {
                Vapor.printlnErr("Could not build class string {any}\n", .{err});
            };
        }
    }

    current_open.state_type = elem_decl.state_type;
    current_open.aria_label = elem_decl.aria_label;
    current_open.alt = elem_decl.alt;

    current_open.hooks_hash +%= current_open.on_callbacks[0];

    current_open.finger_print +%= current_open.style_hash;
    current_open.finger_print +%= current_open.hooks_hash;

    current_open.identity_hash +%= current_open.props_hash;
    current_open.identity_hash +%= current_open.style_hash;
    current_open.identity_hash +%= @intFromEnum(current_open.type);

    return current_open;
}

pub fn configureByNode(ui_node: ?*UINode, elem_decl: ElemDecl) *UINode {
    hash_id = false;
    const current_open = ui_node orelse unreachable;
    const parent = current_open.parent orelse unreachable;
    const style = elem_decl.style orelse unreachable;
    inherited_color = null;

    // Early exit if style hasn't changed
    if (elem_decl.elem_type == .ListItem) {
        if (parent.type != .List) {
            Vapor.printlnErr("ListItem must be a child of a List, Otherwise reconciliation will fail\n", .{});
        }
    }

    if (style.id != null) {
        current_open.uuid = style.id.?;
    }
    current_open.finger_print +%= parent.finger_print;
    current_open.finger_print +%= @intFromEnum(current_open.type);
    if (elem_decl.elem_type == .Svg) {
        current_open.text = elem_decl.svg;
        current_open.finger_print +%= hashKey(elem_decl.svg);
    } else if (elem_decl.text) |text| {
        current_open.text = text;
        current_open.finger_print +%= hashKey(text);
    }

    if (elem_decl.text_field_params) |params| blk_tfp: {
        const text_field_params = Vapor.arena(.frame).create(types.TextFieldParams) catch |err| {
            Vapor.printlnErr("text field: could not allocate params, field renders without them: {any}", .{err});
            break :blk_tfp;
        };
        text_field_params.* = params;
        current_open.text_field_params = text_field_params;
        switch (params) {
            .radio => |radio| {
                var value: []const u8 = "";
                if (radio.value_ptr) |ptr| {
                    value = ptr[0..radio.value_len];
                }
                var default_value: []const u8 = "";
                if (radio.default_ptr) |ptr| {
                    default_value = ptr[0..radio.default_len];
                }
                current_open.finger_print +%= hashKey(value);
                current_open.finger_print +%= hashKey(default_value);
                current_open.finger_print +%= @intFromEnum(radio.type);
            },

            .string => |string| {
                var value: []const u8 = "";
                if (string.value_ptr) |ptr| {
                    value = ptr[0..string.value_len];
                }
                var default_value: []const u8 = "";
                if (string.default_ptr) |ptr| {
                    default_value = ptr[0..string.default_len];
                }
                current_open.finger_print +%= hashKey(value);
                current_open.finger_print +%= hashKey(default_value);
                current_open.finger_print +%= @intFromEnum(string.type);
            },
            .email => |email| {
                var value: []const u8 = "";
                if (email.value_ptr) |ptr| {
                    value = ptr[0..email.value_len];
                }
                var default_value: []const u8 = "";
                if (email.default_ptr) |ptr| {
                    default_value = ptr[0..email.default_len];
                }
                current_open.finger_print +%= hashKey(value);
                current_open.finger_print +%= hashKey(default_value);
                current_open.finger_print +%= @intFromEnum(email.type);
            },
            .telephone => |telephone| {
                var value: []const u8 = "";
                if (telephone.value_ptr) |ptr| {
                    value = ptr[0..telephone.value_len];
                }
                var default_value: []const u8 = "";
                if (telephone.default_ptr) |ptr| {
                    default_value = ptr[0..telephone.default_len];
                }
                current_open.finger_print +%= hashKey(value);
                current_open.finger_print +%= hashKey(default_value);
                current_open.finger_print +%= @intFromEnum(telephone.type);
            },
            .file => |file| {
                var value: []const u8 = "";
                if (file.value_ptr) |ptr| {
                    value = ptr[0..file.value_len];
                }
                var default_value: []const u8 = "";
                if (file.default_ptr) |ptr| {
                    default_value = ptr[0..file.default_len];
                }
                current_open.finger_print +%= hashKey(value);
                current_open.finger_print +%= hashKey(default_value);
                current_open.finger_print +%= @intFromEnum(file.type);
            },
            .date => |date| {
                var value: []const u8 = "";
                if (date.value_ptr) |ptr| {
                    value = ptr[0..date.value_len];
                }
                var default_value: []const u8 = "";
                if (date.default_ptr) |ptr| {
                    default_value = ptr[0..date.default_len];
                }
                current_open.finger_print +%= hashKey(value);
                current_open.finger_print +%= hashKey(default_value);
                current_open.finger_print +%= @intFromEnum(date.type);
            },
            .password => |password| {
                var value: []const u8 = "";
                if (password.value_ptr) |ptr| {
                    value = ptr[0..password.value_len];
                }
                var default_value: []const u8 = "";
                if (password.default_ptr) |ptr| {
                    default_value = ptr[0..password.default_len];
                }
                current_open.finger_print +%= hashKey(value);
                current_open.finger_print +%= hashKey(default_value);
                current_open.finger_print +%= @intFromEnum(password.type);
            },
            .int => |number| {
                current_open.finger_print +%= @as(u32, @intCast(number.value orelse 0));
                current_open.finger_print +%= @as(u32, @intCast(number.default orelse 0));
                current_open.finger_print +%= @intFromEnum(number.type);
            },
            .float => |number| {
                current_open.finger_print +%= @as(u32, @intFromFloat(number.value orelse 0));
                current_open.finger_print +%= @as(u32, @intFromFloat(number.default orelse 0));
                current_open.finger_print +%= @intFromEnum(number.type);
            },
        }
    }

    if (elem_decl.hover_style_fields) |fields| {
        const hover_style_fields = Vapor.arena(.frame).create([]const types.StyleFields) catch |err| blk_hover: {
            Vapor.printlnErr("hover style: could not allocate, hover styles skipped: {any}", .{err});
            break :blk_hover null;
        } orelse return current_open;
        hover_style_fields.* = fields;
        current_open.hover_style_fields = hover_style_fields;
    }

    if (elem_decl.accessibility) |accessibility| {
        Accessibility.a11y_map.put(hashKey(current_open.uuid), accessibility) catch |err| {
            std.log.err("Error adding accessibility {any}\n", .{err});
        };
        current_open.accessibility = true;
        current_open.finger_print +%= hashKey(Accessibility.toAttributeString(accessibility));
    }

    current_open.href = elem_decl.href;
    current_open.src = elem_decl.src;
    current_open.type = elem_decl.elem_type;
    current_open.name = elem_decl.name;

    if (current_open.href) |href| {
        current_open.finger_print +%= hashKey(href);
    }

    if (elem_decl.inlineStyle) |inlineStyle| {
        if (inlineStyle.len > 0) {
            current_open.inlineStyle = inlineStyle;
            current_open.style_hash +%= hashKey(inlineStyle);
        }
    }

    if (elem_decl.video) |video| {
        current_open.video = video;
        if (video.src) |src| {
            current_open.finger_print +%= hashKey(src);
        }
        current_open.finger_print +%= @intFromBool(video.autoplay);
        current_open.finger_print +%= @intFromBool(video.muted);
        current_open.finger_print +%= @intFromBool(video.loop);
        current_open.finger_print +%= @intFromBool(video.controls);
    }

    current_open.props_hash = current_open.finger_print;

    // this adds 60ms
    var hash_l: u32 = 0;
    var hash_v: u32 = 0;
    var hash_p: u32 = 0;
    var hash_mp: u32 = 0;
    var hash_i: u32 = 0;
    var hash_a: u32 = 0;
    var hash_t: u32 = 0;
    var hash_r: u32 = 0;
    var hash_tv: u32 = 0;

    hash_l = 0;
    hash_v = 0;
    hash_p = 0;
    hash_mp = 0;
    hash_i = 0;
    hash_a = 0;
    hash_t = 0;
    hash_r = 0;
    hash_tv = 0;

    packed_position = .{};
    packed_layout = .{};
    packed_margins_paddings = .{};
    packed_visual = .{};
    packed_animations = .{};
    packed_interactive = .{};
    packed_transition = .{};
    packed_layer = .{ .Grid = .{} };
    packed_transforms = .{};
    packed_responsive = .{};
    target_packed_visual = .{};

    current_open.packed_field_ptrs = PackedFieldPtrs{};
    if (style.style_id != null) {
        hash_id = true;
        current_open.class = style.style_id.?;
    }

    var additonal_classes: ?[]const u8 = null;

    if (style.visual) |visual| {
        if (visual.edges) |e| {
            additonal_classes = e;
        }
    }

    hash_l = configureLayouts(current_open, style);
    hash_v = configureVisual(current_open, style);

    if (style.target_visual) |visual| {
        checkVisual(&visual, &target_packed_visual);
        hash_tv = std.hash.XxHash32.hash(0, std.mem.asBytes(&target_packed_visual));
    }

    hash_p = configurePositions(current_open, style);
    hash_mp = configureMarginsPaddings(current_open, style);
    hash_i = configureInteractive(current_open, style);
    hash_a = configureAnimations(current_open, elem_decl);
    hash_t = configureTransforms(current_open, style);
    hash_r = configureResponsive(current_open, style);

    // ** Packed Animations and Interactive **

    current_open.style_hash +%= hash_l;
    current_open.style_hash +%= hash_p;
    current_open.style_hash +%= hash_mp;
    current_open.style_hash +%= hash_v;
    current_open.style_hash +%= hash_a;
    current_open.style_hash +%= hash_i;
    current_open.style_hash +%= hash_t;
    current_open.style_hash +%= hash_r;
    current_open.style_hash +%= hash_tv;

    // This adds 40ms for 10000 rows
    if (current_open.target) |target| {
        const class = Vapor.frame.fmt("t_vis-{s}", .{target});
        const new_class_hash = hashKey(class);
        _ = Vapor.class_cache.get(new_class_hash) orelse {
            Vapor.class_cache.set(new_class_hash, .defined) catch |err| {
                Vapor.printlnErr("class cache: not recorded, rule may be re-emitted: {any}", .{err});
            };
            Vapor.generator.writeTargetStyle(current_open, hash_tv, &target_packed_visual);
        };
    }

    if (style.style_id != null) {
        const class = current_open.class.?;
        const new_class_hash = hashKey(class);
        _ = Vapor.class_cache.get(new_class_hash) orelse {
            Vapor.class_cache.set(new_class_hash, .defined) catch |err| {
                Vapor.printlnErr("class cache: not recorded, rule may be re-emitted: {any}", .{err});
            };
            Vapor.generator.writeNodeStyle(current_open);
        };
    } else {
        // This adds 2ms for 10000 nodes
        buildClassString(
            &current_open.packed_field_ptrs.?,
            current_open,
            hash_l,
            hash_p,
            hash_mp,
            hash_v,
            hash_a,
            hash_i,
            hash_t,
            hash_r,
            hash_tv,
            additonal_classes,
        ) catch |err| {
            Vapor.printlnErr("Could not build class string {any}\n", .{err});
        };
    }

    current_open.state_type = elem_decl.state_type;
    current_open.aria_label = elem_decl.aria_label;
    current_open.alt = elem_decl.alt;

    current_open.hooks_hash +%= current_open.on_callbacks[0];
    current_open.finger_print +%= current_open.style_hash;
    current_open.finger_print +%= current_open.hooks_hash;

    current_open.identity_hash +%= current_open.props_hash;
    current_open.identity_hash +%= current_open.style_hash;
    current_open.identity_hash +%= @intFromEnum(current_open.type);

    return current_open;
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
            inherited_color = color;
        }
        if (inherited_color) |in| {
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

pub fn configurePlainByNode(ui_node: ?*UINode, elem_decl: ElemDecl) *UINode {
    hash_id = false;
    const current_open = ui_node orelse unreachable;
    const parent = current_open.parent orelse unreachable;
    inherited_color = null;

    // Early exit if style hasn't changed

    if (elem_decl.elem_type == .ListItem) {
        if (parent.type != .List) {
            Vapor.printlnErr("ListItem must be a child of a List, Otherwise reconciliation will fail\n", .{});
        }
    }

    current_open.finger_print +%= parent.finger_print;
    current_open.finger_print +%= @intFromEnum(current_open.type);
    if (elem_decl.elem_type == .Svg) {
        current_open.text = elem_decl.svg;
        current_open.finger_print +%= hashKey(elem_decl.svg);
    } else if (elem_decl.text) |text| {
        current_open.text = text;
        current_open.finger_print +%= hashKey(text);
    }

    if (elem_decl.text_field_params) |params| blk_tfp: {
        const text_field_params = Vapor.arena(.frame).create(types.TextFieldParams) catch |err| {
            Vapor.printlnErr("text field: could not allocate params, field renders without them: {any}", .{err});
            break :blk_tfp;
        };
        text_field_params.* = params;
        current_open.text_field_params = text_field_params;
        switch (params) {
            .string => |string| {
                var value: []const u8 = "";
                if (string.value_ptr) |ptr| {
                    value = ptr[0..string.value_len];
                }
                var default_value: []const u8 = "";
                if (string.default_ptr) |ptr| {
                    default_value = ptr[0..string.default_len];
                }
                current_open.finger_print +%= hashKey(value);
                current_open.finger_print +%= hashKey(default_value);
                current_open.finger_print +%= @intFromEnum(string.type);
            },
            .radio => |radio| {
                var value: []const u8 = "";
                if (radio.value_ptr) |ptr| {
                    value = ptr[0..radio.value_len];
                }
                var default_value: []const u8 = "";
                if (radio.default_ptr) |ptr| {
                    default_value = ptr[0..radio.default_len];
                }
                current_open.finger_print +%= hashKey(value);
                current_open.finger_print +%= hashKey(default_value);
                current_open.finger_print +%= @intFromEnum(radio.type);
            },
            .email => |email| {
                var value: []const u8 = "";
                if (email.value_ptr) |ptr| {
                    value = ptr[0..email.value_len];
                }
                var default_value: []const u8 = "";
                if (email.default_ptr) |ptr| {
                    default_value = ptr[0..email.default_len];
                }
                current_open.finger_print +%= hashKey(value);
                current_open.finger_print +%= hashKey(default_value);
                current_open.finger_print +%= @intFromEnum(email.type);
            },
            .telephone => |telephone| {
                var value: []const u8 = "";
                if (telephone.value_ptr) |ptr| {
                    value = ptr[0..telephone.value_len];
                }
                var default_value: []const u8 = "";
                if (telephone.default_ptr) |ptr| {
                    default_value = ptr[0..telephone.default_len];
                }
                current_open.finger_print +%= hashKey(value);
                current_open.finger_print +%= hashKey(default_value);
                current_open.finger_print +%= @intFromEnum(telephone.type);
            },
            .file => |file| {
                var value: []const u8 = "";
                if (file.value_ptr) |ptr| {
                    value = ptr[0..file.value_len];
                }
                var default_value: []const u8 = "";
                if (file.default_ptr) |ptr| {
                    default_value = ptr[0..file.default_len];
                }
                current_open.finger_print +%= hashKey(value);
                current_open.finger_print +%= hashKey(default_value);
                current_open.finger_print +%= @intFromEnum(file.type);
            },
            .date => |date| {
                var value: []const u8 = "";
                if (date.value_ptr) |ptr| {
                    value = ptr[0..date.value_len];
                }
                var default_value: []const u8 = "";
                if (date.default_ptr) |ptr| {
                    default_value = ptr[0..date.default_len];
                }
                current_open.finger_print +%= hashKey(value);
                current_open.finger_print +%= hashKey(default_value);
                current_open.finger_print +%= @intFromEnum(date.type);
            },
            .password => |password| {
                var value: []const u8 = "";
                if (password.value_ptr) |ptr| {
                    value = ptr[0..password.value_len];
                }
                var default_value: []const u8 = "";
                if (password.default_ptr) |ptr| {
                    default_value = ptr[0..password.default_len];
                }
                current_open.finger_print +%= hashKey(value);
                current_open.finger_print +%= hashKey(default_value);
                current_open.finger_print +%= @intFromEnum(password.type);
            },
            .int => |number| {
                current_open.finger_print +%= @as(u32, @intCast(number.value orelse 0));
                current_open.finger_print +%= @as(u32, @intCast(number.default orelse 0));
                current_open.finger_print +%= @intFromEnum(number.type);
            },
            .float => |number| {
                current_open.finger_print +%= @as(u32, @intFromFloat(number.value orelse 0));
                current_open.finger_print +%= @as(u32, @intFromFloat(number.default orelse 0));
                current_open.finger_print +%= @intFromEnum(number.type);
            },
        }
    }

    if (elem_decl.accessibility) |accessibility| {
        Accessibility.a11y_map.put(hashKey(current_open.uuid), accessibility) catch |err| {
            std.log.err("Error adding accessibility {any}\n", .{err});
        };
        current_open.accessibility = true;
        current_open.finger_print +%= hashKey(Accessibility.toAttributeString(accessibility));
    }

    current_open.href = elem_decl.href;
    current_open.src = elem_decl.src;
    current_open.type = elem_decl.elem_type;
    current_open.name = elem_decl.name;

    if (current_open.href) |href| {
        current_open.finger_print +%= hashKey(href);
    }

    if (elem_decl.inlineStyle) |inlineStyle| {
        if (inlineStyle.len > 0) {
            current_open.inlineStyle = inlineStyle;
            current_open.style_hash +%= hashKey(inlineStyle);
        }
    }

    if (elem_decl.video) |video| {
        current_open.video = video;
        if (video.src) |src| {
            current_open.finger_print +%= hashKey(src);
        }
        current_open.finger_print +%= @intFromBool(video.autoplay);
        current_open.finger_print +%= @intFromBool(video.muted);
        current_open.finger_print +%= @intFromBool(video.loop);
        current_open.finger_print +%= @intFromBool(video.controls);
    }

    current_open.props_hash = current_open.finger_print;

    // this adds 60ms
    current_open.state_type = elem_decl.state_type;
    current_open.aria_label = elem_decl.aria_label;
    current_open.alt = elem_decl.alt;

    current_open.finger_print +%= current_open.style_hash;

    return current_open;
}
