//! TextFieldBuilder methods for ids and ARIA attributes.
//! Declared and documented as inline methods on TextFieldBuilder
//! (text_field.zig), so editors complete their arguments; those call these.

const TextFieldMod = @import("../text_field.zig");
const Self = TextFieldMod.TextFieldBuilder;
const Vapor = @import("../vapor.zig");
const Accessibility = @import("../accessibility.zig").Accessibility;

pub fn id(self: *const Self, element_id: []const u8) Self {
    var new_self: Self = self.*;
    new_self._id = element_id;
    if (new_self._ui_node) |node| Vapor.assignUserId(node, element_id);
    return new_self;
}

pub fn a11y(self: *const Self, accessibility: Accessibility) Self {
    var new_self: Self = self.*;
    new_self._accessibility = accessibility;
    return new_self;
}

pub fn ariaLabel(self: *const Self, label: []const u8) Self {
    var new_self: Self = self.*;
    var acc = new_self._accessibility orelse Accessibility{};
    acc.label = label;
    new_self._accessibility = acc;
    return new_self;
}

pub fn role(self: *const Self, r: Accessibility.Role) Self {
    var new_self: Self = self.*;
    var acc = new_self._accessibility orelse Accessibility{};
    acc.role = r;
    new_self._accessibility = acc;
    return new_self;
}

pub fn ariaExpanded(self: *const Self, expanded: bool) Self {
    var new_self: Self = self.*;
    var acc = new_self._accessibility orelse Accessibility{};
    acc.expanded = expanded;
    new_self._accessibility = acc;
    return new_self;
}

pub fn ariaSelected(self: *const Self, selected: bool) Self {
    var new_self: Self = self.*;
    var acc = new_self._accessibility orelse Accessibility{};
    acc.selected = selected;
    new_self._accessibility = acc;
    return new_self;
}

pub fn ariaControls(self: *const Self, uuid: []const u8) Self {
    var new_self: Self = self.*;
    var acc = new_self._accessibility orelse Accessibility{};
    acc.controls = uuid;
    new_self._accessibility = acc;
    return new_self;
}

pub fn ariaActiveDescendant(self: *const Self, uuid: ?[]const u8) Self {
    var new_self: Self = self.*;
    var acc = new_self._accessibility orelse Accessibility{};
    acc.active_descendant = uuid;
    new_self._accessibility = acc;
    return new_self;
}

pub fn ariaHidden(self: *const Self, hidden_val: bool) Self {
    var new_self: Self = self.*;
    var acc = new_self._accessibility orelse Accessibility{};
    acc.hidden = hidden_val;
    new_self._accessibility = acc;
    return new_self;
}

pub fn tabIndex(self: *const Self, index: i16) Self {
    var new_self: Self = self.*;
    var acc = new_self._accessibility orelse Accessibility{};
    acc.tab_index = index;
    new_self._accessibility = acc;
    return new_self;
}
