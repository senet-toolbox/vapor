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

pub fn BuilderClose(comptime state_type: types.StateType) type {
    return struct {
        const Self = @This();
        const _state_type: types.StateType = state_type;

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
                unreachable;
            };
            new_self._ui_node = node;
            return node;
        }

        pub fn ellipsis(self: *const Self, value: types.Ellipsis) Self {
            if (self._elem_type != .Text) {
                Vapor.printWarn("Ellipsis can only be used on Text, not {any}", .{self._elem_type});
                return self.*;
            }
            var new_self: Self = self.*;
            var visual = new_self._visual orelse types.Visual{};
            visual.ellipsis = value;
            new_self._visual = visual;
            return new_self;
        }

        pub fn scroll(self: *const Self, scroll_type: types.Scroll) Self {
            var new_self: Self = self.*;
            new_self._scroll = scroll_type;
            return new_self;
        }

        pub fn TextArea() Self {
            const elem_decl = ElementDecl{
                .state_type = _state_type,
                .elem_type = .TextArea,
                .can_have_children = false,
            };

            const ui_node = LifeCycle.open(elem_decl) orelse {
                Vapor.printlnSrcErr("Could not add component Link to lifecycle {any}\n", .{error.CouldNotAllocate}, @src());
                unreachable;
            };

            const self = Self{
                ._elem_type = .TextArea,
                ._ui_node = ui_node,
                ._text_field_type = .string,
                ._text_field_params = .{ .string = .{} },
            };

            return self;
        }

        pub fn TextField(textfield_type: types.InputTypes) Self {
            const elem_decl = ElementDecl{
                .state_type = _state_type,
                .elem_type = .TextField,
                .can_have_children = false,
            };
            const ui_node = LifeCycle.open(elem_decl) orelse {
                Vapor.printlnSrcErr("{any}\n", .{error.CouldNotAllocate}, @src());
                unreachable;
            };

            switch (textfield_type) {
                .string => {
                    return Self{
                        ._elem_type = .TextField,
                        ._ui_node = ui_node,
                        ._text_field_type = .string,
                        ._text_field_params = .{ .string = .{} },
                    };
                },
                .int => {
                    return Self{
                        ._elem_type = .TextField,
                        ._ui_node = ui_node,
                        ._text_field_type = .int,
                        ._text_field_params = .{ .int = .{} },
                    };
                },
                .password => {
                    return Self{
                        ._elem_type = .TextField,
                        ._ui_node = ui_node,
                        ._text_field_type = .password,
                        ._text_field_params = .{ .password = .{} },
                    };
                },
                .email => {
                    return Self{
                        ._elem_type = .TextField,
                        ._ui_node = ui_node,
                        ._text_field_type = .email,
                        ._text_field_params = .{ .email = .{} },
                    };
                },
                .telephone => {
                    return Self{
                        ._elem_type = .TextField,
                        ._ui_node = ui_node,
                        ._text_field_type = .telephone,
                        ._text_field_params = .{ .telephone = .{} },
                    };
                },
                .file => {
                    return Self{
                        ._elem_type = .TextField,
                        ._ui_node = ui_node,
                        ._text_field_type = .file,
                        ._text_field_params = .{ .file = .{} },
                    };
                },
                .float => {
                    return Self{
                        ._elem_type = .TextField,
                        ._ui_node = ui_node,
                        ._text_field_type = .float,
                        ._text_field_params = .{ .float = .{} },
                    };
                },
                .date => {
                    return Self{
                        ._elem_type = .TextField,
                        ._ui_node = ui_node,
                        ._text_field_type = .date,
                        ._text_field_params = .{ .date = .{} },
                    };
                },
                .radio => {
                    return Self{
                        ._elem_type = .TextField,
                        ._ui_node = ui_node,
                        ._text_field_type = .radio,
                        ._text_field_params = .{ .radio = .{} },
                    };
                },
                else => {
                    Vapor.printlnSrcErr("Error: TextField only accepts valid types, Not valid: {any}", .{textfield_type}, @src());
                    unreachable;
                    // @compileError("TextField only accepts []const u8 or TextInput");
                },
            }
        }

        pub fn placeholder(self: *const Self, value: anytype) Self {
            var new_self: Self = self.*;
            var text_field_params = new_self._text_field_params orelse {
                Vapor.printlnSrcErr("TextFieldParams is null", .{}, @src());
                return self.*;
            };

            const V = @TypeOf(value);

            // Switch on the type of the value passed in
            switch (@typeInfo(V)) {
                .pointer => { // This correctly covers []const u8 (which is a *two-part* pointer type in memory)
                    if (@typeInfo(V).pointer.size == .slice or @typeInfo(V).pointer.size == .one) {
                        // The value is a []const u8 slice

                        // Now, safely switch on the TextField's type to update the correct union field
                        // All these fields expect a string (slice) value
                        switch (self._text_field_type) {
                            .string => {
                                text_field_params.string.default_ptr = value.ptr;
                                text_field_params.string.default_len = value.len;
                            },
                            .password => {
                                text_field_params.password.default_ptr = value.ptr;
                                text_field_params.password.default_len = value.len;
                            },
                            .email => {
                                text_field_params.email.default_ptr = value.ptr;
                                text_field_params.email.default_len = value.len;
                            },
                            .telephone => {
                                text_field_params.telephone.default_ptr = value.ptr;
                                text_field_params.telephone.default_len = value.len;
                            },
                            .file => {
                                text_field_params.file.default_ptr = value.ptr;
                                text_field_params.file.default_len = value.len;
                            },
                            .date => {
                                text_field_params.date.default_ptr = value.ptr;
                                text_field_params.date.default_len = value.len;
                            },
                            else => {
                                Vapor.printlnSrcErr("Error: Placeholder and TextField Type mismatch TextFieldType: {any} PlaceholderType: {any}", .{ self._text_field_type, V }, @src());
                                unreachable;
                                // @compileError("TextField only accepts []const u8 or TextInput");
                            },
                        }
                    } else {
                        Vapor.printlnErr("Cannot set integer placeholder on type: {any}", .{@typeInfo(V).pointer});
                        // @compileError("Placeholder received a generic pointer that is not a []const u8 string slice.");
                    }
                },
                .int, .comptime_int => {
                    // The value is an integer
                    switch (self._text_field_type) {
                        .int => {
                            text_field_params.int.default = value;
                        },
                        else => {
                            Vapor.printlnErr("Cannot set integer placeholder on type: " ++ @typeName(V), .{});
                        },
                        // else => @compileError("Cannot set integer placeholder on type: " ++ @typeName(V)),
                    }
                },
                .float => {
                    switch (self._text_field_type) {
                        .float => {
                            text_field_params.float.default = value;
                        },
                        else => {
                            Vapor.printlnErr("Cannot set float placeholder on type: " ++ @typeName(V), .{});
                        },
                        // else => @compileError("Cannot set float placeholder on type: " ++ @typeName(V)),
                    }
                },
                // Add other types (e.g., .Float for float input fields) as needed
                else => {
                    @compileError("Unsupported placeholder type: " ++ @typeName(V));
                },
            }

            new_self._text_field_params = text_field_params;
            return new_self;
        }

        pub fn fieldName(self: *const Self, name: []const u8) Self {
            var new_self: Self = self.*;
            new_self._name = name;
            return new_self;
        }

        pub fn required(self: *const Self, value: bool) Self {
            var new_self: Self = self.*;
            if (self._elem_type != .TextField and self._elem_type != .TextArea) {
                Vapor.printlnErr("bindValue only works on TextField and TextArea", .{});
                return self.*;
            }

            switch (self._text_field_type) {
                .radio => {
                    new_self._text_field_params.?.radio.required = value;
                },
                else => {
                    Vapor.printlnErr("NOT IMPLEMENTED", .{});
                    return self.*;
                },
            }
            return new_self;
        }

        pub fn valStr(self: *const Self, value: []const u8) Self {
            var new_self: Self = self.*;
            if (self._elem_type != .TextField and self._elem_type != .TextArea) {
                Vapor.printlnErr("bindValue only works on TextField and TextArea", .{});
                return self.*;
            }

            _ = self._ui_node orelse {
                Vapor.printlnSrcErr("Node is null must ref() first, before setting onChange", .{}, @src());
                unreachable;
            };

            switch (self._text_field_type) {
                .password => {
                    new_self._text_field_params.?.password.value_ptr = value.ptr;
                    new_self._text_field_params.?.password.value_len = value.len;
                },
                .email => {
                    new_self._text_field_params.?.email.value_ptr = value.ptr;
                    new_self._text_field_params.?.email.value_len = value.len;
                },
                .string => {
                    new_self._text_field_params.?.string.value_ptr = value.ptr;
                    new_self._text_field_params.?.string.value_len = value.len;
                },
                .telephone => {
                    new_self._text_field_params.?.telephone.value_ptr = value.ptr;
                    new_self._text_field_params.?.telephone.value_len = value.len;
                },
                .date => {
                    new_self._text_field_params.?.date.value_ptr = value.ptr;
                    new_self._text_field_params.?.date.value_len = value.len;
                },
                else => {
                    Vapor.printlnErr("NOT IMPLEMENTED", .{});
                    return self.*;
                },
            }

            return new_self;
        }

        pub fn val(self: *const Self, value: anytype) Self {
            var new_self: Self = self.*;
            if (self._elem_type != .TextField and self._elem_type != .TextArea) {
                Vapor.printlnErr("bindValue only works on TextField or TextArea", .{});
                return self.*;
            }
            if (@typeInfo(@TypeOf(value)) != .pointer) {
                Vapor.printlnErr("bindValue only works on pointer types", .{});
                return self.*;
            }

            _ = self._ui_node orelse {
                Vapor.printlnSrcErr("Node is null must ref() first, before setting onChange", .{}, @src());
                unreachable;
            };

            switch (self._text_field_type) {
                .password => {
                    if (@TypeOf(value.*) != []const u8) {
                        Vapor.printlnErr("val and TextField type mismatch", .{});
                        return self.*;
                    }
                    _ = Vapor.text_field_table.replaceOrAdd(value) catch |err| {
                        std.log.err("bindValue: Could not add string to table {any}\n", .{err});
                        unreachable;
                    };

                    new_self._text_field_params.?.password.value_ptr = value.*.ptr;
                    new_self._text_field_params.?.password.value_len = value.*.len;
                },
                .email => {
                    if (@TypeOf(value.*) != []const u8) {
                        Vapor.printlnErr("val and TextField type mismatch", .{});
                        return self.*;
                    }
                    _ = Vapor.text_field_table.replaceOrAdd(value) catch |err| {
                        std.log.err("bindValue: Could not add string to table {any}\n", .{err});
                        unreachable;
                    };

                    new_self._text_field_params.?.email.value_ptr = value.*.ptr;
                    new_self._text_field_params.?.email.value_len = value.*.len;
                },
                .string => {
                    if (@TypeOf(value.*) != []const u8) {
                        Vapor.printlnErr("val and TextField type mismatch {any} != []const u8", .{@TypeOf(value.*)});
                        return self.*;
                    }
                    _ = Vapor.text_field_table.replaceOrAdd(value) catch |err| {
                        std.log.err("bindValue: Could not add string to table {any}\n", .{err});
                        unreachable;
                    };

                    new_self._text_field_params.?.string.value_ptr = value.*.ptr;
                    new_self._text_field_params.?.string.value_len = value.*.len;
                },
                .telephone => {
                    if (@TypeOf(value.*) != []const u8) {
                        Vapor.printlnErr("val and TextField type mismatch", .{});
                        return self.*;
                    }
                    _ = Vapor.text_field_table.replaceOrAdd(value) catch |err| {
                        std.log.err("bindValue: Could not add string to table {any}\n", .{err});
                        unreachable;
                    };

                    new_self._text_field_params.?.telephone.value_ptr = value.*.ptr;
                    new_self._text_field_params.?.telephone.value_len = value.*.len;
                },

                .int => {
                    if (@TypeOf(value.*) != i32) {
                        Vapor.printlnErr("val and TextField type mismatch {any}", .{@TypeOf(value.*)});
                        return self.*;
                    }
                    new_self._text_field_params.?.int.value = value.*;
                    new_self._text_field_params.?.int.default = value.*;
                },
                .float => {
                    if (@TypeOf(value.*) != f32) {
                        Vapor.printlnErr("val and TextField type mismatch", .{});
                        return self.*;
                    }
                    new_self._text_field_params.?.float.value = value.*;
                },
                .date => {
                    if (@TypeOf(value.*) != []const u8) {
                        Vapor.printlnErr("val and TextField type mismatch", .{});
                        return self.*;
                    }
                    new_self._text_field_params.?.date.value_ptr = value.ptr;
                    new_self._text_field_params.?.date.value_len = value.len;
                },
                .radio => {
                    if (@TypeOf(value.*) != []const u8) {
                        Vapor.printlnErr("val and TextField type mismatch", .{});
                        return self.*;
                    }
                    new_self._text_field_params.?.radio.value_ptr = value.ptr;
                    new_self._text_field_params.?.radio.value_len = value.len;
                },
                else => {
                    Vapor.printlnErr("NOT IMPLEMENTED", .{});
                    return self.*;
                },
            }
            new_self._value = @ptrCast(@alignCast(value));

            return new_self;
        }

        pub fn bind(self: *const Self, value: anytype) Self {
            var new_self: Self = self.*;
            if (self._elem_type != .TextField and self._elem_type != .TextArea) {
                Vapor.printlnErr("bindValue only works on TextField", .{});
                return self.*;
            }
            if (@typeInfo(@TypeOf(value)) != .pointer) {
                Vapor.printlnErr("bindValue only works on pointer types", .{});
                return self.*;
            }

            switch (self._text_field_type) {
                .password => {
                    if (@TypeOf(value.*) != []const u8) {
                        Vapor.printlnErr("Password bindValue and TextField type mismatch", .{});
                        return self.*;
                    }
                    _ = Vapor.text_field_table.replaceOrAdd(value) catch |err| {
                        std.log.err("bindValue: Could not add string to table {any}\n", .{err});
                        unreachable;
                    };

                    new_self._text_field_params.?.password.value_ptr = value.*.ptr;
                    new_self._text_field_params.?.password.value_len = value.*.len;
                },
                .email => {
                    if (@TypeOf(value.*) != []const u8) {
                        Vapor.printlnErr("Email bindValue and TextField type mismatch", .{});
                        return self.*;
                    }
                    _ = Vapor.text_field_table.replaceOrAdd(value) catch |err| {
                        std.log.err("bindValue: Could not add string to table {any}\n", .{err});
                        unreachable;
                    };

                    new_self._text_field_params.?.email.value_ptr = value.*.ptr;
                    new_self._text_field_params.?.email.value_len = value.*.len;
                },
                .telephone => {
                    if (@TypeOf(value.*) != []const u8) {
                        Vapor.printlnErr("Telephone bindValue and TextField type mismatch", .{});
                        return self.*;
                    }
                    _ = Vapor.text_field_table.replaceOrAdd(value) catch |err| {
                        std.log.err("bindValue: Could not add string to table {any}\n", .{err});
                        unreachable;
                    };

                    new_self._text_field_params.?.telephone.value_ptr = value.*.ptr;
                    new_self._text_field_params.?.telephone.value_len = value.*.len;
                },
                .string => {
                    if (@TypeOf(value.*) == []u8) {
                        Vapor.printlnErr("String bindValue and TextField type mismatch {any}", .{@typeInfo(@TypeOf(value.*))});
                        return self.*;
                    } else if (@TypeOf(value.*) == []const u8) {
                        _ = Vapor.text_field_table.replaceOrAdd(value) catch |err| {
                            std.log.err("bindValue: Could not add string to table {any}\n", .{err});
                            unreachable;
                        };
                    } else {
                        Vapor.printlnErr("String bindValue and TextField type mismatch {any}", .{@typeInfo(@TypeOf(value.*))});
                        return self.*;
                    }

                    new_self._text_field_params.?.string.value_ptr = value.*.ptr;
                    new_self._text_field_params.?.string.value_len = value.*.len;
                },
                .int => {
                    if (@TypeOf(value.*) != i32) {
                        Vapor.printlnErr("int bindValue and TextField type mismatch {any}", .{@TypeOf(value.*)});
                        return self.*;
                    }

                    new_self._text_field_params.?.int.value = value.*;
                },
                .float => {
                    if (@TypeOf(value.*) != f32) {
                        Vapor.printlnErr("Float bindValue and TextField type mismatch", .{});
                        return self.*;
                    }
                },
                .date => {
                    if (@TypeOf(value.*) == []u8) {
                        Vapor.printlnErr("String bindValue and TextField type mismatch {any}", .{@typeInfo(@TypeOf(value.*))});
                        return self.*;
                    } else if (@TypeOf(value.*) == []const u8) {
                        _ = Vapor.text_field_table.replaceOrAdd(value) catch |err| {
                            std.log.err("bindValue: Could not add string to table {any}\n", .{err});
                            unreachable;
                        };
                    } else {
                        Vapor.printlnErr("String bindValue and TextField type mismatch {any}", .{@typeInfo(@TypeOf(value.*))});
                        return self.*;
                    }

                    new_self._text_field_params.?.date.value_ptr = value.*.ptr;
                    new_self._text_field_params.?.date.value_len = value.*.len;
                },
                else => {
                    Vapor.printlnErr("NOT IMPLEMENTED", .{});
                    return self.*;
                },
            }
            // Store the bound pointer
            new_self._value = @ptrCast(@alignCast(value));

            // Build an erased updater fn for this specific type
            const Updater = struct {
                pub fn update(ptr: *anyopaque, evt: *Vapor.Event) void {
                    const T = @TypeOf(value.*);
                    const typed: *T = @ptrCast(@alignCast(ptr));

                    typed.* = switch (@typeInfo(T)) {
                        .int, .float, .comptime_int, .comptime_float => evt.number() catch blk: {
                            std.log.err("Error casting number", .{});
                            break :blk 0;
                        },
                        .pointer => |info| if (info.child == u8) evt.text() else @compileError("unsupported pointer type"),
                        else => @compileError("unsupported type: " ++ @typeName(T)),
                    };
                }
            };
            new_self._bind_ptr = @ptrCast(@alignCast(value));
            new_self._bind_update_fn = Updater.update;

            return new_self;
        }

        pub fn focus(self: *const Self) Self {
            const ui_node = self._ui_node orelse {
                Vapor.printlnSrcErr("Node is null", .{}, @src());
                unreachable;
            };

            var uuid: []const u8 = ui_node.uuid;
            if (self._id) |_id| {
                uuid = _id;
            }

            Vapor.onLayout(Vapor.focus, .{uuid});
            return self.*;
        }

        pub fn onFocus(self: *const Self, cb: fn (*Vapor.Event) void) Self {
            var new_self: Self = self.*;

            const ui_node = self._ui_node orelse blk: {
                const ui_node = LifeCycle.open(ElementDecl{
                    .state_type = _state_type,
                    .elem_type = self._elem_type,
                }) orelse {
                    Vapor.printlnSrcErr("Node is null", .{}, @src());
                    unreachable;
                };
                new_self._ui_node = ui_node;

                break :blk ui_node;
            };

            Vapor.attachEventCallback(ui_node, .focus, cb) catch |err| {
                Vapor.println("ONLEAVE: Could not attach event callback {any}\n", .{err});
                unreachable;
            };
            return new_self;
        }

        pub fn onBlur(self: *const Self, cb: fn (*Vapor.Event) void) Self {
            var new_self: Self = self.*;

            const ui_node = self._ui_node orelse blk: {
                const ui_node = LifeCycle.open(ElementDecl{
                    .state_type = _state_type,
                    .elem_type = self._elem_type,
                }) orelse {
                    Vapor.printlnSrcErr("Node is null", .{}, @src());
                    unreachable;
                };
                new_self._ui_node = ui_node;

                break :blk ui_node;
            };

            Vapor.attachEventCallback(ui_node, .blur, cb) catch |err| {
                Vapor.println("ONLEAVE: Could not attach event callback {any}\n", .{err});
                unreachable;
            };

            return new_self;
        }

        pub fn onScroll(self: *const Self, callback: anytype, args: anytype) Self {
            var new_self = self.*;
            new_self._on_change_cb = Vapor.ErasedEventCallback.make(Vapor.arena(.frame), .scroll, callback, args) catch |err| {
                Vapor.printlnErr("onScroll: could not allocate callback, handler not attached: {any}", .{err});
                return new_self;
            };
            return new_self;
        }

        pub fn onEvent(self: *const Self, event: types.EventType, func: anytype, args: anytype) *const Self {
            const ui_node = self._ui_node orelse {
                Vapor.printlnSrcErr("Node is null", .{}, @src());
                unreachable;
            };
            Vapor.attachEventCtxCallback(ui_node, event, func, args) catch |err| {
                Vapor.println("OnEventCtx: Could not attach event callback {any}\n", .{err});
                unreachable;
            };
            return self;
        }

        pub fn onEventCtx(self: *const Self, event: types.EventType, func: anytype, args: anytype) *const Self {
            const ui_node = self._ui_node orelse {
                Vapor.printlnSrcErr("Node is null", .{}, @src());
                unreachable;
            };
            Vapor.attachEventCtxCallback(ui_node, event, func, args) catch |err| {
                Vapor.println("OnEventCtx: Could not attach event callback {any}\n", .{err});
                unreachable;
            };
            return self;
        }

        pub fn onMount(self: *const Self, callback: anytype, args: anytype) *const Self {
            const ui_node = self._ui_node orelse {
                Vapor.printlnSrcErr("Node is null", .{}, @src());
                unreachable;
            };

            const erased = Vapor.ErasedCallback.make(Vapor.arena(.frame), callback, args) catch |err| {
                Vapor.println("Error could not create closure {any}\n", .{err});
                return self;
            };

            var mount_node_key = hashKey(ui_node.uuid);
            mount_node_key +%= hashKey(Vapor.on_mount_hash);

            Vapor.erased_hooks_registry.put(mount_node_key, erased) catch |err| {
                Vapor.printlnErr("Could Not add mount callback {any}", .{err});
                return self;
            };
            ui_node.on_callbacks[0] = mount_node_key;

            return self;
        }

        pub fn onChange(self: *const Self, func: anytype, args: anytype) Self {
            var new_self = self.*;
            new_self._on_change_cb = Vapor.ErasedEventCallback.make(Vapor.arena(.frame), .input, func, args) catch |err| {
                Vapor.printlnErr("onChange: could not allocate callback, handler not attached: {any}", .{err});
                return new_self;
            };
            return new_self;
        }

        pub fn fontWeight(self: *const Self, value: u16) Self {
            var n = self.*;
            var v = n._visual orelse types.Visual{};
            v.font_weight = value;
            n._visual = v;
            return n;
        }

        pub fn fontColor(self: *const Self, color: ?Color) Self {
            var n = self.*;
            var v = n._visual orelse types.Visual{};
            v.text_color = color;
            n._visual = v;
            return n;
        }

        pub fn onKeyDown(self: *const Self, cb: fn (*Vapor.Event) void) Self {
            var new_self: Self = self.*;

            const ui_node = self._ui_node orelse blk: {
                const ui_node = LifeCycle.open(ElementDecl{
                    .state_type = _state_type,
                    .elem_type = self._elem_type,
                }) orelse {
                    Vapor.printlnSrcErr("Node is null", .{}, @src());
                    unreachable;
                };
                new_self._ui_node = ui_node;

                break :blk ui_node;
            };

            // If we have a binded value we instead create a wrapper ctx around the cb passed in
            // this way we can update the binded values from the callback and call the developer's
            // cb with the updated value
            Vapor.attachEventCallback(ui_node, .keydown, cb) catch |err| {
                Vapor.println("ONLEAVE: Could not attach event callback {any}\n", .{err});
                unreachable;
            };

            return new_self;
        }

        pub fn config(self: *const Self, text_field_config: types.TextFieldConfig) Self {
            var new_self: Self = self.*;
            var text_field_params = new_self._text_field_params orelse {
                Vapor.printlnSrcErr("TextFieldParams is null", .{}, @src());
                return self.*;
            };
            switch (text_field_params) {
                .string => {
                    text_field_params.string.min_len = text_field_config.min;
                    text_field_params.string.max_len = text_field_config.max;
                },
                .int => {
                    text_field_params.int.min_len = text_field_config.min;
                    text_field_params.int.max_len = text_field_config.max;
                },
                // .password => |password| {
                //     password.min_len = config.min_len;
                //     password.max_len = config.max_len;
                // },
                // .email => |email| {
                //     email.min_len = config.min_len;
                //     email.max_len = config.max_len;
                // },
                // .telephone => |telephone| {
                //     telephone.min_len = config.min_len;
                //     telephone.max_len = config.max_len;
                // },
                // .file => |file| {
                //     file.min_len = config.min_len;
                //     file.max_len = config.max_len;
                // },
                else => {},
            }
            new_self._text_field_params = text_field_params;
            return new_self;
        }

        pub fn whitespace(self: *const Self, value: types.WhiteSpace) Self {
            var new_self: Self = self.*;
            var visual = new_self._visual orelse types.Visual{};
            visual.white_space = value;
            new_self._visual = visual;
            return new_self;
        }

        pub fn fontSize(self: *const Self, font_size: u8) Self {
            var new_self: Self = self.*;
            var visual = new_self._visual orelse types.Visual{};
            visual.font_size = font_size;
            new_self._visual = visual;
            return new_self;
        }

        pub fn fontFamily(self: *const Self, font_family: []const u8) Self {
            var new_self: Self = self.*;
            new_self._font_family = font_family;
            return new_self;
        }

        pub fn onHover(self: *const Self, cb: fn (*Vapor.Event) void) Self {
            var new_self: Self = self.*;

            const ui_node = self._ui_node orelse blk: {
                const ui_node = LifeCycle.open(ElementDecl{
                    .state_type = _state_type,
                    .elem_type = self._elem_type,
                }) orelse {
                    Vapor.printlnSrcErr("Node is null", .{}, @src());
                    unreachable;
                };
                new_self._ui_node = ui_node;

                break :blk ui_node;
            };

            Vapor.attachEventCallback(ui_node, .pointerenter, cb) catch |err| {
                Vapor.println("ONLEAVE: Could not attach event callback {any}\n", .{err});
                unreachable;
            };

            return new_self;
        }

        pub fn onLeave(self: *const Self, cb: fn (*Vapor.Event) void) Self {
            var new_self: Self = self.*;

            const ui_node = self._ui_node orelse blk: {
                const ui_node = LifeCycle.open(ElementDecl{
                    .state_type = _state_type,
                    .elem_type = self._elem_type,
                }) orelse {
                    Vapor.printlnSrcErr("Node is null", .{}, @src());
                    unreachable;
                };
                new_self._ui_node = ui_node;

                break :blk ui_node;
            };
            Vapor.attachEventCallback(ui_node, .mouseleave, cb) catch |err| {
                Vapor.println("ONLEAVE: Could not attach event callback {any}\n", .{err});
                unreachable;
            };

            return new_self;
        }

        pub fn onHoverCtx(self: *const Self, cb: anytype, args: anytype) Self {
            var new_self: Self = self.*;

            const ui_node = self._ui_node orelse blk: {
                const ui_node = LifeCycle.open(ElementDecl{
                    .state_type = _state_type,
                    .elem_type = self._elem_type,
                }) orelse {
                    Vapor.printlnSrcErr("Node is null", .{}, @src());
                    unreachable;
                };
                new_self._ui_node = ui_node;

                break :blk ui_node;
            };

            Vapor.attachEventCtxCallback(ui_node, .mouseenter, cb, args) catch |err| {
                Vapor.println("ONLEAVE: Could not attach event callback {any}\n", .{err});
                unreachable;
            };

            return new_self;
        }

        /// Gives the field a stable identity, the same as `.id()` on the
        /// element builders.
        ///
        /// The generated uuid encodes the child's position, so a field that
        /// moves is seen by the reconciler as a delete plus an insert. `_id`
        /// also travels through `end()` into the style, which is where
        /// `Configuration` picks it up; setting the uuid here as well means the
        /// identity is established as soon as the caller asks for it.
        pub fn id(self: *const Self, element_id: []const u8) Self {
            var new_self: Self = self.*;
            new_self._id = element_id;
            if (new_self._ui_node) |node| Vapor.assignUserId(node, element_id);
            return new_self;
        }

        pub fn animationEnter(self: *const Self, animation_tag: ?[]const u8) Self {
            if (animation_tag) |_animation| {
                var new_self: Self = self.*;
                new_self._animation_enter = _animation;
                return new_self;
            }
            return self.*;
        }

        pub fn animation(self: *const Self, animation_tag: ?[]const u8) Self {
            if (animation_tag) |_animation| {
                var new_self: Self = self.*;
                var visual = new_self._visual orelse types.Visual{};
                visual.animation = _animation;
                new_self._visual = visual;
                return new_self;
            }
            return self.*;
        }

        pub fn animationExit(self: *const Self, animation_tag: ?[]const u8) Self {
            var new_self: Self = self.*;
            new_self._animation_exit = animation_tag;
            return new_self;
        }

        pub fn ref(self: *const Self, element: *Element) Self {
            var new_self: Self = self.*;

            const ui_node = self._ui_node orelse blk: {
                const ui_node = LifeCycle.open(ElementDecl{
                    .state_type = _state_type,
                    .elem_type = self._elem_type,
                }) orelse {
                    Vapor.printlnSrcErr("Node is null", .{}, @src());
                    unreachable;
                };
                new_self._ui_node = ui_node;

                break :blk ui_node;
            };

            element.element_type = self._elem_type;
            element._node_ptr = ui_node;
            new_self._element = element;

            const uuid = ui_node.uuid;
            Vapor.element_registry.put(hashKey(uuid), element) catch |err| {
                Vapor.printlnErr("bind: could not register element: {any}", .{err});
            };
            return new_self;
        }

        pub fn baseStyle(self: *const Self, style_ptr: *const Vapor.Style) Self {
            var new_self: Self = self.*;
            new_self._style = style_ptr;
            return new_self;
        }

        pub fn interaction(self: *const Self, interactive: types.Interactive) Self {
            var new_self: Self = self.*;
            new_self._interactive = interactive;
            return new_self;
        }

        /// Set full accessibility config
        pub fn a11y(self: *const Self, accessibility: Accessibility) Self {
            var new_self: Self = self.*;
            new_self._accessibility = accessibility;
            return new_self;
        }

        /// Shorthand: just set aria-label
        pub fn ariaLabel(self: *const Self, label: []const u8) Self {
            var new_self: Self = self.*;
            var acc = new_self._accessibility orelse Accessibility{};
            acc.label = label;
            new_self._accessibility = acc;
            return new_self;
        }

        /// Shorthand: set role
        pub fn role(self: *const Self, r: Accessibility.Role) Self {
            var new_self: Self = self.*;
            var acc = new_self._accessibility orelse Accessibility{};
            acc.role = r;
            new_self._accessibility = acc;
            return new_self;
        }

        /// Shorthand: aria-expanded
        pub fn ariaExpanded(self: *const Self, expanded: bool) Self {
            var new_self: Self = self.*;
            var acc = new_self._accessibility orelse Accessibility{};
            acc.expanded = expanded;
            new_self._accessibility = acc;
            return new_self;
        }

        /// Shorthand: aria-selected
        pub fn ariaSelected(self: *const Self, selected: bool) Self {
            var new_self: Self = self.*;
            var acc = new_self._accessibility orelse Accessibility{};
            acc.selected = selected;
            new_self._accessibility = acc;
            return new_self;
        }

        /// Shorthand: aria-controls
        pub fn ariaControls(self: *const Self, uuid: []const u8) Self {
            var new_self: Self = self.*;
            var acc = new_self._accessibility orelse Accessibility{};
            acc.controls = uuid;
            new_self._accessibility = acc;
            return new_self;
        }

        /// Shorthand: aria-activedescendant
        pub fn ariaActiveDescendant(self: *const Self, uuid: ?[]const u8) Self {
            var new_self: Self = self.*;
            var acc = new_self._accessibility orelse Accessibility{};
            acc.active_descendant = uuid;
            new_self._accessibility = acc;
            return new_self;
        }

        /// Shorthand: aria-hidden
        pub fn ariaHidden(self: *const Self, hidden_val: bool) Self {
            var new_self: Self = self.*;
            var acc = new_self._accessibility orelse Accessibility{};
            acc.hidden = hidden_val;
            new_self._accessibility = acc;
            return new_self;
        }

        /// Shorthand: tabindex
        pub fn tabIndex(self: *const Self, index: i16) Self {
            var new_self: Self = self.*;
            var acc = new_self._accessibility orelse Accessibility{};
            acc.tab_index = index;
            new_self._accessibility = acc;
            return new_self;
        }

        pub fn whiteSpace(self: *const Self, value: types.WhiteSpace) Self {
            var n = self.*;
            var v = n._visual orelse types.Visual{};
            v.white_space = value;
            n._visual = v;
            return n;
        }

        /// This function takes a const pointer to a Style Struct, and returns the body function callback
        /// This function is static, so any styles added via chaining methods will not be applied
        /// Use baseStyle to keep all chained additions
        pub fn style(self: *const Self, style_ptr: *const Vapor.Style) Self {
            var new_self: Self = self.*;
            new_self._style = style_ptr;
            return new_self;
        }

        pub fn font(self: *const Self, font_size: u8, weight: ?u16, color: ?Color) Self {
            var new_self: Self = self.*;
            var visual = new_self._visual orelse types.Visual{};
            visual.font_size = font_size;
            visual.font_weight = weight;
            visual.text_color = color;
            new_self._visual = visual;
            return new_self;
        }

        pub fn bold(self: *const Self) Self {
            var new_self: Self = self.*;
            var visual = new_self._visual orelse types.Visual{};
            visual.font_weight = 700;
            new_self._visual = visual;
            return new_self;
        }

        pub fn pos(self: *const Self, position: types.Position) Self {
            var new_self: Self = self.*;
            var new_position = new_self._pos orelse types.Position{};
            new_position.top = position.top;
            new_position.right = position.right;
            new_position.bottom = position.bottom;
            new_position.left = position.left;
            new_position.type = position.type;
            new_self._pos = new_position;
            return new_self;
        }

        pub fn zIndex(self: *const Self, z_index: ?i16) Self {
            var new_self: Self = self.*;
            var position = new_self._pos orelse types.Position{};
            position.z_index = z_index;
            new_self._pos = position;
            return new_self;
        }

        pub fn blur(self: *const Self, value: ?u8) Self {
            var new_self: Self = self.*;
            var visual = new_self._visual orelse types.Visual{};
            visual.blur = value;
            new_self._visual = visual;
            return new_self;
        }

        pub fn layout(self: *const Self, value: types.Layout) Self {
            var new_self: Self = self.*;
            new_self._layout = value;
            return new_self;
        }

        pub fn center(self: *const Self) Self {
            var new_self: Self = self.*;
            new_self._layout = .center;
            return new_self;
        }

        pub fn background(self: *const Self, value: types.Color) Self {
            var new_self: Self = self.*;
            var visual = new_self._visual orelse types.Visual{};
            visual.background = value;
            new_self._visual = visual;
            return new_self;
        }

        pub fn shadow(self: *const Self, value: types.Shadow) Self {
            var new_self: Self = self.*;
            var visual = new_self._visual orelse types.Visual{};
            visual.shadow = value;
            new_self._visual = visual;
            return new_self;
        }

        pub fn layer(self: *const Self, value: types.BackgroundLayer) Self {
            var new_self: Self = self.*;
            var visual = new_self._visual orelse types.Visual{};
            visual.layer = value;
            new_self._visual = visual;
            return new_self;
        }

        pub fn wrap(self: *const Self, value: types.FlexWrap) Self {
            var new_self: Self = self.*;
            new_self._flex_wrap = value;
            return new_self;
        }

        pub fn textDecoration(self: *const Self, value: types.TextDecoration) Self {
            var new_self: Self = self.*;
            var visual = new_self._visual orelse types.Visual{};
            visual.text_decoration = value;
            new_self._visual = visual;
            return new_self;
        }

        pub fn hoverScale(self: *const Self) Self {
            var new_self: Self = self.*;
            var _interactive = new_self._interactive orelse types.Interactive{};
            var hover = _interactive.hover orelse types.Visual{};
            hover.transform = .scale();
            _interactive.hover = hover;
            new_self._interactive = _interactive;
            return new_self;
        }

        pub fn outline(self: *const Self, value: types.Outline, color: ?Color) Self {
            var new_self: Self = self.*;
            var visual = new_self._visual orelse types.Visual{};
            visual.outline = value;
            visual.outline_color = color;
            new_self._visual = visual;
            return new_self;
        }

        pub fn caret(self: *const Self, value: types.Caret) Self {
            var new_self: Self = self.*;
            var visual = new_self._visual orelse types.Visual{};
            visual.caret = value;
            new_self._visual = visual;
            return new_self;
        }

        pub fn resize(self: *const Self, value: types.Resize) Self {
            var new_self: Self = self.*;
            var visual = new_self._visual orelse types.Visual{};
            visual.resize = value;
            new_self._visual = visual;
            return new_self;
        }

        pub fn hoverBackground(self: *const Self, color: types.Color) Self {
            var new_self: Self = self.*;
            var _interactive = new_self._interactive orelse types.Interactive{};
            var hover = _interactive.hover orelse types.Visual{};
            hover.background = color;
            _interactive.hover = hover;
            new_self._interactive = _interactive;
            return new_self;
        }

        pub fn pointer(self: *const Self) Self {
            var new_self: Self = self.*;
            var visual = new_self._visual orelse types.Visual{};
            visual.cursor = .pointer;
            new_self._visual = visual;
            return new_self;
        }

        pub fn noDecoration(self: *const Self) Self {
            var new_self: Self = self.*;
            var visual = new_self._visual orelse types.Visual{};
            visual.text_decoration = .none;
            new_self._visual = visual;
            return new_self;
        }

        pub fn hoverText(self: *const Self, color: types.Color) Self {
            var new_self: Self = self.*;
            var _interactive = new_self._interactive orelse types.Interactive{};
            var hover = _interactive.hover orelse types.Visual{};
            hover.text_color = color;
            _interactive.hover = hover;
            new_self._interactive = _interactive;
            return new_self;
        }
        pub fn childGap(self: *const Self, value: u8) Self {
            var new_self: Self = self.*;
            new_self._child_gap = value;
            return new_self;
        }

        pub fn spacing(self: *const Self, value: u8) Self {
            var new_self: Self = self.*;
            new_self._child_gap = value;
            return new_self;
        }

        pub fn padding(self: *const Self, value: types.Padding) Self {
            var new_self: Self = self.*;
            new_self._padding = value;
            return new_self;
        }

        pub fn pl(self: *const Self, value: u8) Self {
            var new_self: Self = self.*;
            if (new_self._padding == null) {
                new_self._padding = .{};
            }
            new_self._padding.?._left = value;
            return new_self;
        }

        pub fn pr(self: *const Self, value: u8) Self {
            var new_self: Self = self.*;
            if (new_self._padding == null) {
                new_self._padding = .{};
            }
            new_self._padding.?._right = value;
            return new_self;
        }

        pub fn pt(self: *const Self, value: u8) Self {
            var new_self: Self = self.*;
            if (new_self._padding == null) {
                new_self._padding = .{};
            }
            new_self._padding.?._top = value;
            return new_self;
        }

        pub fn pb(self: *const Self, value: u8) Self {
            var new_self: Self = self.*;
            if (new_self._padding == null) {
                new_self._padding = .{};
            }
            new_self._padding.?._bottom = value;
            return new_self;
        }

        pub fn cursor(self: *const Self, value: types.Cursor) Self {
            var new_self: Self = self.*;
            var visual = new_self._visual orelse types.Visual{};
            visual.cursor = value;
            new_self._visual = visual;
            return new_self;
        }

        pub fn margin(self: *const Self, value: types.Margin) Self {
            var new_self: Self = self.*;
            new_self._margin = value;
            return new_self;
        }

        pub fn size(self: *const Self, dim: types.Size) Self {
            var new_self: Self = self.*;
            new_self._size = dim;
            return new_self;
        }

        pub fn hw(self: *const Self, height_value: types.Sizing, width_value: types.Sizing) Self {
            var new_self: Self = self.*;
            if (new_self._size == null) {
                new_self._size = .{ .width = width_value, .height = height_value };
            } else {
                new_self._size.?.width = width_value;
                new_self._size.?.height = height_value;
            }
            return new_self;
        }

        pub fn width(self: *const Self, length: types.Sizing) Self {
            var new_self: Self = self.*;
            if (new_self._size == null) {
                new_self._size = .{ .width = length };
            } else {
                new_self._size.?.width = length;
            }
            return new_self;
        }

        pub fn height(self: *const Self, length: types.Sizing) Self {
            var new_self: Self = self.*;
            if (new_self._size == null) {
                new_self._size = .{ .height = length };
            } else {
                new_self._size.?.height = length;
            }
            return new_self;
        }

        pub fn border(self: *const Self, value: types.BorderGrouped) Self {
            var new_self: Self = self.*;
            var visual = new_self._visual orelse types.Visual{};
            visual.border = value;
            new_self._visual = visual;
            return new_self;
        }

        pub fn radius(self: *const Self, value: types.BorderRadius) Self {
            var new_self: Self = self.*;
            var visual = new_self._visual orelse types.Visual{};
            visual.border_radius = value;
            new_self._visual = visual;
            return new_self;
        }

        pub fn duration(self: *const Self, value: u32) Self {
            var new_self: Self = self.*;
            new_self._transition = .{ .duration = value };
            return new_self;
        }

        pub fn direction(self: *const Self, value: types.Direction) Self {
            var new_self: Self = self.*;
            new_self._direction = value;
            return new_self;
        }

        pub fn class(self: *const Self, class_name: []const u8) Self {
            var n = self.*;
            n._class = class_name;
            return n;
        }

        pub fn inlineStyle(self: *const Self, comptime fmt: []const u8, args: anytype) Self {
            var new_self: Self = self.*;
            const allocator = Vapor.arena(.frame);
            const text = std.fmt.allocPrint(allocator, fmt, args) catch |err| {
                Vapor.printlnColor(
                    \\Error formatting text: {any}\n"
                    \\FMT: {s}\n"
                    \\ARGS: {any}\n"
                , .{ err, fmt, args }, .hex("#FF3029"));
                return new_self;
            };
            Vapor.frame_arena.addBytesUsed(text.len);
            new_self._inlineStyle = text;
            return new_self;
        }

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
                const node = self._ui_node orelse unreachable;

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
