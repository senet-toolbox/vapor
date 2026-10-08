//! An app whose wasm imports every binding vapor declares in Vapor.Wasm and
//! Vapor.Browser. The browser refuses to instantiate a module with an import
//! the runtime does not provide, so this page reaching vapor:ready proves
//! every binding is wired into the import object, not merely present in the
//! bundle text (check-abi's guarantee). It also has to pull in
//! browser.min.js to get there.

const std = @import("std");
const Vapor = @import("vapor");

fn countFns(comptime nss: anytype) usize {
    var n: usize = 0;
    for (nss) |ns| {
        for (@typeInfo(ns).@"struct".decls) |decl| {
            if (@typeInfo(@TypeOf(@field(ns, decl.name))) == .@"fn") n += 1;
        }
    }
    return n;
}

const namespaces = .{ Vapor.Wasm, Vapor.Browser };

// Addresses taken into an exported table, so every extern stays an import.
const bindings = blk: {
    @setEvalBranchQuota(100_000);
    var list: [countFns(namespaces)]*const anyopaque = undefined;
    var i: usize = 0;
    for (namespaces) |ns| {
        for (@typeInfo(ns).@"struct".decls) |decl| {
            const value = @field(ns, decl.name);
            if (@typeInfo(@TypeOf(value)) == .@"fn") {
                list[i] = @ptrCast(&value);
                i += 1;
            }
        }
    }
    break :blk list;
};

export fn bindingCount() usize {
    return bindings.len;
}

export fn bindingAddress(i: usize) usize {
    return @intFromPtr(bindings[i]);
}

pub export fn init() void {
    Vapor.init(.{});
    Vapor.Page(.{ .route = "/" }, home, null);
}

fn home() void {
    Vapor.TextFmt("{d} bindings", .{bindings.len}).id("count").end();
}

pub const std_options = std.Options{
    .log_level = .info,
    .logFn = Vapor.lib.log,
};
