//! Decorative edge lines drawn on an element's sides with ::before/::after,
//! configured with a builder and attached with `.edges(name)`.

const std = @import("std");
const Vapor = @import("vapor.zig");
const Color = Vapor.Types.Color;
const Writer = @import("Writer.zig");

pub const Edges = @This();

/// Creates the edges registry. Call it once in `init`, before any `.build()`.
pub fn new() void {
    Vapor.edges_table = std.StringHashMap(Edges).init(Vapor.arena(.persist));
}

// ============================================
// TYPES
// ============================================

pub const Edge = enum(u8) {
    top,
    bottom,
    left,
    right,
};

pub const Mode = enum(u8) {
    single, // One element, 2 edges max (uses ::before/::after)
    wrapped, // Two elements, 4 edges (wrapper + inner)
};

pub const EdgeConfig = struct {
    enabled: bool = true,
    thickness: f32 = 1,
    color: ?Color = null,
    offset: f32 = 0,
    inset: f32 = 0,
};

pub const EdgeState = struct {
    top: ?EdgeConfig = null,
    bottom: ?EdgeConfig = null,
    left: ?EdgeConfig = null,
    right: ?EdgeConfig = null,

    fn getPtr(self: *EdgeState, e: Edge) *?EdgeConfig {
        return switch (e) {
            .top => &self.top,
            .bottom => &self.bottom,
            .left => &self.left,
            .right => &self.right,
        };
    }

    fn get(self: EdgeState, e: Edge) ?EdgeConfig {
        return switch (e) {
            .top => self.top,
            .bottom => self.bottom,
            .left => self.left,
            .right => self.right,
        };
    }

    fn count(self: EdgeState) u8 {
        var c: u8 = 0;
        if (self.top != null) c += 1;
        if (self.bottom != null) c += 1;
        if (self.left != null) c += 1;
        if (self.right != null) c += 1;
        return c;
    }
};

// ============================================
// MAIN STRUCT
// ============================================

class: []const u8,
inner_class: ?[]const u8 = null, // Only used in wrapped mode
mode: Mode = .single,
normal: EdgeState = .{},
hover: EdgeState = .{},
transition_ms: u32 = 300,
easing: []const u8 = "ease",

// Builder state
current_edges: [4]bool = .{ false, false, false, false },
editing_hover: bool = false,

// ============================================
// CONSTRUCTORS
// ============================================

/// Single element with up to 2 edges (top/bottom OR left/right)
/// Usage: Edges.box("my-box").vertical().thickness(2)...
pub fn box(class_name: []const u8) Edges {
    return Edges{
        .class = class_name,
        .mode = .single,
    };
}

/// Two elements for all 4 edges
/// Usage: Edges.wrapped("wrapper", "inner").all()...
pub fn wrapped(wrapper: []const u8, inner: []const u8) Edges {
    return Edges{
        .class = wrapper,
        .inner_class = inner,
        .mode = .wrapped,
    };
}

/// Alias for wrapped (backwards compatible)
pub fn init(wrapper: []const u8, inner: []const u8) Edges {
    return wrapped(wrapper, inner);
}

// ============================================
// EDGE SELECTION
// ============================================

fn selectEdges(self: Edges, val_top: bool, val_bottom: bool, val_left: bool, val_right: bool) Edges {
    var e = self;
    e.current_edges = .{ val_top, val_bottom, val_left, val_right };
    return e;
}

/// Selects the top edge; the next settings apply to it.
pub fn top(self: Edges) Edges {
    return self.selectEdges(true, false, false, false);
}

/// Selects the bottom edge; the next settings apply to it.
pub fn bottom(self: Edges) Edges {
    return self.selectEdges(false, true, false, false);
}

/// Selects the left edge; the next settings apply to it.
pub fn left(self: Edges) Edges {
    return self.selectEdges(false, false, true, false);
}

