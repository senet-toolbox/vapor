const Vapor = @import("Vapor.zig");
const DynamicObject = @import("Dynamic.zig").DynamicObject;
const Event = @import("Event.zig");
const UIContext = @import("UITree.zig");
const UINode = @import("UITree.zig").UINode;
const Wasm = @import("WASM.zig");
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

pub fn ArgsTuple(comptime Fn: type) type {
    const out = std.meta.ArgsTuple(Fn);
    return if (std.meta.fields(out).len == 0) @TypeOf(.{}) else out;
}

pub const ErasedEventCallback = struct {
    ctx: *anyopaque,
    callFn: *const fn (*anyopaque, *Event) void,
    event_type: Vapor.EventType,
    dynamic_object: ?*DynamicObject = null,

    pub fn call(self: *const ErasedEventCallback, evt: *Event) void {
        self.callFn(self.ctx, evt);
    }

    pub fn make(allocator: std.mem.Allocator, event_type: Vapor.EventType, cb: anytype, args: anytype) !ErasedEventCallback {
        const Args = @TypeOf(args);

        const Closure = struct {
            arguments: Args,

            fn run(ptr: *anyopaque, evt: *Event) void {
                const self: *@This() = @ptrCast(@alignCast(ptr));
                // cb is comptime-captured, append evt to the args
                @call(.auto, cb, self.arguments ++ .{evt});
            }
        };

        const closure = try allocator.create(Closure);
        closure.* = .{ .arguments = args };

        return .{
            .ctx = @ptrCast(closure),
            .callFn = Closure.run,
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
        std.log.err("Event Callback not found {s}\n", .{@tagName(event_type)});
        Vapor.printlnSrcErr("Event Callback not found\n", .{}, @src());
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
                    if (event_type == .rightclick) {
                        std.log.info("rightclick", .{});
                    }
                    Vapor.cycle();
                }
            }
            return;
        }
    }
}

pub fn attachEventCtxCallback(ui_node: *UINode, event_type: Vapor.EventType, cb: anytype, args: anytype) !void {
    if (!Vapor.isWasi) return;

    // Check for duplicates
    if (ui_node.event_handlers) |handlers| {
        for (handlers.handlers.items) |handler| {
            if (handler.event_type == event_type) {
                std.log.err("Event: {any}", .{event_type});
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

    var type_onid = Vapor.hashKey(ui_node.uuid);
    type_onid +%= @intFromEnum(event_type);
    try Vapor.erased_event_registry.put(type_onid, erased);

    const onid = Vapor.hashKey(ui_node.uuid);
    try Vapor.nodes_with_events.put(onid, ui_node);
}

pub fn attachEventCallback(ui_node: *UINode, event_type: Vapor.EventType, cb: fn (event: *Event) void) !void {
    if (!Vapor.isWasi) return;

    // Check for duplicates
    if (ui_node.event_handlers) |handlers| {
        for (handlers.handlers.items) |handler| {
            if (handler.event_type == event_type) {
                return error.EventCtxCallbackError;
            }
        }
    }

    const erased = try ErasedEventCallback.make(Vapor.arena(.frame), event_type, cb, .{});

    // Ensure handlers list exists
    if (ui_node.event_handlers == null) {
        const handlers = try Vapor.arena(.frame).create(EventHandlers);
        handlers.* = .{ .handlers = .{} };
        ui_node.event_handlers = handlers;
    }

    try ui_node.event_handlers.?.handlers.append(Vapor.arena(.frame), erased);

    const onid = Vapor.hashKey(ui_node.uuid);
    try Vapor.nodes_with_events.put(onid, ui_node);
}

pub fn addGlobalListener(event_type: Vapor.EventType, cb: fn (*Event) void) ?u32 {
    if (!Vapor.isWasi) return null;

    const erased = ErasedEventCallback.make(Vapor.arena(.persist), event_type, cb, .{}) catch |err| {
        Vapor.printlnErr("addGlobalListener: could not allocate callback, listener not attached: {any}", .{err});
        return null;
    };

    const id = Vapor.erased_event_registry.count() + 1;
    Vapor.erased_event_registry.put(id, erased) catch |err| {
        Vapor.printlnErr("addGlobalListener: could not register, listener not attached: {any}", .{err});
        return null;
    };

    const event_type_str: []const u8 = std.enums.tagName(types.EventType, event_type) orelse return null;
    if (Vapor.isWasi) {
        Wasm.createEventListenerGlobal(event_type_str.ptr, event_type_str.len, id);
    }
    return @intCast(id);
}

/// USes persist under the hood
pub fn addGlobalListenerCtx(event_type: Vapor.EventType, cb: anytype, args: anytype) ?u32 {
    if (!Vapor.isWasi) return null;

    const erased = ErasedEventCallback.make(Vapor.arena(.persist), event_type, cb, args) catch |err| {
        Vapor.printlnErr("addGlobalListenerCtx: could not allocate callback, listener not attached: {any}", .{err});
        return null;
    };

    const id = Vapor.erased_event_registry.count() + 1;
    Vapor.erased_event_registry.put(id, erased) catch |err| {
        Vapor.printlnErr("addGlobalListenerCtx: could not register, listener not attached: {any}", .{err});
        return null;
    };

    const event_type_str: []const u8 = std.enums.tagName(types.EventType, event_type) orelse return null;
    if (Vapor.isWasi) {
        Wasm.createEventListenerGlobal(event_type_str.ptr, event_type_str.len, id);
    }
    return @intCast(id);
}

pub fn removeGlobalListener(event_type: Vapor.EventType, cb_idx: u32) ?bool {
    const event_type_str = std.enums.tagName(types.EventType, event_type) orelse return null;
    Wasm.removeEventListener(event_type_str.ptr, event_type_str.len, cb_idx);
    return true;
}

pub const ErasedCallback = struct {
    ctx: *anyopaque,
    callFn: *const fn (*anyopaque) void,
    deinitFn: *const fn (*anyopaque) void,

    pub fn call(self: *const ErasedCallback) void {
        self.callFn(self.ctx);
    }

    pub fn deinit(self: *ErasedCallback) void {
        self.deinitFn(self.ctx);
    }

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
    node.prev_style_hash = UIContext.prev_style_hashes.get(node.hash) orelse 0;
    if (old_hash == node.hash) return;
    moveEntry(&Vapor.erased_registry, old_hash, node.hash);
    moveEntry(&Vapor.element_registry, old_hash, node.hash);
}

pub fn moveEntry(map: anytype, from: u32, to: u32) void {
    const kv = map.fetchRemove(from) orelse return;
    map.put(to, kv.value) catch |err| {
        Vapor.printlnErr("assignUserId: could not re-register entry, it is lost: {any}", .{err});
    };
}

// The JS/WASM side calls back with the id:
pub export fn invokeErasedCallback(id: u32) void {
    var erased = Vapor.erased_registry.get(id) orelse {
        std.log.err("Erased Callback not found {d}", .{id});
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
        std.log.err("Hooks Callback not found {d}", .{id});
        return;
    };
    erased.call();
}
