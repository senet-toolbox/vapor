// This is the Frontend module dep for KeyStone.
const std = @import("std");
const Vapor = @import("../Vapor.zig");
const Kit = Vapor.Kit;
const Fetch = @import("../Fetch.zig");
const JWT = @import("JWT.zig");

pub const Provider = enum {
    google,
    github,
    apple,
    azure,
};

pub const AuthState = enum {
    loading,
    signed_out,
    signed_in,
};

pub const AuthUser = struct {
    id: []const u8,
    email: []const u8,
    name: []const u8,
    picture: ?[]const u8 = null,
};

pub const SessionInfo = struct {
    token: []const u8,
    user: ?AuthUser = null,
    provider: ?Provider = null,
    issued_at: ?i64 = null,
    expires_at: ?i64 = null,
};

pub const AuthSnapshot = struct {
    state: AuthState,
    session: ?SessionInfo = null,
    err: ?[]const u8 = null,
};

pub const ClientConfig = struct {
    client_id: []const u8,
    redirect_uri: ?[]const u8 = null,
    scope: ?[]const u8 = null,
};

/// Backward-compatible alias.
pub const Config = ClientConfig;

pub const Clients = struct {
    google: ?ClientConfig = null,
    github: ?ClientConfig = null,
    azure: ?ClientConfig = null,
    apple: ?ClientConfig = null,
};

pub const InitConfig = struct {
    clients: Clients,
    hook_path: []const u8 = "/auth/callback",
    backend_url: []const u8 = "http://localhost:8080",
    session_storage_key: []const u8 = "keystone_session_token",
    auth_sync_storage_key: []const u8 = "keystone_auth_sync",
    oauth_provider_cookie_name: []const u8 = "oauth_provider",
    oauth_state_cookie_name: []const u8 = "keystone_oauth_state",
    oauth_nonce_cookie_name: []const u8 = "keystone_oauth_nonce",
    oauth_state_storage_key: []const u8 = "keystone_oauth_state",
    oauth_nonce_storage_key: []const u8 = "keystone_oauth_nonce",
    oauth_provider_storage_key: []const u8 = "keystone_oauth_provider",
};

pub const AuthFetchOptions = struct {
    retry_on_401: bool = true,
};

const AuthorizeConfig = struct {
    base_url: []const u8,
    response_type: ?[]const u8 = null,
    default_scope: ?[]const u8 = null,
    access_type: ?[]const u8 = null,
    prompt: ?[]const u8 = null,
    response_mode: ?[]const u8 = null,
    include_state: bool = false,
    include_nonce: bool = false,
};

const BackendState = enum {
    loading,
    signed_out,
    signed_in,
};

const BackendUser = struct {
    id: []const u8,
    email: []const u8,
    name: []const u8,
    picture: ?[]const u8 = null,
};

const BackendSession = struct {
    token: []const u8,
    user: BackendUser,
    provider: Provider,
    issued_at: i64,
    expires_at: i64,
};

const AuthSessionResponse = struct {
    success: bool,
    state: BackendState,
    session: ?BackendSession = null,
    err: ?[]const u8 = null,
};

const ExchangeSessionResponse = struct {
    success: bool,
    state: BackendState,
    token: []const u8,
    issued_at: i64,
    expires_at: i64,
    user: BackendUser,
};

const LegacyTokenExchangeResponse = struct {
    token: []const u8,
};

const JwtFallbackClaims = struct {
    sub: ?[]const u8 = null,
    email: ?[]const u8 = null,
    name: ?[]const u8 = null,
    exp: ?i64 = null,
    iat: ?i64 = null,
};

const provider_tags = std.meta.tags(Provider);
const provider_count = provider_tags.len;

const KeyStone = @This();
var on_auth_change: ?*const fn (Kit.Response) void = null;
var on_auth_state_change: ?*const fn (AuthSnapshot) void = null;
var configured_provider_cache: [provider_count]Provider = undefined;
var configured_provider_count: usize = 0;
var auth_snapshot: AuthSnapshot = .{ .state = .signed_out };
var focus_sync_listener_id: ?u32 = null;

