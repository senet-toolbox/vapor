const TextFieldMod = @import("../TextField.zig");
const Self = TextFieldMod.TextFieldBuilder;
const types = @import("../types.zig");
const Vapor = @import("../Vapor.zig");
const LifeCycle = @import("../Vapor.zig").LifeCycle;
const ElementDecl = types.ElementDeclaration;
const Element = @import("../Element.zig").Element;
const utils = @import("../utils.zig");
const hashKey = utils.hashKey;

pub fn focus(self: *const Self) Self {
    const ui_node = self._ui_node orelse {
        Vapor.printlnSrcErr("Node is null", .{}, @src());
        @panic("vapor: Node is null");
    };

    var uuid: []const u8 = ui_node.uuid;
    if (self._id) |_id| {
        uuid = _id;
    }

    Vapor.onLayout(Vapor.focus, .{uuid});
    return self.*;
}

pub fn onFocus(self: *const Self, cb: fn (*Vapor.Event) void) Self {
    var new_self: Self = self.*;

    const ui_node = self._ui_node orelse blk: {
        const ui_node = LifeCycle.open(ElementDecl{
            .state_type = Self._state_type,
            .elem_type = self._elem_type,
        }) orelse {
            Vapor.printlnSrcErr("Node is null", .{}, @src());
            @panic("vapor: Node is null");
        };
        new_self._ui_node = ui_node;

        break :blk ui_node;
    };

    Vapor.attachEventCallback(ui_node, .focus, cb) catch |err| {
        Vapor.println("ONLEAVE: Could not attach event callback {any}\n", .{err});
        @panic("vapor: ONLEAVE: Could not attach event callback");
    };
    return new_self;
}

pub fn onBlur(self: *const Self, cb: fn (*Vapor.Event) void) Self {
    var new_self: Self = self.*;

    const ui_node = self._ui_node orelse blk: {
        const ui_node = LifeCycle.open(ElementDecl{
            .state_type = Self._state_type,
            .elem_type = self._elem_type,
        }) orelse {
            Vapor.printlnSrcErr("Node is null", .{}, @src());
            @panic("vapor: Node is null");
        };
        new_self._ui_node = ui_node;

        break :blk ui_node;
    };

    Vapor.attachEventCallback(ui_node, .blur, cb) catch |err| {
        Vapor.println("ONLEAVE: Could not attach event callback {any}\n", .{err});
        @panic("vapor: ONLEAVE: Could not attach event callback");
    };

    return new_self;
}

pub fn onScroll(self: *const Self, callback: anytype, args: anytype) Self {
    var new_self = self.*;
    new_self._on_change_cb = Vapor.ErasedEventCallback.make(Vapor.arena(.frame), .scroll, callback, args) catch |err| {
        Vapor.printlnErr("onScroll: could not allocate callback, handler not attached: {any}", .{err});
        return new_self;
    };
    return new_self;
}

