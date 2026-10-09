# Changelog

All notable changes to this project are documented here. This project follows
[Semantic Versioning](https://semver.org/): breaking changes bump the major
version and are listed with a migration note.

## [Unreleased]

### Internal cleanup (no API change)

- The remaining oversized files are split by concern, each re-exporting what
  it moved so every public name still resolves at its old path (checked
  mechanically, along with the wasm's export and import tables):
  - `convertStyleCustomWriter.zig` (2,242 lines): `css/` (values,
    background, keyframes, exports).
  - `Components.zig` (2,182): `ComponentBuilder`'s methods live in
    `builder/` (elements, attributes, events, layout, style, tree) and the
    struct aliases them, so `Box().padding(...)` is unchanged.
  - `TextField.zig` (1,641): the same, under `text_field/`.
  - `Configuration.zig` (1,631): the style packers move to `configure/`.
  - `Animation.zig` (1,498): presets and the removal queue move to
    `animation/`.
  - JS runtime: `wasi.js` (2,422) becomes `env/` (one module per binding
    domain) plus `instance.js`, `struct_bridge.js` and `event_type.js`;
    `traversal.js` and `wasi_obj.js` lose element construction, teardown and
    the memory readers to their own modules.
- `TextField.BuilderClose(state_type)` now returns one builder type,
  `TextFieldBuilder`, for every state type, as `Components.Builder` already
  did. Only `.pure` was ever instantiated.
- Removed the remaining commented-out code and two dead runtime bindings.

## [2.2.0] — 2026-10-09

### Fetch API

`Vapor.fetch(url, .{})` starts a request (GET unless `.method` says
otherwise); `Vapor.Fetch` holds the types: `Request` (was `Fetch.Fetch`),
`Result`, `Response`, `Options` (was `Kit.HttpReq`), `Headers`, `Method`
(was `Kit.Methods`), `State`. The old names still compile as deprecated
aliases.

Requests are now serialized with JSON escaping (a header value containing a
quote produced invalid JSON and the request failed), and `mode`, `redirect`,
`referrer_policy`, `integrity` and `use_credentials`, which were accepted but
never sent, now reach the browser's fetch. Removed the unused
`fetchWithAbortWasm`, `abortFetchWasm`, `fetchWithProgressWasm` and
`fetchJsonWasm` bindings (1.3 KB of runtime).

### Internal cleanup (no API change)

- Removed ~2,250 lines: dead private declarations, exports no runtime called,
  and commented-out code (an old Transition implementation alone was 354).
- `Vapor.zig` (3,082 lines) is split by responsibility into Storage, Log,
  Hex, Query, Memory, Timers, Events, Hooks, Exports and StaticGenerator;
  `types.zig` (2,859) into `types/` (color, sizing, box, background, packed,
  input, style). Both re-export everything they moved: every previously
  public name still resolves at its old path (checked mechanically).

### Browser APIs load on demand, and work

Bindings for canvas, audio, geolocation, IndexedDB, websockets, drag and drop,
session storage, notifications, fullscreen, selection, mutation observers,
performance timing, pointer lock, vibration, screen orientation, battery and
Web Share were implemented in the runtime but never added to the wasm's
import object, so an app calling any of them failed to load with a LinkError.

They now live in a second runtime file, `browser.min.js`, which the core
runtime fetches from beside itself only when the app's wasm imports one of
them. Apps that use none never download it; the core runtime is 23% smaller
(78.8 KB to 60.5 KB). On the Zig side they moved from `Vapor.Wasm` to
`Vapor.Browser`.

**Migration:** call them as `Vapor.Browser.audioPlayWasm(...)` etc., and
install the second file next to the first:

```zig
b.getInstallStep().dependOn(&b.addInstallBinFile(
    vapor_dep.namedLazyPath("runtime-browser"),
    "browser.min.js",
).step);
```

The runtime bundles are ES modules now (load them with
`<script type="module">`, as metal's template always has).

A browser test loads an app that imports every binding vapor declares, so a
binding that exists in the runtime but is not wired in fails CI; the text
check `check-abi` could not catch that.

## [2.1.0] — 2026-10-08

A correctness release, driven by new end-to-end tests that run apps in
headless Chrome (`zig build browser-test`), in Debug and ReleaseSmall, both
client-rendered and from prerendered pages.

### Security

- **`javascript:` URLs ran.** Link hrefs, iframe sources and
  `setWindowLocation` used app strings as-is, so a link built from user input
  could run script in the app's origin. `javascript:`/`vbscript:` URLs are now
  blocked (case and embedded whitespace normalised as browsers do); a blocked
  link has no href and is reported with `console.error`.

### Fixed

- **Buttons with `.id()` all ran the last button's handler.** `.id()` gave the
  node a new uuid but kept the hash JS reports clicks by, and handed the old
  uuid to the next sibling, which overwrote the callback. An `.id()`'d
  TextField threw in JS for the same reason.
- **Removing any node trapped unless the app called `Animation.new()`**, so
  keyed-list changes and navigation failed with `RuntimeError: null function`.
  `Vapor.init` now creates the Animation, Edges and Polygons registries;
  calling `Animation.new()` and friends yourself is harmless but unnecessary.
- **Links:** every click was routed internally, so links to other sites could
  not leave the app and cmd/ctrl-click could not open a tab. Only plain clicks
  on same-origin links are routed now, and each adds exactly one history entry.
- **Router:** `/users/:id/edit` could not be registered next to `/users/:id`;
  `/users/new` was routed to `/users/:id`. Fixed, see below.
- **`load(u32, key)` on a missing key returned 0** instead of null; negative,
  64-bit and float values could not round-trip. All numbers and bools now go
  through the string binding.
- **`.hex("#fff")` was black** and alpha digits were ignored: only `#rrggbb`
  was parsed. `#rgb`, `#rgba` and `#rrggbbaa` work.
- `minWidth`/`maxWidth`/`minHeight`/`maxHeight` with an unsupported sizing, and
  `.animationEnter` with an unregistered name, were undefined behaviour in
  release builds; they are now logged and ignored. 105 other `unreachable`s on
  error paths are `@panic`s with a message, so release builds fail the same
  way Debug does.
- Static generation wrote dynamic routes to literal `release/users/:id/`
  directories. They are skipped, and `release/app.html` is written as the
  client-rendered fallback for static hosts.
- The runtime no longer logs internal debugging to production consoles.

### Added

- `Vapor.routeParam("id")`: the value of a dynamic segment during render.
- `<html data-vapor-ready>` and a `vapor:ready` window event once the first
  render (or hydration) is done.
- `globalThis.__VAPOR_DEBUG__ = true` shows the runtime's diagnostics.

### Behaviour changes

| Before | After |
| --- | --- |
| `/users` rendered the `/users/:id` page with no id | it renders `/error`, unless `/users` is registered |
| `load(u32, missing)` returned `0` | returns `null` |
| values stored with `store(int)` were written by a `u32` binding | written as decimal text; old values still parse |

## [2.0.2] — 2026-10-08

### The JS runtime ships with vapor

The runtime that loads the wasm and applies its DOM operations used to live in
the docs site and reach apps as a frozen copy inside metal, while metal fetched
vapor's latest commit — so any change to the Zig↔JS boundary broke new apps.
It now lives in `js/src`, ships prebuilt as `js/dist/bundle.min.js`, and is
exposed as the named lazy path `runtime`. `zig build test` checks that every
`extern fn` has a JS implementation (`check-abi`).

**Migration:** install the runtime from the dependency instead of keeping your
own copy, and serve it as `/bundle.min.js`:

```zig
b.getInstallStep().dependOn(&b.addInstallBinFile(
    vapor_dep.namedLazyPath("runtime"),
    "bundle.min.js",
).step);
```

### Fixed

- **`Fetch` without a manual `Fetch.init()` trapped.** `Vapor.init` did not
  initialize it, so an app's first `fetch()` read an undefined hashmap
  (`RuntimeError: null function`). `Vapor.init` now does; an extra
  `Fetch.init()` before any request is harmless.
- **`Kit.routePush` failed to link.** Its JS side, `routePushWASM`, did not
  exist; any app reaching it failed to instantiate. Added.
- **`store`/`load` with `f32`.** `store` passed a float to a `u32` binding (a
  compile error) and `load` used a binding that did not exist. Both now go
  through the string binding.
- The static generator looked for `bundle.min.js` only in the project root and
  printed `Copy error: error.FileNotFound` for metal-scaffolded apps.

### Breaking changes

| Removed | Why |
| --- | --- |
| `Wasm.trackAllocWasm`, `Wasm.runOnAnimationFrameWasm`, `Wasm.tick`, `Wasm.getLocalStorageF32Wasm`, `Wasm.getLocalStorageUIntWasm` | no JS implementation ever existed, so calling any of them made the module fail to load |

## [2.0.0] — 2026-08-11

A correctness and hardening release. Four memory-safety bugs are fixed, a
type-checking gate was added that surfaced 68 latent compile errors across 22
modules, and the public API changed in several places as a result.

### Security

- **`Writer` performed no bounds checking.** Every write was a raw `@memcpy`
  into a fixed 4096/8192-byte buffer, and the `!void` return type never actually
  produced an error. In `ReleaseFast`/`ReleaseSmall` — the modes used to ship
  wasm — an oversized style silently wrote past the end of the buffer. Writes
  are now bounds-checked and truncate cleanly, reporting the first overflow.
- **JWT signature lengths were unchecked.** `verify` copied the decoded
  signature into a fixed-size array with `@memcpy` without comparing lengths.
  The decoded length is attacker-controlled, so a crafted token caused a panic
  under ReleaseSafe and a buffer overflow under ReleaseFast/ReleaseSmall. A
  wrong-length signature is now `error.InvalidSignature`.
- **The SSR path did not escape HTML.** Text nodes and attribute values were
  written into the served document verbatim, so any value containing markup
  became markup. Text and attributes are now escaped. `Vapor.Html(...)` and
  `Svg` remain raw by design — treat them like `dangerouslySetInnerHTML`.

### Breaking changes

| Before | After | Why |
| --- | --- | --- |
| `JWT.DecodingKey.fromEs256Bytes([N]u8)` | `fromEs256Sec1([]const u8)` | ECDSA public keys are SEC1-encoded and accept compressed or uncompressed forms; the old fixed-array signature could not express either |
| `JWT.DecodingKey.fromEs384Bytes([N]u8)` | `fromEs384Sec1([]const u8)` | as above |
| `DateTime.addDays(...) DateTime` | `addDays(...) !DateTime` | negative day counts can land before the epoch, which `fromTimestamp` rejects |
| `.gradient(types.Background)` | `.gradient(types.Color)` | `types.Background` no longer exists; the field it assigns is `?Color` |
| `.hoverBackground(types.Background)` | `.hoverBackground(types.Color)` | as above |
| `Draggable.element: Binded` | `element: *Binded` | `init` always took a pointer; the value field could never be constructed |
| `printUIRouteTree(u32)` | `printUIRouteTree([]const u8)` | routes are string paths everywhere else |
| `Writer.write(...) !void` | `... error{OutOfSpace}!void` | the old error set was empty, so `catch` branches were dead code that silently type-checked |

**Removed** — `.key()` on the component builders, along with `UINode.key`. It
assigned a field that nothing in the library ever read, so it silently did
nothing. `.id()` is the real keying mechanism: it writes the uuid directly, so
identity survives a move. Anything using `.key()` should use `.id()`.

Also removed — each of these referenced types, fields or functions that no
longer existed and could not compile if called:

- `Vapor.ThemeType`, `Vapor.SrcComponent` — dangling re-exports pointing at nothing
- `lib/helpers.zig` (`generateUUID`, `UUID`) — needed a time and entropy source
  that Zig 0.16 no longer provides ambiently on freestanding wasm
- `Element.removeFromParent` — called `Vapor.removeFromParent`, which never existed
- `Vapor.addRoute`, `Vapor.end` — superseded, and referencing removed APIs
- `UIContext.endContext`, `createStack`, `traverse`, `traverseChildren` — a dead
  `RenderCommand` tree layer calling allocator methods that no longer exist

**Behavioural notes:**

- `Writer.size` is now `buffer.len - 1`. The last byte is reserved so callers
  can always write their NUL terminator at `pos`; these buffers are handed to JS
  as C strings.
- `types.TextDecorationType` gained a `blink` member. Exhaustive switches over
  it need a new prong.
- `types.color_theme` is now `var`, not `const`. `switchColorTheme()` mutates
  it, which previously could not compile.

### Added

- **`zig build check`** — a type-checking gate. Zig analyses declarations
  lazily, so unreferenced code is parsed but never type-checked; this is how 68
  errors accumulated unnoticed across 22 modules. `src/check.zig` references
  every public declaration in every module, and `build.zig` fails if a new file
  under `src/` is not listed. Runs against `wasm32-wasi` and the host. Wired
  into both `zig build` and `zig build test`. Runs against three targets:
  `wasm32-wasi`, the host, and `x86_64-linux` explicitly, so a macOS developer
  sees what CI sees.
- `StringTable.handleOf` — look up an interned string's handle without
  interning it. Lets `Vapor.unpin([]const u8)` work.
- `Kit.Fetch` and `Kit.Response` — aliases into `Fetch.zig`, where the HTTP
  layer now lives.
- `Vapor.StateType` — re-export that `comptime.zig` already claimed to provide.
- MIT `LICENSE` file, which the README had referenced without it existing.
- Test suite grew from 28 to 51 tests, covering `Writer` bounds, JWT signature
  lengths, HTML escaping, the style compiler's truncation boundary, keyed
  reconciliation, and compile-checking every example in the README.

### Fixed

- **`TextField.id()` did not key the node.** It set `_id`, which reached the
  uuid later through the style, but never returned the node's unkeyed slot — so
  a conditionally-rendered field with an id renumbered all of its unkeyed
  siblings. It now behaves exactly like `.id()` on the element builders. The
  shared logic lives on `UINode.refundUnkeyedSlot`.
- **`.id()` and `.src()` could corrupt sibling naming, or panic.** Both refund
  the "unkeyed slot" that automatic naming took for the node, but nothing
  tracked whether the refund had already happened. `.src(...).id(...)`, or two
  `.id()` calls, decremented twice for one slot — renumbering every later
  sibling, and overflowing the `usize` when the count was already zero. A
  `uuid_is_user_set` flag now makes the refund happen exactly once.

- `Animation.RemovalQueue.release` freed memory it did not own — `uuid` is
  borrowed from the `UINode`.
- `HashStyle` hashed `v.animation` by pointer address. It is frame-arena
  allocated, so identical styles hashed differently on every frame.
- Bridge's timeout dispatch pointed at three registries that no longer existed,
  and nine of its wasm exports lacked a calling convention, so they could not be
  exported at all.
- `Configuration.configurePlainByNode` was missing the `.radio` prong that
  `configureByNode` already had.
- `Kit.Window.params` and `Element.selection` fell off the end of non-void
  functions on their non-wasm paths.
