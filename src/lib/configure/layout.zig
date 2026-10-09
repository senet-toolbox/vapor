const Configuration = @import("../Configuration.zig");
const UINode = @import("../UITree.zig").UINode;
const std = @import("std");
const types = @import("../types.zig");
const Vapor = @import("../Vapor.zig");
const utils = @import("../utils.zig");
const hashKey = utils.hashKey;
const StringTable = @import("../StringTable.zig").StringTable;
const Packer = @import("../Packer.zig");

pub fn configureLayouts(ui_node: *UINode, style: *const Vapor.Style) u32 {
    var hash_l: u32 = 0;

    if (ui_node.parent) |parent| {
        if (parent.direction == .column) {
            Configuration.packed_layout.parent_direction = .column;
        }
        if (parent.column_count) |count| {
            if (parent.spacing) |spacing| {
                Configuration.packed_layout.column_count = count;
                if (spacing > count) {
                    Configuration.packed_layout.column_spacing = @as(f32, @floatFromInt(spacing)) / @as(f32, @floatFromInt(count));
                } else {}
            }
        }
    }

    if (style.flex_type == .hidden) {
        Configuration.packed_layout.flex = .hidden;
    } else if (style.layout) |layout| {
        if (layout.x == .in_line and layout.y == .in_line) {
            Configuration.packed_layout.flex = .flow;
            Configuration.packed_layout.layout = layout;
        } else if (ui_node.text != null) {
            Configuration.packed_layout.text_align = layout;
        } else {
            Configuration.packed_layout.flex = .flex;
            Configuration.packed_layout.layout = layout;
        }
    } else if (ui_node.type == .FlexBox) {
        Configuration.packed_layout.flex = .flex;
    }

    if (style.placement) |placement| Configuration.packed_layout.placement = placement;
    if (style.size) |size| Configuration.packed_layout.size = size;
    if (style.child_gap) |child_gap| Configuration.packed_layout.spacing = child_gap;
    if (style.spacing) |spacing| Configuration.packed_layout.spacing = spacing;
    if (style.direction) |direction| Configuration.packed_layout.direction = direction;
    if (style.flex_wrap) |flex_wrap| Configuration.packed_layout.flex_wrap = flex_wrap;
    if (style.scroll) |scroll| Configuration.packed_layout.scroll = scroll;
    if (style.aspect_ratio) |aspect_ratio| Configuration.packed_layout.aspect_ratio = aspect_ratio;

    hash_l = std.hash.XxHash32.hash(0, std.mem.asBytes(&Configuration.packed_layout));

    if (Configuration.hash_id) {
        if (Packer.layouts_pool.create()) |packed_layout_ptr| {
            packed_layout_ptr.* = Configuration.packed_layout;
            ui_node.packed_field_ptrs.?.layout_ptr = packed_layout_ptr;
        } else |err| {
            Vapor.printlnErr("style: could not allocate, node renders without this group: {any}", .{err});
        }
        return hash_l;
    }
    if (Configuration.getOrPutAndUpdateHash(
        hash_l,
        types.PackedLayout,
        Configuration.packed_layout,
        &Packer.layouts,
        &Packer.layouts_pool,
    )) |ptr| {
        ui_node.packed_field_ptrs.?.layout_ptr = ptr;
    } else |err| {
        Vapor.printlnErr("style: could not cache, node renders without this group: {any}", .{err});
    }
    return hash_l;
}

