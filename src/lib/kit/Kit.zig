const std = @import("std");
const Vapor = @import("../Vapor.zig");
const isWasi = Vapor.isWasi;
const Wasm = Vapor.Wasm;
const utils = @import("../utils.zig");
const hashKey = utils.hashKey;
const getUnderlyingType = utils.getUnderlyingType;
const getUnderlyingValue = utils.getUnderlyingValue;
const DynamicObject = @import("../Dynamic.zig");
pub const Json = @import("JSON.zig");

// The HTTP layer moved into Fetch.zig; these keep `Kit.Fetch` / `Kit.Response`
// working for callers such as KeyStone.
// HTTP types moved to Fetch.zig; these names are kept so existing code builds.
const FetchModule = @import("../Fetch.zig");
pub const Response = FetchModule.Result;
pub const HttpReq = FetchModule.Options;
pub const Headers = FetchModule.Headers;
pub const HttpHeader = FetchModule.Header;
pub const Methods = FetchModule.Method;

pub const Kit = @This();

pub fn timestamp() i64 {
    var threaded: std.Io.Threaded = .init_single_threaded;
    const io = threaded.io();
    const ts = std.Io.Timestamp.now(io, .real);
    return ts.toSeconds();
}

pub fn milliTimestamp() i64 {
    var threaded: std.Io.Threaded = .init_single_threaded;
    const io = threaded.io();
    const ts = std.Io.Timestamp.now(io, .cpu_thread);
    return ts.toMilliseconds();
}

pub const Window = struct {
    pub fn openTab(url: []const u8) void {
        if (isWasi) {
            Wasm.windowOpenWasm(url.ptr, url.len);
        }
    }

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
            Vapor.printlnSrc("Attempted to get params, but not wasi", .{}, @src());
            return null;
        }
    }

    pub fn params() ?std.StringHashMap([]const u8) {
        if (isWasi) {
            const params_str = paramsStr() orelse return null;
            return parseParams(params_str, Vapor.arena(.frame)) catch return null;
        }
        return null;
    }

    pub fn origin() []const u8 {
        if (isWasi) {
            const _origin = Wasm.getWindowOriginWasm();
            const origin_str = std.mem.span(_origin);
            return origin_str;
        } else {
            Vapor.printlnSrc("Attempted to get origin, but not wasi", .{}, @src());
            return "";
        }
    }
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

pub const String = struct {
    start: usize,
    len: usize,
    capacity: usize,
    contents: [65535]u8 = undefined,

    pub fn new() String {
        return String{
            .start = 0,
            .len = 0,
            .capacity = 65535,
        };
    }

    pub fn init(initial: []const u8) String {
        var new_string = String.new();
        new_string.append_str(initial);
        return new_string;
    }

    pub fn append_str(self: *String, input: []const u8) void {
        const required_len = self.len + input.len;
        const required_capacity = required_len + (10 - required_len % 10);

        // Case 1: contents exists and is big enough
        if (required_capacity <= self.capacity) {
            @memcpy(self.contents[self.len .. self.len + input.len], input);
            self.len = required_len;
        }
    }
};

pub fn fastJson(comptime T: type, data: T, writer: *String) !void {
    const fields = @typeInfo(T).@"struct".fields;
    writer.append_str("{");
    inline for (fields, 0..) |f, j| {
        const field_value_optional = @field(data, f.name);
        const is_optional = @typeInfo(f.type) == .optional;
        const field_type: type = getUnderlyingType(@TypeOf(field_value_optional));
        if (!is_optional or (is_optional and field_value_optional != null)) {
            const field_value = getUnderlyingValue(field_type, @TypeOf(field_value_optional), field_value_optional);
            writer.append_str("\"");
            writer.append_str(f.name);
            writer.append_str("\"");
            writer.append_str(": ");
            switch (field_type) {
                i8, i16, i32, i64, i128, f16, f32, f64, f128 => {
                    const max_len = 20;
                    var buf: [max_len]u8 = undefined;
                    const value = try std.fmt.bufPrint(&buf, "{any}", .{field_value});
                    writer.append_str(value);
                },
                bool => {
                    if (field_value) {
                        writer.append_str("true");
                    } else {
                        writer.append_str("false");
                    }
                },
                [][]const u8, []const []const u8 => {
                    writer.append_str("[");
                    for (field_value, 0..) |e, i| {
                        writer.append_str("\"");
                        writer.append_str(e);
                        writer.append_str("\"");
                        if (i < field_value.len - 1) writer.append_str(",");
                    }
                    writer.append_str("]");
                },
                []i8, []i16, []i32, []i64, []i128, []f16, []f32, []f64, []f128 => {
                    writer.append_str("[");
                    for (field_value, 0..) |e, i| {
                        const max_len = 4;
                        var buf: [max_len]u8 = undefined;
                        const value = try std.fmt.bufPrint(&buf, "{any}", .{e});
                        writer.append_str(value);
                        if (i > 0) writer.append_str(",");
                    }
                    writer.append_str("]");
                },
                []const u8 => {
                    writer.append_str("\"");
                    writer.append_str(field_value);
                    writer.append_str("\"");
                },
                else => {
                    switch (@typeInfo(field_type)) {
                        .@"struct" => {
                            var inner_writer = String.new();
                            try fastJson(field_type, field_value, &inner_writer);
                            const payload = inner_writer.contents[0..inner_writer.len];
                            writer.append_str(payload);
                        },
                        else => {},
                    }
                },
            }
            if (j < fields.len - 1) writer.append_str(", ");
        }
    }
    writer.append_str("}");
}

