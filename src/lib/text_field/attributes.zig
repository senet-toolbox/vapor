const TextFieldMod = @import("../TextField.zig");
const Self = TextFieldMod.TextFieldBuilder;
const Vapor = @import("../Vapor.zig");
const Accessibility = @import("../Accessibility.zig").Accessibility;

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
