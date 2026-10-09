const types = @import("lib/types.zig");
const std = @import("std");
const builtin = @import("builtin");
pub const lib = @import("lib/vapor.zig");
pub const IconTokens = @import("config").IconTokens;
pub const init = lib.init;
pub const Wasm = lib.Wasm;
/// Browser APIs beyond rendering (canvas, audio, geolocation, ...); their JS
/// loads on demand. See lib/browser.zig.
pub const Browser = @import("lib/browser.zig");
pub const Arena = lib.Arena;
pub const IconType = IconTokens;
pub const Bounds = lib.Bounds;
const TransitionState = @import("lib/transition.zig").TransitionState;
pub const Binded = @import("lib/element.zig").Element;
pub const Draggable = @import("lib/draggable.zig").Draggable;
pub const KeyStone = @import("lib/keystone/KeyStone.zig");
pub const utils = @import("lib/utils.zig");
/// `Vapor.fetch(url, .{})` starts a request; `Vapor.Fetch` holds its types
/// (`Request`, `Result`, `Response`, `Options`, `State`).
pub const Fetch = @import("lib/fetch.zig");
pub const fetch = Fetch.fetch;

// vapor.zig
pub const ArrayArena = @import("lib/array.zig").Array;
pub const persist = lib.persist;
pub const view = lib.view;
pub const frame = lib.frame;

// pub const renderCycle = @import("lib/vapor.zig").renderCycle;
pub const LifeCycle = @import("lib/vapor.zig").LifeCycle;
pub const ElementType = @import("lib/vapor.zig").ElementType;
pub const ElementDecl = @import("lib/vapor.zig").ElementDecl;
pub const StateType = @import("lib/vapor.zig").StateType;
pub const Kit = @import("lib/kit/kit.zig");
pub const Page = lib.Page;
pub const routeParam = lib.routeParam;
pub const println = lib.println;
pub const printlnSrc = lib.printlnSrc;
pub const transparentizeHex = types.Color.transparentize;
pub const setGlobalStyleVariables = lib.setGlobalStyleVariables;
pub const hexToRgba = lib.hexToRgba;
pub const Bridge = @import("lib/bridge.zig");
pub const isMobile = utils.isMobile;
pub const isDesktop = utils.isDesktop;
pub const cycle = lib.cycle;
pub const Clipboard = lib.Clipboard;
pub const registerTimeout = lib.registerTimeout;
pub const timeout = lib.timeout;
pub const Event = lib.Event;
pub const fmtln = lib.fmtln;
pub const fmtArena = lib.fmtArena;
pub const dupe = lib.dupe;
pub const pin = lib.pin;
pub const unpin = lib.unpin;
pub const compact = lib.compact;
pub const cloneFrame = lib.cloneFrame;
pub const arena = lib.arena;
pub const Style = types.Style;
pub const Types = types;
pub const DateTime = @import("lib/DateTime.zig");
pub const Animation = @import("lib/Animation.zig");
pub const Edges = @import("lib/Edges.zig").Edges;
pub const Transition = @import("lib/transition.zig");
pub const ThemeDefinition = Types.ThemeDefinition;
pub const FileReader = @import("lib/File.zig").FileReader;
pub const Polygons = @import("lib/Polygon.zig").Polygons;

const ComponentBuilder = @import("lib/components.zig").Builder;
const ComponentBuilderClose = @import("lib/components.zig").BuilderClose;
pub const Accessibility = @import("lib/accessibility.zig").Accessibility;

pub const registerHook = lib.registerHook;
pub const queryComponentIds = lib.queryComponentIds;
pub const queryByUUID = lib.queryByUUID;
pub const getComponentBounds = lib.getComponentBounds;
pub const getComponentOffsets = lib.getComponentOffsets;
pub const onPopState = lib.onPopState;
pub const scrollIntoView = Event.scrollIntoView;
pub const Writer = @import("lib/Writer.zig");
pub const onCommit = lib.onCommit;
pub const mutateById = lib.mutateById;
pub const print = lib.print;
pub const printSrcErr = lib.printlnSrcErr;
pub const cast = utils.cast;
pub const alert = lib.alert;

pub const Builder = ComponentBuilder;
pub const BuilderClose = ComponentBuilderClose;

