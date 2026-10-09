const std = @import("std");
const types = @import("types.zig");
const Vapor = @import("Vapor.zig");
const UINode = @import("UITree.zig").UINode;
const LifeCycle = @import("Vapor.zig").LifeCycle;
const println = Vapor.println;
const Style = types.Style;
const ElementDecl = types.ElementDeclaration;
const Color = types.Color;
const Element = @import("Element.zig").Element;
pub const IconTokens = @import("config").IconTokens;
pub const Experimental = @import("config").Experimental;
const utils = @import("utils.zig");
const hashKey = utils.hashKey;
const Draggable = @import("Draggable.zig").Draggable;
const Shadow = @import("Shadow.zig");
const Accessibility = @import("Accessibility.zig").Accessibility;

pub fn assertTakesResizeEntry(comptime f: anytype) void {
    const info = @typeInfo(@TypeOf(f));
    if (info != .@"fn") @compileError("expected a function, got " ++ @typeName(@TypeOf(f)));

    inline for (info.@"fn".params) |param| {
        // param.type is ?type — it's null for `anytype`/generic params
        if (param.type) |t| {
            if (t == Vapor.Kit.ResizeEntry) return; // found it, all good
        }
    }
    @compileError("function must take a Vapor.Kit.ResizeEntry");
}

pub const on_resize: []const u8 = "on_resize"; // pick a constant, distinct from on_mount_hash

pub const StringEntry = struct {
    ptr: [*]const u8,
    len: usize,
    persisted: []const u8,
};

pub var text_string_table: std.AutoHashMap(u32, StringEntry) = undefined;

const HeaderSize = enum(u32) {
    XXLarge = 12,
    XLarge = 8,
    Large = 4,
    Medium = 2,
    Small = 1,
};

pub fn Header(text: []const u8, size: HeaderSize, style: Style) void {
    // ElementDecl.style is `?*const Style`, so resolve the size-derived default
    // on a local copy and point at that. It outlives open/configure/close.
    var resolved = style;
    var visual = resolved.visual orelse types.Visual{};
    if (visual.font_size == null) {
        visual.font_size = switch (size) {
            .XXLarge => 12 * 12,
            .XLarge => 12 * 8,
            .Large => 12 * 4,
            .Medium => 12 * 2,
            .Small => 12 * 1,
        };
        resolved.visual = visual;
    }
    const elem_decl = ElementDecl{
        .style = &resolved,
        .state_type = .static,
        .elem_type = .Header,
        .text = text,
    };
    _ = LifeCycle.open(elem_decl);
    LifeCycle.configure(elem_decl);
    LifeCycle.close({});
}

pub fn Hooks(hooks: Vapor.HooksFuncs) fn (void) void {
    var elem_decl = ElementDecl{
        .state_type = .static,
        .elem_type = .Hooks,
    };
    const ui_node = LifeCycle.open(elem_decl) orelse @panic("vapor: could not allocate a Hooks node");
    if (hooks.mounted) |f| {
        elem_decl.hooks.mounted_id = 1;
        Vapor.mounted_funcs.put(hashKey(ui_node.uuid), f) catch |err| {
            println("Mount Function Registry {any}\n", .{err});
        };
    }
    if (hooks.created) |f| {
        elem_decl.hooks.created_id += 1;
        Vapor.created_funcs.put(hashKey(ui_node.uuid), f) catch |err| {
            println("Mount Function Registry {any}\n", .{err});
        };
    }
    if (hooks.updated) |f| {
        elem_decl.hooks.updated_id += 1;
        Vapor.updated_funcs.put(hashKey(ui_node.uuid), f) catch |err| {
            println("Mount Function Registry {any}\n", .{err});
        };
    }
    if (hooks.destroy) |f| {
        elem_decl.hooks.destroy_id += 1;
        Vapor.destroy_funcs.put(hashKey(ui_node.uuid), f) catch |err| {
            println("Mount Function Registry {any}\n", .{err});
        };
    }
    LifeCycle.configure(elem_decl);
    return LifeCycle.close;
}

pub const LinkOptions = struct {
    url: []const u8,
    aria_label: ?[]const u8 = null,
};

const Position = enum { top, bottom, left, right };
const Layout = enum { center, start, end };

pub fn createNode(elem_decl: ElementDecl) *UINode {
    const ui_node = LifeCycle.open(elem_decl) orelse {
        // Vapor.printlnSrcErr("Could not add component to lifecycle {any}\n", .{error.CouldNotAllocate}, @src());
        @panic("vapor: Could not add component to lifecycle");
    };
    return ui_node;
}

