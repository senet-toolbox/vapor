//! Timeouts, intervals, animation frames and view transitions.

const Vapor = @import("vapor.zig");
const Wasm = @import("wasm.zig");
const std = @import("std");

pub var animation_frame_callback: ?*Vapor.Node = null;

/// Calls `callback` with `args` before the browser's next repaint
/// (requestAnimationFrame). Returns the frame request id.
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
        Vapor.report.err("runOnAnimationFrame: could not allocate closure, frame not scheduled: {any}", .{err});
        return 0;
    };
    closure.* = .{
        .arguments = args,
    };

    animation_frame_callback = &closure.run_node;
    Vapor.ctx_callback_registry.put(@intFromPtr(animation_frame_callback), &closure.run_node) catch |err| {
        Vapor.report.err("runOnAnimationFrame: could not register callback, frame not scheduled: {any}", .{err});
        return 0;
    };

    if (Vapor.isWasi) {
        return Wasm.requestAnimationFrameWasm(@intFromPtr(animation_frame_callback));
    }
    return 0;
}

pub export fn callAnimationFrameCallback(callback_ptr: u32) void {
    const node = Vapor.ctx_callback_registry.get(callback_ptr) orelse {
        Vapor.report.err("Ctx Callback Not found {any}", .{callback_ptr});
        return;
    };
    @call(.auto, node.data.runFn, .{&node.data});
    if (Vapor.mode == .atomic) {
        Vapor.cycle();
    }
}

/// Milliseconds since the page loaded (`performance.now()`); 0 outside the
/// browser.
pub fn nowMs() f64 {
    if (Vapor.isWasi) {
        return Vapor.performance_now();
    } else {
        return 0;
    }
}

/// Calls `callback` with `args` every `delay_ms` milliseconds. `name`
/// identifies the interval.
pub fn loopInterval(name: []const u8, delay_ms: u32, callback: anytype, args: anytype) void {
    // The interval outlives the render that starts it, so the closure cannot
    // live in the frame arena, which is recycled two renders later.
    const erased = Vapor.ErasedCallback.make(Vapor.arena(.persist), callback, args) catch |err| {
        Vapor.report.err("loopInterval '{s}': could not allocate closure, interval not started: {any}", .{ name, err });
        return;
    };

    const callback_id: u32 = Vapor.hashKey(name);
    // Store just the ErasedCallback instead of *Node
    Vapor.erased_registry.put(callback_id, erased) catch |err| {
        Vapor.report.err("loopInterval '{s}': could not register, interval not started: {any}", .{ name, err });
        return;
    };

    if (Vapor.isWasi) {
        Wasm.createInterval(callback_id, delay_ms);
    }
}

/// Calls `cb` with `args` once, after `ms` milliseconds. `callback_name`
/// identifies it, so `cancelTimeout` can stop it.
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
        Vapor.report.err("timeout: could not allocate closure, callback not scheduled: {any}", .{err});
        return;
    };
    closure.* = .{
        .arguments = args,
    };

    const callback_id = Vapor.hashKey(callback_name);
    Vapor.ctx_callback_registry.put(callback_id, &closure.run_node) catch |err| {
        Vapor.report.err("Button Function Registry {any}", .{err});
    };

    if (Vapor.isWasi) {
        Wasm.timeoutCtx(ms, callback_id);
    } else {
        return;
    }
}

/// Stops the timeout started under `callback_name`, if it has not fired.
pub fn cancelTimeout(callback_name: []const u8) void {
    const callback_id = Vapor.hashKey(callback_name);
    if (Vapor.isWasi) {
        Wasm.cancelTimeoutWasm(callback_id);
    }
}

/// Calls `cb` once, after `ms` milliseconds.
pub fn registerTimeout(ms: u32, cb: *const fn () void) void {
    const id = Vapor.callback_registry.count() + 1;
    Vapor.callback_registry.put(id, cb) catch |err| {
        Vapor.report.err("Button Function Registry {any}", .{err});
    };
    if (Vapor.isWasi) {
        Wasm.timeout(ms, id);
    } else {
        return;
    }
}

/// Runs `callback` with `args` inside a view transition
/// (`document.startViewTransition`), so the browser animates the change.
pub fn startViewTransition(callback: anytype, args: anytype) void {
    const erased = Vapor.ErasedCallback.make(Vapor.arena(.frame), callback, args) catch |err| {
        Vapor.report.err("view transition: could not allocate closure, transition skipped: {any}", .{err});
        return;
    };

    const callback_id: u32 = Vapor.hashKey("view-transition");
    // Store just the ErasedCallback instead of *Node
    Vapor.erased_registry.put(callback_id, erased) catch |err| {
        Vapor.report.err("view transition: could not register callback, transition skipped: {any}", .{err});
        return;
    };

    if (Vapor.isWasi) {
        Wasm.startViewTransitionWasm(callback_id);
    }
}
