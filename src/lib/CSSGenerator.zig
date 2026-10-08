// CSS Rules, classnames must always be with dashes, cannot use icon types
const std = @import("std");
const UITree = @import("UITree.zig");
const UINode = UITree.UINode;
const indexOf = UITree.indexOf;
const StyleWriter = @import("convertStyleCustomWriter.zig");
const generateStyle = StyleWriter.generateStyle;
const Vapor = @import("Vapor.zig");
const Writer = @import("Writer.zig");
const KeyGenerator = @import("Key.zig").KeyGenerator;
const Types = @import("types.zig");
const Packer = @import("Packer.zig");
const Edges = @import("Edges.zig").Edges;
const Abstractions = @import("Abstractions.zig");
const ManagedMemoryPool = Abstractions.ManagedMemoryPool;
const ManagedAutoHashMap = Abstractions.ManagedAutoHashMap;

const Generator = @This();
buffer: [1024 * 1024]u8 = undefined,
start: usize = 0,
end: usize = 0,
pub fn init(gen: *Generator) void {
    gen.* = .{};
}

pub fn deinit(gen: *Generator) void {
    gen.start = 0;
    gen.end = 0;
    gen.buffer = undefined;
}

var writer: Writer = undefined;
var injectedCSS = Vapor.persist.array([]const u8);

pub fn injectCSS(css: []const u8) void {
    injectedCSS.append(css);
}

// -----------------------------------------------------------------------------
// SECTION 1: Original Helper Functions (Unchanged)
// -----------------------------------------------------------------------------
// These functions are already simple, single-purpose wrappers.

fn writeCss(_: *Generator, node: *UINode, _: []const u8) void {
    writer.writeByte('{') catch {};
    writer.writeByte('\n') catch {};
    StyleWriter.generateStylePass(node, &writer);
    writer.writeByte('}') catch {};
    writer.writeByte('\n') catch {};

    // This area checks if the current node has a hover style
    // if it does, we then check if the children of the node inherit the hover style
    if (node.packed_field_ptrs) |packed_field_ptrs| {
        if (packed_field_ptrs.interactive_ptr) |interactive_ptr| {
            if (interactive_ptr.has_hover) {
                writer.writeByte('.') catch {};
                writer.write(node.class.?) catch {};
                writer.write(":hover") catch {};
                writer.write("{\n") catch {};

                const hover = interactive_ptr.hover;
                StyleWriter.generateVisual(&hover, &writer);
                writer.writeByte('}') catch {};
                writer.writeByte('\n') catch {};

                // Now we write the inherited styles for the children
                // in the form or .class:hover .child_class {}
                // We write the inherited styles for the children
                if (node.children_count > 0) {
                    writer.writeByte('.') catch {};
                    writer.write(node.class.?) catch {};
                    writer.write(":hover") catch {};
                    var children = node.children();
                    while (children.next()) |child| {
                        if (child.hover_style_fields) |fields| {
                            if (child.class) |class| {
                                writer.writeByte(' ') catch {};
                                writer.writeByte('.') catch {};
                                writer.write(class) catch {};

                                writer.write("{\n") catch {};
                                for (fields.*) |field| {
                                    StyleWriter.writeStyleField(field, &hover, &writer);
                                }
                                writer.writeByte('}') catch {};
                                writer.writeByte('\n') catch {};
                            }
                        }
                    }
                }
            }
        }
    }
}

fn writeLayout(layout_ptr: *const Types.PackedLayout) void {
    StyleWriter.generateLayout(layout_ptr, &writer);
}

fn writeVisual(visual_ptr: *const Types.PackedVisual) void {
    StyleWriter.generateVisual(visual_ptr, &writer);
}

fn writeInteractive(interactive_ptr: *const Types.PackedInteractive) void {
    const hover = interactive_ptr.hover;
    const hover_position = interactive_ptr.hover_position;
    StyleWriter.generateVisual(&hover, &writer);
    StyleWriter.generatePositions(&hover_position, &writer);
    if (interactive_ptr.has_hover_transform) {
        StyleWriter.writePropValue("transform", .{ .tag = .transform_type, .data = .{ .transform_type = interactive_ptr.hover_transform } }, &writer);
    }
}

fn writeAnimation(animation_ptr: *const Types.PackedAnimations) void {
    StyleWriter.generateAnimations(animation_ptr, &writer);
}

fn writePos(pos_ptr: *const Types.PackedPosition) void {
    StyleWriter.generatePositions(pos_ptr, &writer);
}

fn writeMarginPaddings(margin_paddings_ptr: *const Types.PackedMarginsPaddings) void {
    StyleWriter.generateMarginsPadding(margin_paddings_ptr, &writer);
}

fn writeTransform(transform_ptr: *const Types.PackedTransforms) void {
    StyleWriter.generateTransforms(transform_ptr, &writer);
}

