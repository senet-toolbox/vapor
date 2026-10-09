const Vapor = @import("../Vapor.zig");
const Animation = Vapor.Animation;
const Writer = @import("../Writer.zig");

/// Writes all registered animations to the CSS buffer
pub fn generateAnimationsFrames(writer: *Writer) void {
    if (Vapor.animations) |table| {
        var it = table.iterator();
        while (it.next()) |entry| {
            const anim = entry.value_ptr.*;
            writeKeyframesBlock(anim, writer);
        }
    }
}

fn writeKeyframesBlock(anim: Animation, writer: *Writer) void {
    writer.write("@keyframes ") catch {};
    writer.write(anim._name) catch {};
    writer.write(" {\n") catch {};

    if (anim.frame_count > 0) {
        for (anim.frames) |maybe_frame| {
            if (maybe_frame) |frame| {
                writer.writeF32(frame.percent) catch {};
                writer.write("% {\n") catch {};
                writeFrameProperties(frame, writer);
                writer.write("}\n") catch {};
            }
        }
    } else {
        // From (0%)
        writer.write("from { ") catch {};
        writePropertiesAtValue(writer, anim, .from);
        writer.write("}\n") catch {};

        // To (100%)
        writer.write("to { ") catch {};
        writePropertiesAtValue(writer, anim, .to);
        writer.write("}\n") catch {};
    }
    writer.write("}\n") catch {};
}

fn writeFrameProperties(frame: Animation.Keyframe, writer: *Writer) void {
    var has_transform = false;
    var has_filter = false;

    // 1. Group and Write Transforms
    // CSS requires: transform: scale(1) rotate(45deg); (all in one line)
    for (frame.props) |p_opt| {
        if (p_opt) |p| {
            if (p.type.isTransform()) {
                if (!has_transform) {
                    writer.write("transform:") catch {};
                    has_transform = true;
                }
                writer.writeByte(' ') catch {};
                writeAnimTransformValue(p, writer);
            }
        }
    }
    if (has_transform) writer.write(";\n") catch {};

    // 2. Group and Write Filters
    // CSS requires: filter: blur(5px) brightness(1.2); (all in one line)
    for (frame.props) |p_opt| {
        if (p_opt) |p| {
            if (p.type.isFilter()) {
                if (!has_filter) {
                    writer.write("filter:") catch {};
                    has_filter = true;
                }
                writer.writeByte(' ') catch {};
                writeAnimTransformValue(p, writer);
            }
        }
    }
    if (has_filter) writer.write(";\n") catch {};

    // 3. Write Regular Properties (Opacity, Colors, etc.)
    for (frame.props) |p_opt| {
        if (p_opt) |p| {
            if (!p.type.isTransform() and !p.type.isFilter()) {
                // Map the enum type to CSS string
                const prop_str = p.type.toCss();
                writer.write(prop_str) catch {};
                writer.writeByte(':') catch {};

                // Write value + unit
                writeAnimStandardValue(p, writer);
                writer.write(";\n") catch {};
            }
        }
    }
}

fn writeAnimTransformValue(p: Animation.PropValue, writer: *Writer) void {
    const func_name = p.type.toCss();
    writer.write(func_name) catch {};
    writer.writeByte('(') catch {};

    switch (p.value) {
        .number => |val| {
            // Write Float
            const is_int = @floor(val) == val;
            if (is_int) {
                writer.writeI32(@intFromFloat(val)) catch {};
            } else {
                writer.writeF32(val) catch {};
            }
            // Write Unit
            const unit_str = p.unit.toCss();
            writer.write(unit_str) catch {};
        },
        .color => |col| {
            // Use your existing colorToCSS helper from your style system
            // You might need to wrap the Color in PackedColor if your helper expects that
            // Or just call writeRgba directly if it's a raw Color struct

            // Assuming `col` is your standard Color struct:
            col.toCss(writer) catch {};
            // OR if using PackedColor helper:
            // colorToCSS(.{ .color = col, .has_color = true }, writer) catch {};
        },
        .shadow => |shadow| {
            // Use your existing colorToCSS helper from your style system
            // You might need to wrap the Color in PackedColor if your helper expects that
            // Or just call writeRgba directly if it's a raw Color struct

            // Assuming `col` is your standard Color struct:
            shadow.toCss(writer) catch {};
        },
    }

    writer.writeByte(')') catch {};
}

