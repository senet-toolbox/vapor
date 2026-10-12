//! ComponentBuilder methods for events and lifecycle: `.onEvent`, `.onHover`,
//! `.onMount`, `.ref`, ... Aliased from components.zig.

const Components = @import("../components.zig");
const Self = Components.ComponentBuilder;
const std = @import("std");
const types = @import("../types.zig");
const Vapor = @import("../vapor.zig");
const println = Vapor.println;
const Element = @import("../element.zig").Element;
const utils = @import("../utils.zig");
const hashKey = utils.hashKey;
const Draggable = @import("../draggable.zig").Draggable;

/// Has no effect on these elements: binding a value is for `TextField` and
/// `TextArea` (see their `.bind`).
pub fn bind(self: *const Self, value: anytype) Self {
    var n = self.*;
    if (self._elem_type != .TextField) {
        Vapor.report.err("bindValue only works on TextField", .{});
        return self.*;
    }
    if (@typeInfo(@TypeOf(value)) != .pointer) {
        Vapor.report.err("bindValue only works on pointer types", .{});
        return self.*;
    }
    n._value = @ptrCast(@alignCast(value));
    return n;
}

/// Calls `cb` with the event when the element gains focus.
pub fn onFocus(self: *const Self, cb: fn (*Vapor.Event) void) Self {
    var n = self.*;
    const ui_node = self.getOrCreateNode(&n);
    Vapor.attachEventCallback(ui_node, .focus, cb) catch |err| {
        Vapor.report.err("onFocus: could not attach the event callback: {any}", .{err});
        @panic("vapor: onFocus: Could not attach event callback");
    };
    return n;
}

/// Calls `cb` with the event when the element loses focus.
pub fn onBlur(self: *const Self, cb: fn (*Vapor.Event) void) Self {
    var n = self.*;
    const ui_node = self.getOrCreateNode(&n);
    Vapor.attachEventCallback(ui_node, .blur, cb) catch |err| {
        Vapor.report.err("onBlur: could not attach the event callback: {any}", .{err});
        @panic("vapor: onBlur: Could not attach event callback");
    };
    return n;
}

/// Calls `func` with `args` and then the event whenever the element's value
/// changes (the DOM `input` event).
pub fn onChange(self: *const Self, func: anytype, args: anytype) *const Self {
    const ui_node = self._ui_node orelse {
        Vapor.report.err("Node is null", .{});
        @panic("vapor: Node is null");
    };

    Vapor.attachEventCtxCallback(ui_node, .input, func, args) catch |err| {
        Vapor.report.err("onChange: could not attach the event callback: {any}", .{err});
        @panic("vapor: ONCHANGE: Could not attach event callback");
    };
    return self;
}

/// Calls `callback` whenever the element resizes (a ResizeObserver). The
/// callback takes `args` and a `Vapor.Kit.ResizeEntry` with the new size.
pub fn onResize(self: *const Self, callback: anytype, args: anytype) *const Self {
    const resizer = Vapor.Kit.defaultResizeObserver();

    Components.assertTakesResizeEntry(callback);

    const ui_node = self._ui_node orelse {
        Vapor.report.err("Node is null", .{});
        @panic("vapor: Node is null");
    };

    var callback_id: u32 = @truncate(@intFromPtr(&callback));

    callback_id +%= hashKey(ui_node.uuid);
    callback_id +%= hashKey(Components.on_resize); // NOT on_mount_hash — avoids collision

    // Use persist arena — resize callbacks live across many frames
    const erased = Vapor.Kit.ResizeCallback.make(Vapor.arena(.frame), callback, args) catch |err| {
        Vapor.report.err("onResize closure error {any}", .{err});
        return self;
    };

    Vapor.resize_callbacks.put(callback_id, erased) catch |err| {
        Vapor.report.err("Could not add resize callback {any}", .{err});
        return self;
    };

    resizer.observeWithCallback(.{ .uuid = ui_node.uuid }, callback_id);

    // Tag the node so the post-mount step knows to register it with the default observer
    ui_node.on_callbacks[4] = callback_id;

    return self;
}