/// Selects the right edge; the next settings apply to it.
pub fn right(self: Edges) Edges {
    return self.selectEdges(false, false, false, true);
}

/// Top + Bottom (for single mode, uses ::before and ::after)
pub fn horizontal(self: Edges) Edges {
    return self.selectEdges(true, true, false, false);
}

/// Left + Right (for single mode, uses ::before and ::after)
pub fn vertical(self: Edges) Edges {
    return self.selectEdges(false, false, true, true);
}

/// All 4 edges (requires wrapped mode)
pub fn all(self: Edges) Edges {
    return self.selectEdges(true, true, true, true);
}

// ============================================
// STATE SELECTION
// ============================================

/// The next settings apply while the element is hovered.
pub fn onHover(self: Edges) Edges {
    var e = self;
    e.editing_hover = true;
    return e;
}

/// The next settings apply when not hovered (the default).
pub fn onNormal(self: Edges) Edges {
    var e = self;
    e.editing_hover = false;
    return e;
}

// ============================================
// PROPERTY SETTERS
// ============================================

fn applyToSelected(self: Edges, comptime field: []const u8, value: anytype) Edges {
    var e = self;
    const state = if (e.editing_hover) &e.hover else &e.normal;
    const edges = [_]Edge{ .top, .bottom, .left, .right };

    for (edges, 0..) |edge_type, i| {
        if (e.current_edges[i]) {
            const ptr = state.getPtr(edge_type);
            if (ptr.* == null) {
                ptr.* = EdgeConfig{};
            }
            @field(ptr.*.?, field) = value;
        }
    }
    return e;
}

/// Line thickness in pixels, for the selected edges.
pub fn thickness(self: Edges, px: f32) Edges {
    return self.applyToSelected("thickness", px);
}

/// Line colour, for the selected edges.
pub fn color(self: Edges, c: Color) Edges {
    return self.applyToSelected("color", c);
}

/// Distance from the element in pixels, for the selected edges.
pub fn offset(self: Edges, px: f32) Edges {
    return self.applyToSelected("offset", px);
}

/// How far the line stops short of the corners, in percent, for the selected
/// edges.
pub fn inset(self: Edges, percent: f32) Edges {
    return self.applyToSelected("inset", percent);
}

/// Animates hover changes over `ms` milliseconds.
pub fn transition(self: Edges, ms: u32) Edges {
    var e = self;
    e.transition_ms = ms;
    return e;
}

/// CSS timing function for the transition.
pub fn ease(self: Edges, easing_fn: []const u8) Edges {
    var e = self;
    e.easing = easing_fn;
    return e;
}

// ============================================
// CSS GENERATION
// ============================================

/// Writes the edges' CSS rules to `writer`.
pub fn writeCss(self: Edges, writer: *Writer) void {
    switch (self.mode) {
        .single => self.writeSingleModeCss(writer),
        .wrapped => self.writeWrappedModeCss(writer),
    }
}

fn writeSingleModeCss(self: Edges, writer: *Writer) void {
    // Base element styles
    writer.write(".") catch {};
    writer.write(self.class) catch {};
    writer.write(" {\n  position: relative;\n}\n\n") catch {};

    // Determine which pair we're using
    const use_horizontal = self.normal.top != null or self.normal.bottom != null;
    const use_vertical = self.normal.left != null or self.normal.right != null;

    if (use_horizontal and use_vertical) {
        // Error: single mode can't do both pairs
        writer.write("/* ERROR: Single mode only supports 2 edges (horizontal OR vertical) */\n") catch {};
        return;
    }

    if (use_horizontal) {
        self.writeSingleHorizontalEdges(writer);
    } else if (use_vertical) {
        self.writeSingleVerticalEdges(writer);
    }
}

