const Values = @import("values.zig");
const Writer = @import("../Writer.zig");
const Types = @import("../types.zig");
const Vapor = @import("../Vapor.zig");

pub fn gridToCSS(grid: Types.PackedGrid, writer: anytype) !void {
    writer.write("linear-gradient(90deg, ") catch {};
    const grid_color = grid.packed_color.has_color;
    if (grid_color) {
        const rgba = grid.packed_color.color;
        Values.writeRgba(writer, rgba) catch {};
    } else {
        Values.writeThematic(writer, grid.packed_color.token) catch {};
    }
    writer.writeByte(' ') catch {};
    writer.writeU8Num(grid.thickness) catch {};
    writer.write("px, ") catch {};
    Values.writeRgba(writer, .{}) catch {};
    writer.writeByte(' ') catch {};
    writer.writeU8Num(grid.thickness) catch {};
    writer.write("px),") catch {};

    writer.write("linear-gradient(180deg, ") catch {};
    if (grid_color) {
        const rgba = grid.packed_color.color;
        Values.writeRgba(writer, rgba) catch {};
    } else {
        Values.writeThematic(writer, grid.packed_color.token) catch {};
    }
    writer.writeByte(' ') catch {};
    writer.writeU8Num(grid.thickness) catch {};
    writer.write("px, ") catch {};
    Values.writeRgba(writer, .{}) catch {};
    writer.writeByte(' ') catch {};
    writer.writeU8Num(grid.thickness) catch {};
    writer.write("px)") catch {};
}

pub fn dotsToCSS(dots: Types.PackedDots, writer: anytype) !void {
    writer.write("radial-gradient(circle, ") catch {};
    const dots_color = dots.packed_color.has_color;
    if (dots_color) {
        const rgba = dots.packed_color.color;
        Values.writeRgba(writer, rgba) catch {};
    } else {
        Values.writeThematic(writer, dots.packed_color.token) catch {};
    }
    writer.writeByte(' ') catch {};
    writer.writeF16(dots.radius) catch {};
    writer.write("px, ") catch {};
    writer.write("transparent") catch {};
    writer.writeByte(' ') catch {};
    writer.writeF16(0) catch {};
    writer.write("px)") catch {};
}

pub fn gradientToCSS(gradient: Types.PackedGradient, writer: *Writer) !void {
    switch (gradient.type) {
        .linear => {
            writer.write("linear-gradient(") catch {};
        },
        .radial => {
            writer.write("radial-gradient(") catch {};
        },
        else => {
            Vapor.printlnSrcErr("Gradient is not radius or linear", .{}, @src());
        },
    }
    switch (gradient.direction.type) {
        .to_top => writer.write("to top") catch {},
        .to_bottom => writer.write("to bottom") catch {},
        .to_left => writer.write("to left") catch {},
        .to_right => writer.write("to right") catch {},
        .to_top_left => writer.write("to top left") catch {},
        .to_top_right => writer.write("to top right") catch {},
        .angle => {
            writer.writeF32(gradient.direction.angle) catch {};
            writer.write("deg") catch {};
        },
        .none => {},
    }
    if (gradient.colors_ptr > 0) {
        const colors = Vapor.packed_colors.get(gradient.colors_ptr) orelse {
            Vapor.printlnSrcErr("Colors ptr is null", .{}, @src());
            return;
        };
        for (colors) |color| {
            writer.write(", ") catch {};
            Values.colorToCSS(color, writer) catch {};
        }
    }

    writer.write(")") catch {};
}

fn linesToCSS(lines: Types.PackedLines, writer: anytype) !void {
    writer.write("repeating-linear-gradient(") catch {};

    switch (lines.direction) {
        .horizontal => writer.write("0deg") catch {},
        .vertical => writer.write("90deg") catch {},
        .diagonal_up => writer.write("-45deg") catch {},
        .diagonal_down => writer.write("45deg") catch {},
    }

    writer.write(", ") catch {};

    const has_color = lines.color.has_color;
    if (has_color) {
        Values.writeRgba(writer, lines.color.color) catch {};
    } else {
        Values.writeThematic(writer, lines.color.token) catch {};
    }

    writer.write(" 0px, ") catch {};

    if (has_color) {
        Values.writeRgba(writer, lines.color.color) catch {};
    } else {
        Values.writeThematic(writer, lines.color.token) catch {};
    }

    writer.writeByte(' ') catch {};
    writer.writeU8Num(lines.thickness) catch {};
    writer.write("px, transparent ") catch {};
    writer.writeU8Num(lines.thickness) catch {};
    writer.write("px, transparent ") catch {};
    writer.writeU8Num(lines.spacing) catch {};
    writer.write("px)") catch {};
}

