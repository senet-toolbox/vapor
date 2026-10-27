//! `ComponentBuilder`, the value every element constructor returns: its
//! fields, the helpers its methods share, and one alias per method into
//! builder/. Also `Hooks` and the `Builder` compatibility functions.

const std = @import("std");
const types = @import("types.zig");
const Vapor = @import("vapor.zig");
const UINode = @import("UITree.zig").UINode;
const LifeCycle = @import("vapor.zig").LifeCycle;
const println = Vapor.println;
const Style = types.Style;
const ElementDecl = types.ElementDeclaration;
const Color = types.Color;
const Element = @import("element.zig").Element;
pub const IconTokens = @import("config").IconTokens;
pub const Experimental = @import("config").Experimental;
const utils = @import("utils.zig");
const hashKey = utils.hashKey;
const Draggable = @import("draggable.zig").Draggable;
const Shadow = @import("Shadow.zig");
const Accessibility = @import("accessibility.zig").Accessibility;
const NodeTable = @import("node_table.zig").NodeTable;

/// Compile error unless `f` takes a `Vapor.Kit.ResizeEntry`.
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

pub var text_string_table: NodeTable(StringEntry) = undefined;

/// Frees a pruned text's persisted copy.
pub fn dropText(entry: StringEntry) void {
    Vapor.arena(.persist).free(entry.persisted);
}

const HeaderSize = enum(u32) {
    XXLarge = 12,
    XLarge = 8,
    Large = 4,
    Medium = 2,
    Small = 1,
};

/// A heading styled with `style`, sized by `size`.
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

/// Wraps the block in a node whose `mounted`/`created`, `updated` and `destroy`
/// callbacks run at those points: `Hooks(.{ .mounted = f })({ ... })`.
pub fn Hooks(hooks: Vapor.HooksFuncs) *const fn (void) void {
    const elem_decl = ElementDecl{
        .state_type = .static,
        .elem_type = .Hooks,
    };
    const ui_node = LifeCycle.open(elem_decl) orelse @panic("vapor: could not allocate a Hooks node");
    if (hooks.created != null or hooks.mounted != null) {
        setNodeHook(ui_node, 0, Vapor.on_mount_hash, runMountHooks, .{ hooks.created, hooks.mounted });
    }
    if (hooks.updated) |f| setNodeHook(ui_node, 1, Vapor.on_update_hash, runHook, .{f});
    if (hooks.destroy) |f| setNodeHook(ui_node, 2, Vapor.on_destroy_hash, runHook, .{f});
    LifeCycle.configure(elem_decl);
    return &LifeCycle.close;
}

fn runHook(f: *const fn () void) void {
    f();
}

/// `created` and `mounted` both fire once the element is on the page.
fn runMountHooks(created: ?*const fn () void, mounted: ?*const fn () void) void {
    if (created) |f| f();
    if (mounted) |f| f();
}

/// Registers `cb(args)` in the node's lifecycle slot: 0 mount, 1 update,
/// 2 destroy. Same mechanism as the builders' `.onMount` and friends.
fn setNodeHook(ui_node: *UINode, slot: usize, comptime hook_name: []const u8, cb: anytype, args: anytype) void {
    const erased = Vapor.ErasedCallback.make(Vapor.arena(.frame), cb, args) catch |err| {
        Vapor.report.err("Hooks: could not allocate callback: {any}", .{err});
        return;
    };
    const callback_id = hashKey(ui_node.uuid) +% hashKey(hook_name);
    Vapor.erased_hooks_registry.put(callback_id, erased) catch |err| {
        Vapor.report.err("Hooks: could not register callback: {any}", .{err});
        return;
    };
    ui_node.on_callbacks[slot] = callback_id;
}

pub const LinkOptions = struct {
    url: []const u8,
    aria_label: ?[]const u8 = null,
};

const Position = enum { top, bottom, left, right };
const Layout = enum { center, start, end };

