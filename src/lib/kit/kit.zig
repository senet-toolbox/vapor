//! Browser helpers: window and URL, navigation, a JSON writer, intersection
//! and resize observers, websockets, timestamps.

const std = @import("std");
const Vapor = @import("../vapor.zig");
const isWasi = Vapor.isWasi;
const Wasm = Vapor.Wasm;
const utils = @import("../utils.zig");
const hashKey = utils.hashKey;
const getUnderlyingType = utils.getUnderlyingType;
const getUnderlyingValue = utils.getUnderlyingValue;
const DynamicObject = @import("../dynamic.zig");
pub const Json = @import("json.zig");

pub const Kit = @This();

/// Current time in seconds since the Unix epoch.
pub fn timestamp() i64 {
    var threaded: std.Io.Threaded = .init_single_threaded;
    const io = threaded.io();
    const ts = std.Io.Timestamp.now(io, .real);
    return ts.toSeconds();
}

/// A millisecond clock for measuring intervals (see `throttle`).
pub fn milliTimestamp() i64 {
    var threaded: std.Io.Threaded = .init_single_threaded;
    const io = threaded.io();
    const ts = std.Io.Timestamp.now(io, .cpu_thread);
    return ts.toMilliseconds();
}

pub const Window = struct {
    /// Opens `url` in a new tab.
    pub fn openTab(url: []const u8) void {
        if (isWasi) {
            Wasm.windowOpenWasm(url.ptr, url.len);
        }
    }

    /// The URL's query string, or `null` if it has none.
    pub fn paramsStr() ?[]const u8 {
        if (isWasi) {
            const _params = getWindowParamsWasm();
            const params_str = std.mem.span(_params);
            if (params_str.len == 0) {
                return null;
            } else {
                return params_str;
            }
        } else {
            return null;
        }
    }

    /// The URL's query parameters as a map (frame memory), or `null`.
    pub fn params() ?std.StringHashMap([]const u8) {
        if (isWasi) {
            const params_str = paramsStr() orelse return null;
            return parseParams(params_str, Vapor.arena(.frame)) catch return null;
        }
        return null;
    }

    /// The page's origin, e.g. "https://example.com".
    pub fn origin() []const u8 {
        if (isWasi) {
            const _origin = Wasm.getWindowOriginWasm();
            const origin_str = std.mem.span(_origin);
            return origin_str;
        } else {
            return "";
        }
    }
    /// The current URL path.
    pub fn path() []const u8 {
        if (isWasi) {
            return std.mem.span(getWindowInformationWasm());
        } else {
            const prefix = "/root";
            if (std.mem.startsWith(u8, Vapor.current_route, prefix)) {
                const rest = Vapor.current_route[prefix.len..];
                return if (rest.len == 0) "/" else rest;
            } else {
                return Vapor.current_route;
            }
        }
    }
};

/// This function takes a slice of json and parses it into a struct
/// # Parameters:
/// - `T`: struct type
/// - `slice`: []const u8,
///
/// # Returns:
/// T: struct
///
/// # Usage:
/// ```zig
/// const my_struct = try Kit.glue(MyStruct, json_slice);
/// ```
/// NOTE: This function dellocates the parsed struct, after use, clone it if you need it beyond the scope of the function
pub fn glue(comptime T: type, slice: []const u8) !T {
    const parsed = std.json.parseFromSlice(
        T,
        Vapor.getFrameAllocator(),
        slice,
        .{},
    ) catch return error.MalformedJson;

    return parsed.value;
}

var last_time: i64 = 0;
/// Returns true if less than `delay` ms passed since the last call that
/// returned false; use it to skip work in rapid-fire handlers.
pub fn throttle(delay: i64) bool {
    const current_time = milliTimestamp();
    if (current_time - last_time < delay) {
        return true;
    }
    last_time = current_time;
    return false;
}

extern fn setWindowLocationWasm(
    url_ptr: [*]const u8,
    url_len: usize,
) void;

