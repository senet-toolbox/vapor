//! Attaching event callbacks to nodes and the document, and dispatching events
//! the runtime reports back to them.

const Vapor = @import("vapor.zig");
const DynamicObject = @import("dynamic.zig").DynamicObject;
const Event = @import("Event.zig");
const UIContext = @import("UITree.zig");
const UINode = @import("UITree.zig").UINode;
const Wasm = @import("wasm.zig");
const std = @import("std");
const types = @import("types.zig");

pub const EventHandler = struct {
    type: Vapor.EventType,
    ctx_aware: bool = false,
    cb_opaque: *const anyopaque,
};

pub const EventHandlers = struct {
    // handlers: std.ArrayListUnmanaged(EventHandler),
    handlers: std.ArrayListUnmanaged(ErasedEventCallback),
};

pub const Action = struct {
    dynamic_object: ?*DynamicObject = null,
    runFn: ActionProto,
    deinitFn: NodeProto,
    argsFn: ?ArgsProto = null,
};

pub const Node = struct { data: Action };

pub const ActionProto = *const fn (*Action) void;

pub const NodeProto = *const fn (*Node) void;

pub const ArgsProto = *const fn (*Action) []const u8;

/// `std.meta.ArgsTuple(Fn)`, or an empty tuple for functions without parameters.
pub fn ArgsTuple(comptime Fn: type) type {
    const out = std.meta.ArgsTuple(Fn);
    return if (std.meta.fields(out).len == 0) @TypeOf(.{}) else out;
}

pub const ErasedEventCallback = struct {
    ctx: *anyopaque,
    callFn: *const fn (*anyopaque, *Event) void,
    destroyFn: *const fn (std.mem.Allocator, *anyopaque) void,
    event_type: Vapor.EventType,
    dynamic_object: ?*DynamicObject = null,

    /// Runs the callback with `evt`.
    pub fn call(self: *const ErasedEventCallback, evt: *Event) void {
        self.callFn(self.ctx, evt);
    }

    /// Frees the closure, which `make` allocated with `allocator`.
    pub fn destroy(self: *const ErasedEventCallback, allocator: std.mem.Allocator) void {
        self.destroyFn(allocator, self.ctx);
    }

    /// Wraps `cb` and `args` as an event callback; the event is passed last.
    pub fn make(allocator: std.mem.Allocator, event_type: Vapor.EventType, cb: anytype, args: anytype) !ErasedEventCallback {
        const Args = @TypeOf(args);

        const Closure = struct {
            arguments: Args,

            fn run(ptr: *anyopaque, evt: *Event) void {
                const self: *@This() = @ptrCast(@alignCast(ptr));
                // cb is comptime-captured, append evt to the args
                @call(.auto, cb, self.arguments ++ .{evt});
            }

            fn destroy(gpa: std.mem.Allocator, ptr: *anyopaque) void {
                gpa.destroy(@as(*@This(), @ptrCast(@alignCast(ptr))));
            }
        };

        const closure = try allocator.create(Closure);
        closure.* = .{ .arguments = args };

        return .{
            .ctx = @ptrCast(closure),
            .callFn = Closure.run,
            .destroyFn = Closure.destroy,
            .event_type = event_type,
        };
    }
};

pub export fn dispatchEvent(event_type_int: u32, callback_id: u32) void {
    const event_type: Vapor.EventType = @enumFromInt(event_type_int);

    var event = Event{
        .id = callback_id,
        .type = event_type,
    };

    const erased = Vapor.erased_event_registry.get(callback_id) orelse {
        Vapor.report.err("dispatchEvent: no document listener {d} for {s}", .{ callback_id, @tagName(event_type) });
        return;
    };

    erased.call(&event);

    if (Vapor.mode == .atomic and event_type != .pointermove) {
        Vapor.cycle();
    }
}

/// We cannot use hash here since has is determeined by the node itself, so if a user create an id, then the hash will be different,
/// the hash is basied on depth ect, while id is user diefined so we must hash the id
pub export fn dispatchNodeEvent(ui_node: *UINode, event_type_int: u32) void {
    const handlers = ui_node.event_handlers orelse return;
    const event_type: Vapor.EventType = @enumFromInt(event_type_int);

    var type_onid = Vapor.hashKey(ui_node.uuid);
    type_onid +%= @intFromEnum(event_type);
    var event = Event{
        .id = type_onid,
        .type = event_type,
    };

    for (handlers.handlers.items) |*handler| {
        if (handler.event_type == event_type) {
            handler.call(&event);

            if (Vapor.mode == .atomic and event_type != .pointermove and event_type != .scroll and ui_node.cycle == true) {
                if (ui_node.type != .Form) {
                    Vapor.cycle();
                }
            }
            return;
        }
    }
}

