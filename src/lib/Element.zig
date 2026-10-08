const types = @import("types.zig");
const Vapor = @import("Vapor.zig");
const UINode = @import("UITree.zig").UINode;
const ElementType = @import("types.zig").ElementType;
const std = @import("std");
const isWasi = Vapor.isWasi;
const Wasm = Vapor.Wasm;
const Event = @import("Event.zig");
const utils = @import("utils.zig");
const hashKey = utils.hashKey;
const Style = @import("types.zig").Style;
const ScrollBehavior = Vapor.Event.ScrollBehavior;
const ScrollBlock = Vapor.Event.ScrollBlock;
const ScrollIntoViewOptions = Vapor.Event.ScrollIntoViewOptions;

const ScrollOptions = struct {
    top: f32 = 0,
    left: f32 = 0,
    behavior: ScrollBehavior = .auto,
    block: ScrollBlock = .start,
};

const flex_type_map = [_][]const u8{
    "default",
    "flex",
    "inline",
    "block",
    "inline-block",
    "none",
};

const Rect = struct {
    top: f32,
    left: f32,
    right: f32,
    bottom: f32,
    width: f32,
    height: f32,
};

const Offsets = struct {
    offset_top: f32,
    offset_left: f32,
    offset_right: f32,
    offset_bottom: f32,
    offset_width: f32,
    offset_height: f32,
};

const Selection = struct {
    start: u32,
    end: u32,
};

const AttributeType = union(enum) {
    string: []const u8,
    number: f32,
};

