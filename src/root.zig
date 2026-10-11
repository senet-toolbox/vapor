//! Vapor: build web apps in Zig. Pages and components are Zig functions that
//! describe UI with element builders; Vapor compiles to WebAssembly, diffs
//! each render against the last, and applies the changes to the DOM.
//!
//! ```zig
//! const Vapor = @import("vapor");
//! const Box = Vapor.Box;
//! const Text = Vapor.Text;
//!
//! pub fn init() void {
//!     Vapor.Page(.{ .route = "/" }, render, null);
//! }
//!
//! fn render() void {
//!     Box().padding(.all(16)).children({
//!         Text("Hello from Zig").fontSize(24).end();
//!     });
//! }
//! ```
//!
//! Containers (`Box`, `Row`, `Stack`, ...) take their children in
//! `.children({ ... })`; leaves (`Text`, `Image`, `Icon`, ...) finish with
//! `.end()`. Every builder method returns the builder, so styling chains.
//!
//! The sections below group the API by task. Everything under "Internals" is
//! reachable for advanced use but may change between minor versions.

const std = @import("std");
const builtin = @import("builtin");
const types = @import("lib/types.zig");
const components = @import("lib/components.zig");
const text_field = @import("lib/text_field.zig");

/// The core runtime. Most of what it offers is re-exported below under a
/// stable name; reach into `lib` only for what is not.
pub const lib = @import("lib/vapor.zig");

// ── App and pages ───────────────────────────────────────────────────────────

pub const init = lib.init;
pub const Page = lib.Page;
pub const PageFn = lib.PageFn;
pub const registerLayout = lib.registerLayout;
pub const routeParam = lib.routeParam;
pub const getStatus = lib.getStatus;
pub const cycle = lib.cycle;

// ── Elements ────────────────────────────────────────────────────────────────
// Containers: finish with `.children({ ... })`.

pub const Box = PureComponent.Box;
pub const Row = PureComponent.Row;
pub const Stack = PureComponent.Stack;
pub const Center = PureComponent.Center;
pub const Section = PureComponent.Section;
pub const Layer = PureComponent.Layer;
pub const List = PureComponent.List;
pub const ListItem = PureComponent.ListItem;
pub const Link = PureComponent.Link;
pub const RedirectLink = PureComponent.RedirectLink;
pub const Button = PureComponent.Button;
pub const Form = PureComponent.Form;
/// A `<button type="submit">` for a `Form`.
pub const SubmitButton = PureComponent.FormButton;
pub const FieldSet = PureComponent.FieldSet;
pub const Table = PureComponent.Table;
pub const TableHead = PureComponent.TableHead;
pub const TableHeader = PureComponent.TableHeader;
pub const TableBody = PureComponent.TableBody;
pub const TableRow = PureComponent.TableRow;
pub const TableCell = PureComponent.TableCell;
pub const Anchor = PureComponent.Anchor;

// Leaves: finish with `.end()`.

pub const Text = PureComponentClose.Text;
pub const TextFmt = PureComponentClose.TextFmt;
pub const Heading = PureComponentClose.Heading;
pub const Label = PureComponentClose.Label;
pub const Code = PureComponentClose.Code;
pub const Number = PureComponentClose.Number;
pub const Html = PureComponentClose.Html;
pub const Image = PureComponentClose.Image;
pub const Icon = PureComponentClose.Icon;
pub const Svg = PureComponentClose.Svg;
pub const Graphic = PureComponentClose.Graphic;
pub const Video = PureComponentClose.Video;
pub const Iframe = PureComponentClose.Iframe;
pub const Spacer = PureComponentClose.Spacer;
pub const Divider = PureComponentClose.Divider;
pub const TextField = text_field.TextFieldBuilder.TextField;
pub const TextArea = text_field.TextFieldBuilder.TextArea;
pub const Null = PureComponentClose.Null;
pub const Null2 = PureComponentClose.Null2;

/// The type every element builder above returns (`Box()`, `Text(...)`, ...).
/// Name it to write helpers that take or return a builder.
pub const PureComponent = components.ComponentBuilder;
/// Same type as `PureComponent`; kept for older code.
pub const PureComponentClose = components.ComponentBuilder;
/// `Builder(state)` returns `PureComponent` for every state.
pub const Builder = components.Builder;
/// Same as `Builder`; kept for older code.
pub const BuilderClose = components.BuilderClose;
/// The builder `TextField(...)` and `TextArea()` return.
/// `TextFieldBuilder(state)` returns the same type for every state.
pub const TextFieldBuilder = text_field.BuilderClose;
/// Same as `TextFieldBuilder`; kept for older code.
pub const TextAreaBuilder = text_field.BuilderClose;

// ── Styling ─────────────────────────────────────────────────────────────────

