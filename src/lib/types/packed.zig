const types = @import("../types.zig");
const PackedTransition = @import("../Transition.zig").PackedTransition;
const StringTable = @import("../StringTable.zig").StringTable;
const Vapor = @import("../Vapor.zig");

pub const PackedResponsive = struct {
    flags_layout: [3]bool = .{ false, false, false },
    flags_visual: [3]bool = .{ false, false, false },
    mobile_layout: PackedLayout = .{},
    desktop_layout: PackedLayout = .{},
    tablet_layout: PackedLayout = .{},
    mobile_visual: PackedVisual = .{},
    desktop_visual: PackedVisual = .{},
    tablet_visual: PackedVisual = .{},
};

pub const PackedCaret = packed struct {
    type: types.CaretType = .none,
    color: types.PackedColor = .{},
};

pub const PackedLayout = packed struct {
    flex: types.FlexType = .default,
    layout: types.Layout = .{},
    direction: types.Direction = .row,
    size: types.Size = .{},
    child_gap: u8 = 0,
    spacing: u8 = 0,
    scroll: types.Scroll = .{},
    flex_wrap: types.FlexWrap = .none,
    text_align: types.Layout = .{},
    aspect_ratio: types.AspectRatio = .none,
    placement: types.AnchorPlacement = .none,
    parent_direction: types.Direction = .row,
    column_count: u8 = 0,
    column_spacing: f32 = 0,
};

pub const PackedPosition = packed struct {
    position_type: types.PositionType = .none,
    top: types.Pos = .{},
    right: types.Pos = .{},
    bottom: types.Pos = .{},
    left: types.Pos = .{},
    z_index: i16 = 0,
    // anchor_name_ptr: ?[*]const u8 = null,
    // anchor_name_len: u32 = 0,
    anchor_name_handle: u32 = StringTable.null_handle, // Replaces ptr + len
    position_anchor_handle: u32 = StringTable.null_handle, // Replaces ptr + len
};

pub const PackedMarginsPaddings = packed struct {
    padding: types.Padding = .{},
    margin: types.Margin = .{},
};

pub const PackedGrid = packed struct {
    size: u8 = 0,
    thickness: u8 = 1,
    packed_color: types.PackedColor = .{},
};

pub const PackedLines = packed struct {
    direction: types.LinesDirection = .horizontal,
    color: types.PackedColor = .{},
    thickness: u8 = 1,
    spacing: u8 = 10,
};

pub const PackedDots = packed struct {
    radius: f16 = 0,
    spacing: u8 = 0,
    packed_color: types.PackedColor = .{},
};

pub const PackedGradient = packed struct {
    type: types.GradientType = .none,
    direction: types.GradientDirection = .{},
    colors_ptr: u32 = 0,
    colors_len: u32 = 0,
    clip: types.BackgroundClip = .none,
};

pub const PackedLayer = union(enum) {
    Grid: PackedGrid,
    Dot: PackedDots,
    Gradient: PackedGradient,
    Lines: PackedLines,
};

pub const PackedShadow = packed struct {
    top: i16 = 0,
    left: i16 = 0,
    blur: u8 = 0,
    spread: u8 = 0,
    color: types.PackedColor = .{},
};

pub const PackedTransform = packed struct {
    size_type: types.SizeType = .none,
    type: types.TransformType = .none,
    scale_size: f32 = 1,
    trans_x: f32 = 0,
    trans_y: f32 = 0,
    deg: f16 = 0,
    x: f16 = 0,
    y: f16 = 0,
    z: f16 = 0,
    opacity: f16 = 1,
    type_ptr: u32 = 0,
    type_len: usize = 0,

    pub fn set(packed_transform: *PackedTransform, transform: *const types.Transform) void {
        const type_slice = transform.type;
        var slice: []types.TransformType = Vapor.arena(.frame).alloc(types.TransformType, type_slice.len) catch return;
        for (type_slice, 0..) |element, i| {
            slice[i] = element;
        }

        const count = Vapor.packed_transforms.count() + 1;
        Vapor.packed_transforms.put(count, slice) catch return;

        packed_transform.type_ptr = count;
        packed_transform.type_len = slice.len;
        packed_transform.size_type = transform.size_type;
        packed_transform.scale_size = transform.scale_size;
        packed_transform.trans_x = transform.trans_x;
        packed_transform.trans_y = transform.trans_y;
        packed_transform.deg = transform.deg;
        packed_transform.x = transform.x;
        packed_transform.y = transform.y;
        packed_transform.z = transform.z;
        packed_transform.opacity = transform.opacity;
    }
};

pub const PackedLayers = packed struct {
    items_ptr: u32 = 0,
    len: u32 = 0,
};

pub const PackedTextDecoration = packed struct {
    type: types.TextDecorationType = .none,
    style: types.TextDecorationStyle = .default,
    color: types.PackedColor = .{},
};

pub const PackedVisual = packed struct {
    animation_name_handle: u32 = StringTable.null_handle, // Replaces ptr + len
    animation: u32 = StringTable.null_handle, // Replaces ptr + len
    animation_play_state: types.AnimationPlayState = .none, // Replaces ptr + len
    background: types.PackedColor = .{},
    packed_layers: PackedLayers = .{},
    background_layers: PackedLayers = .{},
    has_border_radius: bool = false,
    border_radius: types.BorderRadius = .{},
    has_border_thickeness: bool = false,
    border_thickness: types.Border = .{},
    has_border_color: bool = false,
    border_color: types.PackedColor = .{},
    border_style: types.BorderStyle = .default,
    font_size: u8 = 0,
    font_weight: u16 = 0,
    text_color: types.PackedColor = .{},
    font_style: types.FontStyle = .default,
    has_opacity: bool = false,
    ellipsis: types.Ellipsis = .none,
    opacity: f16 = 1,
    text_decoration: PackedTextDecoration = .{},
    blur: u8 = 0,
    list_style: types.ListStyle = .default,
    outline: types.Outline = .default,
    has_outline_color: bool = false,
    outline_color: types.PackedColor = .{},
    shadow: PackedShadow = .{},
    text_shadow: u32 = 0,
    has_white_space: bool = false,
    white_space: types.WhiteSpace = .normal,
    cursor: types.Cursor = .default,
    fill: types.PackedColor = .{},
    stroke: types.PackedColor = .{},
    font_family_handle: u32 = StringTable.null_handle, // Replaces ptr + len
    has_transitions: bool = false,
    transitions: PackedTransition = .{},
    is_text_gradient: bool = false,
    caret: PackedCaret = .{},
    resize: types.Resize = .default,
    new_shadow: u32 = 0, // Replaces ptr + len
    edges_handle: u32 = StringTable.null_handle, // Replaces ptr + len
    color_mix: types.PackedColorMix = .{},
};

pub const PackedInteractive = struct {
    has_hover: bool = false,
    hover: PackedVisual = undefined,
    has_hover_position: bool = false,
    hover_position: PackedPosition = undefined,
    has_focus: bool = false,
    focus: PackedVisual = undefined,
    has_focus_within: bool = false,
    focus_within: PackedVisual = undefined,
    has_hover_transform: bool = false,
    hover_transform: PackedTransform = undefined,
};

pub const PackedAnimations = packed struct {
    has_animation_enter: bool = false,
    has_animation_exit: bool = false,
    animation_enter: u32 = StringTable.null_handle, // Replaces ptr + len
    animation_exit: u32 = StringTable.null_handle, // Replaces ptr + len
};

pub const PackedTransforms = packed struct {
    has_transform: bool = false,
    transform: PackedTransform = undefined,
    transform_origin: types.TransformOrigin = .default,
};