/// Navigates the browser to `url` with a full page load.
pub fn setWindowLocation(url: []const u8) void {
    if (isWasi) {
        setWindowLocationWasm(url.ptr, url.len);
    }
}

extern fn navigateWasm(
    path_ptr: [*]const u8,
    path_len: usize,
) void;

/// Navigates within the app to `path`, without a page load.
pub fn navigate(path: []const u8) void {
    if (isWasi) {
        navigateWasm(path.ptr, path.len);
    }
}

extern fn backWasm() void;

/// Goes back one entry in the browser history.
pub fn back() void {
    if (isWasi) {
        backWasm();
    }
}

extern fn routePushWASM(
    path_ptr: [*]const u8,
    path_len: usize,
) void;

/// Adds `path` to the browser history without navigating.
pub fn routePush(path: []const u8) void {
    if (isWasi) {
        routePushWASM(path.ptr, path.len);
    }
}

extern fn getWindowInformationWasm() [*:0]u8;

/// The current URL path, or `null`.
pub fn getWindowPath() ?[]const u8 {
    if (isWasi) {
        return std.mem.span(getWindowInformationWasm());
    } else {
        const prefix = "/root";
        if (std.mem.startsWith(u8, Vapor.current_route, prefix)) {
            const rest = Vapor.current_route[prefix.len..];
            return if (rest.len == 0) "/" else rest;
        } else {
            return Vapor.current_route;
        }
    }
}

extern fn getWindowParamsWasm() [*:0]u8;

/// The URL's query string, or `null` if it has none.
pub fn getWindowParams() ?[]const u8 {
    if (isWasi) {
        const params = getWindowParamsWasm();
        const params_str = std.mem.span(params);
        if (params_str.len == 0) {
            return null;
        } else {
            return params_str;
        }
    } else {
        return null;
    }
}

fn decoder(encoded: []const u8, decoded: *std.array_list.Managed(u8)) !void {
    var i: usize = 0;
    while (i < encoded.len) : (i += 1) {
        if (encoded[i] == '%') {
            // Ensure there's enough room for two hex characters
            if (i + 2 >= encoded.len) {
                return error.InvalidInput;
            }

            const hex = encoded[i + 1 .. i + 3];
            const decodedByte = try std.fmt.parseInt(u8, hex, 16);
            try decoded.append(decodedByte);
            i += 2; // Skip over the two hex characters
        } else if (encoded[i] == '+') {
            // Replace '+' with a space
            try decoded.append(' ');
        } else {
            try decoded.append(encoded[i]);
        }
    }
}

/// Parses the query string of `url` into a map allocated with `allocator`;
/// `null` if it has none.
pub fn parseParams(url: []const u8, allocator: std.mem.Allocator) !?std.StringHashMap([]const u8) {
    const params_start = std.mem.find(u8, url, "?") orelse return null;

    var params = std.StringHashMap([]const u8).init(allocator);
    errdefer {
        // Clean up allocated values on error
        var it = params.valueIterator();
        while (it.next()) |value| {
            allocator.free(value.*);
        }
        params.deinit();
    }

    var pos = params_start + 1;

    while (pos < url.len) {
        // Find end of this pair
        const remaining = url[pos..];
        const param_pair_end = std.mem.find(u8, remaining, "&") orelse remaining.len;
        const pair = remaining[0..param_pair_end];

        if (pair.len == 0) {
            pos += 1;
            continue;
        }

        // Find the separator
        const separator = std.mem.find(u8, pair, "=") orelse return error.SeparatorNotFound;

        const key_encoded = pair[0..separator];
        const value_encoded = pair[separator + 1 ..];

        // Decode key (also needs decoding!)
        var key_decoded = std.array_list.Managed(u8).init(allocator);
        defer key_decoded.deinit();
        try decoder(key_encoded, &key_decoded);
        const key = try key_decoded.toOwnedSlice();
        errdefer allocator.free(key);

        // Decode value
        var value_decoded = std.array_list.Managed(u8).init(allocator);
        defer value_decoded.deinit();
        try decoder(value_encoded, &value_decoded);
        const value = try value_decoded.toOwnedSlice();

        try params.put(key, value);

        pos += param_pair_end + 1; // +1 to skip the '&'
    }

    return params;
}

