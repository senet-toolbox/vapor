//! Compile-only gate for the keystone module, like src/check.zig for vapor:
//! references every public declaration so the compiler type-checks all of it.

const std = @import("std");
const KeyStone = @import("keystone");

/// Takes a reference to every public declaration of `T` and recurses into
/// keystone's own container types. Generic functions are only named; the
/// test suite instantiates the ones apps call.
fn refAll(comptime T: type, comptime depth: usize) void {
    if (depth == 0) return;
    @setEvalBranchQuota(100_000);
    inline for (comptime std.meta.declarations(T)) |decl| {
        const Value = @TypeOf(@field(T, decl.name));
        if (Value == type) {
            const Decl = @field(T, decl.name);
            switch (@typeInfo(Decl)) {
                .@"struct", .@"enum", .@"union", .@"opaque" => {
                    if (comptime std.mem.startsWith(u8, @typeName(Decl), "keystone.")) refAll(Decl, depth - 1);
                },
                else => {},
            }
            continue;
        }
        switch (@typeInfo(Value)) {
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

export fn __keystone_check() void {
    refAll(KeyStone, 4);
}