fn writeSingleHorizontalEdges(self: Edges, writer: *Writer) void {
    // Shared pseudo-element base
    writer.write(".") catch {};
    writer.write(self.class) catch {};
    writer.write("::before,\n.") catch {};
    writer.write(self.class) catch {};
    writer.write("::after {\n") catch {};
    writer.write("  content: '';\n  position: absolute;\n  left: 0;\n  right: 0;\n") catch {};

    const config = self.normal.top orelse self.normal.bottom.?;
    writer.write("  height: ") catch {};
    self.writeFloat(writer, config.thickness);
    writer.write("px;\n  background: ") catch {};
    if (config.color) |c| {
        c.toCss(writer) catch {};
    } else {
        writer.write("currentColor") catch {};
    }
    writer.write(";\n  transition: ") catch {};
    self.writeFloat(writer, @floatFromInt(self.transition_ms));
    writer.write("ms ") catch {};
    writer.write(self.easing) catch {};
    writer.write(";\n}\n\n") catch {};

    // Individual positions
    self.writeSingleEdgePosition(writer, .top, "::before", "top", false);
    self.writeSingleEdgePosition(writer, .bottom, "::after", "bottom", false);

    // Hover states
    if (self.hover.top != null) {
        self.writeSingleEdgePosition(writer, .top, "::before", "top", true);
    }
    if (self.hover.bottom != null) {
        self.writeSingleEdgePosition(writer, .bottom, "::after", "bottom", true);
    }
}

fn writeSingleVerticalEdges(self: Edges, writer: *Writer) void {
    // Shared pseudo-element base
    writer.write(".") catch {};
    writer.write(self.class) catch {};
    writer.write("::before,\n.") catch {};
    writer.write(self.class) catch {};
    writer.write("::after {\n") catch {};
    writer.write("  content: '';\n  position: absolute;\n  top: 0;\n  bottom: 0;\n") catch {};

    const config = self.normal.left orelse self.normal.right.?;
    writer.write("  width: ") catch {};
    self.writeFloat(writer, config.thickness);
    writer.write("px;\n  background: ") catch {};
    if (config.color) |c| {
        c.toCss(writer) catch {};
    } else {
        writer.write("currentColor") catch {};
    }
    writer.write(";\n  transition: ") catch {};
    self.writeFloat(writer, @floatFromInt(self.transition_ms));
    writer.write("ms ") catch {};
    writer.write(self.easing) catch {};
    writer.write(";\n}\n\n") catch {};

    // Individual positions
    self.writeSingleEdgePosition(writer, .left, "::before", "left", false);
    self.writeSingleEdgePosition(writer, .right, "::after", "right", false);

    // Hover states
    if (self.hover.left != null) {
        self.writeSingleEdgePosition(writer, .left, "::before", "left", true);
    }
    if (self.hover.right != null) {
        self.writeSingleEdgePosition(writer, .right, "::after", "right", true);
    }
}

fn writeSingleEdgePosition(
    self: Edges,
    writer: *Writer,
    edge: Edge,
    pseudo: []const u8,
    pos_prop: []const u8,
    hover: bool,
) void {
    const state = if (hover) self.hover else self.normal;
    const config = state.get(edge) orelse return;

    writer.write(".") catch {};
    writer.write(self.class) catch {};
    if (hover) writer.write(":hover") catch {};
    writer.write(pseudo) catch {};
    writer.write(" {\n  ") catch {};
    writer.write(pos_prop) catch {};
    writer.write(": ") catch {};
    self.writeFloat(writer, config.offset);
    writer.write("px;\n") catch {};

    // Inset for horizontal edges (left/right inset)
    if (edge == .top or edge == .bottom) {
        if (config.inset > 0) {
            writer.write("  left: ") catch {};
            self.writeFloat(writer, config.inset);
            writer.write("%;\n  right: ") catch {};
            self.writeFloat(writer, config.inset);
            writer.write("%;\n") catch {};
        }
    }
    // Inset for vertical edges (top/bottom inset)
    if (edge == .left or edge == .right) {
        if (config.inset > 0) {
            writer.write("  top: ") catch {};
            self.writeFloat(writer, config.inset);
            writer.write("%;\n  bottom: ") catch {};
            self.writeFloat(writer, config.inset);
            writer.write("%;\n") catch {};
        }
    }

    // Color override
    if (config.color) |c| {
        writer.write("  background: ") catch {};
        c.toCss(writer) catch {};
        writer.write(";\n") catch {};
    }

    writer.write("}\n\n") catch {};
}