fn writeAnimStandardValue(p: Animation.PropValue, writer: *Writer) void {
    switch (p.value) {
        .number => |val| {
            // Write Float
            const is_int = @floor(val) == val;
            if (is_int) {
                writer.writeI32(@intFromFloat(val)) catch {};
            } else {
                writer.writeF32(val) catch {};
            }
            // Write Unit
            const unit_str = p.unit.toCss();
            writer.write(unit_str) catch {};
        },
        .color => |col| {
            // Use your existing colorToCSS helper from your style system
            // You might need to wrap the Color in PackedColor if your helper expects that
            // Or just call writeRgba directly if it's a raw Color struct

            // Assuming `col` is your standard Color struct:
            col.toCss(writer) catch {};
            // OR if using PackedColor helper:
            // colorToCSS(.{ .color = col, .has_color = true }, writer) catch {};
        },
        .shadow => |shadow| {
            // Use your existing colorToCSS helper from your style system
            // You might need to wrap the Color in PackedColor if your helper expects that
            // Or just call writeRgba directly if it's a raw Color struct

            // Assuming `col` is your standard Color struct:
            shadow.toCss(writer) catch {};
        },
    }
}

pub const ValueType = enum { from, to };

fn writePropertiesAtValue(writer: *Writer, animation: Animation, value_type: ValueType) void {
    var has_transform = false;
    var has_filter = false;

    // First pass: check what property groups we have
    for (animation.properties[0..animation.property_count]) |maybe_prop| {
        if (maybe_prop) |p| {
            if (p.prop_type.isTransform()) has_transform = true;
            if (p.prop_type.isFilter()) has_filter = true;
        }
    }

    // Write transform properties (grouped)
    if (has_transform) {
        writer.write("transform: ") catch {};
        var first_transform = true;
        for (animation.properties[0..animation.property_count]) |maybe_prop| {
            if (maybe_prop) |p| {
                if (p.prop_type.isTransform()) {
                    if (!first_transform) writer.writeByte(' ') catch {};
                    first_transform = false;
                    writeTransformValue(writer, p, value_type);
                }
            }
        }
        writer.write("; ") catch {};
    }

    // Write filter properties (grouped)
    if (has_filter) {
        writer.write("filter: ") catch {};
        var first_filter = true;
        for (animation.properties[0..animation.property_count]) |maybe_prop| {
            if (maybe_prop) |p| {
                if (p.prop_type.isFilter()) {
                    if (!first_filter) writer.writeByte(' ') catch {};
                    first_filter = false;
                    writeFilterValue(writer, p, value_type);
                }
            }
        }
        writer.write("; ") catch {};
    }

    // Write standalone properties (opacity, width, etc.)
    for (animation.properties[0..animation.property_count]) |maybe_prop| {
        if (maybe_prop) |p| {
            if (!p.prop_type.isTransform() and !p.prop_type.isFilter()) {
                writeStandaloneProperty(writer, p, value_type);
            }
        }
    }
}

fn writeTransformValue(writer: *Writer, prop: Animation.Property, value_type: ValueType) void {
    const value = switch (value_type) {
        .from => prop.from_value,
        .to => prop.to_value,
    };

    writer.write(prop.prop_type.toCss()) catch {};
    writer.writeByte('(') catch {};
    writer.writeF32(value) catch {};
    writer.write(prop.unit.toCss()) catch {};
    writer.writeByte(')') catch {};
}

fn writeFilterValue(writer: *Writer, prop: Animation.Property, value_type: ValueType) void {
    const value = switch (value_type) {
        .from => prop.from_value,
        .to => prop.to_value,
    };

    writer.write(prop.prop_type.toCss()) catch {};
    writer.writeByte('(') catch {};
    writer.writeF32(value) catch {};

    // Filter units
    switch (prop.prop_type) {
        .blur => writer.write("px") catch {},
        .brightness, .saturate => writer.write("%") catch {},
        else => {},
    }
    writer.writeByte(')') catch {};
}

fn writeStandaloneProperty(writer: *Writer, prop: Animation.Property, value_type: ValueType) void {
    const value = switch (value_type) {
        .from => prop.from_value,
        .to => prop.to_value,
    };

    writer.write(prop.prop_type.toCss()) catch {};
    writer.write(": ") catch {};
    writer.writeF32(value) catch {};
    writer.write(prop.unit.toCss()) catch {};
    writer.write("; ") catch {};
}
