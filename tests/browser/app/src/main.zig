//! The app `zig build browser-test` drives in headless Chrome.
//!
//! Each page exercises one behaviour end to end: Zig state -> reconciler ->
//! JS runtime -> DOM, and DOM events back. Elements the runner inspects carry
//! an explicit `.id()`, which vapor also uses as the DOM id.

const std = @import("std");
const Vapor = @import("vapor");
const KeyStone = @import("keystone");
const Box = Vapor.Box;
const Button = Vapor.Button;
const Text = Vapor.Text;
const TextFmt = Vapor.TextFmt;
const TextField = Vapor.TextField;
const Link = Vapor.Link;

pub export fn init() void {
    Vapor.init(.{});
    // The test server records what is posted here.
    Vapor.reportErrors(.{ .url = "/errors/report", .release = "browser-test", .environment = "test" });
    Vapor.Page(.{ .route = "/" }, home, null);
    Vapor.Page(.{ .route = "/crash" }, crashPage, null);
    Vapor.Page(.{ .route = "/list" }, list, null);
    Vapor.Page(.{ .route = "/cond" }, cond, null);
    Vapor.Page(.{ .route = "/input" }, input, null);
    Vapor.Page(.{ .route = "/numbers" }, numbers, null);
    Vapor.Page(.{ .route = "/escape" }, escape, null);
    Vapor.Page(.{ .route = "/a" }, pageA, null);
    Vapor.Page(.{ .route = "/b" }, pageB, null);
    Vapor.Page(.{ .route = "/fetch" }, fetchPage, null);
    Vapor.Page(.{ .route = "/storage" }, storagePage, null);
    Vapor.Page(.{ .route = "/urls" }, urls, null);
    Vapor.Page(.{ .route = "/users/:id" }, userPage, null);
    Vapor.Page(.{ .route = "/users/:id/edit" }, userEditPage, null);
    Vapor.Page(.{ .route = "/users/new" }, newUserPage, null);
    Vapor.Page(.{ .route = "/hide" }, hidePage, null);
    Vapor.Page(.{ .route = "/focus" }, focusPage, null);
    Vapor.Page(.{ .route = "/hooks" }, hooksPage, null);
    Vapor.Page(.{ .route = "/styles" }, stylesPage, null);
    Vapor.Page(.{ .route = "/listeners" }, listenersPage, null);
    Vapor.Page(.{ .route = "/resize" }, resizePage, null);
    Vapor.Page(.{ .route = "/responsive" }, responsivePage, null);
    Vapor.Page(.{ .route = "/svg" }, svgPage, null);
    Vapor.Page(.{ .route = "/listen" }, listenPage, null);
    Vapor.Page(.{ .route = "/stale" }, stalePage, null);
    Vapor.Page(.{ .route = "/drag" }, dragPage, null);
    Vapor.Page(.{ .route = "/mount-off" }, mountOffPage, null);
    Vapor.Page(.{ .route = "/once" }, oncePage, null);
    Vapor.Page(.{ .route = "/aria" }, ariaPage, null);
    Vapor.Page(.{ .route = "/focus-any" }, focusAnyPage, null);
    Vapor.Page(.{ .route = "/timeout" }, timeoutPage, null);
    Vapor.Page(.{ .route = "/transition" }, transitionPage, null);
    Vapor.Page(.{ .route = "/transition-b" }, transitionPageB, null);
    Vapor.Page(.{ .route = "/playground" }, playgroundPage, null);
    Vapor.Page(.{ .route = "/signin" }, signInPage, null);
    Vapor.Page(.{ .route = "/auth/callback" }, callbackPage, null);
    Vapor.Page(.{ .route = "/error" }, notFound, null);
    // After the pages: it formats into the frame arena, which needs a route.
    // The backend is this origin, where the test server answers the code
    // exchange.
    KeyStone.init(.{ .clients = .{ .google = .{ .client_id = "test-client" } }, .backend_url = "" });
}

pub const std_options = std.Options{
    .log_level = .info,
    .logFn = Vapor.lib.log,
};

// ── / : events update state, state updates the DOM ─────────────────────────

var count: u32 = 0;

fn increment() void {
    count += 1;
}

