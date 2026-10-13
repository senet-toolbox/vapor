//! Compile-only gate. Not part of the shipped library.
//!
//! Zig analyses declarations lazily: a function that nothing references is
//! parsed but never type-checked. A library therefore compiles "clean" while
//! large parts of its public API are broken, and users discover the breakage
//! one API at a time. This file forces the compiler to analyse every module
//! under `src/` and every public declaration those modules expose.
//!
//! Referenced only by the `check` build step, which `zig build` and
//! `zig build test` both depend on. `build.zig` verifies that every `.zig`
//! file under `src/` appears in one of the two lists below, so a new file
//! cannot silently opt out of type-checking.
//!
//! Every module in the library is type-checked, on both the wasm and the host
//! target. There is no opt-out list.

const std = @import("std");
const builtin = @import("builtin");

/// A consumer supplies `theme` and `config`; the check compiles against the
/// fixtures in `tests/support/`. `tests/support/theme.zig` imports "vapor",
/// which for the check step resolves to this file, so re-export what it needs.
/// Routing it to a second module rooted at `root.zig` would give the check
/// two distinct copies of every type.
pub const Types = @import("lib/types.zig");

/// Modules the gate enforces. Every source file under `src/` belongs either
/// here or in `host_only_modules`; `build.zig` fails the check if one is
/// listed in neither.
const modules = .{
    @import("root.zig"),
    @import("lib/abstractions.zig"),
    @import("lib/accessibility.zig"),
    @import("lib/Animation.zig"),
    @import("lib/array.zig"),
    @import("lib/bridge.zig"),
    @import("lib/CSSGenerator.zig"),
    @import("lib/class_cache.zig"),
    @import("lib/node_table.zig"),
    @import("lib/components.zig"),
    @import("lib/configuration.zig"),
    @import("lib/DateTime.zig"),
    @import("lib/draggable.zig"),
    @import("lib/dynamic.zig"),
    @import("lib/Edges.zig"),
    @import("lib/element.zig"),
    @import("lib/Event.zig"),
    @import("lib/fetch.zig"),
    @import("lib/FrameAllocator.zig"),
    @import("lib/hash_style.zig"),
    @import("lib/key.zig"),
    @import("lib/packer.zig"),
    @import("lib/Polygon.zig"),
    @import("lib/Pool.zig"),
    @import("lib/reconciler.zig"),
    @import("lib/Router.zig"),
    @import("lib/Shadow.zig"),
    @import("lib/storage_table.zig"),
    @import("lib/string_table.zig"),
    @import("lib/text_field.zig"),
    @import("lib/text_field_table.zig"),
    @import("lib/transition.zig"),
    @import("lib/UITree.zig"),
    @import("lib/vapor.zig"),
    @import("lib/wasm.zig"),
    @import("lib/animation/removal.zig"),
    @import("lib/animation/presets.zig"),
    @import("lib/configure/motion.zig"),
    @import("lib/configure/visual.zig"),
    @import("lib/configure/layout.zig"),
    @import("lib/text_field/style.zig"),
    @import("lib/text_field/attributes.zig"),
    @import("lib/text_field/events.zig"),
    @import("lib/text_field/value.zig"),
    @import("lib/builder/tree.zig"),
    @import("lib/builder/elements.zig"),
    @import("lib/builder/style.zig"),
    @import("lib/builder/layout.zig"),
    @import("lib/builder/events.zig"),
    @import("lib/builder/attributes.zig"),
    @import("lib/css/exports.zig"),
    @import("lib/css/background.zig"),
    @import("lib/css/values.zig"),
    @import("lib/css/keyframes.zig"),
    @import("lib/types/style.zig"),
    @import("lib/types/packed.zig"),
    @import("lib/types/sizing.zig"),
    @import("lib/types/box.zig"),
    @import("lib/types/color.zig"),
    @import("lib/types/input.zig"),
    @import("lib/types/background.zig"),
    @import("lib/static_generator.zig"),
    @import("lib/exports.zig"),
    @import("lib/hooks.zig"),
    @import("lib/events.zig"),
    @import("lib/timers.zig"),
    @import("lib/memory.zig"),
    @import("lib/query.zig"),
    @import("lib/hex.zig"),
    @import("lib/log.zig"),
    @import("lib/storage.zig"),
    @import("lib/browser.zig"),
    @import("lib/Writer.zig"),
    @import("lib/constants/Color.zig"),
    @import("lib/style_compiler.zig"),
    @import("lib/kit/json.zig"),
    @import("lib/kit/kit.zig"),
    @import("lib/structures/structures.zig"),
    @import("lib/types.zig"),
    @import("lib/utils.zig"),
};