/// Calls `callback` with `args` once the element is on the page.
pub fn onMount(self: *const Self, callback: anytype, args: anytype) *const Self {
    if (@typeInfo(@TypeOf(callback)) != .@"fn") {
        @compileError("onMount callback must be a function, got " ++ @typeName(@TypeOf(callback)));
    }

    const ui_node = self._ui_node orelse {
        Vapor.report.err("Node is null", .{});
        @panic("vapor: Node is null");
    };

    var callback_id: u32 = @truncate(@intFromPtr(&callback));
    callback_id +%= hashKey(ui_node.uuid);
    callback_id +%= hashKey(Vapor.on_mount_hash);

    const erased = Vapor.ErasedCallback.make(Vapor.arena(.frame), callback, args) catch |err| {
        Vapor.report.err("could not create closure: {any}", .{err});
        return self;
    };

    Vapor.erased_hooks_registry.put(callback_id, erased) catch |err| {
        Vapor.report.err("Could Not add mount callback {any}", .{err});
        return self;
    };
    ui_node.on_callbacks[0] = callback_id;

    return self;
}

/// Calls `callback` with `args` when a render changes the element.
pub fn onUpdate(self: *const Self, callback: anytype, args: anytype) *const Self {
    if (@typeInfo(@TypeOf(callback)) != .@"fn") {
        @compileError("onUpdate callback must be a function, got " ++ @typeName(@TypeOf(callback)));
    }

    const ui_node = self._ui_node orelse {
        Vapor.report.err("Node is null", .{});
        @panic("vapor: Node is null");
    };

    const erased = Vapor.ErasedCallback.make(Vapor.arena(.frame), callback, args) catch |err| {
        Vapor.report.err("could not create closure: {any}", .{err});
        return self;
    };

    var callback_id: u32 = @truncate(@intFromPtr(&callback));
    callback_id +%= hashKey(ui_node.uuid);
    callback_id +%= hashKey(Vapor.on_update_hash);

    Vapor.erased_hooks_registry.put(callback_id, erased) catch |err| {
        Vapor.report.err("Could Not add update callback {any}", .{err});
        return self;
    };
    ui_node.on_callbacks[1] = callback_id;

    return self;
}

/// Calls `callback` with `args` when the element is removed from the page.
pub fn onDestroy(self: *const Self, callback: anytype, args: anytype) *const Self {
    if (@typeInfo(@TypeOf(callback)) != .@"fn") {
        @compileError("onDestroy callback must be a function, got " ++ @typeName(@TypeOf(callback)));
    }

    const ui_node = self._ui_node orelse {
        Vapor.report.err("Node is null", .{});
        @panic("vapor: Node is null");
    };

    const erased = Vapor.ErasedCallback.make(Vapor.arena(.frame), callback, args) catch |err| {
        Vapor.report.err("could not create closure: {any}", .{err});
        return self;
    };

    var callback_id: u32 = @truncate(@intFromPtr(&callback));

    callback_id +%= hashKey(ui_node.uuid);
    callback_id +%= hashKey(Vapor.on_destroy_hash);

    Vapor.erased_hooks_registry.put(callback_id, erased) catch |err| {
        Vapor.report.err("Could Not add update callback {any}", .{err});
        return self;
    };
    ui_node.on_callbacks[2] = callback_id;

    return self;
}

/// Calls `func` with `args` and the event when the pointer moves onto the
/// element and again when it leaves (mouseover and mouseout).
pub fn ifMouseOver(self: *const Self, func: anytype, args: anytype) *const Self {
    const ui_node = self._ui_node orelse {
        Vapor.report.err("Node is null", .{});
        @panic("vapor: Node is null");
    };
    Vapor.attachEventCtxCallback(ui_node, .mouseover, func, args) catch |err| {
        Vapor.report.err("ifMouseOver: could not attach the event callback: {any}", .{err});
        @panic("vapor: OnEventCtx: Could not attach event callback");
    };

    Vapor.attachEventCtxCallback(ui_node, .mouseout, func, args) catch |err| {
        Vapor.report.err("ifMouseOver: could not attach the event callback: {any}", .{err});
        @panic("vapor: OnEventCtx: Could not attach event callback");
    };

    return self;
}

/// Calls `func` with `args` and the event when the pointer enters the element.
pub fn onHover(self: *const Self, func: anytype, args: anytype) *const Self {
    const ui_node = self._ui_node orelse {
        Vapor.report.err("Node is null", .{});
        @panic("vapor: Node is null");
    };
    Vapor.attachEventCtxCallback(ui_node, .pointerenter, func, args) catch |err| {
        Vapor.report.err("onHover: could not attach the event callback: {any}", .{err});
        @panic("vapor: OnEventCtx: Could not attach event callback");
    };
    return self;
}