/// Calls `cb` with `args` and then the event whenever `event_type` fires on the node.
pub fn attachEventCtxCallback(ui_node: *UINode, event_type: Vapor.EventType, cb: anytype, args: anytype) !void {
    if (!Vapor.isWasi) return;

    // Check for duplicates
    if (ui_node.event_handlers) |handlers| {
        for (handlers.handlers.items) |handler| {
            if (handler.event_type == event_type) {
                Vapor.report.err("Event: {any}", .{event_type});
                return error.EventAlreadyAttached;
            }
        }
    }

    const erased = try ErasedEventCallback.make(Vapor.arena(.frame), event_type, cb, args);

    // Ensure handlers list exists
    if (ui_node.event_handlers == null) {
        const handlers = try Vapor.arena(.frame).create(EventHandlers);
        handlers.* = .{ .handlers = .empty };
        ui_node.event_handlers = handlers;
    }

    try ui_node.event_handlers.?.handlers.append(Vapor.arena(.frame), erased);

    const onid = Vapor.hashKey(ui_node.uuid);
    try Vapor.nodes_with_events.put(onid, ui_node);
}

/// Calls `cb` with the event whenever `event_type` fires on the node.
pub fn attachEventCallback(ui_node: *UINode, event_type: Vapor.EventType, cb: fn (event: *Event) void) !void {
    return attachEventCtxCallback(ui_node, event_type, cb, .{});
}

/// Calls `cb` with the event whenever `event_type` fires on the document.
/// Returns an id for `removeGlobalListener`, or `null` outside the browser.
pub fn addGlobalListener(event_type: Vapor.EventType, cb: fn (*Event) void) ?u32 {
    if (!Vapor.isWasi) return null;

    const erased = ErasedEventCallback.make(Vapor.arena(.persist), event_type, cb, .{}) catch |err| {
        Vapor.report.err("addGlobalListener: could not allocate callback, listener not attached: {any}", .{err});
        return null;
    };

    const id = Vapor.next_global_listener_id;
    Vapor.erased_event_registry.put(id, erased) catch |err| {
        Vapor.report.err("addGlobalListener: could not register, listener not attached: {any}", .{err});
        return null;
    };

    Vapor.next_global_listener_id += 1;

    const event_type_str: []const u8 = std.enums.tagName(types.EventType, event_type) orelse return null;
    if (Vapor.isWasi) {
        Wasm.createEventListenerGlobal(event_type_str.ptr, event_type_str.len, id);
    }
    return @intCast(id);
}

/// Like `addGlobalListener`, but calls `cb` with `args` and then the event.
pub fn addGlobalListenerCtx(event_type: Vapor.EventType, cb: anytype, args: anytype) ?u32 {
    if (!Vapor.isWasi) return null;

    const erased = ErasedEventCallback.make(Vapor.arena(.persist), event_type, cb, args) catch |err| {
        Vapor.report.err("addGlobalListenerCtx: could not allocate callback, listener not attached: {any}", .{err});
        return null;
    };

    const id = Vapor.next_global_listener_id;
    Vapor.erased_event_registry.put(id, erased) catch |err| {
        Vapor.report.err("addGlobalListenerCtx: could not register, listener not attached: {any}", .{err});
        return null;
    };

    Vapor.next_global_listener_id += 1;

    const event_type_str: []const u8 = std.enums.tagName(types.EventType, event_type) orelse return null;
    if (Vapor.isWasi) {
        Wasm.createEventListenerGlobal(event_type_str.ptr, event_type_str.len, id);
    }
    return @intCast(id);
}

/// Removes the document listener `cb_idx` that `addGlobalListener` returned.
pub fn removeGlobalListener(event_type: Vapor.EventType, cb_idx: u32) ?bool {
    const event_type_str = std.enums.tagName(types.EventType, event_type) orelse return null;
    // A listener may remove itself while it runs: `dispatchEvent` has
    // already copied the arguments out of the closure by then.
    const kv = Vapor.erased_event_registry.fetchRemove(cb_idx) orelse return false;
    kv.value.destroy(Vapor.arena(.persist));
    if (Vapor.isWasi) {
        Wasm.removeEventListener(event_type_str.ptr, event_type_str.len, cb_idx);
    }
    return true;
}

/// A listener `Element.listen` added.
pub const Listener = struct {
    id: u32,

    /// Detaches the listener and frees its callback. Safe from inside the
    /// listener itself, and after its element left the page.
    pub fn remove(self: Listener) void {
        dropElementListener(self.id);
        if (Vapor.isWasi) Wasm.removeElementListener(self.id);
    }
};