// ============================================================
// Shared style-merge logic — compiled ONCE, not per generic instantiation
// ============================================================

fn mergeVisualFields(target: *types.Visual, source: types.Visual) void {
    if (source.background != null) target.background = source.background;
    if (source.fill != null) target.fill = source.fill;
    if (source.stroke != null) target.stroke = source.stroke;
    if (source.border != null) target.border = source.border;
    if (source.border_radius != null) target.border_radius = source.border_radius;
    if (source.border_thickness != null) target.border_thickness = source.border_thickness;
    if (source.border_color != null) target.border_color = source.border_color;
    if (source.text_color != null) target.text_color = source.text_color;
    if (source.font_size != null) target.font_size = source.font_size;
    if (source.font_weight != null) target.font_weight = source.font_weight;
    if (source.letter_spacing != null) target.letter_spacing = source.letter_spacing;
    if (source.line_height != null) target.line_height = source.line_height;
    if (source.opacity != null) target.opacity = source.opacity;
    if (source.ellipsis != null) target.ellipsis = source.ellipsis;
    if (source.shadow != null) target.shadow = source.shadow;
    if (source.cursor != null) target.cursor = source.cursor;
    if (source.layer != null) target.layer = source.layer;
    if (source.layers != null) target.layers = source.layers;
    if (source.text_shadow != null) target.text_shadow = source.text_shadow;
}

fn mergeHoverVisualFields(target: *types.Visual, source: types.Visual) void {
    mergeVisualFields(target, source);
    if (source.animation != null) target.animation = source.animation;
    if (source.animation_name != null) target.animation_name = source.animation_name;
}

pub const StyleMergeParams = struct {
    style_ptr: ?*const Vapor.Style,
    pos: ?types.Position,
    visual: ?types.Visual,
    interactive: ?types.Interactive,
    target_visual: ?types.Visual,
    child_gap: ?u8,
    transform_origin: ?types.TransformOrigin,
    padding: ?types.Padding,
    layout: ?types.Layout,
    placement: ?types.AnchorPlacement,
    margin: ?types.Margin,
    size: ?types.Size,
    transition: ?types.Transition,
    flex_wrap: ?types.FlexWrap,
    direction: ?types.Direction,
    list_style: ?types.ListStyle,
    font_family: ?[]const u8,
    scroll: ?types.Scroll,
    show_scrollbar: ?bool,
    flex_type: types.FlexType,
    id: ?[]const u8,
    class: ?[]const u8,
    anchor: ?[]const u8,
    edges: ?[]const u8,
    aspect_ratio: ?types.AspectRatio,
    include_extended: bool,
    include_aspect_ratio: bool,
    responsive: ?types.Responsive,
};

pub fn mergeStyles(p: StyleMergeParams) Style {
    var s = if (p.style_ptr) |sp| sp.* else Style{};
    if (s.position == null) s.position = p.pos;

    if (s.visual != null and p.visual != null) {
        var visual = s.visual.?;
        mergeVisualFields(&visual, p.visual.?);
        if (p.include_extended and p.edges != null) visual.edges = p.edges;
        s.visual = visual;
    } else if (p.visual) |v| {
        s.visual = v;
        if (p.include_extended) s.visual.?.edges = p.edges;
    }

    if (p.include_extended) {
        if (s.interactive != null and p.interactive != null) {
            const interactive = s.interactive.?;
            const _interactive = p.interactive.?;
            if (interactive.hover != null and _interactive.hover != null) {
                var visual = interactive.hover.?;
                mergeHoverVisualFields(&visual, _interactive.hover.?);
                s.interactive.?.hover = visual;
            }
        } else if (p.interactive) |i| {
            s.interactive = i;
        }
    } else {
        if (s.interactive == null) s.interactive = p.interactive;
    }

    s.target_visual = p.target_visual;
    if (s.child_gap == null) s.child_gap = p.child_gap;
    if (s.transform_origin == null) s.transform_origin = p.transform_origin;
    if (s.padding == null) s.padding = p.padding;
    if (s.flex_type == null) s.flex_type = p.flex_type;

    if (s.layout != null) {
        if (p.layout) |l| s.layout = l;
    } else s.layout = p.layout;
    if (s.placement != null) {
        if (p.placement) |pl| s.placement = pl;
    } else s.placement = p.placement;
    if (s.margin == null) s.margin = p.margin;
    if (s.size == null) s.size = p.size;
    if (s.transition == null) s.transition = p.transition;
    if (s.flex_wrap == null) s.flex_wrap = p.flex_wrap;
    if (p.direction) |d| s.direction = d;
    if (s.list_style == null) s.list_style = p.list_style;
    if (s.font_family == null) s.font_family = p.font_family;
    if (s.scroll == null) s.scroll = p.scroll;
    if (s.show_scrollbar == null) s.show_scrollbar = p.show_scrollbar;
    if (p.include_aspect_ratio) {
        if (s.aspect_ratio == null) s.aspect_ratio = p.aspect_ratio;
    }
    if (p.flex_type == .center) {
        s.layout = .center;
    } else if (p.flex_type == .stack) {
        s.direction = .column;
    }
    if (p.id) |_id| s.id = _id;
    if (p.class) |_class| s.style_id = _class;
    if (p.anchor) |_anchor| s.anchor = _anchor;
    if (p.responsive) |_responsive| s.responsive = _responsive;
    return s;
}

