//! ComponentBuilder methods that finish an element: `.children`, `.items`,
//! `.child`, `.end`, `.close`, `.clone`. Aliased from components.zig.

const Components = @import("../components.zig");
const Self = Components.ComponentBuilder;
const Vapor = @import("../vapor.zig");
const UINode = @import("../UITree.zig").UINode;
const LifeCycle = @import("../vapor.zig").LifeCycle;

/// Finishes a child passed to `child`/`items`. Builders come by value or, from
/// `Text` and `Center`, by pointer.
fn endChild(item: anytype) void {
    const T = @TypeOf(item);
    if (T == Self or T == *Self or T == *const Self) item.end();
}

/// Closes a container with exactly one child builder: `Box().child(Text("x"))`.
pub fn child(self: *const Self, item: anytype) void {
    endChild(item);

    var inline_style = self._inlineStyle;
    if (self._element) |el| blk: {
        if (el.attributes) |_| {
            inline_style = el.coalesceAttributesAndInline(inline_style) catch break :blk;
        }
    }

    var mutable_style = Components.mergeStyles(self.getStyleMergeParams(true, false));

    const elem_decl = self.makeElemDecl(null, &mutable_style, inline_style);
    Vapor.LifeCycle.configure(elem_decl);
    return Vapor.LifeCycle.close({});
}

/// Closes a container with the child builders in a tuple:
/// `Row().items(.{ Text("a"), Text("b") })`.
pub fn items(self: *const Self, nodes: anytype) void {
    inline for (nodes) |kid| endChild(kid);

    var inline_style = self._inlineStyle;
    if (self._element) |el| blk: {
        if (el.attributes) |_| {
            inline_style = el.coalesceAttributesAndInline(inline_style) catch break :blk;
        }
    }

    var mutable_style = Components.mergeStyles(self.getStyleMergeParams(true, false));
    const elem_decl = self.makeElemDecl(null, &mutable_style, inline_style);
    Vapor.LifeCycle.configure(elem_decl);
    return Vapor.LifeCycle.close({});
}

/// Closes a container. Write its children as the block argument:
/// `Box().children({ Text("a").end(); })`. The block runs first, so the
/// children are built inside this element.
pub fn children(self: *const Self, _: void) void {
    if (self._used_style) return Vapor.LifeCycle.close({});
    var mutable_style = Components.mergeStyles(self.getStyleMergeParams(true, false));

    var inline_style = self._inlineStyle;
    if (self._element) |el| blk: {
        if (el.attributes) |_| {
            inline_style = el.coalesceAttributesAndInline(inline_style) catch break :blk;
        }
    }

    const elem_decl = self.makeElemDecl(null, &mutable_style, inline_style);
    Vapor.LifeCycle.configure(elem_decl);
    return Vapor.LifeCycle.close({});
}

/// Internal: copies a node's rendered fields for `clone`.
pub fn copyFields(dst: *UINode, node_src: *const UINode) void {
    dst.text = node_src.text;
    dst.href = node_src.href;
    dst.src = node_src.src;
    dst.class = node_src.class;
    dst.packed_field_ptrs = node_src.packed_field_ptrs;
    dst.style_hashes = node_src.style_hashes;
    dst.style_hash = node_src.style_hash;
    dst.hooks = node_src.hooks;
    dst.event_handlers = node_src.event_handlers;
    dst.aria_label = node_src.aria_label;
    dst.alt = node_src.alt;
    dst.direction = node_src.direction;
    dst.finger_print = node_src.finger_print;
    dst.props_hash = node_src.props_hash;
    dst.hooks_hash = node_src.hooks_hash;
    dst.animation_exit = node_src.animation_exit;
    dst.inlineStyle = node_src.inlineStyle;
    dst.video = node_src.video;
    dst.text_field_params = node_src.text_field_params;
    dst.name = node_src.name;
    dst.hover_style_fields = node_src.hover_style_fields;
}

/// Internal: clones a node's subtree for `clone`.
pub fn cloneRecurse(ui_node: *UINode) void {
    var itr = ui_node.children();
    while (itr.next()) |og_child| {
        const cloned_child = Components.createNode(.{
            .state_type = Self._state_type,
            .elem_type = og_child.type,
        });
        copyFields(cloned_child, og_child);
        cloneRecurse(og_child); // open children of og_child as children of cloned_child
        Vapor.LifeCycle.close({}); // close cloned_child — once per open
    }
}

/// Renders a copy of this already-built element and its subtree.
pub fn clone(self: *const Self) void {
    const ui_node = self._ui_node orelse @panic("vapor: builder has no node");
    const cloned_ui_node = Components.createNode(.{
        .state_type = Self._state_type,
        .elem_type = ui_node.type,
    });
    copyFields(cloned_ui_node, ui_node);
    cloneRecurse(ui_node);
    return Vapor.LifeCycle.close({});
}

/// Closes the element without children. Same as `.children({})`.
pub fn close(self: *const Self) void {
    if (self._used_style) return Vapor.LifeCycle.close({});
    var mutable_style = Components.mergeStyles(self.getStyleMergeParams(true, false));

    var inline_style = self._inlineStyle;
    if (self._element) |el| blk: {
        if (el.attributes) |_| {
            inline_style = el.coalesceAttributesAndInline(inline_style) catch break :blk;
        }
    }

    const elem_decl = self.makeElemDecl(null, &mutable_style, inline_style);
    Vapor.LifeCycle.configure(elem_decl);
    return Vapor.LifeCycle.close({});
}

/// Finishes a leaf element (`Text`, `Image`, `Icon`, ...). On a container,
/// closes it with no children.
pub fn end(self: *const Self) void {
    const ui_node = self._ui_node orelse @panic("vapor: builder has no node");
    if (self._used_style) {
        if (ui_node.can_have_children) LifeCycle.close({});
        return;
    }
    var mutable_style = Components.mergeStyles(self.getStyleMergeParams(false, true));
    var text: ?[]const u8 = self._text;
    if (self._elem_type == .Text and self._persisted_text) text = Components.persistText(self._ui_node, self._text);

    var inline_style = self._inlineStyle;
    if (self._element) |el| blk: {
        if (el.attributes) |_| {
            inline_style = el.coalesceAttributesAndInline(inline_style) catch break :blk;
        }
    }

    const elem_decl = self.makeElemDecl(text, &mutable_style, inline_style);
    _ = Vapor.current_ctx.configureByNode(self._ui_node, elem_decl);
    if (ui_node.can_have_children) LifeCycle.close({});
}

/// The element's id: the one set with `.id`, or the generated one.
pub fn getUUID(self: *const Self) []const u8 {
    if (self._ui_node == null) {
        Vapor.printlnSrcErr("getUUID Failed: Node is null", .{}, @src());
        return "";
    }
    return self._ui_node.?.uuid;
}
