const std = @import("std");
const Vapor = @import("Vapor.zig"); // Assuming Color is defined here
const Allocator = std.mem.Allocator;
const Color = Vapor.Types.Color;
const Writer = @import("Writer.zig");
const StyleCompiler = @import("convertStyleCustomWriter.zig");

pub const Shadow = @This();

// -- 1. The Single Shadow Layer --
// Represents one comma-separated part of the box-shadow property
pub const Layer = struct {
    inset: bool = false,
    x: i16 = 0,
    y: i16 = 0,
    blur: u16 = 0,
    spread: i16 = 0,
    color: Color = .{ .Literal = .{} },

    pub fn init(color: Color) Layer {
        return .{ .color = color };
    }

    /// Sets X and Y offsets
    pub fn off(self: Layer, x_val: i16, y_val: i16) Layer {
        var l = self;
        l.x = x_val;
        l.y = y_val;
        return l;
    }

    /// Sets blur radius
    pub fn setBlur(self: Layer, val: u16) Layer {
        var l = self;
        l.blur = val;
        return l;
    }

    /// Sets spread radius
    pub fn setSpread(self: Layer, val: i16) Layer {
        var l = self;
        l.spread = val;
        return l;
    }

    /// Marks this layer as an inner shadow
    pub fn setInset(self: Layer) Layer {
        var l = self;
        l.inset = true;
        return l;
    }

    pub fn writeCss(self: Layer, writer: *Writer) !void {
        if (self.inset) _ = try writer.write("inset ");
        try writer.writeI16(self.x);
        try writer.write("px ");
        try writer.writeI16(self.y);
        try writer.write("px ");
        try writer.writeU16(self.blur);
        try writer.write("px ");
        if (self.spread > 0) {
            try writer.writeI16(self.spread);
            try writer.write("px ");
        }
        // Delegate to Color's write implementation
        // Adjust this call based on how your Color struct works (e.g. .format or .toCss)
        try self.color.toCss(writer);
    }
};

// -- 2. The Main Shadow Container --
const MAX_LAYERS = 4; // Sufficient for 99% of UI needs

layers: [MAX_LAYERS]?Layer = [_]?Layer{null} ** MAX_LAYERS,
layer_count: u8 = 0,

/// Start a new shadow definition
pub fn init() Shadow {
    return Shadow{};
}

/// Generic method to add a fully constructed layer
pub fn add(self: Shadow, layer: Layer) Shadow {
    var s = self;
    if (s.layer_count < MAX_LAYERS) {
        s.layers[s.layer_count] = layer;
        s.layer_count += 1;
    }
    return s;
}

// -- 3. Fluent Builders for Inline Use --

/// Add a standard drop shadow: x, y, blur, color
/// Usage: .shadow(Shadow.init().drop(0, 4, 10, .black))
pub fn drop(self: Shadow, x: i16, y: i16, blur: u16, color: Color) Shadow {
    return self.add(Layer.init(color).off(x, y).setBlur(blur));
}

/// Add a drop shadow with spread control
pub fn dropSpread(self: Shadow, x: i16, y: i16, blur: u16, spread: i16, color: Color) Shadow {
    return self.add(Layer.init(color).off(x, y).setBlur(blur).setSpread(spread));
}

/// Add an inset shadow: x, y, color
/// Usage: .shadow(Shadow.init().inset(0, -2, .blue))
pub fn inset(self: Shadow, x: i16, y: i16, color: Color) Shadow {
    return self.add(Layer.init(color).off(x, y).setInset());
}

/// Add an inset shadow with blur
pub fn insetBlur(self: Shadow, x: i16, y: i16, blur: u16, color: Color) Shadow {
    return self.add(Layer.init(color).off(x, y).setBlur(blur).setInset());
}

// -- 4. Presets (Common Patterns) --

/// Standard elevation (drop shadow growing downwards)
pub fn elevation(depth: i16, color: Color) Shadow {
    return init().drop(0, depth, @intCast(depth * 2), color);
}

/// Subtle card shadow (offset x/y)
pub fn card(color: Color) Shadow {
    return init().drop(4, 4, 0, color);
}

/// Glow effect (centered, blurred, optional spread)
pub fn glow(size: u16, color: Color) Shadow {
    return init().dropSpread(0, 0, size, @divFloor(@as(i16, @intCast(size)), 2), color);
}

/// Glow effect (centered, blurred, optional spread)
pub fn insetGlow(x: i16, y: i16, size: u16, color: Color) Shadow {
    return init().dropSpread(x, y, size, @divFloor(@as(i16, @intCast(size)), 2), color);
}

/// Add an inset shadow with blur
pub fn insetSpread(x: i16, y: i16, blur: u16, spread: i16, color: Color) Shadow {
    return init().dropSpread(x, y, blur, spread, color);
}

// -- 5. Output Generation --

pub fn writeCss(self: Shadow, writer: *Writer) !void {
    if (self.layer_count == 0) {
        try writer.write("none");
        return;
    }

    var written: u8 = 0;
    for (self.layers) |maybe_layer| {
        if (maybe_layer) |l| {
            if (written > 0) try writer.write(",");
            try l.writeCss(writer);
            written += 1;
        }
    }
}

pub fn toCss(self: Shadow, writer: *Writer) !void {
    try self.writeCss(writer);
}

// -- 6. Tests --

test "inset and drop layers compose into one box-shadow" {
    // box-shadow: inset 0 -2px #053794, 0 1px 3px #0006
    const s = Shadow.init()
        .inset(0, -2, .hex("#053794"))
        .drop(0, 1, 3, .hex("#0006"));

    var buf: [256]u8 = undefined;
    var writer: Writer = undefined;
    writer.init(&buf);
    try s.writeCss(&writer);
    const css = writer.getAll();

    try std.testing.expectEqualStrings("inset 0px -2px 0px rgb(5,55,148),0px 1px 3px rgba(0,0,0,0.40)", css);
}
