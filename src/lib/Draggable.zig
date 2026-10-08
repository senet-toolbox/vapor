const std = @import("std");
const Vapor = @import("Vapor.zig");

// Draggable behavior that can be attached to any element
pub const Draggable = struct {
    element: *Vapor.Binded = undefined,

    // State
    initial_x: f32 = 0,
    initial_y: f32 = 0,
    current_x: f32 = 0,
    current_y: f32 = 0,
    delta_x: f32 = 0,
    delta_y: f32 = 0,
    movement_x: f32 = 0,
    movement_y: f32 = 0,
    is_dragging: bool = false,
    x: f32 = 0,
    y: f32 = 0,

    // Options
    config: Config = .{},

    // Callbacks
    on_drag_start: ?*const fn (self: *Draggable, evt: *Vapor.Event) void = null,
    on_drag: ?*const fn (self: *Draggable, evt: *Vapor.Event) void = null,
    on_drag_ctx: ?*const fn (self: *Draggable, evt: *Vapor.Event, ctx: ?*anyopaque) void = null,
    on_drag_end: ?*const fn (self: *Draggable, evt: *Vapor.Event) void = null,
    on_drop: ?*const fn (self: *Draggable, evt: *Vapor.Event, target: ?*Vapor.Binded) void = null,

    // Internal listener IDs
    move_listener_id: ?u32 = null,
    up_listener_id: ?u32 = null,
    ctx: ?*anyopaque = null,

    pub const Config = struct {
        // Constraint options
        constrain_to_parent: bool = false,
        constrain_to_viewport: bool = false,
        custom_bounds: ?Bounds = null,

        // Snapping
        snap_to_grid: bool = false,
        grid_size: f32 = 10,
        snap_threshold: f32 = 5,

        // Behavior
        axis: Axis = .both,
        handle: ?*Vapor.Binded = null, // Optional drag handle
        revert_on_invalid_drop: bool = false,
        animate_revert: bool = true,
        cursor: []const u8 = "move",
        disabled: bool = false,

        // Performance
        use_gpu: bool = true, // Use translate3d
        throttle_ms: ?u32 = null, // Throttle drag events
    };

    pub const Axis = enum { x, y, both };

    pub const Bounds = struct {
        min_x: f32 = -std.math.inf(f32),
        max_x: f32 = std.math.inf(f32),
        min_y: f32 = -std.math.inf(f32),
        max_y: f32 = std.math.inf(f32),
    };

    // Initialize a draggable with fluent API
    pub fn init(element: *Vapor.Binded) *Draggable {
        const self = Vapor.arena(.persist).create(Draggable) catch |err| {
            Vapor.printlnErr("Draggable.init: allocation failed: {any}", .{err});
            @panic("vapor: out of memory creating a Draggable");
        };
        self.* = .{ .element = element };

        // Setup listeners on the element or handle
        const target = self.config.handle orelse element;
        target.addInstListener(.pointerdown, handlePointerDown, .{self});

        return self;
    }

    // Initialize a draggable with fluent API
    pub fn addStartListener(self: *Draggable) void {
        // Setup listeners on the element or handle
        const target = self.element;
        target.addInstListener(.pointerdown, handlePointerDown, .{self});
    }

    pub fn deinit(self: *Draggable) void {
        Vapor.arena(.persist).destroy(self);
    }

    // Fluent configuration API
    pub fn constrainToParent(self: *Draggable) *Draggable {
        self.config.constrain_to_parent = true;
        return self;
    }

    pub fn constrainToBounds(self: *Draggable, bounds: Bounds) *Draggable {
        self.config.custom_bounds = bounds;
        return self;
    }

    pub fn snapToGrid(self: *Draggable, size: f32) *Draggable {
        self.config.snap_to_grid = true;
        self.config.grid_size = size;
        return self;
    }

    pub fn axis(self: *Draggable, ax: Axis) *Draggable {
        self.config.axis = ax;
        return self;
    }

    pub fn handle(self: *Draggable, h: *Vapor.Binded) *Draggable {
        self.config.handle = h;
        return self;
    }

    pub fn onStart(self: *Draggable, callback: *const fn (*Draggable, *Vapor.Event) void) *Draggable {
        self.on_drag_start = callback;
        return self;
    }

    pub fn onDrag(self: *Draggable, callback: *const fn (*Draggable, *Vapor.Event) void) *Draggable {
        self.on_drag = callback;
        return self;
    }

    pub fn onEnd(self: *Draggable, callback: *const fn (*Draggable, *Vapor.Event) void) *Draggable {
        self.on_drag_end = callback;
        return self;
    }

    pub fn onDrop(self: *Draggable, callback: *const fn (*Draggable, *Vapor.Event, ?*Vapor.Binded) void) *Draggable {
        self.on_drop = callback;
        return self;
    }

    // Internal handlers
    pub fn handlePointerDown(self: *Draggable, evt: *Vapor.Event) void {
        if (self.config.disabled) return;

        evt.preventDefault();
        self.is_dragging = true;

        // Store initial position
        self.initial_x = evt.clientX();
        self.initial_y = evt.clientY();

        // Add document-level listeners for move and up
        self.move_listener_id = Vapor.addGlobalListenerCtx(.pointermove, handlePointerMove, .{self}) orelse unreachable;
        self.up_listener_id = Vapor.addGlobalListenerCtx(.pointerup, handlePointerUp, .{self}) orelse unreachable;

        // User callback
        if (self.on_drag_start) |callback| {
            callback(self, evt);
        }
    }

    fn handlePointerMove(self: *Draggable, evt: *Vapor.Event) void {
        if (!self.is_dragging) return;

        evt.preventDefault();

        // Calculate delta
        var delta_x = evt.clientX() - self.initial_x;
        var delta_y = evt.clientY() - self.initial_y;
        self.movement_x = evt.movementX();
        self.movement_y = evt.movementY();

        self.delta_x = delta_x;
        self.delta_y = delta_y;

        // Apply axis constraints
        switch (self.config.axis) {
            .x => delta_y = 0,
            .y => delta_x = 0,
            .both => {},
        }

        // Calculate new position
        const new_x = self.current_x + delta_x;
        const new_y = self.current_y + delta_y;

        // Update position
        self.x = new_x;
        self.y = new_y;

        // User callback
        if (self.on_drag) |callback| {
            callback(self, evt);
        } else if (self.on_drag_ctx) |callback| {
            callback(self, evt, self.ctx);
        } else {
            self.updatePosition(new_x, new_y);
        }
    }

    fn handlePointerUp(self: *Draggable, evt: *Vapor.Event) void {
        if (!self.is_dragging) return;

        self.is_dragging = false;

        // Remove document listeners
        if (self.move_listener_id) |id| {
            Vapor.println("handlePointerUp", .{});
            _ = Vapor.removeGlobalListener(.pointermove, id);
            self.move_listener_id = null;
        }
        if (self.up_listener_id) |id| {
            _ = Vapor.removeGlobalListener(.pointerup, id);
            self.up_listener_id = null;
        }

        self.current_x = self.x;
        self.current_y = self.y;

        // User callback
        if (self.on_drag_end) |callback| {
            callback(self, evt);
        }
    }

    pub fn updatePosition(self: *Draggable, x: f32, y: f32) void {
        _ = self.element.translate3d(.{ .x = x, .y = y });
    }

    fn revertPosition(self: *Draggable) void {
        if (self.config.animate_revert) {
            self.element.transition("transform", "0.3s ease");
            defer self.element.transition("transform", "none");
        }
        self.updatePosition(self.current_x, self.current_y);
    }

    fn getDropTarget(self: *Draggable, evt: *Vapor.Event) ?*Vapor.Binded {
        // Get element at pointer position
        // This would use elementFromPoint or similar
        _ = self;
        _ = evt;
        return null; // TODO: Implement drop target detection
    }

    // Public methods
    pub fn setPosition(self: *Draggable, x: f32, y: f32) void {
        self.current_x = x;
        self.current_y = y;
        self.x = x;
        self.y = y;
        self.updatePosition(x, y);
    }

    pub fn getPosition(self: *const Draggable) struct { x: f32, y: f32 } {
        return .{ .x = self.x, .y = self.y };
    }

    pub fn enable(self: *Draggable) void {
        self.config.disabled = false;
    }

    pub fn disable(self: *Draggable) void {
        self.config.disabled = true;
    }

    pub fn destroy(self: *Draggable) void {
        // Clean up listeners
        if (self.move_listener_id) |id| {
            _ = Vapor.removeGlobalListener(.pointermove, id);
        }
        if (self.up_listener_id) |id| {
            _ = Vapor.removeGlobalListener(.pointerup, id);
        }
        // TODO: Remove pointerdown listener from element/handle

        Vapor.arena(.persist).destroy(self);
    }
};

// Extension method for Vapor.Binded
pub fn draggable(element: *Vapor.Binded) *Draggable {
    return Draggable.init(element);
}