const Param = struct {
    key: []const u8,
    value: []const u8,
};

/// Scrolls the window to `x`, `y` pixels.
pub fn scrollTo(x: f32, y: f32) void {
    if (isWasi) {
        Wasm.scrollToWasm(x, y);
    }
}

pub const QueryBuilder = struct {
    allocator: std.mem.Allocator,
    params: std.array_list.Managed(Param),
    str: []const u8,

    /// This function takes a pointer to this QueryBuilder instance.
    /// Deinitializes the query builder instance
    /// # Parameters:
    /// - `target`: *QueryBuilder.
    /// - `allocator`: std.mem.Allocator.
    ///
    /// # Returns:
    /// void.
    pub fn init(query_builder: *QueryBuilder, allocator: std.mem.Allocator) !void {
        query_builder.* = .{
            .allocator = allocator,
            .params = std.array_list.Managed(Param).init(allocator),
            .str = "",
        };
    }

    /// This function takes a pointer to this QueryBuilder instance.
    /// Deinitializes the query builder instance, loops over the keys and values to free
    /// # Parameters:
    /// - `target`: *QueryBuilder.
    ///
    /// # Returns:
    /// void.
    pub fn deinit(query_builder: *QueryBuilder) void {
        for (query_builder.params.items) |param| {
            query_builder.allocator.free(param.key);
            query_builder.allocator.free(param.value);
        }
        query_builder.params.deinit();
        if (query_builder.str.len > 0) {
            query_builder.allocator.free(query_builder.str);
        }
    }

    /// This function adds a value and key to the query builder.
    /// # Example
    /// try query.add("client_id", "98f3$j%gw54u4562$");
    ///
    /// # Parameters:
    /// - `key`: []const u8.
    /// - `value`: []const u8.
    ///
    /// # Returns:
    /// void and adds to query builder list.
    pub fn add(query_builder: *QueryBuilder, key: []const u8, value: []const u8) !void {
        const key_dup = try query_builder.allocator.dupe(u8, key);
        const value_dup = try query_builder.allocator.dupe(u8, value);
        try query_builder.params.append(.{ .key = key_dup, .value = value_dup });
    }

    /// This function removes a key.
    /// # Example
    /// try query.remove("client_id");
    ///
    /// # Parameters:
    /// - `key`: []const u8.
    ///
    /// # Returns:
    /// void
    pub fn remove(query_builder: *QueryBuilder, key: []const u8) !void {
        // utils.assert_cm(query_builder.query_param_list.capacity > 0, "QueryBuilder not initilized");
        for (query_builder.params.items, 0..) |query_param, i| {
            if (std.mem.eql(u8, query_param.key, key)) {
                _ = query_builder.params.orderedRemove(i);
                break;
            }
        }
    }

    /// This function encodes the url pass.
    /// # Example
    /// try query.urlEncoder("https://accounts.google.com/o/oauth2/v2/auth");
    ///
    /// # Parameters:
    /// - `url`: []const u8.
    ///
    /// # Returns:
    /// []const u8
    pub fn urlEncoder(query_builder: *QueryBuilder, url: []const u8) ![]const u8 {
        var allocating: std.Io.Writer.Allocating = .init(query_builder.allocator);
        defer allocating.deinit();
        const w = &allocating.writer;

        for (url) |c| {
            switch (c) {
                'a'...'z', 'A'...'Z', '0'...'9', '-', '_', '.', '~' => try w.writeByte(c),
                ' ' => try w.writeAll("%20"),
                else => try w.print("%{X:02}", .{c}),
            }
        }
        return allocating.toOwnedSlice();
    }

    /// This function encodes the query and set query_builder.str.
    /// # Example
    /// try query.queryStrEncode();
    ///
    /// # Returns:
    /// void
    pub fn queryStrEncode(query_builder: *QueryBuilder) !void {
        if (query_builder.params.items.len == 0) {
            query_builder.str = "";
            return;
        }

        var list = std.array_list.Managed(u8).init(query_builder.allocator);
        errdefer list.deinit();

        for (query_builder.params.items, 0..) |param, i| {
            if (i > 0) {
                try list.append('&');
            }

            // URL encode key
            const encoded_key = try query_builder.urlEncoder(param.key);
            defer query_builder.allocator.free(encoded_key);
            try list.appendSlice(encoded_key);

            try list.append('=');

            // URL encode value
            const encoded_value = try query_builder.urlEncoder(param.value);
            defer query_builder.allocator.free(encoded_value);
            try list.appendSlice(encoded_value);
        }

        query_builder.str = try list.toOwnedSlice();
    }

    /// This function generates the queried url plus the precursor url.
    /// # Example
    /// try query.generateUrl("https://accounts.google.com/o/oauth2/v2/auth", query.str);
    ///
    /// # Parameters:
    /// - `base_url`: []const u8.
    /// - `query`: []const u8.
    ///
    /// # Returns:
    /// []const u8
    pub fn generateUrl(query_builder: *QueryBuilder, base_url: []const u8, query: []const u8) ![]const u8 {
        var result = std.array_list.Managed(u8).init(query_builder.allocator);
        errdefer result.deinit();

        try result.appendSlice(base_url);
        if (query.len > 0) {
            try result.append('?');
            try result.appendSlice(query);
        }

        return result.toOwnedSlice();
    }

    // Helper function to get parameters in order
    /// The parameters added so far.
    pub fn getParams(query_builder: *QueryBuilder) []const Param {
        return query_builder.params.items;
    }
};