/// Modules that only build for a host target. They use filesystem access and
/// blocking I/O (`std.Io.Threaded`), which wasm32-freestanding has no
/// implementation for. Checked on the host target only.
const host_only_modules = .{
    @import("lib/File.zig"),
    @import("lib/html_generator.zig"),
};

/// How far to descend into nested public types. Container types nested more
/// deeply than this are only checked if something shallower reaches them.
const max_depth = 4;

/// Takes a reference to every public declaration of `T`, which is what forces
/// the compiler to analyse it, then recurses into public container types.
///
/// Generic functions are skipped: they have no body to analyse until they are
/// instantiated with concrete arguments. Instantiations that matter are pinned
/// explicitly in `instantiations` below.
fn refAll(comptime T: type, comptime depth: usize) void {
    if (depth == 0) return;
    // isOurs walks type names at comptime; large namespaces exceed the default.
    @setEvalBranchQuota(100_000);
    inline for (comptime std.meta.declarations(T)) |decl| {
        const Value = @TypeOf(@field(T, decl.name));

        if (Value == type) {
            const Decl = @field(T, decl.name);
            switch (@typeInfo(Decl)) {
                .@"struct", .@"enum", .@"union", .@"opaque" => {
                    if (comptime isOurs(Decl)) refAll(Decl, depth - 1);
                },
                else => {},
            }
            continue;
        }

        switch (@typeInfo(Value)) {
            // Naming a declaration analyses its type; taking the address of a
            // function is what additionally pulls in its body. A generic or
            // variadic function has no body until it is instantiated.
            .@"fn" => |info| {
                if (info.is_generic or info.is_var_args) {
                    _ = @field(T, decl.name);
                } else {
                    _ = &@field(T, decl.name);
                }
            },
            else => _ = @field(T, decl.name),
        }
    }
}

/// Keeps recursion inside this library. Without it `refAll` walks into `std`
/// through re-exported types and the check takes minutes instead of seconds.
fn isOurs(comptime T: type) bool {
    const name = @typeName(T);
    return std.mem.startsWith(u8, name, "lib.") or
        std.mem.startsWith(u8, name, "root.") or
        std.mem.startsWith(u8, name, "check.");
}

/// Generic entry points that ship as part of the public API. Each needs a
/// concrete instantiation before the compiler will look at its body.
///
/// The element builders — `Box`, `Row`, `Text`, `Button` and the rest of what
/// `root.zig` re-exports — live in `Components.Builder` and
/// `TextField.Builder`. They are the most-used surface in the library, so
/// they are pinned here for every state type the public API exposes.
fn instantiations() void {
    inline for (.{ .pure, .dynamic }) |state_type| {
        refAll(@import("lib/components.zig").Builder(state_type), max_depth);
        refAll(@import("lib/components.zig").Builder(state_type), max_depth);
        refAll(@import("lib/text_field.zig").Builder(state_type), max_depth);
    }

    refAll(@import("lib/array.zig").Array(u8), max_depth);
    refAll(@import("lib/array.zig").BoundedArray(u8, 4), max_depth);
    refAll(@import("lib/structures/structures.zig").RingBuffer(u8, 4), max_depth);
    refAll(@import("lib/structures/structures.zig").BoundedArray(u8, 4), max_depth);
    refAll(@import("lib/abstractions.zig").ManagedMemoryPool(u32), max_depth);
    refAll(@import("lib/abstractions.zig").ManagedAutoHashMap(u32, u32), max_depth);
}

/// Exported so it is always analysed, and with it everything it touches.
/// Never called.
export fn __vapor_check() void {
    inline for (modules) |module| refAll(module, max_depth);
    if (comptime !builtin.target.cpu.arch.isWasm()) {
        inline for (host_only_modules) |module| refAll(module, max_depth);
    }
    instantiations();
}
