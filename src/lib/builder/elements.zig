const Components = @import("../Components.zig");
const Self = Components.ComponentBuilder;
const types = @import("../types.zig");
const Vapor = @import("../Vapor.zig");
const LifeCycle = @import("../Vapor.zig").LifeCycle;
const println = Vapor.println;
const ElementDecl = types.ElementDeclaration;
const IconTokens = @import("config").IconTokens;
const utils = @import("../utils.zig");
const hashKey = utils.hashKey;

pub fn Null() void {
    _ = LifeCycle.open(.{ .elem_type = .Noop, .state_type = Self._state_type });
    LifeCycle.configure(.{ .elem_type = .Noop, .state_type = Self._state_type });
    LifeCycle.close({});
}

pub fn Null2(elem_type: Vapor.Types.ElementType) void {
    _ = LifeCycle.open(.{ .elem_type = elem_type, .state_type = Self._state_type });
    LifeCycle.configure(.{ .elem_type = .Noop, .state_type = Self._state_type });
    LifeCycle.close({});
}

pub fn Heading(level: u8, text: []const u8) Self {
    const ui_node = Components.createNode(.{ .state_type = Self._state_type, .elem_type = .Heading, .text = text, .level = level });
    return Self{ ._elem_type = .Heading, ._text = text, ._level = level, ._ui_node = ui_node, ._returns_close = false };
}

pub fn Video(options: *const types.Video) Self {
    const ui_node = Vapor.current_ctx.open(.{ .state_type = Self._state_type, .elem_type = .Video, .can_have_children = false }) catch |err| {
        println("{any}\n", .{err});
        @panic("vapor: could not allocate a Video node");
    };
    return Self{ ._elem_type = .Video, ._video = options, ._ui_node = ui_node, ._returns_close = false };
}

pub fn Box() Self {
    const ui_node = Components.createNode(.{ .state_type = Self._state_type, .elem_type = .FlexBox });
    return Self{ ._ui_node = ui_node, ._elem_type = .FlexBox, ._returns_close = true };
}

pub fn Row() Self {
    const ui_node = Components.createNode(.{ .state_type = Self._state_type, .elem_type = .FlexBox });
    return Self{ ._ui_node = ui_node, ._elem_type = .FlexBox, ._returns_close = true };
}

pub fn Layer(layer_type: types.Layers) Self {
    const ui_node = Components.createNode(.{ .state_type = Self._state_type, .elem_type = .FlexBox });
    ui_node.layer = layer_type;
    return Self{ ._ui_node = ui_node, ._elem_type = .FlexBox, ._returns_close = true };
}

pub fn Table() Self {
    return Self{ ._ui_node = Components.createNode(.{ .state_type = Self._state_type, .elem_type = .Table }), ._elem_type = .Table, ._returns_close = true };
}

pub fn TableRow() Self {
    return Self{ ._ui_node = Components.createNode(.{ .state_type = Self._state_type, .elem_type = .TableRow }), ._elem_type = .TableRow, ._returns_close = true };
}

pub fn TableCell() Self {
    return Self{ ._ui_node = Components.createNode(.{ .state_type = Self._state_type, .elem_type = .TableCell }), ._elem_type = .TableCell, ._returns_close = true };
}

pub fn TableBody() Self {
    return Self{ ._ui_node = Components.createNode(.{ .state_type = Self._state_type, .elem_type = .TableBody }), ._elem_type = .TableBody, ._returns_close = true };
}

pub fn TableHeader() Self {
    return Self{ ._ui_node = Components.createNode(.{ .state_type = Self._state_type, .elem_type = .TableHeader }), ._elem_type = .TableHeader, ._returns_close = true };
}

pub fn TableHead() Self {
    return Self{ ._ui_node = Components.createNode(.{ .state_type = Self._state_type, .elem_type = .TableHead }), ._elem_type = .TableHead, ._returns_close = true };
}

pub fn Form(submit: anytype, args: anytype) Self {
    const ui_node = Components.createNode(.{ .state_type = Self._state_type, .elem_type = .Form });
    Vapor.attachEventCtxCallback(ui_node, .submit, submit, args) catch |err| {
        Vapor.println("ONSUBMIT: Could not attach event callback {any}\n", .{err});
        @panic("vapor: ONSUBMIT: Could not attach event callback");
    };
    return Self{ ._ui_node = ui_node, ._elem_type = .Form, ._returns_close = true };
}

