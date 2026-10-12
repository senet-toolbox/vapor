//! The element constructors (`Box`, `Text`, `Button`, ...). Each opens a node
//! and returns a ComponentBuilder. Aliased from components.zig.

const Components = @import("../components.zig");
const Self = Components.ComponentBuilder;
const types = @import("../types.zig");
const Vapor = @import("../vapor.zig");
const LifeCycle = @import("../vapor.zig").LifeCycle;
const println = Vapor.println;
const ElementDecl = types.ElementDeclaration;
const IconTokens = @import("config").IconTokens;
const utils = @import("../utils.zig");
const hashKey = utils.hashKey;

/// An empty placeholder node. Renders nothing, but holds a position among its
/// siblings so conditional content does not shift the keys of what follows.
pub fn Null() void {
    _ = LifeCycle.open(.{ .elem_type = .Noop, .state_type = Self._state_type });
    LifeCycle.configure(.{ .elem_type = .Noop, .state_type = Self._state_type });
    LifeCycle.close({});
}

/// `<h1>`..`<h6>`: `Heading(2, "Settings").end()`.
pub fn Heading(level: u8, text: []const u8) Self {
    const ui_node = Components.createNode(.{ .state_type = Self._state_type, .elem_type = .Heading, .text = text, .level = level });
    return Self{ ._elem_type = .Heading, ._text = text, ._level = level, ._ui_node = ui_node, ._returns_close = false };
}

/// `<video>` playing `options.src`. Pass a pointer to a value that outlives the
/// render (a global or `Vapor.persist` allocation).
pub fn Video(options: *const types.Video) Self {
    const ui_node = Vapor.current_ctx.open(.{ .state_type = Self._state_type, .elem_type = .Video, .can_have_children = false }) catch |err| {
        Vapor.report.err("{any}", .{err});
        @panic("vapor: could not allocate a Video node");
    };
    return Self{ ._elem_type = .Video, ._video = options, ._ui_node = ui_node, ._returns_close = false };
}

/// A flex container (`<div>`), laid out as a row unless `.direction(.column)`.
/// Finish with `.children({ ... })`.
pub fn Box() Self {
    const ui_node = Components.createNode(.{ .state_type = Self._state_type, .elem_type = .FlexBox });
    return Self{ ._ui_node = ui_node, ._elem_type = .FlexBox, ._returns_close = true };
}

/// A flex container laid out as a row. Same as `Box`.
pub fn Row() Self {
    const ui_node = Components.createNode(.{ .state_type = Self._state_type, .elem_type = .FlexBox });
    return Self{ ._ui_node = ui_node, ._elem_type = .FlexBox, ._returns_close = true };
}

/// A container rendered into a top-level layer (tooltip, popover, modal, toast)
/// so it stacks above the page. The element moves into the page element with id
/// `layer-<name>`; when the page has none, it renders in place.
pub fn Layer(layer_type: types.Layers) Self {
    const ui_node = Components.createNode(.{ .state_type = Self._state_type, .elem_type = .FlexBox });
    ui_node.layer = layer_type;
    return Self{ ._ui_node = ui_node, ._elem_type = .FlexBox, ._returns_close = true };
}

/// `<table>`. Nest `TableHead`/`TableBody`, then `TableRow`, then `TableCell`.
pub fn Table() Self {
    return Self{ ._ui_node = Components.createNode(.{ .state_type = Self._state_type, .elem_type = .Table }), ._elem_type = .Table, ._returns_close = true };
}

/// `<tr>`.
pub fn TableRow() Self {
    return Self{ ._ui_node = Components.createNode(.{ .state_type = Self._state_type, .elem_type = .TableRow }), ._elem_type = .TableRow, ._returns_close = true };
}

/// `<td>`.
pub fn TableCell() Self {
    return Self{ ._ui_node = Components.createNode(.{ .state_type = Self._state_type, .elem_type = .TableCell }), ._elem_type = .TableCell, ._returns_close = true };
}

/// `<tbody>`.
pub fn TableBody() Self {
    return Self{ ._ui_node = Components.createNode(.{ .state_type = Self._state_type, .elem_type = .TableBody }), ._elem_type = .TableBody, ._returns_close = true };
}

