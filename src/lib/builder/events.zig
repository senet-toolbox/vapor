const Components = @import("../Components.zig");
const Self = Components.ComponentBuilder;
const std = @import("std");
const types = @import("../types.zig");
const Vapor = @import("../Vapor.zig");
const println = Vapor.println;
const Element = @import("../Element.zig").Element;
const utils = @import("../utils.zig");
const hashKey = utils.hashKey;
const Draggable = @import("../Draggable.zig").Draggable;

pub fn bind(self: *const Self, value: anytype) Self {
    var n = self.*;
    if (self._elem_type != .TextField) {
        Vapor.printlnErr("bindValue only works on TextField", .{});
        return self.*;
    }
    if (@typeInfo(@TypeOf(value)) != .pointer) {
        Vapor.printlnErr("bindValue only works on pointer types", .{});
        return self.*;
    }
    n._value = @ptrCast(@alignCast(value));
    return n;
}

pub fn onFocus(self: *const Self, cb: fn (*Vapor.Event) void) Self {
    var n = self.*;
    var element = self._element orelse {
        Vapor.printlnSrcErr("Element is null must bind() first, before setting onChange", .{}, @src());
        @panic("vapor: Element is null must bind() first, before setting onChange");
    };
    const ui_node = self.getOrCreateNode(&n);
    var onid = hashKey(ui_node.uuid);
    onid +%= hashKey(Vapor.on_change_hash);
    element.on_focus = cb;
    Vapor.events_callbacks.put(onid, cb) catch |err| {
        Vapor.println("Event Callback Error: {any}\n", .{err});
    };
    return n;
}

pub fn onBlur(self: *const Self, cb: fn (*Vapor.Event) void) Self {
    var n = self.*;
    var element = self._element orelse {
        Vapor.printlnSrcErr("Element is null must bind() first, before setting onChange", .{}, @src());
        @panic("vapor: Element is null must bind() first, before setting onChange");
    };
    const ui_node = self.getOrCreateNode(&n);
    var onid = hashKey(ui_node.uuid);
    onid +%= hashKey(Vapor.on_blur_hash);
    element.on_blur = cb;
    Vapor.events_callbacks.put(onid, cb) catch |err| {
        Vapor.println("Event Callback Error: {any}\n", .{err});
    };
    return n;
}

pub fn onChange(self: *const Self, func: anytype, args: anytype) *const Self {
    const ui_node = self._ui_node orelse {
        Vapor.printlnSrcErr("Node is null", .{}, @src());
        @panic("vapor: Node is null");
    };

    Vapor.attachEventCallbackCtx(ui_node, .input, func, args) catch |err| {
        Vapor.println("ONCHANGE: Could not attach event callback {any}\n", .{err});
        @panic("vapor: ONCHANGE: Could not attach event callback");
    };
    return self;
}

pub fn onResize(self: *const Self, callback: anytype, args: anytype) *const Self {
    const resizer = Vapor.Kit.defaultResizeObserver();

    Components.assertTakesResizeEntry(callback);

    const ui_node = self._ui_node orelse {
        Vapor.printlnSrcErr("Node is null", .{}, @src());
        @panic("vapor: Node is null");
    };

    var callback_id: u32 = @truncate(@intFromPtr(&callback));

    callback_id +%= hashKey(ui_node.uuid);
    callback_id +%= hashKey(Components.on_resize); // NOT on_mount_hash — avoids collision

    // Use persist arena — resize callbacks live across many frames
    const erased = Vapor.Kit.ResizeCallback.make(Vapor.arena(.frame), callback, args) catch |err| {
        std.log.err("onResize closure error {any}\n", .{err});
        return self;
    };

    Vapor.resize_callbacks.put(callback_id, erased) catch |err| {
        std.log.err("Could not add resize callback {any}", .{err});
        return self;
    };

    resizer.observeWithCallback(.{ .uuid = ui_node.uuid }, callback_id);

    // Tag the node so the post-mount step knows to register it with the default observer
    ui_node.on_callbacks[4] = callback_id;

    return self;
}