pub const Style = types.Style;
/// Every style value type: `Color`, `Padding`, `Size`, `Layout`, ...
pub const Types = types;
pub const ThemeDefinition = Types.ThemeDefinition;
pub const setGlobalStyleVariables = lib.setGlobalStyleVariables;
/// Adds raw CSS to the page's stylesheet.
pub const injectCSS = @import("lib/CSSGenerator.zig").injectCSS;
pub const hexToRgba = lib.hexToRgba;
/// Same as `Types.Color.transparentize`: `color` with its alpha replaced.
pub const transparentizeHex = types.Color.transparentize;
/// The icon set your app's `config` module declares.
pub const IconTokens = @import("config").IconTokens;
/// Same as `IconTokens`.
pub const IconType = IconTokens;
/// ARIA attributes for an element; pass to `.a11y(...)`.
pub const Accessibility = @import("lib/accessibility.zig").Accessibility;
/// Decorative lines along an element's sides, drawn with ::before/::after.
pub const Edges = @import("lib/Edges.zig").Edges;
/// Polygon shapes (triangle, hexagon, star, custom points) for elements.
pub const Polygons = @import("lib/Polygon.zig").Polygons;

// ── Animation ───────────────────────────────────────────────────────────────

/// Keyframe animations: build one with `Animation.init("name")` or a preset
/// such as `Animation.fadeIn("name")`, register it with `.build()`, and
/// attach it with an element's `.animation(...)`.
pub const Animation = @import("lib/Animation.zig");
/// CSS transitions between style states.
pub const Transition = @import("lib/transition.zig");

// ── Events and hooks ────────────────────────────────────────────────────────

/// The event passed to handlers: key and modifiers, input text or number,
/// pointer position, form data, `preventDefault`.
pub const Event = lib.Event;
/// Declarative lifecycle hooks: `Hooks(.{ .mounted = f, .destroy = g })({ … })`.
pub const Hooks = components.Hooks;
/// The callbacks `Hooks` accepts.
pub const HooksFuncs = lib.HooksFuncs;
pub const onMount = lib.onMount;
pub const onLayout = lib.onLayout;
pub const onCommit = lib.onCommit;
pub const onPopState = lib.onPopState;
pub const registerHook = lib.registerHook;
pub const addGlobalListener = lib.addGlobalListener;
pub const addGlobalListenerCtx = lib.addGlobalListenerCtx;
pub const removeGlobalListener = lib.removeGlobalListener;
pub const timeout = lib.timeout;
pub const registerTimeout = lib.registerTimeout;
pub const scrollIntoView = Event.scrollIntoView;
/// Drag state for an element; attach it with the element's `.createDraggable(&d)`
/// after `.ref(...)`.
pub const Draggable = @import("lib/draggable.zig").Draggable;

// ── Reading and changing the DOM ────────────────────────────────────────────

pub const queryComponentIds = lib.queryComponentIds;
pub const queryByUUID = lib.queryByUUID;
pub const getComponentBounds = lib.getComponentBounds;
pub const getComponentOffsets = lib.getComponentOffsets;
/// A rendered element's box, in CSS pixels.
pub const Bounds = lib.Bounds;
pub const mutateById = lib.mutateById;
/// A handle to a rendered element, filled in by a builder's `.ref(&element)`.
pub const Binded = @import("lib/element.zig").Element;

// ── Data ────────────────────────────────────────────────────────────────────

/// HTTP requests: `Vapor.fetch(url, .{})` starts one; `Vapor.Fetch` holds its
/// types (`Request`, `Result`, `Response`, `Options`, `State`).
pub const Fetch = @import("lib/fetch.zig");
pub const fetch = Fetch.fetch;
/// Saves a string, number, bool or enum in localStorage under `key`.
pub const store = lib.store;
/// Reads back what `store` saved: `load([]const u8, "key")`, `load(u32, "key")`.
pub const load = lib.getStore;
/// Copies text to the system clipboard: `Clipboard.copy("...")`.
pub const Clipboard = lib.Clipboard;
/// Reads files the user picked in a file input.
pub const FileReader = @import("lib/File.zig").FileReader;
/// Calendar dates and times.
pub const DateTime = @import("lib/DateTime.zig");
/// Client-side authentication: sessions, OAuth and JWT handling.
pub const KeyStone = @import("lib/keystone/KeyStone.zig");
/// Browser helpers: navigation, window, timestamps, cookies, URL parsing.
pub const Kit = @import("lib/kit/kit.zig");

// ── Memory ──────────────────────────────────────────────────────────────────
// `frame`: until two renders later, for values used while rendering.
// `view`: until the app leaves the page on screen. `persist`: until you free
// it. See `arena`.