pub const Element = struct {

    // Size and position related
    client_height: f32 = 0,
    client_width: f32 = 0,
    client_left: f32 = 0,
    client_top: f32 = 0,
    offset_height: f32 = 0,
    offsetWidth: u32 = 0,
    offset_left: f32 = 0,
    offset_top: f32 = 0,
    scroll_height: f32 = 0,
    scroll_width: f32 = 0,
    scroll_left: u32 = 0,
    scroll_top: f32 = 0,

    // Element properties
    id: ?[]const u8 = null,
    attribute: ?[]const u8 = null,
    draggable: bool = false,
    element_type: ElementType = .Box,
    _node_ptr: ?*UINode = null,

    attributes: ?AttributesValues = null, // all []const u8 fields owned by `allocator`
    extra_inline_style: ?[]const u8 = null, // owned; what the user set via .style
    style_dirty: bool = true,

    text: []const u8 = "",
    on_change: ?*const fn (event: *Event) void = null,
    on_hover: ?*const fn (event: *Event) void = null,
    on_submit: ?*const fn (event: *Event) void = null,
    on_focus: ?*const fn (event: *Event) void = null,
    on_blur: ?*const fn (event: *Event) void = null,

    buf: ?std.array_list.Managed(u8) = null,

    style: struct {
        top: f32 = 0,
        left: f32 = 0,
        right: f32 = 0,
        bottom: f32 = 0,
        background: []const u8 = "white",
    } = .{},

    pub fn _get_id(self: *Element) ?[]const u8 {
        if (self._node_ptr) |node| {
            return node.uuid;
        } else if (self.id) |id| {
            return id;
        } else {
            return null;
        }
    }

    pub fn init(self: *Element, allocator: std.mem.Allocator) void {
        self.buf =
            std.array_list.Managed(u8).init(allocator);
    }

    pub fn scrollTo(self: *Element, options: ScrollOptions) void {
        if (!Vapor.isWasi) return;
        const id = self._get_id() orelse {
            Vapor.printlnSrc("Id is null", .{}, @src());
            return;
        };
        Wasm.scrollToBehaviorWasm(id.ptr, id.len, options.top, options.left, options.behavior, options.block);
    }

    pub fn scrollToBottom(self: *Element, value: u32) void {
        if (!Vapor.isWasi) return;
        const id = self._get_id() orelse {
            Vapor.printlnSrc("Id is null", .{}, @src());
            return;
        };
        const attribute: []const u8 = "scrollBottom";
        mutateDomElement(id.ptr, id.len, attribute.ptr, attribute.len, @floatFromInt(value));
        self.scroll_top = @floatFromInt(value);
    }

    pub fn scrollHeight(self: *Element) f32 {
        if (!Vapor.isWasi) return 0;
        const id = self._get_id() orelse {
            Vapor.printlnSrc("Id is null", .{}, @src());
            return 0;
        };
        const attribute: []const u8 = "scrollHeight";
        return @floatFromInt(Wasm.getAttributeWasmNumber(id.ptr, id.len, attribute.ptr, attribute.len));
    }

    pub fn scrollWidth(self: *Element) u32 {
        if (!Vapor.isWasi) return 0;
        const id = self._get_id() orelse {
            Vapor.printlnSrc("Id is null", .{}, @src());
            return 0;
        };
        const attribute: []const u8 = "scrollWidth";
        return Wasm.getAttributeWasmNumber(id.ptr, id.len, attribute.ptr, attribute.len);
    }

    pub fn scrollToTop(self: *Element, value: f32) void {
        if (!Vapor.isWasi) return;
        const id = self._get_id() orelse {
            Vapor.printlnSrc("Id is null", .{}, @src());
            return;
        };
        const attribute: []const u8 = "scrollTop";
        mutateDomElement(id.ptr, id.len, attribute.ptr, attribute.len, value);
        self.scroll_top = value;
    }

    pub fn setAttribute(self: *Element, key: []const u8, value: []const u8) void {
        const id = self._get_id() orelse {
            Vapor.printlnSrc("Id is null", .{}, @src());
            return;
        };
        if (isWasi) {
            Vapor.Wasm.setAttributeWasm(id.ptr, id.len, key.ptr, key.len, value.ptr, value.len);
        }
        return;
    }

    pub fn scrollTop(self: *Element) f32 {
        if (!Vapor.isWasi) return 0;
        const attribute: []const u8 = "scrollTop";
        self.scroll_top = @floatFromInt(self.getAttributeNumber(attribute));
        return self.scroll_top;
    }

    pub fn scrollIntoView(self: *Element, options: ScrollIntoViewOptions) void {
        if (!Vapor.isWasi) return;
        const id = self._get_id() orelse {
            Vapor.printlnSrc("Id is null", .{}, @src());
            return;
        };
        Wasm.scrollIntoViewWasm(id.ptr, id.len, options.behavior, options.block);
    }

    pub fn toOffsetWidth(self: *Element, value: u32) void {
        if (!Vapor.isWasi) return;
        const id = self._get_id() orelse {
            Vapor.printlnSrc("Id is null", .{}, @src());
            return;
        };
        const attribute: []const u8 = "offsetWidth";
        mutateDomElement(id.ptr, id.len, attribute.ptr, attribute.len, @floatFromInt(value));
        @field(self, attribute) = value;
    }

    pub fn getAttributeNumber(self: *Element, attribute: []const u8) u32 {
        if (!Vapor.isWasi) return 0;
        const id = self._get_id() orelse {
            Vapor.printlnSrc("Id is null", .{}, @src());
            return 0;
        };
        return Wasm.getAttributeWasmNumber(id.ptr, id.len, attribute.ptr, attribute.len);
    }

    pub fn cursorPosition(self: *Element) u32 {
        const id = self._get_id() orelse {
            Vapor.printlnSrc("Id is null", .{}, @src());
            return 0;
        };
        const attribute: []const u8 = "selectionStart";
        return Wasm.getAttributeWasmNumber(id.ptr, id.len, attribute.ptr, attribute.len);
    }

    pub fn setCursorPosition(self: *Element, value: usize) void {
        const id = self._get_id() orelse {
            Vapor.printlnSrc("Id is null", .{}, @src());
            return;
        };
        if (isWasi) {
            Wasm.setCursorPositionWasm(id.ptr, id.len, value);
        }
    }

    pub fn selection(self: *Element) ?Selection {
        // selectionWasm hands back a mutable [*]u32, which a const array
        // literal cannot stand in for, so the off-wasm stub returns directly.
        if (!Vapor.isWasi) return Selection{ .start = 0, .end = 0 };

        const id = self._get_id() orelse {
            Vapor.printlnSrc("Id is null", .{}, @src());
            return null;
        };
        const selections = Wasm.selectionWasm(id.ptr, id.len);
        return Selection{
            .start = selections[0],
            .end = selections[1],
        };
    }

    pub fn replaceRange(self: *Element, start: usize, end: usize, replacement: []const u8) void {
        const id = self._get_id() orelse return;
        Wasm.replaceRangeWasm(id.ptr, id.len, start, end, replacement.ptr, replacement.len);
    }

    pub fn mutate(self: *Element, attribute: []const u8, value: u32) void {
        const id = self._get_id() orelse {
            Vapor.printlnSrc("Id is null", .{}, @src());
            return;
        };
        mutateDomElement(id.ptr, id.len, attribute.ptr, attribute.len, @floatFromInt(value));
    }

    pub fn addInstListener(
        self: *const Element,
        event_type: types.EventType,
        cb: anytype,
        args: anytype,
    ) void {
        if (!Vapor.isWasi) return;
        const ui_node = self._node_ptr orelse {
            Vapor.printlnSrc("Node is null", .{}, @src());
            @panic("vapor: Node is null");
        };
        return Vapor.attachEventCtxCallback(ui_node, event_type, cb, args) catch |err| {
            std.log.err("Event Callback Error: {any}\n", .{err});
            @panic("vapor: Event Callback Error");
        };
    }

    pub fn addListener(self: *Element, event_type: types.EventType, cb: *const fn (event: *Event) void) ?usize {
        const ui_node = self._node_ptr orelse {
            Vapor.printlnSrc("Node is null", .{}, @src());
            return null;
        };
        if (isWasi) {
            return Vapor.elementEventListener(ui_node, event_type, cb);
        } else {
            return 0;
        }
    }

    pub fn removeListener(
        self: *Element,
        event_type: types.EventType,
        cb_idx: usize,
    ) ?bool {
        const id = self._get_id() orelse {
            Vapor.printlnSrc("Id is null", .{}, @src());
            return null;
        };
        return Vapor.destroyElementEventListener(id, event_type, cb_idx);
    }

    pub fn removeInstListener(
        self: *Element,
        event_type: types.EventType,
        cb_idx: usize,
    ) ?bool {
        const id = self._get_id() orelse {
            Vapor.printlnSrc("Id is null", .{}, @src());
            return null;
        };
        return Vapor.destroyElementInstEventListener(id, event_type, cb_idx);
    }

    pub fn mutateStyleString(self: *Element, attribute: []const u8, value: []const u8) void {
        const id = self._get_id() orelse {
            Vapor.printlnSrc("Id is null", .{}, @src());
            return;
        };
        mutateDomElementStyleString(id.ptr, id.len, attribute.ptr, attribute.len, value.ptr, value.len);
    }

    const Unit = enum {
        px,
        percent,
        em,
        rem,
        vw,
        vh,
        deg,
        none,
    };

    const Sizing = struct {
        value: f32,
        unit: Unit,
        pub fn toString(self: *const Sizing) []const u8 {
            return Vapor.frame.fmt("{d}{s}", .{ self.value, @tagName(self.unit) });
        }
    };

    const Attributes = union(enum) {
        id: []const u8,
        class: []const u8,
        style: []const u8,
        src: []const u8,
        alt: []const u8,
        href: []const u8,
        height: Sizing,
        width: Sizing,
        top: Sizing,
        left: Sizing,
        bottom: Sizing,
        right: Sizing,
        flex_type: types.FlexType,
    };

    const AttributesValues = struct {
        id: ?[]const u8 = null,
        class: ?[]const u8 = null,
        style: ?[]const u8 = null,
        src: ?[]const u8 = null,
        alt: ?[]const u8 = null,
        href: ?[]const u8 = null,
        height: ?Sizing = null,
        width: ?Sizing = null,
        top: ?Sizing = null,
        left: ?Sizing = null,
        bottom: ?Sizing = null,
        right: ?Sizing = null,
        flex_type: ?types.FlexType = null,
    };

    pub fn mutateAttribute(self: *Element, attribute: Attributes) void {
        var attributes = self.attributes orelse AttributesValues{};
        switch (attribute) {
            .id => self.setOwnedString(&attributes.id, attribute.id) catch {},
            .class => self.setOwnedString(&attributes.class, attribute.class) catch {},
            .src => self.setOwnedString(&attributes.src, attribute.src) catch {},
            .alt => self.setOwnedString(&attributes.alt, attribute.alt) catch {},
            .href => self.setOwnedString(&attributes.href, attribute.href) catch {},

            .style => {
                // user-provided inline style; merged in flushStyle
                self.setOwnedString(&self.extra_inline_style, attribute.style) catch {};
                self.style_dirty = true;
            },

            .height => {
                attributes.height = attribute.height;
                self.style_dirty = true;
            },
            .width => {
                attributes.width = attribute.width;
                self.style_dirty = true;
            },
            .top => {
                attributes.top = attribute.top;
                self.style_dirty = true;
            },
            .left => {
                attributes.left = attribute.left;
                self.style_dirty = true;
            },
            .bottom => {
                attributes.bottom = attribute.bottom;
                self.style_dirty = true;
            },
            .right => {
                attributes.right = attribute.right;
                self.style_dirty = true;
            },
            .flex_type => {
                attributes.flex_type = attribute.flex_type;
                self.style_dirty = true;
            },
        }
        self.attributes = attributes;
        self.flushStyle() catch {};
    }

    fn setOwnedString(self: *Element, slot: *?[]const u8, new_value: []const u8) !void {
        if (slot.*) |old| Vapor.persist.allocator().free(old);
        slot.* = try Vapor.persist.allocator().dupe(u8, new_value);
        // Push attribute-style props (id/class/src/alt/href) to DOM immediately if you want;
        // they don't participate in the style coalescing.
        // For style sources, just mark dirty:
        if (slot == &self.extra_inline_style) self.style_dirty = true;
    }

    pub fn coalesceAttributesAndInline(self: *Element, inline_style: ?[]const u8) ![]const u8 {
        const attributes = self.attributes orelse return error.AttributesIsNull;
        var aw: std.Io.Writer.Allocating = .init(Vapor.persist.allocator());
        defer aw.deinit();
        const w = &aw.writer;

        // 1) structured fields first
        if (attributes.height) |s| try w.print("height:{s};", .{s.toString()});
        if (attributes.width) |s| try w.print("width:{s};", .{s.toString()});
        if (attributes.top) |s| try w.print("top:{s};", .{s.toString()});
        if (attributes.left) |s| try w.print("left:{s};", .{s.toString()});
        if (attributes.bottom) |s| try w.print("bottom:{s};", .{s.toString()});
        if (attributes.right) |s| try w.print("right:{s};", .{s.toString()});
        if (attributes.flex_type) |ft|
            try w.print("display:{s};", .{flex_type_map[@intFromEnum(ft)]});

        // 2) user inline style appended last so it wins (or first if you want structured to win)
        if (self.extra_inline_style) |s| _ = try w.write(s);
        if (inline_style) |s| _ = try w.write(s);

        self.style_dirty = false;
        return Vapor.frame.dupe(aw.written());
    }

    pub fn flushStyle(self: *Element) !void {
        if (!self.style_dirty) return;

        const attributes = self.attributes orelse {
            std.log.err("Attributes not set", .{});
            return;
        };
        var aw: std.Io.Writer.Allocating = .init(Vapor.persist.allocator());
        defer aw.deinit();
        const w = &aw.writer;

        // 1) structured fields first
        if (attributes.height) |s| try w.print("height:{s};", .{s.toString()});
        if (attributes.width) |s| try w.print("width:{s};", .{s.toString()});
        if (attributes.top) |s| try w.print("top:{s};", .{s.toString()});
        if (attributes.left) |s| try w.print("left:{s};", .{s.toString()});
        if (attributes.bottom) |s| try w.print("bottom:{s};", .{s.toString()});
        if (attributes.right) |s| try w.print("right:{s};", .{s.toString()});
        if (attributes.flex_type) |ft|
            try w.print("display:{s};", .{flex_type_map[@intFromEnum(ft)]});

        // 2) user inline style appended last so it wins (or first if you want structured to win)
        if (self.extra_inline_style) |s| _ = try w.write(s);

        self.mutateDomElementString("style", aw.written());
        self.style_dirty = false;
        try w.flush();
    }

    pub fn mutateDomElementString(self: *Element, attribute: []const u8, value: []const u8) void {
        if (!Vapor.isWasi) return;
        const id = self._get_id() orelse {
            Vapor.printlnSrc("Id is null", .{}, @src());
            return;
        };
        Wasm.mutateDomElementStringWasm(id.ptr, id.len, attribute.ptr, attribute.len, value.ptr, value.len);
    }

    pub fn mutateStyle(self: *Element, style: *const Style) void {
        const id = self._get_id() orelse {
            Vapor.printlnSrc("Id is null", .{}, @src());
            return;
        };

        const fields = @typeInfo(Style).@"struct".fields;
        inline for (fields) |field| {
            const field_value = @field(style, field.name);
            const field_name = field.name;
            const field_type = field.type;
            switch (field_type) {
                []const u8 => {
                    mutateDomElementStyleString(
                        id.ptr,
                        id.len,
                        field_name.ptr,
                        field_name.len,
                        field_value.ptr,
                        field_value.len,
                    );
                },
                // Color => {
                //     mutateDomElementStyle(
                //         id.ptr,
                //         id.len,
                //         field_name.ptr,
                //         field_name.len,
                //         field_value.Literal.r,
                //         field_value.Literal.g,
                //         field_value.Literal.b,
                //         field_value.Literal.a,
                //     );
                // },
                else => {},
            }
        }
    }

    pub fn scrollLeft(self: *Element, value: u32) void {
        const id = self._get_id() orelse {
            Vapor.printlnSrc("Id is null", .{}, @src());
            return;
        };
        const attribute: []const u8 = "scrollLeft";
        mutateDomElement(id.ptr, id.len, attribute.ptr, attribute.len, @floatFromInt(value));
        self.scroll_left = value;
    }

    pub fn getOffsets(self: *Element) ?Offsets {
        const id = self._get_id() orelse {
            Vapor.printlnSrc("Id is null", .{}, @src());
            return null;
        };
        // const bounds_ptr = Vapor.getOffsets(id.ptr, @intCast(id.len));
        const bounds_ptr = if (isWasi) blk: {
            break :blk Wasm.getOffsetsWasm(id.ptr, id.len);
        } else {
            // Dummy implementation - return offsets with fake values
            // Assuming offsets contain [offsetX, offsetY]
            return null;
        };

        return Offsets{
            .offset_top = bounds_ptr[0],
            .offset_left = bounds_ptr[1],
            .offset_right = bounds_ptr[2],
            .offset_bottom = bounds_ptr[3],
            .offset_width = bounds_ptr[4],
            .offset_height = bounds_ptr[5],
        };
    }

    pub fn getBoundingClientRect(self: *Element) ?Vapor.Bounds {
        const id = self._get_id() orelse {
            std.log.err("Could not get Bounding Rectangle, Id is null, Attach the element to a Node first", .{});
            return null;
        };

        return Vapor.getComponentBounds(id);
    }

    pub fn clear(self: *Element) void {
        const id = self._get_id() orelse {
            Vapor.printlnSrc("Id is null", .{}, @src());
            return;
        };
        const text = "";
        setTextFieldValue(id.ptr, @intCast(id.len), text.ptr, @intCast(text.len));
    }

    pub fn setText(self: *Element, text: []const u8) void {
        const id = self._get_id() orelse {
            Vapor.printlnSrc("Id is null", .{}, @src());
            return;
        };

        if (self.buf) |*buf| {
            buf.clearRetainingCapacity();
            buf.appendSlice(text) catch {
                std.log.err("Could not append slice {any}\n", .{text});
                return;
            };
            self.text = buf.toOwnedSlice() catch {
                std.log.err("Could not toOwnedSlice {any}\n", .{text});
                return;
            };
        } else {
            self.text = text;
        }
        setTextFieldValue(id.ptr, @intCast(id.len), text.ptr, @intCast(text.len));
    }

    pub fn getInputValue(self: *Element) ?[]const u8 {
        const id = self._get_id() orelse {
            Vapor.printlnSrc("Id is null", .{}, @src());
            return null;
        };
        if (!isWasi) return null;
        const resp = Wasm.getInputValueWasm(id.ptr, id.len);
        return std.mem.span(resp);
    }

    pub fn focus(self: *Element) void {
        const id = self._get_id() orelse {
            Vapor.printlnSrc("Cannot Focus on Element, Id is null", .{}, @src());
            std.log.err("Potentially the Element is not in the DOM or mounted Yet, the Element need to exist in the UI to be focusable", .{});
            std.log.err("Check your if statement?", .{});
            return;
        };
        if (self.element_type != .TextField and self.element_type != .TextArea) {
            Vapor.println("Can only focus on TextField Element, add element Type Input\n", .{});
            return;
        }
        Vapor.focus(id);
    }

    pub fn focused(self: *Element) bool {
        const id = self._get_id() orelse {
            Vapor.printlnSrc("Id is null", .{}, @src());
            return false;
        };
        return Vapor.focused(id);
    }

    pub fn click(self: *Element) void {
        const id = self._get_id() orelse {
            Vapor.printlnSrc("Id is null", .{}, @src());
            return;
        };
        if (self.element_type != .TextField) {
            Vapor.println("Must be TextField type", .{});
            return;
        }
        if (isWasi) {
            Wasm.callClickWASM(id.ptr, id.len);
        }
    }
    pub fn startVideo(self: *Element) void {
        const id = self._get_id() orelse {
            Vapor.printlnSrcErr("Id is null", .{}, @src());
            @panic("vapor: Id is null");
        };
        if (isWasi) {
            Wasm.startVideoWasm(id.ptr, id.len);
        }
    }

    pub fn playVideo(self: *Element) void {
        const id = self._get_id() orelse {
            Vapor.printlnSrcErr("Id is null", .{}, @src());
            @panic("vapor: Id is null");
        };
        if (isWasi) {
            Wasm.playVideoWasm(id.ptr, id.len);
        }
    }

    pub fn pauseVideo(self: *Element) void {
        if (!isWasi) return;
        const id = self._get_id() orelse {
            Vapor.printlnSrcErr("Id is null", .{}, @src());
            @panic("vapor: Id is null");
        };
        Wasm.pauseVideoWasm(id.ptr, id.len);
    }

    pub fn stopCamera(self: *Element) void {
        const id = self._get_id() orelse {
            Vapor.printlnSrcErr("Id is null", .{}, @src());
            @panic("vapor: Id is null");
        };
        if (isWasi) {
            Wasm.stopCameraWasm(id.ptr, id.len);
        }
    }

    pub fn seekVideo(self: *Element, time: f32) void {
        const id = self._get_id() orelse {
            Vapor.printlnSrcErr("Id is null", .{}, @src());
            @panic("vapor: Id is null");
        };
        if (isWasi) {
            Wasm.seekVideoWasm(id.ptr, id.len, time);
        }
    }

    pub fn setVolume(self: *Element, volume: f32) void {
        const id = self._get_id() orelse {
            Vapor.printlnSrcErr("Id is null", .{}, @src());
            @panic("vapor: Id is null");
        };
        Wasm.setVolumeWasm(id.ptr, id.len, volume);
    }

    pub fn muteVideo(self: *Element) void {
        const id = self._get_id() orelse {
            Vapor.printlnSrcErr("Id is null", .{}, @src());
            @panic("vapor: Id is null");
        };
        Wasm.muteVideoWasm(id.ptr, id.len, true);
    }

    pub fn getVideoDuration(self: *Element) f32 {
        if (!isWasi) return 0;
        const id = self._get_id() orelse {
            Vapor.printlnSrcErr("Id is null", .{}, @src());
            @panic("vapor: Id is null");
        };
        return Wasm.getVideoDurationWasm(id.ptr, id.len);
    }

    pub fn getVideoCurrentTime(self: *Element) f32 {
        if (!isWasi) return 0;
        const id = self._get_id() orelse {
            Vapor.printlnSrcErr("Id is null", .{}, @src());
            @panic("vapor: Id is null");
        };
        return Wasm.getVideoCurrentTimeWasm(id.ptr, id.len);
    }

    pub fn translate3d(element: *Element, translation: Translate3d) ?void {
        if (!isWasi) return;
        const id = element._get_id() orelse {
            Vapor.printlnSrcErr("Id is null", .{}, @src());
            return null;
        };
        Wasm.translate3dWasm(id.ptr, id.len, translation.x, translation.y, translation.z);
    }

    pub fn setPointerCapture(element: *Element, evt: *Event) void {
        if (!isWasi) return;
        const id = element._get_id() orelse {
            Vapor.printlnSrcErr("Id is null", .{}, @src());
            return;
        };
        Wasm.setPointerCaptureWasm(id.ptr, id.len, evt.id);
    }

    pub fn releasePointerCapture(element: *Element, evt: *Event) void {
        if (!isWasi) return;
        const id = element._get_id() orelse {
            Vapor.printlnSrcErr("Id is null", .{}, @src());
            return;
        };
        std.log.info("{s} {any}", .{ id, evt.type });
        Wasm.releasePointerCaptureWasm(id.ptr, id.len, evt.id);
    }
};