pub const ObserverOptions = struct {
    threshold: f32 = 0,
    rootMargin_top: i32 = 0,
    rootMargin_right: i32 = 0,
    rootMargin_bottom: i32 = 0,
    rootMargin_left: i32 = 0,
};

/// Observer is a struct that allows you to observe the visibility of an element
/// and call a callback when the element becomes visible or invisible
/// # Parameters:
/// - `name`: []const u8,
/// - `callback`: anytype,
/// - `options`: ObserverOptions,
///
/// # Returns:
/// Observer
///
/// # Usage:
/// ```zig
/// const observer = Kit.Observer.new("my_observer", onObserver, .{ .threshold = 0.5 });
///
/// fn onObserver(target: Observer.Target) void {
///     const target: Observer.Target = target;
///     _ = target;
/// }
/// ``` NOTE: This function dellocates, after use, clone the fields if need them outsside the handler function
/// # Example:
/// ```zig
/// const observer = Kit.Observer.new("my_observer", onObserver, .{ .threshold = 0.5 });
///
/// var target_link: []const u8 = "";
/// fn onObserver(target: Observer.Target) void {
///     const target: Observer.Target = target;
///     target_link = Vapor.clone(target.url);
/// }
/// ```
pub const Observer = struct {
    pub const Target = struct {
        url: []const u8,
        is_in_view: bool,
        index: usize,
    };
    name: []const u8,
    callback: *const fn (Target) void,
    oberver_nodes: std.array_list.Managed(Vapor.ObserverNode),

    /// An IntersectionObserver named `name` that calls `callback` when an observed
    /// element enters or leaves the viewport.
    pub fn new(name: []const u8, callback: fn (Target) void, options: ObserverOptions) Observer {
        const Closure = struct {
            run_node: Vapor.Node = .{ .data = .{ .runFn = runFn, .deinitFn = deinitFn } },
            fn runFn(action: *Vapor.Action) void {
                const run_node: *Vapor.Node = @fieldParentPtr("data", action);
                const object = run_node.data.dynamic_object orelse {
                    Vapor.report.err("Bridge: Observer callback called without object, this is a js side issue", .{});
                    Vapor.report.err("No object found", .{});
                    return;
                };
                const target: Target = DynamicObject.convertFromDynamicToType(Target, object);
                @call(.auto, callback, .{target});
            }
            fn deinitFn(_: *Vapor.Node) void {}
        };

        const closure = Vapor.arena(.persist).create(Closure) catch |err| {
            Vapor.report.err("could not create closure: {any}", .{err});
            @panic("vapor: Error could not create closure");
        };
        closure.* = .{};

        const hash = hashKey(name);
        Vapor.ctx_callback_registry.put(hash, &closure.run_node) catch |err| {
            Vapor.report.err("Button Function Registry {any}", .{err});
        };

        if (isWasi) {
            Wasm.createObserverWasm(hash, &options);
        }

        return Observer{
            .name = name,
            .callback = callback,
            .oberver_nodes = std.array_list.Managed(Vapor.ObserverNode).init(Vapor.arena(.persist)),
        };
    }

    /// Stops observing every element, keeping the observer.
    pub fn disconnect(self: *Observer) void {
        if (!isWasi) return;
        const hash = hashKey(self.name);
        Wasm.reinitObserverWasm(hash);
    }

    /// Removes the observer named `name`.
    pub fn destroy(name: []const u8) void {
        if (!isWasi) return;
        Wasm.destroyObserverWasm(name.ptr, name.len);
    }

    /// Starts observing `item`.
    pub fn observe(self: *Observer, item: Vapor.ObserverNode, index: ?usize) void {
        if (!isWasi) return;
        self.oberver_nodes.append(item) catch |err| {
            Vapor.report.err("observe: could not record node, not observed: {any}", .{err});
            return;
        };
        const hash = hashKey(self.name);
        switch (item) {
            .uuid => |uuid| {
                Wasm.observeWasm(hash, uuid.ptr, uuid.len, index orelse 0);
            },
            .type => |element_type| {
                const element_type_str = @tagName(element_type);
                Wasm.observeWasm(hash, element_type_str.ptr, element_type_str.len, index orelse 0);
            },
        }
    }
};

