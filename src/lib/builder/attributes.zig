//! ComponentBuilder methods for ids and attributes: `.id`, ARIA, `.hidden`,
//! `.attribute`. Aliased from components.zig.

const Components = @import("../components.zig");
const Self = Components.ComponentBuilder;
const std = @import("std");
const Vapor = @import("../vapor.zig");
const Accessibility = @import("../accessibility.zig").Accessibility;

/// All accessibility attributes at once; see `Vapor.Accessibility`.
pub fn a11y(self: *const Self, accessibility: Accessibility) Self {
    var n = self.*;
    n._accessibility = accessibility;
    return n;
}

/// Accessible name for screen readers (`aria-label`).
pub fn ariaLabel(self: *const Self, label: []const u8) Self {
    var n = self.*;
    var acc = n._accessibility orelse Accessibility{};
    acc.label = label;
    n._accessibility = acc;
    return n;
}

/// ARIA role, e.g. `.button`, `.dialog`.
pub fn role(self: *const Self, r: Accessibility.Role) Self {
    var n = self.*;
    var acc = n._accessibility orelse Accessibility{};
    acc.role = r;
    n._accessibility = acc;
    return n;
}

/// Whether the control's popup or section is open (`aria-expanded`).
pub fn ariaExpanded(self: *const Self, expanded: bool) Self {
    var n = self.*;
    var acc = n._accessibility orelse Accessibility{};
    acc.expanded = expanded;
    n._accessibility = acc;
    return n;
}

/// Whether the item is selected (`aria-selected`).
pub fn ariaSelected(self: *const Self, selected: bool) Self {
    var n = self.*;
    var acc = n._accessibility orelse Accessibility{};
    acc.selected = selected;
    n._accessibility = acc;
    return n;
}

/// Id of the element this one controls (`aria-controls`).
pub fn ariaControls(self: *const Self, uuid: []const u8) Self {
    var n = self.*;
    var acc = n._accessibility orelse Accessibility{};
    acc.controls = uuid;
    n._accessibility = acc;
    return n;
}

/// Id of the focused descendant in a composite widget
/// (`aria-activedescendant`). `null` clears it.
pub fn ariaActiveDescendant(self: *const Self, uuid: ?[]const u8) Self {
    var n = self.*;
    var acc = n._accessibility orelse Accessibility{};
    acc.active_descendant = uuid;
    n._accessibility = acc;
    return n;
}

/// Hides the element from assistive technology (`aria-hidden`).
pub fn ariaHidden(self: *const Self, hidden_val: bool) Self {
    var n = self.*;
    var acc = n._accessibility orelse Accessibility{};
    acc.hidden = hidden_val;
    n._accessibility = acc;
    return n;
}

/// Tab order: 0 joins the normal order, -1 makes it focusable only from code.
pub fn tabIndex(self: *const Self, index: i16) Self {
    var n = self.*;
    var acc = n._accessibility orelse Accessibility{};
    acc.tab_index = index;
    n._accessibility = acc;
    return n;
}

/// The form field name (`name` attribute) a `Form` submits it under.
pub fn fieldName(self: *const Self, name: []const u8) Self {
    var n = self.*;
    n._name = name;
    return n;
}

/// Uses the text as given instead of copying it. Only for strings that outlive
/// the page, such as literals and globals.
pub fn unmanaged(self: *const Self) Self {
    var n = self.*;
    n._persisted_text = false;
    return n;
}

/// Leaves the element out of the layout (`display: none`) while `is_hidden` is
/// true. Unlike `.hide`, this works on every render, the first included.
pub fn hidden(self: *const Self, is_hidden: bool) Self {
    var n = self.*;
    if (!is_hidden) return n;
    n._flex_type = .hidden;
    return n;
}

/// Gives the element a stable identity.
///
/// The generated uuid encodes the child's position, so an element that
/// moves is seen by the reconciler as a delete plus an insert. Anything in
/// a list that can reorder, or that sits after a conditionally-rendered
/// sibling, wants an id — it is what keeps the node itself alive across the
/// move. The value also becomes the element's DOM id.
pub fn id(self: *const Self, element_id: []const u8) Self {
    var n = self.*;
    n._id = element_id;
    Vapor.assignUserId(n._ui_node.?, element_id);
    return n;
}

/// Gives the element an id made from a source location: `.src(@src())`.
pub fn src(self: *const Self, source_location: std.builtin.SourceLocation) Self {
    var n = self.*;
    n._id = Vapor.frame.fmt("{s}-{d}", .{ source_location.file, source_location.line });
    Vapor.assignUserId(n._ui_node.?, n._id.?);
    return n;
}

/// Makes this element the CSS anchor named `name`, for elements positioned
/// with `anchorPlacement`.
pub fn anchorSource(self: *const Self, name: []const u8) Self {
    var n = self.*;
    n._anchor = name;
    return n;
}

/// Sets the DOM attribute `attribute_name` once the element is on the page. Both
/// strings must stay valid until then (literals, or frame allocations).
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