fn home() void {
    Box().id("home").children({
        Button(increment, .{}).id("inc").children({
            Text("Increment").end();
        });
        Text(count).id("count").end();
    });
}

// ── /crash : a panic and a trap, reported to the URL the app set ───────────

var crash_note: []const u8 = "";

fn panicNow() void {
    @panic("boom: the crash test panics");
}

fn trapNow() void {
    @trap();
}

fn crashPage() void {
    Box().id("crash-page").children({
        TextField(.string).id("crash-note").bind(&crash_note).end();
        Button(panicNow, .{}).id("crash-panic").children({
            Text("Panic").end();
        });
        Button(trapNow, .{}).id("crash-trap").children({
            Text("Trap").end();
        });
    });
}

// ── /list : keyed children keep their DOM nodes across reorders ────────────

var items_buf: [32]u32 = .{ 1, 2, 3, 4, 5 } ++ .{0} ** 27;
var items_len: usize = 5;
var next_item: u32 = 6;

fn items() []u32 {
    return items_buf[0..items_len];
}

fn reverseItems() void {
    std.mem.reverse(u32, items());
}

fn prependItem() void {
    if (items_len == items_buf.len) return;
    std.mem.copyBackwards(u32, items_buf[1 .. items_len + 1], items_buf[0..items_len]);
    items_buf[0] = next_item;
    next_item += 1;
    items_len += 1;
}

fn removeFirst() void {
    if (items_len == 0) return;
    std.mem.copyForwards(u32, items_buf[0 .. items_len - 1], items_buf[1..items_len]);
    items_len -= 1;
}

fn list() void {
    Box().id("list-page").children({
        Button(reverseItems, .{}).id("reverse").children({
            Text("Reverse").end();
        });
        Button(prependItem, .{}).id("prepend").children({
            Text("Prepend").end();
        });
        Button(removeFirst, .{}).id("remove-first").children({
            Text("Remove first").end();
        });
        Box().id("items").children({
            for (items()) |item| {
                Box().id(Vapor.frame.fmt("item-{d}", .{item})).children({
                    TextFmt("Item {d}", .{item}).end();
                });
            }
        });
    });
}

// ── /cond : a conditional sibling must not disturb what follows it ─────────

var show_banner = false;

fn toggleBanner() void {
    show_banner = !show_banner;
}

fn cond() void {
    Box().id("cond-page").children({
        Button(toggleBanner, .{}).id("toggle").children({
            Text("Toggle").end();
        });
        if (show_banner) {
            Text("Banner").id("banner").end();
        }
        Text("Stable").id("stable").end();
        Text("Unkeyed after").end();
    });
}

// ── /hide : .hidden(false) shows the element again ─────────────────────────

var panel_hidden = false;

fn toggleHidden() void {
    panel_hidden = !panel_hidden;
}

fn hidePage() void {
    Box().id("hide-page").children({
        Button(toggleHidden, .{}).id("toggle-hidden").children({
            Text("Toggle").end();
        });
        Text("Panel").id("panel").hidden(panel_hidden).end();
    });
}

// ── /styles : unused CSS rules are removed, responsive rules insert ───────

var style_step: f32 = 0;

fn restyle() void {
    style_step += 1;
}

fn stylesPage() void {
    Box().id("styles-page").children({
        Button(restyle, .{}).id("restyle").children({
            Text("Restyle").end();
        });
        // A new width each click, so a new class each render.
        Box().id("styled").width(.px(100 + style_step)).height(.px(20)).end();
        // Same styles, different classes: each keeps its own class.
        Box().id("hovered").hover(.{ .opacity = 0.5 }).width(.px(40 + style_step)).end();
        Box().id("class-a").class("user-a").width(.px(30)).end();
        Box().id("class-b").class("user-b").width(.px(30)).end();
        Box().id("responsive")
            .responsive(.mobile, .{ .child_gap = 4 })
            .responsive(.desktop, .{ .child_gap = 8 })
            .end();
    });
}

// ── /listeners : document listeners are added and removed one by one ──────

var key_a: u32 = 0;
var key_b: u32 = 0;
var listener_a: ?u32 = null;
var listener_b: ?u32 = null;

fn keyA(_: *Vapor.Event) void {
    key_a += 1;
}

fn keyB(_: *Vapor.Event) void {
    key_b += 1;
}