pub fn persistText(ui_node: ?*UINode, text_value: ?[]const u8) ?[]const u8 {
    const value = text_value orelse return null;
    const uuid = hashKey(ui_node.?.uuid);
    const slice: []const u8 = value;
    if (text_string_table.get(uuid)) |entry| {
        const old_string = entry.persisted;
        if (entry.len == slice.len and entry.ptr == slice.ptr and std.mem.eql(u8, entry.persisted, slice)) return entry.persisted;
        const new_copy = Vapor.arena(.persist).dupe(u8, slice) catch return null;
        text_string_table.put(uuid, .{ .ptr = slice.ptr, .len = slice.len, .persisted = new_copy }) catch return null;
        defer Vapor.arena(.persist).free(old_string);
        return new_copy;
    } else {
        const copy = Vapor.arena(.persist).dupe(u8, slice) catch return null;
        text_string_table.put(uuid, .{ .ptr = slice.ptr, .len = slice.len, .persisted = copy }) catch return null;
        return copy;
    }
}

// ============================================================
// Single unified ComponentBuilder — NO comptime parameters
// ============================================================

pub const ComponentBuilder = struct {
    const Self = @This();
    pub const _state_type: types.StateType = .pure;

    _target: ?[]const u8 = null,
    _target_visual: ?types.Visual = null,
    _returns_close: bool = true,
    _level: ?u8 = null,
    _video: ?*const types.Video = null,
    _font_family: ?[]const u8 = null,
    _value: ?*anyopaque = null,
    _elem_type: Vapor.ElementType,
    _flex_type: types.FlexType = .flex,
    _text: ?[]const u8 = null,
    _href: ?[]const u8 = null,
    _src: ?[]const u8 = null,
    _alt: ?[]const u8 = null,
    _svg: []const u8 = "",
    _aria_label: ?[]const u8 = null,
    _ui_node: ?*UINode = null,
    _id: ?[]const u8 = null,
    _style: ?*const Vapor.Style = null,
    _draggable: ?*Draggable = null,
    _element: ?*Element = null,
    _animation_enter: ?[]const u8 = null,
    _animation_exit: ?[]const u8 = null,
    _name: ?[]const u8 = null,
    _used_style: bool = false,
    _pos: ?types.Position = null,
    _padding: ?types.Padding = null,
    _layout: ?types.Layout = null,
    _placement: ?types.AnchorPlacement = null,
    _margin: ?types.Margin = null,
    _size: ?types.Size = null,
    _child_gap: ?u8 = null,
    _visual: ?types.Visual = null,
    _text_decoration: ?types.TextDecoration = null,
    _flex_wrap: ?types.FlexWrap = null,
    _interactive: ?types.Interactive = null,
    _transition: ?types.Transition = null,
    _direction: ?types.Direction = null,
    _list_style: ?types.ListStyle = null,
    _class: ?[]const u8 = null,
    _scroll: ?types.Scroll = null,
    _show_scrollbar: ?bool = null,
    _transform_origin: ?types.TransformOrigin = null,
    _inlineStyle: ?[]const u8 = null,
    _style_fields: ?[]const types.StyleFields = null,
    _hover_style_fields: ?[]const types.StyleFields = null,
    _anchor: ?[]const u8 = null,
    _aspect_ratio: ?types.AspectRatio = null,
    _persisted_text: bool = false,
    _accessibility: ?Accessibility = null,
    _column_count: ?u8 = null,
    _edges: ?[]const u8 = null,
    _responsive: ?types.Responsive = null,
    _morph: bool = false,

    // --- Internal helpers ---
    // `pub` only so the method files under builder/ can reach them; not part
    // of the public API.

    pub fn getOrCreateNode(self: *const Self, new_self: *Self) *UINode {
        if (self._ui_node) |node| return node;
        const node = LifeCycle.open(ElementDecl{
            .state_type = _state_type,
            .elem_type = self._elem_type,
        }) orelse {
            Vapor.printlnSrcErr("Node is null", .{}, @src());
            @panic("vapor: Node is null");
        };
        new_self._ui_node = node;
        return node;
    }

    pub fn getStyleMergeParams(self: *const Self, include_extended: bool, include_aspect_ratio: bool) StyleMergeParams {
        return .{
            .style_ptr = self._style,
            .pos = self._pos,
            .visual = self._visual,
            .interactive = self._interactive,
            .target_visual = self._target_visual,
            .child_gap = self._child_gap,
            .transform_origin = self._transform_origin,
            .padding = self._padding,
            .layout = self._layout,
            .placement = self._placement,
            .margin = self._margin,
            .size = self._size,
            .transition = self._transition,
            .flex_wrap = self._flex_wrap,
            .direction = self._direction,
            .list_style = self._list_style,
            .font_family = self._font_family,
            .scroll = self._scroll,
            .show_scrollbar = self._show_scrollbar,
            .flex_type = self._flex_type,
            .id = self._id,
            .class = self._class,
            .anchor = self._anchor,
            .edges = self._edges,
            .aspect_ratio = self._aspect_ratio,
            .include_extended = include_extended,
            .include_aspect_ratio = include_aspect_ratio,
            .responsive = self._responsive,
        };
    }

    pub fn makeElemDecl(self: *const Self, text: ?[]const u8, mutable_style: *const Style, inline_style: ?[]const u8) Vapor.ElementDecl {
        return .{
            .state_type = _state_type,
            .elem_type = self._elem_type,
            .text = text,
            .style = mutable_style,
            .href = self._href,
            .svg = self._svg,
            .alt = self._alt,
            .aria_label = self._aria_label,
            .animation_enter = self._animation_enter,
            .animation_exit = self._animation_exit,
            .name = self._name,
            .video = self._video,
            .style_fields = self._style_fields,
            .hover_style_fields = self._hover_style_fields,
            .inlineStyle = inline_style,
            .accessibility = self._accessibility,
            .src = self._src,
            .morph = self._morph,
            .target = self._target,
        };
    }

    // The methods live in builder/, one file per concern. Each alias below
    // makes one of them callable as `builder.method(...)`.

    // --- Constructors ---

    const ElementConstructors = @import("builder/elements.zig");
    pub const Null = ElementConstructors.Null;
    pub const Null2 = ElementConstructors.Null2;
    pub const Heading = ElementConstructors.Heading;
    pub const Video = ElementConstructors.Video;
    pub const Box = ElementConstructors.Box;
    pub const Row = ElementConstructors.Row;
    pub const Layer = ElementConstructors.Layer;
    pub const Table = ElementConstructors.Table;
    pub const TableRow = ElementConstructors.TableRow;
    pub const TableCell = ElementConstructors.TableCell;
    pub const TableBody = ElementConstructors.TableBody;
    pub const TableHeader = ElementConstructors.TableHeader;
    pub const TableHead = ElementConstructors.TableHead;
    pub const Form = ElementConstructors.Form;
    pub const Section = ElementConstructors.Section;
    pub const List = ElementConstructors.List;
    pub const ListItem = ElementConstructors.ListItem;
    pub const Center = ElementConstructors.Center;
    pub const FormButton = ElementConstructors.FormButton;
    pub const Button = ElementConstructors.Button;
    pub const Stack = ElementConstructors.Stack;
    pub const Link = ElementConstructors.Link;
    pub const RedirectLink = ElementConstructors.RedirectLink;
    pub const Label = ElementConstructors.Label;
    pub const Code = ElementConstructors.Code;
    pub const Spacer = ElementConstructors.Spacer;
    pub const Divider = ElementConstructors.Divider;
    pub const Iframe = ElementConstructors.Iframe;
    pub const FieldSet = ElementConstructors.FieldSet;
    pub const Number = ElementConstructors.Number;
    pub const Text = ElementConstructors.Text;
    pub const Html = ElementConstructors.Html;
    pub const TextFmt = ElementConstructors.TextFmt;
    pub const Graphic = ElementConstructors.Graphic;
    pub const Icon = ElementConstructors.Icon;
    pub const Svg = ElementConstructors.Svg;
    pub const Image = ElementConstructors.Image;
    pub const Anchor = ElementConstructors.Anchor;

    // --- Chainable instance methods ---

    const LayoutMethods = @import("builder/layout.zig");
    pub const edges = LayoutMethods.edges;
    pub const aspectRatio = LayoutMethods.aspectRatio;
    pub const pos = LayoutMethods.pos;
    pub const zIndex = LayoutMethods.zIndex;
    pub const layout = LayoutMethods.layout;
    pub const anchorPlacement = LayoutMethods.anchorPlacement;
    pub const placement = LayoutMethods.placement;
    pub const center = LayoutMethods.center;
    pub const spacing = LayoutMethods.spacing;
    pub const padding = LayoutMethods.padding;
    pub const pl = LayoutMethods.pl;
    pub const pr = LayoutMethods.pr;
    pub const pt = LayoutMethods.pt;
    pub const pb = LayoutMethods.pb;
    pub const mt = LayoutMethods.mt;
    pub const mb = LayoutMethods.mb;
    pub const ml = LayoutMethods.ml;
    pub const mr = LayoutMethods.mr;
    pub const my = LayoutMethods.my;
    pub const mx = LayoutMethods.mx;
    pub const margin = LayoutMethods.margin;
    pub const size = LayoutMethods.size;
    pub const hw = LayoutMethods.hw;
    pub const width = LayoutMethods.width;
    pub const minWidth = LayoutMethods.minWidth;
    pub const maxWidth = LayoutMethods.maxWidth;
    pub const height = LayoutMethods.height;
    pub const minHeight = LayoutMethods.minHeight;
    pub const maxHeight = LayoutMethods.maxHeight;
    pub const columns = LayoutMethods.columns;
    pub const direction = LayoutMethods.direction;
    pub const wrap = LayoutMethods.wrap;
    pub const scroll = LayoutMethods.scroll;
    pub const showScrollBar = LayoutMethods.showScrollBar;
    pub const hide = LayoutMethods.hide;
    pub const responsive = LayoutMethods.responsive;

    const AttributeMethods = @import("builder/attributes.zig");
    pub const id = AttributeMethods.id;
    pub const src = AttributeMethods.src;
    pub const anchorSource = AttributeMethods.anchorSource;
    pub const attribute = AttributeMethods.attribute;
    pub const fieldName = AttributeMethods.fieldName;
    pub const unmanaged = AttributeMethods.unmanaged;
    pub const hidden = AttributeMethods.hidden;
    pub const a11y = AttributeMethods.a11y;
    pub const ariaLabel = AttributeMethods.ariaLabel;
    pub const role = AttributeMethods.role;
    pub const ariaExpanded = AttributeMethods.ariaExpanded;
    pub const ariaSelected = AttributeMethods.ariaSelected;
    pub const ariaControls = AttributeMethods.ariaControls;
    pub const ariaActiveDescendant = AttributeMethods.ariaActiveDescendant;
    pub const ariaHidden = AttributeMethods.ariaHidden;
    pub const tabIndex = AttributeMethods.tabIndex;

    const StyleMethods = @import("builder/style.zig");
    pub const fontStyle = StyleMethods.fontStyle;
    pub const ellipsis = StyleMethods.ellipsis;
    pub const fill = StyleMethods.fill;
    pub const stroke = StyleMethods.stroke;
    pub const inherit = StyleMethods.inherit;
    pub const inheritHover = StyleMethods.inheritHover;
    pub const bold = StyleMethods.bold;
    pub const whiteSpace = StyleMethods.whiteSpace;
    pub const fontSize = StyleMethods.fontSize;
    pub const fontWeight = StyleMethods.fontWeight;
    pub const weight = StyleMethods.weight;
    pub const fontFamily = StyleMethods.fontFamily;
    pub const textColor = StyleMethods.textColor;
    pub const fontColor = StyleMethods.fontColor;
    pub const font = StyleMethods.font;
    pub const blur = StyleMethods.blur;
    pub const background = StyleMethods.background;
    pub const outline = StyleMethods.outline;
    pub const shadow = StyleMethods.shadow;
    pub const layer = StyleMethods.layer;
    pub const layers = StyleMethods.layers;
    pub const gradient = StyleMethods.gradient;
    pub const textDecoration = StyleMethods.textDecoration;
    pub const hoverScale = StyleMethods.hoverScale;
    pub const hover = StyleMethods.hover;
    pub const hoverTarget = StyleMethods.hoverTarget;
    pub const hoverBackground = StyleMethods.hoverBackground;
    pub const pointer = StyleMethods.pointer;
    pub const noDecoration = StyleMethods.noDecoration;
    pub const opacity = StyleMethods.opacity;
    pub const hoverText = StyleMethods.hoverText;
    pub const transformOrigin = StyleMethods.transformOrigin;
    pub const cursor = StyleMethods.cursor;
    pub const border = StyleMethods.border;
    pub const borderStyle = StyleMethods.borderStyle;
    pub const radius = StyleMethods.radius;
    pub const colorMix = StyleMethods.colorMix;
    pub const listStyle = StyleMethods.listStyle;
    pub const style = StyleMethods.style;
    pub const baseStyle = StyleMethods.baseStyle;
    pub const interaction = StyleMethods.interaction;
    pub const inlineStyle = StyleMethods.inlineStyle;
    pub const morph = StyleMethods.morph;
    pub const class = StyleMethods.class;
    pub const classFmt = StyleMethods.classFmt;
    pub const transition = StyleMethods.transition;
    pub const transform = StyleMethods.transform;
    pub const scale = StyleMethods.scale;
    pub const animationEnter = StyleMethods.animationEnter;
    pub const animation = StyleMethods.animation;
    pub const animationExit = StyleMethods.animationExit;
    pub const duration = StyleMethods.duration;

    const EventMethods = @import("builder/events.zig");
    pub const bind = EventMethods.bind;
    pub const onFocus = EventMethods.onFocus;
    pub const onBlur = EventMethods.onBlur;
    pub const onChange = EventMethods.onChange;
    pub const onResize = EventMethods.onResize;
    pub const onMount = EventMethods.onMount;
    pub const onUpdate = EventMethods.onUpdate;
    pub const onDestroy = EventMethods.onDestroy;
    pub const ifMouseOver = EventMethods.ifMouseOver;
    pub const onHover = EventMethods.onHover;
    pub const onLeave = EventMethods.onLeave;
    pub const cycle = EventMethods.cycle;
    pub const onEvent = EventMethods.onEvent;
    pub const onEventCtx = EventMethods.onEventCtx;
    pub const onMountCtx = EventMethods.onMountCtx;
    pub const onHoverCtx = EventMethods.onHoverCtx;
    pub const onDragStart = EventMethods.onDragStart;
    pub const createDraggable = EventMethods.createDraggable;
    pub const ref = EventMethods.ref;

    // --- Terminal methods ---

    const TreeMethods = @import("builder/tree.zig");
    pub const child = TreeMethods.child;
    pub const items = TreeMethods.items;
    pub const children = TreeMethods.children;
    pub const cloneRecurse = TreeMethods.cloneRecurse;
    pub const clone = TreeMethods.clone;
    pub const close = TreeMethods.close;
    pub const end = TreeMethods.end;
    pub const getUUID = TreeMethods.getUUID;

};

// ============================================================
// Backward-compatible aliases
// ============================================================

// const InertBuilder = @import("Inert.zig").InertBuilder;
pub fn Builder(comptime state_type: types.StateType) type {
    _ = state_type;
    return ComponentBuilder;
}

pub fn BuilderClose(comptime state_type: types.StateType) type {
    _ = state_type;
    return ComponentBuilder;
}

var alt_len: usize = 0;
const API = struct {
    pub fn getHeadingLevel(ptr: ?*UINode) callconv(.c) u8 {
        const node_ptr = ptr orelse return 0;
        const heading = node_ptr.type == .Heading;
        if (heading) {
            return node_ptr.level orelse return 0;
        }
        return 0;
    }

    pub fn getAlt(node_ptr: ?*UINode) callconv(.c) ?[*]const u8 {
        if (node_ptr) |node| {
            const alt = node.alt orelse return null;
            alt_len = alt.len;
            return alt.ptr;
        }
        return null;
    }
    pub fn getAltLen() callconv(.c) usize {
        return alt_len;
    }
};

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