/// Listens for `event_type` on the element whose DOM id is `element_id`,
/// calling `cb` with `args` and then the event. See `Element.listen`.
pub fn addElementListener(element_id: []const u8, event_type: Vapor.EventType, cb: anytype, args: anytype) ?Listener {
    if (!Vapor.isWasi) return null;

    const erased = ErasedEventCallback.make(Vapor.arena(.persist), event_type, cb, args) catch |err| {
        Vapor.report.err("Element.listen: could not allocate the callback: {any}", .{err});
        return null;
    };
    const id = Vapor.next_global_listener_id;
    Vapor.element_listeners.put(id, erased) catch |err| {
        erased.destroy(Vapor.arena(.persist));
        Vapor.report.err("Element.listen: could not register the listener: {any}", .{err});
        return null;
    };
    Vapor.next_global_listener_id += 1;

    const event_type_str = @tagName(event_type);
    if (!Wasm.addElementListener(element_id.ptr, element_id.len, event_type_str.ptr, event_type_str.len, id)) {
        dropElementListener(id);
        Vapor.report.warn("Element.listen: element \"{s}\" is not on the page yet; call listen once it is, e.g. from onMount", .{element_id});
        return null;
    }
    return .{ .id = id };
}

/// Called by the runtime when an `Element.listen` listener's element leaves
/// the page, and by `Listener.remove`: frees the listener's callback.
pub export fn dropElementListener(id: u32) void {
    const kv = Vapor.element_listeners.fetchRemove(id) orelse return;
    kv.value.destroy(Vapor.arena(.persist));
}

/// Called by the runtime when an `Element.listen` listener's event fires.
/// Unlike `.onEvent` handlers, it does not rerender the page.
pub export fn dispatchElementListener(event_type_int: u32, id: u32) void {
    const erased = Vapor.element_listeners.get(id) orelse return;
    var event = Event{ .id = id, .type = @enumFromInt(event_type_int) };
    // The closure may remove the listener while it runs: `call` has copied
    // its arguments out by then.
    erased.call(&event);
}

pub const ErasedCallback = struct {
    ctx: *anyopaque,
    callFn: *const fn (*anyopaque) void,
    deinitFn: *const fn (*anyopaque) void,

    /// Runs the callback.
    pub fn call(self: *const ErasedCallback) void {
        self.callFn(self.ctx);
    }

    /// Releases the callback's closure.
    pub fn deinit(self: *ErasedCallback) void {
        self.deinitFn(self.ctx);
    }

    /// Wraps `cb` and `args` as a callback.
    pub fn make(allocator: std.mem.Allocator, cb: anytype, args: anytype) !ErasedCallback {
        const Args = @TypeOf(args);

        // cb is captured by the comptime closure below — not stored in the struct
        const Closure = struct {
            arguments: Args,

            fn run(ptr: *anyopaque) void {
                const self: *@This() = @ptrCast(@alignCast(ptr));
                @call(.auto, cb, self.arguments);
            }

            fn destroy(_: *anyopaque) void {
                // const self: *@This() = @ptrCast(@alignCast(ptr));
                // allocator.destroy(self);
            }
        };

        const closure = try allocator.create(Closure);
        closure.* = .{
            .arguments = args,
        };

        return .{
            .ctx = @ptrCast(closure),
            .callFn = Closure.run,
            .deinitFn = Closure.destroy,
        };
    }
};

/// Gives `node` a caller-chosen id (`.id()`, `.src()`).
///
/// Everything keyed by the node's hash has to follow the new id. JS reports a
/// button click by `node.hash`, and the generated id the node had is handed
/// back to its parent (`refundUnkeyedSlot`) for the next unkeyed sibling. Left
/// under the old hash, a button's callback was overwritten by that sibling's,
/// so every `.id()`'d button in a row ran the last one's handler.
pub fn assignUserId(node: *UINode, new_id: []const u8) void {
    const old_hash = node.hash;
    node.refundUnkeyedSlot();
    node.uuid = new_id;
    node.hash = Vapor.hashKey(new_id);
    if (old_hash == node.hash) return;
    moveEntry(&Vapor.button_callbacks, old_hash, node.hash);
    moveEntry(&Vapor.element_registry, old_hash, node.hash);
}

/// Moves `map`'s entry from key `from` to key `to`.
pub fn moveEntry(map: anytype, from: u32, to: u32) void {
    const kv = map.fetchRemove(from) orelse return;
    map.put(to, kv.value) catch |err| {
        Vapor.report.err("assignUserId: could not re-register entry, it is lost: {any}", .{err});
    };
}

// The JS/WASM side calls back with the id:
pub export fn invokeErasedCallback(id: u32) void {
    var erased = Vapor.button_callbacks.get(id) orelse Vapor.erased_registry.get(id) orelse {
        Vapor.report.err("Erased Callback not found {d}", .{id});
        return;
    };
    erased.call();
    if (Vapor.mode == .atomic) {
        Vapor.cycle();
    }
}

// The JS/WASM side calls back with the id:
pub export fn invokeHooksErasedCallback(id: u32) void {
    var erased = Vapor.erased_hooks_registry.get(id) orelse {
        Vapor.report.err("Hooks Callback not found {d}", .{id});
        return;
    };
    erased.call();
}