pub var keystone: KeyStone = .{
    .clients = .{},
    .hook_path = "/auth/callback",
    .backend_url = "http://localhost:8080",
    .session_storage_key = "keystone_session_token",
    .auth_sync_storage_key = "keystone_auth_sync",
    .oauth_provider_cookie_name = "oauth_provider",
    .oauth_state_cookie_name = "keystone_oauth_state",
    .oauth_nonce_cookie_name = "keystone_oauth_nonce",
    .oauth_state_storage_key = "keystone_oauth_state",
    .oauth_nonce_storage_key = "keystone_oauth_nonce",
    .oauth_provider_storage_key = "keystone_oauth_provider",
    .hook_registered = false,
};

clients: Clients,
hook_path: []const u8,
backend_url: []const u8,
session_storage_key: []const u8,
auth_sync_storage_key: []const u8,
oauth_provider_cookie_name: []const u8,
oauth_state_cookie_name: []const u8,
oauth_nonce_cookie_name: []const u8,
oauth_state_storage_key: []const u8,
oauth_nonce_storage_key: []const u8,
oauth_provider_storage_key: []const u8,
hook_registered: bool,

pub fn init(cfg: InitConfig) void {
    keystone.clients = cfg.clients;
    keystone.hook_path = cfg.hook_path;
    keystone.backend_url = cfg.backend_url;
    keystone.session_storage_key = cfg.session_storage_key;
    keystone.auth_sync_storage_key = cfg.auth_sync_storage_key;
    keystone.oauth_provider_cookie_name = cfg.oauth_provider_cookie_name;
    keystone.oauth_state_cookie_name = cfg.oauth_state_cookie_name;
    keystone.oauth_nonce_cookie_name = cfg.oauth_nonce_cookie_name;
    keystone.oauth_state_storage_key = cfg.oauth_state_storage_key;
    keystone.oauth_nonce_storage_key = cfg.oauth_nonce_storage_key;
    keystone.oauth_provider_storage_key = cfg.oauth_provider_storage_key;

    keystone.initHooks();
    rebuildConfiguredProviderCache();
    hydrateFromStoredToken();
}

pub fn onAuthChange(cb: *const fn (Kit.Response) void) void {
    on_auth_change = cb;
}

pub fn onAuthStateChange(cb: *const fn (AuthSnapshot) void) void {
    on_auth_state_change = cb;
}

pub fn getAuthState() AuthSnapshot {
    return auth_snapshot;
}

pub fn configuredProviders() []const Provider {
    return configured_provider_cache[0..configured_provider_count];
}

pub fn hasProvider(provider: Provider) bool {
    return keystone.getClient(provider) != null;
}

pub fn oauthUrl(provider: Provider) ?[]const u8 {
    const client = keystone.getClient(provider) orelse return null;
    return buildAuthorizeUrl(provider, client, true) catch null;
}

pub fn signIn(provider: Provider) void {
    signInWithOauth(provider);
}

pub fn signInWithOauth(provider: Provider) void {
    const client = keystone.getClient(provider) orelse return;
    const url = buildAuthorizeUrl(provider, client, false) catch return;
    defer Vapor.allocator_global.free(url);
    setAuthState(.{ .state = .loading });
    Kit.setWindowLocation(url);
}

pub fn handleAuthExchanges() void {
    _ = maybeHandleAuthExchange();
}

pub fn maybeHandleAuthExchange() bool {
    const params = Kit.Window.params() orelse return false;
    if (params.get("code") == null and params.get("error") == null) return false;

    if (params.get("error")) |oauth_err| {
        setAuthState(.{ .state = .signed_out, .err = oauth_err });
        clearPendingOauthGuards();
        return true;
    }

    const code = params.get("code") orelse return false;
    const provider = getProviderFromCookieOrStore() orelse return false;
    if (!validateCallbackGuards(params)) {
        setAuthState(.{ .state = .signed_out, .err = "oauth_guard_mismatch" });
        clearPendingOauthGuards();
        return true;
    }

    exchangeCode(provider, code);
    return true;
}