fn writeWrappedModeCss(self: Edges, writer: *Writer) void {
    const inner = self.inner_class orelse return;

    // Wrapper base styles
    writer.write(".") catch {};
    writer.write(self.class) catch {};
    writer.write(" {\n  position: relative;\n  display: inline-block;\n}\n\n") catch {};

    // Inner element base styles
    writer.write(".") catch {};
    writer.write(inner) catch {};
    writer.write(" {\n  position: relative;\n  z-index: 1;\n}\n\n") catch {};

    // Top & Bottom edges (on wrapper)
    self.writeWrapperPseudoBase(writer);

    // Left & Right edges (on inner)
    self.writeInnerPseudoBase(writer);

    // Individual positions
    self.writeWrappedEdgePositions(writer, false);

    // Hover states
    if (self.hasHoverChanges()) {
        self.writeWrappedEdgePositions(writer, true);
    }
}

fn writeWrapperPseudoBase(self: Edges, writer: *Writer) void {
    const has_top = self.normal.top != null;
    const has_bottom = self.normal.bottom != null;

    if (!has_top and !has_bottom) return;

    writer.write(".") catch {};
    writer.write(self.class) catch {};
    writer.write("::before,\n.") catch {};
    writer.write(self.class) catch {};
    writer.write("::after {\n") catch {};
    writer.write("  content: '';\n  position: absolute;\n  left: 0;\n  right: 0;\n") catch {};

    const config = self.normal.top orelse self.normal.bottom.?;
    writer.write("  height: ") catch {};
    self.writeFloat(writer, config.thickness);
    writer.write("px;\n  background: ") catch {};
    if (config.color) |c| {
        c.toCss(writer) catch {};
    } else {
        writer.write("currentColor") catch {};
    }
    writer.write(";\n  transition: ") catch {};
    self.writeFloat(writer, @floatFromInt(self.transition_ms));
    writer.write("ms ") catch {};
    writer.write(self.easing) catch {};
    writer.write(";\n}\n\n") catch {};
}

fn writeInnerPseudoBase(self: Edges, writer: *Writer) void {
    const inner = self.inner_class orelse return;
    const has_left = self.normal.left != null;
    const has_right = self.normal.right != null;

    if (!has_left and !has_right) return;

    writer.write(".") catch {};
    writer.write(inner) catch {};
    writer.write("::before,\n.") catch {};
    writer.write(inner) catch {};
    writer.write("::after {\n") catch {};
    writer.write("  content: '';\n  position: absolute;\n  top: 0;\n  bottom: 0;\n") catch {};

    const config = self.normal.left orelse self.normal.right.?;
    writer.write("  width: ") catch {};
    self.writeFloat(writer, config.thickness);
    writer.write("px;\n  background: ") catch {};
    if (config.color) |c| {
        c.toCss(writer) catch {};
    } else {
        writer.write("currentColor") catch {};
    }
    writer.write(";\n  transition: ") catch {};
    self.writeFloat(writer, @floatFromInt(self.transition_ms));
    writer.write("ms ") catch {};
    writer.write(self.easing) catch {};
    writer.write(";\n  z-index: -1;\n}\n\n") catch {};
}

