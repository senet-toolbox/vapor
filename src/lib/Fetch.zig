//! HTTP requests from the browser.
//!
//!     const users = Vapor.fetch("/api/users", .{});        // GET by default
//!     users.handle(onUsers, .{});
//!
//!     fn onUsers(result: Vapor.Fetch.Result) void {
//!         switch (result) {
//!             .ok => |response| ... response.body ...,
//!             .err => |err| ... err.message ...,
//!         }
//!     }
//!
//!     // in render, the same handle reports progress:
//!     switch (users.state()) { .idle, .loading => ..., .ok => ..., .err => ... }
//!
//! `fetch` returns a `*Request`; see "Pointer lifetime model" below for how
//! long it stays valid. GET/OPTIONS requests to the same URL share one
//! Request, so several components can ask for the same data.

const Vapor = @import("Vapor.zig");
const std = @import("std");

// =============================================================================
// Public types
// =============================================================================
pub const State = enum {
    idle,
    loading,
    err,
    ok,
};

pub const Result = union(enum) {
    ok: Response,
    err: ErrorResponse,

    pub fn isOk(self: Result) bool {
        return self == .ok;
    }

    pub fn body(self: Result) ?[]const u8 {
        return switch (self) {
            .ok => |r| r.body,
            .err => null,
        };
    }

    pub fn unwrap(self: Result) ?Response {
        return switch (self) {
            .ok => |r| r,
            .err => null,
        };
    }
};

pub const Response = struct {
    status: u16,
    body: []const u8,
    headers: ?Headers,
    url: []const u8,
    content_type: []const u8,
    content_length: usize,
    elapsed_ms: u32,
    redirected: bool,
};

pub const ErrorResponse = struct {
    code: u16 = 404,
    message: []const u8 = "Default Error",
    body: []const u8 = "Default Body Error",
    url: []const u8 = "/url/error",
    elapsed_ms: u32 = 1000,
    kind: ErrorKind = .network,
};

pub const ErrorKind = enum {
    network,
    timeout,
    parse,
    aborted,
    http,
    unknown,
};

// =============================================================================
// Internal: wire format from JS
// =============================================================================

const ParsedResponseWire = struct {
    ok: bool,
    status: u16 = 0,
    message: []const u8 = "",
    body: []const u8 = "",
    url: []const u8 = "",
    redirected: bool = false,
    content_type: []const u8 = "",
    content_length: usize = 0,
    elapsed_ms: u32 = 0,
    headers: ?std.json.Value = null,
    error_kind: []const u8 = "",
    error_name: []const u8 = "",
};

fn wireToResult(wire: ParsedResponseWire) Result {
    if (wire.ok) {
        return .{ .ok = .{
            .status = wire.status,
            .body = wire.body,
            .url = wire.url,
            .content_type = wire.content_type,
            .content_length = wire.content_length,
            .elapsed_ms = wire.elapsed_ms,
            .redirected = wire.redirected,
            .headers = wireHeaders(wire.headers),
        } };
    }
    return .{ .err = .{
        .code = wire.status,
        .message = wire.message,
        .body = wire.body,
        .url = wire.url,
        .elapsed_ms = wire.elapsed_ms,
        .kind = parseErrorKind(wire.error_kind),
    } };
}

fn parseErrorKind(s: []const u8) ErrorKind {
    if (std.mem.eql(u8, s, "network")) return .network;
    if (std.mem.eql(u8, s, "timeout")) return .timeout;
    if (std.mem.eql(u8, s, "abort")) return .aborted;
    if (std.mem.eql(u8, s, "parse")) return .parse;
    if (std.mem.eql(u8, s, "http")) return .http;
    return .unknown;
}

fn wireHeaders(value: ?std.json.Value) ?Headers {
    _ = value;
    // Implement when/if response headers are needed by users.
    return null;
}

// =============================================================================
// Erased callback type
// =============================================================================