pub fn setTextFieldValue(ptr: [*]const u8, len: u32, text_ptr: [*]const u8, text_len: u32) void {
    if (isWasi) {
        return Wasm.setInputValueWasm(ptr, len, text_ptr, text_len);
    } else {
        // Dummy implementation - nothing to do off-wasm
        return;
    }
}

pub fn mutateDomElement(
    id_ptr: [*]const u8,
    id_len: usize,
    attribute: [*]const u8,
    attribute_len: usize,
    value: f32,
) void {
    if (isWasi) {
        Wasm.mutateDomElementWasm(id_ptr, id_len, attribute, attribute_len, value);
    } else {
        // Dummy implementation - log the action if needed
        if (comptime std.debug.runtime_safety) {
            const id = id_ptr[0..id_len];
            const attr = attribute[0..attribute_len];
            Vapor.println("DOM: Would set element '{s}' attribute '{s}' to {d}\n", .{ id, attr, value });
        }
        // No-op in non-WASM environments
    }
}

const Translate3d = struct {
    x: f32 = 0,
    y: f32 = 0,
    z: f32 = 0,
    pub fn toString(self: *const Translate3d) []const u8 {
        return Vapor.fmtln("translate3d({d}px, {d}px, 0)", .{
            self.x,
            self.y,
            // self.z,
        });
    }
};

