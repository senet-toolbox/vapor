//! `Element` (exported as `Vapor.Element`): a handle to a rendered DOM element,
//! filled in by `.ref`, for reading and changing it outside a render.

const types = @import("types.zig");
const Vapor = @import("vapor.zig");
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

    /// Internal: the element's DOM id, once `.ref` has bound it.
    pub fn _get_id(self: *Element) ?[]const u8 {
        if (self._node_ptr) |node| {
            return node.uuid;
        } else if (self.id) |id| {
            return id;
        } else {
            return null;
        }
    }

    /// Gives `setText` its own buffer, so the text it keeps does not depend on the
    /// caller's memory.
    pub fn init(self: *Element, allocator: std.mem.Allocator) void {
        self.buf =
            std.array_list.Managed(u8).init(allocator);
    }

    /// Scrolls the element's content to `options.top`/`options.left`.
    pub fn scrollTo(self: *Element, options: ScrollOptions) void {
        if (!Vapor.isWasi) return;
        const id = self._get_id() orelse {
            Vapor.report.warn("Element: not bound to an element on the page; bind it with .ref() first", .{});
            return;
        };
        Wasm.scrollToBehaviorWasm(id.ptr, id.len, options.top, options.left, options.behavior, options.block);
    }

    /// Sets the element's `scrollBottom` property to `value`.
    pub fn scrollToBottom(self: *Element, value: u32) void {
        if (!Vapor.isWasi) return;
        const id = self._get_id() orelse {
            Vapor.report.warn("Element: not bound to an element on the page; bind it with .ref() first", .{});
            return;
        };
        const attribute: []const u8 = "scrollBottom";
        mutateDomElement(id.ptr, id.len, attribute.ptr, attribute.len, @floatFromInt(value));
        self.scroll_top = @floatFromInt(value);
    }

    /// Total height of the element's content, in pixels.
    pub fn scrollHeight(self: *Element) f32 {
        if (!Vapor.isWasi) return 0;
        const id = self._get_id() orelse {
            Vapor.report.warn("Element: not bound to an element on the page; bind it with .ref() first", .{});
            return 0;
        };
        const attribute: []const u8 = "scrollHeight";
        return @floatFromInt(Wasm.getAttributeWasmNumber(id.ptr, id.len, attribute.ptr, attribute.len));
    }

    /// Total width of the element's content, in pixels.
    pub fn scrollWidth(self: *Element) u32 {
        if (!Vapor.isWasi) return 0;
        const id = self._get_id() orelse {
            Vapor.report.warn("Element: not bound to an element on the page; bind it with .ref() first", .{});
            return 0;
        };
        const attribute: []const u8 = "scrollWidth";
        return Wasm.getAttributeWasmNumber(id.ptr, id.len, attribute.ptr, attribute.len);
    }

    /// Scrolls the element's content to `value` pixels from the top.
    pub fn scrollToTop(self: *Element, value: f32) void {
        if (!Vapor.isWasi) return;
        const id = self._get_id() orelse {
            Vapor.report.warn("Element: not bound to an element on the page; bind it with .ref() first", .{});
            return;
        };
        const attribute: []const u8 = "scrollTop";
        mutateDomElement(id.ptr, id.len, attribute.ptr, attribute.len, value);
        self.scroll_top = value;
    }

    /// Sets a DOM attribute on the element.
    pub fn setAttribute(self: *Element, key: []const u8, value: []const u8) void {
        const id = self._get_id() orelse {
            Vapor.report.warn("Element: not bound to an element on the page; bind it with .ref() first", .{});
            return;
        };
        if (isWasi) {
            Vapor.Wasm.setAttributeWasm(id.ptr, id.len, key.ptr, key.len, value.ptr, value.len);
        }
        return;
    }

    /// How far the content is scrolled from the top, in pixels.
    pub fn scrollTop(self: *Element) f32 {
        if (!Vapor.isWasi) return 0;
        const attribute: []const u8 = "scrollTop";
        self.scroll_top = @floatFromInt(self.getAttributeNumber(attribute));
        return self.scroll_top;
    }

    /// Scrolls the page so the element is visible.
    pub fn scrollIntoView(self: *Element, options: ScrollIntoViewOptions) void {
        if (!Vapor.isWasi) return;
        const id = self._get_id() orelse {
            Vapor.report.warn("Element: not bound to an element on the page; bind it with .ref() first", .{});
            return;
        };
        Wasm.scrollIntoViewWasm(id.ptr, id.len, options.behavior, options.block);
    }

    /// Sets the element's `offsetWidth` property.
    pub fn toOffsetWidth(self: *Element, value: u32) void {
        if (!Vapor.isWasi) return;
        const id = self._get_id() orelse {
            Vapor.report.warn("Element: not bound to an element on the page; bind it with .ref() first", .{});
            return;
        };
        const attribute: []const u8 = "offsetWidth";
        mutateDomElement(id.ptr, id.len, attribute.ptr, attribute.len, @floatFromInt(value));
        @field(self, attribute) = value;
    }

    /// Reads a numeric DOM property, e.g. "clientHeight".
    pub fn getAttributeNumber(self: *Element, attribute: []const u8) u32 {
        if (!Vapor.isWasi) return 0;
        const id = self._get_id() orelse {
            Vapor.report.warn("Element: not bound to an element on the page; bind it with .ref() first", .{});
            return 0;
        };
        return Wasm.getAttributeWasmNumber(id.ptr, id.len, attribute.ptr, attribute.len);
    }

    /// The text cursor's position in a text field.
    pub fn cursorPosition(self: *Element) u32 {
        const id = self._get_id() orelse {
            Vapor.report.warn("Element: not bound to an element on the page; bind it with .ref() first", .{});
            return 0;
        };
        const attribute: []const u8 = "selectionStart";
        return Wasm.getAttributeWasmNumber(id.ptr, id.len, attribute.ptr, attribute.len);
    }

    /// Moves the text cursor in a text field.
    pub fn setCursorPosition(self: *Element, value: usize) void {
        const id = self._get_id() orelse {
            Vapor.report.warn("Element: not bound to an element on the page; bind it with .ref() first", .{});
            return;
        };
        if (isWasi) {
            Wasm.setCursorPositionWasm(id.ptr, id.len, value);
        }
    }

    /// The selected range in a text field.
    pub fn selection(self: *Element) ?Selection {
        // selectionWasm hands back a mutable [*]u32, which a const array
        // literal cannot stand in for, so the off-wasm stub returns directly.
        if (!Vapor.isWasi) return Selection{ .start = 0, .end = 0 };

        const id = self._get_id() orelse {
            Vapor.report.warn("Element: not bound to an element on the page; bind it with .ref() first", .{});
            return null;
        };
        const selections = Wasm.selectionWasm(id.ptr, id.len);
        return Selection{
            .start = selections[0],
            .end = selections[1],
        };
    }

    /// Replaces characters `start` to `end` of a text field's value.
    pub fn replaceRange(self: *Element, start: usize, end: usize, replacement: []const u8) void {
        const id = self._get_id() orelse return;
        Wasm.replaceRangeWasm(id.ptr, id.len, start, end, replacement.ptr, replacement.len);
    }

    /// Sets a numeric DOM property.
    pub fn mutate(self: *Element, attribute: []const u8, value: u32) void {
        const id = self._get_id() orelse {
            Vapor.report.warn("Element: not bound to an element on the page; bind it with .ref() first", .{});
            return;
        };
        mutateDomElement(id.ptr, id.len, attribute.ptr, attribute.len, @floatFromInt(value));
    }

    /// Calls `cb` with `args` and then the event whenever `event_type` fires
    /// on the element, until `.remove()` on the returned listener or until
    /// the element leaves the page.
    ///
    /// Unlike the builder's `.onEvent`, the listener is not part of the
    /// render: it stays across rerenders, and its events do not rerender the
    /// page, which suits frequent events such as `scroll` or `pointermove`.
    /// Call `Vapor.cycle()` from the handler when it changes what the page
    /// shows.
    ///
    /// The element must already be on the page: bind it with `.ref()` and
    /// call `listen` from `onMount` or an event handler. Returns null when it
    /// is not, and outside the browser.
    pub fn listen(self: *Element, event_type: types.EventType, cb: anytype, args: anytype) ?Vapor.Listener {
        const id = self._get_id() orelse {
            Vapor.report.warn("Element.listen: not bound to an element on the page; bind it with .ref() first", .{});
            return null;
        };
        return Vapor.addElementListener(id, event_type, cb, args);
    }

    /// Calls `cb` with `args` and the event whenever `event_type` fires on the
    /// element.
    pub fn addInstListener(
        self: *const Element,
        event_type: types.EventType,
        cb: anytype,
        args: anytype,
    ) void {
        if (!Vapor.isWasi) return;
        const ui_node = self._node_ptr orelse {
            Vapor.report.warn("Element: not bound to an element on the page; bind it with .ref() first", .{});
            @panic("vapor: Node is null");
        };
        return Vapor.attachEventCtxCallback(ui_node, event_type, cb, args) catch |err| {
            Vapor.report.err("Event Callback Error: {any}", .{err});
            @panic("vapor: Event Callback Error");
        };
    }

    /// Sets one CSS property in the element's inline style.
    pub fn mutateStyleString(self: *Element, attribute: []const u8, value: []const u8) void {
        const id = self._get_id() orelse {
            Vapor.report.warn("Element: not bound to an element on the page; bind it with .ref() first", .{});
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
        /// The size as CSS, e.g. "50%", in frame memory.
        pub fn toString(self: *const Sizing) []const u8 {
            const suffix = switch (self.unit) {
                .percent => "%",
                .none => "",
                else => @tagName(self.unit),
            };
            return Vapor.frame.fmt("{d}{s}", .{ self.value, suffix });
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

    /// Sets one attribute. Only the style-related ones (size, position, display,
    /// `style`) are applied to the page; `id`, `class`, `src`, `alt` and `href` are
    /// recorded but not applied yet.
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
        if (slot.*) |old| Vapor.persist.arena().free(old);
        slot.* = try Vapor.persist.arena().dupe(u8, new_value);
        // Push attribute-style props (id/class/src/alt/href) to DOM immediately if you want;
        // they don't participate in the style coalescing.
        // For style sources, just mark dirty:
        if (slot == &self.extra_inline_style) self.style_dirty = true;
    }

    /// Internal: merges `mutateAttribute` styles with the builder's inline style.
    pub fn coalesceAttributesAndInline(self: *Element, inline_style: ?[]const u8) ![]const u8 {
        const attributes = self.attributes orelse return error.AttributesIsNull;
        var aw: std.Io.Writer.Allocating = .init(Vapor.persist.arena());
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

    /// Writes the styles set with `mutateAttribute` to the element.
    pub fn flushStyle(self: *Element) !void {
        if (!self.style_dirty) return;

        const attributes = self.attributes orelse {
            Vapor.report.err("Attributes not set", .{});
            return;
        };
        var aw: std.Io.Writer.Allocating = .init(Vapor.persist.arena());
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

    /// Sets a string DOM property.
    pub fn mutateDomElementString(self: *Element, attribute: []const u8, value: []const u8) void {
        if (!Vapor.isWasi) return;
        const id = self._get_id() orelse {
            Vapor.report.warn("Element: not bound to an element on the page; bind it with .ref() first", .{});
            return;
        };
        Wasm.mutateDomElementStringWasm(id.ptr, id.len, attribute.ptr, attribute.len, value.ptr, value.len);
    }

    /// Applies a `Style`'s fields directly to the element's inline style.
    pub fn mutateStyle(self: *Element, style: *const Style) void {
        const id = self._get_id() orelse {
            Vapor.report.warn("Element: not bound to an element on the page; bind it with .ref() first", .{});
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
                else => {},
            }
        }
    }

    /// Scrolls the content to `value` pixels from the left.
    pub fn scrollLeft(self: *Element, value: u32) void {
        const id = self._get_id() orelse {
            Vapor.report.warn("Element: not bound to an element on the page; bind it with .ref() first", .{});
            return;
        };
        const attribute: []const u8 = "scrollLeft";
        mutateDomElement(id.ptr, id.len, attribute.ptr, attribute.len, @floatFromInt(value));
        self.scroll_left = value;
    }

    /// The element's offset box relative to its offset parent.
    pub fn getOffsets(self: *Element) ?Offsets {
        const id = self._get_id() orelse {
            Vapor.report.warn("Element: not bound to an element on the page; bind it with .ref() first", .{});
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

    /// The element's box relative to the viewport.
    pub fn getBoundingClientRect(self: *Element) ?Vapor.Bounds {
        const id = self._get_id() orelse {
            Vapor.report.err("Could not get Bounding Rectangle, Id is null, Attach the element to a Node first", .{});
            return null;
        };

        return Vapor.getComponentBounds(id);
    }

    /// Empties a text field.
    pub fn clear(self: *Element) void {
        const id = self._get_id() orelse {
            Vapor.report.warn("Element: not bound to an element on the page; bind it with .ref() first", .{});
            return;
        };
        const text = "";
        setTextFieldValue(id.ptr, @intCast(id.len), text.ptr, @intCast(text.len));
    }

    /// Sets a text field's value.
    pub fn setText(self: *Element, text: []const u8) void {
        const id = self._get_id() orelse {
            Vapor.report.warn("Element: not bound to an element on the page; bind it with .ref() first", .{});
            return;
        };

        if (self.buf) |*buf| {
            buf.clearRetainingCapacity();
            buf.appendSlice(text) catch {
                Vapor.report.err("Could not append slice {any}", .{text});
                return;
            };
            self.text = buf.toOwnedSlice() catch {
                Vapor.report.err("Could not toOwnedSlice {any}", .{text});
                return;
            };
        } else {
            self.text = text;
        }
        setTextFieldValue(id.ptr, @intCast(id.len), text.ptr, @intCast(text.len));
    }

    /// A text field's current value.
    pub fn getInputValue(self: *Element) ?[]const u8 {
        const id = self._get_id() orelse {
            Vapor.report.warn("Element: not bound to an element on the page; bind it with .ref() first", .{});
            return null;
        };
        if (!isWasi) return null;
        const resp = Wasm.getInputValueWasm(id.ptr, id.len);
        return std.mem.span(resp);
    }

    /// Focuses the element: a field, a button, a link, or anything with a
    /// tab index.
    pub fn focus(self: *Element) void {
        const id = self._get_id() orelse {
            Vapor.report.warn("Element: not bound to an element on the page; bind it with .ref() first", .{});
            Vapor.report.err("Potentially the Element is not in the DOM or mounted Yet, the Element need to exist in the UI to be focusable", .{});
            Vapor.report.err("Check your if statement?", .{});
            return;
        };
        Vapor.focus(id);
    }

    /// Whether the element has focus.
    pub fn focused(self: *Element) bool {
        const id = self._get_id() orelse {
            Vapor.report.warn("Element: not bound to an element on the page; bind it with .ref() first", .{});
            return false;
        };
        return Vapor.focused(id);
    }

    /// Clicks the element, as if the user had.
    pub fn click(self: *Element) void {
        const id = self._get_id() orelse {
            Vapor.report.warn("Element: not bound to an element on the page; bind it with .ref() first", .{});
            return;
        };
        if (self.element_type != .TextField) {
            Vapor.report.err("Must be TextField type", .{});
            return;
        }
        if (isWasi) {
            Wasm.callClickWASM(id.ptr, id.len);
        }
    }
    /// Starts the camera stream into this video element.
    pub fn startVideo(self: *Element) void {
        const id = self._get_id() orelse {
            Vapor.report.err("Id is null", .{});
            @panic("vapor: Id is null");
        };
        if (isWasi) {
            Wasm.startVideoWasm(id.ptr, id.len);
        }
    }

    /// Plays the video.
    pub fn playVideo(self: *Element) void {
        const id = self._get_id() orelse {
            Vapor.report.err("Id is null", .{});
            @panic("vapor: Id is null");
        };
        if (isWasi) {
            Wasm.playVideoWasm(id.ptr, id.len);
        }
    }

    /// Pauses the video.
    pub fn pauseVideo(self: *Element) void {
        if (!isWasi) return;
        const id = self._get_id() orelse {
            Vapor.report.err("Id is null", .{});
            @panic("vapor: Id is null");
        };
        Wasm.pauseVideoWasm(id.ptr, id.len);
    }

    /// Stops the camera stream.
    pub fn stopCamera(self: *Element) void {
        const id = self._get_id() orelse {
            Vapor.report.err("Id is null", .{});
            @panic("vapor: Id is null");
        };
        if (isWasi) {
            Wasm.stopCameraWasm(id.ptr, id.len);
        }
    }

    /// Jumps to `time` seconds.
    pub fn seekVideo(self: *Element, time: f32) void {
        const id = self._get_id() orelse {
            Vapor.report.err("Id is null", .{});
            @panic("vapor: Id is null");
        };
        if (isWasi) {
            Wasm.seekVideoWasm(id.ptr, id.len, time);
        }
    }

    /// Volume from 0 to 1.
    pub fn setVolume(self: *Element, volume: f32) void {
        const id = self._get_id() orelse {
            Vapor.report.err("Id is null", .{});
            @panic("vapor: Id is null");
        };
        Wasm.setVolumeWasm(id.ptr, id.len, volume);
    }

    /// Mutes the video.
    pub fn muteVideo(self: *Element) void {
        const id = self._get_id() orelse {
            Vapor.report.err("Id is null", .{});
            @panic("vapor: Id is null");
        };
        Wasm.muteVideoWasm(id.ptr, id.len, true);
    }

    /// The video's length in seconds.
    pub fn getVideoDuration(self: *Element) f32 {
        if (!isWasi) return 0;
        const id = self._get_id() orelse {
            Vapor.report.err("Id is null", .{});
            @panic("vapor: Id is null");
        };
        return Wasm.getVideoDurationWasm(id.ptr, id.len);
    }

    /// The playback position in seconds.
    pub fn getVideoCurrentTime(self: *Element) f32 {
        if (!isWasi) return 0;
        const id = self._get_id() orelse {
            Vapor.report.err("Id is null", .{});
            @panic("vapor: Id is null");
        };
        return Wasm.getVideoCurrentTimeWasm(id.ptr, id.len);
    }

    /// Moves the element with a GPU-accelerated `translate3d`, without a render.
    pub fn translate3d(element: *Element, translation: Translate3d) ?void {
        if (!isWasi) return;
        const id = element._get_id() orelse {
            Vapor.report.err("Id is null", .{});
            return null;
        };
        Wasm.translate3dWasm(id.ptr, id.len, translation.x, translation.y, translation.z);
    }

    /// Sends all pointer events of `evt`'s pointer to this element until released.
    pub fn setPointerCapture(element: *Element, evt: *Event) void {
        if (!isWasi) return;
        const id = element._get_id() orelse {
            Vapor.report.err("Id is null", .{});
            return;
        };
        Wasm.setPointerCaptureWasm(id.ptr, id.len, evt.id);
    }

    /// Ends `setPointerCapture`.
    pub fn releasePointerCapture(element: *Element, evt: *Event) void {
        if (!isWasi) return;
        const id = element._get_id() orelse {
            Vapor.report.err("Id is null", .{});
            return;
        };
        Vapor.report.info("{s} {any}", .{ id, evt.type });
        Wasm.releasePointerCaptureWasm(id.ptr, id.len, evt.id);
    }
};

/// Internal: sets the value of the text field with the given id.
pub fn setTextFieldValue(ptr: [*]const u8, len: u32, text_ptr: [*]const u8, text_len: u32) void {
    if (isWasi) {
        return Wasm.setInputValueWasm(ptr, len, text_ptr, text_len);
    } else {
        // Dummy implementation - nothing to do off-wasm
        return;
    }
}

/// Internal: sets a numeric DOM property by element id.
pub fn mutateDomElement(
    id_ptr: [*]const u8,
    id_len: usize,
    attribute: [*]const u8,
    attribute_len: usize,
    value: f32,
) void {
    if (isWasi) {
        Wasm.mutateDomElementWasm(id_ptr, id_len, attribute, attribute_len, value);
    }
}

const Translate3d = struct {
    x: f32 = 0,
    y: f32 = 0,
    z: f32 = 0,
    /// The CSS `translate3d(...)`, in frame memory.
    pub fn toString(self: *const Translate3d) []const u8 {
        return Vapor.fmtln("translate3d({d}px, {d}px, 0)", .{
            self.x,
            self.y,
            // self.z,
        });
    }
};

/// Internal: sets a numeric inline style property by element id.
pub fn mutateDomElementStyle(
    id_ptr: [*]const u8,
    id_len: usize,
    attribute: [*]const u8,
    attribute_len: usize,
    value: f32,
) void {
    if (isWasi) {
        Wasm.mutateDomElementStyleWasm(id_ptr, id_len, attribute, attribute_len, value);
    }
}

/// Internal: sets a string inline style property by element id.
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
    }
}

// The unit's tag name was the CSS suffix, so .percent produced "50percent".
test "attribute sizes use CSS unit suffixes" {
    Vapor.init(.{});
    Vapor.Page(.{ .route = "/element-units" }, struct {
        fn render() void {}
    }.render, null);
    const percent = Element.Sizing{ .value = 50, .unit = .percent };
    try std.testing.expectEqualStrings("50%", percent.toString());
    const px = Element.Sizing{ .value = 12, .unit = .px };
    try std.testing.expectEqualStrings("12px", px.toString());
    const none = Element.Sizing{ .value = 2, .unit = .none };
    try std.testing.expectEqualStrings("2", none.toString());
}
