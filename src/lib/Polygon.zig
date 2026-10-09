const std = @import("std");
const Vapor = @import("vapor.zig");
const Color = Vapor.Types.Color;
const Writer = @import("Writer.zig");

pub const Polygons = @This();

/// Creates the polygon registry. Call it once in `init`, before any `.build()`.
pub fn new() void {
    Vapor.polygons_table = std.StringHashMap(Polygons).init(Vapor.arena(.persist));
}

// ============================================
// TYPES
// ============================================

pub const Shape = enum {
    triangle,
    square,
    pentagon,
    hexagon,
    heptagon,
    octagon,
    star,
    custom,
};

pub const TriangleDirection = enum {
    up,
    down,
    left,
    right,
};

pub const Point = struct {
    x: f32,
    y: f32,
};

pub const PolygonConfig = struct {
    shape: Shape = .custom,
    sides: u8 = 3,
    points: ?[]const Point = null,
    rotation: f32 = 0,
    star_inner_radius: f32 = 0.4, // For stars: inner radius as % of outer
    triangle_dir: TriangleDirection = .up,
};

// ============================================
// MAIN STRUCT
// ============================================

class: []const u8,
config: PolygonConfig = .{},
background: ?Color = null,
border_color: ?Color = null,
border_width: f32 = 0,
hover_background: ?Color = null,
hover_border_color: ?Color = null,
hover_scale: f32 = 1.0,
transition_ms: u32 = 300,
easing: []const u8 = "ease",

// ============================================
// CONSTRUCTORS
// ============================================

/// Starts a polygon shape for the CSS class `class_name`. Apply it to an
/// element with `.class(class_name)` after `.build()`.
pub fn init(class_name: []const u8) Polygons {
    return Polygons{
        .class = class_name,
    };
}

// ============================================
// PRESET SHAPES
// ============================================

/// A triangle pointing in `dir`.
pub fn triangle(self: Polygons, dir: TriangleDirection) Polygons {
    var p = self;
    p.config.shape = .triangle;
    p.config.sides = 3;
    p.config.triangle_dir = dir;
    return p;
}

/// A triangle pointing up.
pub fn triangleUp(self: Polygons) Polygons {
    return self.triangle(.up);
}

/// A triangle pointing down.
pub fn triangleDown(self: Polygons) Polygons {
    return self.triangle(.down);
}

/// A triangle pointing left.
pub fn triangleLeft(self: Polygons) Polygons {
    return self.triangle(.left);
}

/// A triangle pointing right.
pub fn triangleRight(self: Polygons) Polygons {
    return self.triangle(.right);
}

/// A square.
pub fn square(self: Polygons) Polygons {
    var p = self;
    p.config.shape = .square;
    p.config.sides = 4;
    return p;
}

/// A regular pentagon.
pub fn pentagon(self: Polygons) Polygons {
    var p = self;
    p.config.shape = .pentagon;
    p.config.sides = 5;
    return p;
}

/// A regular hexagon.
pub fn hexagon(self: Polygons) Polygons {
    var p = self;
    p.config.shape = .hexagon;
    p.config.sides = 6;
    return p;
}

/// A regular heptagon.
pub fn heptagon(self: Polygons) Polygons {
    var p = self;
    p.config.shape = .heptagon;
    p.config.sides = 7;
    return p;
}

/// A regular octagon.
pub fn octagon(self: Polygons) Polygons {
    var p = self;
    p.config.shape = .octagon;
    p.config.sides = 8;
    return p;
}

/// A regular polygon with `sides` sides.
pub fn ngon(self: Polygons, sides: u8) Polygons {
    var p = self;
    p.config.shape = .custom;
    p.config.sides = sides;
    return p;
}

/// A star with `points_count` points.
pub fn star(self: Polygons, points_count: u8) Polygons {
    var p = self;
    p.config.shape = .star;
    p.config.sides = points_count;
    return p;
}

/// A five-pointed star.
pub fn star5(self: Polygons) Polygons {
    return self.star(5);
}

/// A six-pointed star.
pub fn star6(self: Polygons) Polygons {
    return self.star(6);
}

/// Custom points (each x,y as percentage 0-100)
pub fn custom(self: Polygons, points: []const Point) Polygons {
    var p = self;
    p.config.shape = .custom;
    p.config.points = points;
    return p;
}

// ============================================
// MODIFIERS
// ============================================