const ObserverExport = DynamicObject.exportStruct(ObserverOptions);

// --- THE EXPORTS ---
// Everything inside here gets auto-exported to JS
pub const API = struct {
    /// Internal: runs a `registerHook` callback for a navigation.
    pub fn hookInstCallback(id: u32) callconv(.c) void {
        const hook_cb = Vapor.hooks_inst_callbacks.get(id).?;
        const params_str = Kit.getWindowParams() orelse "";
        const path = Kit.getWindowPath() orelse {
            Vapor.report.err("Hooks ERROR: Could not get window path", .{});
            return;
        };
        var params = std.StringHashMap([]const u8).init(Vapor.arena(.frame));
        if (params_str.len != 0) {
            params = Kit.parseParams(params_str, Vapor.arena(.frame)) catch return orelse return;
        }
        const context = Vapor.HookContext{
            .from_path = "",
            .to_path = path,
            .params = params,
            .query = params,
        };
        @call(.auto, hook_cb, .{context});
    }

    /// Internal: exposes observer options to the JS runtime.
    pub fn getObserverOptions(options: *ObserverOptions) callconv(.c) [*]const u8 {
        ObserverExport.init();
        ObserverExport.instance = options.*;
        return ObserverExport.getInstancePtr();
    }

    /// Internal: field count of the observer options layout.
    pub fn getObserverFieldCount() callconv(.c) u32 {
        return ObserverExport.getFieldCount();
    }

    /// Internal: one field of the observer options layout.
    pub fn getObserverFieldDescriptor(index: u32) callconv(.c) ?*const DynamicObject.FieldDescriptor() {
        return ObserverExport.getFieldDescriptor(index);
    }

    /// Internal: number of elements an observer watches.
    pub fn getObserverNodeCount(observer_name: [*:0]u8) callconv(.c) usize {
        const name = std.mem.span(observer_name);
        const nodes = Vapor.observer_nodes.get(name) orelse return 0;
        return nodes.items.len;
    }

    /// Internal: id of the `index`-th element an observer watches.
    pub fn getObserverNode(observer_name: [*:0]u8, index: usize) callconv(.c) ?[*]const u8 {
        const name = std.mem.span(observer_name);
        const nodes = Vapor.observer_nodes.get(name) orelse return null;
        const node = nodes.items[index];
        return node.uuid.ptr;
    }

    /// Internal: length of that id.
    pub fn getObserverNodeLength(observer_name: [*:0]u8, index: usize) callconv(.c) usize {
        const name = std.mem.span(observer_name);
        const nodes = Vapor.observer_nodes.get(name) orelse return 0;
        const node = nodes.items[index];
        return node.uuid.len;
    }

    /// Internal: exposes resize observer options to the JS runtime.
    pub fn getResizeOptions(options: *ResizeOptions) callconv(.c) [*]const u8 {
        ResizeOptionsExport.init();
        ResizeOptionsExport.instance = options.*;
        return ResizeOptionsExport.getInstancePtr();
    }

    /// Internal: field count of the resize options layout.
    pub fn getResizeOptionsFieldCount() callconv(.c) u32 {
        return ResizeOptionsExport.getFieldCount();
    }

    /// Internal: one field of the resize options layout.
    pub fn getResizeOptionsFieldDescriptor(index: u32) callconv(.c) ?*const DynamicObject.FieldDescriptor() {
        return ResizeOptionsExport.getFieldDescriptor(index);
    }
};