/// `<th>`, a header cell.
pub fn TableHeader() Self {
    return Self{ ._ui_node = Components.createNode(.{ .state_type = Self._state_type, .elem_type = .TableHeader }), ._elem_type = .TableHeader, ._returns_close = true };
}

/// `<thead>`.
pub fn TableHead() Self {
    return Self{ ._ui_node = Components.createNode(.{ .state_type = Self._state_type, .elem_type = .TableHead }), ._elem_type = .TableHead, ._returns_close = true };
}

/// `<form>` that calls `submit` with `args` when submitted. Read the fields in
/// the handler with `Event.formData`.
pub fn Form(submit: anytype, args: anytype) Self {
    const ui_node = Components.createNode(.{ .state_type = Self._state_type, .elem_type = .Form });
    Vapor.attachEventCtxCallback(ui_node, .submit, submit, args) catch |err| {
        Vapor.report.err("Form: could not attach the event callback: {any}", .{err});
        @panic("vapor: ONSUBMIT: Could not attach event callback");
    };
    return Self{ ._ui_node = ui_node, ._elem_type = .Form, ._returns_close = true };
}

/// `<section>`.
pub fn Section() Self {
    const ui_node = LifeCycle.open(.{ .state_type = Self._state_type, .elem_type = .Intersection }) orelse {
        Vapor.report.err("Could not add component to lifecycle {any}", .{error.CouldNotAllocate});
        @panic("vapor: Could not add component to lifecycle");
    };
    return Self{ ._ui_node = ui_node, ._elem_type = .Intersection, ._returns_close = true };
}

/// `<ul>`. Put `ListItem`s in it.
pub fn List() Self {
    const ui_node = LifeCycle.open(.{ .state_type = Self._state_type, .elem_type = .List }) orelse {
        Vapor.report.err("Could not add component to lifecycle {any}", .{error.CouldNotAllocate});
        @panic("vapor: Could not add component to lifecycle");
    };
    return Self{ ._ui_node = ui_node, ._elem_type = .List, ._returns_close = true };
}

/// `<li>`.
pub fn ListItem() Self {
    const ui_node = LifeCycle.open(.{ .state_type = Self._state_type, .elem_type = .ListItem }) orelse {
        Vapor.report.err("Could not add component to lifecycle {any}", .{error.CouldNotAllocate});
        @panic("vapor: Could not add component to lifecycle");
    };
    return Self{ ._ui_node = ui_node, ._elem_type = .ListItem, ._returns_close = true };
}

/// A flex container that centres its children on both axes.
pub fn Center() *Self {
    const ui_node = LifeCycle.open(.{ .state_type = Self._state_type, .elem_type = .FlexBox }) orelse {
        Vapor.report.err("Could not add component to lifecycle {any}", .{error.CouldNotAllocate});
        @panic("vapor: Could not add component to lifecycle");
    };
    const self = Vapor.arena(.frame).create(Self) catch |err| {
        Vapor.report.err("component builder: allocation failed: {any}", .{err});
        @panic("vapor: out of memory creating a component");
    };
    self.* = .{
        ._ui_node = ui_node,
        ._elem_type = .FlexBox,
        ._flex_type = .center,
        ._returns_close = true,
    };
    return self;
}

/// `<button type="submit">` for the enclosing `Form`.
pub fn SubmitButton() Self {
    const elem_decl = ElementDecl{
        .state_type = Self._state_type,
        .elem_type = .SubmitButton,
    };

    const ui_node = LifeCycle.open(elem_decl) orelse {
        Vapor.report.err("LifeCycle open could not allocate {any}", .{error.CouldNotAllocate});
        @panic("vapor: LifeCycle open could not allocate");
    };

    return Self{ ._elem_type = .SubmitButton, ._ui_node = ui_node, ._returns_close = true };
}

/// `<button>` that calls `cb` with `args` when clicked: `Button(save, .{id})`.
/// Finish with `.children({ ... })` for its label.
pub fn Button(cb: anytype, args: anytype) Self {
    const elem_decl = ElementDecl{
        .state_type = Self._state_type,
        .elem_type = .CtxButton,
    };

    const ui_node = LifeCycle.open(elem_decl) orelse {
        Vapor.report.err("LifeCycle open could not allocate {any}", .{error.CouldNotAllocate});
        @panic("vapor: LifeCycle open could not allocate");
    };

    const erased = Vapor.ErasedCallback.make(Vapor.arena(.frame), cb, args) catch |err| {
        Vapor.report.err("could not create closure: {any}", .{err});
        @panic("vapor: Error could not create closure");
    };

    const callback_id = hashKey(ui_node.uuid);
    Vapor.button_callbacks.put(callback_id, erased) catch |err| {
        Vapor.report.err("Registry error {any}", .{err});
        @panic("vapor: Registry error");
    };

    return Self{ ._elem_type = .CtxButton, ._ui_node = ui_node, ._returns_close = true };
}