pub fn onMount(self: *const Self, callback: anytype, args: anytype) *const Self {
    if (@typeInfo(@TypeOf(callback)) != .@"fn") {
        @compileError("onMount callback must be a function, got " ++ @typeName(@TypeOf(callback)));
    }

    const ui_node = self._ui_node orelse {
        Vapor.printlnSrcErr("Node is null", .{}, @src());
        @panic("vapor: Node is null");
    };

    var callback_id: u32 = @truncate(@intFromPtr(&callback));
    callback_id +%= hashKey(ui_node.uuid);
    callback_id +%= hashKey(Vapor.on_mount_hash);

    const erased = Vapor.ErasedCallback.make(Vapor.arena(.frame), callback, args) catch |err| {
        Vapor.println("Error could not create closure {any}\n", .{err});
        return self;
    };

    Vapor.erased_hooks_registry.put(callback_id, erased) catch |err| {
        Vapor.printlnErr("Could Not add mount callback {any}", .{err});
        return self;
    };
    ui_node.on_callbacks[0] = callback_id;

    return self;
}

pub fn onUpdate(self: *const Self, callback: anytype, args: anytype) *const Self {
    if (@typeInfo(@TypeOf(callback)) != .@"fn") {
        @compileError("onUpdate callback must be a function, got " ++ @typeName(@TypeOf(callback)));
    }

    const ui_node = self._ui_node orelse {
        Vapor.printlnSrcErr("Node is null", .{}, @src());
        @panic("vapor: Node is null");
    };

    const erased = Vapor.ErasedCallback.make(Vapor.arena(.frame), callback, args) catch |err| {
        Vapor.println("Error could not create closure {any}\n", .{err});
        return self;
    };

    var callback_id: u32 = @truncate(@intFromPtr(&callback));
    callback_id +%= hashKey(ui_node.uuid);
    callback_id +%= hashKey(Vapor.on_update_hash);

    Vapor.erased_hooks_registry.put(callback_id, erased) catch |err| {
        Vapor.printlnErr("Could Not add update callback {any}", .{err});
        return self;
    };
    ui_node.on_callbacks[1] = callback_id;

    return self;
}

pub fn onDestroy(self: *const Self, callback: anytype, args: anytype) *const Self {
    if (@typeInfo(@TypeOf(callback)) != .@"fn") {
        @compileError("onDestroy callback must be a function, got " ++ @typeName(@TypeOf(callback)));
    }

    const ui_node = self._ui_node orelse {
        Vapor.printlnSrcErr("Node is null", .{}, @src());
        @panic("vapor: Node is null");
    };

    const erased = Vapor.ErasedCallback.make(Vapor.arena(.frame), callback, args) catch |err| {
        Vapor.println("Error could not create closure {any}\n", .{err});
        return self;
    };

    var callback_id: u32 = @truncate(@intFromPtr(&callback));

    callback_id +%= hashKey(ui_node.uuid);
    callback_id +%= hashKey(Vapor.on_destroy_hash);

    Vapor.erased_hooks_registry.put(callback_id, erased) catch |err| {
        Vapor.printlnErr("Could Not add update callback {any}", .{err});
        return self;
    };
    ui_node.on_callbacks[2] = callback_id;

    return self;
}

pub fn ifMouseOver(self: *const Self, func: anytype, args: anytype) *const Self {
    const ui_node = self._ui_node orelse {
        Vapor.printlnSrcErr("Node is null", .{}, @src());
        @panic("vapor: Node is null");
    };
    Vapor.attachEventCtxCallback(ui_node, .mouseover, func, args) catch |err| {
        Vapor.println("OnEventCtx: Could not attach event callback {any}\n", .{err});
        @panic("vapor: OnEventCtx: Could not attach event callback");
    };

    Vapor.attachEventCtxCallback(ui_node, .mouseout, func, args) catch |err| {
        Vapor.println("OnEventCtx: Could not attach event callback {any}\n", .{err});
        @panic("vapor: OnEventCtx: Could not attach event callback");
    };

    return self;
}

pub fn onHover(self: *const Self, func: anytype, args: anytype) *const Self {
    const ui_node = self._ui_node orelse {
        Vapor.printlnSrcErr("Node is null", .{}, @src());
        @panic("vapor: Node is null");
    };
    Vapor.attachEventCtxCallback(ui_node, .pointerenter, func, args) catch |err| {
        Vapor.println("OnEventCtx: Could not attach event callback {any}\n", .{err});
        @panic("vapor: OnEventCtx: Could not attach event callback");
    };
    return self;
}

pub fn onLeave(self: *const Self, func: anytype, args: anytype) *const Self {
    const ui_node = self._ui_node orelse {
        Vapor.printlnSrcErr("Node is null", .{}, @src());
        @panic("vapor: Node is null");
    };
    Vapor.attachEventCtxCallback(ui_node, .mouseleave, func, args) catch |err| {
        Vapor.println("ONLEAVE: Could not attach event callback {any}\n", .{err});
        @panic("vapor: ONLEAVE: Could not attach event callback");
    };
    return self;
}