fn addListeners() void {
    listener_a = Vapor.addGlobalListener(.keydown, keyA);
    listener_b = Vapor.addGlobalListener(.keydown, keyB);
}

fn removeListenerA() void {
    if (listener_a) |id| _ = Vapor.removeGlobalListener(.keydown, id);
    listener_a = null;
}

fn listenersPage() void {
    Box().id("listeners-page").children({
        Button(addListeners, .{}).id("add-listeners").children({
            Text("Add").end();
        });
        Button(removeListenerA, .{}).id("remove-a").children({
            Text("Remove A").end();
        });
        Button(rerenderOnly, .{}).id("listeners-refresh").children({
            Text("Refresh").end();
        });
        TextFmt("{d}/{d}", .{ key_a, key_b }).id("key-count").end();
    });
}

// ── /listen : Element.listen outlives renders and does not rerender ───────

var listen_element: Vapor.Element = .{};
var listener: ?Vapor.Listener = null;
var listen_hits: u32 = 0;
var listen_renders: u32 = 0;
var listen_target_shown = true;

fn targetClicked(step: u32, _: *Vapor.Event) void {
    listen_hits += step;
}

fn startListening() void {
    listener = listen_element.listen(.click, targetClicked, .{@as(u32, 2)});
}

fn stopListening() void {
    if (listener) |l| l.remove();
    listener = null;
}

fn toggleListenTarget() void {
    listen_target_shown = !listen_target_shown;
    // The listener goes with its element; the handle is stale now.
    if (!listen_target_shown) listener = null;
}

fn listenPage() void {
    listen_renders += 1;
    Box().id("listen-page").children({
        if (listen_target_shown) {
            Box().id("listen-target").ref(&listen_element).children({
                Text("Target").end();
            });
        }
        Button(startListening, .{}).id("listen-start").children({
            Text("Listen").end();
        });
        Button(stopListening, .{}).id("listen-stop").children({
            Text("Stop").end();
        });
        Button(toggleListenTarget, .{}).id("listen-toggle").children({
            Text("Toggle").end();
        });
        Button(rerenderOnly, .{}).id("listen-refresh").children({
            Text("Refresh").end();
        });
        TextFmt("hits={d} listeners={d}", .{ listen_hits, Vapor.lib.element_listeners.count() }).id("listen-state").end();
        TextFmt("{d}", .{listen_renders}).id("listen-renders").end();
    });
}

// ── /focus : onFocus and onBlur on ordinary elements ───────────────────────

var focus_count: u32 = 0;
var blur_count: u32 = 0;

fn focused(_: *Vapor.Event) void {
    focus_count += 1;
}

fn blurred(_: *Vapor.Event) void {
    blur_count += 1;
}

var field_focus_count: u32 = 0;
var field_change_count: u32 = 0;

fn fieldFocused(_: *Vapor.Event) void {
    field_focus_count += 1;
}

fn fieldChanged(_: *Vapor.Event) void {
    field_change_count += 1;
}

fn focusPage() void {
    Box().id("focus-page").children({
        Button(toggleHidden, .{}).id("focus-target").onFocus(focused).onBlur(blurred).children({
            Text("Focus me").end();
        });
        TextField(.string).id("focus-field").onFocus(fieldFocused).onChange(fieldChanged, .{}).end();
        TextFmt("{d}/{d}", .{ focus_count, blur_count }).id("focus-count").end();
        TextFmt("{d}/{d}", .{ field_focus_count, field_change_count }).id("field-count").end();
    });
}

// ── /hooks : Hooks(.{ .mounted, .destroy }) fire around a block ────────────

var hooked = false;
var hook_mounts: u32 = 0;
var hook_destroys: u32 = 0;

fn toggleHooked() void {
    hooked = !hooked;
}

fn rerenderOnly() void {}

fn hooksMounted() void {
    hook_mounts += 1;
}

fn hooksDestroyed() void {
    hook_destroys += 1;
}

fn hooksPage() void {
    Box().id("hooks-page").children({
        Button(toggleHooked, .{}).id("toggle-hooks").children({
            Text("Toggle").end();
        });
        Button(rerenderOnly, .{}).id("hooks-refresh").children({
            Text("Refresh").end();
        });
        if (hooked) {
            Vapor.Hooks(.{ .mounted = hooksMounted, .destroy = hooksDestroyed })({
                Text("inside").id("hooked").end();
            });
        }
        TextFmt("{d}/{d}", .{ hook_mounts, hook_destroys }).id("hooks-count").end();
    });
}