/// Allocate for the current render.
pub const frame = lib.frame;
/// Allocate for the page on screen; freed when the app leaves it. See `arena`.
pub const view = lib.view;
/// Allocate for the life of the app.
pub const persist = lib.persist;
/// The allocator for a lifetime: `arena(.frame)`, `arena(.persist)`, ...
pub const arena = lib.arena;
/// The lifetimes `arena`, `array` and `dupe` accept.
pub const Arena = lib.Arena;
pub const array = lib.array;
/// `std.array_list.Managed`, the list type `array` returns.
pub const Array = lib.Array;
/// A growable array backed by one of the arenas.
pub const ArrayArena = @import("lib/array.zig").Array;
pub const dupe = lib.dupe;
pub const fmtln = lib.fmtln;
pub const fmtArena = lib.fmtArena;
pub const cloneFrame = lib.cloneFrame;
pub const pin = lib.pin;
pub const unpin = lib.unpin;
pub const compact = lib.compact;

// ── Logging ─────────────────────────────────────────────────────────────────
// Output goes to the browser console, and to stderr natively. Logging is on
// in every build; turn it off with `Vapor.lib.build_options.enable_debug =
// false`. `printErr` and `printlnSrc` are currently no-ops.

pub const println = lib.println;
pub const printlnSrc = lib.printlnSrc;
pub const print = lib.print;
pub const printErr = lib.printlnErr;
pub const printErrSrc = lib.printlnSrcErr;
/// Same as `printErrSrc`.
pub const printSrcErr = lib.printlnSrcErr;
pub const alert = lib.alert;

// ── Platform ────────────────────────────────────────────────────────────────

pub const isMobile = utils.isMobile;
pub const isDesktop = utils.isDesktop;
/// Browser APIs beyond rendering (canvas, audio, geolocation, IndexedDB,
/// websockets, ...). Their JS loads on demand, only for apps that use them.
pub const Browser = @import("lib/browser.zig");
/// Every core binding to the JS runtime. Prefer the wrappers above.
pub const Wasm = lib.Wasm;

// ── Utilities ───────────────────────────────────────────────────────────────

/// Small helpers: hashing, casting, type introspection.
pub const utils = @import("lib/utils.zig");
pub const cast = utils.cast;
/// A fixed-buffer writer that truncates instead of overflowing.
pub const Writer = @import("lib/Writer.zig");

/// Gets the pointer of the parent Struct, given a pointer to one of its fields, the parent struct type, and the field name.
/// Example:
///   ```zig
///   const Parent = struct {
///      name: []const u8,
///      child: i32,
///   };
///
///   var parent = Parent{
///       .name = "example",
///       .child = 42,
///   };
///
///   fn logNameViaChild(x: *i32) void {
///       const parent_ptr = parentPtr(Parent, "child", x);
///       std.log.info("Parent name: {s}\n", .{parent_ptr.name});
///   }
///
///   logNameViaChild(&parent.child);
///```
pub fn parentPtr(comptime Parent: type, comptime field_name: []const u8, field_ptr: anytype) *Parent {
    return @alignCast(@fieldParentPtr(field_name, field_ptr));
}

// ── Internals ───────────────────────────────────────────────────────────────
// The node lifecycle the element builders drive, and the JS ABI. Public for
// custom elements and tooling; may change between minor versions.

pub const LifeCycle = lib.LifeCycle;
pub const ElementType = lib.ElementType;
pub const ElementDecl = lib.ElementDecl;
pub const StateType = lib.StateType;
/// Functions the JS runtime calls to walk the render tree.
pub const Bridge = @import("lib/bridge.zig");

/// Internal modules, exposed to vapor's own test suite only.
pub const Testing = if (builtin.is_test) struct {
    pub const Reconciler = @import("lib/reconciler.zig");
    pub const UIContext = @import("lib/UITree.zig");
    pub const FrameAllocator = @import("lib/FrameAllocator.zig");
    pub const JWT = @import("lib/keystone/jwt.zig");
    pub const HtmlGenerator = @import("lib/html_generator.zig");
    pub const StyleCompiler = @import("lib/style_compiler.zig");
} else struct {};

// A test binary only collects test blocks from its own root module, so the
// ones inside src/lib run from the `vapor-lib-tests` step, which is rooted
// here. Each file with tests has to be referenced from this block.
test {
    _ = lib; // lib/vapor.zig
    _ = Animation;
    _ = types.NewShadow;
    _ = @import("lib/keystone/jwt.zig");
    _ = @import("lib/Router.zig");
    _ = @import("lib/class_cache.zig");
    _ = Fetch;
    _ = @import("lib/storage.zig");
    _ = @import("lib/element.zig");
    _ = @import("lib/utils.zig");
}