pub fn bootstrap() void {
    setAuthState(.{ .state = .loading, .session = auth_snapshot.session });
    const url = Vapor.frame.fmt("{s}/auth/session/bootstrap", .{keystone.backend_url});
    Fetch.fetch(url, .{
        .method = .POST,
        .credentials = "include",
    }).handle(handleAuthSessionResponse, .{});
}

pub fn restoreSession() void {
    bootstrap();
}

pub fn refreshSession() void {
    const url = Vapor.frame.fmt("{s}/auth/session/refresh", .{keystone.backend_url});
    Fetch.fetch(url, .{
        .method = .POST,
        .credentials = "include",
    }).handle(handleAuthSessionResponse, .{});
}

pub fn syncFromStorage() void {
    const stored = Vapor.getStore([]const u8, keystone.session_storage_key) orelse "";
    const current = auth_snapshot.session orelse SessionInfo{ .token = "" };
    if (!std.mem.eql(u8, stored, current.token)) {
        if (stored.len == 0) {
            setAuthState(.{ .state = .signed_out });
        } else {
            hydrateFromStoredToken();
        }
    }
}

/// Uses focus events to keep auth state in sync when users move between tabs/windows.
pub fn enableFocusSync() void {
    if (focus_sync_listener_id != null) return;
    focus_sync_listener_id = Vapor.addGlobalListener(.focus, onGlobalFocus);
}

pub fn disableFocusSync() void {
    if (focus_sync_listener_id) |id| {
        _ = Vapor.removeGlobalListener(.focus, id);
        focus_sync_listener_id = null;
    }
}

pub fn isAuthenticated() bool {
    const token = getAccessToken() orelse return false;
    return !JWT.isExpired(token);
}

pub fn getSession() ?[]const u8 {
    return getAccessToken();
}

pub fn getAccessToken() ?[]const u8 {
    return Vapor.getStore([]const u8, keystone.session_storage_key);
}

pub fn getUser() ?AuthUser {
    return if (auth_snapshot.session) |s| s.user else null;
}

pub fn clearSession() void {
    clearLocalSession();
    setAuthState(.{ .state = .signed_out });
}

pub fn signOut() void {
    signOutWithOptions(.{});
}

pub const SignOutOptions = struct {
    revoke_remote: bool = false,
    notify_backend: bool = true,
};

pub fn signOutWithOptions(options: SignOutOptions) void {
    clearProviderCookie(keystone.oauth_provider_cookie_name);
    clearProviderCookie(keystone.oauth_state_cookie_name);
    clearProviderCookie(keystone.oauth_nonce_cookie_name);
    clearPendingOauthGuards();
    clearLocalSession();
    setAuthState(.{ .state = .signed_out });

    if (!options.notify_backend) return;
    const body = if (options.revoke_remote) "revoke_remote=true" else "revoke_remote=false";
    const url = Vapor.frame.fmt("{s}/auth/session/signout", .{keystone.backend_url});
    Fetch.fetch(url, .{
        .method = .POST,
        .body = body,
        .credentials = "include",
        .headers = .{ .content_type = "application/x-www-form-urlencoded" },
        .body_type = .string,
    }).handle(handleAuthSessionResponse, .{});
}

/// Backward-compatible alias.
pub fn signout() void {
    signOut();
}

pub fn validateSession(provider: Provider, cb: fn (Kit.Response) void) void {
    const token = getAccessToken() orelse return;
    const url = Vapor.frame.fmt("{s}/auth/validate/{s}/session", .{ keystone.backend_url, @tagName(provider) });
    const auth_header = Vapor.frame.fmt("Bearer {s}", .{token});
    Fetch.fetch(url, .{
        .method = .POST,
        .credentials = "include",
        .headers = .{ .authorization = auth_header },
    }).handle(cb, .{});
}

pub fn authFetch(url: []const u8, http_req: Kit.HttpReq, cb: fn (Kit.Response) void) void {
    authFetchWithOptions(url, http_req, .{}, cb);
}

