const Vapor = @import("Vapor.zig");
const DynamicObject = @import("Dynamic.zig").DynamicObject;
const Packer = @import("Packer.zig");
const UIContext = @import("UITree.zig");
const UINode = @import("UITree.zig").UINode;
const Wasm = @import("WASM.zig");
const std = @import("std");
const types = @import("types.zig");

pub export fn hasLayoutFunctions() bool {
    const length = Vapor.on_end_ctx_funcs.items.len;
    if (length == 0) return false;
    return true;
}

pub export fn onLayoutCallback() callconv(.c) void {
    const length = Vapor.on_end_ctx_funcs.items.len;
    if (length == 0) return;
    var i: usize = length - 1;
    while (i >= 0) : (i -= 1) {
        const node = Vapor.on_end_ctx_funcs.orderedRemove(i);
        @call(.auto, node.data.runFn, .{&node.data});
        if (i == 0) return;
    }
}

pub export fn getVideo(uinode: *UINode) callconv(.c) ?*const types.Video {
    if (uinode.video) |video| {
        return video;
    }
    return null;
}

pub export fn onPopStateCallback() callconv(.c) void {
    const length = Vapor.pop_state_funcs.items.len;
    if (length == 0) return;
    var i: usize = length - 1;
    while (i >= 0) : (i -= 1) {
        const call = Vapor.pop_state_funcs.items[i];
        @call(.auto, call, .{});
        if (i == 0) return;
    }
}

pub export fn callbackCtx(callback_ptr: u32, object_ptr: ?*DynamicObject) callconv(.c) void {
    const node = Vapor.ctx_callback_registry.get(callback_ptr) orelse {
        std.log.err("Ctx Callback Not found {any}\n", .{callback_ptr});
        return;
    };
    node.data.dynamic_object = object_ptr;
    @call(.auto, node.data.runFn, .{&node.data});
    if (Vapor.mode == .atomic) {
        Vapor.cycle();
    }
}

pub export fn resizeCallback(resize_callback: u32, object_ptr: ?*DynamicObject) callconv(.c) void {
    if (object_ptr == null) {
        std.log.err("Resize Entry is Null", .{});
        return;
    }
    const erased = Vapor.resize_callbacks.get(resize_callback) orelse {
        std.log.err("Resize Ctx Callback Not found {any}\n", .{resize_callback});
        return;
    };

    erased.call(object_ptr.?);
}

// --- Rendering & Tree Management ---
pub export fn renderUI(route: [*:0]u8) callconv(.c) u32 {
    Vapor.renderCycle(route) catch |err| {
        Vapor.printlnSrcErr("Error while rendering", .{}, @src());
        switch (err) {
            error.NoRouteFound => {
                Vapor.printlnSrcErr("No Route found", .{}, @src());
            },
        }
        return 0;
    };
    return 1;
}

pub export fn getRenderTreePtr() callconv(.c) ?*UIContext.CommandsTree {
    const tree_op = Vapor.current_ctx.ui_tree;
    if (tree_op != null) {
        return Vapor.current_ctx.ui_tree.?;
    }
    return null;
}

pub export fn getRenderUINodeRootPtr() callconv(.c) ?*UINode {
    if (Vapor.current_ctx.root == null) return null;
    return Vapor.current_ctx.root.?;
}

pub export fn getUINodeChildrenCount(node_ptr: ?*UINode) callconv(.c) usize {
    const node = node_ptr orelse return 0;
    return node.children_count;
}

pub export fn getUINodeChild(node_ptr: ?*UINode, index: u32) callconv(.c) ?*UINode {
    const node = node_ptr orelse return null;
    return node.childAt(index);
}

// Zig side - export first child and next sibling
pub export fn getUINodeFirstChild(node_ptr: ?*UINode) callconv(.c) ?*UINode {
    const node = node_ptr orelse return null;
    return node.first_child;
}

pub export fn getUINodeNextSibling(node_ptr: ?*UINode) callconv(.c) ?*UINode {
    const node = node_ptr orelse return null;
    return node.next_sibling;
}

pub export fn markCurrentTreeNotDirty() callconv(.c) void {
    if (!Vapor.has_context) return;
    const root = Vapor.current_ctx.root orelse return;
    Vapor.markChildrenNotDirty(root);
}