/// A flex container laid out as a column.
pub fn Stack() Self {
    const ui_node = LifeCycle.open(.{ .state_type = Self._state_type, .elem_type = .FlexBox }) orelse {
        Vapor.report.err("Could not add component to lifecycle {any}", .{error.CouldNotAllocate});
        @panic("vapor: Could not add component to lifecycle");
    };
    ui_node.direction = .column;
    return Self{ ._ui_node = ui_node, ._elem_type = .FlexBox, ._flex_type = .stack, ._direction = .column, ._returns_close = true };
}

/// `<a>` that navigates within the app without a page load. External URLs and
/// modified clicks (new tab, other origin) behave as normal links.
pub fn Link(options: Components.LinkOptions) Self {
    const ui_node = LifeCycle.open(.{ .state_type = Self._state_type, .elem_type = .Link, .href = options.url, .aria_label = options.aria_label }) orelse {
        Vapor.report.err("Could not add component Link to lifecycle {any}", .{error.CouldNotAllocate});
        @panic("vapor: Could not add component Link to lifecycle");
    };

    return Self{ ._ui_node = ui_node, ._elem_type = .Link, ._aria_label = options.aria_label, ._href = options.url, ._returns_close = true };
}

/// `<a>` that always does a full browser navigation to `options.url`.
pub fn RedirectLink(options: Components.LinkOptions) Self {
    const ui_node = LifeCycle.open(.{ .state_type = Self._state_type, .elem_type = .RedirectLink, .href = options.url, .aria_label = options.aria_label }) orelse {
        Vapor.report.err("Could not add component Link to lifecycle {any}", .{error.CouldNotAllocate});
        @panic("vapor: Could not add component Link to lifecycle");
    };
    return Self{ ._ui_node = ui_node, ._elem_type = .RedirectLink, ._aria_label = options.aria_label, ._href = options.url, ._returns_close = true };
}

/// `<label>` with `text`.
pub fn Label(text: []const u8) Self {
    const ui_node = LifeCycle.open(.{ .state_type = .static, .elem_type = .Label, .text = text, .can_have_children = false }) orelse {
        Vapor.report.err("Could not add component to lifecycle {any}", .{error.CouldNotAllocate});
        @panic("vapor: Could not add component to lifecycle");
    };
    return Self{ ._elem_type = .Label, ._text = text, ._ui_node = ui_node, ._returns_close = false };
}

/// `<code>` showing `value`, a string or an integer.
pub fn Code(value: anytype) Self {
    const text = blk: switch (@typeInfo(@TypeOf(value))) {
        .pointer => break :blk value,
        .int => break :blk Vapor.fmtln("{any}", .{value}),
        else => {
            Vapor.report.err("Text only accepts []const u8 or number types, NOT {any}", .{@TypeOf(value)});
            return Self{ ._elem_type = .Code, ._text = "", ._returns_close = false };
        },
    };
    const ui_node = LifeCycle.open(.{ .state_type = Self._state_type, .elem_type = .Code, .can_have_children = false }) orelse {
        Vapor.report.err("Could not add component to lifecycle {any}", .{error.CouldNotAllocate});
        @panic("vapor: Could not add component to lifecycle");
    };
    return Self{ ._elem_type = .Code, ._text = text, ._ui_node = ui_node, ._returns_close = false };
}

/// Empty space `val` pixels tall that fills the available width.
pub fn Spacer(val: f32) Self {
    const ui_node = LifeCycle.open(.{ .state_type = Self._state_type, .elem_type = .Spacer, .can_have_children = false }) orelse {
        Vapor.report.err("Could not add component to lifecycle {any}", .{error.CouldNotAllocate});
        @panic("vapor: Could not add component to lifecycle");
    };
    return Self{ ._elem_type = .Spacer, ._ui_node = ui_node, ._size = .hw(.px(val), .expand), ._returns_close = false };
}