pub fn backgroundLayersToCSS(packed_layers: Types.PackedLayers, writer: *Writer) !void {
    const layers = Vapor.packed_layers.get(packed_layers.items_ptr) orelse @panic("vapor: background layers missing from packed_layers");

    for (layers, 0..) |layer, i| {
        switch (layer) {
            .Gradient => |gradient| {
                try gradientToCSS(gradient, writer);

                // Write clip directly after the gradient
                if (gradient.clip != .none) {
                    writer.write(" ") catch {};
                    writer.write(gradient.clip.toCss()) catch {};
                }
            },
            else => {},
        }
        if (i < packed_layers.len - 1) {
            writer.write(", ") catch {};
        }
    }
    writer.write(";\n") catch {};
}

pub fn layersToCSS(packed_layers: Types.PackedLayers, writer: *Writer) !void {
    const layers = Vapor.packed_layers.get(packed_layers.items_ptr) orelse @panic("vapor: background layers missing from packed_layers");

    // First pass: write background-image
    for (layers, 0..) |layer, i| {
        switch (layer) {
            .Grid => |grid| {
                try gridToCSS(grid, writer);
            },
            .Dot => |dots| {
                try dotsToCSS(dots, writer);
            },
            .Lines => |lines| {
                try linesToCSS(lines, writer);
            },
            .Gradient => |gradient| {
                try gradientToCSS(gradient, writer);
            },
        }
        if (i < packed_layers.len - 1) {
            writer.write(", \n") catch {};
        } else {
            writer.write(";\n") catch {};
        }
    }

    // Second pass: write background-clip
    var has_clip = false;
    for (layers) |layer| {
        switch (layer) {
            .Gradient => |gradient| {
                if (gradient.clip != .none) {
                    has_clip = true;
                    break;
                }
            },
            else => {},
        }
    }

    if (has_clip) {
        writer.write("background-clip: ") catch {};
        for (layers, 0..) |layer, i| {
            const clip: Vapor.Types.BackgroundClip = switch (layer) {
                .Gradient => |gradient| gradient.clip,
                // Default to border-box for non-gradient layers
                else => .borderBox,
            };

            if (clip != .none) {
                writer.write(clip.toCss()) catch {};
            } else {
                writer.write("border-box") catch {};
            }

            if (i < packed_layers.len - 1) {
                writer.write(", ") catch {};
            } else {
                writer.write(";\n") catch {};
            }
        }
    }

    // Third pass: write background-size
    for (layers, 0..) |layer, i| {
        switch (layer) {
            .Grid => |grid| {
                writer.write("background-size: ") catch {};
                writer.writeU16(grid.size) catch {};
                writer.write("px ") catch {};
                writer.writeU16(grid.size) catch {};
                writer.write("px, ") catch {};

                writer.writeU16(grid.size) catch {};
                writer.write("px ") catch {};
                writer.writeU16(grid.size) catch {};
                writer.write("px") catch {};
            },
            .Lines => {
                break;
            },
            .Dot => |dots| {
                writer.write("background-size: ") catch {};
                writer.writeU16(dots.spacing) catch {};
                writer.write("px ") catch {};
                writer.writeU16(dots.spacing) catch {};
                writer.write("px") catch {};
            },
            .Gradient => {
                writer.write("background-size: ") catch {};
                writer.write("100% 100%") catch {};
            },
        }
        if (i < packed_layers.len - 1) {
            writer.write(", \n") catch {};
        } else {
            writer.write(";\n") catch {};
        }
    }

    writer.write("background-position: center center") catch {};
}