/// Opens a node for `elem_decl`; panics if it cannot be allocated.
pub fn createNode(elem_decl: ElementDecl) *UINode {
    const ui_node = LifeCycle.open(elem_decl) orelse {
        // Vapor.report.err("Could not add component to lifecycle {any}", .{error.CouldNotAllocate});
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

/// Builds the final `Style` from a base style and the builder's chained values.
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

/// Copies a Text element's string into persistent memory, reusing the copy
/// while the text is unchanged.
pub fn persistText(ui_node: ?*UINode, text_value: ?[]const u8) ?[]const u8 {
    const value = text_value orelse return null;
    const uuid = hashKey(ui_node.?.uuid);
    const slice: []const u8 = value;
    if (text_string_table.get(uuid)) |entry| {
        const old_string = entry.persisted;
        if (entry.len == slice.len and entry.ptr == slice.ptr and std.mem.eql(u8, entry.persisted, slice)) {
            // Rewritten so the entry counts as used by this render.
            text_string_table.put(uuid, entry) catch {};
            return entry.persisted;
        }
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

    /// The builder's node, opening one if it has none yet.
    pub fn getOrCreateNode(self: *const Self, new_self: *Self) *UINode {
        if (self._ui_node) |node| return node;
        const node = LifeCycle.open(ElementDecl{
            .state_type = _state_type,
            .elem_type = self._elem_type,
        }) orelse {
            Vapor.report.err("Node is null", .{});
            @panic("vapor: Node is null");
        };
        new_self._ui_node = node;
        return node;
    }

    /// The builder's chained style values, for `mergeStyles`.
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

    /// The element declaration `end`/`children` configure the node with.
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
    pub const SubmitButton = ElementConstructors.SubmitButton;
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
    // Each method is declared here and calls its body in builder/. An alias
    // (`pub const width = LayoutMethods.width;`) would be shorter, but editors
    // (ZLS) then complete none of its arguments. A test checks each body has
    // its method here.

    const LayoutMethods = @import("builder/layout.zig");
    /// Draws the edge lines registered under `edges_tag` (see `Vapor.Edges`). `null`
    /// leaves the element unchanged.
    pub inline fn edges(self: *const Self, edges_tag: ?[]const u8) Self {
        return LayoutMethods.edges(self, edges_tag);
    }

    /// Fixes the element's width-to-height ratio.
    pub inline fn aspectRatio(self: *const Self, ratio: types.AspectRatio) Self {
        return LayoutMethods.aspectRatio(self, ratio);
    }

    /// Positioning: `.pos(.{ .type = .absolute, .top = .px(0), .right = .px(0) })`.
    /// Keeps a z-index set with `zIndex`.
    pub inline fn pos(self: *const Self, position: types.Position) Self {
        return LayoutMethods.pos(self, position);
    }

    /// Stacking order. `null` removes it.
    pub inline fn zIndex(self: *const Self, z_index: ?i16) Self {
        return LayoutMethods.zIndex(self, z_index);
    }

    /// How children are aligned on both axes, e.g. `.layout(.center)`.
    pub inline fn layout(self: *const Self, value: types.Layout) Self {
        return LayoutMethods.layout(self, value);
    }

    /// Where to place this element relative to its CSS anchor (see `Anchor`).
    pub inline fn placement(self: *const Self, value: types.AnchorPlacement) Self {
        return LayoutMethods.placement(self, value);
    }

    /// Centres the children on both axes. Same as `.layout(.center)`.
    pub inline fn center(self: *const Self) Self {
        return LayoutMethods.center(self);
    }

    /// Gap between children, in pixels.
    pub inline fn spacing(self: *const Self, value: u8) Self {
        return LayoutMethods.spacing(self, value);
    }

    /// Inner spacing on every side: `.padding(.all(16))`,
    /// `.padding(.{ .left = 12, .top = 4 })`. Replaces all four sides, so set it
    /// before `.pl`, `.padX` and the other one-side shorthands.
    pub inline fn padding(self: *const Self, value: types.Padding) Self {
        return LayoutMethods.padding(self, value);
    }

    /// Left padding in pixels; keeps the other sides.
    pub inline fn pl(self: *const Self, value: u8) Self {
        return LayoutMethods.pl(self, value);
    }

    /// Right padding in pixels; keeps the other sides.
    pub inline fn pr(self: *const Self, value: u8) Self {
        return LayoutMethods.pr(self, value);
    }

    /// Top padding in pixels; keeps the other sides.
    pub inline fn pt(self: *const Self, value: u8) Self {
        return LayoutMethods.pt(self, value);
    }

    /// Bottom padding in pixels; keeps the other sides.
    pub inline fn pb(self: *const Self, value: u8) Self {
        return LayoutMethods.pb(self, value);
    }

    /// Left and right padding in pixels; keeps the top and bottom.
    pub inline fn padX(self: *const Self, value: u8) Self {
        return LayoutMethods.padX(self, value);
    }

    /// Top and bottom padding in pixels; keeps the left and right.
    pub inline fn padY(self: *const Self, value: u8) Self {
        return LayoutMethods.padY(self, value);
    }

    /// Top margin in pixels (negative allowed); keeps the other sides.
    pub inline fn mt(self: *const Self, value: i16) Self {
        return LayoutMethods.mt(self, value);
    }

    /// Bottom margin in pixels (negative allowed); keeps the other sides.
    pub inline fn mb(self: *const Self, value: i16) Self {
        return LayoutMethods.mb(self, value);
    }

    /// Left margin in pixels (negative allowed); keeps the other sides.
    pub inline fn ml(self: *const Self, value: i16) Self {
        return LayoutMethods.ml(self, value);
    }

    /// Right margin in pixels (negative allowed); keeps the other sides.
    pub inline fn mr(self: *const Self, value: i16) Self {
        return LayoutMethods.mr(self, value);
    }

    /// Top and bottom margin in pixels; keeps the left and right.
    pub inline fn my(self: *const Self, value: i16) Self {
        return LayoutMethods.my(self, value);
    }

    /// Left and right margin in pixels; keeps the top and bottom.
    pub inline fn mx(self: *const Self, value: i16) Self {
        return LayoutMethods.mx(self, value);
    }

    /// Outer spacing on every side: `.margin(.all(8))`, `.margin(.{ .top = 4 })`.
    /// Replaces all four sides, so set it before `.mt`, `.mx` and the other
    /// one-side shorthands.
    pub inline fn margin(self: *const Self, value: types.Margin) Self {
        return LayoutMethods.margin(self, value);
    }

    /// Width and height together: `.size(.full)`, `.size(.squarePx(48))`.
    pub inline fn size(self: *const Self, dim: types.Size) Self {
        return LayoutMethods.size(self, dim);
    }

    /// Height, then width.
    pub inline fn hw(self: *const Self, height_value: types.Sizing, width_value: types.Sizing) Self {
        return LayoutMethods.hw(self, height_value, width_value);
    }

    /// Width: `.width(.px(320))`, `.width(.percent(50))`, `.width(.expand)` (fill the
    /// available space), ...
    pub inline fn width(self: *const Self, length: types.Sizing) Self {
        return LayoutMethods.width(self, length);
    }

    /// Minimum width. Only `.px` and `.percent` sizes are supported; others are
    /// ignored. It takes the place of `.width` (one wins, the last called), so
    /// for a fixed width that never overflows its container use
    /// `.inlineStyle("max-width: 100%", .{})` beside `.width`.
    pub inline fn minWidth(self: *const Self, min: types.Sizing) Self {
        return LayoutMethods.minWidth(self, min);
    }

    /// Maximum width. Only `.px` and `.percent` sizes are supported; others are
    /// ignored. It takes the place of `.width` (one wins, the last called), so
    /// for a fixed width that never overflows its container use
    /// `.inlineStyle("max-width: 100%", .{})` beside `.width`.
    pub inline fn maxWidth(self: *const Self, max: types.Sizing) Self {
        return LayoutMethods.maxWidth(self, max);
    }

    /// Height, with the same sizes as `width`.
    pub inline fn height(self: *const Self, length: types.Sizing) Self {
        return LayoutMethods.height(self, length);
    }

    /// Minimum height. Only `.px` and `.percent` sizes are supported; others are
    /// ignored.
    pub inline fn minHeight(self: *const Self, min: types.Sizing) Self {
        return LayoutMethods.minHeight(self, min);
    }

    /// Maximum height. Only `.px` and `.percent` sizes are supported; others are
    /// ignored.
    pub inline fn maxHeight(self: *const Self, max: types.Sizing) Self {
        return LayoutMethods.maxHeight(self, max);
    }

    /// Lays children out `column_count` to a row: a child with a percentage width
    /// takes that share of the row, less its part of the `spacing`.
    pub inline fn columns(self: *const Self, column_count: u8) *const Self {
        return LayoutMethods.columns(self, column_count);
    }

    /// Main axis for the children: `.row` or `.column`.
    pub inline fn direction(self: *const Self, value: types.Direction) Self {
        return LayoutMethods.direction(self, value);
    }

    /// Whether children wrap onto new lines when they do not fit.
    pub inline fn wrap(self: *const Self, value: types.FlexWrap) Self {
        return LayoutMethods.wrap(self, value);
    }

    /// Overflow behaviour on each axis, e.g. `.scroll(.{ .y = .scroll })`.
    pub inline fn scroll(self: *const Self, scroll_type: types.Scroll) Self {
        return LayoutMethods.scroll(self, scroll_type);
    }

    /// Whether a scrolling element shows its scroll bar.
    pub inline fn showScrollBar(self: *const Self, show: bool) Self {
        return LayoutMethods.showScrollBar(self, show);
    }

    /// Style overrides for one screen size: mobile below 768px, tablet from 768px,
    /// desktop from 1024px. Call once per platform.
    pub inline fn responsive(self: *const Self, platform: types.Platform, responsive_style: types.ResponsiveStyle) Self {
        return LayoutMethods.responsive(self, platform, responsive_style);
    }

    /// Hides the element on `platform`'s screens: `.mobile` is narrower than
    /// 768px, `.tablet` 768px and wider, `.desktop` 1024px and wider. It is CSS,
    /// so a prerendered page is right on every screen before the app loads, and
    /// it follows rotation and resizing. Prefer it to branching on
    /// `Vapor.isMobile()`, which the static generator always answers false.
    pub inline fn hideOn(self: *const Self, platform: types.Platform) Self {
        return LayoutMethods.hideOn(self, platform);
    }

    /// Shows the element only on `platform`'s screens (see `hideOn`), e.g. a
    /// menu button `.showOn(.mobile)` and a full nav `.showOn(.tablet)`.
    pub inline fn showOn(self: *const Self, platform: types.Platform) Self {
        return LayoutMethods.showOn(self, platform);
    }

    const AttributeMethods = @import("builder/attributes.zig");
    /// Gives the element a stable identity.
    ///
    /// The generated uuid encodes the child's position, so an element that
    /// moves is seen by the reconciler as a delete plus an insert. Anything in
    /// a list that can reorder, or that sits after a conditionally-rendered
    /// sibling, wants an id — it is what keeps the node itself alive across the
    /// move. The value also becomes the element's DOM id.
    pub inline fn id(self: *const Self, element_id: []const u8) Self {
        return AttributeMethods.id(self, element_id);
    }

    /// Gives the element an id made from a source location: `.src(@src())`.
    pub inline fn src(self: *const Self, source_location: std.builtin.SourceLocation) Self {
        return AttributeMethods.src(self, source_location);
    }

    /// Makes this element the CSS anchor named `name`, for elements positioned
    /// with `placement`.
    pub inline fn anchorSource(self: *const Self, name: []const u8) Self {
        return AttributeMethods.anchorSource(self, name);
    }

    /// Sets the DOM attribute `attribute_name` once the element is on the page. Both
    /// strings must stay valid until then (literals, or frame allocations).
    pub inline fn attribute(self: *const Self, attribute_name: []const u8, value: []const u8) *const Self {
        return AttributeMethods.attribute(self, attribute_name, value);
    }

    /// The form field name (`name` attribute) a `Form` submits it under.
    pub inline fn fieldName(self: *const Self, name: []const u8) Self {
        return AttributeMethods.fieldName(self, name);
    }

    /// Uses the text as given instead of copying it. Only for strings that outlive
    /// the page, such as literals and globals.
    pub inline fn unmanaged(self: *const Self) Self {
        return AttributeMethods.unmanaged(self);
    }

    /// Leaves the element out of the layout (`display: none`) while `is_hidden` is
    /// true. Unlike `.hide`, this works on every render, the first included.
    pub inline fn hidden(self: *const Self, is_hidden: bool) Self {
        return AttributeMethods.hidden(self, is_hidden);
    }

    /// All accessibility attributes at once; see `Vapor.Accessibility`.
    pub inline fn a11y(self: *const Self, accessibility: Accessibility) Self {
        return AttributeMethods.a11y(self, accessibility);
    }

    /// Accessible name for screen readers (`aria-label`).
    pub inline fn ariaLabel(self: *const Self, label: []const u8) Self {
        return AttributeMethods.ariaLabel(self, label);
    }

    /// ARIA role, e.g. `.button`, `.dialog`.
    pub inline fn role(self: *const Self, r: Accessibility.Role) Self {
        return AttributeMethods.role(self, r);
    }

    /// Whether the control's popup or section is open (`aria-expanded`).
    pub inline fn ariaExpanded(self: *const Self, expanded: bool) Self {
        return AttributeMethods.ariaExpanded(self, expanded);
    }

    /// Whether the item is selected (`aria-selected`).
    pub inline fn ariaSelected(self: *const Self, selected: bool) Self {
        return AttributeMethods.ariaSelected(self, selected);
    }

    /// Id of the element this one controls (`aria-controls`).
    pub inline fn ariaControls(self: *const Self, uuid: []const u8) Self {
        return AttributeMethods.ariaControls(self, uuid);
    }

    /// Id of the focused descendant in a composite widget
    /// (`aria-activedescendant`). `null` clears it.
    pub inline fn ariaActiveDescendant(self: *const Self, uuid: ?[]const u8) Self {
        return AttributeMethods.ariaActiveDescendant(self, uuid);
    }

    /// Hides the element from assistive technology (`aria-hidden`).
    pub inline fn ariaHidden(self: *const Self, hidden_val: bool) Self {
        return AttributeMethods.ariaHidden(self, hidden_val);
    }

    /// Tab order: 0 joins the normal order, -1 makes it focusable only from code.
    pub inline fn tabIndex(self: *const Self, index: i16) Self {
        return AttributeMethods.tabIndex(self, index);
    }

    const StyleMethods = @import("builder/style.zig");
    /// Normal or italic text.
    pub inline fn fontStyle(self: *const Self, font_style: types.FontStyle) Self {
        return StyleMethods.fontStyle(self, font_style);
    }

    /// Truncates overflowing text with "…". Text elements only; ignored (with a
    /// warning) elsewhere.
    pub inline fn ellipsis(self: *const Self, value: types.Ellipsis) Self {
        return StyleMethods.ellipsis(self, value);
    }

    /// SVG fill colour.
    pub inline fn fill(self: *const Self, value: types.Color) Self {
        return StyleMethods.fill(self, value);
    }

    /// SVG stroke colour.
    pub inline fn stroke(self: *const Self, value: types.Color) Self {
        return StyleMethods.stroke(self, value);
    }

    /// Not implemented yet: the fields are recorded but nothing applies them. See
    /// `inheritHover`.
    pub inline fn inherit(self: *const Self, fields: []const types.StyleFields) Self {
        return StyleMethods.inherit(self, fields);
    }

    /// While the parent is hovered, this element takes the listed fields (border,
    /// colour, ...) from the parent's `.hover(...)` style.
    pub inline fn inheritHover(self: *const Self, fields: []const types.StyleFields) Self {
        return StyleMethods.inheritHover(self, fields);
    }

    /// Font weight 700.
    pub inline fn bold(self: *const Self) Self {
        return StyleMethods.bold(self);
    }

    /// How whitespace and line breaks in the text are handled (CSS `white-space`).
    pub inline fn whiteSpace(self: *const Self, value: types.WhiteSpace) Self {
        return StyleMethods.whiteSpace(self, value);
    }

    /// Font size in pixels.
    pub inline fn fontSize(self: *const Self, font_size: u8) Self {
        return StyleMethods.fontSize(self, font_size);
    }

    /// Font weight: 100 to 900.
    pub inline fn fontWeight(self: *const Self, value: u16) Self {
        return StyleMethods.fontWeight(self, value);
    }

    /// CSS font family, e.g. `"Inter, sans-serif"`.
    pub inline fn fontFamily(self: *const Self, font_family: []const u8) Self {
        return StyleMethods.fontFamily(self, font_family);
    }

    /// Text colour. `null` removes it.
    pub inline fn textColor(self: *const Self, color: ?Color) Self {
        return StyleMethods.textColor(self, color);
    }

    /// Size in pixels, weight and colour in one call: `.font(16, 600, .black)`.
    pub inline fn font(self: *const Self, font_size_val: u8, font_weight: ?u16, color: ?Color) Self {
        return StyleMethods.font(self, font_size_val, font_weight, color);
    }

    /// Gaussian blur radius in pixels. `null` removes it.
    pub inline fn blur(self: *const Self, value: ?u8) Self {
        return StyleMethods.blur(self, value);
    }

    /// Background colour: a literal or a theme colour. For a gradient, use `.layer`.
    pub inline fn background(self: *const Self, value: types.Color) Self {
        return StyleMethods.background(self, value);
    }

    /// Outline style and colour; unlike a border, it takes no space.
    pub inline fn outline(self: *const Self, value: types.Outline, color: ?Color) Self {
        return StyleMethods.outline(self, value, color);
    }

    /// Box shadow, or text shadow on text elements. `null` leaves it unchanged.
    pub inline fn shadow(self: *const Self, value: ?Shadow) Self {
        return StyleMethods.shadow(self, value);
    }

    /// A patterned background layer: grid, dots, lines or gradient. Not to be
    /// confused with `Vapor.Layer`, which places an element above the page.
    pub inline fn layer(self: *const Self, value: ?types.BackgroundLayer) Self {
        return StyleMethods.layer(self, value);
    }

    /// Several background layers at once.
    pub inline fn layers(self: *const Self, value: ?[]const types.BackgroundLayer) Self {
        return StyleMethods.layers(self, value);
    }

    /// Underline, overline or line-through, with its style and colour.
    pub inline fn textDecoration(self: *const Self, value: types.TextDecoration) Self {
        return StyleMethods.textDecoration(self, value);
    }

    /// Grows the element slightly (to 104%) while hovered.
    pub inline fn hoverScale(self: *const Self) Self {
        return StyleMethods.hoverScale(self);
    }

    /// Style applied while the element is hovered.
    pub inline fn hover(self: *const Self, value: types.Visual) Self {
        return StyleMethods.hover(self, value);
    }

    /// While this element is hovered, applies `value` to its descendants that have
    /// the class `target` (see `.class`).
    pub inline fn hoverTarget(self: *const Self, target: []const u8, value: types.Visual) Self {
        return StyleMethods.hoverTarget(self, target, value);
    }

    /// Background colour while hovered.
    pub inline fn hoverBackground(self: *const Self, color: types.Color) Self {
        return StyleMethods.hoverBackground(self, color);
    }

    /// Pointer cursor, as for something clickable.
    pub inline fn pointer(self: *const Self) Self {
        return StyleMethods.pointer(self);
    }

    /// Removes text decoration, e.g. a link's underline.
    pub inline fn noDecoration(self: *const Self) Self {
        return StyleMethods.noDecoration(self);
    }

    /// Opacity, from 0 (invisible) to 1.
    pub inline fn opacity(self: *const Self, value: f16) Self {
        return StyleMethods.opacity(self, value);
    }

    /// Text colour while hovered.
    pub inline fn hoverText(self: *const Self, color: Color) Self {
        return StyleMethods.hoverText(self, color);
    }

    /// The point transforms scale and rotate around.
    pub inline fn transformOrigin(self: *const Self, value: types.TransformOrigin) Self {
        return StyleMethods.transformOrigin(self, value);
    }

    /// Mouse cursor shown over the element.
    pub inline fn cursor(self: *const Self, value: types.Cursor) Self {
        return StyleMethods.cursor(self, value);
    }

    /// Border thickness, colour, radius and style together.
    pub inline fn border(self: *const Self, value: types.Border) Self {
        return StyleMethods.border(self, value);
    }

    /// Border line style (solid, dashed, ...); keeps the thickness and colour.
    pub inline fn borderStyle(self: *const Self, value: types.BorderStyle) Self {
        return StyleMethods.borderStyle(self, value);
    }

    /// Corner radius; keeps the other border settings.
    pub inline fn radius(self: *const Self, value: types.BorderRadius) Self {
        return StyleMethods.radius(self, value);
    }

    /// A colour blended from two others (CSS `color-mix`).
    pub inline fn colorMix(self: *const Self, value: types.ColorMix) Self {
        return StyleMethods.colorMix(self, value);
    }

    /// Bullet or numbering style of a `List`.
    pub inline fn listStyle(self: *const Self, value: types.ListStyle) Self {
        return StyleMethods.listStyle(self, value);
    }

    /// A shared `Vapor.Style` to start from; the chained methods override it.
    pub inline fn style(self: *const Self, style_ptr: *const Vapor.Style) Self {
        return StyleMethods.style(self, style_ptr);
    }

    /// Styles for interaction states: hover, focus and focus-within.
    pub inline fn interaction(self: *const Self, interactive: types.Interactive) Self {
        return StyleMethods.interaction(self, interactive);
    }

    /// Raw CSS for the element's `style` attribute, formatted like `std.fmt`:
    /// `.inlineStyle("grid-area: {s};", .{area})`. Prefer the typed methods; this is
    /// the escape hatch.
    pub inline fn inlineStyle(self: *const Self, comptime fmt: []const u8, args: anytype) Self {
        return StyleMethods.inlineStyle(self, fmt, args);
    }

    /// When the element is reused across renders, animate its style changes instead
    /// of applying them instantly.
    pub inline fn morph(self: *const Self, m: bool) Self {
        return StyleMethods.morph(self, m);
    }

    /// Adds a CSS class, for rules you inject yourself.
    pub inline fn class(self: *const Self, class_name: []const u8) Self {
        return StyleMethods.class(self, class_name);
    }

    /// Adds a CSS class built like `std.fmt`: `.classFmt("col-{d}", .{n})`.
    pub inline fn classFmt(self: *const Self, comptime fmt: []const u8, args: anytype) Self {
        return StyleMethods.classFmt(self, fmt, args);
    }

    /// Animates style changes: which properties, duration and easing.
    pub inline fn transition(self: *const Self, _transition: types.Transition) Self {
        return StyleMethods.transition(self, _transition);
    }

    /// Scale, rotate and translate. `null` removes the transform.
    pub inline fn transform(self: *const Self, value: ?types.Transform) Self {
        return StyleMethods.transform(self, value);
    }

    /// Scales the element by `value` (1 is unchanged). Replaces any other transform.
    pub inline fn scale(self: *const Self, value: f16) Self {
        return StyleMethods.scale(self, value);
    }

    /// Plays the registered animation named `animation_tag` when the element first
    /// appears. `null` leaves it unchanged.
    pub inline fn animationEnter(self: *const Self, animation_tag: ?[]const u8) Self {
        return StyleMethods.animationEnter(self, animation_tag);
    }

    /// Plays the registered animation named `animation_tag` (see `Vapor.Animation`).
    /// `null` leaves it unchanged.
    pub inline fn animation(self: *const Self, animation_tag: ?[]const u8) Self {
        return StyleMethods.animation(self, animation_tag);
    }

    /// Plays the registered animation named `animation_tag` before the element is
    /// removed; removal waits for it to finish.
    pub inline fn animationExit(self: *const Self, animation_tag: ?[]const u8) Self {
        return StyleMethods.animationExit(self, animation_tag);
    }

    /// Transition duration in milliseconds. Replaces any `.transition(...)`.
    pub inline fn duration(self: *const Self, value: u32) Self {
        return StyleMethods.duration(self, value);
    }

    const EventMethods = @import("builder/events.zig");
    /// Has no effect on these elements: binding a value is for `TextField` and
    /// `TextArea` (see their `.bind`).
    pub inline fn bind(self: *const Self, value: anytype) Self {
        return EventMethods.bind(self, value);
    }

    /// Calls `cb` with the event when the element gains focus.
    pub inline fn onFocus(self: *const Self, cb: fn (*Vapor.Event) void) Self {
        return EventMethods.onFocus(self, cb);
    }

    /// Calls `cb` with the event when the element loses focus.
    pub inline fn onBlur(self: *const Self, cb: fn (*Vapor.Event) void) Self {
        return EventMethods.onBlur(self, cb);
    }

    /// Calls `func` with `args` and then the event whenever the element's value
    /// changes (the DOM `input` event).
    pub inline fn onChange(self: *const Self, func: anytype, args: anytype) *const Self {
        return EventMethods.onChange(self, func, args);
    }

    /// Calls `callback` whenever the element resizes (a ResizeObserver). The
    /// callback takes `args` and a `Vapor.Kit.ResizeEntry` with the new size.
    pub inline fn onResize(self: *const Self, callback: anytype, args: anytype) *const Self {
        return EventMethods.onResize(self, callback, args);
    }

    /// Calls `callback` with `args` once the element is on the page.
    pub inline fn onMount(self: *const Self, callback: anytype, args: anytype) *const Self {
        return EventMethods.onMount(self, callback, args);
    }

    /// Calls `callback` with `args` when a render changes the element.
    pub inline fn onUpdate(self: *const Self, callback: anytype, args: anytype) *const Self {
        return EventMethods.onUpdate(self, callback, args);
    }

    /// Calls `callback` with `args` when the element is removed from the page.
    pub inline fn onDestroy(self: *const Self, callback: anytype, args: anytype) *const Self {
        return EventMethods.onDestroy(self, callback, args);
    }

    /// Calls `func` with `args` and the event when the pointer moves onto the
    /// element and again when it leaves (mouseover and mouseout).
    pub inline fn ifMouseOver(self: *const Self, func: anytype, args: anytype) *const Self {
        return EventMethods.ifMouseOver(self, func, args);
    }

    /// Calls `func` with `args` and the event when the pointer enters the element.
    pub inline fn onHover(self: *const Self, func: anytype, args: anytype) *const Self {
        return EventMethods.onHover(self, func, args);
    }

    /// Calls `func` with `args` and the event when the pointer leaves the element.
    pub inline fn onLeave(self: *const Self, func: anytype, args: anytype) *const Self {
        return EventMethods.onLeave(self, func, args);
    }

    /// Whether this element's events trigger a rerender (default `true`). Turn it
    /// off for handlers that change no state, such as pointer tracking.
    pub inline fn cycle(self: *const Self, should_cycle: bool) *const Self {
        return EventMethods.cycle(self, should_cycle);
    }

    /// Calls `func` with `args` and the event whenever `event` fires on the element:
    /// `.onEvent(.keydown, onKey, .{&state})`.
    pub inline fn onEvent(self: *const Self, event: types.EventType, func: anytype, args: anytype) Self {
        return EventMethods.onEvent(self, event, func, args);
    }

    /// Calls `cb` with `args` and the event when the pointer enters the element
    /// (mouseenter).
    pub inline fn onHoverCtx(self: *const Self, cb: anytype, args: anytype) Self {
        return EventMethods.onHoverCtx(self, cb, args);
    }

    /// Calls `cb` with the event when a pointer is pressed on the element.
    pub inline fn onDragStart(self: *const Self, cb: fn (*Vapor.Event) void) Self {
        return EventMethods.onDragStart(self, cb);
    }

    /// Makes the element draggable with the drag state in `draggable_ptr`, which
    /// must outlive the element (keep it in persistent memory).
    pub inline fn createDraggable(self: *const Self, draggable_ptr: *Draggable) *const Self {
        return EventMethods.createDraggable(self, draggable_ptr);
    }

    /// Fills `element` with a handle to this element, for reading its size, scroll
    /// position or attributes after it is on the page. Start `element` as `.{}`,
    /// never `undefined`: the render reads its other fields (styles set through it).
    pub inline fn ref(self: *const Self, element: *Element) Self {
        return EventMethods.ref(self, element);
    }

    // --- Terminal methods ---

    const TreeMethods = @import("builder/tree.zig");
    /// Closes a container with exactly one child builder: `Box().child(Text("x"))`.
    pub inline fn child(self: *const Self, item: anytype) void {
        return TreeMethods.child(self, item);
    }

    /// Closes a container with the child builders in a tuple:
    /// `Row().items(.{ Text("a"), Text("b") })`.
    pub inline fn items(self: *const Self, nodes: anytype) void {
        return TreeMethods.items(self, nodes);
    }

    /// Closes a container. Write its children as the block argument:
    /// `Box().children({ Text("a").end(); })`. The block runs first, so the
    /// children are built inside this element.
    pub inline fn children(self: *const Self, body: void) void {
        return TreeMethods.children(self, body);
    }

    pub const cloneRecurse = TreeMethods.cloneRecurse;
    /// Renders a copy of this already-built element and its subtree.
    pub inline fn clone(self: *const Self) void {
        return TreeMethods.clone(self);
    }

    /// Closes the element without children. Same as `.children({})`.
    pub inline fn close(self: *const Self) void {
        return TreeMethods.close(self);
    }

    /// Finishes a leaf element (`Text`, `Image`, `Icon`, ...). On a container,
    /// closes it with no children.
    pub inline fn end(self: *const Self) void {
        return TreeMethods.end(self);
    }

    /// The element's id: the one set with `.id`, or the generated one.
    pub inline fn getUUID(self: *const Self) []const u8 {
        return TreeMethods.getUUID(self);
    }
};

/// Kept for source compatibility; every state type gets the same builder.
pub fn Builder(comptime state_type: types.StateType) type {
    _ = state_type;
    return ComponentBuilder;
}

var alt_len: usize = 0;
const API = struct {
    /// Runtime export: a heading node's level.
    pub fn getHeadingLevel(ptr: ?*UINode) callconv(.c) u8 {
        const node_ptr = ptr orelse return 0;
        const heading = node_ptr.type == .Heading;
        if (heading) {
            return node_ptr.level orelse return 0;
        }
        return 0;
    }

    /// Runtime export: an image node's alt text.
    pub fn getAlt(node_ptr: ?*UINode) callconv(.c) ?[*]const u8 {
        if (node_ptr) |node| {
            const alt = node.alt orelse return null;
            alt_len = alt.len;
            return alt.ptr;
        }
        return null;
    }
    /// Runtime export: length of the last alt text.
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

test "every chainable method is declared on the builder" {
    const B = ComponentBuilder;
    inline for (.{ B.LayoutMethods, B.AttributeMethods, B.StyleMethods, B.EventMethods, B.TreeMethods }) |Methods| {
        try utils.expectWrapsMethods(B, Methods);
    }
}
