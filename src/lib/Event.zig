const std = @import("std");
const Vapor = @import("vapor.zig");
const Wasm = Vapor.Wasm;
const isWasi = Vapor.isWasi;
const utils = @import("utils.zig");
const hashKey = utils.hashKey;
const DynamicObject = @import("dynamic.zig");

pub const Event = @This();
id: u32,
type: Vapor.Types.EventType,

/// The key pressed (`KeyboardEvent.key`): "a", "Enter", "ArrowUp", ... Valid
/// for this render; copy it with `Vapor.dupe` to keep it.
pub fn key(evt: *Event) []const u8 {
    const key_str: []const u8 = "key";
    const resp = getEventData(evt.id, key_str.ptr, key_str.len);
    return std.mem.span(resp);
}

/// The kind of edit (`InputEvent.inputType`), e.g. "insertText",
/// "deleteContentBackward".
pub fn inputType(evt: *Event) []const u8 {
    const key_str: []const u8 = "inputType";
    const resp = getEventData(evt.id, key_str.ptr, key_str.len);
    return std.mem.span(resp);
}

/// Whether the Meta (Cmd / Windows) key was held.
pub fn metaKey(evt: *Event) bool {
    const key_str: []const u8 = "metaKey";
    const resp = getEventData(evt.id, key_str.ptr, key_str.len);
    switch (resp[0]) {
        't' => return true,
        'f' => return false,
        else => return false,
    }
}
/// Whether Shift was held.
pub fn shiftKey(evt: *Event) bool {
    const key_str: []const u8 = "shiftKey";
    const resp = getEventData(evt.id, key_str.ptr, key_str.len);
    switch (resp[0]) {
        't' => return true,
        'f' => return false,
        else => return false,
    }
}

/// Whether Control was held.
pub fn ctrlKey(evt: *Event) bool {
    const key_str: []const u8 = "ctrlKey";
    const resp = getEventData(evt.id, key_str.ptr, key_str.len);
    switch (resp[0]) {
        't' => return true,
        'f' => return false,
        else => return false,
    }
}

/// Whether Alt (Option) was held.
pub fn altKey(evt: *Event) bool {
    const key_str: []const u8 = "altKey";
    const resp = getEventData(evt.id, key_str.ptr, key_str.len);
    switch (resp[0]) {
        't' => return true,
        'f' => return false,
        else => return false,
    }
}

/// The target field's current value. Valid for this render; copy it with
/// `Vapor.dupe` to keep it.
pub fn text(evt: *Event) []const u8 {
    const resp = getEventDataInput(evt.id);
    return std.mem.span(resp);
}

/// The target field's value parsed as an `i32`; `error.EmptyString` when empty.
pub fn number(evt: *Event) !i32 {
    const resp = getEventDataInput(evt.id);
    const num_str = std.mem.span(resp);
    if (num_str.len == 0) return error.EmptyString;
    return try std.fmt.parseInt(i32, num_str, 10);
}

/// The target field's value parsed as an `i64`; `error.EmptyString` when empty.
pub fn int64(evt: *Event) !i64 {
    const resp = getEventDataInput(evt.id);
    const num_str = std.mem.span(resp);
    if (num_str.len == 0) return error.EmptyString;
    return try std.fmt.parseInt(i64, num_str, 10);
}

/// The target field's value parsed as an `f32`; `error.EmptyString` when empty.
pub fn float(evt: *Event) !f32 {
    const resp = getEventDataInput(evt.id);
    const num_str = std.mem.span(resp);
    if (num_str.len == 0) return error.EmptyString;
    return try std.fmt.parseFloat(f32, num_str);
}