fn writeToken(token: []const u8) void {
    writer.writeByte('.') catch {};
    writer.write(token) catch {};
    writer.writeByte('{') catch {};
    writer.writeByte('\n') catch {};
}

// -----------------------------------------------------------------------------
// SECTION 2: New & Refactored Helper Functions
// -----------------------------------------------------------------------------

/// NEW: This helper just performs the buffer copy.
fn appendWriterToGenerator(gen: *Generator) void {
    const len: usize = writer.pos;
    if (gen.start + len > gen.buffer.len) {
        // Truncate rather than run past the buffer. `unreachable` here was
        // undefined behaviour in the ReleaseSmall builds that ship.
        Vapor.printlnErr(
            "css: stylesheet exceeds the {d} byte buffer, output truncated at {d}",
            .{ gen.buffer.len, gen.start },
        );
        return;
    }
    gen.end += len;
    @memcpy(gen.buffer[gen.start..gen.end], writer.buffer[0..len]);
    gen.start += len;
}

/// REFACTORED: Now uses the new appendWriterToGenerator helper.
fn writeToGlobal(gen: *Generator) void {
    writer.writeByte('}') catch {};
    writer.writeByte('\n') catch {};
    appendWriterToGenerator(gen);
}

/// NEW: This generic function replaces ALL the loops in `writeAllStyles`.
fn writeCommonStyleGroup(
    gen: *Generator,
    allocator: std.mem.Allocator,
    map: anytype,
    class_prefix: []const u8,
    key_buf: *[128]u8,
    write_fn: anytype,
    token_suffix: ?[]const u8,
) void {
    var itr = map.iterator();
    while (itr.next()) |entry| {
        const hash = entry.key_ptr.*;
        const value_ptr = entry.value_ptr.*;
        const common_key = KeyGenerator.generateHashKey(key_buf, hash, class_prefix);

        var local_buffer: [4096]u8 = undefined;
        writer.init(local_buffer[0..]);

        if (token_suffix) |suffix| {
            // Handle special cases like ":hover"
            // Losing this token means the rule is not emitted for that
            // pseudo-state, not that the whole stylesheet is invalid.
            const full_token = std.fmt.allocPrint(allocator, "{s}{s}", .{ common_key, suffix }) catch |err| {
                Vapor.printlnErr("css: could not build token '{s}{s}': {any}", .{ common_key, suffix, err });
                return;
            };
            writeToken(full_token);
            // No free needed, `allocator` is a frame allocator
        } else {
            writeToken(common_key);
        }

        write_fn(value_ptr); // Call the specific function (e.g., writeLayout)
        gen.writeToGlobal();
    }
}

/// NEW: This helper consolidates the repeated logic in `writeNodeStyle`.
fn writeFullNodeRule(gen: *Generator, node: *UINode, selector: []const u8) void {
    var buffer: [4096]u8 = undefined;
    writer.init(buffer[0..]);

    writer.writeByte('.') catch {};
    writer.write(selector) catch {};

    gen.writeCss(node, selector); // This writes the full { ...styles... } block

    appendWriterToGenerator(gen);
}

// -----------------------------------------------------------------------------
// SECTION 3: Consolidated Public Functions
// -----------------------------------------------------------------------------

/// REFACTORED: Now dramatically simpler, just calls the new helper.
pub fn writeAllStyles(gen: *Generator) void {
    const allocator = Vapor.arena(.frame);
    var key_buf: [128]u8 = undefined; // Shared buffer for key generation

    writeCommonStyleGroup(gen, allocator, &Packer.layouts, "lay", &key_buf, writeLayout, null);
    writeCommonStyleGroup(gen, allocator, &Packer.visuals, "vis", &key_buf, writeVisual, null);

    writeCommonStyleGroup(gen, allocator, &Packer.positions, "pos", &key_buf, writePos, null);
    writeCommonStyleGroup(gen, allocator, &Packer.margins_paddings, "mapa", &key_buf, writeMarginPaddings, null);
    writeCommonStyleGroup(gen, allocator, &Packer.transforms, "tran", &key_buf, writeTransform, null);
    writeCommonStyleGroup(gen, allocator, &Packer.animations, "anim", &key_buf, writeAnimation, null);

    // Special cases with ":hover"
    writeCommonStyleGroup(gen, allocator, &Packer.interactives, "intr", &key_buf, writeInteractive, ":hover");
    writeCommonStyleResponsive(gen, &Packer.responsives, "resp", &key_buf);
}