///////////////////////////////////////////////////////////////////////////////////////////////////
/// RESIZE
///////////////////////////////////////////////////////////////////////////////////////////////////

pub const ResizeBox = enum(u8) {
    content_box = 0,
    border_box = 1,
    device_pixel_content_box = 2,
};

pub const ResizeOptions = struct {
    box: ResizeBox = .content_box,
};

pub const ResizeEntry = struct {
    /// Width of the border box (CSS pixels)
    width: f32,
    /// Height of the border box
    height: f32,
    /// Width of the content box (excludes padding/border)
    content_width: f32,
    /// Content box height
    content_height: f32,
    /// Optional index (for users observing many elements via the primitive)
    index: usize,
};

pub var global_resizer: ?ResizeObserver = undefined;

fn globalResizeCallback(_: ResizeEntry) void {
    Vapor.report.info("Resized code container", .{});
}

/// The shared ResizeObserver behind `.onResize`.
pub fn defaultResizeObserver() *ResizeObserver {
    if (global_resizer) |*resizer| return resizer;
    const resizer = ResizeObserver.new("vapor_global_resizer", globalResizeCallback, .{});
    global_resizer = resizer;
    return &global_resizer.?;
}

const ResizeOptionsExport = DynamicObject.exportStruct(ResizeOptions);

pub const ResizeCallback = struct {
    ctx: *anyopaque,
    callFn: *const fn (*anyopaque, *DynamicObject.DynamicObject) void,
    dynamic_object: ?*DynamicObject = null,

    /// Internal: runs the stored callback with a resize entry.
    pub fn call(self: *const ResizeCallback, entry: *DynamicObject.DynamicObject) void {
        self.callFn(self.ctx, entry);
    }

    /// Internal: wraps `cb` and `args` as a resize callback.
    pub fn make(allocator: std.mem.Allocator, cb: anytype, args: anytype) !ResizeCallback {
        const Args = @TypeOf(args);

        const Closure = struct {
            arguments: Args,

            fn run(ptr: *anyopaque, dyn_obj: *DynamicObject.DynamicObject) void {
                const self: *@This() = @ptrCast(@alignCast(ptr));
                // cb is comptime-captured, append entry to the args
                const entry: ResizeEntry = DynamicObject.convertFromDynamicToType(ResizeEntry, dyn_obj);
                @call(.auto, cb, self.arguments ++ .{entry});
            }
        };

        const closure = try allocator.create(Closure);
        closure.* = .{ .arguments = args };

        return .{
            .ctx = @ptrCast(closure),
            .callFn = Closure.run,
        };
    }
};