/// Declarative lifecycle hooks: `Hooks(.{ .mounted = f, .destroyed = g })({ … })`.
pub const Hooks = @import("lib/components.zig").Hooks;
pub const HooksFuncs = lib.HooksFuncs;

pub const printErrSrc = lib.printlnSrcErr;
pub const printErr = lib.printlnErr;

pub const addGlobalListener = lib.addGlobalListener;
pub const addGlobalListenerCtx = lib.addGlobalListenerCtx;
pub const removeGlobalListener = lib.removeGlobalListener;

pub const Array = lib.Array;
pub const array = lib.array;
pub const getStatus = lib.getStatus;

pub const PureComponent = ComponentBuilder(.pure);
pub const PureComponentClose = ComponentBuilderClose(.pure);
pub const TextField = @import("lib/text_field.zig").BuilderClose(.pure).TextField;
pub const TextFieldBuilder = @import("lib/text_field.zig").BuilderClose;
pub const TextAreaBuilder = @import("lib/text_field.zig").BuilderClose;
pub const registerLayout = lib.registerLayout;
pub const PageFn = lib.PageFn;
pub const Box = PureComponent.Box;
pub const Row = PureComponent.Row;
pub const Text = PureComponentClose.Text;
pub const Link = PureComponent.Link;
pub const Image = PureComponentClose.Image;
pub const Spacer = PureComponentClose.Spacer;
pub const Divider = PureComponentClose.Divider;
pub const Iframe = PureComponentClose.Iframe;
pub const load = lib.getStore;
pub const store = lib.store;
pub const List = PureComponent.List;
pub const ListItem = PureComponent.ListItem;
pub const Graphic = PureComponentClose.Graphic;
pub const Svg = PureComponentClose.Svg;
pub const RedirectLink = PureComponent.RedirectLink;
pub const Icon = PureComponentClose.Icon;
pub const Stack = PureComponent.Stack;
pub const Center = PureComponent.Center;
pub const Button = PureComponent.Button;
pub const TextFmt = PureComponentClose.TextFmt;
pub const TextArea = @import("lib/text_field.zig").BuilderClose(.pure).TextArea;
pub const Heading = PureComponentClose.Heading;
pub const Section = PureComponent.Section;
pub const Video = PureComponentClose.Video;
pub const Null = PureComponentClose.Null;
pub const Null2 = PureComponentClose.Null2;
pub const Form = PureComponent.Form;
pub const Label = PureComponentClose.Label;
pub const SubmitButton = PureComponent.FormButton;
pub const FieldSet = PureComponent.FieldSet;
pub const Html = PureComponentClose.Html;
pub const Table = PureComponent.Table;
pub const TableRow = PureComponent.TableRow;
pub const TableCell = PureComponent.TableCell;
pub const TableBody = PureComponent.TableBody;
pub const TableHeader = PureComponent.TableHeader;
pub const TableHead = PureComponent.TableHead;
pub const Anchor = PureComponent.Anchor;
pub const Layer = PureComponent.Layer;
pub const Code = PureComponentClose.Code;
pub const Number = PureComponentClose.Number;
pub const onMount = lib.onMount;
pub const onLayout = lib.onLayout;
pub const injectCSS = @import("lib/CSSGenerator.zig").injectCSS;

pub const Testing = if (builtin.is_test) struct {
    pub const Reconciler = @import("lib/reconciler.zig");
    pub const UIContext = @import("lib/UITree.zig");
    pub const FrameAllocator = @import("lib/FrameAllocator.zig");
    pub const JWT = @import("lib/keystone/jwt.zig");
    pub const HtmlGenerator = @import("lib/html_generator.zig");
    pub const StyleCompiler = @import("lib/style_compiler.zig");
} else struct {};

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

// A test binary only collects test blocks from its own root module, so the
// ones inside src/lib run from the `vapor-lib-tests` step, which is rooted
// here. Each file with tests has to be referenced from this block.
test {
    _ = lib; // lib/vapor.zig
    _ = Animation;
    _ = types.NewShadow;
    _ = @import("lib/keystone/jwt.zig");
    _ = @import("lib/Router.zig");
    _ = Fetch;
    _ = @import("lib/storage.zig");
}
