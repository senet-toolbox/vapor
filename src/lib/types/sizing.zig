const types = @import("../types.zig");
const isMobile = @import("../utils.zig").isMobile;

pub const Direction = enum(u8) {
    column = 0,
    row = 1,
};

pub const SizingType = enum(u8) {
    none,
    fit,
    grow,
    percent,
    fixed,
    elastic,
    elastic_percent,
    clamp_px,
    clamp_percent,
    min_max_vp,
    auto,
    top,
    bottom,
    left,
    right,
    min_px,
    min_percent,
    max_px,
    max_percent,
    vp,
};

pub const SizingConstraint = packed struct {
    min: f32 = 0,
    max: f32 = 0,
    preferred: f32 = 0,
};

pub const Size = packed struct {
    width: Sizing = .{},
    height: Sizing = .{},
    pub const full = Size{ .width = .percent(100), .height = .percent(100) };
    pub const expand = Size{ .width = .expand, .height = .expand };
    pub fn square_px(size: f32) Size {
        return .{
            .width = .px(size),
            .height = .px(size),
        };
    }
    pub fn square_percent(size: f32) Size {
        return .{
            .width = .percent(size),
            .height = .percent(size),
        };
    }

    pub fn px(size: f32) Size {
        return .{
            .width = .px(size),
            .height = .px(size),
        };
    }

    pub fn percent(size: f32) Size {
        return .{
            .width = .percent(size),
            .height = .percent(size),
        };
    }

    /// Creates a height sizing
    pub fn h(size: Sizing) Size {
        return .{
            .height = size,
        };
    }
    /// Creates a width sizing
    pub fn w(size: Sizing) Size {
        return .{
            .width = size,
        };
    }
    /// Creates a height and width sizing
    pub fn hw(height: Sizing, width: Sizing) Size {
        return .{
            .width = width,
            .height = height,
        };
    }
    /// Creates a height and width sizing with pixel values
    pub fn hw_px(height: f32, width: f32) Size {
        return .{
            .width = .px(width),
            .height = .px(height),
        };
    }
    /// Creates a height and width sizing with percent values
    pub fn hw_percent(height: f32, width: f32) Size {
        return .{
            .width = .percent(width),
            .height = .percent(height),
        };
    }
};

pub const Sizing = packed struct {
    size: SizingConstraint = .{},
    type: SizingType = .none,

    pub const grow = Sizing{ .type = .grow, .size = .{ .min = 0, .max = 0 } };
    pub const expand = Sizing{ .type = .grow, .size = .{ .min = 0, .max = 0 } };
    pub const auto = Sizing{ .type = .auto, .size = .{ .min = 0, .max = 0 } };
    pub const fit = Sizing{ .type = .fit, .size = .{ .min = 0, .max = 0 } };
    pub const full = percent(100);

    pub fn px(size: f32) Sizing {
        return .{ .type = .fixed, .size = .{
            .min = size,
            .max = size,
        } };
    }

    pub fn vp(size: f32) Sizing {
        return .{ .type = .vp, .size = .{
            .min = size,
            .max = size,
        } };
    }

    pub fn elastic(min: f32, max: f32) Sizing {
        return .{ .type = .elastic, .size = .{
            .min = min,
            .max = max,
        } };
    }

    pub fn percent(size: f32) Sizing {
        return .{ .type = .percent, .size = .{
            .min = size,
            .max = size,
        } };
    }

    pub fn min_max_vp(min: f32, max: f32) Sizing {
        return .{ .type = .min_max_vp, .size = .{
            .min = min,
            .max = max,
        } };
    }

    pub fn at(mobile: f32, desktop: f32) Sizing {
        if (isMobile()) {
            return .{ .type = .percent, .size = .{
                .min = mobile,
                .max = mobile,
            } };
        }
        return .{ .type = .percent, .size = .{
            .min = desktop,
            .max = desktop,
        } };
    }

    pub fn mobile_desktop_percent(mobile: f32, desktop: f32) Sizing {
        if (isMobile()) {
            return .{ .type = .percent, .size = .{
                .min = mobile,
                .max = mobile,
            } };
        }
        return .{ .type = .percent, .size = .{
            .min = desktop,
            .max = desktop,
        } };
    }
    //
    pub fn mobile_desktop(mobile: Sizing, desktop: Sizing) Sizing {
        if (isMobile()) {
            return mobile;
        } else {
            return desktop;
        }
    }

    pub fn clamp(min: f32, preferred: f32, max: f32, unit: types.SizingUnit) Sizing {
        switch (unit) {
            .px => return .{ .type = .clamp_px, .size = .{ .min = min, .max = max, .preferred = preferred } },
            .percent => return .{ .type = .clamp_percent, .size = .{ .min = min, .max = max, .preferred = preferred } },
        }
    }
};

pub const PosType = enum(u8) {
    fit = 0,
    grow = 1,
    percent = 2,
    fixed = 3,
};

pub const Pos = packed struct {
    type: SizingType = .none,
    value: f32 = 0,

    pub const grow = Pos{ .type = .grow, .value = 0 };
    pub fn px(pos: f32) Pos {
        return .{ .type = .fixed, .value = pos };
    }

    pub fn percent(pos: f32) Pos {
        return .{ .type = .percent, .value = pos };
    }

    pub fn mobile_desktop_percent(mobile: f32, desktop: f32) Pos {
        if (isMobile()) {
            return .{ .type = .percent, .value = mobile };
        }
        return .{ .type = .percent, .value = desktop };
    }
    //
    pub fn mobile_desktop(mobile: Pos, desktop: Pos) Pos {
        if (isMobile()) {
            return mobile;
        } else {
            return desktop;
        }
    }
};

pub const SizeType = enum(u8) {
    percent,
    deg,
    px,
    scale,
    none,
};