pub fn authFetchWithOptions(
    url: []const u8,
    http_req: Kit.HttpReq,
    options: AuthFetchOptions,
    cb: fn (Kit.Response) void,
) void {
    const callback = cb;
    const Ctx = struct {
        url: []const u8,
        req: Kit.HttpReq,
        options: AuthFetchOptions,
    };
    const Handlers = struct {
        fn onRequest(ctx: Ctx, resp: Kit.Response) void {
            if (resp == .err and resp.err.code == 401 and ctx.options.retry_on_401) {
                const refresh_url = Vapor.frame.fmt("{s}/auth/session/refresh", .{keystone.backend_url});
                Kit.fetchWithParams(refresh_url, ctx, onRefresh, .{
                    .method = .POST,
                    .credentials = "include",
                });
                return;
            }
            callback(resp);
        }

        fn onRefresh(ctx: Ctx, resp: Kit.Response) void {
            handleAuthSessionResponse(resp);
            if (resp == .ok and auth_snapshot.state == .signed_in and getAccessToken() != null) {
                const retried_req = withAuthHeader(ctx.req, getAccessToken());
                Fetch.fetch(ctx.url, retried_req).handle(callback, .{});
                return;
            }
            callback(resp);
        }
    };

    const ctx = Ctx{
        .url = Vapor.dupe(url, .persist),
        .req = http_req,
        .options = options,
    };
    const req_with_auth = withAuthHeader(http_req, getAccessToken());
    Kit.fetchWithParams(url, ctx, Handlers.onRequest, req_with_auth);
}

fn withAuthHeader(http_req: Kit.HttpReq, token: ?[]const u8) Kit.HttpReq {
    if (token == null) return http_req;
    const auth_header = Vapor.frame.fmt("Bearer {s}", .{token.?});
    var auth_req = http_req;

    if (http_req.headers) |headers| {
        auth_req.headers = .{
            .content_type = headers.content_type,
            .authorization = auth_header,
            .accept = headers.accept,
            .user_agent = headers.user_agent,
        };
    } else {
        auth_req.headers = .{
            .authorization = auth_header,
        };
    }
    return auth_req;
}

fn initHooks(self: *KeyStone) void {
    if (self.hook_registered) return;
    _ = Vapor.registerHook(self.hook_path, exchangeHook, .before);
    self.hook_registered = true;
}

fn exchangeHook(_: Vapor.HookContext) void {
    if (!maybeHandleAuthExchange()) {
        std.log.err("Failed to handle auth exchange", .{});
    }
}

fn onGlobalFocus(_: *Vapor.Event) void {
    syncFromStorage();
}

fn rebuildConfiguredProviderCache() void {
    configured_provider_count = 0;
    inline for (provider_tags) |provider| {
        if (keystone.getClient(provider) != null) {
            configured_provider_cache[configured_provider_count] = provider;
            configured_provider_count += 1;
        }
    }
}

fn getProviderFromCookieOrStore() ?Provider {
    if (Vapor.getCookie(keystone.oauth_provider_cookie_name)) |provider_str| {
        if (std.meta.stringToEnum(Provider, provider_str)) |provider| return provider;
    }

    const stored = Vapor.getStore([]const u8, keystone.oauth_provider_storage_key) orelse return null;
    return std.meta.stringToEnum(Provider, stored);
}

fn validateCallbackGuards(params: std.StringHashMap([]const u8)) bool {
    const expected_state = Vapor.getStore([]const u8, keystone.oauth_state_storage_key);
    if (expected_state) |state| {
        if (state.len > 0) {
            const incoming_state = params.get("state") orelse return false;
            if (!std.mem.eql(u8, state, incoming_state)) return false;
        }
    }

    const expected_nonce = Vapor.getStore([]const u8, keystone.oauth_nonce_storage_key);
    if (expected_nonce) |nonce| {
        if (nonce.len > 0) {
            const incoming_nonce = params.get("nonce") orelse return false;
            if (!std.mem.eql(u8, nonce, incoming_nonce)) return false;
        }
    }

    return true;
}