// --- Layout & Allocation ---
pub export fn allocateUINodeLayoutInfo() callconv(.c) *u8 {
    const ui_info_ptr: *u8 = @ptrCast(&Vapor.ui_node_layout_info);
    return ui_info_ptr;
}

pub export fn allocUint8(length: u32) callconv(.c) [*]const u8 {
    const slice = Vapor.allocator_global.alloc(u8, length) catch
        @panic("failed to allocate memory");
    return slice.ptr;
}

pub export fn allocUint8Frame(length: u32) callconv(.c) [*]const u8 {
    const slice = Vapor.getFrameAllocator().alloc(u8, length) catch
        @panic("failed to allocate memory");
    return slice.ptr;
}

pub export fn allocate(size: usize) callconv(.c) ?[*]f32 {
    const buf = Vapor.allocator_global.alloc(f32, size) catch |err| {
        Vapor.println("{any}\n", .{err});
        return null;
    };
    return buf.ptr;
}

pub export fn allocateU32(size: usize) callconv(.c) ?[*]u32 {
    const buf = Vapor.arena(.persist).alloc(u32, size) catch |err| {
        Vapor.println("{any}\n", .{err});
        return null;
    };
    return buf.ptr;
}

// --- CSS & Commands ---
pub export fn getCSS() callconv(.c) ?[*]const u8 {
    return Vapor.generator.getCSS().ptr;
}

pub export fn getCSSLen() callconv(.c) usize {
    return Vapor.generator.end;
}

pub export fn getRenderCommandPtr(tree: *Vapor.CommandsTree) callconv(.c) [*]u8 {
    if (std.mem.eql(u8, tree.node.id, "global-style")) {
        Vapor.println("getRenderCommandPtr {any}\n", .{tree.node.node_ptr.dirty});
    }
    return @ptrCast(tree.node);
}

pub export fn getTreeNodeChildrenCount(tree: *Vapor.CommandsTree) callconv(.c) usize {
    return tree.children.items.len;
}

pub export fn getTreeNodeChild(tree: *Vapor.CommandsTree, index: usize) callconv(.c) *Vapor.CommandsTree {
    const child = tree.children.items[index];
    return child;
}

// --- Removal Handling ---
pub export fn shouldRerender() callconv(.c) bool {
    return Vapor.global_rerender;
}

pub export fn forceRerender() callconv(.c) void {
    Vapor.global_rerender = true;
}

pub export fn rerenderEverything() callconv(.c) void {
    if (!Vapor.isWasi) return;
    Vapor.browser_width = Wasm.windowWidth();
    Vapor.browser_height = Wasm.windowHeight();
    Vapor.global_rerender = true;
    Vapor.rerender_everything = true;
}

pub export fn hasDirty() callconv(.c) bool {
    return Vapor.has_dirty;
}

pub export fn resetRerender() callconv(.c) void {
    Vapor.global_rerender = false;
    Vapor.rerender_everything = false;
    Vapor.has_dirty = false;
    Vapor.status = .{};
}

pub export fn resetPacker() callconv(.c) void {
    Packer.animations.clearRetainingCapacity();
    Packer.layouts.clearRetainingCapacity();
    Packer.positions.clearRetainingCapacity();
    Packer.margins_paddings.clearRetainingCapacity();
    Packer.visuals.clearRetainingCapacity();
    Packer.interactives.clearRetainingCapacity();
    Packer.transforms.clearRetainingCapacity();
    Packer.responsives.clearRetainingCapacity();
    UIContext.element_style_hash_map.clearRetainingCapacity();
}

pub export fn setRouteRenderTree(ptr: [*:0]u8) callconv(.c) u32 {
    Vapor.renderCycle(ptr) catch |err| {
        Vapor.printlnSrcErr("Error while rendering", .{}, @src());
        switch (err) {
            error.NoRouteFound => {
                Vapor.printlnSrcErr("No Route found", .{}, @src());
            },
        }
        return 0;
    };
    return 1;
}

pub export fn getDirtyValue(node: *UINode) callconv(.c) bool {
    return node.dirty;
}

pub export fn recordState(err_str: [*:0]u8, event_str: ?[*:0]u8) void {
    _ = err_str;
    _ = event_str;
}
