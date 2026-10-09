const Configuration = @import("../Configuration.zig");
const UINode = @import("../UITree.zig").UINode;
const std = @import("std");
const types = @import("../types.zig");
const ElemDecl = types.ElementDeclaration;
const Vapor = @import("../Vapor.zig");
const utils = @import("../utils.zig");
const hashKey = utils.hashKey;
const StringTable = @import("../StringTable.zig").StringTable;
const Packer = @import("../Packer.zig");
const VisualModule = @import("visual.zig");
const checkVisual = VisualModule.checkVisual;

pub fn configureTransforms(ui_node: *UINode, style: *const Vapor.Style) u32 {
    var hash_t: u32 = 0;
    if (style.transform_origin) |transform_origin| {
        Configuration.packed_transforms.transform_origin = transform_origin;
    }

    if (style.visual) |visual| {
        if (visual.transform) |transform| {
            Configuration.packed_transforms.has_transform = true;
            Configuration.packed_transforms.transform = handleTransform(transform, &hash_t);
        }
    }

    hash_t +%= std.hash.XxHash32.hash(0, std.mem.asBytes(&Configuration.packed_transforms));

    if (style.visual) |visual| {
        if (visual.transform) |transform| {
            var packed_transform: types.PackedTransform = undefined;
            // I updated this so that it is the frame allocator
            packed_transform.set(&transform);
            Configuration.packed_transforms.transform = packed_transform;
        }
    }
    // Early exit if nothing to store
    if (!Configuration.packed_transforms.has_transform and style.transform_origin == null) {
        return hash_t;
    }

    if (Configuration.hash_id) {
        if (Packer.transforms_pool.create()) |packed_transforms_ptr| {
            packed_transforms_ptr.* = Configuration.packed_transforms;
            ui_node.packed_field_ptrs.?.transforms_ptr = packed_transforms_ptr;
        } else |err| {
            Vapor.printlnErr("style: could not allocate, node renders without this group: {any}", .{err});
        }
        return hash_t;
    }
    if (Configuration.getOrPutAndUpdateHash(
        hash_t,
        types.PackedTransforms,
        Configuration.packed_transforms,
        &Packer.transforms,
        &Packer.transforms_pool,
    )) |ptr| {
        ui_node.packed_field_ptrs.?.transforms_ptr = ptr;
    } else |err| {
        Vapor.printlnErr("style: could not cache, node renders without this group: {any}", .{err});
    }
    return hash_t;
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

pub fn configureAnimations(ui_node: *UINode, elem_decl: ElemDecl) u32 {
    const has_animation = elem_decl.animation_enter != null or elem_decl.animation_exit != null;
    if (!has_animation) return 0;

    var hash_a: u32 = 0;

    if (elem_decl.animation_enter) |animation_enter| {
        Configuration.packed_animations.has_animation_enter = true;
        Configuration.packed_animations.animation_enter = Vapor.string_table.intern(animation_enter) catch StringTable.null_handle;
        hash_a +%= hashKey(animation_enter);
    }

    if (elem_decl.animation_exit) |animation_exit| {
        ui_node.animation_exit = animation_exit;
        Configuration.packed_animations.has_animation_exit = true;
        Configuration.packed_animations.animation_exit = Vapor.string_table.intern(animation_exit) catch StringTable.null_handle;
        hash_a +%= hashKey(animation_exit);
    }

    if (!Configuration.packed_animations.has_animation_enter and !Configuration.packed_animations.has_animation_exit) return 0;

    hash_a = std.hash.XxHash32.hash(0, std.mem.asBytes(&Configuration.packed_animations));

    if (Configuration.hash_id) {
        if (Packer.animations_pool.create()) |packed_animations_ptr| {
            packed_animations_ptr.* = Configuration.packed_animations;
            ui_node.packed_field_ptrs.?.animations_ptr = packed_animations_ptr;
        } else |err| {
            Vapor.printlnErr("style: could not allocate, node renders without this group: {any}", .{err});
        }
        return hash_a;
    }

    if (Configuration.getOrPutAndUpdateHash(
        hash_a,
        types.PackedAnimations,
        Configuration.packed_animations,
        &Packer.animations,
        &Packer.animations_pool,
    )) |ptr| {
        ui_node.packed_field_ptrs.?.animations_ptr = ptr;
    } else |err| {
        Vapor.printlnErr("style: could not cache, node renders without this group: {any}", .{err});
    }
    return hash_a;
}

pub fn configureInteractive(ui_node: *UINode, style: *const Vapor.Style) u32 {
    var hash_i: u32 = 0;
    const interactive = style.interactive orelse return hash_i;
    if (interactive.hover) |hover| {
        var packed_hover: types.PackedVisual = .{};
        checkVisual(&hover, &packed_hover);

        Configuration.packed_interactive.has_hover = true;
        Configuration.packed_interactive.hover = packed_hover;

        if (hover.transform) |transform| {
            Configuration.packed_interactive.has_hover_transform = true;
            Configuration.packed_interactive.hover_transform = handleTransform(transform, &hash_i);
        }
    }

    if (interactive.hover_position) |hover_position| {
        Configuration.packed_interactive.has_hover_position = true;
        Configuration.packed_interactive.hover_position = .{};
        Configuration.packed_interactive.hover_position.position_type = hover_position.type;
        if (hover_position.top) |top| Configuration.packed_interactive.hover_position.top = .{ .type = top.type, .value = top.value };
        if (hover_position.right) |right| Configuration.packed_interactive.hover_position.right = .{ .type = right.type, .value = right.value };
        if (hover_position.bottom) |bottom| Configuration.packed_interactive.hover_position.bottom = .{ .type = bottom.type, .value = bottom.value };
        if (hover_position.left) |left| Configuration.packed_interactive.hover_position.left = .{ .type = left.type, .value = left.value };
        if (hover_position.z_index) |z_index| Configuration.packed_interactive.hover_position.z_index = z_index;
    }

    if (interactive.focus) |focus| {
        var packed_focus: types.PackedVisual = .{};
        checkVisual(&focus, &packed_focus);
        Configuration.packed_interactive.has_focus = true;
        Configuration.packed_interactive.focus = packed_focus;
    }

    hash_i = std.hash.XxHash32.hash(0, std.mem.asBytes(&Configuration.packed_interactive));

    if (interactive.hover) |hover| {
        if (hover.animation) |animation| {
            Configuration.packed_interactive.hover.animation = Vapor.string_table.intern(animation) catch StringTable.null_handle;
            hash_i +%= hashKey(animation);
        }

        if (hover.animation_name) |animation_name| {
            if (animation_name.len > 0) {
                hash_i +%= hashKey(animation_name);
                Configuration.packed_interactive.hover.animation_name_handle = Vapor.string_table.intern(animation_name) catch StringTable.null_handle;
            }
        }

        if (hover.transform) |transform| {
            var packed_transform: types.PackedTransform = undefined;
            packed_transform.set(&transform);
            Configuration.packed_interactive.hover_transform = packed_transform;
        }
    }

    if (Configuration.hash_id) {
        if (Packer.interactives_pool.create()) |packed_interactive_ptr| {
            packed_interactive_ptr.* = Configuration.packed_interactive;
            ui_node.packed_field_ptrs.?.interactive_ptr = packed_interactive_ptr;
        } else |err| {
            Vapor.printlnErr("style: could not allocate, node renders without this group: {any}", .{err});
        }
        return hash_i;
    }

    if (Configuration.getOrPutAndUpdateHash(
        hash_i,
        types.PackedInteractive,
        Configuration.packed_interactive,
        &Packer.interactives,
        &Packer.interactives_pool,
    )) |ptr| {
        ui_node.packed_field_ptrs.?.interactive_ptr = ptr;
    } else |err| {
        Vapor.printlnErr("style: could not cache, node renders without this group: {any}", .{err});
    }
    return hash_i;
}
