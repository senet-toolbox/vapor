const Vapor = @import("Vapor.zig");
const Wasm = @import("WASM.zig");
const std = @import("std");

pub fn printlnErr(
    comptime fmt: []const u8,
    args: anytype,
) void {
    _ = fmt;
    _ = args;
}

pub const LogLevel = enum(u32) {
    err = 0,
    warn = 1,
    info = 2,
    debug = 3,

    fn label(self: LogLevel) []const u8 {
        return switch (self) {
            .err => "ERROR",
            .warn => "WARN",
            .info => "INFO",
            .debug => "DEBUG",
        };
    }

    fn color(self: LogLevel) []const u8 {
        return switch (self) {
            .err => "color: #FF3029;",
            .warn => "color: #FFA629;",
            .info => "color: #4229FF;",
            .debug => "color: #FF29F4;",
        };
    }
};

pub fn print(
    level: LogLevel,
    comptime fmt: []const u8,
    args: anytype,
) void {
    if (!(Vapor.isWasi and Vapor.build_options.enable_debug)) return;
    // var buf: [16 * 1024]u8 = undefined;
    const msg = std.fmt.allocPrint(Vapor.allocator_global, fmt, args) catch return;
    defer Vapor.allocator_global.free(msg);
    // const msg = std.fmt.bufPrint(&buf, fmt, args) catch return;
    printRaw(level, msg);
}

pub fn printRaw(level: LogLevel, msg: []const u8) void {
    // var full_buf: [2048]u8 = undefined;
    const full = std.fmt.allocPrint(Vapor.allocator_global, "[%c{s}%c] {s}", .{ level.label(), msg }) catch return;
    defer Vapor.allocator_global.free(full);
    const style = level.color();
    Vapor.consoleLogWasm(@intFromEnum(level), full.ptr, full.len, style.ptr, style.len);
}

// Convenience wrappers (optional)
pub fn printErr(comptime fmt: []const u8, args: anytype) void {
    print(.err, fmt, args);
}

pub fn printWarn(comptime fmt: []const u8, args: anytype) void {
    print(.warn, fmt, args);
}

pub fn printInfo(comptime fmt: []const u8, args: anytype) void {
    print(.info, fmt, args);
}

pub fn printDebug(comptime fmt: []const u8, args: anytype) void {
    print(.debug, fmt, args);
}

pub fn printlnSrcErr(
    comptime fmt: []const u8,
    args: anytype,
    src: std.builtin.SourceLocation,
) void {
    if (Vapor.isWasi and Vapor.build_options.enable_debug) {
        const buf = std.fmt.allocPrint(Vapor.allocator_global, fmt, args) catch return;
        const buf_with_src = std.fmt.allocPrint(Vapor.allocator_global, "[Vapor] [%cERROR:{s}:{d}%c]\n{s}", .{ src.file, src.line, buf[0..] }) catch return;
        const style_1 = "color: #FF3029;";
        const style_2 = "";
        _ = Wasm.consoleLogColoredWasm(buf_with_src.ptr, buf_with_src.len, style_1[0..].ptr, style_1.len, style_2[0..].ptr, style_2.len);
        Vapor.allocator_global.free(buf_with_src);
        Vapor.allocator_global.free(buf);
    }
}

pub fn printlnWithColor(
    comptime fmt: []const u8,
    args: anytype,
    color: []const u8,
    title: []const u8,
) void {
    _ = fmt;
    _ = args;
    _ = color;
    _ = title;
}

pub fn printlnColor(
    comptime fmt: []const u8,
    args: anytype,
    color: Vapor.Types.Color,
) void {
    _ = fmt;
    _ = args;
    _ = color;
}

pub fn printlnAllocation(
    comptime fmt: []const u8,
    args: anytype,
) void {
    _ = fmt;
    _ = args;
}

pub fn printlnSrc(
    comptime fmt: []const u8,
    args: anytype,
    src: std.builtin.SourceLocation,
) void {
    _ = fmt;
    _ = args;
    _ = src;
}

pub fn println(
    comptime fmt: []const u8,
    args: anytype,
) void {
    if (Vapor.isWasi and Vapor.build_options.enable_debug) {
        const buf = std.fmt.allocPrint(Vapor.allocator_global, fmt, args) catch return;
        _ = Wasm.consoleLogWasm(buf.ptr, buf.len);
        Vapor.allocator_global.free(buf);
    } else if (!Vapor.isWasi) {
        std.debug.print(fmt, args);
    }
}

pub fn alert(comptime fmt: []const u8, args: anytype) void {
    if (Vapor.isWasi) {
        const message = Vapor.fmtln(fmt, args);
        Wasm.alertWasm(message.ptr, message.len);
    }
}

pub fn log(
    comptime level: std.log.Level,
    comptime scope: @EnumLiteral(),
    comptime format: []const u8,
    args: anytype,
) void {
    _ = scope;
    if (Vapor.isWasi and Vapor.build_options.enable_debug) {
        switch (level) {
            .err => _ = printErr(format, args),
            .warn => _ = printWarn(format, args),
            .info => _ = printInfo(format, args),
            .debug => _ = printDebug(format, args),
        }
    } else if (!Vapor.isWasi) {
        std.debug.print(format, args);
    }
}