pub const ResizeObserver = struct {
    pub const Entry = ResizeEntry;

    name: []const u8,
    callback: *const fn (Entry) void,
    observer_nodes: std.array_list.Managed(Vapor.ObserverNode),

    /// A ResizeObserver named `name` that calls `callback` with each size change.
    pub fn new(name: []const u8, callback: fn (Entry) void, options: ResizeOptions) ResizeObserver {
        const Closure = struct {
            run_node: Vapor.Node = .{ .data = .{ .runFn = runFn, .deinitFn = deinitFn } },
            fn runFn(action: *Vapor.Action) void {
                const run_node: *Vapor.Node = @fieldParentPtr("data", action);
                const object = run_node.data.dynamic_object orelse {
                    Vapor.report.err("ResizeObserver callback called without object", .{});
                    return;
                };
                const entry: Entry = DynamicObject.convertFromDynamicToType(Entry, object);
                @call(.auto, callback, .{entry});
            }
            fn deinitFn(_: *Vapor.Node) void {}
        };

        const closure = Vapor.arena(.persist).create(Closure) catch |err| {
            Vapor.report.err("ResizeObserver: allocation failed: {any}", .{err});
            @panic("vapor: out of memory creating a ResizeObserver");
        };
        closure.* = .{};

        const hash = hashKey(name);
        Vapor.ctx_callback_registry.put(hash, &closure.run_node) catch |err| {
            Vapor.report.err("ResizeObserver registry error {any}", .{err});
        };

        if (isWasi) {
            Wasm.createResizeObserverWasm(hash, &options);
        }

        return ResizeObserver{
            .name = name,
            .callback = callback,
            .observer_nodes = std.array_list.Managed(Vapor.ObserverNode).init(Vapor.arena(.persist)),
        };
    }

    /// Internal: observes `item`, reporting to the callback registered under
    /// `callback_hash`.
    pub fn observeWithCallback(self: *ResizeObserver, item: Vapor.ObserverNode, callback_hash: ?u32) void {
        if (!isWasi) return;
        self.observer_nodes.append(item) catch |err| {
            Vapor.report.err("observe: could not record node, not observed: {any}", .{err});
            return;
        };
        const hash = hashKey(self.name);
        switch (item) {
            .uuid => |uuid| {
                Wasm.observeResizeWasm(hash, uuid.ptr, uuid.len, callback_hash orelse 0);
            },
            .type => |element_type| {
                const tag = @tagName(element_type);
                Wasm.observeResizeWasm(hash, tag.ptr, tag.len, callback_hash orelse 0);
            },
        }
    }

    /// Starts observing `item`.
    pub fn observe(self: *ResizeObserver, item: Vapor.ObserverNode, index: ?usize) void {
        if (!isWasi) return;
        self.observer_nodes.append(item) catch |err| {
            Vapor.report.err("observe: could not record node, not observed: {any}", .{err});
            return;
        };
        const hash = hashKey(self.name);
        switch (item) {
            .uuid => |uuid| {
                Wasm.observeResizeWasm(hash, uuid.ptr, uuid.len, index orelse 0);
            },
            .type => |element_type| {
                const tag = @tagName(element_type);
                Wasm.observeResizeWasm(hash, tag.ptr, tag.len, index orelse 0);
            },
        }
    }

    /// Stops observing the element `uuid`.
    pub fn unobserve(self: *ResizeObserver, uuid: []const u8) void {
        if (!isWasi) return;
        const hash = hashKey(self.name);
        Wasm.unobserveResizeWasm(hash, uuid.ptr, uuid.len);
    }

    /// Stops observing every element, keeping the observer.
    pub fn disconnect(self: *ResizeObserver) void {
        if (!isWasi) return;
        const hash = hashKey(self.name);
        Wasm.disconnectResizeObserverWasm(hash);
    }

    /// Removes the resize observer named `name`.
    pub fn destroy(name: []const u8) void {
        if (!isWasi) return;
        // The JS side keys observers by name hash, same as `disconnect`.
        Wasm.destroyResizeObserverWasm(hashKey(name));
    }
};