fn writeWrappedEdgePositions(self: Edges, writer: *Writer, hover: bool) void {
    const inner = self.inner_class orelse return;
    const state = if (hover) self.hover else self.normal;

    // Top edge
    if (state.top) |config| {
        writer.write(".") catch {};
        writer.write(self.class) catch {};
        if (hover) writer.write(":hover") catch {};
        writer.write("::before {\n  top: ") catch {};
        self.writeFloat(writer, config.offset);
        writer.write("px;\n") catch {};

        if (config.inset > 0) {
            writer.write("  left: ") catch {};
            self.writeFloat(writer, config.inset);
            writer.write("%;\n  right: ") catch {};
            self.writeFloat(writer, config.inset);
            writer.write("%;\n") catch {};
        }

        if (config.color) |c| {
            writer.write("  background: ") catch {};
            c.toCss(writer) catch {};
            writer.write(";\n") catch {};
        }

        writer.write("}\n\n") catch {};
    }

    // Bottom edge
    if (state.bottom) |config| {
        writer.write(".") catch {};
        writer.write(self.class) catch {};
        if (hover) writer.write(":hover") catch {};
        writer.write("::after {\n  bottom: ") catch {};
        self.writeFloat(writer, config.offset);
        writer.write("px;\n") catch {};

        if (config.inset > 0) {
            writer.write("  left: ") catch {};
            self.writeFloat(writer, config.inset);
            writer.write("%;\n  right: ") catch {};
            self.writeFloat(writer, config.inset);
            writer.write("%;\n") catch {};
        }

        if (config.color) |c| {
            writer.write("  background: ") catch {};
            c.toCss(writer) catch {};
            writer.write(";\n") catch {};
        }

        writer.write("}\n\n") catch {};
    }

    // Left edge
    if (state.left) |config| {
        writer.write(".") catch {};
        if (hover) {
            writer.write(self.class) catch {};
            writer.write(":hover .") catch {};
        }
        writer.write(inner) catch {};
        writer.write("::before {\n  left: ") catch {};
        self.writeFloat(writer, config.offset);
        writer.write("px;\n") catch {};

        if (config.inset > 0) {
            writer.write("  top: ") catch {};
            self.writeFloat(writer, config.inset);
            writer.write("%;\n  bottom: ") catch {};
            self.writeFloat(writer, config.inset);
            writer.write("%;\n") catch {};
        }

        if (config.color) |c| {
            writer.write("  background: ") catch {};
            c.toCss(writer) catch {};
            writer.write(";\n") catch {};
        }

        writer.write("}\n\n") catch {};
    }

    // Right edge
    if (state.right) |config| {
        writer.write(".") catch {};
        if (hover) {
            writer.write(self.class) catch {};
            writer.write(":hover .") catch {};
        }
        writer.write(inner) catch {};
        writer.write("::after {\n  right: ") catch {};
        self.writeFloat(writer, config.offset);
        writer.write("px;\n") catch {};

        if (config.inset > 0) {
            writer.write("  top: ") catch {};
            self.writeFloat(writer, config.inset);
            writer.write("%;\n  bottom: ") catch {};
            self.writeFloat(writer, config.inset);
            writer.write("%;\n") catch {};
        }

        if (config.color) |c| {
            writer.write("  background: ") catch {};
            c.toCss(writer) catch {};
            writer.write(";\n") catch {};
        }

        writer.write("}\n\n") catch {};
    }
}

fn hasHoverChanges(self: Edges) bool {
    return self.hover.top != null or
        self.hover.bottom != null or
        self.hover.left != null or
        self.hover.right != null;
}

fn writeFloat(self: Edges, writer: *Writer, val: f32) void {
    _ = self;
    const is_int = @floor(val) == val;
    if (is_int) {
        writer.writeI32(@intFromFloat(val)) catch {};
    } else {
        writer.writeF32(val) catch {};
    }
}

// ============================================
// BUILD / REGISTER
// ============================================

/// Registers the edges under their name so `.edges(name)` can use them.
/// Requires `Edges.new()` first.
pub fn build(self: Edges) void {
    if (Vapor.edges_table == null) return;
    Vapor.edges_table.?.put(self.class, self) catch |err| {
        Vapor.report.err("Could not create edges {any}", .{err});
    };
}
