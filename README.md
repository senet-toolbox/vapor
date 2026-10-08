# Vapor

A UI framework for Zig that compiles to WebAssembly.

Vapor gives you a declarative component API, a keyed reconciler, and a CSS
compiler, with a memory model built for the browser: per-route arenas, interned
strings, and style data packed behind pointer groups so the node tree stays
small. You write pages and components in Zig; Vapor produces the DOM operations
and the stylesheet.

> **Status: alpha.** The API is still moving. Breaking changes bump the major
> version and are documented with migration notes in
> [CHANGELOG.md](CHANGELOG.md), but there is no deprecation cycle yet. It is
> used in production by one site ([senet.run](https://senet.run)).

## Requirements

- **Zig 0.16.0** — Vapor tracks Zig closely and will not build on older versions.
- A WebAssembly host. The shipping target is `wasm32-wasi`.

## Installation

```bash
zig fetch --save git+https://github.com/senet-toolbox/vapor
```

Or, while developing against a local checkout:

```zig
// build.zig.zon
.dependencies = .{
    .vapor = .{ .path = "../vapor" },
},
```

## Setup

Vapor requires two modules from your application. It will not compile without
them — they are how the framework learns your icon set and your theme.

| Module   | Provides                                        |
| -------- | ----------------------------------------------- |
| `config` | `IconTokens` — the icons your app can reference  |
| `theme`  | `ThemeTokens` and `Colors` — your design tokens  |

```zig
// build.zig
const config_module = b.addModule("config", .{
    .root_source_file = b.path("src/config.zig"),
    .optimize = optimize,
});

const vapor_dep = b.dependency("vapor", .{ .target = target, .optimize = optimize });
const vapor_module = vapor_dep.module("vapor");
vapor_module.addImport("config", config_module);

// theme depends on vapor, and vapor depends on theme — a deliberate cycle,
// which Zig resolves at the module level.
const theme_module = b.addModule("theme", .{
    .root_source_file = b.path("src/Theme.zig"),
    .target = target,
    .optimize = optimize,
    .imports = &.{.{ .name = "vapor", .module = vapor_module }},
});
vapor_module.addImport("theme", theme_module);
```

Vapor also ships the JavaScript runtime that loads the wasm and applies its
DOM operations. Install it next to your wasm so the two always come from the
same Vapor version:

```zig
// build.zig, after b.installArtifact(exe)
b.getInstallStep().dependOn(&b.addInstallBinFile(
    vapor_dep.namedLazyPath("runtime"),
    "bundle.min.js",
).step);
```

and load it from your HTML with `<script type="module" src="/bundle.min.js">`
(served from `zig-out/bin/`). `metal vapor create` sets all of this up.

The two modules are small:

```zig
// src/config.zig
pub const IconTokens = struct {
    web: ?[]const u8 = null,
    svg: ?[]const u8 = null,

    pub const search = IconTokens{ .web = "bi bi-search", .svg = "<svg …</svg>" };
};
```

```zig
// src/Theme.zig
const Vapor = @import("vapor");
const Color = Vapor.Types.Color;

pub const ThemeTokens = enum(u8) { none, text, background, primary };

pub const Colors = struct {
    text: Color = .black,
    background: Color = .white,
    primary: Color = .vapor_blue,
};

pub const Light = Colors{};
pub const Dark = Colors{ .text = .white, .background = .black };
```

## A minimal app

```zig
const std = @import("std");
const Vapor = @import("vapor");
const Theme = @import("theme");

fn HomePage() void {
    Vapor.Center().size(.full).children({
        Vapor.Text("Hello, world!").end();
    });
}

fn initPages() void {
    Vapor.Page(.{ .route = "/" }, HomePage, null);
}

// Called from JavaScript once the module is instantiated.
pub export fn init() void {
    Vapor.init(.{});
    Vapor.Animation.new();

    Vapor.setGlobalStyleVariables(.{
        .themes = &.{
            .{ .name = "light", .theme = Theme.Light, .default = true },
            .{ .name = "dark", .theme = Theme.Dark },
        },
    });

    initPages();
}
```

## Core concepts

### Components

Components are built with a fluent builder. Containers take a `children` block;
leaves end with `.end()`.

```zig
Vapor.Box()
    .size(.full)
    .padding(.all(16))
    .children({
        Vapor.Heading(1, "Title").end();
        Vapor.Text("Body copy").end();
        Vapor.Button(onClick, .{}).children({
            Vapor.Text("Click me").end();
        });
    });
```

The full set is re-exported from the root: `Box`, `Row`, `Stack`, `Center`,
`Text`, `TextFmt`, `Heading`, `Button`, `Link`, `Image`, `Svg`, `Icon`, `List`,
`Table`, `Form`, `TextField`, `TextArea`, and others.

### Stable identity — `.id()`

Vapor names each element automatically, from its type and its position among
its siblings. That is fine for static layout, but it means **an element that
moves gets a new name**, and the reconciler — which matches old to new by name —
sees a delete and an insert rather than a move.

Give anything that can move an explicit id:

```zig
for (todos.items) |todo| {
    Vapor.Row().id(todo.id).children({      // survives reordering
        Vapor.Text(todo.title).end();
    });
}
```

Reach for it when a list can reorder, when items are inserted or removed
anywhere but the end, or when an element sits after a sibling that renders
conditionally. The symptom of a missing id is an element that appears twice for
a moment, or that loses its DOM state (scroll position, focus, an in-progress
CSS transition) when something above it changes.

The value also becomes the element's DOM id, so it must be unique in the
document.

### Pages, layouts and hooks

```zig
Vapor.Page(.{ .route = "/docs" }, DocsPage, null);

// Wrap a route subtree in shared chrome.
try Vapor.registerLayout("/docs", docsLayout, .{ .reset = true });

// Run before or after navigation.
_ = Vapor.registerHook("/docs", beforeNavigate, .before);
```

### Memory

Vapor never asks you for an allocator. It exposes four arenas with different
lifetimes, and you choose which one a value belongs to:

| Arena      | Lives for                                     |
| ---------- | --------------------------------------------- |
| `.frame`   | one render pass — the default for UI strings   |
| `.view`    | the current route                              |
| `.request` | one in-flight request                          |
| `.persist` | the life of the application                    |

```zig
const label = Vapor.frame.fmt("{d} items", .{count}); // freed after this frame
const name  = Vapor.dupe(user.name, .persist);        // survives navigation
```

### Data fetching

`Fetch` coalesces requests so several components can ask for the same resource
without duplicating it. `GET` and `OPTIONS` coalesce by URL; other methods get
their own slot unless you give them an explicit `key`.

```zig
const req = Fetch.fetch("/api/accounts", .{ .method = .GET });
req.handle(onAccounts, .{});

// Two mutations with the same key coalesce; without one they stay separate.
_ = Fetch.fetch("/api/sync", .{ .method = .POST, .key = "account-sync" });
```

### Authentication

`Vapor.KeyStone` wraps OAuth sign-in, session storage, token refresh and
authenticated fetch for Google, GitHub, Apple and Azure. It expects a backend
that exchanges the OAuth code — tokens are never minted in the browser.

## Build options

| Option     | Default | Effect                                    |
| ---------- | ------- | ----------------------------------------- |
| `-Dstatic` | `false` | Static-render mode                        |
| `-Datomic` | `true`  | Atomic render cycle                       |

## Bundle size

Size depends almost entirely on what your application pulls in — icon sets and
component libraries dominate. Build with `-Doptimize=ReleaseSmall` for the
smallest output, and measure your own binary rather than trusting a headline
number.

## Development

```bash
zig build          # build, and type-check the whole library
zig build check    # type-check only, for wasm32-wasi and the host
zig build test     # run the test suite (also runs check)
```

`zig build check` is worth explaining. Zig analyses declarations lazily, so a
function nothing references is parsed but never type-checked — which means a
library can compile clean while parts of its public API are broken, and users
discover it one API at a time. `src/check.zig` references every public
declaration in every module, so compiling it forces full semantic analysis.
`build.zig` additionally fails the step if a new file under `src/` is not listed
there, so nothing can silently opt out.

It runs against three targets: `wasm32-wasi` (what ships), your host, and
`x86_64-linux` explicitly — the last so that a macOS developer sees the same
result CI does. Native hosts need libc and position-independent code where wasm
does not, and macOS supplies both implicitly, so a Linux-only failure is
otherwise invisible until CI.

### The JS runtime

The runtime source lives in `js/src/`; `js/dist/bundle.min.js` is the built
copy that apps install, committed so that apps need no Node toolchain. After
editing `js/src`, rebuild it (needs `npx`; esbuild is pinned):

```bash
zig build runtime
```

`zig build test` runs `check-abi`, which fails if any `extern fn` in `src/`
has no implementation in the bundle — the browser refuses to instantiate a
module with a missing import, so this would otherwise surface as a LinkError
in every app that reaches the function. CI also rebuilds the bundle and fails
if it differs from the committed one.

## Security notes

- Text and attribute values are HTML-escaped in the SSR path.
- `Vapor.Html(...)` and `Svg` emit raw markup **by design** and are not escaped.
  Treat them like `dangerouslySetInnerHTML`: never pass user input.

## License

MIT — see [LICENSE](LICENSE).
