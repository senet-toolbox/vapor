const Vapor = @import("Vapor.zig");
const UIContext = @import("UITree.zig");
const UINode = @import("UITree.zig").UINode;
const Wasm = @import("WASM.zig");
const std = @import("std");

pub fn printUIRouteTree(route: []const u8) void {
    Vapor.frame_arena.beginFrame(); // For double-buffered approach
    Vapor.current_route = route;
    // Vapor.btn_registry.clearRetainingCapacity();
    // Vapor.mounted_funcs.clearRetainingCapacity();

    // ctx_callback_registry.clearRetainingCapacity();

    // mounted_ctx_funcs.clearRetainingCapacity();

    // Get the old context for current route
    const old_route = Vapor.router.searchRoute(route) orelse {
        Vapor.printlnWithColor("No Router found {s}\n", .{route}, "#FF3029", "ERROR");
        Vapor.printlnWithColor("Loading Error Page\n", .{}, "#FF3029", "ERROR");
        return;
    };
    Vapor.render_page = old_route.page;
    Vapor.route_params = old_route.params;
    const old_ctx = Vapor.current_ctx;
    // Create new context
    const new_ctx: *UIContext = Vapor.allocator_global.create(UIContext) catch {
        Vapor.println("Failed to allocate UIContext\n", .{});
        return;
    };

    UIContext.initContext(new_ctx) catch |err| {
        Vapor.println("Allocator ran out of space {any}\n", .{err});
        new_ctx.deinit();
        Vapor.allocator_global.destroy(new_ctx);
        return;
    };

    new_ctx.root.?.uuid = old_ctx.root.?.uuid;

    // Pure tree is attached to the traversal algo, ie itll be updated when the traversal algo is updated
    // pure_tree.init(new_ctx.root.?, &allocator_global) catch {};
    // error_tree.init(new_ctx.root.?, &allocator_global) catch {};
    // Here we set the current_ctx to the new_ctx
    Vapor.current_ctx = new_ctx;
    var route_itr = std.mem.tokenizeScalar(u8, route, '/');
    var count: usize = 0;
    while (route_itr.next()) |_| {
        count += 1;
    }
    Vapor.route_segments = Vapor.allocator_global.alloc([]const u8, count) catch return;
    count = 0;
    route_itr.reset();
    while (route_itr.next()) |route_token| {
        Vapor.route_segments[count] = route_token;
        count += 1;
    }

    Vapor.next_layout_path_to_check = "";
    // We call the routes and nested layuts
    // This finds the reset layout, if it exists
    Vapor.findResetLayout();
    // This calls the render tree, with render_page as the root function call
    // First it traverses the layouts calling them in order, and then it calls the render_page
    Vapor.callNestedLayouts(); // 4.5ms

    // We reconcile the new dom
    // the reason the vapor-debugger gets remvoed is the new ui tree does not include it;

    // const valid_route = replace_dash(current_route) catch unreachable;
    // defer allocator_global.free(valid_route);

    // writer.print("\"{s}\":", .{current_route}) catch unreachable;
    // writer.writeAll("{\n") catch unreachable;
    printStaticTextNode(new_ctx.root.?);
    // writer.writeAll("}\n") catch unreachable;
}

pub fn printUITree(node: *UINode) void {
    // if (node.dirty) {
    Vapor.println("UI: {s}\n", .{node.uuid});
    // }
    var children = node.children();
    while (children.next()) |child| {
        printUITree(child);
    }
}

pub fn escapeForJson(input: []const u8) ![]u8 {
    var list = std.array_list.Managed(u8).init(Vapor.allocator_global);

    for (input) |c| {
        switch (c) {
            '"' => {
                // Add backslash before quote: → \"
                try list.append('\\');
                try list.append('"');
            },
            '\\' => {
                // Optional: also escape existing backslashes → \\
                try list.append('\\');
                try list.append('\\');
            },
            '\n' => {
                // Optional: also escape existing backslashes → \\
                continue;
            },
            else => {
                try list.append(c);
            },
        }
    }

    return list.toOwnedSlice();
}

pub fn replace_dash(input: []const u8) ![]u8 {
    var list = std.array_list.Managed(u8).init(Vapor.allocator_global);

    for (input) |c| {
        switch (c) {
            '/' => {
                // Add backslash before quote: → \"
                try list.append('-');
            },
            else => {
                try list.append(c);
            },
        }
    }

    return list.toOwnedSlice();
}

pub fn printStaticTextNode(node: *UINode) void {
    if (node.state_type == .static) blk: {
        var valid_text: []const u8 = "";
        if (node.text) |text| {
            valid_text = escapeForJson(text) catch |err| {
                Vapor.printlnErr("static text: skipping '{s}': {any}", .{ node.uuid, err });
                break :blk;
            };
        } else if (node.href) |href| {
            valid_text = escapeForJson(href) catch |err| {
                Vapor.printlnErr("static text: skipping '{s}': {any}", .{ node.uuid, err });
                break :blk;
            };
        } else break :blk;
        defer Vapor.allocator_global.free(valid_text);
        if (Vapor.writer.end > Vapor.current_route.len + 10) {
            _ = Vapor.writer.write(",\n") catch |err| {
                Vapor.printlnErr("static text: manifest truncated at '{s}': {any}", .{ node.uuid, err });
                break :blk;
            };
        }
        Vapor.writer.print("\"{s}\":\"{s}\"", .{ node.uuid, valid_text }) catch |err| {
            Vapor.printlnErr("static text: manifest truncated at '{s}': {any}", .{ node.uuid, err });
            break :blk;
        };
    }
    var children = node.children();
    while (children.next()) |child| {
        printStaticTextNode(child);
    }
}