// 1. This variable will hold our list of names.
// It is calculated at compile-time but stored in the binary for runtime use.

const WssOptions = struct {
    key: []const u8,
    query: []const u8,
    port: u16 = 8080,
    on_connection: ?*const fn () void = undefined,
    on_message: ?*const fn (msg: []const u8) void = undefined,
    on_close: ?*const fn () void = undefined,
};

extern fn createWss(
    port: u16,
    id: u32,
    query: [*]const u8,
    query_len: u32,
) void;

extern fn sendWss(
    id: u32,
    msg: [*]const u8,
    msg_len: u32,
) void;

var wss_callbacks: ?std.AutoHashMap(u32, WssOptions) = null;

pub const Wss = struct {
    id: u32,
    /// Sends `msg` over the websocket.
    pub fn send(wss: *const Wss, msg: []const u8) void {
        if (!isWasi) return;
        sendWss(wss.id, msg.ptr, msg.len);
    }
};

/// Opens a websocket to this host on `wss_options.port`, with the given
/// callbacks. Fails outside the browser.
pub fn useWss(wss_options: WssOptions) !Wss {
    if (!isWasi) return error.WasiOnly;
    if (wss_callbacks == null) {
        wss_callbacks = std.AutoHashMap(u32, WssOptions).init(Vapor.arena(.persist));
        const key = utils.hashKey(wss_options.key);
        wss_callbacks.?.put(key, wss_options) catch |err| {
            Vapor.report.err("Error adding wss options {any}", .{err});
            return error.CouldNotAddWssOptions;
        };
        createWss(wss_options.port, key, wss_options.query.ptr, wss_options.query.len);
        return Wss{
            .id = key,
        };
    } else if (wss_callbacks) |*callbacks| {
        const key = utils.hashKey(wss_options.key);
        callbacks.put(key, wss_options) catch |err| {
            Vapor.report.err("Error adding wss options {any}", .{err});
            return error.CouldNotAddWssOptions;
        };
        createWss(wss_options.port, key, wss_options.query.ptr, wss_options.query.len);
        return Wss{
            .id = key,
        };
    }
    return error.CouldNotAddWssOptions;
}

export fn onWssConnection(id: u32) void {
    if (wss_callbacks) |callbacks| {
        const wss_ops = callbacks.get(id) orelse {
            Vapor.report.err("Error getting wss options {any}", .{error.CouldNotGetWssCallbacks});
            return;
        };
        if (wss_ops.on_connection) |cb| {
            cb();
            if (Vapor.mode == .atomic) {
                Vapor.cycle();
            }
        }
    }
}
export fn onWssMessage(id: u32, msg_nullterm: [*:0]u8) void {
    const msg = std.mem.span(msg_nullterm);
    if (wss_callbacks) |callbacks| {
        const wss_ops = callbacks.get(id) orelse {
            Vapor.report.err("Error getting wss options {any}", .{error.CouldNotGetWssCallbacks});
            return;
        };
        if (wss_ops.on_message) |cb| {
            cb(msg);
            if (Vapor.mode == .atomic) {
                Vapor.cycle();
            }
        }
    }
}

export fn onWssClose(id: u32) void {
    if (wss_callbacks) |callbacks| {
        const wss_ops = callbacks.get(id) orelse {
            Vapor.report.err("Error getting wss options {any}", .{error.CouldNotGetWssCallbacks});
            return;
        };
        if (wss_ops.on_close) |cb| {
            cb();
        }
    }
}

// --- Auto-Export Magic ---
// This runs automatically when this file is imported
comptime {
    const decls = std.meta.declarations(API);

    for (decls) |decl| {
        const val = @field(API, decl.name);
        const Type = @TypeOf(val);
        if (@typeInfo(Type) == .@"fn") {
            // Export it with its own name
            @export(&val, .{ .name = decl.name });
        }
    }
}