// ── /input : typing flows back into Zig state ──────────────────────────────

var name: []const u8 = "";

fn nameChanged(evt: *Vapor.Event) void {
    name = Vapor.dupe(evt.text(), .persist);
}

var secret: []const u8 = "";

fn input() void {
    Box().id("input-page").children({
        TextField(.string).id("name").bind(&name).onChange(nameChanged, .{}).end();
        TextFmt("Hello, {s}!", .{name}).id("greeting").end();
        // What the runtime sets when it creates an element, which a
        // prerendered page has to end up with too.
        TextField(.password).id("secret").bind(&secret).end();
        Link(.{ .url = "/a", .aria_label = "Go to page A" }).id("labelled-link").children({
            Text("A").end();
        });
        Button(noop, .{}).id("labelled-button").ariaLabel("Do nothing").children({
            Text("Nothing").end();
        });
    });
}

// ── /numbers : number fields bound to Zig values ──────────────────────────

var quantity: i32 = 3;
var price: f32 = 2.5;

fn numbers() void {
    Box().id("numbers-page").children({
        TextField(.int).id("quantity").bind(&quantity).end();
        TextField(.float).id("price").bind(&price).end();
        TextFmt("{d} at {d}", .{ quantity, price }).id("order").end();
    });
}

// ── /signin and /auth/callback : KeyStone's OAuth state ────────────────────

fn signIn() void {
    KeyStone.signInWithOauth(.google);
}

fn signInPage() void {
    Box().id("signin-page").children({
        Button(signIn, .{}).id("sign-in").children({
            Text("Sign in with Google").end();
        });
    });
}

fn callbackPage() void {
    Box().id("callback-page").children({
        Text(KeyStone.getAuthState().err orelse "none").id("auth-error").end();
    });
}

// ── /escape : text is text, never markup ───────────────────────────────────

fn escape() void {
    Box().id("escape-page").children({
        Text("<img src=x onerror=\"window.__xss = 1\">").id("payload").end();
    });
}

// ── /a and /b : client-side navigation, and memory across route changes ───

fn pageA() void {
    Box().id("page-a").children({
        Text("Page A").end();
        Link(.{ .url = "/b" }).id("to-b").children({
            Text("Go to B").end();
        });
        for (0..50) |i| {
            TextFmt("A row {d}", .{i}).end();
        }
    });
}

fn pageB() void {
    Box().id("page-b").children({
        Text("Page B").end();
        Link(.{ .url = "/a" }).id("to-a").children({
            Text("Go to A").end();
        });
        for (0..50) |i| {
            TextFmt("B row {d}", .{i}).end();
        }
    });
}

// ── /fetch : a request's lifecycle reaches the DOM ─────────────────────────

var request: ?*Vapor.Fetch.Request = null;
var fetched: []const u8 = "";

fn onFetched(result: Vapor.Fetch.Result) void {
    switch (result) {
        .ok => |response| fetched = Vapor.dupe(response.body, .persist),
        .err => |err| fetched = Vapor.dupe(err.message, .persist),
    }
}

fn fetchPage() void {
    if (request == null) {
        const req = Vapor.fetch("/api/greeting.txt", .{});
        req.handle(onFetched, .{});
        request = req;
    }
    Box().id("fetch-page").children({
        switch (request.?.state()) {
            .idle, .loading => Text("loading").id("fetch-state").end(),
            .ok => TextFmt("ok:{s}", .{fetched}).id("fetch-state").end(),
            .err => TextFmt("err:{s}", .{fetched}).id("fetch-state").end(),
        }
    });
}

// ── /storage : localStorage round trips, including floats ──────────────────

fn saveValues() void {
    Vapor.store("int", @as(u32, 42));
    Vapor.store("float", @as(f32, 2.5));
    Vapor.store("text", @as([]const u8, "zig"));
}

