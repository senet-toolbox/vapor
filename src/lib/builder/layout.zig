//! ComponentBuilder methods for layout and size: `.padding`, `.size`,
//! `.direction`, `.responsive`, ... Aliased from components.zig.

const Components = @import("../components.zig");
const Self = Components.ComponentBuilder;
const types = @import("../types.zig");
const Vapor = @import("../vapor.zig");

/// Draws the edge lines registered under `edges_tag` (see `Vapor.Edges`). `null`
/// leaves the element unchanged.
pub fn edges(self: *const Self, edges_tag: ?[]const u8) Self {
    if (edges_tag) |_edges| {
        var n = self.*;
        n._edges = _edges;
        return n;
    }
    return self.*;
}

/// Fixes the element's width-to-height ratio.
pub fn aspectRatio(self: *const Self, ratio: types.AspectRatio) Self {
    var n = self.*;
    n._aspect_ratio = ratio;
    return n;
}

/// Overflow behaviour on each axis, e.g. `.scroll(.{ .y = .scroll })`.
pub fn scroll(self: *const Self, scroll_type: types.Scroll) Self {
    var n = self.*;
    n._scroll = scroll_type;
    return n;
}

/// Whether a scrolling element shows its scroll bar.
pub fn showScrollBar(self: *const Self, show: bool) Self {
    var n = self.*;
    n._show_scrollbar = show;
    return n;
}

/// Positioning: `.pos(.{ .type = .absolute, .top = .px(0), .right = .px(0) })`.
/// Keeps a z-index set with `zIndex`.
pub fn pos(self: *const Self, position: types.Position) Self {
    var n = self.*;
    var p = n._pos orelse types.Position{};
    p.top = position.top;
    p.right = position.right;
    p.bottom = position.bottom;
    p.left = position.left;
    p.type = position.type;
    n._pos = p;
    return n;
}

/// Stacking order. `null` removes it.
pub fn zIndex(self: *const Self, z_index: ?i16) Self {
    var n = self.*;
    var p = n._pos orelse types.Position{};
    p.z_index = z_index;
    n._pos = p;
    return n;
}

/// How children are aligned on both axes, e.g. `.layout(.center)`.
pub fn layout(self: *const Self, value: types.Layout) Self {
    var n = self.*;
    n._layout = value;
    return n;
}

/// Where to place this element relative to its CSS anchor (see `Anchor`).
pub fn placement(self: *const Self, value: types.AnchorPlacement) Self {
    var n = self.*;
    n._placement = value;
    return n;
}

/// Centres the children on both axes. Same as `.layout(.center)`.
pub fn center(self: *const Self) Self {
    var n = self.*;
    n._layout = .center;
    return n;
}

/// Whether children wrap onto new lines when they do not fit.
pub fn wrap(self: *const Self, value: types.FlexWrap) Self {
    var n = self.*;
    n._flex_wrap = value;
    return n;
}

/// Gap between children, in pixels.
pub fn spacing(self: *const Self, value: u8) Self {
    var n = self.*;
    n._child_gap = value;
    const node = self._ui_node orelse {
        Vapor.printlnSrcErr("Node is null", .{}, @src());
        return self.*;
    };
    node.spacing = value;
    return n;
}

/// Inner spacing: `.padding(.all(16))`, `.padding(.tb(8, 4))`, ...
pub fn padding(self: *const Self, value: types.Padding) Self {
    var n = self.*;
    n._padding = value;
    return n;
}

/// Left padding in pixels; keeps the other sides.
pub fn pl(self: *const Self, value: u8) Self {
    var n = self.*;
    if (n._padding == null) n._padding = .{};
    n._padding.?.left = value;
    return n;
}

/// Right padding in pixels; keeps the other sides.
pub fn pr(self: *const Self, value: u8) Self {
    var n = self.*;
    if (n._padding == null) n._padding = .{};
    n._padding.?.right = value;
    return n;
}

/// Top padding in pixels; keeps the other sides.
pub fn pt(self: *const Self, value: u8) Self {
    var n = self.*;
    if (n._padding == null) n._padding = .{};
    n._padding.?.top = value;
    return n;
}

/// Bottom padding in pixels; keeps the other sides.
pub fn pb(self: *const Self, value: u8) Self {
    var n = self.*;
    if (n._padding == null) n._padding = .{};
    n._padding.?.bottom = value;
    return n;
}

/// Top margin in pixels (negative allowed); keeps the other sides.
pub fn mt(self: *const Self, value: i16) Self {
    var n = self.*;
    if (n._margin == null) n._margin = .{};
    n._margin.?.top = value;
    return n;
}

/// Bottom margin in pixels (negative allowed); keeps the other sides.
pub fn mb(self: *const Self, value: i16) Self {
    var n = self.*;
    if (n._margin == null) n._margin = .{};
    n._margin.?.bottom = value;
    return n;
}

/// Left margin in pixels (negative allowed); keeps the other sides.
pub fn ml(self: *const Self, value: i16) Self {
    var n = self.*;
    if (n._margin == null) n._margin = .{};
    n._margin.?.left = value;
    return n;
}

/// Right margin in pixels (negative allowed); keeps the other sides.
pub fn mr(self: *const Self, value: i16) Self {
    var n = self.*;
    if (n._margin == null) n._margin = .{};
    n._margin.?.right = value;
    return n;
}

/// Top and bottom margin in pixels.
pub fn my(self: *const Self, value: i16) Self {
    var n = self.*;
    if (n._margin == null) n._margin = .{};
    n._margin.?.top = value;
    n._margin.?.bottom = value;
    return n;
}

