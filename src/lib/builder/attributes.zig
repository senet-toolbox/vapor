//! ComponentBuilder methods for ids and attributes: `.id`, ARIA, `.hidden`,
//! `.attribute`.
//! Declared and documented as inline methods on ComponentBuilder
//! (components.zig), so editors complete their arguments; those call these.

const Components = @import("../components.zig");
const Self = Components.ComponentBuilder;
const std = @import("std");
const Vapor = @import("../vapor.zig");
const Accessibility = @import("../accessibility.zig").Accessibility;

pub fn a11y(self: *const Self, accessibility: Accessibility) Self {
    var n = self.*;
    n._accessibility = accessibility;
    return n;
}

pub fn ariaLabel(self: *const Self, label: []const u8) Self {
    var n = self.*;
    var acc = n._accessibility orelse Accessibility{};
    acc.label = label;
    n._accessibility = acc;
    return n;
}

pub fn role(self: *const Self, r: Accessibility.Role) Self {
    var n = self.*;
    var acc = n._accessibility orelse Accessibility{};
    acc.role = r;
    n._accessibility = acc;
    return n;
}

pub fn ariaExpanded(self: *const Self, expanded: bool) Self {
    var n = self.*;
    var acc = n._accessibility orelse Accessibility{};
    acc.expanded = expanded;
    n._accessibility = acc;
    return n;
}

pub fn ariaSelected(self: *const Self, selected: bool) Self {
    var n = self.*;
    var acc = n._accessibility orelse Accessibility{};
    acc.selected = selected;
    n._accessibility = acc;
    return n;
}

pub fn ariaControls(self: *const Self, uuid: []const u8) Self {
    var n = self.*;
    var acc = n._accessibility orelse Accessibility{};
    acc.controls = uuid;
    n._accessibility = acc;
    return n;
}

pub fn ariaActiveDescendant(self: *const Self, uuid: ?[]const u8) Self {
    var n = self.*;
    var acc = n._accessibility orelse Accessibility{};
    acc.active_descendant = uuid;
    n._accessibility = acc;
    return n;
}

pub fn ariaHidden(self: *const Self, hidden_val: bool) Self {
    var n = self.*;
    var acc = n._accessibility orelse Accessibility{};
    acc.hidden = hidden_val;
    n._accessibility = acc;
    return n;
}

pub fn tabIndex(self: *const Self, index: i16) Self {
    var n = self.*;
    var acc = n._accessibility orelse Accessibility{};
    acc.tab_index = index;
    n._accessibility = acc;
    return n;
}

pub fn fieldName(self: *const Self, name: []const u8) Self {
    var n = self.*;
    n._name = name;
    return n;
}

pub fn unmanaged(self: *const Self) Self {
    var n = self.*;
    n._persisted_text = false;
    return n;
}

pub fn hidden(self: *const Self, is_hidden: bool) Self {
    var n = self.*;
    if (!is_hidden) return n;
    n._flex_type = .hidden;
    return n;
}

pub fn id(self: *const Self, element_id: []const u8) Self {
    var n = self.*;
    n._id = element_id;
    Vapor.assignUserId(n._ui_node.?, element_id);
    return n;
}

pub fn src(self: *const Self, source_location: std.builtin.SourceLocation) Self {
    var n = self.*;
    n._id = Vapor.frame.fmt("{s}-{d}", .{ source_location.file, source_location.line });
    Vapor.assignUserId(n._ui_node.?, n._id.?);
    return n;
}

pub fn anchorSource(self: *const Self, name: []const u8) Self {
    var n = self.*;
    n._anchor = name;
    return n;
}

pub fn attribute(self: *const Self, attribute_name: []const u8, value: []const u8) *const Self {
    const ui_node = self._ui_node orelse {
        Vapor.report.err("Node is null", .{});
        @panic("vapor: Node is null");
    };

    const uuid = ui_node.uuid;
    if (Vapor.isWasi) {
        Vapor.onLayout(Vapor.Wasm.setAttributeWasm, .{ uuid.ptr, uuid.len, attribute_name.ptr, attribute_name.len, value.ptr, value.len });
        // Vapor.Wasm.setAttributeWasm(uuid.ptr, uuid.len, attribute.ptr, attribute.len, value.ptr, value.len);
    }
    return self;
}