pub fn cycle(self: *const Self, should_cycle: bool) *const Self {
    const ui_node = self._ui_node orelse {
        Vapor.printlnSrcErr("Node is null", .{}, @src());
        @panic("vapor: Node is null");
    };
    ui_node.cycle = should_cycle;
    return self;
}

pub fn onEvent(self: *const Self, event: types.EventType, func: anytype, args: anytype) Self {
    const ui_node = self._ui_node orelse {
        Vapor.printlnSrcErr("Node is null", .{}, @src());
        @panic("vapor: Node is null");
    };
    Vapor.attachEventCtxCallback(ui_node, event, func, args) catch |err| {
        Vapor.println("OnEventCtx: Could not attach event callback {any}\n", .{err});
        @panic("vapor: OnEventCtx: Could not attach event callback");
    };
    return self.*;
}

pub fn onEventCtx(self: *const Self, event: types.EventType, func: anytype, args: anytype) *const Self {
    const ui_node = self._ui_node orelse {
        Vapor.printlnSrcErr("Node is null", .{}, @src());
        @panic("vapor: Node is null");
    };
    Vapor.attachEventCtxCallback(ui_node, event, func, args) catch |err| {
        Vapor.println("OnEventCtx: Could not attach event callback {any}\n", .{err});
        @panic("vapor: OnEventCtx: Could not attach event callback");
    };
    return self;
}

pub fn onMountCtx(self: *const Self, cb: anytype, args: anytype) Self {
    var n = self.*;
    const ui_node = self.getOrCreateNode(&n);
    const Args = @TypeOf(args);
    const Closure = struct {
        arguments: Args,
        run_node: Vapor.Node = .{ .data = .{ .runFn = runFn, .deinitFn = deinitFn } },
        fn runFn(action: *Vapor.Action) void {
            const run_node: *Vapor.Node = @fieldParentPtr("data", action);
            const closure: *@This() = @alignCast(@fieldParentPtr("run_node", run_node));
            @call(.auto, cb, closure.arguments);
        }
        fn deinitFn(node: *Vapor.Node) void {
            const closure: *@This() = @alignCast(@fieldParentPtr("run_node", node));
            Vapor.allocator_global.destroy(closure);
        }
    };
    const closure = Vapor.arena(.frame).create(Closure) catch |err| {
        println("Error could not create closure {any}\n ", .{err});
        @panic("vapor: Error could not create closure");
    };
    closure.* = .{ .arguments = args };
    Vapor.mounted_ctx_funcs.put(hashKey(ui_node.uuid), &closure.run_node) catch |err| {
        println("Hooks Function Registry {any}\n", .{err});
    };
    return n;
}

pub fn onHoverCtx(self: *const Self, cb: anytype, args: anytype) Self {
    var n = self.*;
    const ui_node = self.getOrCreateNode(&n);
    Vapor.attachEventCtxCallback(ui_node, .mouseenter, cb, args) catch |err| {
        Vapor.println("ONHOVERCTX: Could not attach event callback {any}\n", .{err});
        @panic("vapor: ONHOVERCTX: Could not attach event callback");
    };
    return n;
}

pub fn onDragStart(self: *const Self, cb: fn (*Vapor.Event) void) Self {
    var n = self.*;
    const ui_node = self.getOrCreateNode(&n);
    Vapor.attachEventCallback(ui_node, .pointerdown, cb) catch |err| {
        Vapor.println("ONDRAGSTART: Could not attach event callback {any}\n", .{err});
        @panic("vapor: ONDRAGSTART: Could not attach event callback");
    };
    return n;
}

pub fn createDraggable(self: *const Self, draggable_ptr: *Draggable) *const Self {
    var element = draggable_ptr.element;
    var ui_node = self._ui_node orelse {
        Vapor.printlnSrcErr("Node is null must ref() first", .{}, @src());
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
        Vapor.println("ONDRAGSTART: Could not attach event callback {any}\n", .{err});
        @panic("vapor: ONDRAGSTART: Could not attach event callback");
    };

    return self;
}

pub fn ref(self: *const Self, element: *Element) Self {
    var n = self.*;
    const ui_node = self.getOrCreateNode(&n);
    element.element_type = self._elem_type;
    element._node_ptr = ui_node;
    n._element = element;
    // Without the registry entry the element simply is not addressable
    // from JS; the node still renders.
    Vapor.element_registry.put(hashKey(ui_node.uuid), element) catch |err| {
        Vapor.printlnErr("ref: could not register element: {any}", .{err});
    };
    return n;
}