/// A bar `w` pixels wide that fills the available height. It has no colour
/// until you give it one with `.background(...)`.
pub fn Divider(w: f32) Self {
    const ui_node = LifeCycle.open(.{ .state_type = Self._state_type, .elem_type = .FlexBox, .can_have_children = false }) orelse {
        Vapor.report.err("Could not add component to lifecycle {any}", .{error.CouldNotAllocate});
        @panic("vapor: Could not add component to lifecycle");
    };
    return Self{ ._elem_type = .FlexBox, ._ui_node = ui_node, ._size = .hw(.expand, .px(w)), ._returns_close = false };
}

/// `<iframe>` loading `iframe_src`.
pub fn Iframe(iframe_src: ?[]const u8) Self {
    const ui_node = LifeCycle.open(.{ .state_type = Self._state_type, .elem_type = .Iframe, .can_have_children = false }) orelse {
        Vapor.report.err("Could not add component to lifecycle {any}", .{error.CouldNotAllocate});
        @panic("vapor: Could not add component to lifecycle");
    };
    return Self{ ._elem_type = .Iframe, ._ui_node = ui_node, ._returns_close = false, ._href = iframe_src };
}

/// `<fieldset>` for grouping form controls.
pub fn FieldSet() Self {
    const ui_node = LifeCycle.open(.{ .state_type = Self._state_type, .elem_type = .FieldSet }) orelse {
        Vapor.report.err("Could not add component to lifecycle {any}", .{error.CouldNotAllocate});
        @panic("vapor: Could not add component to lifecycle");
    };
    return Self{ ._elem_type = .FieldSet, ._ui_node = ui_node, ._returns_close = true };
}

/// Text showing a number or an enum's tag name, formatted for this render.
pub fn Number(value: anytype) Self {
    const ui_node = LifeCycle.open(.{ .state_type = Self._state_type, .elem_type = .Text, .can_have_children = false }) orelse {
        Vapor.report.err("Could not add component to lifecycle {any}", .{error.CouldNotAllocate});
        @panic("vapor: Could not add component to lifecycle");
    };
    const text = blk: switch (@typeInfo(@TypeOf(value))) {
        .int => {
            const n = Vapor.fmtln("{any}", .{value});
            Vapor.frame_arena.addBytesUsed(n.len);
            break :blk n;
        },
        .float => {
            const n = Vapor.fmtln("{any}", .{value});
            Vapor.frame_arena.addBytesUsed(n.len);
            break :blk n;
        },
        .@"enum" => {
            const n = Vapor.fmtln("{s}", .{@tagName(value)});
            Vapor.frame_arena.addBytesUsed(n.len);
            break :blk n;
        },
        else => {
            Vapor.report.err("Text only accepts []const u8 or number types, NOT {any}", .{@TypeOf(value)});
            return Self{ ._elem_type = .Text, ._text = "", ._ui_node = ui_node, ._returns_close = false };
        },
    };
    return Self{ ._elem_type = .Text, ._text = text, ._ui_node = ui_node, ._returns_close = false };
}

/// Text content: a string, a number, or an enum (shown as its tag name). The
/// string is copied, so a temporary is fine. Finish with `.end()`.
pub fn Text(value: anytype) *Self {
    const ui_node = Components.createNode(.{ .state_type = Self._state_type, .elem_type = .Text, .can_have_children = false });
    const self = Vapor.arena(.frame).create(Self) catch |err| {
        Vapor.report.err("component builder: allocation failed: {any}", .{err});
        @panic("vapor: out of memory creating a component");
    };
    const text = blk: switch (@typeInfo(@TypeOf(value))) {
        .pointer => |ptr_info| {
            if (ptr_info.size == .one) return {
                self.* = .{ ._elem_type = .Text, ._text = value, ._ui_node = ui_node, ._persisted_text = true, ._returns_close = false };
                return self;
            };

            if (ptr_info.size == .slice or ptr_info.size == .one) return {
                self.* = .{ ._elem_type = .Text, ._text = value, ._ui_node = ui_node, ._persisted_text = true, ._returns_close = false };
                return self;
            };
        },
        .int => {
            const n = Vapor.fmtln("{any}", .{value});
            Vapor.frame_arena.addBytesUsed(n.len);
            break :blk n;
        },
        .float => {
            const n = Vapor.fmtln("{any}", .{value});
            Vapor.frame_arena.addBytesUsed(n.len);
            break :blk n;
        },
        .@"enum" => {
            const n = Vapor.fmtln("{s}", .{@tagName(value)});
            Vapor.frame_arena.addBytesUsed(n.len);
            break :blk n;
        },
        else => {
            Vapor.report.err("Text only accepts []const u8 or number types, NOT {any}", .{@TypeOf(value)});
            return Self{ ._elem_type = .Text, ._text = "", ._ui_node = ui_node, ._returns_close = false };
        },
    };

    self.* = .{ ._elem_type = .Text, ._text = text, ._ui_node = ui_node, ._returns_close = false };
    return self;
}