pub fn configureResponsive(ui_node: *UINode, style: *const Vapor.Style) u32 {
    var hash_r: u32 = 0;

    const responsive = style.responsive orelse return hash_r;
    if (responsive.mobile) |s| {
        if (ui_node.parent) |parent| {
            if (parent.direction == .column) {
                Configuration.packed_responsive.mobile_layout.parent_direction = .column;
            }
            if (parent.column_count) |count| {
                if (parent.spacing) |spacing| {
                    Configuration.packed_responsive.mobile_layout.column_count = count;
                    if (spacing > count) {
                        Configuration.packed_responsive.mobile_layout.column_spacing = @as(f32, @floatFromInt(spacing)) / @as(f32, @floatFromInt(count));
                    } else {}
                }
            }
        }

        if (s.flex_type == .hidden) {
            Configuration.packed_responsive.mobile_layout.flex = .hidden;
        } else if (s.layout) |layout| {
            if (layout.x == .in_line and layout.y == .in_line) {
                Configuration.packed_responsive.mobile_layout.flex = .flow;
                Configuration.packed_responsive.mobile_layout.layout = layout;
            } else if (ui_node.text != null) {
                Configuration.packed_responsive.mobile_layout.text_align = layout;
            } else {
                Configuration.packed_responsive.mobile_layout.flex = .flex;
                Configuration.packed_responsive.mobile_layout.layout = layout;
            }
        } else if (ui_node.type == .FlexBox) {
            Configuration.packed_responsive.mobile_layout.flex = .flex;
        }

        if (s.placement) |placement| Configuration.packed_responsive.mobile_layout.placement = placement;
        if (s.size) |size| Configuration.packed_responsive.mobile_layout.size = size;
        if (s.child_gap) |child_gap| Configuration.packed_responsive.mobile_layout.spacing = child_gap;
        if (s.spacing) |spacing| Configuration.packed_responsive.mobile_layout.spacing = spacing;
        if (s.direction) |direction| Configuration.packed_responsive.mobile_layout.direction = direction;
        if (s.flex_wrap) |flex_wrap| Configuration.packed_responsive.mobile_layout.flex_wrap = flex_wrap;
        if (s.scroll) |scroll| Configuration.packed_responsive.mobile_layout.scroll = scroll;
        if (s.aspect_ratio) |aspect_ratio| Configuration.packed_responsive.mobile_layout.aspect_ratio = aspect_ratio;
        Configuration.packed_responsive.flags_layout[0] = true;

        if (s.visual) |visual| {
            if (ui_node.type == .Button or ui_node.type == .ButtonCycle or ui_node.type == .CtxButton) {
                if (!Configuration.packed_responsive.mobile_visual.has_border_thickeness) {
                    Configuration.packed_responsive.mobile_visual.has_border_thickeness = true;
                    Configuration.packed_responsive.mobile_visual.border_thickness = .all(0);
                    Configuration.packed_responsive.mobile_visual.background = .{ .color = .{ .a = 0, .r = 0, .g = 0, .b = 0 }, .has_color = true };
                }
            }
            Configuration.checkVisual(&visual, &Configuration.packed_responsive.mobile_visual);
            Configuration.packed_responsive.flags_visual[0] = true;
        }
    }

    if (responsive.desktop) |s| {
        if (ui_node.parent) |parent| {
            if (parent.direction == .column) {
                Configuration.packed_responsive.desktop_layout.parent_direction = .column;
            }
            if (parent.column_count) |count| {
                if (parent.spacing) |spacing| {
                    Configuration.packed_responsive.desktop_layout.column_count = count;
                    if (spacing > count) {
                        Configuration.packed_responsive.desktop_layout.column_spacing = @as(f32, @floatFromInt(spacing)) / @as(f32, @floatFromInt(count));
                    } else {}
                }
            }
        }

        if (s.flex_type == .hidden) {
            Configuration.packed_responsive.desktop_layout.flex = .hidden;
        } else if (s.layout) |layout| {
            if (layout.x == .in_line and layout.y == .in_line) {
                Configuration.packed_responsive.desktop_layout.flex = .flow;
                Configuration.packed_responsive.desktop_layout.layout = layout;
            } else if (ui_node.text != null) {
                Configuration.packed_responsive.desktop_layout.text_align = layout;
            } else {
                Configuration.packed_responsive.desktop_layout.flex = .flex;
                Configuration.packed_responsive.desktop_layout.layout = layout;
            }
        } else if (ui_node.type == .FlexBox) {
            Configuration.packed_responsive.desktop_layout.flex = .flex;
        }

        if (s.placement) |placement| Configuration.packed_responsive.desktop_layout.placement = placement;
        if (s.size) |size| Configuration.packed_responsive.desktop_layout.size = size;
        if (s.child_gap) |child_gap| Configuration.packed_responsive.desktop_layout.spacing = child_gap;
        if (s.spacing) |spacing| Configuration.packed_responsive.desktop_layout.spacing = spacing;
        if (s.direction) |direction| Configuration.packed_responsive.desktop_layout.direction = direction;
        if (s.flex_wrap) |flex_wrap| Configuration.packed_responsive.desktop_layout.flex_wrap = flex_wrap;
        if (s.scroll) |scroll| Configuration.packed_responsive.desktop_layout.scroll = scroll;
        if (s.aspect_ratio) |aspect_ratio| Configuration.packed_responsive.desktop_layout.aspect_ratio = aspect_ratio;
        Configuration.packed_responsive.flags_layout[1] = true;

        if (s.visual) |visual| {
            if (ui_node.type == .Button or ui_node.type == .ButtonCycle or ui_node.type == .CtxButton) {
                if (!Configuration.packed_responsive.desktop_visual.has_border_thickeness) {
                    Configuration.packed_responsive.desktop_visual.has_border_thickeness = true;
                    Configuration.packed_responsive.desktop_visual.border_thickness = .all(0);
                    Configuration.packed_responsive.desktop_visual.background = .{ .color = .{ .a = 0, .r = 0, .g = 0, .b = 0 }, .has_color = true };
                }
            }

            Configuration.checkVisual(&visual, &Configuration.packed_responsive.desktop_visual);
            Configuration.packed_responsive.flags_visual[1] = true;
        }
    }

    hash_r = std.hash.XxHash32.hash(0, std.mem.asBytes(&Configuration.packed_responsive));

    if (Configuration.hash_id) {
        if (Packer.responsive_pool.create()) |packed_responsive_ptr| {
            packed_responsive_ptr.* = Configuration.packed_responsive;
            ui_node.packed_field_ptrs.?.responsive_ptr = packed_responsive_ptr;
        } else |err| {
            Vapor.printlnErr("style: could not allocate, node renders without this group: {any}", .{err});
        }
        return hash_r;
    }

    if (Configuration.getOrPutAndUpdateHash(
        hash_r,
        types.PackedResponsive,
        Configuration.packed_responsive,
        &Packer.responsives,
        &Packer.responsive_pool,
    )) |ptr| {
        ui_node.packed_field_ptrs.?.responsive_ptr = ptr;
    } else |err| {
        Vapor.printlnErr("style: could not cache, node renders without this group: {any}", .{err});
    }

    return hash_r;
}

