const Vapor = @import("Vapor.zig");
const std = @import("std");

pub const HookInst = struct {
    hook_cb: HookInstProto,
};

pub const HookInstProto = *const fn (*HookInst) void;

pub const HookInstNode = struct { data: HookInst };

pub const HookContext = struct {
    from_path: []const u8,
    to_path: []const u8,
    params: std.StringHashMap([]const u8),
    query: std.StringHashMap([]const u8),
};

pub const HookType = enum(u8) {
    before = 0,
    after = 1,
};

pub fn onPopState(callback: *const fn () void) void {
    Vapor.pop_state_funcs.append(callback) catch |err| {
        Vapor.printlnErr("Button Function Registry {any}\n", .{err});
    };
}

pub fn onPushState(callback: *const fn () void) void {
    Vapor.push_state_funcs.append(callback) catch |err| {
        Vapor.printlnErr("Button Function Registry {any}\n", .{err});
    };
}

/// onMount should be called inside the UI
pub fn onMount(callback: anytype, args: anytype) void {
    if (@typeInfo(@TypeOf(callback)) != .@"fn") {
        @compileError("onMount callback must be a function, got " ++ @typeName(@TypeOf(callback)));
    }

    const callback_id: u32 = @intFromPtr(&callback);

    const ui_node = Vapor.current_ctx.currentNode() orelse {
        std.log.err("No current node found", .{});
        return;
    };

    if (ui_node.on_callbacks[0] != 0) {
        std.log.err("onMount callback already exists on Element: {s}\n Using first created callback", .{ui_node.uuid});
        return;
    }

    const erased = Vapor.ErasedCallback.make(Vapor.arena(.frame), callback, args) catch |err| {
        Vapor.println("Error could not create closure {any}\n", .{err});
        return;
    };

    Vapor.erased_hooks_registry.put(callback_id, erased) catch |err| {
        Vapor.printlnErr("Could Not add mount callback {any}", .{err});
        return;
    };
    ui_node.on_callbacks[0] = callback_id;
}

pub fn onLayout(callback: anytype, args: anytype) void {
    const Args = @TypeOf(args);
    const Closure = struct {
        arguments: Args,
        run_node: Vapor.Node = .{ .data = .{ .runFn = runFn, .deinitFn = deinitFn } },
        //
        fn runFn(action: *Vapor.Action) void {
            const run_node: *Vapor.Node = @fieldParentPtr("data", action);
            const closure: *@This() = @alignCast(@fieldParentPtr("run_node", run_node));
            @call(.auto, callback, closure.arguments);
        }
        //
        fn deinitFn(node: *Vapor.Node) void {
            const closure: *@This() = @alignCast(@fieldParentPtr("run_node", node));
            Vapor.allocator_global.destroy(closure);
        }
    };

    const closure = Vapor.allocator_global.create(Closure) catch |err| {
        Vapor.printlnErr("onLayout: could not allocate closure, callback not scheduled: {any}", .{err});
        return;
    };
    closure.* = .{
        .arguments = args,
    };

    Vapor.on_end_ctx_funcs.append(&closure.run_node) catch |err| {
        Vapor.println("Hooks Function Registry {any}\n", .{err});
    };
}

/// This hook takes a function callback and calls it after the virtual dom has been created
/// WARNING: This is a dangerous hook, and can cause infinite loops
pub fn onCommit(callback: *const fn () void) void {
    Vapor.on_commit_funcs.append(callback) catch |err| {
        Vapor.printlnErr("Button Function Registry {any}\n", .{err});
    };
}

pub fn onCommitCtx(callback: anytype, args: anytype) void {
    const Args = @TypeOf(args);
    const Closure = struct {
        arguments: Args,
        run_node: Vapor.Node = .{ .data = .{ .runFn = runFn, .deinitFn = deinitFn } },
        //
        fn runFn(action: *Vapor.Action) void {
            const run_node: *Vapor.Node = @fieldParentPtr("data", action);
            const closure: *@This() = @alignCast(@fieldParentPtr("run_node", run_node));
            @call(.auto, callback, closure.arguments);
        }
        //
        fn deinitFn(node: *Vapor.Node) void {
            const closure: *@This() = @alignCast(@fieldParentPtr("run_node", node));
            Vapor.allocator_global.destroy(closure);
        }
    };

    const closure = Vapor.arena(.frame).create(Closure) catch |err| {
        Vapor.printlnErr("onCommitCtx: could not allocate closure, callback not scheduled: {any}", .{err});
        return;
    };
    closure.* = .{
        .arguments = args,
    };

    Vapor.on_commit_ctx_funcs.append(&closure.run_node) catch |err| {
        Vapor.println("Hooks Function Registry {any}\n", .{err});
    };
}

pub fn onCommitCtxCallback() void {
    const length = Vapor.on_commit_ctx_funcs.items.len;
    if (length == 0) return;
    var i: usize = length - 1;
    while (i >= 0) : (i -= 1) {
        const node = Vapor.on_commit_ctx_funcs.orderedRemove(i);
        @call(.auto, node.data.runFn, .{&node.data});
        if (i == 0) return;
    }
}
