//! Navigation and the window's location: moving between pages, reading the
//! current path and query, opening other URLs, scrolling the window.
//!
//! Outside the browser (prerendering, tests) the location is the route being
//! rendered, and `navigate`/`back` are recorded for `Vapor.testing` to follow.

const std = @import("std");
const Vapor = @import("vapor.zig");
const Wasm = Vapor.Wasm;
const isWasi = Vapor.isWasi;

extern fn navigateWasm(path_ptr: [*]const u8, path_len: usize) void;
extern fn backWasm() void;
extern fn routePushWASM(path_ptr: [*]const u8, path_len: usize) void;
extern fn setWindowLocationWasm(url_ptr: [*]const u8, url_len: usize) void;

/// Natively, the last navigation an app asked for, until `Vapor.testing`
/// follows it.
pub const NativeRequest = union(enum) { none, navigate: []const u8, back };
pub var native_request: NativeRequest = .none;
var native_path_buf: [1024]u8 = undefined;

/// Navigates within the app to `path`, without a page load.
pub fn navigate(path: []const u8) void {
    if (isWasi) {
        navigateWasm(path.ptr, path.len);
    } else {
        const len = @min(path.len, native_path_buf.len);
        @memcpy(native_path_buf[0..len], path[0..len]);
        native_request = .{ .navigate = native_path_buf[0..len] };
    }
}

/// Goes back one entry in the browser history.
pub fn back() void {
    if (isWasi) {
        backWasm();
    } else {
        native_request = .back;
    }
}

/// Adds `path` to the browser history without navigating.
pub fn pushPath(path: []const u8) void {
    if (isWasi) routePushWASM(path.ptr, path.len);
}

/// Leaves the app for `url`, with a full page load.
pub fn redirect(url: []const u8) void {
    if (isWasi) setWindowLocationWasm(url.ptr, url.len);
}

/// Opens `url` in a new tab.
pub fn openTab(url: []const u8) void {
    if (isWasi) Wasm.windowOpenWasm(url.ptr, url.len);
}

/// The current URL path, e.g. "/users/42".
pub fn currentPath() []const u8 {
    if (isWasi) return std.mem.span(Wasm.getWindowInformationWasm());
    const prefix = "/root";
    if (!std.mem.startsWith(u8, Vapor.current_route, prefix)) return Vapor.current_route;
    const rest = Vapor.current_route[prefix.len..];
    return if (rest.len == 0) "/" else rest;
}

/// The URL's query string with its leading "?", or `null` if it has none.
pub fn queryString() ?[]const u8 {
    if (!isWasi) return null;
    const query = std.mem.span(Wasm.getWindowParamsWasm());
    return if (query.len == 0) null else query;
}

/// The URL's query parameters, decoded, in frame memory; `null` if there are
/// none.
pub fn queryParams() ?std.StringHashMap([]const u8) {
    const query = queryString() orelse return null;
    return Vapor.Kit.parseParams(query, Vapor.arena(.frame)) catch null;
}

/// The page's origin, e.g. "https://example.com"; empty outside the browser.
pub fn origin() []const u8 {
    if (!isWasi) return "";
    return std.mem.span(Wasm.getWindowOriginWasm());
}

/// Scrolls the window to `x`, `y` pixels.
pub fn scrollTo(x: f32, y: f32) void {
    if (isWasi) Wasm.scrollToWasm(x, y);
}