/// Left and right margin in pixels.
pub fn mx(self: *const Self, value: i16) Self {
    var n = self.*;
    if (n._margin == null) n._margin = .{};
    n._margin.?.left = value;
    n._margin.?.right = value;
    return n;
}

/// Outer spacing: `.margin(.all(8))`, ...
pub fn margin(self: *const Self, value: types.Margin) Self {
    var n = self.*;
    n._margin = value;
    return n;
}

/// Style overrides for one screen size: mobile below 768px, tablet from 768px,
/// desktop from 1024px. Call once per platform.
pub fn responsive(self: *const Self, platform: types.Platform, responsive_style: types.ResponsiveStyle) Self {
    var new_self = self.*;
    var responsive_val = self._responsive orelse blk: {
        break :blk types.Responsive{};
    };
    switch (platform) {
        .mobile => {
            responsive_val.mobile = responsive_style;
        },
        .desktop => {
            responsive_val.desktop = responsive_style;
        },
        .tablet => {
            responsive_val.tablet = responsive_style;
        },
    }
    new_self._responsive = responsive_val;
    return new_self;
}

/// Width and height together: `.size(.full)`, `.size(.squarePx(48))`.
pub fn size(self: *const Self, dim: types.Size) Self {
    var n = self.*;
    n._size = dim;
    return n;
}

/// Height, then width.
pub fn hw(self: *const Self, height_value: types.Sizing, width_value: types.Sizing) Self {
    var n = self.*;
    if (n._size == null) {
        n._size = .{ .width = width_value, .height = height_value };
    } else {
        n._size.?.width = width_value;
        n._size.?.height = height_value;
    }
    return n;
}

/// Width: `.width(.px(320))`, `.width(.percent(50))`, `.width(.expand)` (fill the
/// available space), ...
pub fn width(self: *const Self, length: types.Sizing) Self {
    var n = self.*;
    if (n._size == null) {
        n._size = .{ .width = length };
    } else {
        n._size.?.width = length;
    }
    return n;
}

/// Minimum width. Only `.px` and `.percent` sizes are supported; others are
/// ignored.
pub fn minWidth(self: *const Self, min: types.Sizing) Self {
    var n = self.*;
    const sizing: types.Sizing = switch (min.type) {
        .percent => .{ .type = .min_percent, .size = min.size },
        .fixed => .{ .type = .min_px, .size = min.size },
        else => {
            Vapor.printlnErr("minWidth: only .percent and .px sizes are supported; ignored", .{});
            return self.*;
        },
    };
    if (n._size == null) {
        n._size = .{ .width = sizing };
    } else {
        n._size.?.width = sizing;
    }
    return n;
}

/// Maximum width. Only `.px` and `.percent` sizes are supported; others are
/// ignored.
pub fn maxWidth(self: *const Self, max: types.Sizing) Self {
    var n = self.*;
    const sizing: types.Sizing = switch (max.type) {
        .percent => .{ .type = .max_percent, .size = max.size },
        .fixed => .{ .type = .max_px, .size = max.size },
        else => {
            Vapor.printlnErr("maxWidth: only .percent and .px sizes are supported; ignored", .{});
            return self.*;
        },
    };
    if (n._size == null) {
        n._size = .{ .width = sizing };
    } else {
        n._size.?.width = sizing;
    }
    return n;
}

/// Height, with the same sizes as `width`.
pub fn height(self: *const Self, length: types.Sizing) Self {
    var n = self.*;
    if (n._size == null) {
        n._size = .{ .height = length };
    } else {
        n._size.?.height = length;
    }
    return n;
}

/// Minimum height. Only `.px` and `.percent` sizes are supported; others are
/// ignored.
pub fn minHeight(self: *const Self, min: types.Sizing) Self {
    var n = self.*;
    const sizing: types.Sizing = switch (min.type) {
        .percent => .{ .type = .min_percent, .size = min.size },
        .fixed => .{ .type = .min_px, .size = min.size },
        else => {
            Vapor.printlnErr("minHeight: only .percent and .px sizes are supported; ignored", .{});
            return self.*;
        },
    };
    if (n._size == null) {
        n._size = .{ .height = sizing };
    } else {
        n._size.?.height = sizing;
    }
    return n;
}

/// Maximum height. Only `.px` and `.percent` sizes are supported; others are
/// ignored.
pub fn maxHeight(self: *const Self, max: types.Sizing) Self {
    var n = self.*;
    const sizing: types.Sizing = switch (max.type) {
        .percent => .{ .type = .max_percent, .size = max.size },
        .fixed => .{ .type = .max_px, .size = max.size },
        else => {
            Vapor.printlnErr("maxHeight: only .percent and .px sizes are supported; ignored", .{});
            return self.*;
        },
    };
    if (n._size == null) {
        n._size = .{ .height = sizing };
    } else {
        n._size.?.height = sizing;
    }
    return n;
}

/// Lays children out `column_count` to a row: a child with a percentage width
/// takes that share of the row, less its part of the `spacing`.
pub fn columns(self: *const Self, column_count: u8) *const Self {
    const node = self._ui_node orelse {
        Vapor.printlnSrcErr("Node is null", .{}, @src());
        return self;
    };
    node.column_count = column_count;
    return self;
}

/// Main axis for the children: `.row` or `.column`.
pub fn direction(self: *const Self, value: types.Direction) Self {
    var n = self.*;
    n._direction = value;
    self._ui_node.?.direction = value;
    return n;
}