pub const ErasedFetchCallback = struct {
    ctx: *anyopaque,
    callFn: *const fn (*anyopaque, Result) void,
    /// Snapshot of entry generation at registration time. Used to detect
    /// stale callbacks BEFORE touching ctx (which may be in freed arena memory).
    generation: u32,
    entry_ptr: *Request.RequestEntry,

    pub fn call(self: ErasedFetchCallback, result: Result) void {
        if (self.generation != self.entry_ptr.generation) return;
        self.callFn(self.ctx, result);
    }
};

// =============================================================================
// Options
// =============================================================================

pub const Method = enum { GET, POST, PATCH, DELETE, PUT, OPTIONS };

/// A header outside the common set `Headers` names.
pub const Header = struct {
    name: []const u8,
    value: []const u8,
};

/// Common request headers. Unset ones are not sent.
pub const Headers = struct {
    const Self = @This();

    content_type: []const u8 = "text/html",
    authorization: ?[]const u8 = null,
    accept: ?[]const u8 = null,
    user_agent: ?[]const u8 = null,

    pub const Field = struct {
        name: []const u8, // "Content-Type"
        value: []const u8,
    };

    pub fn iterator(self: *const Self) Iterator {
        return .{ .headers = self };
    }

    pub const Iterator = struct {
        headers: *const Self,
        idx: usize = 0,

        pub fn next(it: *Iterator) ?Field {
            const fields = std.meta.fields(Self);
            while (it.idx < fields.len) {
                const i = it.idx;
                it.idx += 1;
                inline for (fields, 0..) |f, j| {
                    if (i == j) {
                        // non-optional []const u8 coerces to ?[]const u8,
                        // so this one line handles both kinds of field
                        const opt: ?[]const u8 = @field(it.headers, f.name);
                        if (opt) |v| return .{
                            .name = comptime headerName(f.name),
                            .value = v,
                        };
                    }
                }
            }
            return null;
        }
    };
};

/// content_type -> Content-Type, user_agent -> User-Agent
fn headerName(comptime field: []const u8) []const u8 {
    comptime {
        var out: []const u8 = "";
        var upper = true;
        for (field) |c| {
            if (c == '_') {
                out = out ++ "-";
                upper = true;
            } else if (upper) {
                out = out ++ [_]u8{std.ascii.toUpper(c)};
                upper = false;
            } else {
                out = out ++ [_]u8{c};
            }
        }
        return out;
    }
}

pub const BodyType = enum {
    /// Sent as-is.
    string,
    /// Already-serialized JSON, sent as-is with the request.
    json,
};

/// Options for `fetch`. The string fields mirror the browser's RequestInit.
pub const Options = struct {
    method: Method = .GET,
    headers: ?Headers = null,
    extra_headers: []const Header = &.{},
    body: ?[]const u8 = null,
    body_type: BodyType = .string,
    /// "same-origin" (browser default), "include" or "omit".
    credentials: ?[]const u8 = null,
    /// Shorthand for `.credentials = "include"`.
    use_credentials: bool = false,
    mode: ?[]const u8 = null,
    redirect: ?[]const u8 = null,
    referrer_policy: ?[]const u8 = null,
    integrity: ?[]const u8 = null,
    /// Gives a mutation a stable, shared Request; see the lifetime model.
    key: ?[]const u8 = null,
};