pub fn Section() Self {
    const ui_node = LifeCycle.open(.{ .state_type = Self._state_type, .elem_type = .Intersection }) orelse {
        Vapor.printlnSrcErr("Could not add component to lifecycle {any}\n", .{error.CouldNotAllocate}, @src());
        @panic("vapor: Could not add component to lifecycle");
    };
    return Self{ ._ui_node = ui_node, ._elem_type = .Intersection, ._returns_close = true };
}

pub fn List() Self {
    const ui_node = LifeCycle.open(.{ .state_type = Self._state_type, .elem_type = .List }) orelse {
        Vapor.printlnSrcErr("Could not add component to lifecycle {any}\n", .{error.CouldNotAllocate}, @src());
        @panic("vapor: Could not add component to lifecycle");
    };
    return Self{ ._ui_node = ui_node, ._elem_type = .List, ._returns_close = true };
}

pub fn ListItem() Self {
    const ui_node = LifeCycle.open(.{ .state_type = Self._state_type, .elem_type = .ListItem }) orelse {
        Vapor.printlnSrcErr("Could not add component to lifecycle {any}\n", .{error.CouldNotAllocate}, @src());
        @panic("vapor: Could not add component to lifecycle");
    };
    return Self{ ._ui_node = ui_node, ._elem_type = .ListItem, ._returns_close = true };
}