pub fn onEvent(self: *const Self, event: types.EventType, func: anytype, args: anytype) *const Self {
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

pub fn onMount(self: *const Self, callback: anytype, args: anytype) *const Self {
    const ui_node = self._ui_node orelse {
        Vapor.printlnSrcErr("Node is null", .{}, @src());
        @panic("vapor: Node is null");
    };

    const erased = Vapor.ErasedCallback.make(Vapor.arena(.frame), callback, args) catch |err| {
        Vapor.println("Error could not create closure {any}\n", .{err});
        return self;
    };

    var mount_node_key = hashKey(ui_node.uuid);
    mount_node_key +%= hashKey(Vapor.on_mount_hash);

    Vapor.erased_hooks_registry.put(mount_node_key, erased) catch |err| {
        Vapor.printlnErr("Could Not add mount callback {any}", .{err});
        return self;
    };
    ui_node.on_callbacks[0] = mount_node_key;

    return self;
}

pub fn onChange(self: *const Self, func: anytype, args: anytype) Self {
    var new_self = self.*;
    new_self._on_change_cb = Vapor.ErasedEventCallback.make(Vapor.arena(.frame), .input, func, args) catch |err| {
        Vapor.printlnErr("onChange: could not allocate callback, handler not attached: {any}", .{err});
        return new_self;
    };
    return new_self;
}

pub fn onKeyDown(self: *const Self, cb: fn (*Vapor.Event) void) Self {
    var new_self: Self = self.*;

    const ui_node = self._ui_node orelse blk: {
        const ui_node = LifeCycle.open(ElementDecl{
            .state_type = Self._state_type,
            .elem_type = self._elem_type,
        }) orelse {
            Vapor.printlnSrcErr("Node is null", .{}, @src());
            @panic("vapor: Node is null");
        };
        new_self._ui_node = ui_node;

        break :blk ui_node;
    };

    // If we have a binded value we instead create a wrapper ctx around the cb passed in
    // this way we can update the binded values from the callback and call the developer's
    // cb with the updated value
    Vapor.attachEventCallback(ui_node, .keydown, cb) catch |err| {
        Vapor.println("ONLEAVE: Could not attach event callback {any}\n", .{err});
        @panic("vapor: ONLEAVE: Could not attach event callback");
    };

    return new_self;
}

pub fn onHover(self: *const Self, cb: fn (*Vapor.Event) void) Self {
    var new_self: Self = self.*;

    const ui_node = self._ui_node orelse blk: {
        const ui_node = LifeCycle.open(ElementDecl{
            .state_type = Self._state_type,
            .elem_type = self._elem_type,
        }) orelse {
            Vapor.printlnSrcErr("Node is null", .{}, @src());
            @panic("vapor: Node is null");
        };
        new_self._ui_node = ui_node;

        break :blk ui_node;
    };

    Vapor.attachEventCallback(ui_node, .pointerenter, cb) catch |err| {
        Vapor.println("ONLEAVE: Could not attach event callback {any}\n", .{err});
        @panic("vapor: ONLEAVE: Could not attach event callback");
    };

    return new_self;
}

pub fn onLeave(self: *const Self, cb: fn (*Vapor.Event) void) Self {
    var new_self: Self = self.*;

    const ui_node = self._ui_node orelse blk: {
        const ui_node = LifeCycle.open(ElementDecl{
            .state_type = Self._state_type,
            .elem_type = self._elem_type,
        }) orelse {
            Vapor.printlnSrcErr("Node is null", .{}, @src());
            @panic("vapor: Node is null");
        };
        new_self._ui_node = ui_node;

        break :blk ui_node;
    };
    Vapor.attachEventCallback(ui_node, .mouseleave, cb) catch |err| {
        Vapor.println("ONLEAVE: Could not attach event callback {any}\n", .{err});
        @panic("vapor: ONLEAVE: Could not attach event callback");
    };

    return new_self;
}

pub fn onHoverCtx(self: *const Self, cb: anytype, args: anytype) Self {
    var new_self: Self = self.*;

    const ui_node = self._ui_node orelse blk: {
        const ui_node = LifeCycle.open(ElementDecl{
            .state_type = Self._state_type,
            .elem_type = self._elem_type,
        }) orelse {
            Vapor.printlnSrcErr("Node is null", .{}, @src());
            @panic("vapor: Node is null");
        };
        new_self._ui_node = ui_node;

        break :blk ui_node;
    };

    Vapor.attachEventCtxCallback(ui_node, .mouseenter, cb, args) catch |err| {
        Vapor.println("ONLEAVE: Could not attach event callback {any}\n", .{err});
        @panic("vapor: ONLEAVE: Could not attach event callback");
    };

    return new_self;
}

pub fn ref(self: *const Self, element: *Element) Self {
    var new_self: Self = self.*;

    const ui_node = self._ui_node orelse blk: {
        const ui_node = LifeCycle.open(ElementDecl{
            .state_type = Self._state_type,
            .elem_type = self._elem_type,
        }) orelse {
            Vapor.printlnSrcErr("Node is null", .{}, @src());
            @panic("vapor: Node is null");
        };
        new_self._ui_node = ui_node;

        break :blk ui_node;
    };

    element.element_type = self._elem_type;
    element._node_ptr = ui_node;
    new_self._element = element;

    const uuid = ui_node.uuid;
    Vapor.element_registry.put(hashKey(uuid), element) catch |err| {
        Vapor.printlnErr("bind: could not register element: {any}", .{err});
    };
    return new_self;
}