fn storagePage() void {
    Box().id("storage-page").children({
        Button(saveValues, .{}).id("save").children({
            Text("Save").end();
        });
        TextFmt("int={?d} float={?d} text={?s}", .{
            Vapor.load(u32, "int"),
            Vapor.load(f32, "float"),
            Vapor.load([]const u8, "text"),
        }).id("stored").end();
    });
}

// ── /urls : script URLs are blocked; other origins are not routed ──────────

fn urls() void {
    Box().id("urls-page").children({
        Link(.{ .url = "javascript:window.__pwned = 1" }).id("js-link").children({
            Text("script link").end();
        });
        Link(.{ .url = " JaVa\tScRiPt:window.__pwned = 2" }).id("js-link-obfuscated").children({
            Text("obfuscated script link").end();
        });
        Link(.{ .url = "https://example.com/elsewhere" }).id("external").children({
            Text("external").end();
        });
        Link(.{ .url = "/a" }).id("internal").children({
            Text("internal").end();
        });
    });
}

// ── /stale : renders that change nothing keep event targets current ─────

var stale_hovers: u32 = 0;

fn staleHovered(_: *Vapor.Event) void {
    stale_hovers += 1;
}

// Each render builds its nodes in a fresh frame arena, and resetting the
// arena from two renders back hands its buffers back to the allocator. In an
// app, other allocations (fetched data, say) soon reuse them; here every
// size class is filled with junk, so a node pointer kept from an older render
// reads garbage rather than a look-alike node.
fn staleRefresh() void {
    var size: usize = 1024;
    while (size <= 1024 * 1024) : (size *= 2) {
        const junk = Vapor.lib.allocator_global.alloc(u8, size) catch return;
        @memset(junk, 0xAA);
        Vapor.lib.allocator_global.free(junk);
    }
}

fn stalePage() void {
    Box().id("stale-page").children({
        Box().id("stale-target").onEvent(.mouseover, staleHovered, .{}).children({
            Text("Hover me").end();
        });
        TextFmt("hovers={d}", .{stale_hovers}).id("stale-hovers").end();
        Button(staleRefresh, .{}).id("stale-refresh").children({
            Text("Refresh").end();
        });
    });
}

// ── /drag : .createDraggable moves its element with the pointer ────────────

var drag: Vapor.Draggable = .{};
var drag_first_render = true;

fn dragPage() void {
    const d = &drag;
    if (drag_first_render) {
        drag_first_render = false;
        // A Draggable made without an element holds junk there (Debug fills
        // undefined memory with 0xAA); zero would hide the bug, since wasm
        // can write to address 0.
        d.element = @ptrFromInt(0xAAAA_AAA8);
    }
    Box().id("drag-page").children({
        Box()
            .id("drag-target")
            .width(.px(40))
            .height(.px(40))
            .background(.black)
            .createDraggable(d)
            .children({});
    });
}

// ── /mount-off : an element that stops having an onMount hook ─────────────

var mount_on = true;

fn mounted() void {}

fn toggleMount() void {
    mount_on = !mount_on;
}

fn mountOffPage() void {
    Box().id("mount-off-page").children({
        // The same element in the same place, with and without the hook.
        const target = Box().id("mount-off-target");
        if (mount_on) {
            target.onMount(mounted, .{}).children({});
        } else {
            target.children({});
        }
        Button(toggleMount, .{}).id("mount-off-toggle").children({
            Text("Toggle").end();
        });
    });
}

// ── /once : one event, one handler call ──────────────────────────────────

var once_keys: u32 = 0;
var once_overs: u32 = 0;

fn onceKey(_: *Vapor.Event) void {
    once_keys += 1;
}

fn onceOver(_: *Vapor.Event) void {
    once_overs += 1;
}

fn oncePage() void {
    Box().id("once-page").children({
        Box()
            .id("once-target")
            .tabIndex(0)
            .onEvent(.keydown, onceKey, .{})
            .onEvent(.mouseover, onceOver, .{})
            .children({
            Text("Target").end();
        });
        TextFmt("keys={d} overs={d}", .{ once_keys, once_overs }).id("once-count").end();
    });
}

// ── /aria : accessibility attributes follow state both ways ─────────────────

var aria_off = true;

fn toggleAria() void {
    aria_off = !aria_off;
}