/// Set when `collectComponentIds` could not record a match, so
/// `queryComponentIds` can report a short list instead of returning one that
/// looks complete.
pub var component_id_collection_failed: bool = false;

pub fn collectComponentIds(node: *UINode, selected_type: Vapor.ElementType, component_ids: *std.array_list.Managed([]const u8)) void {
    if (node.type == selected_type) {
        component_ids.append(node.uuid) catch |err| {
            Vapor.printlnErr("queryComponentIds: could not record '{s}': {any}", .{ node.uuid, err });
            component_id_collection_failed = true;
        };
    }
    var children = node.children();
    while (children.next()) |child| {
        collectComponentIds(child, selected_type, component_ids);
    }
}

pub fn queryComponentIds(target_type: Vapor.ElementType) ![][]const u8 {
    const root = Vapor.current_ctx.root orelse return error.NoTree;
    var component_ids = std.array_list.Managed([]const u8).init(Vapor.allocator_global);
    component_id_collection_failed = false;
    collectComponentIds(root, target_type, &component_ids);
    if (component_id_collection_failed) {
        component_ids.deinit();
        return error.OutOfMemory;
    }
    return try component_ids.toOwnedSlice();
}

pub fn findNodeByUUID(node: *UINode, uuid: []const u8) ?*UINode {
    // 1. Check the current node
    if (std.mem.eql(u8, node.uuid, uuid)) {
        return node;
    }

    // 2. Iterate through children
    var children = node.children();
    while (children.next()) |child| {
        // Only return if we actually found something!
        if (findNodeByUUID(child, uuid)) |found| {
            return found;
        }
    }

    // 3. No match found in this branch
    return null;
}

pub fn queryByUUID(uuid: []const u8) !*UINode {
    const root = Vapor.current_ctx.root orelse return error.NoTree;
    const node = findNodeByUUID(root, uuid) orelse return error.NodeNotFound;
    return node;
}

pub fn mutateById(uuid: []const u8, attribute: []const u8, value: []const u8) void {
    if (Vapor.isWasi) {
        Wasm.mutateDomElementStringWasm(uuid.ptr, uuid.len, attribute.ptr, attribute.len, value.ptr, value.len);
    }
}

pub const MutationType = union(enum) {
    string: []const u8,
    int: i32,
    float: f32,
};

pub fn mutateElementById(uuid: []const u8, attribute: []const u8, value: MutationType) void {
    switch (value) {
        .string => |string| {
            Wasm.mutateDomElementStringWasm(uuid.ptr, uuid.len, attribute.ptr, attribute.len, string.ptr, string.len);
        },
        .int => |int| {
            Wasm.mutateDomElementI32Wasm(uuid.ptr, uuid.len, attribute.ptr, attribute.len, int);
        },
        .float => |float| {
            Wasm.mutateDomElementF32Wasm(uuid.ptr, uuid.len, attribute.ptr, attribute.len, float);
        },
    }
}

pub const Bounds = struct {
    top: f32 = 0,
    left: f32 = 0,
    right: f32 = 0,
    bottom: f32 = 0,
    width: f32 = 0,
    height: f32 = 0,
};

pub const Offsets = struct {
    top: f32 = 0,
    left: f32 = 0,
    right: f32 = 0,
    bottom: f32 = 0,
    width: f32 = 0,
    height: f32 = 0,
};

pub fn getComponentOffsets(uuid: []const u8) ?Offsets {
    const bounds_ptr = if (Vapor.isWasi) blk: {
        break :blk Wasm.getOffsetsWasm(uuid.ptr, uuid.len);
    } else {
        return null;
    };

    return Offsets{
        .top = bounds_ptr[0],
        .left = bounds_ptr[1],
        .right = bounds_ptr[2],
        .bottom = bounds_ptr[3],
        .width = bounds_ptr[4],
        .height = bounds_ptr[5],
    };
}

pub fn getComponentBounds(uuid: []const u8) ?Bounds {
    const bounds_ptr = if (Vapor.isWasi) blk: {
        break :blk Wasm.getBoundingClientRectWasm(uuid.ptr, uuid.len);
    } else {
        return null;
    };

    return Bounds{
        .top = bounds_ptr[0],
        .left = bounds_ptr[1],
        .right = bounds_ptr[2],
        .bottom = bounds_ptr[3],
        .width = bounds_ptr[4],
        .height = bounds_ptr[5],
    };
}

pub fn iterateTreeChildren(tree: *Vapor.CommandsTree) void {
    for (tree.children.items) |child| {
        iterateTreeChildren(child);
    }
}