pub fn mutateDomElementStyle(
    id_ptr: [*]const u8,
    id_len: usize,
    attribute: [*]const u8,
    attribute_len: usize,
    value: f32,
) void {
    if (isWasi) {
        Wasm.mutateDomElementStyleWasm(id_ptr, id_len, attribute, attribute_len, value);
    } else {
        // Dummy implementation - log the action if needed
        if (comptime std.debug.runtime_safety) {
            const id = id_ptr[0..id_len];
            const attr = attribute[0..attribute_len];
            Vapor.println("DOM: Would set element '{s}' style '{s}' to {d:.2}\n", .{ id, attr, value });
        }
        // No-op in non-WASM environments
    }
}

pub fn mutateDomElementStyleString(
    id_ptr: [*]const u8,
    id_len: usize,
    attribute: [*]const u8,
    attribute_len: usize,
    value_ptr: [*]const u8,
    value_len: usize,
) void {
    if (isWasi) {
        Wasm.mutateDomElementStyleStringWasm(id_ptr, id_len, attribute, attribute_len, value_ptr, value_len);
    } else {
        // Dummy implementation - log the action if needed
        if (comptime std.debug.runtime_safety) {
            const id = id_ptr[0..id_len];
            const attr = attribute[0..attribute_len];
            const value = value_ptr[0..value_len];
            Vapor.println("DOM: Would set element '{s}' style '{s}' to '{s}'\n", .{ id, attr, value });
        }
        // No-op in non-WASM environments
    }
}