fn writeCommonStyleResponsive(
    gen: *Generator,
    map: *ManagedAutoHashMap(u32, *Vapor.Types.PackedResponsive),
    class_prefix: []const u8,
    key_buf: *[128]u8,
) void {
    var itr = map.iterator();
    while (itr.next()) |entry| {
        const hash = entry.key_ptr.*;
        const value_ptr = entry.value_ptr.*;
        const common_key = KeyGenerator.generateHashKey(key_buf, hash, class_prefix);

        var local_buffer: [4096]u8 = undefined;
        writer.init(local_buffer[0..]);

        // flag 0 is mobile
        // flag 0 is mobile (applies below tablet breakpoint)
        if (value_ptr.flags_layout[0]) {
            writer.write("@media (max-width: 767px) {") catch {};
            writeToken(common_key);
            StyleWriter.generateLayout(&value_ptr.mobile_layout, &writer);

            if (value_ptr.flags_visual[0]) {
                writer.write("\n") catch {};
                StyleWriter.generateVisual(&value_ptr.mobile_visual, &writer);
            }

            writer.write("}\n") catch {};
            gen.writeToGlobal();
        }

        // flag 2 is tablet (applies at tablet and above)
        if (value_ptr.flags_layout[2]) {
            writer.write("@media (min-width: 768px) {") catch {};
            writeToken(common_key);
            StyleWriter.generateLayout(&value_ptr.tablet_layout, &writer);

            if (value_ptr.flags_visual[2]) {
                writer.write("\n") catch {};
                StyleWriter.generateVisual(&value_ptr.tablet_visual, &writer);
            }

            writer.write("}\n") catch {};
            gen.writeToGlobal();
        }
        // flag 1 is desktop (applies at desktop and above)
        if (value_ptr.flags_layout[1]) {
            writer.write("@media (min-width: 1024px) {") catch {};
            writeToken(common_key);
            StyleWriter.generateLayout(&value_ptr.desktop_layout, &writer);

            if (value_ptr.flags_visual[1]) {
                writer.write("\n") catch {};
                StyleWriter.generateVisual(&value_ptr.desktop_visual, &writer);
            }

            writer.write("}\n") catch {};
            gen.writeToGlobal();
        }
    }
}

/// REFACTORED: Now uses the `writeFullNodeRule` helper.
pub fn writeNodeStyle(gen: *Generator, node: *UINode) void {
    const class = node.class;

    if (class) |c| {
        var tokenized = std.mem.tokenizeScalar(u8, c, ' ');
        while (tokenized.next()) |token| {
            if (contains(token, "gk")) {
                // Generate the "fbc-..." selector
                var fbc_buf: [256]u8 = undefined; // Buffer for UUID string
                const fbc_selector = std.fmt.bufPrint(&fbc_buf, "fbc-{s}", .{node.uuid}) catch |err| {
                    Vapor.printlnErr("css: uuid too long for a selector '{s}': {any}", .{ node.uuid, err });
                    continue;
                };
                writeFullNodeRule(gen, node, fbc_selector);
            } else if (token.len > 0) {
                writeFullNodeRule(gen, node, token);
            }
        }
    }
}

pub fn writeTargetStyle(gen: *Generator, node: *UINode, hash_tv: u32, target_ptr: *Types.PackedVisual) void {
    var key_buf: [128]u8 = undefined;
    const target = node.target.?;

    var buffer: [4096]u8 = undefined;
    writer.init(buffer[0..]);
    writer.writeByte('.') catch {};
    const common_key = KeyGenerator.generateHashKey(&key_buf, hash_tv, "t_vis");
    writer.write(common_key) catch {};
    writer.write(":hover ") catch {};
    writer.writeByte('.') catch {};
    writer.write(target) catch {};
    writer.writeByte(' ') catch {};

    writer.write("{\n") catch {};
    StyleWriter.generateVisual(target_ptr, &writer);
    writer.writeByte('}') catch {};
    writer.writeByte('\n') catch {};

    appendWriterToGenerator(gen);
}

pub fn printCSS(gen: *Generator) void {
    const buffer = gen.buffer[0..gen.end];
    Vapor.println("{s}", .{buffer});
}

pub fn getCSS(gen: *Generator) []const u8 {
    for (injectedCSS.items) |css| {
        const len: usize = css.len;
        gen.end += len;
        if (gen.start + len > gen.buffer.len) {
            Vapor.printlnErr("Buffer overflow, increase buffer size {d}\n", .{gen.start + len});
            @panic("vapor: Buffer overflow, increase buffer size");
        }
        @memcpy(gen.buffer[gen.start..gen.end], css[0..len]);
        gen.start += len;
    }

    return gen.buffer[0..gen.end];
}

pub fn getAnimations(gen: *Generator) []const u8 {
    _ = gen;
    const ptr = StyleWriter.getAnimationsPtr() orelse return "";
    const len = StyleWriter.getAnimationsLen();
    return ptr[0..len];
}

/// Uses SIMD to check if a needle exists within a haystack.
pub fn contains(haystack: []const u8, needle: []const u8) bool {
    return std.mem.indexOf(u8, haystack, needle) != null;
}