/// Serializes `options` as the RequestInit object the runtime hands to the
/// browser's fetch(). Every string is JSON-escaped.
pub fn requestJson(allocator: std.mem.Allocator, options: Options) ![]u8 {
    var out = std.Io.Writer.Allocating.init(allocator);
    errdefer out.deinit();
    const w = &out.writer;
    const str = struct {
        fn write(writer: *std.Io.Writer, value: []const u8) !void {
            try std.json.Stringify.encodeJsonString(value, .{}, writer);
        }
    }.write;

    try w.writeAll("{\"method\":");
    try str(w, @tagName(options.method));

    if (options.headers != null or options.extra_headers.len > 0) {
        try w.writeAll(",\"headers\":{");
        var first = true;
        if (options.headers) |headers| {
            var it = headers.iterator();
            while (it.next()) |field| {
                if (!first) try w.writeAll(",");
                first = false;
                try str(w, field.name);
                try w.writeAll(":");
                try str(w, field.value);
            }
        }
        for (options.extra_headers) |header| {
            if (!first) try w.writeAll(",");
            first = false;
            try str(w, header.name);
            try w.writeAll(":");
            try str(w, header.value);
        }
        try w.writeAll("}");
    }

    const credentials: ?[]const u8 = options.credentials orelse if (options.use_credentials) "include" else null;
    const optional_strings = [_]struct { []const u8, ?[]const u8 }{
        .{ "credentials", credentials },
        .{ "mode", options.mode },
        .{ "redirect", options.redirect },
        .{ "referrerPolicy", options.referrer_policy },
        .{ "integrity", options.integrity },
    };
    for (optional_strings) |pair| {
        const value = pair[1] orelse continue;
        try w.writeAll(",");
        try str(w, pair[0]);
        try w.writeAll(":");
        try str(w, value);
    }

    if (options.body) |body| {
        try w.writeAll(",\"body\":");
        // The runtime stringifies a JSON body again before sending, so both
        // kinds reach the network as the text given here.
        switch (options.body_type) {
            .string => try str(w, body),
            .json => try w.writeAll(body),
        }
    }

    try w.writeAll("}");
    return out.toOwnedSlice();
}

test requestJson {
    const gpa = std.testing.allocator;

    const minimal = try requestJson(gpa, .{});
    defer gpa.free(minimal);
    try std.testing.expectEqualStrings("{\"method\":\"GET\"}", minimal);

    const full = try requestJson(gpa, .{
        .method = .POST,
        .headers = .{ .content_type = "application/json", .authorization = "Bearer \"x\"" },
        .extra_headers = &.{.{ .name = "X-Trace", .value = "a\nb" }},
        .body = "{\"n\":1}",
        .body_type = .json,
        .use_credentials = true,
        .referrer_policy = "no-referrer",
    });
    defer gpa.free(full);
    try std.testing.expectEqualStrings(
        "{\"method\":\"POST\",\"headers\":{\"Content-Type\":\"application/json\"," ++
            "\"Authorization\":\"Bearer \\\"x\\\"\",\"X-Trace\":\"a\\nb\"}," ++
            "\"credentials\":\"include\",\"referrerPolicy\":\"no-referrer\",\"body\":{\"n\":1}}",
        full,
    );
    // Valid JSON, whatever the header values contained.
    const parsed = try std.json.parseFromSlice(std.json.Value, gpa, full, .{});
    parsed.deinit();
}

/// Starts (or joins) a request; call `.handle` on the result to send it.
pub fn fetch(url: []const u8, options: Options) *Request {
    return Request.fetch(url, options);
}

/// Deprecated: `Vapor.Fetch.Fetch` is now `Vapor.Fetch.Request`, and requests
/// start with `Vapor.fetch(url, .{})`. Kept so existing code compiles.
pub const Fetch = Request;

// =============================================================================
// Module-level state
// =============================================================================

pub var fetch_callback_registry: std.AutoHashMap(u32, ErasedFetchCallback) = undefined;
var next_callback_id: u32 = 1;

// Monotonic clock for LRU reclamation of pooled mutation slots.
var lru_tick: u64 = 0;

// =============================================================================
// Pointer lifetime model
// =============================================================================
//
// fetch() returns a raw *Request. How long that pointer stays valid depends on
// how the request is keyed:
//
//   - GET / OPTIONS, or ANY method given an explicit `key`: REGISTERED. Lives in
//     the persistent registry, never recycled. The pointer is valid for the life
//     of the app — safe to stash in a store and read from render forever.
//
//   - Keyless mutation (POST/PUT/PATCH/DELETE): POOLED. Lives in a fixed slot
//     pool and is meant to be read soon after firing (spinner → result → done).
//     The pointer stays valid until its slot is recycled, which only happens once
//     all POOL_SIZE slots are occupied and another mutation needs one (LRU). A
//     stale read is not a crash — `slots` is static — but it would surface a
//     different request's state.
//
// RULE: if you need to hold a request long-term and read it from render across
// many events, give it a `key`. A keyed request is registered, so its pointer is
// stable exactly like a GET. Keyless mutations are transient by design.