/// Rotates the shape by `degrees`.
pub fn rotate(self: Polygons, degrees: f32) Polygons {
    var p = self;
    p.config.rotation = degrees;
    return p;
}

/// For stars: how deep the inner points go (0.1 = very pointy, 0.9 = barely a star)
pub fn innerRadius(self: Polygons, ratio: f32) Polygons {
    var p = self;
    p.config.star_inner_radius = ratio;
    return p;
}

// ============================================
// STYLING
// ============================================

/// Fill colour.
pub fn fill(self: Polygons, c: Color) Polygons {
    var p = self;
    p.background = c;
    return p;
}

/// Outline colour and width.
pub fn stroke(self: Polygons, c: Color, width: f32) Polygons {
    var p = self;
    p.border_color = c;
    p.border_width = width;
    return p;
}

/// Animates hover changes over `ms` milliseconds.
pub fn transition(self: Polygons, ms: u32) Polygons {
    var p = self;
    p.transition_ms = ms;
    return p;
}

/// CSS timing function for the transition, e.g. "ease-out".
pub fn ease(self: Polygons, easing_fn: []const u8) Polygons {
    var p = self;
    p.easing = easing_fn;
    return p;
}

// ============================================
// HOVER STATES
// ============================================

/// Fill colour while hovered.
pub fn hoverFill(self: Polygons, c: Color) Polygons {
    var p = self;
    p.hover_background = c;
    return p;
}

/// Outline colour while hovered.
pub fn hoverStroke(self: Polygons, c: Color) Polygons {
    var p = self;
    p.hover_border_color = c;
    return p;
}

/// Scale while hovered (1 is unchanged).
pub fn hoverScale(self: Polygons, scale: f32) Polygons {
    var p = self;
    p.hover_scale = scale;
    return p;
}

// ============================================
// CSS GENERATION
// ============================================

/// Writes the shape's CSS rules to `writer`.
pub fn writeCss(self: Polygons, writer: *Writer) void {
    // Base styles
    writer.write(".") catch {};
    writer.write(self.class) catch {};
    writer.write(" {\n") catch {};

    // Background
    if (self.background) |bg| {
        writer.write("  background: ") catch {};
        bg.toCss(writer) catch {};
        writer.write(";\n") catch {};
    }

    // Clip path
    writer.write("  clip-path: polygon(") catch {};
    self.writePolygonPoints(writer);
    writer.write(");\n") catch {};

    // Transition
    writer.write("  transition: transform ") catch {};
    writeFloat(writer, @floatFromInt(self.transition_ms));
    writer.write("ms ") catch {};
    writer.write(self.easing) catch {};
    writer.write(", background ") catch {};
    writeFloat(writer, @floatFromInt(self.transition_ms));
    writer.write("ms ") catch {};
    writer.write(self.easing) catch {};
    writer.write(";\n") catch {};

    writer.write("}\n\n") catch {};

    // Hover state
    if (self.hover_background != null or self.hover_scale != 1.0) {
        writer.write(".") catch {};
        writer.write(self.class) catch {};
        writer.write(":hover {\n") catch {};

        if (self.hover_background) |bg| {
            writer.write("  background: ") catch {};
            bg.toCss(writer) catch {};
            writer.write(";\n") catch {};
        }

        if (self.hover_scale != 1.0) {
            writer.write("  transform: scale(") catch {};
            writeFloat(writer, self.hover_scale);
            writer.write(");\n") catch {};
        }

        writer.write("}\n\n") catch {};
    }

    // Border using drop-shadow filter (works with clip-path)
    if (self.border_width > 0 and self.border_color != null) {
        self.writeBorderStyles(writer);
    }
}

fn writePolygonPoints(self: Polygons, writer: *Writer) void {
    // Custom points take precedence
    if (self.config.points) |pts| {
        for (pts, 0..) |pt, i| {
            if (i > 0) writer.write(", ") catch {};
            writeFloat(writer, pt.x);
            writer.write("% ") catch {};
            writeFloat(writer, pt.y);
            writer.write("%") catch {};
        }
        return;
    }

    switch (self.config.shape) {
        .triangle => self.writeTrianglePoints(writer),
        .star => self.writeStarPoints(writer),
        else => self.writeRegularPolygonPoints(writer),
    }
}