/// The submitted form's fields as a copy of `form_value.*` with each field
/// filled in from the form control of the same name; `null` if the form is
/// empty. Pass a pointer to a struct whose field names match the controls'
/// `.fieldName(...)`.
pub fn formData(evt: *Event, form_value: anytype) ?@typeInfo(@TypeOf(form_value)).pointer.child {
    if (isWasi) {
        const handle = Wasm.formDataWasm(evt.id);
        const obj = DynamicObject.finalizeObject(handle);

        var cloned_form: @typeInfo(@TypeOf(form_value)).pointer.child = form_value.*;
        const fields = @typeInfo(@TypeOf(cloned_form)).@"struct".fields;
        if (obj.fields.items.len == 0) return null;
        inline for (fields, 0..) |field, i| {
            if (i > obj.fields.items.len - 1) break;
            const obj_value = obj.fields.items[i].value;

            switch (@typeInfo(field.type)) {
                .pointer => |ptr| {
                    if (ptr.size == .slice) {
                        @field(cloned_form, field.name) = obj_value.string;
                    }
                },

                .int => {
                    if (obj_value == .string) {
                        @field(cloned_form, field.name) = std.fmt.parseInt(field.type, obj_value.string, 10) catch |err| blk: {
                            Vapor.printlnErr("Error parsing int field {s} value {s} {any}", .{ field.name, obj_value.string, err });
                            break :blk 0;
                        };
                    } else {
                        @field(cloned_form, field.name) = @intCast(obj_value.int);
                        Vapor.printlnSrcErr("WE NEED TO CHECK THIS SO THAT THE SIGNEDNESS IS OKAY", .{}, @src());
                    }
                },
                .@"struct" => {
                    var section = @field(cloned_form, field.name);
                    fillStruct(field.type, &section, obj);
                    @field(cloned_form, field.name) = section;
                },
                else => {
                    Vapor.printlnErr("Cannot set non string or int float types TYPE", .{});
                },
            }
        }
        return cloned_form;
    }
    return null;
}

/// Helper function to map a DynamicObject to a Zig struct type
fn fillStruct(comptime T: type, cloned_form: *T, obj: *DynamicObject.DynamicObject) void {
    const fields = @typeInfo(T).@"struct".fields;

    var index: usize = 0;
    inline for (fields, 0..) |field, i| {
        // Safety check: ensure we don't out-of-bounds the dynamic object
        if (i >= obj.fields.items.len) break;

        if (@typeInfo(field.type) == .@"struct") continue;

        var obj_field: ?DynamicObject.Field = null;
        for (obj.fields.items, 0..) |item, j| {
            index = j;
            if (std.mem.eql(u8, item.name, field.name)) {
                obj_field = item;
            }
        }

        if (obj_field) |of| {
            const obj_value = of.value;
            switch (@typeInfo(field.type)) {
                .pointer => |ptr| {
                    if (ptr.size == .slice and ptr.child == u8) {
                        @field(cloned_form, field.name) = obj_value.string;
                    } else if (ptr.size == .slice and ptr.child == []const u8) {
                        @field(cloned_form, field.name) = &.{obj_value.string};
                    }
                },
                .int => {
                    if (obj_value == .string) {
                        @field(cloned_form, field.name) = std.fmt.parseInt(field.type, obj_value.string, 10) catch |err| blk: {
                            Vapor.printlnErr("Error parsing int field {s} value {s} {any}", .{ field.name, obj_value.string, err });
                            break :blk 0;
                        };
                    } else {
                        // Added a safety check for signedness/bounds as requested
                        @field(cloned_form, field.name) = @intCast(obj_value.int);
                    }
                },
                .float => {
                    // Handling floats since they are common in forms
                    @field(cloned_form, field.name) = if (obj_value == .float) obj_value.float else 0;
                },
                .@"enum" => {
                    std.log.info("Enum: {any}", .{obj_value});
                },
                .@"struct" => {},
                else => {
                    Vapor.printlnErr("Cannot set unsupported type for field {s}: {any}", .{ field.name, field.type });
                },
            }
        } else {
            std.log.warn("Field {s} not found in DynamicObject instead found {s}\n", .{ field.name, obj.fields.items[index].name });
        }
    }
}

/// Stops the browser's default action, e.g. a form submission reloading the
/// page.
pub fn preventDefault(evt: *Event) void {
    if (isWasi) {
        Wasm.eventPreventDefault(evt.id);
    }
}

/// Stops the event reaching handlers on parent elements.
pub fn stopPropagation(evt: *Event) void {
    if (isWasi) {
        Wasm.eventStopPropagation(evt.id);
    }
}

/// The target's vertical scroll offset in pixels.
pub fn scrollTop(evt: *Event) f32 {
    const key_str: []const u8 = "scrollTop";
    return getEventDataNumber(evt.id, key_str.ptr, key_str.len);
}

/// Pointer x in pixels, relative to the viewport.
pub fn clientX(evt: *Event) f32 {
    const key_str: []const u8 = "clientX";
    return getEventDataNumber(evt.id, key_str.ptr, key_str.len);
}

/// Pointer y in pixels, relative to the viewport.
pub fn clientY(evt: *Event) f32 {
    const key_str: []const u8 = "clientY";
    return getEventDataNumber(evt.id, key_str.ptr, key_str.len);
}

/// Pointer x in pixels, relative to the target element.
pub fn offsetX(evt: *Event) f32 {
    const key_str: []const u8 = "offsetX";
    return getEventDataNumber(evt.id, key_str.ptr, key_str.len);
}