pub fn configurePositions(ui_node: *UINode, style: *const Vapor.Style) u32 {
    var hash_p: u32 = 0;
    if (style.anchor) |anchor| {
        if (ui_node.type == .Anchor) {
            Configuration.packed_position.position_anchor_handle = Vapor.string_table.intern(anchor) catch StringTable.null_handle;
            hash_p +%= hashKey(anchor);
        } else {
            Configuration.packed_position.anchor_name_handle = Vapor.string_table.intern(anchor) catch StringTable.null_handle;
            hash_p +%= hashKey(anchor);
        }
    }

    if (style.position) |position| {
        // ** Packed Position **
        Configuration.packed_position.position_type = position.type;
        if (position.top) |top| Configuration.packed_position.top = .{ .type = top.type, .value = top.value };
        if (position.right) |right| Configuration.packed_position.right = .{ .type = right.type, .value = right.value };
        if (position.bottom) |bottom| Configuration.packed_position.bottom = .{ .type = bottom.type, .value = bottom.value };
        if (position.left) |left| Configuration.packed_position.left = .{ .type = left.type, .value = left.value };
        if (position.z_index) |z_index| Configuration.packed_position.z_index = z_index;
    }

    hash_p = std.hash.XxHash32.hash(0, std.mem.asBytes(&Configuration.packed_position));

    if (Configuration.hash_id) {
        if (Packer.positions_pool.create()) |packed_position_ptr| {
            packed_position_ptr.* = Configuration.packed_position;
            ui_node.packed_field_ptrs.?.position_ptr = packed_position_ptr;
        } else |err| {
            Vapor.printlnErr("style: could not allocate, node renders without this group: {any}", .{err});
        }
        return hash_p;
    }
    if (Configuration.getOrPutAndUpdateHash(
        hash_p,
        types.PackedPosition,
        Configuration.packed_position,
        &Packer.positions,
        &Packer.positions_pool,
    )) |ptr| {
        ui_node.packed_field_ptrs.?.position_ptr = ptr;
    } else |err| {
        Vapor.printlnErr("style: could not cache, node renders without this group: {any}", .{err});
    }
    return hash_p;
}

pub fn configureMarginsPaddings(ui_node: *UINode, style: *const Vapor.Style) u32 {
    var hash_mp: u32 = 0;
    // ** Packed Margins and Padding **
    if (style.padding) |padding| Configuration.packed_margins_paddings.padding = padding;
    if (style.margin) |margin| Configuration.packed_margins_paddings.margin = margin;

    // This is an expensive operation, since the the visual hash is quite large
    hash_mp = std.hash.XxHash32.hash(0, std.mem.asBytes(&Configuration.packed_margins_paddings));
    if (Configuration.hash_id) {
        if (Packer.margins_paddings_pool.create()) |packed_margin_paddings_ptr| {
            packed_margin_paddings_ptr.* = Configuration.packed_margins_paddings;
            ui_node.packed_field_ptrs.?.margins_paddings_ptr = packed_margin_paddings_ptr;
        } else |err| {
            Vapor.printlnErr("style: could not allocate, node renders without this group: {any}", .{err});
        }
        return hash_mp;
    }
    if (Configuration.getOrPutAndUpdateHash(
        hash_mp,
        types.PackedMarginsPaddings,
        Configuration.packed_margins_paddings,
        &Packer.margins_paddings,
        &Packer.margins_paddings_pool,
    )) |ptr| {
        ui_node.packed_field_ptrs.?.margins_paddings_ptr = ptr;
    } else |err| {
        Vapor.printlnErr("style: could not cache, node renders without this group: {any}", .{err});
    }
    return hash_mp;
}