var last_time: i64 = 0;
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

pub fn setWindowLocation(url: []const u8) void {
    if (isWasi) {
        setWindowLocationWasm(url.ptr, url.len);
    } else {
        Vapor.printlnSrc("Attempted to reroute, but not wasi {s}", .{url}, @src());
    }
}

extern fn navigateWasm(
    path_ptr: [*]const u8,
    path_len: usize,
) void;

pub fn navigate(path: []const u8) void {
    if (isWasi) {
        navigateWasm(path.ptr, path.len);
    } else {
        Vapor.printlnSrc("Attempted to reroute, but not wasi {s}", .{path}, @src());
    }
}

extern fn backWasm() void;

pub fn back() void {
    if (isWasi) {
        backWasm();
    } else {
        Vapor.printlnSrc("Attempted to reroute, but not wasi", .{}, @src());
    }
}

extern fn routePushWASM(
    path_ptr: [*]const u8,
    path_len: usize,
) void;

pub fn routePush(path: []const u8) void {
    if (isWasi) {
        routePushWASM(path.ptr, path.len);
    } else {
        Vapor.printlnSrc("Attempted to reroute, but not wasi {s}", .{path}, @src());
    }
}

extern fn getWindowInformationWasm() [*:0]u8;

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
        Vapor.printlnSrc("Attempted to get params, but not wasi", .{}, @src());
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
        const seperator = std.mem.find(u8, pair, "=") orelse return error.SeperatorNotFound;

        const key_encoded = pair[0..seperator];
        const value_encoded = pair[seperator + 1 ..];

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

// Field type enum that JS can understand
pub const FieldType = enum(u8) {
    u8_type,
    i8_type,
    u16_type,
    i16_type,
    u32_type,
    i32_type,
    u64_type,
    i64_type,
    f32_type,
    f64_type,
    bool_type,
    string_type, // ptr + len pair
};

// Schema field descriptor
pub const FieldDescriptor = packed struct {
    field_type: FieldType,
    offset: u32,
    name_ptr: usize,
    name_len: usize,
};

// Generic schema generator
pub fn StructSchema(comptime T: type) type {
    return struct {
        pub var fields: []FieldDescriptor = undefined;
        pub fn init() void {
            const type_info = @typeInfo(T);
            if (type_info != .@"struct") {
                @compileError("StructSchema only works with struct types");
            }

            const struct_fields = type_info.@"struct".fields;
            fields = Vapor.arena(.persist).alloc(FieldDescriptor, struct_fields.len) catch |err| {
                Vapor.printlnErr("StructSchema: allocation failed: {any}", .{err});
                @panic("vapor: out of memory building a struct schema");
            };

            inline for (struct_fields, 0..) |field, i| {
                const field_type = mapZigTypeToFieldType(field.type);
                // Vapor.print("Field {s} type {d} {any} {any}\n", .{ field.name, field_type, @offsetOf(T, field.name), @intFromPtr(field.name.ptr) });
                fields[i] = FieldDescriptor{
                    .field_type = field_type,
                    .offset = @offsetOf(T, field.name),
                    .name_ptr = @intFromPtr(field.name.ptr),
                    .name_len = field.name.len,
                };
            }
        }

        pub fn getSchema() []FieldDescriptor {
            return fields;
        }

        pub fn getSchemaLength() usize {
            return fields.len;
        }
    };
}