// =============================================================================
// Mutation slot pool
// =============================================================================

const POOL_SIZE = 64;

const Slot = struct {
    fetch: Request,
    entry: Request.RequestEntry,
    last_used: u64 = 0,
};

var slots: [POOL_SIZE]Slot = undefined;
var free_stack: [POOL_SIZE]u16 = undefined;
var free_top: usize = 0;
var pool_inited: bool = false;

fn initPool() void {
    for (&slots, 0..) |*s, i| {
        s.entry = .{ .arena = std.heap.ArenaAllocator.init(Vapor.allocator_global) };
        s.last_used = 0;
        free_stack[i] = @intCast(i);
    }
    free_top = POOL_SIZE;
    pool_inited = true;
}

/// Return a slot to the pool: drop any pending callback, reset (bumps generation,
/// retains arena capacity), and push the index back. The generation bump is what
/// lets resumecallback reject a late callback aimed at this now-recycled slot.
fn reclaimSlot(idx: u16) void {
    const s = &slots[idx];
    s.entry.cancelInFlight();
    s.entry.reset();
    free_stack[free_top] = idx;
    free_top += 1;
}

/// Acquire a slot index for a new mutation. Pops a free slot if available;
/// otherwise sweeps for the least-recently-used non-loading slot and reclaims it.
/// Returns null only if every slot is currently in flight (.loading).
fn popSlotIndex() ?u16 {
    if (free_top > 0) {
        free_top -= 1;
        return free_stack[free_top];
    }

    // Pool exhausted — reclaim the LRU slot that is not in flight.
    var victim: ?u16 = null;
    var victim_tick: u64 = std.math.maxInt(u64);
    for (&slots, 0..) |*s, i| {
        if (s.entry.state == .loading) continue; // never steal an in-flight request
        if (s.last_used < victim_tick) {
            victim_tick = s.last_used;
            victim = @intCast(i);
        }
    }

    if (victim) |idx| {
        reclaimSlot(idx); // pushes idx back onto the free stack
        free_top -= 1;
        return free_stack[free_top];
    }

    return null; // all POOL_SIZE slots are in flight at once
}

// =============================================================================
// Request
// =============================================================================

/// Mock control — single tagged union replaces force_error / forced_error_response /
/// force_infinite_loading. Illegal states unrepresentable.
pub const Mock = union(enum) {
    none,
    infinite_loading,
    error_response: ErrorResponse,
    ok_response: Response,
    delay: Delay,
};

const Delay = union(enum) {
    ms: u32,
    secs: f32,
};