fn ariaPage() void {
    Box().id("aria-page").children({
        // aria-disabled is written only while true.
        Box()
            .id("aria-target")
            .a11y(Vapor.Accessibility.init().setDisabled(aria_off))
            .children({
            Text("Target").end();
        });
        Button(toggleAria, .{}).id("aria-toggle").children({
            Text("Toggle").end();
        });
    });
}

// ── /focus-any : Element.focus works on any focusable element ─────────────

var focus_any_target: Vapor.Element = .{};

fn focusTheTarget() void {
    focus_any_target.focus();
}

fn noop() void {}

fn focusAnyPage() void {
    Box().id("focus-any-page").children({
        Button(noop, .{}).id("focus-any-target").ref(&focus_any_target).children({
            Text("Target").end();
        });
        Button(focusTheTarget, .{}).id("focus-any-go").children({
            Text("Focus it").end();
        });
    });
}

// ── /timeout : named timeouts replace, fire once, re-arm and free ──────────

var timeout_arms: u32 = 0;
var timeout_fires: u32 = 0;
var timeout_last: u32 = 0;
var timeout_chain_left: u32 = 0;

fn timeoutFired(arm: u32) void {
    timeout_fires += 1;
    timeout_last = arm;
}

/// Arms the same named timeout again: the pending one is replaced.
fn armTimeout() void {
    timeout_arms += 1;
    Vapor.timeout("browser-test-timeout", 150, timeoutFired, .{timeout_arms});
}

/// Runs three times: each run arms the next one under its own name.
fn chainStep() void {
    timeout_fires += 1;
    timeout_chain_left -= 1;
    if (timeout_chain_left > 0) Vapor.timeout("browser-test-chain", 30, chainStep, .{});
}

fn startChain() void {
    timeout_chain_left = 3;
    Vapor.timeout("browser-test-chain", 30, chainStep, .{});
}

fn timeoutPage() void {
    Box().id("timeout-page").children({
        Button(armTimeout, .{}).id("timeout-arm").children({
            Text("Arm").end();
        });
        Button(startChain, .{}).id("timeout-chain").children({
            Text("Chain").end();
        });
        TextFmt("fires={d} last={d} pending={d}", .{
            timeout_fires,
            timeout_last,
            Vapor.lib.ctx_callback_registry.count(),
        }).id("timeout-state").end();
    });
}

// ── /transition : a declared transition runs when state changes the style ──

var transition_wide = false;

fn toggleTransition() void {
    transition_wide = !transition_wide;
}

/// The same tree on both pages, so navigating reuses the box (ids are
/// positional) with another width.
fn transitionBox(width: f32) void {
    Box()
        .id("transition-box")
        .width(.px(width))
        .height(.px(20))
        .background(.hex("#336699"))
        .transition(.{ .properties = &.{.width}, .duration = 300, .timing = .linear })
        .end();
}

/// Opts in to animating across pages too.
fn morphBox(width: f32) void {
    Box()
        .id("morph-box")
        .width(.px(width))
        .height(.px(20))
        .background(.hex("#993366"))
        .morph(true)
        .end();
}

fn transitionPage() void {
    Box().id("transition-page").children({
        Button(toggleTransition, .{}).id("transition-toggle").children({
            Text("Toggle").end();
        });
        Link(.{ .url = "/transition-b" }).id("transition-to-b").children({
            Text("To B").end();
        });
        transitionBox(if (transition_wide) 300 else 60);
        morphBox(60);
    });
}

fn transitionPageB() void {
    Box().id("transition-page").children({
        Button(toggleTransition, .{}).id("transition-toggle").children({
            Text("Toggle").end();
        });
        Link(.{ .url = "/transition" }).id("transition-to-b").children({
            Text("To A").end();
        });
        transitionBox(400);
        morphBox(400);
    });
}

// ── /playground : an iframe runs wasm the page hands it ────────────────────

/// The wasm to run is this app's own: in the iframe it renders "/", so the
/// counter on the home page shows that it booted and handles events. The
/// binding exists only in the browser, not in the prerendering generator.
fn runPlayground() void {
    const url = "/zig-out/bin/vapor.wasm";
    if (Vapor.lib.isWasi) Vapor.Wasm.runPlaygroundWasm(url.ptr, url.len);
}