pub fn Center() *Self {
    const ui_node = LifeCycle.open(.{ .state_type = Self._state_type, .elem_type = .FlexBox }) orelse {
        Vapor.printlnSrcErr("Could not add component to lifecycle {any}\n", .{error.CouldNotAllocate}, @src());
        @panic("vapor: Could not add component to lifecycle");
    };
    const self = Vapor.arena(.frame).create(Self) catch |err| {
        Vapor.printlnErr("component builder: allocation failed: {any}", .{err});
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

pub fn FormButton() Self {
    const elem_decl = ElementDecl{
        .state_type = Self._state_type,
        .elem_type = .SubmitButton,
    };

    const ui_node = LifeCycle.open(elem_decl) orelse {
        Vapor.printlnSrcErr("LifeCycle open could not allocate {any}\n", .{error.CouldNotAllocate}, @src());
        @panic("vapor: LifeCycle open could not allocate");
    };

    return Self{ ._elem_type = .SubmitButton, ._ui_node = ui_node, ._returns_close = true };
}

pub fn Button(cb: anytype, args: anytype) Self {
    const elem_decl = ElementDecl{
        .state_type = Self._state_type,
        .elem_type = .CtxButton,
    };

    const ui_node = LifeCycle.open(elem_decl) orelse {
        Vapor.printlnSrcErr("LifeCycle open could not allocate {any}\n", .{error.CouldNotAllocate}, @src());
        @panic("vapor: LifeCycle open could not allocate");
    };

    const erased = Vapor.ErasedCallback.make(Vapor.arena(.frame), cb, args) catch |err| {
        println("Error could not create closure {any}\n", .{err});
        @panic("vapor: Error could not create closure");
    };

    const callback_id = hashKey(ui_node.uuid);
    // Store just the ErasedCallback instead of *Node
    Vapor.erased_registry.put(callback_id, erased) catch |err| {
        println("Registry error {any}\n", .{err});
        @panic("vapor: Registry error");
    };

    return Self{ ._elem_type = .CtxButton, ._ui_node = ui_node, ._returns_close = true };
}

pub fn Stack() Self {
    const ui_node = LifeCycle.open(.{ .state_type = Self._state_type, .elem_type = .FlexBox }) orelse {
        Vapor.printlnSrcErr("Could not add component to lifecycle {any}\n", .{error.CouldNotAllocate}, @src());
        @panic("vapor: Could not add component to lifecycle");
    };
    ui_node.direction = .column;
    return Self{ ._ui_node = ui_node, ._elem_type = .FlexBox, ._flex_type = .stack, ._direction = .column, ._returns_close = true };
}

pub fn Link(options: Components.LinkOptions) Self {
    const ui_node = LifeCycle.open(.{ .state_type = Self._state_type, .elem_type = .Link, .href = options.url, .aria_label = options.aria_label }) orelse {
        Vapor.printlnSrcErr("Could not add component Link to lifecycle {any}\n", .{error.CouldNotAllocate}, @src());
        @panic("vapor: Could not add component Link to lifecycle");
    };

    return Self{ ._ui_node = ui_node, ._elem_type = .Link, ._aria_label = options.aria_label, ._href = options.url, ._returns_close = true };
}

pub fn RedirectLink(options: Components.LinkOptions) Self {
    const ui_node = LifeCycle.open(.{ .state_type = Self._state_type, .elem_type = .RedirectLink, .href = options.url, .aria_label = options.aria_label }) orelse {
        Vapor.printlnSrcErr("Could not add component Link to lifecycle {any}\n", .{error.CouldNotAllocate}, @src());
        @panic("vapor: Could not add component Link to lifecycle");
    };
    return Self{ ._ui_node = ui_node, ._elem_type = .RedirectLink, ._aria_label = options.aria_label, ._href = options.url, ._returns_close = true };
}

pub fn Label(text: []const u8) Self {
    const ui_node = LifeCycle.open(.{ .state_type = .static, .elem_type = .Label, .text = text, .can_have_children = false }) orelse {
        Vapor.printlnSrcErr("Could not add component to lifecycle {any}\n", .{error.CouldNotAllocate}, @src());
        @panic("vapor: Could not add component to lifecycle");
    };
    return Self{ ._elem_type = .Label, ._text = text, ._ui_node = ui_node, ._returns_close = false };
}

pub fn Code(value: anytype) Self {
    const text = blk: switch (@typeInfo(@TypeOf(value))) {
        .pointer => break :blk value,
        .int => break :blk Vapor.fmtln("{any}", .{value}),
        else => {
            Vapor.printlnErr("Text only accepts []const u8 or number types, NOT {any}", .{@TypeOf(value)});
            return Self{ ._elem_type = .Code, ._text = "", ._returns_close = false };
        },
    };
    const ui_node = LifeCycle.open(.{ .state_type = Self._state_type, .elem_type = .Code, .can_have_children = false }) orelse {
        Vapor.printlnSrcErr("Could not add component to lifecycle {any}\n", .{error.CouldNotAllocate}, @src());
        @panic("vapor: Could not add component to lifecycle");
    };
    return Self{ ._elem_type = .Code, ._text = text, ._ui_node = ui_node, ._returns_close = false };
}

pub fn Spacer(val: f32) Self {
    const ui_node = LifeCycle.open(.{ .state_type = Self._state_type, .elem_type = .Spacer, .can_have_children = false }) orelse {
        Vapor.printlnSrcErr("Could not add component to lifecycle {any}\n", .{error.CouldNotAllocate}, @src());
        @panic("vapor: Could not add component to lifecycle");
    };
    return Self{ ._elem_type = .Spacer, ._ui_node = ui_node, ._size = .hw(.px(val), .expand), ._returns_close = false };
}

pub fn Divider(w: f32) Self {
    const ui_node = LifeCycle.open(.{ .state_type = Self._state_type, .elem_type = .FlexBox, .can_have_children = false }) orelse {
        Vapor.printlnSrcErr("Could not add component to lifecycle {any}\n", .{error.CouldNotAllocate}, @src());
        @panic("vapor: Could not add component to lifecycle");
    };
    return Self{ ._elem_type = .FlexBox, ._ui_node = ui_node, ._size = .hw(.expand, .px(w)), ._returns_close = false };
}

pub fn Iframe(iframe_src: ?[]const u8) Self {
    const ui_node = LifeCycle.open(.{ .state_type = Self._state_type, .elem_type = .Iframe, .can_have_children = false }) orelse {
        Vapor.printlnSrcErr("Could not add component to lifecycle {any}\n", .{error.CouldNotAllocate}, @src());
        @panic("vapor: Could not add component to lifecycle");
    };
    return Self{ ._elem_type = .Iframe, ._ui_node = ui_node, ._returns_close = false, ._href = iframe_src };
}

pub fn FieldSet() Self {
    const ui_node = LifeCycle.open(.{ .state_type = Self._state_type, .elem_type = .FieldSet }) orelse {
        Vapor.printlnSrcErr("Could not add component to lifecycle {any}\n", .{error.CouldNotAllocate}, @src());
        @panic("vapor: Could not add component to lifecycle");
    };
    return Self{ ._elem_type = .FieldSet, ._ui_node = ui_node, ._returns_close = true };
}

pub fn Number(value: anytype) Self {
    const ui_node = LifeCycle.open(.{ .state_type = Self._state_type, .elem_type = .Text, .can_have_children = false }) orelse {
        Vapor.printlnSrcErr("Could not add component to lifecycle {any}\n", .{error.CouldNotAllocate}, @src());
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
            Vapor.printlnErr("Text only accepts []const u8 or number types, NOT {any}", .{@TypeOf(value)});
            return Self{ ._elem_type = .Text, ._text = "", ._ui_node = ui_node, ._returns_close = false };
        },
    };
    return Self{ ._elem_type = .Text, ._text = text, ._ui_node = ui_node, ._returns_close = false };
}

pub fn Text(value: anytype) *Self {
    const ui_node = Components.createNode(.{ .state_type = Self._state_type, .elem_type = .Text, .can_have_children = false });
    const self = Vapor.arena(.frame).create(Self) catch |err| {
        Vapor.printlnErr("component builder: allocation failed: {any}", .{err});
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
            Vapor.printlnErr("Text only accepts []const u8 or number types, NOT {any}", .{@TypeOf(value)});
            return Self{ ._elem_type = .Text, ._text = "", ._ui_node = ui_node, ._returns_close = false };
        },
    };

    self.* = .{ ._elem_type = .Text, ._text = text, ._ui_node = ui_node, ._returns_close = false };
    return self;
}