pub const Request = struct {
    http_req: Options,
    url: []const u8,
    debug: bool = false,
    mock: Mock = .none,
    entry: *RequestEntry,
    /// Index into the slot pool when this is a pooled (keyless mutation) request,
    /// null when registry-backed or heap-overflow (both never recycle).
    pool_slot: ?u16 = null,

    pub const RequestKey = struct {
        url: []const u8,
        method: Method,
        /// Dedup discriminator. "" for GET/OPTIONS coalescing; the explicit
        /// HttpReq.key when one is supplied. Keyless mutations never enter the
        /// registry, so they never produce a RequestKey.
        tag: []const u8 = "",
    };

    pub const RequestKeyContext = struct {
        pub fn hash(_: RequestKeyContext, key: RequestKey) u64 {
            var h = std.hash.Wyhash.init(0);
            h.update(key.url);
            h.update(std.mem.asBytes(&key.method));
            h.update(key.tag);
            return h.final();
        }
        pub fn eql(_: RequestKeyContext, a: RequestKey, b: RequestKey) bool {
            return a.method == b.method and
                std.mem.eql(u8, a.url, b.url) and
                std.mem.eql(u8, a.tag, b.tag);
        }
    };

    pub const RequestEntry = struct {
        arena: std.heap.ArenaAllocator,
        generation: u32 = 0,
        last_result: ?Result = null,
        state: State = .idle,
        in_flight_id: ?u32 = null,

        pub fn allocator(self: *RequestEntry) std.mem.Allocator {
            return self.arena.allocator();
        }

        pub fn reset(self: *RequestEntry) void {
            _ = self.arena.reset(.retain_capacity);
            self.last_result = null;
            self.generation +%= 1;
        }

        pub fn deinit(self: *RequestEntry) void {
            self.arena.deinit();
        }

        pub fn cancelInFlight(self: *RequestEntry) void {
            if (self.in_flight_id) |id| {
                cleanupCallback(id);
                self.in_flight_id = null;
            }
        }
    };

    pub var request_registry: std.HashMap(
        RequestKey,
        *RequestEntry,
        RequestKeyContext,
        80,
    ) = undefined;

    pub var fetch_registry: std.HashMap(
        RequestKey,
        *Request,
        RequestKeyContext,
        80,
    ) = undefined;

    /// Called by Vapor.init; (re)creates empty registries. Calling it again
    /// before any request is in flight, as older apps do, is harmless.
    pub fn init() void {
        request_registry = std.HashMap(RequestKey, *RequestEntry, RequestKeyContext, 80)
            .init(Vapor.arena(.persist));
        fetch_registry = std.HashMap(RequestKey, *Request, RequestKeyContext, 80)
            .init(Vapor.arena(.persist));
        fetch_callback_registry = std.AutoHashMap(u32, ErasedFetchCallback)
            .init(Vapor.arena(.persist));
        initPool();
    }

    /// Methods whose requests are safe to coalesce by (url, method). Reads share
    /// a single source of truth; writes are discrete actions and get their own slot.
    fn isSharedMethod(m: Method) bool {
        return switch (m) {
            .GET, .OPTIONS => true,
            else => false,
        };
    }

    pub fn fetch(url: []const u8, http_req: Options) *Request {
        const shared = isSharedMethod(http_req.method);
        const has_key = http_req.key != null;

        // Registry path: GET/OPTIONS (coalesce by url+method) or any method with
        // an explicit key (coalesce by url+method+key).
        if (shared or has_key) {
            return fetchRegistered(url, http_req);
        }

        // Pool path: keyless mutation — independent per call.
        return fetchPooled(url, http_req);
    }

    fn fetchRegistered(url: []const u8, http_req: Options) *Request {
        const persist = Vapor.allocator_global;
        const tag: []const u8 = http_req.key orelse "";
        const key = RequestKey{ .url = url, .method = http_req.method, .tag = tag };

        const f = if (fetch_registry.get(key)) |existing|
            existing
        else blk: {
            const new = Vapor.arena(.persist).create(Request) catch |err| {
                Vapor.printlnErr("fetch: allocation failed: {any}", .{err});
                @panic("vapor: out of memory creating a request");
            };
            const owned_key = RequestKey{
                .url = persist.dupe(u8, url) catch "",
                .method = http_req.method,
                .tag = persist.dupe(u8, tag) catch "",
            };
            // Not registering only costs coalescing; the request still runs.
            fetch_registry.put(owned_key, new) catch |err| {
                Vapor.printlnErr("fetch: could not register for coalescing: {any}", .{err});
            };
            break :blk new;
        };

        const entry = getOrCreateEntry(key);
        f.* = .{
            .http_req = http_req,
            .url = url,
            .entry = entry,
            .pool_slot = null,
        };
        return f;
    }

    fn fetchPooled(url: []const u8, http_req: Options) *Request {
        if (popSlotIndex()) |idx| {
            const s = &slots[idx];
            // Slot is clean (reclaimSlot/init reset it). Wire the fetch to the
            // slot's own entry.
            s.fetch = .{
                .http_req = http_req,
                .url = url,
                .entry = &s.entry,
                .pool_slot = idx,
            };
            return &s.fetch;
        }

        // Overflow: every slot is in flight. Fall back to a standalone heap-backed
        // request that behaves like a registered one (stable pointer, never
        // recycled). This can only leak under > POOL_SIZE concurrent in-flight
        // mutations, which a UI realistically never hits. TODO: bound or grow.
        const persist = Vapor.allocator_global;
        const entry = persist.create(RequestEntry) catch |err| {
            Vapor.printlnErr("fetch: allocation failed: {any}", .{err});
            @panic("vapor: out of memory creating a request entry");
        };
        entry.* = .{ .arena = std.heap.ArenaAllocator.init(persist) };
        const f = persist.create(Request) catch |err| {
            Vapor.printlnErr("fetch: allocation failed: {any}", .{err});
            @panic("vapor: out of memory creating a request");
        };
        f.* = .{
            .http_req = http_req,
            .url = url,
            .entry = entry,
            .pool_slot = null,
        };
        return f;
    }

    fn getOrCreateEntry(key: RequestKey) *RequestEntry {
        if (request_registry.get(key)) |existing| return existing;

        const entry = Vapor.allocator_global.create(RequestEntry) catch |err| {
            Vapor.printlnErr("fetch: allocation failed: {any}", .{err});
            @panic("vapor: out of memory creating a request entry");
        };
        entry.* = .{
            .arena = std.heap.ArenaAllocator.init(Vapor.allocator_global),
        };
        const owned_key = RequestKey{
            .url = Vapor.allocator_global.dupe(u8, key.url) catch "",
            .method = key.method,
            .tag = Vapor.allocator_global.dupe(u8, key.tag) catch "",
        };
        request_registry.put(owned_key, entry) catch |err| {
            Vapor.printlnErr("fetch: could not register request: {any}", .{err});
        };
        return entry;
    }

    /// Register a callback and dispatch. Args is a tuple; the framework prepends
    /// the Result. Example: `.handle(myFn, .{&state, "extra"})` calls
    /// `myFn(result, &state, "extra")`. Store the *Request returned by fetch() and
    /// read .state()/.response() from it; see the lifetime model up top.
    pub fn handle(self: *Request, comptime cb: anytype, args: anytype) void {
        const entry = self.entry;

        // Drop any in-flight registration before resetting the arena.
        entry.cancelInFlight();
        entry.reset(); // bumps generation — invalidates prior handles to this slot
        entry.state = .loading;

        // Track recency for LRU reclamation (pooled slots only; harmless otherwise).
        if (self.pool_slot) |idx| {
            lru_tick +%= 1;
            slots[idx].last_used = lru_tick;
        }

        const id = next_callback_id;
        next_callback_id +%= 1;

        // ---- Mock paths ----
        switch (self.mock) {
            .infinite_loading => {
                entry.in_flight_id = id;
                return;
            },
            .ok_response => |resp| {
                entry.last_result = .{ .ok = resp };
                entry.state = .ok;
                invokeCallbackDirect(cb, .{ .ok = resp }, args);
                return;
            },
            .error_response => |err| {
                entry.last_result = .{ .err = err };
                entry.state = .err;
                invokeCallbackDirect(cb, .{ .err = err }, args);
                return;
            },
            .none => {},
            else => {},
        }

        // ---- Allocate closure in entry arena ----
        const Args = @TypeOf(args);
        const Closure = struct {
            arguments: Args,
            entry_ptr: *RequestEntry,
            generation: u32,
            id: u32,

            fn invoke(ptr: *anyopaque, result: Result) void {
                const self_c: *@This() = @ptrCast(@alignCast(ptr));

                self_c.entry_ptr.last_result = result;
                self_c.entry_ptr.state = switch (result) {
                    .ok => .ok,
                    .err => .err,
                };
                self_c.entry_ptr.in_flight_id = null;

                const full_args = .{result} ++ self_c.arguments;
                @call(.auto, cb, full_args);
            }
        };

        const arena_alloc = entry.allocator();
        const closure = arena_alloc.create(Closure) catch {
            Vapor.printlnSrcErr("fetch: closure alloc failed\n", .{}, @src());
            entry.state = .err;
            return;
        };
        closure.* = .{
            .arguments = args,
            .entry_ptr = entry,
            .generation = entry.generation,
            .id = id,
        };

        const erased = ErasedFetchCallback{
            .ctx = @ptrCast(closure),
            .callFn = Closure.invoke,
            .generation = entry.generation,
            .entry_ptr = entry,
        };

        fetch_callback_registry.put(id, erased) catch {
            Vapor.printlnSrcErr("fetch: registry put failed\n", .{}, @src());
            entry.state = .err;
            return;
        };
        entry.in_flight_id = id;

        // ---- Build request and dispatch ----
        const json = requestJson(arena_alloc, self.http_req) catch {
            entry.state = .err;
            cleanupCallback(id);
            entry.in_flight_id = null;
            return;
        };

        if (self.debug) {
            std.log.info("fetch {s}: {s}", .{ self.url, json });
        }

        if (Vapor.isWasi) {
            if (self.mock == .delay) {
                const delay_ms = switch (self.mock) {
                    .delay => |d| switch (d) {
                        .ms => |ms| ms,
                        .secs => |s| @as(u32, @intFromFloat(s * 1000)),
                    },
                    else => 0,
                };
                Vapor.timeout("delayed-mocked-req", delay_ms, Vapor.Wasm.fetchWasm, .{ self.url.ptr, self.url.len, id, json.ptr, json.len });
            } else {
                Vapor.Wasm.fetchWasm(self.url.ptr, self.url.len, id, json.ptr, json.len);
            }
        }
    }

    pub fn cancel(self: *Request) void {
        self.entry.cancelInFlight();
        self.entry.state = .idle;
    }

    pub fn state(self: *const Request) State {
        return self.entry.state;
    }

    pub fn response(self: *const Request) ?Result {
        return self.entry.last_result;
    }

    /// Optional eager reclaim for a pooled mutation handle. Safe to call once the
    /// UI no longer needs the result (the body has already been copied into the
    /// string table during reconcile). No-op for registered/overflow requests.
    /// Reclamation also happens lazily on pool exhaustion, so calling this is an
    /// optimization, never a requirement.
    pub fn release(self: *Request) void {
        if (self.pool_slot) |idx| {
            if (self.entry.state == .loading) return; // don't reclaim in-flight
            reclaimSlot(idx);
        }
    }
};