fn writeTrianglePoints(self: Polygons, writer: *Writer) void {
    const points: [3]Point = switch (self.config.triangle_dir) {
        .up => .{
            .{ .x = 50, .y = 0 },
            .{ .x = 100, .y = 100 },
            .{ .x = 0, .y = 100 },
        },
        .down => .{
            .{ .x = 0, .y = 0 },
            .{ .x = 100, .y = 0 },
            .{ .x = 50, .y = 100 },
        },
        .left => .{
            .{ .x = 100, .y = 0 },
            .{ .x = 100, .y = 100 },
            .{ .x = 0, .y = 50 },
        },
        .right => .{
            .{ .x = 0, .y = 0 },
            .{ .x = 100, .y = 50 },
            .{ .x = 0, .y = 100 },
        },
    };

    for (points, 0..) |pt, i| {
        if (i > 0) writer.write(", ") catch {};
        const rotated = self.rotatePoint(pt, self.config.rotation);
        writeFloat(writer, rotated.x);
        writer.write("% ") catch {};
        writeFloat(writer, rotated.y);
        writer.write("%") catch {};
    }
}

fn writeRegularPolygonPoints(self: Polygons, writer: *Writer) void {
    const sides = self.config.sides;
    const base_rotation = self.config.rotation - 90; // Start from top

    var i: u8 = 0;
    while (i < sides) : (i += 1) {
        if (i > 0) writer.write(", ") catch {};

        const angle_deg = base_rotation + (@as(f32, @floatFromInt(i)) * 360.0 / @as(f32, @floatFromInt(sides)));
        const angle_rad = angle_deg * std.math.pi / 180.0;

        const x = 50.0 + 50.0 * @cos(angle_rad);
        const y = 50.0 + 50.0 * @sin(angle_rad);

        writeFloat(writer, x);
        writer.write("% ") catch {};
        writeFloat(writer, y);
        writer.write("%") catch {};
    }
}

fn writeStarPoints(self: Polygons, writer: *Writer) void {
    const points_count = self.config.sides;
    const inner = self.config.star_inner_radius;
    const base_rotation = self.config.rotation - 90;

    var i: u8 = 0;
    const total_points = points_count * 2;
    while (i < total_points) : (i += 1) {
        if (i > 0) writer.write(", ") catch {};

        const angle_deg = base_rotation + (@as(f32, @floatFromInt(i)) * 360.0 / @as(f32, @floatFromInt(total_points)));
        const angle_rad = angle_deg * std.math.pi / 180.0;

        // Alternate between outer (1.0) and inner radius
        const radius: f32 = if (i % 2 == 0) 50.0 else 50.0 * inner;

        const x = 50.0 + radius * @cos(angle_rad);
        const y = 50.0 + radius * @sin(angle_rad);

        writeFloat(writer, x);
        writer.write("% ") catch {};
        writeFloat(writer, y);
        writer.write("%") catch {};
    }
}

fn rotatePoint(self: Polygons, pt: Point, degrees: f32) Point {
    _ = self;
    if (degrees == 0) return pt;

    const rad = degrees * std.math.pi / 180.0;
    const cos_a = @cos(rad);
    const sin_a = @sin(rad);

    // Rotate around center (50, 50)
    const cx = pt.x - 50;
    const cy = pt.y - 50;

    return .{
        .x = 50 + cx * cos_a - cy * sin_a,
        .y = 50 + cx * sin_a + cy * cos_a,
    };
}

fn writeBorderStyles(self: Polygons, writer: *Writer) void {
    // Use a wrapper approach for borders with clip-path
    writer.write(".") catch {};
    writer.write(self.class) catch {};
    writer.write("-border {\n") catch {};
    writer.write("  position: relative;\n") catch {};
    writer.write("  background: ") catch {};
    if (self.border_color) |c| {
        c.toCss(writer) catch {};
    }
    writer.write(";\n") catch {};
    writer.write("  clip-path: polygon(") catch {};
    self.writePolygonPoints(writer);
    writer.write(");\n") catch {};
    writer.write("  padding: ") catch {};
    writeFloat(writer, self.border_width);
    writer.write("px;\n") catch {};
    writer.write("}\n\n") catch {};
}

fn writeFloat(writer: *Writer, val: f32) void {
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

/// Registers the shape so its CSS is emitted. Requires `Polygons.new()` first.
pub fn build(self: Polygons) void {
    if (Vapor.polygons_table == null) return;
    Vapor.polygons_table.?.put(self.class, self) catch |err| {
        Vapor.println("Could not create polygon {any}\n", .{err});
    };
}