fn providerDefaults(provider: Provider) AuthorizeConfig {
    return switch (provider) {
        .google => .{
            .base_url = "https://accounts.google.com/o/oauth2/v2/auth",
            .response_type = "code",
            .default_scope = "openid email profile",
            .access_type = "offline",
            .prompt = "consent",
            .include_state = true,
        },
        .github => .{
            .base_url = "https://github.com/login/oauth/authorize",
            .default_scope = "read:user user:email",
            .include_state = true,
        },
        .apple => .{
            .base_url = "https://appleid.apple.com/auth/authorize",
            .response_type = "code id_token",
            .default_scope = "name email",
            .response_mode = "form_post",
            .include_state = true,
            .include_nonce = true,
        },
        .azure => .{
            .base_url = "https://login.microsoftonline.com/common/oauth2/v2.0/authorize",
            .response_type = "code",
            .default_scope = "openid email profile",
            .include_state = true,
        },
    };
}

fn callbackUrl() []const u8 {
    if (std.mem.startsWith(u8, keystone.hook_path, "http://") or std.mem.startsWith(u8, keystone.hook_path, "https://")) {
        return keystone.hook_path;
    }
    const origin = Kit.Window.origin();
    if (origin.len == 0) return keystone.hook_path;
    return Vapor.frame.fmt("{s}{s}", .{ origin, keystone.hook_path });
}

fn resolveRedirectUri(client: ClientConfig) []const u8 {
    return client.redirect_uri orelse callbackUrl();
}

fn buildAuthorizeUrl(provider: Provider, client: ClientConfig, dry_run: bool) ![]const u8 {
    const cfg = providerDefaults(provider);
    const state = defaultState(provider);
    const nonce = defaultNonce(provider);

    if (!dry_run) {
        rememberOAuthGuard(provider, state, nonce, cfg.include_nonce);
    }

    var query: Kit.QueryBuilder = undefined;
    try query.init(Vapor.allocator_global);
    defer query.deinit();

    try query.add("client_id", client.client_id);
    try query.add("redirect_uri", resolveRedirectUri(client));

    if (cfg.response_type) |response_type| try query.add("response_type", response_type);
    if (client.scope) |scope| {
        try query.add("scope", scope);
    } else if (cfg.default_scope) |scope| {
        try query.add("scope", scope);
    }
    if (cfg.access_type) |access_type| try query.add("access_type", access_type);
    if (cfg.prompt) |prompt| try query.add("prompt", prompt);
    if (cfg.response_mode) |response_mode| try query.add("response_mode", response_mode);
    if (cfg.include_state) try query.add("state", state);
    if (cfg.include_nonce) try query.add("nonce", nonce);

    try query.queryStrEncode();
    return query.generateUrl(cfg.base_url, query.str);
}

fn defaultState(provider: Provider) []const u8 {
    return Vapor.frame.fmt("keystone-{s}-{d}", .{ @tagName(provider), Vapor.Kit.timestamp() });
}

fn defaultNonce(provider: Provider) []const u8 {
    return Vapor.frame.fmt("nonce-{s}-{d}", .{ @tagName(provider), Vapor.Kit.timestamp() });
}

fn rememberOAuthGuard(provider: Provider, state: []const u8, nonce: []const u8, include_nonce: bool) void {
    Vapor.store(keystone.oauth_provider_storage_key, @tagName(provider));
    Vapor.store(keystone.oauth_state_storage_key, state);
    Vapor.setCookie(Vapor.frame.fmt("{s}={s}; Path=/; SameSite=Lax", .{ keystone.oauth_provider_cookie_name, @tagName(provider) }));
    Vapor.setCookie(Vapor.frame.fmt("{s}={s}; Path=/; SameSite=Lax", .{ keystone.oauth_state_cookie_name, state }));

    if (include_nonce) {
        Vapor.store(keystone.oauth_nonce_storage_key, nonce);
        Vapor.setCookie(Vapor.frame.fmt("{s}={s}; Path=/; SameSite=Lax", .{ keystone.oauth_nonce_cookie_name, nonce }));
    } else {
        Vapor.store(keystone.oauth_nonce_storage_key, "");
        clearProviderCookie(keystone.oauth_nonce_cookie_name);
    }
}

