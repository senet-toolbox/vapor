//! Reads structs the JS runtime builds (form data, file info, resize entries)
//! from wasm memory, and describes Zig structs' layout to JS.

const std = @import("std");
const Vapor = @import("vapor.zig");
const utils = @import("utils.zig");
const getUnderlyingType = utils.getUnderlyingType;

// Zig Side
const FieldType = enum {
    string,
    int,
    float,
    bool,
};

pub const Field = struct {
    name: []const u8,
    type: FieldType,
    value: union(enum) {
        string: []const u8,
        int: i32,
        float: f32,
        bool: bool,
    },
};

pub const DynamicObject = struct {
    fields: std.array_list.Managed(Field),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) DynamicObject {
        return .{
            .fields = std.array_list.Managed(Field).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *DynamicObject) void {
        self.fields.deinit();
    }
};

pub fn convertFromDynamicToType(comptime T: type, dyn_object: *DynamicObject) T {
    var new_object: T = undefined;
    const fields = @typeInfo(T).@"struct".fields;
    inline for (fields, 0..) |field, i| {
        const dyn_field_value = dyn_object.fields.items[i].value;
        const dyn_field_type = dyn_object.fields.items[i].type;
        switch (@typeInfo(field.type)) {
            .pointer => |ptr| {
                if (ptr.size == .slice) {
                    @field(new_object, field.name) = dyn_field_value.string;
                } else {
                    std.log.err("Not implemented yet, TYPE: {any}", .{field.type});
                }
            },
            .int => {
                if (dyn_field_type == .int) {
                    @field(new_object, field.name) = @as(field.type, @intCast(dyn_field_value.int));
                } else {
                    std.log.err("Not implemented yet, TYPE: {any}", .{field.type});
                }
            },
            .float => {
                if (dyn_field_type == .float) {
                    @field(new_object, field.name) = @as(field.type, @floatCast(dyn_field_value.float));
                } else if (dyn_field_type == .int) {
                    @field(new_object, field.name) = @as(field.type, @floatFromInt(dyn_field_value.int));
                } else {
                    std.log.err("Not implemented yet, TYPE: {any} {any}", .{ field.type, dyn_field_value });
                    std.log.err("Not implemented yet, TYPE: {any} {any}", .{ field.type, dyn_field_value });
                }
            },
            .bool => {
                if (dyn_field_type == .bool) {
                    @field(new_object, field.name) = dyn_field_value.bool;
                } else {
                    std.log.err("Not implemented yet, TYPE: {any}", .{field.type});
                }
            },
            .@"struct" => {
                if (dyn_field_type == .object) {
                    @field(new_object, field.name) = convertFromDynamicToType(field.type, dyn_field_value.object);
                } else {
                    std.log.err("Not implemented yet, TYPE: {any}", .{field.type});
                }
            },
            else => {},
        }
    }
    return new_object;
}

var current_object: ?*DynamicObject = null;
// Similar for float and bool fields...
pub fn finalizeObject(handle: u32) *DynamicObject {
    const obj = @as(*DynamicObject, @ptrFromInt(@as(usize, @intCast(handle))));
    return obj;
}

// Zig Side - Automatic struct introspection
pub fn FieldDescriptor() type {
    return extern struct {
        name_ptr: [*]const u8,
        name_len: u32,
        offset: u32,
        type_id: u8,
        size: u32,
        can_be_null: bool,
    };
}

pub fn exportStruct(comptime T: type) type {
    return struct {
        pub var instance: T = undefined;
        var descriptors: [@typeInfo(T).@"struct".fields.len]FieldDescriptor() = undefined;

        pub fn init() void {
            const fields = @typeInfo(T).@"struct".fields;
            inline for (fields, 0..) |field, i| {
                descriptors[i] = .{
                    .name_ptr = field.name.ptr,
                    .name_len = field.name.len,
                    .offset = @offsetOf(T, field.name),
                    .type_id = getTypeId(field.type),
                    .size = @sizeOf(getUnderlyingType(field.type)),
                    .can_be_null = @typeInfo(field.type) == .optional,
                };
            }
        }

        pub fn getInstancePtr() [*]const u8 {
            return @ptrCast(&instance);
        }

        pub fn getFieldCount() u32 {
            return @typeInfo(T).@"struct".fields.len;
        }

        pub fn getFieldDescriptor(index: u32) *const FieldDescriptor() {
            return &descriptors[index];
        }

        fn getTypeId(comptime FT: type) u8 {
            return switch (@typeInfo(getUnderlyingType(FT))) {
                .int => |info| if (info.signedness == .unsigned) 1 else 2,
                .float => 3,
                .bool => 4,
                .array => |arr| if (arr.child == u8) 5 else 6,
                .pointer => 7,
                .@"enum" => {
                    return 8;
                },
                else => {
                    return 0;
                },
            };
        }
    };
}
pub const API = struct {
    // --- Dynamic Object Construction ---
    pub fn startObject() callconv(.c) usize {
        current_object = Vapor.allocator_global.create(DynamicObject) catch return 0;
        current_object.?.* = DynamicObject.init(Vapor.allocator_global);
        return @intFromPtr(current_object.?);
    }

    pub fn addStringField(handle: i32, key_ptr: [*:0]u8, value_ptr: [*:0]u8) callconv(.c) void {
        const obj = @as(*DynamicObject, @ptrFromInt(@as(usize, @intCast(handle))));
        const key = std.mem.span(key_ptr);
        const value = std.mem.span(value_ptr);

        obj.fields.append(.{
            .name = key,
            .type = .string,
            .value = .{ .string = value },
        }) catch return;
    }

    pub fn addIntField(handle: i32, key_ptr: [*:0]u8, value: i32) callconv(.c) void {
        const obj = @as(*DynamicObject, @ptrFromInt(@as(usize, @intCast(handle))));
        const key = std.mem.span(key_ptr);

        obj.fields.append(.{
            .name = key,
            .type = .int,
            .value = .{ .int = value },
        }) catch return;
    }

    pub fn addFloatField(handle: i32, key_ptr: [*:0]u8, value: f32) callconv(.c) void {
        const obj = @as(*DynamicObject, @ptrFromInt(@as(usize, @intCast(handle))));
        const key = std.mem.span(key_ptr);

        obj.fields.append(.{
            .name = key,
            .type = .float,
            .value = .{ .float = value },
        }) catch return;
    }

    pub fn addBoolField(handle: i32, key_ptr: [*:0]u8, value: bool) callconv(.c) void {
        const obj = @as(*DynamicObject, @ptrFromInt(@as(usize, @intCast(handle))));
        const key = std.mem.span(key_ptr);

        obj.fields.append(.{
            .name = key,
            .type = .bool,
            .value = .{ .bool = value },
        }) catch return;
    }

    pub fn readObject(callback_ptr: u32, object_ptr: ?*DynamicObject) callconv(.c) void {
        const node = Vapor.ctx_callback_registry.get(callback_ptr) orelse {
            Vapor.printlnSrcErr("Callback not found\n", .{}, @src());
            return;
        };
        node.data.dynamic_object = object_ptr;
        @call(.auto, node.data.runFn, .{&node.data});
        if (Vapor.mode == .atomic) {
            Vapor.cycle();
        }
    }
};

// --- Auto-Export Magic ---
comptime {
    const decls = std.meta.declarations(API);
    for (decls) |decl| {
        // We only care about public functions inside the API struct
        const val = @field(API, decl.name);
        const Type = @TypeOf(val);

        // Check if it is a function
        if (@typeInfo(Type) == .@"fn") {
            // Export it using its declared name
            @export(&val, .{ .name = decl.name });
        }
    }
}