pub export fn getOnFocusCallback(self: *Element) u32 {
    const uuid = self._get_id() orelse {
        Vapor.printlnSrcErr("Id is null", .{}, @src());
        @panic("vapor: Id is null");
    };
    var onid = hashKey(uuid);
    onid +%= hashKey(Vapor.on_focus_hash);
    return onid;
}

pub export fn getOnHoverCallback(self: *Element) u32 {
    const uuid = self._get_id() orelse {
        Vapor.printlnSrcErr("Id is null", .{}, @src());
        @panic("vapor: Id is null");
    };
    if (self.on_hover == null) return 0;
    var onid = hashKey(uuid);
    onid +%= hashKey(Vapor.on_hover_hash);
    return onid;
}

pub export fn getOnChangeCallback(self: *Element) u32 {
    const uuid = self._get_id() orelse {
        Vapor.printlnSrcErr("Id is null", .{}, @src());
        @panic("vapor: Id is null");
    };
    if (self.on_change == null) return 0;
    var onid = hashKey(uuid);
    onid +%= hashKey(Vapor.on_change_hash);
    return onid;
}

pub export fn getOnBlurCallback(self: *Element) u32 {
    const uuid = self._get_id() orelse {
        Vapor.printlnSrcErr("Id is null", .{}, @src());
        @panic("vapor: Id is null");
    };
    var onid = hashKey(uuid);
    onid +%= hashKey(Vapor.on_blur_hash);
    return onid;
}
