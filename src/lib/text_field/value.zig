const TextFieldMod = @import("../TextField.zig");
const Self = TextFieldMod.TextFieldBuilder;
const std = @import("std");
const types = @import("../types.zig");
const Vapor = @import("../Vapor.zig");
const LifeCycle = @import("../Vapor.zig").LifeCycle;
const ElementDecl = types.ElementDeclaration;

pub fn TextArea() Self {
    const elem_decl = ElementDecl{
        .state_type = Self._state_type,
        .elem_type = .TextArea,
        .can_have_children = false,
    };

    const ui_node = LifeCycle.open(elem_decl) orelse {
        Vapor.printlnSrcErr("Could not add component Link to lifecycle {any}\n", .{error.CouldNotAllocate}, @src());
        @panic("vapor: Could not add component Link to lifecycle");
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
        .state_type = Self._state_type,
        .elem_type = .TextField,
        .can_have_children = false,
    };
    const ui_node = LifeCycle.open(elem_decl) orelse {
        Vapor.printlnSrcErr("{any}\n", .{error.CouldNotAllocate}, @src());
        @panic("vapor: could not allocate a TextField node");
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
            @panic("vapor: Error: TextField only accepts valid types, Not valid");
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
                        @panic("vapor: Error: Placeholder and TextField Type mismatch TextFieldType: PlaceholderType");
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
        @panic("vapor: Node is null must ref() first, before setting onChange");
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
        @panic("vapor: Node is null must ref() first, before setting onChange");
    };

    switch (self._text_field_type) {
        .password => {
            if (@TypeOf(value.*) != []const u8) {
                Vapor.printlnErr("val and TextField type mismatch", .{});
                return self.*;
            }
            _ = Vapor.text_field_table.replaceOrAdd(value) catch |err| {
                std.log.err("bindValue: Could not add string to table {any}\n", .{err});
                @panic("vapor: bindValue: Could not add string to table");
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
                @panic("vapor: bindValue: Could not add string to table");
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
                @panic("vapor: bindValue: Could not add string to table");
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
                @panic("vapor: bindValue: Could not add string to table");
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
                @panic("vapor: bindValue: Could not add string to table");
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
                @panic("vapor: bindValue: Could not add string to table");
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
                @panic("vapor: bindValue: Could not add string to table");
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
                    @panic("vapor: bindValue: Could not add string to table");
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
                    @panic("vapor: bindValue: Could not add string to table");
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
        else => {},
    }
    new_self._text_field_params = text_field_params;
    return new_self;
}