fn clearPendingOauthGuards() void {
    Vapor.store(keystone.oauth_provider_storage_key, "");
    Vapor.store(keystone.oauth_state_storage_key, "");
    Vapor.store(keystone.oauth_nonce_storage_key, "");
}

fn exchangeCode(provider: Provider, code: []const u8) void {
    const state = Vapor.getStore([]const u8, keystone.oauth_state_storage_key) orelse "";
    const nonce = Vapor.getStore([]const u8, keystone.oauth_nonce_storage_key) orelse "";
    const body = Vapor.frame.fmt("auth-code={s}&state={s}&nonce={s}", .{ code, state, nonce });
    const url = Vapor.frame.fmt("{s}/exchange/{s}/token", .{ keystone.backend_url, @tagName(provider) });
    Fetch.fetch(url, .{
        .method = .POST,
        .body = body,
        .credentials = "include",
        .headers = .{
            .content_type = "application/x-www-form-urlencoded",
        },
        .body_type = .string,
    }).handle(handleTokenExchangeResponse, .{});
}

fn handleTokenExchangeResponse(resp: Kit.Response) void {
    emitRawAuthResponse(resp);

    switch (resp) {
        .ok => |ok| {
            const provider = getProviderFromCookieOrStore() orelse .google;
            if (Kit.Json.parse(ExchangeSessionResponse, ok.body, .frame)) |exchange_resp| {
                applyBackendSession(.{
                    .token = exchange_resp.token,
                    .provider = provider,
                    .issued_at = exchange_resp.issued_at,
                    .expires_at = exchange_resp.expires_at,
                    .user = .{
                        .id = exchange_resp.user.id,
                        .email = exchange_resp.user.email,
                        .name = exchange_resp.user.name,
                        .picture = exchange_resp.user.picture,
                    },
                });
                clearPendingOauthGuards();
                return;
            } else |_| {}

            if (Kit.Json.parse(AuthSessionResponse, ok.body, .frame)) |auth_resp| {
                applyAuthSessionResponse(auth_resp);
                clearPendingOauthGuards();
                return;
            } else |_| {}

            if (Kit.Json.parse(LegacyTokenExchangeResponse, ok.body, .frame)) |legacy_resp| {
                storeToken(legacy_resp.token);
                setAuthState(.{
                    .state = .signed_in,
                    .session = tokenToSession(legacy_resp.token),
                });
                clearPendingOauthGuards();
                return;
            } else |_| {}

            setAuthState(.{ .state = .signed_out, .err = "malformed_exchange_response" });
        },
        .err => {
            setAuthState(.{ .state = .signed_out, .err = "oauth_exchange_failed" });
        },
    }
}

fn handleAuthSessionResponse(resp: Kit.Response) void {
    emitRawAuthResponse(resp);

    switch (resp) {
        .ok => |ok| {
            const auth_resp: AuthSessionResponse = Kit.Json.parse(AuthSessionResponse, ok.body, .frame) catch {
                setAuthState(.{ .state = .signed_out, .err = "malformed_auth_session_response" });
                return;
            };
            applyAuthSessionResponse(auth_resp);
        },
        .err => {
            setAuthState(.{ .state = .signed_out, .err = "auth_session_request_failed" });
        },
    }
}

fn applyAuthSessionResponse(auth_resp: AuthSessionResponse) void {
    switch (auth_resp.state) {
        .loading => setAuthState(.{ .state = .loading, .session = auth_snapshot.session }),
        .signed_out => {
            clearLocalSession();
            setAuthState(.{ .state = .signed_out, .err = auth_resp.err });
        },
        .signed_in => {
            const backend_session = auth_resp.session orelse {
                setAuthState(.{ .state = .signed_out, .err = "missing_session_payload" });
                return;
            };
            applyBackendSession(backend_session);
        },
    }
}

