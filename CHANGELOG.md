# Changelog

All notable changes to this project are documented here. This project follows
[Semantic Versioning](https://semver.org/): breaking changes bump the major
version and are listed with a migration note.

## [3.5.1] — 2026-10-27

### Fixed

- An `Svg` whose markup changed was redrawn inside the old `<svg>`, which
  kept the old `viewBox` and scaled the new drawing to fit it. Charts that
  measure their box and redraw (opaque's Chart) were drawn too small. The
  element now takes the new markup's attributes and children in place.

## [3.5.0] — 2026-10-26

Pages that work on phones: show and hide by screen size, and responsive
styles that do what they say.

### Added

- `.hideOn(platform)` and `.showOn(platform)` hide or show an element by
  screen size, in CSS, so prerendered pages are right on phones too. See
  "Screen sizes" in the README.

### Fixed

- `.responsive(.tablet, ...)` did nothing: tablet overrides were never
  packed. They now apply from 768px.
- A responsive style could hide an element but not show it again; any
  explicit `flex_type` now applies on its screen size.
- Any responsive override on a Stack also wrote `display: flex;
  flex-direction: row`, so on that screen size the column became a row
  (a phone override of a column's width laid its sections side by side).
  An override now writes only what it sets, keeping the element's
  direction, and `.direction` alone takes effect.
- Responsive `padding` and `margin` were accepted and ignored. They now
  apply, each only when the screen size sets it.
- `.maxWidth(.percent(n))` and `.maxHeight(.percent(n))` wrote nothing. They
  now write `max-width`/`max-height`. Note that `width`, `minWidth` and
  `maxWidth` share one slot (the last call wins); for a fixed width that
  never overflows use `.inlineStyle("max-width: 100%", .{})`.
- `.onResize` kept observing elements after they left the page, and wasm
  logged "Resize Ctx Callback Not found" for them (e.g. after crossing the
  768px breakpoint). The runtime now stops observing them.
- `.onResize` on a prerendered page never fired: it observed the prerendered
  element, which the app replaces when it takes the page over. Elements are
  now observed once the render is on the page, and only once each.
- `.onResize` recorded its element again on every render, in memory that is
  never freed.
- The shared observer behind `.onResize` was declared `undefined` instead of
  `null`, so depending on the build it could count as already created and
  never be made: no resize callback fired and the runtime warned
  "ResizeObserver ... not found" (seen in ReleaseSmall builds).

## [3.4.1] — 2026-10-26

### Fixed

- The package left out tools/release.zig, so `addRelease` failed in apps
  that fetch vapor ("tools/release.zig file_hash FileNotFound"). It is now
  part of the package.

## [3.4.0] — 2026-10-26

A release build for deploying, with files named by their contents; and
prerendered pages come up with everything the runtime gives an element.

### Added

- `addRelease` in vapor's build.zig builds the site to deploy into
  `release/` (see "Releasing" in the README). The wasm, the runtime and the
  generated CSS get names that hash their contents under `release/_vapor/`,
  so a host can cache them forever and a new build is never mixed with a
  visitor's cached files. The release is client-rendered unless the app
  passes its generator, and `release/` is emptied first. The work is done by
  tools/release.zig.
- The runtime loads the wasm from `<html data-vapor-wasm>` and the browser
  bindings from `<html data-vapor-browser>` when the page sets them, which a
  release does. Without them it uses `/zig-out/bin/vapor.wasm` and
  `browser.min.js` beside the bundle, as before.

### Fixed

- When the runtime took over a prerendered page it only updated each
  element's styles and text, so what it sets when it creates an element was
  missing: a password field had no `type="password"` and showed what was
  typed, link and button labels and other accessibility attributes were
  absent, and buttons were `type="submit"`. A prerendered element is now
  built as it would be without prerendering and takes the prerendered one's
  place before the next paint, keeping its children, any text typed into
  it and focus.

## [3.3.0] — 2026-10-26

Unknown paths show a not-found page instead of an empty one.

### Added

- A path no page matches now renders a built-in not-found page — "Page not
  found", the path, and Go back and Home — instead of an empty page. It
  renders inside the app's layouts and takes their text colour. An app's
  `/error` page still replaces it. Its elements have ids
  (`vapor-not-found`, `-back`, `-home`, ...) for tests.

### Changed

- An unmatched path logs a warning ("No page matches ...") instead of two
  errors; a missing `/error` page is logged as info, since the built-in page
  covers it.

## [3.2.2] — 2026-10-23

The static generator compiles apps that use animation frames or text-field
editing.

### Fixed

- `runOnAnimationFrame` keyed the callback registry with a `usize` pointer,
  which does not fit the registry's `u32` key on a 64-bit host, so the
  native static generator failed to compile any app that used it. The key
  is now the pointer truncated to `u32` (unchanged on wasm32).
- `Element.cursorPosition` and `Element.replaceRange` called the browser
  without checking for wasm, so the generator failed to link
  (`undefined symbol: _getAttributeWasmNumber`, `_replaceRangeWasm`). They
  now return early outside the browser, like the other `Element` reads.

## [3.2.1] — 2026-10-23

Static pages build on x86_64 Linux again.

### Fixed

- Prerendering a page with an element that had a hover style but no hover
  position read the position from memory nothing had set. On x86_64 Linux
  that crashed the static build (an index out of bounds in `values.zig`);
  elsewhere it could write a wrong `position` into the hover CSS. The
  static generator now checks `has_hover` and `has_hover_position`, as the
  browser does.
- An element's interactive styles (`PackedInteractive`) and transform
  started `undefined`, and their bytes are hashed into the CSS class name,
  so two equal elements could get different classes. They start empty.
- `ref()`'s doc now says an element bound to it must start as `.{}`; an
  `undefined` one renders garbage styles.

## [3.2.0] — 2026-10-22

Crash reports: an app can have its panics and traps posted to its own
backend, and what Zig prints reaches the console.

### Added

- `Vapor.reportErrors(.{ .url, .release, .environment })`: when the app
  panics or traps, the runtime posts a crash report to `url` as JSON, in the
  shape [reverb-errors](https://github.com/senet-toolbox/reverb-errors)
  records: the error and its stack, a panic's message, the element whose
  callback crashed, the route and URL, the last 20 clicks, inputs and key
  presses (types and element ids only), and a session id per page load.
  The JS runtime builds and sends it, never the wasm that crashed; each
  crash is sent once, and a page sends at most 10. The body is
  `text/plain`, so a backend on another origin needs no preflight. Off
  until called.

### Fixed

- What Zig wrote to stdout and stderr was dropped, a panic's message
  included: the WASI `fd_write` shim wrote nothing (and reported nothing
  written). It now logs it to the console.
- A panic's crash site, in the stack the runtime parses, was Zig 0.16's
  `process.abort` rather than the function that panicked.

### Removed

- The `recordState` wasm export, which did nothing. Crash reports replace
  it.

## [3.1.3] — 2026-10-21

KeyStone sign-in can no longer be forged from another site, and
`TextField(.float).bind` works.

### Fixed

- KeyStone's OAuth `state` and `nonce` are 128 random bits
  (`crypto.getRandomValues`); they were the provider's name and the time,
  which anyone could guess. A callback is now exchanged only when this
  browser holds a pending sign-in with that `state`. With none stored, the
  code used to be sent to the backend, so another site could sign the
  browser into an account of its choosing.
- `TextField(.float).bind(&value)` did not compile: the field parsed what
  was typed as an integer. It now reads a float, and shows the bound value
  when it renders, as `.int` fields already did.

## [3.1.2] — 2026-10-20

Playground frames run on vapor's own runtime.

### Added

- `<html data-vapor-boot="playground">`: a page that runs the wasm its
  parent window posts instead of fetching `/zig-out/bin/vapor.wasm`. It is
  the frame side of `Vapor.Wasm.runPlaygroundWasm`, which until now had no
  3.x counterpart, so a playground needed a forked runtime. The build is
  rendered at `/`, and the frame reports `playground-loaded` or
  `playground-error` to its parent.

## [3.1.1] — 2026-10-19

Fixes found while moving ryven and assembler-chat to 3.x. One visible
change: a `.transition(...)` that never ran now animates when state changes
an element's style, as declared.

### Fixed

- A `Vapor.timeout` that fired was never freed in the browser. 3.1.0 fixed
  this in an export the runtime never called, so only the unit tests saw
  the fix; the runtime now runs fired timeouts through `timeoutCtxFired`.
- Arming a timeout name that is still pending printed "Interval … already
  exists, replacing it". Replacing it is the documented behaviour, so it no
  longer warns.
- `zig build migrate` renamed an app's own `menu.hide()` to `.hidden()`; it
  now renames only the builder's `.hide(bool)`.
- `.transition(...)` never ran when a render changed an element's style
  (a sidebar widening on hover jumped to its new width): the runtime turned
  transitions off for every restyle. It now does so only on a render that
  changes the route, where ids, being positional, let the new page reuse
  the old page's elements. Restyles also no longer force a layout each.
- `.morph(true)` did nothing: the builders' configure paths never copied it
  onto the node, so a morphing element jumped like any other. It now
  animates its style changes, across pages too.

### Added

- `zig build migrate` rewrites 2.x `Vapor.print("...", args)` to
  `Vapor.print(.info, "...", args)`.

## [3.1.0] — 2026-10-16

New API (`Shadow.dropShadow`) and two behaviour changes, plus fixes found by
the interaction tests of the opaque-ui showcase. Run `zig build migrate`
over an app to find the shadow calls to check.

### Added

- `Shadow.dropShadow(x, y, blur, spread, color)`: a drop shadow with offset,
  blur and spread, usable as a decl literal (`.shadow(.dropShadow(...))`).

### Changed

- `Shadow.insetGlow` and `Shadow.insetSpread` draw inside the element, as
  their names say; they drew drop shadows. For the old look use
  `.dropShadow(x, y, blur, spread, color)` (`insetGlow(x, y, size, c)` was
  `.dropShadow(x, y, size, size / 2, c)`). `zig build migrate` points at
  every call.
- `Element.focus()` focuses any element (a button, a link, anything with a
  tab index), not only text fields.

### Fixed

- `.createDraggable(&d)` wrote through `d.element`, which nothing had set
  for a Draggable made with `.{}`: wasm memory at address 0 was overwritten,
  or, with junk left in the field, the page crashed with "memory access out
  of bounds". A Draggable now carries the element `.createDraggable` points
  it at.
- Timeouts leaked their closures: one that fired, was cancelled with
  `cancelTimeout`, or was replaced by another under the same name stayed
  allocated. A timeout that scheduled itself again under its own name also
  lost the new one. All three free it now, and re-arming works.
- An accessibility attribute that a later render left out (`aria-disabled`
  once it was false, `aria-expanded`, a role) stayed on the element: the
  runtime only ever set attributes. It now removes the ones that went away,
  on prerendered pages too.
- A `.onEvent(.keydown, ...)` (or `.keyup`) handler on an element other than
  a button, text field or form ran twice per key press: once from the
  element's own listener and again from the runtime's delegated one.
- An element that lost its `onMount` hook between renders (the same spot on
  the next page, say) made the runtime look up hook 0 and report "Hooks
  Callback not found 0".
- Every interval printed a leftover debug warning to the console.
- `zig build migrate` rewrites `Vapor.CtxButton` to `Vapor.Button` and
  `.newShadow(` to `.shadow(`, which took them over in 2.x.

## [3.0.1] — 2026-10-13

### Fixed

- An event on load could crash with "memory access out of bounds" in
  `dispatchNodeEvent`. Every render builds its nodes in a fresh frame arena,
  but the runtime only refreshed its element-to-node pointers on renders that
  changed the DOM; after two renders that changed nothing (a fetch
  completing, say), a `mouseover` or other event handed wasm a node from a
  freed arena. The runtime now repoints them on every render.
- `zig build migrate` no longer flags `Position.tl/tr/bl/br(a, b, kind)` as
  removed side constructors.

## [3.0.0] — 2026-10-13

A major version: the names deprecated during the API cleanup are removed,
along with APIs that did nothing. Run `zig build migrate -- <app src>` from
this checkout to rewrite an app (see "Renamed" and the README's Upgrading
section); the compiler points at anything it leaves.

### Breaking

- The print helpers that printed nothing are removed: `printErr`,
  `printlnErr`, `printlnSrc`, `printWarn`, `printInfo`, `printDebug`,
  `printlnColor`, `printlnWithColor` and `printlnAllocation`, as is
  `printSrcErr` (a second name for `printlnSrcErr`). Use
  `Vapor.print(.err, ...)` (or `.warn`, `.info`, `.debug`),
  `Vapor.println`, or `std.log` routed through `Vapor.lib.log`.
- `Padding`, `Margin` and `BorderThickness` (was `Border`) share one shape:
  plain `top`/`bottom`/`left`/`right` fields, set with a literal
  (`.padding(.{ .left = 12, .top = 4 })`), plus `all`, `xy`, `vertical`
  and `horizontal` for one value on several sides. On a builder,
  `.pl/.pr/.pt/.pb`, `.padX/.padY` and `.mt/.mb/.ml/.mr/.mx/.my` change
  one side (or axis) and keep the rest. `BorderGrouped` is now `Border`.
  Migration, all caught by the compiler:
  - `Padding`/`BorderThickness` `.top(n)` / `.left(n)` / ... → a literal
    `.{ .top = n }`, or `.pt(n)` / `.pl(n)` on the builder.
  - `BorderThickness` `.tb(n)` / `.lr(n)` → `.vertical(n)` /
    `.horizontal(n)`.
  - `Types.Border` used as a thickness → `Types.BorderThickness`.
- `Visual.border_radius`, `border_thickness` and `border_color` are
  removed; they never reached the CSS. Use `border`, whose parts are now
  all optional: `.border = .{ .radius = .all(8) }` rounds corners without
  a border, and a hover of `.border = .{ .color = c }` changes only the
  colour. A border with a thickness is solid unless `.style` says
  otherwise.
- Removed APIs that did nothing: `Style.checkmark_style`,
  `child_styles`, `will_change`, `btn_id` and `dialog_id` (merged and
  hashed, never written as CSS), the unused `Types.Hover`, `Types.Focus`,
  `Types.CheckMark` and `Types.ChildStyle`, `Vapor.onPushState` (its
  callbacks were never called) and `Null2` (use `Null`). The `.request`
  arena is gone: nothing freed it, so it was `.persist` under another name.
- `Element.addListener`, `removeListener` and `removeInstListener` are
  removed. `addListener` registered a callback nothing ever called, and an
  element's handlers are rebuilt on every render, so a listener added
  after the fact could only last until the next one. Attach handlers with
  `.onEvent(event, cb)` where the element is built; for the document, use
  `Vapor.addGlobalListener`, and for a listener that outlives renders,
  the new `Element.listen` (see Added). `Vapor.lib.eventListener` (whose
  callback was never called either) is gone too: `Vapor.addGlobalListener`
  does the same.
- `Vapor.KeyStone` is its own module, `keystone`, in the same package.
  Apps that sign users in add
  `exe.root_module.addImport("keystone", vapor_dep.module("keystone"))`
  and `@import("keystone")`; the rest never compile it. Its log messages
  use the scope `.keystone`.
- Kit drops what `std` already does or nothing used: `Kit.split`,
  `contains` and `startsWith` (use `std.mem`), `Kit.String` and `fastJson`
  (use `std.ArrayList(u8)` / `std.json`), and the unused `StructSchema`,
  `FieldDescriptor` and `FieldType`.
- Navigation moves from `Vapor.Kit` to the root: `Kit.navigate` →
  `Vapor.navigate`, `back` → `Vapor.back`, `routePush` → `Vapor.pushPath`,
  `setWindowLocation` → `Vapor.redirect`, `scrollTo` → `Vapor.scrollTo`,
  `getWindowPath` / `Window.path` → `Vapor.currentPath` (no longer
  optional), `getWindowParams` / `Window.paramsStr` → `Vapor.queryString`,
  `Window.params` → `Vapor.queryParams`, `Window.origin` → `Vapor.origin`,
  `Window.openTab` → `Vapor.openTab`. `Kit.Window` is gone.
- `.view` memory is now freed when the app leaves the page (see Fixed). A
  global that points into it must be reset in the page's deinit or
  reallocated on the next visit.

### Renamed

The old names are gone. `zig build migrate` rewrites nearly all of them,
and the compiler points at the rest:

- `BorderGrouped` → `Border`; `Border.simple` → `thin`, `.t/.b/.l/.r` →
  `.top/.bottom/.left/.right`, `.tb(color)`/`.lr(color)` →
  `.vertical(1, color)`/`.horizontal(1, color)`.
- The letter constructors on `Padding`, `Margin` and `BorderThickness`
  (`t`, `b`, `l`, `r`, `tb`, `lr`, `tblr`, `tl`, `tr`, `bl`, `br`, and
  `top_left` etc.) → a literal: `.tb(8, 4)` is `.{ .top = 8, .bottom = 4 }`.
  `tblr` took top, bottom, left, right, not CSS's top, right, bottom,
  left, which made it easy to get wrong.
- `Binded` → `Element`.
- Pairs that did the same thing keep one name: `PureComponentClose` →
  `PureComponent`, `BuilderClose` → `Builder`, `TextAreaBuilder` →
  `TextFieldBuilder`, `transparentizeHex` → `Color.transparentize`,
  `IconType` → `IconTokens`; builder methods `fontColor` → `textColor`,
  `weight` → `fontWeight`, `baseStyle` → `style`, `anchorPlacement` →
  `placement`, `onMountCtx` → `onMount`, `onEventCtx` → `onEvent`,
  `gradient` → `background`, `FormButton` → `SubmitButton`, and on text
  fields `whitespace` → `whiteSpace`, `childGap` → `spacing`; `Size.px`/
  `Size.percent` → `squarePx`/`squarePercent`, `Sizing.at` →
  `mobileDesktopPercent`, `Transform.distAndScale` → `directionScale`,
  `Shadow.toCss` → `writeCss`, `persist.allocator` → `persist.arena`,
  `{persist,view,frame}.Array` → `array`, `KeyStone.signIn` →
  `signInWithOauth`, `restoreSession` → `bootstrap`, `getSession` →
  `getAccessToken`, `signout` → `signOut`, `KeyStone.Config` →
  `ClientConfig`, `draggable` → `Draggable.init`, `Vapor.batch` →
  `cycle`, `Pool.initGlobalPool` → `Pool.init`, `utils.hash` →
  `hashKey`, `Vapor.Fetch.Fetch` → `Vapor.Fetch.Request`,
  `clearPersitantStorage` → `clearPersistentStorage`.
- The HTTP names `Vapor.Kit` kept when fetch moved in 2.2.0:
  `Kit.Response` → `Vapor.Fetch.Result`, `Kit.HttpReq` → `Fetch.Options`,
  `Kit.Headers` → `Fetch.Headers`, `Kit.HttpHeader` → `Fetch.Header`,
  `Kit.Methods` → `Fetch.Method`.
- `BorderThickness.solid` → `.all(1)`; `BorderRadius.toplr(a, b)` →
  `.{ .top_left = a, .top_right = b }`.
- `.hide(bool)` → `.hidden(bool)`. `.hide` set the DOM attribute after the
  fact and did nothing on the first render; `.hidden` always applies.
- snake_case functions → camelCase: `square_px` → `squarePx`,
  `square_percent`, `hw_px`, `hw_percent`, `min_max_vp`,
  `mobile_desktop`, `mobile_desktop_percent`, `none_x`/`none_y`,
  `scroll_x`/`scroll_y`, `top_bottom`, `left_right`, `direction_scale`,
  `left_percent`, `top_percent`, `size_weight`, `size_color`,
  `String.append_str`, `Padding.top_left` (→ `tl`) and the other corners.

### Added

- `zig build migrate -- <app src> [--write]` rewrites an app for the
  renames and removals below and lists what it cannot change itself (see
  `tools/migrate.zig`). It also covers older removals: `Vapor.onEnd(f)` →
  `Vapor.onLayout(f, .{})`, `onEndCtx` → `onLayout`,
  `.inlineStyleStr("css")` → `.inlineStyle("css", .{})`, and drops
  `Vapor.Kit.init()`; `Kit.Fetch`, `Kit.ErrResponse` and `HooksCtx` are
  reported. Removed side constructors are rewritten wherever they appear
  (`.top => .b(2)` in a switch becomes `.top => .{ .bottom = 2 }`).
- `Vapor.setCookie`, `Vapor.getCookie` and `Vapor.clearPersistentStorage`
  at the root; they were only reachable through `Vapor.lib`.
- `Vapor.testing.App`: test an app natively in `zig build test`. It renders
  pages (`visit`), reads them (`text`, `expectText`, `exists`, `find`,
  `html`), and fires events (`click`, which bubbles like the browser's,
  `input`, `fire` with the key, value, modifiers or coordinates the handler
  should read), rerendering after each and following links,
  `Vapor.navigate` and `Vapor.back`. Event handlers are now attached
  natively too, which also makes the test suite type-check callbacks it
  skipped before.
- `Element.listen(event, cb, args)` attaches a listener that is not part of
  the render, for frequent events such as `scroll` or `pointermove`: it stays
  across renders until `.remove()` on the returned `Vapor.Listener` or until
  the element leaves the page, and its events do not rerender the page.
- `.padX(n)` / `.padY(n)` on elements and text fields: padding on one
  axis, keeping the other.
- Text fields get the margin shorthands elements had: `.mt`, `.mb`, `.ml`,
  `.mr`, `.mx`, `.my`.
- vapor reports its own problems through `std.log` with scope `.vapor`
  (shown as `[vapor] ...` by `Vapor.lib.log`). About 150 of these reports
  printed nothing before, and the rest went through four different
  functions. ReleaseSmall and ReleaseFast builds leave them out, which made
  the browser-test app 9% smaller.

### Fixed

Found while documenting the API; each has a unit or browser test unless
noted.

- Element event handlers (`onEvent`, `onHover`, `onLeave`, `onFocus`, ...)
  were only attached after the first rerender.
- `Box().onFocus`/`onBlur` never fired and did not compile once called;
  `Box().onChange`, `onMount` with arguments, the text field's `onFocus`/`onBlur`/
  `onKeyDown`/`onHover`/`onLeave` and `onDragStart` did not compile either.
  Every callback-taking public function is now compiled by the test suite.
- Text fields received focus, blur and input events twice once a page had
  rerendered.
- `TextField.onScroll` replaced the field's `onChange` handler and never saw
  a scroll.
- `onCommit` never called its callback.
- `Vapor.Hooks` could not compile (it returned a function type and used
  registries removed earlier); it is rebuilt on the per-node lifecycle
  callbacks.
- `Vapor.onMount` did not compile on 64-bit hosts, which broke prerendering
  for apps that used it.
- A `Page`'s deinit callback never ran, and passing one did not compile.
- `Box().items(.{ Text("a") })` and `.child(Text(...))` dropped the text.
- An `Svg` over the 2 KB debug limit panicked on `.end()`.
- `Types.Layers.modal` rendered into the popover layer; the enum now matches
  the runtime (tooltip, popover, modal, toast).
- `min_max_vp` and `elastic_percent` widths wrote `min-width` from the max.
- `Animation.setAll(.{ .strokeDashoffset = ... })` animated
  `backgroundColor`; `shake`, `shakeY` and `tada` lost their 100% keyframe.
- `loopInterval` kept calling a closure in recycled frame memory.
- `Element.mutateAttribute` wrote percent sizes as `50percent`.
- `KeyStone.authFetch` called a removed function.
- `BoundedArray.orderedRemove` did not compile; `ManagedMemoryPool.destroy`
  rejected pointers it had handed out for small types (no test; compiled by
  `zig build check`).
- `Margin.xy` took `u8`, so it could not express a negative margin.
- `isMobile()` switched at 786px while responsive styles switch at 768px.
- Prerendered (static) pages closed headings with `</h>` instead of `</h2>`
  etc., so the browser put what followed inside the heading; list items
  carried a stray quote.
- `hashToBase62(0)` returned an uninitialized byte; `firstLetterToUpper("")`
  sliced out of bounds.
- `.view` memory was never freed: `arena(.view)` handed out an arena
  nothing reset. It is now freed when the app leaves the page, after the
  page's deinit runs.
- Unused CSS rules were never removed, so the stylesheet grew with every
  new style (a drag that changes a width each frame added a rule per
  frame). The class reference counts this relied on never worked; classes
  are now marked by each render and a rule unused for 3 seconds is
  deleted.
- Style data grew for the life of the app. Every unique style group kept a
  packed copy in a pool and every class combination a string, never freed;
  each navigation cleared the lookup tables without returning their pool
  slots; and an element with its own class (`style_id`) took new slots on
  every render. The class sweep now frees a group's data and cached strings
  together with its CSS rule, an element with its own class keeps its data
  in frame memory, and navigation no longer clears the tables. Removed
  `prev_style_hashes` and `element_style_hash_map`, which stored an entry
  per element and were never read.
- The whole stylesheet was regenerated on every route change; only the
  first render's is used.
- `TextField(...).radius(...)` did nothing.
- Two elements with the same styles but different `.class(...)`, `style_id`
  or edge classes got the first one's class attribute: both vapor's and the
  runtime's caches keyed class attributes by a hash that left those classes
  out.
- After unused CSS rules were removed, every hover style still in use was
  inserted again each time its element changed, since the runtime looked it
  up under a different name than the one it was stored under.
- The tables vapor keeps per element (ARIA attributes, the persisted copy
  of each text, `.ref()` handles) kept an entry for every element id ever
  rendered, so a page whose rows changed grew them for the life of the app.
  An element's entries are now dropped one render after it leaves the page.
- Every render leaked the route string and its split segments. When a route
  had no page, its string was instead freed while vapor still compared the
  next route against it.
- The same per-element growth in the callback tables: `Button` click
  callbacks, `onMount`/`onUpdate`/`onDestroy` hooks and `.onResize`
  callbacks are now dropped with their element. Their closures live in
  frame memory, so a stale entry also pointed at recycled memory.
- Destroy hooks ran after the element's exit animation, by when later
  renders could have recycled the hook's closure. They now run as the
  element starts leaving, while it is still in the DOM.
- `Vapor.onMount` called from two elements with the same function ran both
  with the last element's arguments.
- Two document listeners for the same event (`addGlobalListener`) could not
  be removed separately: removing one removed whichever was added last and
  left the other attached. `removeGlobalListener` now also frees the
  listener.
- A border's line style was left out of its class hash, so changing only
  the style kept the old rule.
- A responsive style with two breakpoints wrote its first `@media` rule
  twice, and after the first render the runtime overwrote it with a plain
  rule, so the mobile style applied at every width.
- `error.SeperatorNotFound` is spelled `error.SeparatorNotFound`.

### Documentation

- `src/root.zig` (was `src/comptime.zig`) groups the public API by task and
  opens with an overview and an example the test suite compiles.
- Every public function an app calls has a doc comment, and every source
  file has a module header. Docs state current behaviour, including the
  no-op `.inherit()`, which records fields nothing reads yet.

### Internal

- Source files follow Zig's naming convention: snake_case for namespaces,
  TitleCase for files that are a struct (`Fetch.zig` -> `fetch.zig`,
  `convertStyleCustomWriter.zig` -> `style_compiler.zig`, ...). The JS
  runtime files are named for what they do (`wasi_obj.js` -> `runtime.js`,
  ...). Apps import the `vapor` module, so nothing changes for them.
- The empty `src/main.zig` and the `vapor` executable it built are gone.

### Internal cleanup (no API change)

- `js/src/styling.js` goes from 491 to 185 lines: one table of generated
  class prefixes instead of eight copied branches, and six unused functions
  are gone (`checkMarkStyling`, `applyHoverClass`, `applyFocusClass`,
  `applyFocusWithinClass`, `applyTooltipClass`, `addKeyframesToStylesheet`).
  The runtime's class-attribute cache is cleared with each CSS sweep instead
  of growing for the life of the page.
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
