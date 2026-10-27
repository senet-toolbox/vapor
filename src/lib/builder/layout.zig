//! ComponentBuilder methods for layout and size: `.padding`, `.size`,
//! `.direction`, `.responsive`, ...
//! Declared and documented as inline methods on ComponentBuilder
//! (components.zig), so editors complete their arguments; those call these.

const Components = @import("../components.zig");
const Self = Components.ComponentBuilder;
const types = @import("../types.zig");
const Vapor = @import("../vapor.zig");

pub fn edges(self: *const Self, edges_tag: ?[]const u8) Self {
    if (edges_tag) |_edges| {
        var n = self.*;
        n._edges = _edges;
        return n;
    }
    return self.*;
}

pub fn aspectRatio(self: *const Self, ratio: types.AspectRatio) Self {
    var n = self.*;
    n._aspect_ratio = ratio;
    return n;
}

pub fn scroll(self: *const Self, scroll_type: types.Scroll) Self {
    var n = self.*;
    n._scroll = scroll_type;
    return n;
}

pub fn showScrollBar(self: *const Self, show: bool) Self {
    var n = self.*;
    n._show_scrollbar = show;
    return n;
}

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

pub fn zIndex(self: *const Self, z_index: ?i16) Self {
    var n = self.*;
    var p = n._pos orelse types.Position{};
    p.z_index = z_index;
    n._pos = p;
    return n;
}

pub fn layout(self: *const Self, value: types.Layout) Self {
    var n = self.*;
    n._layout = value;
    return n;
}

pub fn placement(self: *const Self, value: types.AnchorPlacement) Self {
    var n = self.*;
    n._placement = value;
    return n;
}

pub fn center(self: *const Self) Self {
    var n = self.*;
    n._layout = .center;
    return n;
}

pub fn wrap(self: *const Self, value: types.FlexWrap) Self {
    var n = self.*;
    n._flex_wrap = value;
    return n;
}

pub fn spacing(self: *const Self, value: u8) Self {
    var n = self.*;
    n._child_gap = value;
    const node = self._ui_node orelse {
        Vapor.report.err("Node is null", .{});
        return self.*;
    };
    node.spacing = value;
    return n;
}

pub fn padding(self: *const Self, value: types.Padding) Self {
    var n = self.*;
    n._padding = value;
    return n;
}

pub fn pl(self: *const Self, value: u8) Self {
    var n = self.*;
    if (n._padding == null) n._padding = .{};
    n._padding.?.left = value;
    return n;
}

pub fn pr(self: *const Self, value: u8) Self {
    var n = self.*;
    if (n._padding == null) n._padding = .{};
    n._padding.?.right = value;
    return n;
}

pub fn pt(self: *const Self, value: u8) Self {
    var n = self.*;
    if (n._padding == null) n._padding = .{};
    n._padding.?.top = value;
    return n;
}

pub fn pb(self: *const Self, value: u8) Self {
    var n = self.*;
    if (n._padding == null) n._padding = .{};
    n._padding.?.bottom = value;
    return n;
}

pub fn padX(self: *const Self, value: u8) Self {
    var n = self.*;
    if (n._padding == null) n._padding = .{};
    n._padding.?.left = value;
    n._padding.?.right = value;
    return n;
}

pub fn padY(self: *const Self, value: u8) Self {
    var n = self.*;
    if (n._padding == null) n._padding = .{};
    n._padding.?.top = value;
    n._padding.?.bottom = value;
    return n;
}

pub fn mt(self: *const Self, value: i16) Self {
    var n = self.*;
    if (n._margin == null) n._margin = .{};
    n._margin.?.top = value;
    return n;
}

pub fn mb(self: *const Self, value: i16) Self {
    var n = self.*;
    if (n._margin == null) n._margin = .{};
    n._margin.?.bottom = value;
    return n;
}

pub fn ml(self: *const Self, value: i16) Self {
    var n = self.*;
    if (n._margin == null) n._margin = .{};
    n._margin.?.left = value;
    return n;
}

pub fn mr(self: *const Self, value: i16) Self {
    var n = self.*;
    if (n._margin == null) n._margin = .{};
    n._margin.?.right = value;
    return n;
}

pub fn my(self: *const Self, value: i16) Self {
    var n = self.*;
    if (n._margin == null) n._margin = .{};
    n._margin.?.top = value;
    n._margin.?.bottom = value;
    return n;
}

pub fn mx(self: *const Self, value: i16) Self {
    var n = self.*;
    if (n._margin == null) n._margin = .{};
    n._margin.?.left = value;
    n._margin.?.right = value;
    return n;
}

