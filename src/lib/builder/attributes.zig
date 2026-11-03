//! ComponentBuilder methods for ids and attributes: `.id`, ARIA, `.hidden`,
//! `.attribute`.
//! Declared and documented as inline methods on ComponentBuilder
//! (components.zig), so editors complete their arguments; those call these.

const Components = @import("../components.zig");
const Self = Components.ComponentBuilder;
const std = @import("std");
const Vapor = @import("../vapor.zig");
const Accessibility = @import("../accessibility.zig").Accessibility;
const types = @import("../types.zig");

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

pub fn attribute(self: *const Self, attribute_name: []const u8, value: []const u8) Self {
    var n = self.*;
    if (!allowedAttribute(attribute_name)) {
        Vapor.report.err(".attribute(\"{s}\", ...) is not allowed; see ComponentBuilder.attribute", .{attribute_name});
        return n;
    }
    const previous = n._attributes orelse &.{};
    const list = Vapor.arena(.frame).alloc(types.Attribute, previous.len + 1) catch |err| {
        Vapor.report.err(".attribute: could not allocate, \"{s}\" skipped: {any}", .{ attribute_name, err });
        return n;
    };
    @memcpy(list[0..previous.len], previous);
    list[previous.len] = .{ .name = attribute_name, .value = value };
    n._attributes = list;
    return n;
}

/// Whether `name` is a valid attribute name vapor doesn't write itself.
/// Event handlers (on*) would run script, and id, class, style, href and
/// src have their own builder calls, which escape and check them.
pub fn allowedAttribute(name: []const u8) bool {
    if (name.len == 0) return false;
    for (name, 0..) |c, i| {
        const ok = std.ascii.isAlphabetic(c) or c == '_' or c == ':' or
            (i > 0 and (std.ascii.isDigit(c) or c == '-' or c == '.'));
        if (!ok) return false;
    }
    if (name.len >= 2 and std.ascii.eqlIgnoreCase(name[0..2], "on")) return false;
    for ([_][]const u8{ "id", "class", "style", "href", "src" }) |owned| {
        if (std.ascii.eqlIgnoreCase(name, owned)) return false;
    }
    return true;
}

test allowedAttribute {
    try std.testing.expect(allowedAttribute("data-kind"));
    try std.testing.expect(allowedAttribute("title"));
    try std.testing.expect(allowedAttribute("xml:lang"));
    try std.testing.expect(!allowedAttribute(""));
    try std.testing.expect(!allowedAttribute("onclick"));
    try std.testing.expect(!allowedAttribute("ONLOAD"));
    try std.testing.expect(!allowedAttribute("style"));
    try std.testing.expect(!allowedAttribute("href"));
    try std.testing.expect(!allowedAttribute("data kind"));
    try std.testing.expect(!allowedAttribute("a\"b"));
    try std.testing.expect(!allowedAttribute("-x"));
}
