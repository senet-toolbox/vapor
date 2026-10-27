//! `TextFieldBuilder`, the builder `TextField` and `TextArea` return: its
//! fields, `end()`, and one alias per method into text_field/.

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
const utils = @import("utils.zig");
const hashKey = utils.hashKey;
const DynamicObject = @import("dynamic.zig");
const Accessibility = @import("accessibility.zig").Accessibility;

const Ctx = struct {
    bind_ptr: ?*anyopaque,
    bind_fn: ?*const fn (*anyopaque, *Vapor.Event) void,
    user_cb: ?Vapor.ErasedEventCallback,
};

pub const TextFieldBuilder = struct {
    const Self = @This();
    pub const _state_type: types.StateType = .pure;

    _bind_ptr: ?*anyopaque = null,
    _bind_update_fn: ?*const fn (*anyopaque, *Vapor.Event) void = null,
    _on_change_cb: ?Vapor.ErasedEventCallback = null,

    _font_family: []const u8 = "",
    _value: ?*anyopaque = null,
    _text_field_type: types.InputTypes = .none,
    _text_field_params: ?types.TextFieldParams = null,

    _elem_type: Vapor.ElementType,
    _text: ?[]const u8 = null,
    _alt: ?[]const u8 = null,
    _aria_label: ?[]const u8 = null,
    _ui_node: ?*UINode = null,
    _id: ?[]const u8 = null,
    _style: ?*const Vapor.Style = null,
    _element: ?*Element = null,

    _animation_enter: ?[]const u8 = null,
    _animation_exit: ?[]const u8 = null,
    _name: ?[]const u8 = null,
    _used_style: bool = false,

    // Style props
    _pos: ?types.Position = null,
    _padding: ?types.Padding = null,
    _layout: ?types.Layout = null,
    _margin: ?types.Margin = null,
    _size: ?types.Size = null,
    _child_gap: ?u8 = null,
    _visual: ?types.Visual = null,
    _text_decoration: ?types.TextDecoration = null,
    _flex_wrap: ?types.FlexWrap = null,
    _interactive: ?types.Interactive = null,
    _transition: ?types.Transition = null,
    _direction: types.Direction = .row,
    _scroll: ?types.Scroll = null,
    _inlineStyle: ?[]const u8 = null,
    _class: ?[]const u8 = null,
    _accessibility: ?Accessibility = null,

    // Extract to helper:
    fn getOrCreateNode(self: *const Self, new_self: *Self) *UINode {
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

    // Each method is declared here and calls its body in text_field/. An alias
    // (`pub const width = StyleMethods.width;`) would be shorter, but editors
    // (ZLS) then complete none of its arguments. A test checks each body has
    // its method here.
    const StyleMethods = @import("text_field/style.zig");
    /// Truncates overflowing text with "…". Text elements only; ignored (with a
    /// warning) elsewhere.
    pub inline fn ellipsis(self: *const Self, value: types.Ellipsis) Self {
        return StyleMethods.ellipsis(self, value);
    }

    /// Overflow behaviour on each axis, e.g. `.scroll(.{ .y = .scroll })`.
    pub inline fn scroll(self: *const Self, scroll_type: types.Scroll) Self {
        return StyleMethods.scroll(self, scroll_type);
    }

    /// Font weight: 100 to 900.
    pub inline fn fontWeight(self: *const Self, value: u16) Self {
        return StyleMethods.fontWeight(self, value);
    }

    /// Text colour.
    pub inline fn textColor(self: *const Self, color: ?Color) Self {
        return StyleMethods.textColor(self, color);
    }

    /// Font size in pixels.
    pub inline fn fontSize(self: *const Self, font_size: u8) Self {
        return StyleMethods.fontSize(self, font_size);
    }

    /// CSS font family, e.g. `"Inter, sans-serif"`.
    pub inline fn fontFamily(self: *const Self, font_family: []const u8) Self {
        return StyleMethods.fontFamily(self, font_family);
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

    /// Styles for interaction states: hover, focus and focus-within.
    pub inline fn interaction(self: *const Self, interactive: types.Interactive) Self {
        return StyleMethods.interaction(self, interactive);
    }

    /// How whitespace and line breaks in the text are handled (CSS `white-space`).
    pub inline fn whiteSpace(self: *const Self, value: types.WhiteSpace) Self {
        return StyleMethods.whiteSpace(self, value);
    }

    /// This function takes a const pointer to a Style Struct, and returns the body function callback
    /// This function is static, so any styles added via chaining methods will not be applied
    pub inline fn style(self: *const Self, style_ptr: *const Vapor.Style) Self {
        return StyleMethods.style(self, style_ptr);
    }

    /// Size in pixels, weight and colour in one call: `.font(16, 600, .black)`.
    pub inline fn font(self: *const Self, font_size: u8, weight: ?u16, color: ?Color) Self {
        return StyleMethods.font(self, font_size, weight, color);
    }

    /// Font weight 700.
    pub inline fn bold(self: *const Self) Self {
        return StyleMethods.bold(self);
    }

    /// Positioning: `.pos(.{ .type = .absolute, .top = .px(0), .right = .px(0) })`.
    /// Keeps a z-index set with `zIndex`.
    pub inline fn pos(self: *const Self, position: types.Position) Self {
        return StyleMethods.pos(self, position);
    }

    /// Stacking order. `null` removes it.
    pub inline fn zIndex(self: *const Self, z_index: ?i16) Self {
        return StyleMethods.zIndex(self, z_index);
    }

    /// Gaussian blur radius in pixels. `null` removes it.
    pub inline fn blur(self: *const Self, value: ?u8) Self {
        return StyleMethods.blur(self, value);
    }

    /// How children are aligned on both axes, e.g. `.layout(.center)`.
    pub inline fn layout(self: *const Self, value: types.Layout) Self {
        return StyleMethods.layout(self, value);
    }

    /// Centres the children on both axes. Same as `.layout(.center)`.
    pub inline fn center(self: *const Self) Self {
        return StyleMethods.center(self);
    }

    /// Background colour: a literal or a theme colour. For a gradient, use `.layer`.
    pub inline fn background(self: *const Self, value: types.Color) Self {
        return StyleMethods.background(self, value);
    }

    /// Box shadow.
    pub inline fn shadow(self: *const Self, value: types.Shadow) Self {
        return StyleMethods.shadow(self, value);
    }

    /// A patterned background layer: grid, dots, lines or gradient.
    pub inline fn layer(self: *const Self, value: types.BackgroundLayer) Self {
        return StyleMethods.layer(self, value);
    }

    /// Whether children wrap onto new lines when they do not fit.
    pub inline fn wrap(self: *const Self, value: types.FlexWrap) Self {
        return StyleMethods.wrap(self, value);
    }

    /// Underline, overline or line-through, with its style and colour.
    pub inline fn textDecoration(self: *const Self, value: types.TextDecoration) Self {
        return StyleMethods.textDecoration(self, value);
    }

    /// Grows the element slightly (to 104%) while hovered.
    pub inline fn hoverScale(self: *const Self) Self {
        return StyleMethods.hoverScale(self);
    }

    /// Outline style and colour; unlike a border, it takes no space.
    pub inline fn outline(self: *const Self, value: types.Outline, color: ?Color) Self {
        return StyleMethods.outline(self, value, color);
    }

    /// Shape of the text cursor.
    pub inline fn caret(self: *const Self, value: types.Caret) Self {
        return StyleMethods.caret(self, value);
    }

    /// Whether the user can resize the field: `.none`, `.both`, `.horizontal`,
    /// `.vertical`.
    pub inline fn resize(self: *const Self, value: types.Resize) Self {
        return StyleMethods.resize(self, value);
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

    /// Text colour while hovered.
    pub inline fn hoverText(self: *const Self, color: types.Color) Self {
        return StyleMethods.hoverText(self, color);
    }

    /// Gap between children, in pixels.
    pub inline fn spacing(self: *const Self, value: u8) Self {
        return StyleMethods.spacing(self, value);
    }

    /// Inner spacing on every side: `.padding(.all(16))`,
    /// `.padding(.{ .left = 12, .top = 4 })`. Replaces all four sides, so set it
    /// before `.pl`, `.padX` and the other one-side shorthands.
    pub inline fn padding(self: *const Self, value: types.Padding) Self {
        return StyleMethods.padding(self, value);
    }

    /// Left padding in pixels; keeps the other sides.
    pub inline fn pl(self: *const Self, value: u8) Self {
        return StyleMethods.pl(self, value);
    }

    /// Right padding in pixels; keeps the other sides.
    pub inline fn pr(self: *const Self, value: u8) Self {
        return StyleMethods.pr(self, value);
    }

    /// Top padding in pixels; keeps the other sides.
    pub inline fn pt(self: *const Self, value: u8) Self {
        return StyleMethods.pt(self, value);
    }

    /// Bottom padding in pixels; keeps the other sides.
    pub inline fn pb(self: *const Self, value: u8) Self {
        return StyleMethods.pb(self, value);
    }

    /// Left and right padding in pixels; keeps the top and bottom.
    pub inline fn padX(self: *const Self, value: u8) Self {
        return StyleMethods.padX(self, value);
    }

    /// Top and bottom padding in pixels; keeps the left and right.
    pub inline fn padY(self: *const Self, value: u8) Self {
        return StyleMethods.padY(self, value);
    }

    /// Mouse cursor shown over the element.
    pub inline fn cursor(self: *const Self, value: types.Cursor) Self {
        return StyleMethods.cursor(self, value);
    }

    /// Outer spacing on every side: `.margin(.all(8))`, `.margin(.{ .top = 4 })`.
    /// Replaces all four sides, so set it before `.mt`, `.mx` and the other
    /// one-side shorthands.
    pub inline fn margin(self: *const Self, value: types.Margin) Self {
        return StyleMethods.margin(self, value);
    }

    /// Top margin in pixels (negative allowed); keeps the other sides.
    pub inline fn mt(self: *const Self, value: i16) Self {
        return StyleMethods.mt(self, value);
    }

    /// Bottom margin in pixels (negative allowed); keeps the other sides.
    pub inline fn mb(self: *const Self, value: i16) Self {
        return StyleMethods.mb(self, value);
    }

    /// Left margin in pixels (negative allowed); keeps the other sides.
    pub inline fn ml(self: *const Self, value: i16) Self {
        return StyleMethods.ml(self, value);
    }

    /// Right margin in pixels (negative allowed); keeps the other sides.
    pub inline fn mr(self: *const Self, value: i16) Self {
        return StyleMethods.mr(self, value);
    }

    /// Top and bottom margin in pixels; keeps the left and right.
    pub inline fn my(self: *const Self, value: i16) Self {
        return StyleMethods.my(self, value);
    }

    /// Left and right margin in pixels; keeps the top and bottom.
    pub inline fn mx(self: *const Self, value: i16) Self {
        return StyleMethods.mx(self, value);
    }

    /// Width and height together: `.size(.full)`, `.size(.squarePx(48))`.
    pub inline fn size(self: *const Self, dim: types.Size) Self {
        return StyleMethods.size(self, dim);
    }

    /// Height, then width.
    pub inline fn hw(self: *const Self, height_value: types.Sizing, width_value: types.Sizing) Self {
        return StyleMethods.hw(self, height_value, width_value);
    }

    /// Width: `.width(.px(320))`, `.width(.percent(50))`, `.width(.expand)` (fill the
    /// available space), ...
    pub inline fn width(self: *const Self, length: types.Sizing) Self {
        return StyleMethods.width(self, length);
    }

    /// Height, with the same sizes as `width`.
    pub inline fn height(self: *const Self, length: types.Sizing) Self {
        return StyleMethods.height(self, length);
    }

    /// Border thickness, colour, radius and style together.
    pub inline fn border(self: *const Self, value: types.Border) Self {
        return StyleMethods.border(self, value);
    }

    /// Corner radius; keeps the other border settings.
    pub inline fn radius(self: *const Self, value: types.BorderRadius) Self {
        return StyleMethods.radius(self, value);
    }

    /// Transition duration in milliseconds. Replaces any `.transition(...)`.
    pub inline fn duration(self: *const Self, value: u32) Self {
        return StyleMethods.duration(self, value);
    }

    /// Main axis for the children: `.row` or `.column`.
    pub inline fn direction(self: *const Self, value: types.Direction) Self {
        return StyleMethods.direction(self, value);
    }

    /// Adds a CSS class, for rules you inject yourself.
    pub inline fn class(self: *const Self, class_name: []const u8) Self {
        return StyleMethods.class(self, class_name);
    }

    /// Raw CSS for the element's `style` attribute, formatted like `std.fmt`:
    /// `.inlineStyle("grid-area: {s};", .{area})`. Prefer the typed methods; this is
    /// the escape hatch.
    pub inline fn inlineStyle(self: *const Self, comptime fmt: []const u8, args: anytype) Self {
        return StyleMethods.inlineStyle(self, fmt, args);
    }

    const FieldMethods = @import("text_field/value.zig");
    pub const TextArea = FieldMethods.TextArea;
    pub const TextField = FieldMethods.TextField;
    /// Hint shown while the field is empty: a string, or a number for `.int` and
    /// `.float` fields.
    pub inline fn placeholder(self: *const Self, value: anytype) Self {
        return FieldMethods.placeholder(self, value);
    }

    /// The form field name (`name` attribute) a `Form` submits it under.
    pub inline fn fieldName(self: *const Self, name: []const u8) Self {
        return FieldMethods.fieldName(self, name);
    }

    /// Marks the field required. Only `.radio` fields support it so far; for other
    /// kinds it is ignored.
    pub inline fn required(self: *const Self, value: bool) Self {
        return FieldMethods.required(self, value);
    }

    /// Initial text of the field. Not kept in sync; use `.bind` for that.
    pub inline fn valStr(self: *const Self, value: []const u8) Self {
        return FieldMethods.valStr(self, value);
    }

    /// Shows the value `value` points to.
    pub inline fn val(self: *const Self, value: anytype) Self {
        return FieldMethods.val(self, value);
    }

    /// Two-way binding: shows the value `value` points to and writes the user's
    /// edits back to it. The pointee's type must match the field (`[]const u8` for
    /// text kinds, an integer for `.int`, a float for `.float`).
    pub inline fn bind(self: *const Self, value: anytype) Self {
        return FieldMethods.bind(self, value);
    }

    /// Length limits (`min`, `max`) for `.string` and `.int` fields; ignored for
    /// other kinds.
    pub inline fn config(self: *const Self, text_field_config: types.TextFieldConfig) Self {
        return FieldMethods.config(self, text_field_config);
    }

    const EventMethods = @import("text_field/events.zig");
    /// Focuses the field once it is on the page.
    pub inline fn focus(self: *const Self) Self {
        return EventMethods.focus(self);
    }

    /// Calls `cb` with the event when the element gains focus.
    pub inline fn onFocus(self: *const Self, cb: fn (*Vapor.Event) void) Self {
        return EventMethods.onFocus(self, cb);
    }

    /// Calls `cb` with the event when the element loses focus.
    pub inline fn onBlur(self: *const Self, cb: fn (*Vapor.Event) void) Self {
        return EventMethods.onBlur(self, cb);
    }

    /// Calls `callback` with `args` and the event when the field scrolls.
    pub inline fn onScroll(self: *const Self, callback: anytype, args: anytype) Self {
        return EventMethods.onScroll(self, callback, args);
    }

    /// Calls `func` with `args` and the event whenever `event` fires on the element:
    /// `.onEvent(.keydown, onKey, .{&state})`.
    pub inline fn onEvent(self: *const Self, event: types.EventType, func: anytype, args: anytype) *const Self {
        return EventMethods.onEvent(self, event, func, args);
    }

    /// Calls `callback` with `args` once the element is on the page.
    pub inline fn onMount(self: *const Self, callback: anytype, args: anytype) *const Self {
        return EventMethods.onMount(self, callback, args);
    }

    /// Calls `func` with `args` and then the event whenever the element's value
    /// changes (the DOM `input` event).
    pub inline fn onChange(self: *const Self, func: anytype, args: anytype) Self {
        return EventMethods.onChange(self, func, args);
    }

    /// Calls `cb` with the event on every key press in the field.
    pub inline fn onKeyDown(self: *const Self, cb: fn (*Vapor.Event) void) Self {
        return EventMethods.onKeyDown(self, cb);
    }

    /// Calls `cb` with the event when the pointer enters the field.
    pub inline fn onHover(self: *const Self, cb: fn (*Vapor.Event) void) Self {
        return EventMethods.onHover(self, cb);
    }

    /// Calls `cb` with the event when the pointer leaves the field.
    pub inline fn onLeave(self: *const Self, cb: fn (*Vapor.Event) void) Self {
        return EventMethods.onLeave(self, cb);
    }

    /// Calls `cb` with `args` and the event when the pointer enters the element
    /// (mouseenter).
    pub inline fn onHoverCtx(self: *const Self, cb: anytype, args: anytype) Self {
        return EventMethods.onHoverCtx(self, cb, args);
    }

    /// Fills `element` with a handle to this element, for reading its size, scroll
    /// position or attributes after it is on the page. Start `element` as `.{}`,
    /// never `undefined`: the render reads its other fields (styles set through it).
    pub inline fn ref(self: *const Self, element: *Element) Self {
        return EventMethods.ref(self, element);
    }

    const AttributeMethods = @import("text_field/attributes.zig");
    /// Gives the field a stable identity, the same as `.id()` on the
    /// element builders.
    ///
    /// The generated uuid encodes the child's position, so a field that
    /// moves is seen by the reconciler as a delete plus an insert. `_id`
    /// also travels through `end()` into the style, which is where
    /// `Configuration` picks it up; setting the uuid here as well means the
    /// identity is established as soon as the caller asks for it.
    pub inline fn id(self: *const Self, element_id: []const u8) Self {
        return AttributeMethods.id(self, element_id);
    }

    /// Set full accessibility config
    pub inline fn a11y(self: *const Self, accessibility: Accessibility) Self {
        return AttributeMethods.a11y(self, accessibility);
    }

    /// Shorthand: just set aria-label
    pub inline fn ariaLabel(self: *const Self, label: []const u8) Self {
        return AttributeMethods.ariaLabel(self, label);
    }

    /// Shorthand: set role
    pub inline fn role(self: *const Self, r: Accessibility.Role) Self {
        return AttributeMethods.role(self, r);
    }

    /// Shorthand: aria-expanded
    pub inline fn ariaExpanded(self: *const Self, expanded: bool) Self {
        return AttributeMethods.ariaExpanded(self, expanded);
    }

    /// Shorthand: aria-selected
    pub inline fn ariaSelected(self: *const Self, selected: bool) Self {
        return AttributeMethods.ariaSelected(self, selected);
    }

    /// Shorthand: aria-controls
    pub inline fn ariaControls(self: *const Self, uuid: []const u8) Self {
        return AttributeMethods.ariaControls(self, uuid);
    }

    /// Shorthand: aria-activedescendant
    pub inline fn ariaActiveDescendant(self: *const Self, uuid: ?[]const u8) Self {
        return AttributeMethods.ariaActiveDescendant(self, uuid);
    }

    /// Shorthand: aria-hidden
    pub inline fn ariaHidden(self: *const Self, hidden_val: bool) Self {
        return AttributeMethods.ariaHidden(self, hidden_val);
    }

    /// Shorthand: tabindex
    pub inline fn tabIndex(self: *const Self, index: i16) Self {
        return AttributeMethods.tabIndex(self, index);
    }

    /// Finishes the field: merges its style, attaches the bind/change handler and
    /// configures the node.
    pub fn end(self: *const Self) void {
        if (self._used_style) return;
        // Vapor.LifeCycle.close({});
        var mutable_style = Style{};
        if (self._style) |style_ptr| {
            mutable_style = style_ptr.*;
        }
        if (mutable_style.position == null) mutable_style.position = self._pos;
        if (mutable_style.visual == null) mutable_style.visual = self._visual;
        if (mutable_style.interactive == null) mutable_style.interactive = self._interactive;
        if (mutable_style.child_gap == null) mutable_style.child_gap = self._child_gap;
        if (mutable_style.padding == null) mutable_style.padding = self._padding;
        if (mutable_style.layout == null) mutable_style.layout = self._layout;
        if (mutable_style.margin == null) mutable_style.margin = self._margin;
        if (mutable_style.size == null) mutable_style.size = self._size;
        if (mutable_style.transition == null) mutable_style.transition = self._transition;
        if (mutable_style.flex_wrap == null) mutable_style.flex_wrap = self._flex_wrap;
        mutable_style.direction = self._direction;
        if (mutable_style.font_family == null) mutable_style.font_family = self._font_family;
        if (mutable_style.scroll == null) mutable_style.scroll = self._scroll;

        if (self._id) |_id| {
            mutable_style.id = _id;
        }

        if (self._class) |_class| {
            mutable_style.style_id = _class;
        }

        var elem_decl = Vapor.ElementDecl{
            .state_type = _state_type,
            .elem_type = self._elem_type,
            .text = self._text,
            .style = &mutable_style,
            .alt = self._alt,
            .aria_label = self._aria_label,
            .animation_enter = self._animation_enter,
            .animation_exit = self._animation_exit,
            .name = self._name,
            .inlineStyle = self._inlineStyle,
            .accessibility = self._accessibility,
        };

        if (self._text_field_params) |params| {
            elem_decl.text_field_params = params;
        }

        if (self._bind_update_fn != null or self._on_change_cb != null) {
            const node = self._ui_node orelse @panic("vapor: TextField has no node");

            Vapor.attachEventCtxCallback(node, .input, struct {
                /// Internal: the input handler `end` attaches; updates the bound value, then
                /// calls the user's `onChange`.
                pub fn handler(ctx_opaque: Ctx, evt: *Vapor.Event) void {
                    const ctx: Ctx = ctx_opaque;
                    // 1. Update bound value if present
                    if (ctx.bind_fn) |f| f(ctx.bind_ptr.?, evt);
                    // 2. Call user's onChange if present
                    if (ctx.user_cb) |cb| cb.call(evt);
                }
            }.handler, .{Ctx{
                .bind_ptr = self._bind_ptr,
                .bind_fn = self._bind_update_fn,
                .user_cb = self._on_change_cb,
            }}) catch |err| {
                Vapor.report.err("text field: could not attach change handler: {any}", .{err});
            };
        }

        _ = Vapor.current_ctx.configureByNode(self._ui_node, elem_decl);
    }

    /// Finishes the field without any style.
    pub fn plain(self: *const Self) void {
        const elem_decl = Vapor.ElementDecl{
            .state_type = _state_type,
            .elem_type = self._elem_type,
            .text = self._text,
        };
        _ = Vapor.LifeCycle.open(elem_decl);
        Vapor.LifeCycle.configure(elem_decl);
        Vapor.LifeCycle.close({});
    }

    /// The field's id.
    pub fn getUUID(self: *const Self) []const u8 {
        if (self._ui_node == null) {
            Vapor.report.err("getUUID Failed: Node is null", .{});
            return "";
        }
        return self._ui_node.?.uuid;
    }
};

/// Kept for source compatibility; every state type gets the same builder.
pub fn Builder(comptime state_type: types.StateType) type {
    _ = state_type;
    return TextFieldBuilder;
}

var name_len: usize = 0;
const FieldExportString = DynamicObject.exportStruct(types.InputParamsString);
const FieldExportInt = DynamicObject.exportStruct(types.InputParamsInt);
const FieldExportPassword = DynamicObject.exportStruct(types.InputParamsPassword);
const FieldExportEmail = DynamicObject.exportStruct(types.InputParamsEmail);
const FieldExportTelephone = DynamicObject.exportStruct(types.InputParamsTelephone);
const FieldExportFile = DynamicObject.exportStruct(types.InputParamsFile);
const FieldExportFloat = DynamicObject.exportStruct(types.InputParamsFloat);
const FieldExportDate = DynamicObject.exportStruct(types.InputParamsDate);
const FieldExportRadio = DynamicObject.exportStruct(types.InputParamsRadio);

const API = struct {
    /// Runtime export: a field's `name`.
    pub fn getFieldName(node_ptr: *UINode) callconv(.c) ?[*]const u8 {
        if (node_ptr.name) |name| {
            name_len = name.len;
            return name.ptr;
        }
        return null;
    }

    /// Runtime export: length of the last field name.
    pub fn getFieldNameLen() callconv(.c) usize {
        return name_len;
    }

    /// Runtime export: a field's parameters (kind, placeholder, value, limits).
    pub fn getTextFieldParams(node_ptr: ?*UINode) callconv(.c) ?[*]const u8 {
        const text_field_params = node_ptr.?.text_field_params orelse return null;
        switch (text_field_params.*) {
            .string => |string| {
                FieldExportString.init();
                FieldExportString.instance = string;
                return FieldExportString.getInstancePtr();
            },
            .int => |int| {
                FieldExportInt.init();
                FieldExportInt.instance = int;
                return FieldExportInt.getInstancePtr();
            },
            .password => |password| {
                FieldExportPassword.init();
                FieldExportPassword.instance = password;
                return FieldExportPassword.getInstancePtr();
            },
            .email => |email| {
                FieldExportEmail.init();
                FieldExportEmail.instance = email;
                return FieldExportEmail.getInstancePtr();
            },
            .telephone => |telephone| {
                FieldExportTelephone.init();
                FieldExportTelephone.instance = telephone;
                return FieldExportTelephone.getInstancePtr();
            },
            .file => |file| {
                FieldExportFile.init();
                FieldExportFile.instance = file;
                return FieldExportFile.getInstancePtr();
            },
            .float => |float| {
                FieldExportFloat.init();
                FieldExportFloat.instance = float;
                return FieldExportFloat.getInstancePtr();
            },
            .date => |date| {
                FieldExportDate.init();
                FieldExportDate.instance = date;
                return FieldExportDate.getInstancePtr();
            },
            .radio => |radio| {
                FieldExportRadio.init();
                FieldExportRadio.instance = radio;
                return FieldExportRadio.getInstancePtr();
            },
        }
        return null;
    }

    /// Runtime export: the number of parameter fields.
    pub fn getTextFieldCount(node_ptr: *UINode) callconv(.c) u32 {
        const text_field_params = node_ptr.text_field_params orelse {
            Vapor.report.err("Error: No text_field_params found {any}", .{node_ptr.type});
            return 0;
        };
        switch (text_field_params.*) {
            .string => {
                return FieldExportString.getFieldCount();
            },
            .int => {
                return FieldExportInt.getFieldCount();
            },
            .password => {
                return FieldExportPassword.getFieldCount();
            },
            .email => {
                return FieldExportEmail.getFieldCount();
            },
            .telephone => {
                return FieldExportTelephone.getFieldCount();
            },
            .file => {
                return FieldExportFile.getFieldCount();
            },
            .float => {
                return FieldExportFloat.getFieldCount();
            },
            .date => {
                return FieldExportDate.getFieldCount();
            },
            .radio => {
                return FieldExportRadio.getFieldCount();
            },
        }
        return 0;
    }

    /// Runtime export: one parameter field's layout.
    pub fn getTextFieldDescriptor(node_ptr: ?*UINode, index: u32) callconv(.c) ?*const DynamicObject.FieldDescriptor() {
        const text_field_params = node_ptr.?.text_field_params orelse return null;
        switch (text_field_params.*) {
            .string => {
                return FieldExportString.getFieldDescriptor(index);
            },
            .int => {
                return FieldExportInt.getFieldDescriptor(index);
            },
            .password => {
                return FieldExportPassword.getFieldDescriptor(index);
            },
            .email => {
                return FieldExportEmail.getFieldDescriptor(index);
            },
            .telephone => {
                return FieldExportTelephone.getFieldDescriptor(index);
            },
            .file => {
                return FieldExportFile.getFieldDescriptor(index);
            },
            .float => {
                return FieldExportFloat.getFieldDescriptor(index);
            },
            .date => {
                return FieldExportDate.getFieldDescriptor(index);
            },
            .radio => {
                return FieldExportRadio.getFieldDescriptor(index);
            },
        }
        return null;
    }
};

// --- Auto-Export Magic ---
// This runs automatically when this file is imported
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
    const B = TextFieldBuilder;
    inline for (.{ B.StyleMethods, B.FieldMethods, B.EventMethods, B.AttributeMethods }) |Methods| {
        try utils.expectWrapsMethods(B, Methods);
    }
}