/// Pointer y in pixels, relative to the target element.
pub fn offsetY(evt: *Event) f32 {
    const key_str: []const u8 = "offsetY";
    return getEventDataNumber(evt.id, key_str.ptr, key_str.len);
}

/// Pointer x in pixels, relative to the whole page.
pub fn pageX(evt: *Event) f32 {
    const key_str: []const u8 = "pageX";
    return getEventDataNumber(evt.id, key_str.ptr, key_str.len);
}

/// Pointer y in pixels, relative to the whole page.
pub fn pageY(evt: *Event) f32 {
    const key_str: []const u8 = "pageY";
    return getEventDataNumber(evt.id, key_str.ptr, key_str.len);
}

pub const ScrollIntoViewOptions = struct {
    behavior: ScrollBehavior = .auto,
    block: ScrollBlock = .start,
};

pub const ScrollBehavior = enum(u8) {
    auto,
    smooth,
    instant,
};

pub const ScrollBlock = enum(u8) {
    start,
    center,
    end,
    nearest,
};

/// Scrolls the element with id `uuid` into view.
pub fn scrollIntoView(uuid: []const u8, options: ScrollIntoViewOptions) void {
    if (Vapor.isWasi) {
        Wasm.scrollIntoViewWasm(uuid.ptr, uuid.len, options.behavior, options.block);
    }
}

/// Pointer movement in x since the previous move event, in pixels.
pub fn movementX(evt: *Event) f32 {
    const key_str: []const u8 = "movementX";
    if (Vapor.isWasi) {
        return getEventDataNumber(evt.id, key_str.ptr, key_str.len);
    }
    return 0;
}

/// Pointer movement in y since the previous move event, in pixels.
pub fn movementY(evt: *Event) f32 {
    const key_str: []const u8 = "movementY";
    if (Vapor.isWasi) {
        return getEventDataNumber(evt.id, key_str.ptr, key_str.len);
    }
    return 0;
}

// Static buffers for the dummy returns
var dummy_string_buffer: [256:0]u8 = undefined;
/// Internal: reads the named property of event `id` from the runtime.
pub fn getEventData(id: u32, ptr: [*]const u8, len: u32) [*:0]u8 {
    if (isWasi) {
        return Wasm.getEventDataWasm(id, ptr, len);
    } else {
        // Dummy implementation - return empty string
        @memset(dummy_string_buffer[0..dummy_string_buffer.len], 0);
        const dummy_value = "dummy_event_data";
        @memcpy(dummy_string_buffer[0..dummy_value.len], dummy_value);
        return &dummy_string_buffer;
    }
}

/// Internal: reads the value of event `id`'s target from the runtime.
pub fn getEventDataInput(id: u32) [*:0]u8 {
    if (isWasi) {
        return Wasm.getEventDataInputWasm(id);
    } else {
        // Dummy implementation - return empty string
        @memset(dummy_string_buffer[0..dummy_string_buffer.len], 0);
        const dummy_value = "dummy_input_value";
        @memcpy(dummy_string_buffer[0..dummy_value.len], dummy_value);
        return &dummy_string_buffer;
    }
}

/// Internal: reads the named numeric property of event `id` from the runtime.
pub fn getEventDataNumber(id: u32, ptr: [*]const u8, len: u32) f32 {
    if (isWasi) {
        return Wasm.getEventDataNumberWasm(id, ptr, len);
    } else {
        // Dummy implementation - return 0.0
        return 0.0;
    }
}

export fn registerAllListenerCallbacks() void {
    if (!isWasi) return;
    var evt_itr = Vapor.nodes_with_events.iterator();
    while (evt_itr.next()) |entry| {
        const ui_node = entry.value_ptr.*;
        if (ui_node.event_handlers) |handlers| {
            for (handlers.handlers.items) |handler| {
                if (handler.event_type == .submit or handler.event_type == .mouseover or handler.event_type == .mouseout) {
                    continue;
                }
                // The runtime's root listener already delivers these for text
                // fields (focusin/focusout/input); a direct listener would
                // dispatch each event twice.
                const text_input = ui_node.type == .TextField or ui_node.type == .TextArea;
                if (text_input and (handler.event_type == .focus or handler.event_type == .blur or handler.event_type == .input)) {
                    continue;
                }

                const event_type_str = std.enums.tagName(Vapor.Types.EventType, handler.event_type) orelse unreachable;
                var callback_id = hashKey(ui_node.uuid);
                callback_id +%= @intFromEnum(handler.event_type);
                Wasm.createElementEventListener(ui_node.uuid.ptr, ui_node.uuid.len, event_type_str.ptr, event_type_str.len, callback_id);
            }
        }
    }
}
