const Vapor = @import("Vapor.zig");
const Wasm = @import("WASM.zig");
const std = @import("std");

pub var animation_frame_callback: ?*Vapor.Node = null;

pub fn runOnAnimationFrame(callback: anytype, args: anytype) u32 {
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
        Vapor.printlnErr("runOnAnimationFrame: could not allocate closure, frame not scheduled: {any}", .{err});
        return 0;
    };
    closure.* = .{
        .arguments = args,
    };

    animation_frame_callback = &closure.run_node;
    Vapor.ctx_callback_registry.put(@intFromPtr(animation_frame_callback), &closure.run_node) catch |err| {
        Vapor.printlnErr("runOnAnimationFrame: could not register callback, frame not scheduled: {any}", .{err});
        return 0;
    };

    if (Vapor.isWasi) {
        return Wasm.requestAnimationFrameWasm(@intFromPtr(animation_frame_callback));
    }
    return 0;
}

pub export fn callAnimationFrameCallback(callback_ptr: u32) void {
    const node = Vapor.ctx_callback_registry.get(callback_ptr) orelse {
        std.log.err("Ctx Callback Not found {any}\n", .{callback_ptr});
        return;
    };
    @call(.auto, node.data.runFn, .{&node.data});
    if (Vapor.mode == .atomic) {
        Vapor.cycle();
    }
}

pub fn nowMs() f64 {
    if (Vapor.isWasi) {
        return Vapor.performance_now();
    } else {
        return 0;
    }
}

/// name: name of the interval
/// cb: callback function
/// args: arguments to pass to the callback function
/// delay: delay in ms
pub fn loopInterval(name: []const u8, delay_ms: u32, callback: anytype, args: anytype) void {
    const erased = Vapor.ErasedCallback.make(Vapor.arena(.frame), callback, args) catch |err| {
        Vapor.printlnErr("loopInterval '{s}': could not allocate closure, interval not started: {any}", .{ name, err });
        return;
    };

    const callback_id: u32 = Vapor.hashKey(name);
    // Store just the ErasedCallback instead of *Node
    Vapor.erased_registry.put(callback_id, erased) catch |err| {
        Vapor.printlnErr("loopInterval '{s}': could not register, interval not started: {any}", .{ name, err });
        return;
    };

    if (Vapor.isWasi) {
        Wasm.createInterval(callback_id, delay_ms);
    }
}

pub fn timeout(callback_name: []const u8, ms: u32, cb: anytype, args: anytype) void {
    const Args = @TypeOf(args);
    const Closure = struct {
        arguments: Args,
        run_node: Vapor.Node = .{ .data = .{ .runFn = runFn, .deinitFn = deinitFn } },
        //
        fn runFn(action: *Vapor.Action) void {
            const run_node: *Vapor.Node = @fieldParentPtr("data", action);
            const closure: *@This() = @alignCast(@fieldParentPtr("run_node", run_node));
            @call(.auto, cb, closure.arguments);
        }
        //
        fn deinitFn(node: *Vapor.Node) void {
            const closure: *@This() = @alignCast(@fieldParentPtr("run_node", node));
            Vapor.allocator_global.destroy(closure);
        }
    };

    const closure = Vapor.allocator_global.create(Closure) catch |err| {
        Vapor.printlnErr("timeout: could not allocate closure, callback not scheduled: {any}", .{err});
        return;
    };
    closure.* = .{
        .arguments = args,
    };

    const callback_id = Vapor.hashKey(callback_name);
    Vapor.ctx_callback_registry.put(callback_id, &closure.run_node) catch |err| {
        Vapor.println("Button Function Registry {any}\n", .{err});
    };

    if (Vapor.isWasi) {
        Wasm.timeoutCtx(ms, callback_id);
    } else {
        return;
    }
}

pub fn cancelTimeout(callback_name: []const u8) void {
    const callback_id = Vapor.hashKey(callback_name);
    if (Vapor.isWasi) {
        Wasm.cancelTimeoutWasm(callback_id);
    }
}

pub fn registerTimeout(ms: u32, cb: *const fn () void) void {
    const id = Vapor.callback_registry.count() + 1;
    Vapor.callback_registry.put(id, cb) catch |err| {
        Vapor.println("Button Function Registry {any}\n", .{err});
    };
    if (Vapor.isWasi) {
        Wasm.timeout(ms, id);
    } else {
        return;
    }
}

pub fn startViewTransition(callback: anytype, args: anytype) void {
    const erased = Vapor.ErasedCallback.make(Vapor.arena(.frame), callback, args) catch |err| {
        Vapor.printlnErr("view transition: could not allocate closure, transition skipped: {any}", .{err});
        return;
    };

    const callback_id: u32 = Vapor.hashKey("view-transition");
    // Store just the ErasedCallback instead of *Node
    Vapor.erased_registry.put(callback_id, erased) catch |err| {
        Vapor.printlnErr("view transition: could not register callback, transition skipped: {any}", .{err});
        return;
    };

    if (Vapor.isWasi) {
        Wasm.startViewTransitionWasm(callback_id);
    }
}