/// Calls `func` with `args` and the event when the pointer leaves the element.
pub fn onLeave(self: *const Self, func: anytype, args: anytype) *const Self {
    const ui_node = self._ui_node orelse {
        Vapor.report.err("Node is null", .{});
        @panic("vapor: Node is null");
    };
    Vapor.attachEventCtxCallback(ui_node, .mouseleave, func, args) catch |err| {
        Vapor.report.err("onLeave: could not attach the event callback: {any}", .{err});
        @panic("vapor: ONLEAVE: Could not attach event callback");
    };
    return self;
}

/// Whether this element's events trigger a rerender (default `true`). Turn it
/// off for handlers that change no state, such as pointer tracking.
pub fn cycle(self: *const Self, should_cycle: bool) *const Self {
    const ui_node = self._ui_node orelse {
        Vapor.report.err("Node is null", .{});
        @panic("vapor: Node is null");
    };
    ui_node.cycle = should_cycle;
    return self;
}

/// Calls `func` with `args` and the event whenever `event` fires on the element:
/// `.onEvent(.keydown, onKey, .{&state})`.
pub fn onEvent(self: *const Self, event: types.EventType, func: anytype, args: anytype) Self {
    const ui_node = self._ui_node orelse {
        Vapor.report.err("Node is null", .{});
        @panic("vapor: Node is null");
    };
    Vapor.attachEventCtxCallback(ui_node, event, func, args) catch |err| {
        Vapor.report.err("onEvent: could not attach the event callback: {any}", .{err});
        @panic("vapor: OnEventCtx: Could not attach event callback");
    };
    return self.*;
}

/// Calls `cb` with `args` and the event when the pointer enters the element
/// (mouseenter).
pub fn onHoverCtx(self: *const Self, cb: anytype, args: anytype) Self {
    var n = self.*;
    const ui_node = self.getOrCreateNode(&n);
    Vapor.attachEventCtxCallback(ui_node, .mouseenter, cb, args) catch |err| {
        Vapor.report.err("onHoverCtx: could not attach the event callback: {any}", .{err});
        @panic("vapor: ONHOVERCTX: Could not attach event callback");
    };
    return n;
}

/// Calls `cb` with the event when a pointer is pressed on the element.
pub fn onDragStart(self: *const Self, cb: fn (*Vapor.Event) void) Self {
    var n = self.*;
    const ui_node = self.getOrCreateNode(&n);
    Vapor.attachEventCallback(ui_node, .pointerdown, cb) catch |err| {
        Vapor.report.err("onDragStart: could not attach the event callback: {any}", .{err});
        @panic("vapor: ONDRAGSTART: Could not attach event callback");
    };
    return n;
}

/// Makes the element draggable with the drag state in `draggable_ptr`.
pub fn createDraggable(self: *const Self, draggable_ptr: *Draggable) *const Self {
    var element = draggable_ptr.element;
    var ui_node = self._ui_node orelse {
        Vapor.report.err("Node is null must ref() first", .{});
        @panic("vapor: Node is null must ref() first");
    };
    ui_node.hooks.created_id = 1;
    element.element_type = self._elem_type;
    element._node_ptr = ui_node;
    draggable_ptr.element = element;
    Vapor.attachEventCtxCallback(
        ui_node,
        .pointerdown,
        Draggable.handlePointerDown,
        .{draggable_ptr},
    ) catch |err| {
        Vapor.report.err("createDraggable: could not attach the event callback: {any}", .{err});
        @panic("vapor: ONDRAGSTART: Could not attach event callback");
    };

    return self;
}

/// Fills `element` with a handle to this element, for reading its size, scroll
/// position or attributes after it is on the page.
pub fn ref(self: *const Self, element: *Element) Self {
    var n = self.*;
    const ui_node = self.getOrCreateNode(&n);
    element.element_type = self._elem_type;
    element._node_ptr = ui_node;
    n._element = element;
    // Without the registry entry the element simply is not addressable
    // from JS; the node still renders.
    Vapor.element_registry.put(hashKey(ui_node.uuid), element) catch |err| {
        Vapor.report.err("ref: could not register element: {any}", .{err});
    };
    return n;
}