/// Raw HTML, inserted as-is. Never pass untrusted input: it is not escaped.
pub fn Html(text: []const u8) Self {
    const ui_node = Components.createNode(.{ .state_type = Self._state_type, .elem_type = .HtmlText, .can_have_children = false });
    return Self{ ._elem_type = .HtmlText, ._text = text, ._ui_node = ui_node, ._returns_close = false };
}

/// Text formatted like `std.fmt`: `TextFmt("{d} items", .{count})`.
pub fn TextFmt(comptime fmt: []const u8, args: anytype) Self {
    const text = Vapor.frame.fmt(fmt, args);
    Vapor.frame_arena.addBytesUsed(text.len);
    const ui_node = Components.createNode(.{ .state_type = Self._state_type, .elem_type = .TextFmt, .can_have_children = false });
    return Self{ ._elem_type = .TextFmt, ._text = text, ._ui_node = ui_node, ._returns_close = false };
}

/// An SVG fetched from `options.src` and inlined, so CSS can style it. For large
/// SVGs, prefer this to `Svg`.
pub fn Graphic(options: struct { src: []const u8 }) Self {
    const ui_node = Components.createNode(.{ .state_type = Self._state_type, .elem_type = .Graphic, .can_have_children = false });
    return Self{ ._elem_type = .Graphic, ._href = options.src, ._ui_node = ui_node, ._returns_close = false };
}

/// An icon from your app's `IconTokens`.
pub fn Icon(token: IconTokens) Self {
    const ui_node = Components.createNode(.{ .state_type = Self._state_type, .elem_type = .Icon, .can_have_children = false });
    return Self{ ._elem_type = .Icon, ._href = token.web orelse "", ._ui_node = ui_node, ._returns_close = false };
}

/// Inline SVG markup. In debug builds, markup over 2 KB is refused (it renders
/// empty) unless `override` is set; use `Graphic` for large files.
pub fn Svg(options: struct { svg: []const u8, override: bool = false }) Self {
    const ui_node = Components.createNode(.{ .elem_type = .Svg, .can_have_children = false });
    if (options.svg.len > 2048 and Vapor.build_options.enable_debug and !options.override) {
        Vapor.report.err("Svg is too large inlining: {d}B, use Graphic;\nSVG Content:\n{s}...", .{ options.svg.len, options.svg[0..100] });
        return Self{ ._elem_type = .Svg, ._svg = "", ._ui_node = ui_node, ._returns_close = false };
    }
    return Self{ ._elem_type = .Svg, ._svg = options.svg, ._ui_node = ui_node, ._returns_close = false };
}

/// `<img>` from `options.src`, with `options.alt` as its alternative text.
pub fn Image(options: struct { src: []const u8, alt: ?[]const u8 = null }) Self {
    const ui_node = Components.createNode(.{ .state_type = Self._state_type, .elem_type = .Image, .can_have_children = false });
    return Self{ ._elem_type = .Image, ._href = options.src, ._alt = options.alt, ._ui_node = ui_node, ._returns_close = false };
}

/// A container other elements can position against with CSS anchor
/// positioning, under the anchor name `name`.
pub fn Anchor(name: []const u8) Self {
    const ui_node = Components.createNode(.{ .state_type = Self._state_type, .elem_type = .Anchor });
    return Self{ ._elem_type = .Anchor, ._ui_node = ui_node, ._anchor = name, ._returns_close = true };
}
