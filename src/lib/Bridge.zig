const std = @import("std");
const Vapor = @import("Vapor.zig");
const isWasi = Vapor.isWasi;
const UIContext = @import("UITree.zig");
const CommandsTree = UIContext.CommandsTree;
const Types = @import("types.zig");
const EventType = Types.EventType;
const RenderCommand = Types.RenderCommand;
const UINode = UIContext.UINode;
const Event = @import("Event.zig");
const StyleCompiler = @import("convertStyleCustomWriter.zig");
const Wasm = Vapor.Wasm;
const Writer = @import("Writer.zig");
const utils = @import("utils.zig");
const hashKey = utils.hashKey;
const Kit = @import("kit/Kit.zig");
const Packer = @import("Packer.zig");

const API = struct {
    pub fn getCtxNodeChild(tree: *CommandsTree, index: usize) callconv(.c) ?*CommandsTree {
        const ui_node = tree.node.node_ptr.childAt(index) orelse return null;
        for (tree.children.items) |item| {
            if (std.mem.eql(u8, ui_node.uuid, item.node.id)) {
                return item;
            }
        }
        return null;
    }

    pub fn getTreeNodeChildCommand(tree: *CommandsTree) callconv(.c) *RenderCommand {
        return tree.node;
    }

    pub fn setDirtyToFalse(node: *UINode) callconv(.c) void {
        node.dirty = false;
    }

    // dirty_nodes/added_nodes hold *UINode since the tree stopped being a flat
    // RenderCommand list.
    pub fn getDirtyNode() callconv(.c) [*]const *UINode {
        const node = Vapor.dirty_nodes.items.ptr;
        return node;
    }

    pub fn getAddedNodeCount() callconv(.c) usize {
        return Vapor.added_nodes.items.len;
    }

    pub fn getAddedNode() callconv(.c) [*]const *UINode {
        const node = Vapor.added_nodes.items.ptr;
        return node;
    }

    // Children are an intrusive linked list, so the next sibling is direct.
    pub fn getNextSiblingPtr(ui_node: *UINode) callconv(.c) ?[*]const u8 {
        const sibling = ui_node.next_sibling orelse return null;
        return sibling.uuid.ptr;
    }

    pub fn getNextSiblingLen(ui_node: *UINode) callconv(.c) usize {
        const sibling = ui_node.next_sibling orelse return 0;
        return sibling.uuid.len;
    }

    pub fn checkPotentialNode(_: *UINode) callconv(.c) bool {
        // Vapor.potential_nodes.get(node.uuid) orelse return false;
        return false;
    }

    pub fn getNodeParentId(node: *UINode) callconv(.c) ?[*]const u8 {
        const parent = node.parent orelse return null;
        return parent.uuid.ptr;
    }

    pub fn getNodeParentIdLen(node: *UINode) callconv(.c) usize {
        const parent = node.parent orelse return 0;
        return parent.uuid.len;
    }
    // The first node needs to be marked as false always
    pub fn markCurrentTreeDirty() callconv(.c) void {
        if (!Vapor.has_context) return;
        const root = Vapor.current_ctx.root orelse return;
        Vapor.markChildrenDirty(root);
    }

    pub fn markUINodeTreeDirty(node: *UINode) callconv(.c) void {
        Vapor.markChildrenDirty(node);
    }
    pub fn inputCallback(id_ptr: [*:0]u8) callconv(.c) void {
        const id = std.mem.span(id_ptr);
        defer Vapor.allocator_global.free(id);
        const element = Vapor.element_registry.get(hashKey(id)) orelse return;
        const text = element.getInputValue() orelse return;
        element.text = text;
    }

    pub fn getElementPtr(id_ptr: [*:0]u8) callconv(.c) ?*Vapor.Element {
        const id = std.mem.span(id_ptr);
        defer Vapor.allocator_global.free(id);
        const element = Vapor.element_registry.get(hashKey(id)) orelse return null;
        return element;
    }

    pub fn callback(callbackId: u32) callconv(.c) void {
        const cb = Vapor.callback_registry.get(callbackId) orelse return;
        @call(.auto, cb, .{});
    }

    pub fn cleanUp() callconv(.c) void {
        Vapor.clean_up_ctx = undefined;
    }

    pub fn timeOutCtxCallback(id_ptr: [*:0]u8) callconv(.c) void {
        const id = std.mem.span(id_ptr);
        defer Vapor.allocator_global.free(id);
        const node = Vapor.ctx_callback_registry.get(hashKey(id)) orelse return;
        @call(.auto, node.data.runFn, .{&node.data});
    }

    pub fn timeoutCtxCallBackId(id: usize) callconv(.c) void {
        const key: u32 = @intCast(id);
        const node = Vapor.ctx_callback_registry.get(key) orelse return;
        defer _ = Vapor.ctx_callback_registry.remove(key);
        @call(.auto, node.data.runFn, .{&node.data});
        if (Vapor.mode == .atomic) {
            Vapor.cycle();
        }
    }

    pub fn timeoutCallBackId(id: usize) callconv(.c) void {
        const key: u32 = @intCast(id);
        const func = Vapor.callback_registry.get(key) orelse return;
        defer _ = Vapor.callback_registry.remove(key);
        @call(.auto, func, .{});
        if (Vapor.mode == .atomic) {
            Vapor.cycle();
        }
    }
};

// --- Auto-Export Magic ---
// This runs automatically when this file is imported
comptime {
    const decls = std.meta.declarations(API);

    for (decls) |decl| {
        const val = @field(API, decl.name);
        const Type = @TypeOf(val);
        if (@typeInfo(Type) == .@"fn") {
            // Export it with its own name
            @export(&val, .{ .name = decl.name });
        }
    }
}