pub fn margin(self: *const Self, value: types.Margin) Self {
    var n = self.*;
    n._margin = value;
    return n;
}

pub fn responsive(self: *const Self, platform: types.Platform, responsive_style: types.ResponsiveStyle) Self {
    var new_self = self.*;
    var responsive_val = self._responsive orelse blk: {
        break :blk types.Responsive{};
    };
    const slot = responsiveSlot(&responsive_val, platform);
    var style = responsive_style;
    // Keeps a display `.hideOn`/`.showOn` set, whichever is called first.
    if (style.flex_type == null) {
        if (slot.*) |previous| style.flex_type = previous.flex_type;
    }
    slot.* = style;
    new_self._responsive = responsive_val;
    return new_self;
}

fn responsiveSlot(r: *types.Responsive, platform: types.Platform) *?types.ResponsiveStyle {
    return switch (platform) {
        .mobile => &r.mobile,
        .tablet => &r.tablet,
        .desktop => &r.desktop,
    };
}

fn displayOn(self: *const Self, platform: types.Platform, flex_type: types.FlexType) Self {
    var n = self.*;
    var r = n._responsive orelse types.Responsive{};
    const slot = responsiveSlot(&r, platform);
    var style = slot.* orelse types.ResponsiveStyle{};
    style.flex_type = flex_type;
    slot.* = style;
    n._responsive = r;
    return n;
}

pub fn hideOn(self: *const Self, platform: types.Platform) Self {
    return displayOn(self, platform, .hidden);
}

pub fn showOn(self: *const Self, platform: types.Platform) Self {
    const shown = if (self._flex_type == .hidden) types.FlexType.flex else self._flex_type;
    switch (platform) {
        .mobile => return displayOn(self, .tablet, .hidden),
        .tablet => return displayOn(self, .mobile, .hidden),
        .desktop => {
            // Tablet's rule covers desktop screens too; desktop's comes later
            // in the stylesheet and shows it again.
            const below_mobile = displayOn(self, .mobile, .hidden);
            const below_desktop = displayOn(&below_mobile, .tablet, .hidden);
            return displayOn(&below_desktop, .desktop, shown);
        },
    }
}

pub fn size(self: *const Self, dim: types.Size) Self {
    var n = self.*;
    n._size = dim;
    return n;
}

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

pub fn width(self: *const Self, length: types.Sizing) Self {
    var n = self.*;
    if (n._size == null) {
        n._size = .{ .width = length };
    } else {
        n._size.?.width = length;
    }
    return n;
}

pub fn minWidth(self: *const Self, min: types.Sizing) Self {
    var n = self.*;
    const sizing: types.Sizing = switch (min.type) {
        .percent => .{ .type = .min_percent, .size = min.size },
        .fixed => .{ .type = .min_px, .size = min.size },
        else => {
            Vapor.report.err("minWidth: only .percent and .px sizes are supported; ignored", .{});
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

pub fn maxWidth(self: *const Self, max: types.Sizing) Self {
    var n = self.*;
    const sizing: types.Sizing = switch (max.type) {
        .percent => .{ .type = .max_percent, .size = max.size },
        .fixed => .{ .type = .max_px, .size = max.size },
        else => {
            Vapor.report.err("maxWidth: only .percent and .px sizes are supported; ignored", .{});
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

pub fn height(self: *const Self, length: types.Sizing) Self {
    var n = self.*;
    if (n._size == null) {
        n._size = .{ .height = length };
    } else {
        n._size.?.height = length;
    }
    return n;
}

pub fn minHeight(self: *const Self, min: types.Sizing) Self {
    var n = self.*;
    const sizing: types.Sizing = switch (min.type) {
        .percent => .{ .type = .min_percent, .size = min.size },
        .fixed => .{ .type = .min_px, .size = min.size },
        else => {
            Vapor.report.err("minHeight: only .percent and .px sizes are supported; ignored", .{});
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

pub fn maxHeight(self: *const Self, max: types.Sizing) Self {
    var n = self.*;
    const sizing: types.Sizing = switch (max.type) {
        .percent => .{ .type = .max_percent, .size = max.size },
        .fixed => .{ .type = .max_px, .size = max.size },
        else => {
            Vapor.report.err("maxHeight: only .percent and .px sizes are supported; ignored", .{});
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

pub fn columns(self: *const Self, column_count: u8) *const Self {
    const node = self._ui_node orelse {
        Vapor.report.err("Node is null", .{});
        return self;
    };
    node.column_count = column_count;
    return self;
}

pub fn direction(self: *const Self, value: types.Direction) Self {
    var n = self.*;
    n._direction = value;
    self._ui_node.?.direction = value;
    return n;
}
