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
const utils = @import("utils.zig");
const hashKey = utils.hashKey;
const DynamicObject = @import("Dynamic.zig");
const Accessibility = @import("Accessibility.zig").Accessibility;

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
            Vapor.printlnSrcErr("Node is null", .{}, @src());
            @panic("vapor: Node is null");
        };
        new_self._ui_node = node;
        return node;
    }

    const StyleMethods = @import("text_field/style.zig");
    pub const ellipsis = StyleMethods.ellipsis;
    pub const scroll = StyleMethods.scroll;
    pub const fontWeight = StyleMethods.fontWeight;
    pub const fontColor = StyleMethods.fontColor;
    pub const whitespace = StyleMethods.whitespace;
    pub const fontSize = StyleMethods.fontSize;
    pub const fontFamily = StyleMethods.fontFamily;
    pub const animationEnter = StyleMethods.animationEnter;
    pub const animation = StyleMethods.animation;
    pub const animationExit = StyleMethods.animationExit;
    pub const baseStyle = StyleMethods.baseStyle;
    pub const interaction = StyleMethods.interaction;
    pub const whiteSpace = StyleMethods.whiteSpace;
    pub const style = StyleMethods.style;
    pub const font = StyleMethods.font;
    pub const bold = StyleMethods.bold;
    pub const pos = StyleMethods.pos;
    pub const zIndex = StyleMethods.zIndex;
    pub const blur = StyleMethods.blur;
    pub const layout = StyleMethods.layout;
    pub const center = StyleMethods.center;
    pub const background = StyleMethods.background;
    pub const shadow = StyleMethods.shadow;
    pub const layer = StyleMethods.layer;
    pub const wrap = StyleMethods.wrap;
    pub const textDecoration = StyleMethods.textDecoration;
    pub const hoverScale = StyleMethods.hoverScale;
    pub const outline = StyleMethods.outline;
    pub const caret = StyleMethods.caret;
    pub const resize = StyleMethods.resize;
    pub const hoverBackground = StyleMethods.hoverBackground;
    pub const pointer = StyleMethods.pointer;
    pub const noDecoration = StyleMethods.noDecoration;
    pub const hoverText = StyleMethods.hoverText;
    pub const childGap = StyleMethods.childGap;
    pub const spacing = StyleMethods.spacing;
    pub const padding = StyleMethods.padding;
    pub const pl = StyleMethods.pl;
    pub const pr = StyleMethods.pr;
    pub const pt = StyleMethods.pt;
    pub const pb = StyleMethods.pb;
    pub const cursor = StyleMethods.cursor;
    pub const margin = StyleMethods.margin;
    pub const size = StyleMethods.size;
    pub const hw = StyleMethods.hw;
    pub const width = StyleMethods.width;
    pub const height = StyleMethods.height;
    pub const border = StyleMethods.border;
    pub const radius = StyleMethods.radius;
    pub const duration = StyleMethods.duration;
    pub const direction = StyleMethods.direction;
    pub const class = StyleMethods.class;
    pub const inlineStyle = StyleMethods.inlineStyle;

    const FieldMethods = @import("text_field/value.zig");
    pub const TextArea = FieldMethods.TextArea;
    pub const TextField = FieldMethods.TextField;
    pub const placeholder = FieldMethods.placeholder;
    pub const fieldName = FieldMethods.fieldName;
    pub const required = FieldMethods.required;
    pub const valStr = FieldMethods.valStr;
    pub const val = FieldMethods.val;
    pub const bind = FieldMethods.bind;
    pub const config = FieldMethods.config;

    const EventMethods = @import("text_field/events.zig");
    pub const focus = EventMethods.focus;
    pub const onFocus = EventMethods.onFocus;
    pub const onBlur = EventMethods.onBlur;
    pub const onScroll = EventMethods.onScroll;
    pub const onEvent = EventMethods.onEvent;
    pub const onEventCtx = EventMethods.onEventCtx;
    pub const onMount = EventMethods.onMount;
    pub const onChange = EventMethods.onChange;
    pub const onKeyDown = EventMethods.onKeyDown;
    pub const onHover = EventMethods.onHover;
    pub const onLeave = EventMethods.onLeave;
    pub const onHoverCtx = EventMethods.onHoverCtx;
    pub const ref = EventMethods.ref;

    const AttributeMethods = @import("text_field/attributes.zig");
    pub const id = AttributeMethods.id;
    pub const a11y = AttributeMethods.a11y;
    pub const ariaLabel = AttributeMethods.ariaLabel;
    pub const role = AttributeMethods.role;
    pub const ariaExpanded = AttributeMethods.ariaExpanded;
    pub const ariaSelected = AttributeMethods.ariaSelected;
    pub const ariaControls = AttributeMethods.ariaControls;
    pub const ariaActiveDescendant = AttributeMethods.ariaActiveDescendant;
    pub const ariaHidden = AttributeMethods.ariaHidden;
    pub const tabIndex = AttributeMethods.tabIndex;

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
                Vapor.printlnErr("text field: could not attach change handler: {any}", .{err});
            };
        }

        _ = Vapor.current_ctx.configureByNode(self._ui_node, elem_decl);
    }

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

    pub fn getUUID(self: *const Self) []const u8 {
        if (self._ui_node == null) {
            Vapor.printlnSrcErr("getUUID Failed: Node is null", .{}, @src());
            return "";
        }
        return self._ui_node.?.uuid;
    }
};

/// Kept for source compatibility; every state type gets the same builder.
pub fn BuilderClose(comptime state_type: types.StateType) type {
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
    pub fn getFieldName(node_ptr: *UINode) callconv(.c) ?[*]const u8 {
        if (node_ptr.name) |name| {
            name_len = name.len;
            return name.ptr;
        }
        return null;
    }

    pub fn getFieldNameLen() callconv(.c) usize {
        return name_len;
    }

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

    pub fn getTextFieldCount(node_ptr: *UINode) callconv(.c) u32 {
        const text_field_params = node_ptr.text_field_params orelse {
            Vapor.printErr("Error: No text_field_params found {any}", .{node_ptr.type});
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