fn mapZigTypeToFieldType(comptime T: type) FieldType {
    return switch (T) {
        u8 => .u8_type,
        i8 => .i8_type,
        u16 => .u16_type,
        i16 => .i16_type,
        u32 => .u32_type,
        i32 => .i32_type,
        u64 => .u64_type,
        i64 => .i64_type,
        f32 => .f32_type,
        f64 => .f64_type,
        bool => .bool_type,
        else => blk: {
            // Check if it's a string type (ptr + len)
            const type_info = @typeInfo(T);
            if (type_info == .Pointer) {
                break :blk .string_type;
            }
            @compileError("Unsupported type: " ++ @typeName(T));
        },
    };
}

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

    pub fn new(name: []const u8, callback: fn (Target) void, options: ObserverOptions) Observer {
        const Closure = struct {
            run_node: Vapor.Node = .{ .data = .{ .runFn = runFn, .deinitFn = deinitFn } },
            fn runFn(action: *Vapor.Action) void {
                const run_node: *Vapor.Node = @fieldParentPtr("data", action);
                const object = run_node.data.dynamic_object orelse {
                    Vapor.printlnSrcErr("Bridge: Observer callback called without object, this is a js side issue", .{}, @src());
                    Vapor.printlnSrcErr("No object found", .{}, @src());
                    return;
                };
                const target: Target = DynamicObject.convertFromDynamicToType(Target, object);
                @call(.auto, callback, .{target});
            }
            fn deinitFn(_: *Vapor.Node) void {}
        };

        const closure = Vapor.arena(.persist).create(Closure) catch |err| {
            Vapor.println("Error could not create closure {any}\n ", .{err});
            @panic("vapor: Error could not create closure");
        };
        closure.* = .{};

        const hash = hashKey(name);
        Vapor.ctx_callback_registry.put(hash, &closure.run_node) catch |err| {
            Vapor.println("Button Function Registry {any}\n", .{err});
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

    pub fn disconnect(self: *Observer) void {
        if (!isWasi) return;
        const hash = hashKey(self.name);
        Wasm.reinitObserverWasm(hash);
    }

    pub fn destroy(name: []const u8) void {
        if (!isWasi) return;
        Wasm.destroyObserverWasm(name.ptr, name.len);
    }

    pub fn observe(self: *Observer, item: Vapor.ObserverNode, index: ?usize) void {
        if (!isWasi) return;
        self.oberver_nodes.append(item) catch |err| {
            Vapor.printlnErr("observe: could not record node, not observed: {any}", .{err});
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
    pub fn hookInstCallback(id: u32) callconv(.c) void {
        const hook_cb = Vapor.hooks_inst_callbacks.get(id).?;
        const params_str = Kit.getWindowParams() orelse "";
        const path = Kit.getWindowPath() orelse {
            Vapor.printlnSrcErr("Hooks ERROR: Could not get window path", .{}, @src());
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

    pub fn getObserverOptions(options: *ObserverOptions) callconv(.c) [*]const u8 {
        ObserverExport.init();
        ObserverExport.instance = options.*;
        return ObserverExport.getInstancePtr();
    }

    pub fn getObserverFieldCount() callconv(.c) u32 {
        return ObserverExport.getFieldCount();
    }

    pub fn getObserverFieldDescriptor(index: u32) callconv(.c) ?*const DynamicObject.FieldDescriptor() {
        return ObserverExport.getFieldDescriptor(index);
    }

    pub fn getObserverNodeCount(observer_name: [*:0]u8) callconv(.c) usize {
        const name = std.mem.span(observer_name);
        const nodes = Vapor.observer_nodes.get(name) orelse return 0;
        return nodes.items.len;
    }

    pub fn getObserverNode(observer_name: [*:0]u8, index: usize) callconv(.c) ?[*]const u8 {
        const name = std.mem.span(observer_name);
        const nodes = Vapor.observer_nodes.get(name) orelse return null;
        const node = nodes.items[index];
        return node.uuid.ptr;
    }

    pub fn getObserverNodeLength(observer_name: [*:0]u8, index: usize) callconv(.c) usize {
        const name = std.mem.span(observer_name);
        const nodes = Vapor.observer_nodes.get(name) orelse return 0;
        const node = nodes.items[index];
        return node.uuid.len;
    }

    pub fn getResizeOptions(options: *ResizeOptions) callconv(.c) [*]const u8 {
        ResizeOptionsExport.init();
        ResizeOptionsExport.instance = options.*;
        return ResizeOptionsExport.getInstancePtr();
    }

    pub fn getResizeOptionsFieldCount() callconv(.c) u32 {
        return ResizeOptionsExport.getFieldCount();
    }

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
    std.log.info("Resized code container", .{});
}

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

    pub fn call(self: *const ResizeCallback, entry: *DynamicObject.DynamicObject) void {
        self.callFn(self.ctx, entry);
    }

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

    pub fn new(name: []const u8, callback: fn (Entry) void, options: ResizeOptions) ResizeObserver {
        const Closure = struct {
            run_node: Vapor.Node = .{ .data = .{ .runFn = runFn, .deinitFn = deinitFn } },
            fn runFn(action: *Vapor.Action) void {
                const run_node: *Vapor.Node = @fieldParentPtr("data", action);
                const object = run_node.data.dynamic_object orelse {
                    Vapor.printlnSrcErr("ResizeObserver callback called without object", .{}, @src());
                    return;
                };
                const entry: Entry = DynamicObject.convertFromDynamicToType(Entry, object);
                @call(.auto, callback, .{entry});
            }
            fn deinitFn(_: *Vapor.Node) void {}
        };

        const closure = Vapor.arena(.persist).create(Closure) catch |err| {
            Vapor.printlnErr("ResizeObserver: allocation failed: {any}", .{err});
            @panic("vapor: out of memory creating a ResizeObserver");
        };
        closure.* = .{};

        const hash = hashKey(name);
        Vapor.ctx_callback_registry.put(hash, &closure.run_node) catch |err| {
            Vapor.println("ResizeObserver registry error {any}\n", .{err});
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

    pub fn observeWithCallback(self: *ResizeObserver, item: Vapor.ObserverNode, callback_hash: ?u32) void {
        if (!isWasi) return;
        self.observer_nodes.append(item) catch |err| {
            Vapor.printlnErr("observe: could not record node, not observed: {any}", .{err});
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

    pub fn observe(self: *ResizeObserver, item: Vapor.ObserverNode, index: ?usize) void {
        if (!isWasi) return;
        self.observer_nodes.append(item) catch |err| {
            Vapor.printlnErr("observe: could not record node, not observed: {any}", .{err});
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

    pub fn unobserve(self: *ResizeObserver, uuid: []const u8) void {
        if (!isWasi) return;
        const hash = hashKey(self.name);
        Wasm.unobserveResizeWasm(hash, uuid.ptr, uuid.len);
    }

    pub fn disconnect(self: *ResizeObserver) void {
        if (!isWasi) return;
        const hash = hashKey(self.name);
        Wasm.disconnectResizeObserverWasm(hash);
    }

    pub fn destroy(name: []const u8) void {
        if (!isWasi) return;
        // The JS side keys observers by name hash, same as `disconnect`.
        Wasm.destroyResizeObserverWasm(hashKey(name));
    }
};

// 1. This variable will hold our list of names.
// It is calculated at compile-time but stored in the binary for runtime use.
const export_names = blk: {
    const decls = @typeInfo(API).@"struct".decls;

    // We need to count valid exports first to know the array size
    var count = 0;
    for (decls) |decl| {
        // if (std.ascii.startsWithIgnoreCase(decl.name, "export")) {
        const val = @field(API, decl.name);
        if (@typeInfo(@TypeOf(val)) == .@"fn") {
            count += 1;
        }
        // }
    }

    // Create the array with the exact size needed
    var names: [count][]const u8 = undefined;
    var i = 0;

    // Fill the array
    for (decls) |decl| {
        // if (std.ascii.startsWithIgnoreCase(decl.name, "export")) {
        const val = @field(API, decl.name);
        if (@typeInfo(@TypeOf(val)) == .@"fn") {
            names[i] = decl.name;
            i += 1;

            // Do the actual export here too!
            // @export(val, .{ .name = decl.name });
        }
        // }
    }

    // Return the final array to be stored in 'export_names'
    break :blk names;
};

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
    pub fn send(wss: *const Wss, msg: []const u8) void {
        if (!isWasi) return;
        sendWss(wss.id, msg.ptr, msg.len);
    }
};

pub fn useWss(wss_options: WssOptions) !Wss {
    if (!isWasi) return error.WasiOnly;
    if (wss_callbacks == null) {
        wss_callbacks = std.AutoHashMap(u32, WssOptions).init(Vapor.arena(.persist));
        const key = utils.hash(wss_options.key);
        wss_callbacks.?.put(key, wss_options) catch |err| {
            std.log.err("Error adding wss options {any}\n", .{err});
            return error.CouldNotAddWssOptions;
        };
        createWss(wss_options.port, key, wss_options.query.ptr, wss_options.query.len);
        return Wss{
            .id = key,
        };
    } else if (wss_callbacks) |*callbacks| {
        const key = utils.hash(wss_options.key);
        callbacks.put(key, wss_options) catch |err| {
            std.log.err("Error adding wss options {any}\n", .{err});
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
            std.log.err("Error getting wss options {any}\n", .{error.CouldNotGetWssCallbacks});
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
            std.log.err("Error getting wss options {any}\n", .{error.CouldNotGetWssCallbacks});
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
            std.log.err("Error getting wss options {any}\n", .{error.CouldNotGetWssCallbacks});
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

// Split string into slice of slices
pub fn split(str: []const u8, delimiter: []const u8) std.mem.SplitIterator(u8, .sequence) {
    return std.mem.splitSequence(u8, str, delimiter);
}

pub fn contains(str: []const u8, needle: []const u8) bool {
    return utils.contains(str, needle);
}

pub fn startsWith(str: []const u8, prefix: []const u8) bool {
    return utils.startsWith(str, prefix);
}