/// For mock paths — invoke user callback directly without going through the
/// closure/registry machinery, since mocks are synchronous.
fn invokeCallbackDirect(comptime cb: anytype, result: Result, args: anytype) void {
    const full_args = .{result} ++ args;
    @call(.auto, cb, full_args);
}

fn cleanupCallback(id: u32) void {
    _ = fetch_callback_registry.remove(id);
}

pub export fn resumecallback(id: u32, resp_ptr: [*:0]u8) callconv(.c) void {
    const resp_str = std.mem.span(resp_ptr);

    const erased_kv = fetch_callback_registry.fetchRemove(id) orelse return;
    const cb = erased_kv.value;

    if (cb.generation != cb.entry_ptr.generation) return;

    const arena_alloc = cb.entry_ptr.allocator();
    const wire = std.json.parseFromSliceLeaky(
        ParsedResponseWire,
        arena_alloc,
        resp_str,
        .{ .ignore_unknown_fields = true },
    ) catch {
        const fallback_body = arena_alloc.dupe(u8, resp_str) catch "";
        const result = Result{ .err = .{
            .code = 0,
            .message = "wire parse failed",
            .body = fallback_body,
            .url = "",
            .elapsed_ms = 0,
            .kind = .parse,
        } };
        cb.call(result);
        Vapor.cycle();
        return;
    };

    const result = wireToResult(wire);
    cb.call(result);
    Vapor.cycle();
}