fn playgroundPage() void {
    Box().id("playground-page").children({
        Button(runPlayground, .{}).id("playground-run").children({
            Text("Run").end();
        });
        Vapor.Iframe("/playground.html").id("playground-frame").end();
    });
}

// ── /users/:id : dynamic segments ──────────────────────────────────────────

fn userPage() void {
    Box().id("user-page").children({
        TextFmt("user={?s}", .{Vapor.routeParam("id")}).id("user-id").end();
        Link(.{ .url = "/users/42/edit" }).id("to-edit").children({
            Text("Edit").end();
        });
    });
}

fn userEditPage() void {
    Box().id("user-edit-page").children({
        TextFmt("editing={?s}", .{Vapor.routeParam("id")}).id("user-edit-id").end();
    });
}

fn newUserPage() void {
    Text("New user form").id("new-user").end();
}

// Registered as /error: what vapor renders for a path no page matches.
fn notFound() void {
    Text("Not found").id("not-found").end();
}

// ── /resize : .onResize across removal and an element rebuilt under a new id

var resize_shown = true;
var resize_wide = false;
var resize_alt_id = false;
var resize_renders: u32 = 0;
var resized_width: f32 = 0;

fn sized(entry: Vapor.Kit.ResizeEntry) void {
    resized_width = entry.width;
    Vapor.cycle();
}

fn widenResized() void {
    resize_wide = !resize_wide;
}

fn toggleResized() void {
    resize_shown = !resize_shown;
}

fn swapResizedId() void {
    resize_alt_id = !resize_alt_id;
}

fn rerenderResize() void {
    resize_renders += 1;
}

fn resizePage() void {
    Box().id("resize-page").children({
        if (resize_shown) {
            Box().id(if (resize_alt_id) "resized-b" else "resized-a")
                .onResize(sized, .{})
                .width(.px(if (resize_wide) 300 else 200))
                .height(.px(20))
                .end();
        }
        TextFmt("{d}", .{resized_width}).id("resized-width").end();
        TextFmt("{d}", .{resize_renders}).id("resize-renders").end();
        Button(widenResized, .{}).id("widen").children({
            Text("Widen").end();
        });
        Button(toggleResized, .{}).id("toggle-resized").children({
            Text("Toggle").end();
        });
        Button(swapResizedId, .{}).id("swap-resized").children({
            Text("Swap").end();
        });
        Button(rerenderResize, .{}).id("rerender-resize").children({
            Text("Render").end();
        });
    });
}

// ── /responsive : .hideOn and .showOn per screen size ─────────────────────

fn responsivePage() void {
    Box().id("responsive-page").children({
        Box().id("mobile-only").showOn(.mobile).children({
            Text("mobile").end();
        });
        Box().id("tablet-up").showOn(.tablet).children({
            Text("tablet and up").end();
        });
        Box().id("desktop-only").showOn(.desktop).children({
            Text("desktop").end();
        });
        // .hideOn and .responsive on the same screen size, in both orders.
        Box().id("hidden-then-padded").hideOn(.mobile).responsive(.mobile, .{ .padding = .all(4) }).children({
            Text("not on phones").end();
        });
        Box().id("padded-then-hidden").responsive(.mobile, .{ .padding = .all(4) }).hideOn(.mobile).children({
            Text("not on phones either").end();
        });
        // Spacing and direction per screen size; a margin-only override keeps
        // the padding.
        Vapor.Stack().id("spaced").padding(.all(20)).responsive(.mobile, .{ .padding = .all(4), .direction = .row }).children({
            Text("a").end();
            Text("b").end();
        });
        Box().id("margined").padding(.all(20)).responsive(.mobile, .{ .margin = .all(6) }).children({
            Text("m").end();
        });
    });
}

// ── /svg : an Svg whose markup changes ─────────────────────────────────────

var svg_wide = false;

fn widenSvg() void {
    svg_wide = !svg_wide;
}

fn svgPage() void {
    Box().id("svg-page").children({
        Vapor.Svg(.{ .svg = if (svg_wide)
            \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 100"><rect id="wide-rect" width="400" height="100"/></svg>
        else
            \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 100" preserveAspectRatio="none"><circle id="dot" r="10"/></svg>
        }).id("drawing").end();
        Button(widenSvg, .{}).id("widen-svg").children({
            Text("Widen").end();
        });
    });
}