fn applyBackendSession(backend_session: BackendSession) void {
    storeToken(backend_session.token);
    setAuthState(.{
        .state = .signed_in,
        .session = .{
            .token = backend_session.token,
            .provider = backend_session.provider,
            .issued_at = backend_session.issued_at,
            .expires_at = backend_session.expires_at,
            .user = .{
                .id = backend_session.user.id,
                .email = backend_session.user.email,
                .name = backend_session.user.name,
                .picture = backend_session.user.picture,
            },
        },
    });
}

fn hydrateFromStoredToken() void {
    const token = getAccessToken() orelse {
        setAuthState(.{ .state = .signed_out });
        return;
    };
    if (token.len == 0 or JWT.isExpired(token)) {
        clearLocalSession();
        setAuthState(.{ .state = .signed_out });
        return;
    }
    setAuthState(.{
        .state = .signed_in,
        .session = tokenToSession(token),
    });
}

fn tokenToSession(token: []const u8) SessionInfo {
    var session = SessionInfo{
        .token = token,
    };

    const claims = parseJwtFallbackClaims(token) catch return session;
    if (claims.exp) |exp| session.expires_at = exp;
    if (claims.iat) |iat| session.issued_at = iat;

    if (claims.sub) |id| {
        session.user = .{
            .id = id,
            .email = claims.email orelse "",
            .name = claims.name orelse "User",
            .picture = null,
        };
    }

    return session;
}

fn parseJwtFallbackClaims(token: []const u8) !JwtFallbackClaims {
    var parts = std.mem.splitScalar(u8, token, '.');
    _ = parts.next() orelse return error.InvalidToken;
    const payload_b64 = parts.next() orelse return error.InvalidToken;

    const decoder = std.base64.url_safe_no_pad.Decoder;
    const size = try decoder.calcSizeForSlice(payload_b64);
    var buf: [2048]u8 = undefined;
    if (size > buf.len) return error.PayloadTooLarge;
    try decoder.decode(buf[0..size], payload_b64);

    return try Kit.Json.parse(JwtFallbackClaims, buf[0..size], .frame);
}

fn setAuthState(next: AuthSnapshot) void {
    auth_snapshot = cloneSnapshot(next);
    if (on_auth_state_change) |cb| cb(auth_snapshot);
    writeAuthSyncMarker();
}

fn cloneSnapshot(snapshot: AuthSnapshot) AuthSnapshot {
    var out = AuthSnapshot{
        .state = snapshot.state,
        .session = null,
        .err = if (snapshot.err) |v| Vapor.dupe(v, .persist) else null,
    };

    if (snapshot.session) |session| {
        var copied = SessionInfo{
            .token = Vapor.dupe(session.token, .persist),
            .provider = session.provider,
            .issued_at = session.issued_at,
            .expires_at = session.expires_at,
            .user = null,
        };
        if (session.user) |user| {
            copied.user = .{
                .id = Vapor.dupe(user.id, .persist),
                .email = Vapor.dupe(user.email, .persist),
                .name = Vapor.dupe(user.name, .persist),
                .picture = if (user.picture) |pic| Vapor.dupe(pic, .persist) else null,
            };
        }
        out.session = copied;
    }

    return out;
}

fn emitRawAuthResponse(resp: Kit.Response) void {
    if (on_auth_change) |cb| cb(resp);
}

fn storeToken(token: []const u8) void {
    Vapor.store(keystone.session_storage_key, token);
}

fn clearLocalSession() void {
    Vapor.store(keystone.session_storage_key, "");
}

fn clearProviderCookie(name: []const u8) void {
    const cookie = Vapor.frame.fmt("{s}=; Path=/; Max-Age=0; SameSite=Lax", .{name});
    Vapor.setCookie(cookie);
}

fn writeAuthSyncMarker() void {
    Vapor.store(keystone.auth_sync_storage_key, Vapor.frame.fmt("{d}", .{Vapor.Kit.timestamp()}));
}

fn getClient(self: *const KeyStone, provider: Provider) ?ClientConfig {
    return switch (provider) {
        .google => self.clients.google,
        .github => self.clients.github,
        .apple => self.clients.apple,
        .azure => self.clients.azure,
    };
}