pub fn Html(text: []const u8) Self {
    const ui_node = Components.createNode(.{ .state_type = Self._state_type, .elem_type = .HtmlText, .can_have_children = false });
    return Self{ ._elem_type = .HtmlText, ._text = text, ._ui_node = ui_node, ._returns_close = false };
}

pub fn TextFmt(comptime fmt: []const u8, args: anytype) Self {
    const text = Vapor.frame.fmt(fmt, args);
    Vapor.frame_arena.addBytesUsed(text.len);
    const ui_node = Components.createNode(.{ .state_type = Self._state_type, .elem_type = .TextFmt, .can_have_children = false });
    return Self{ ._elem_type = .TextFmt, ._text = text, ._ui_node = ui_node, ._returns_close = false };
}

pub fn Graphic(options: struct { src: []const u8 }) Self {
    const ui_node = Components.createNode(.{ .state_type = Self._state_type, .elem_type = .Graphic, .can_have_children = false });
    return Self{ ._elem_type = .Graphic, ._href = options.src, ._ui_node = ui_node, ._returns_close = false };
}

pub fn Icon(token: IconTokens) Self {
    const ui_node = Components.createNode(.{ .state_type = Self._state_type, .elem_type = .Icon, .can_have_children = false });
    return Self{ ._elem_type = .Icon, ._href = token.web orelse "", ._ui_node = ui_node, ._returns_close = false };
}

pub fn Svg(options: struct { svg: []const u8, override: bool = false }) Self {
    const ui_node = Components.createNode(.{ .elem_type = .Svg, .can_have_children = false });
    if (options.svg.len > 2048 and Vapor.build_options.enable_debug and !options.override) {
        Vapor.printlnErr("Svg is too large inlining: {d}B, use Graphic;\nSVG Content:\n{s}...", .{ options.svg.len, options.svg[0..100] });
        return Self{ ._elem_type = .Svg, ._svg = "", ._returns_close = false };
    }
    return Self{ ._elem_type = .Svg, ._svg = options.svg, ._ui_node = ui_node, ._returns_close = false };
}

pub fn Image(options: struct { src: []const u8, alt: ?[]const u8 = null }) Self {
    const ui_node = Components.createNode(.{ .state_type = Self._state_type, .elem_type = .Image, .can_have_children = false });
    return Self{ ._elem_type = .Image, ._href = options.src, ._alt = options.alt, ._ui_node = ui_node, ._returns_close = false };
}

pub fn Anchor(name: []const u8) Self {
    const ui_node = Components.createNode(.{ .state_type = Self._state_type, .elem_type = .Anchor });
    return Self{ ._elem_type = .Anchor, ._ui_node = ui_node, ._anchor = name, ._returns_close = true };
}
