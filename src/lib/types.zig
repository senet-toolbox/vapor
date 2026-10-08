const std = @import("std");
const UINode = @import("UITree.zig").UINode;
const Vapor = @import("Vapor.zig");
pub const Transition = @import("Transition.zig").Transition;
pub const TransitionProperty = @import("Transition.zig").TransitionProperty;
pub const PackedTransition = @import("Transition.zig").PackedTransition;
const ColorTheme = @import("constants/Color.zig");
const Animation = @import("Animation.zig");
pub const ThemeTokens = @import("theme").ThemeTokens;
pub var color_theme: ColorTheme = ColorTheme{};
const isMobile = @import("utils.zig").isMobile;
const Event = @import("Event.zig");
const Theme = @import("theme");
pub const NewShadow = @import("Shadow.zig");
const StringTable = @import("StringTable.zig").StringTable;
const Accessibility = @import("Accessibility.zig").Accessibility;
const Edges = @import("Edges.zig").Edges;

pub const Layers = enum(u8) {
    none = 0,
    tooltip = 1,
    modal = 2,
};

pub const ElementType = enum(u8) {
    Rectangle,
    Text,
    Image,
    FlexBox,
    TextField,
    Button,
    Block,
    Box,
    Header,
    Svg,
    Link,
    EmbedLink,
    List,
    ListItem,
    _If,
    Hooks,
    Layout,
    Page,
    Bind,
    Dialog,
    DialogBtnShow,
    DialogBtnClose,
    Draggable,
    RedirectLink,
    Select,
    SelectItem,
    CtxButton,
    EmbedIcon,
    Icon,
    Label,
    Form,
    TextFmt,
    Table,
    TableRow,
    TableCell,
    TableHeader,
    TableBody,
    TextArea,
    Canvas,
    SubmitButton,
    HooksCtx,
    JsonEditor,
    HtmlText,
    Code,
    Span,
    LazyImage,
    Intersection,
    PreImage,
    TextGradient,
    Gradient,
    Virtualize,
    ButtonCycle,
    Graphic,
    Heading,
    Video,
    Noop,
    TableHead,
    Anchor,
    Spacer,
    Iframe,
    FieldSet,
};

pub const AnchorPlacement = enum(u8) {
    none,
    top,
    bottom,
    left,
    right,
    top_left,
    top_right,
    bottom_left,
    bottom_right,

    pub fn toPositionArea(self: AnchorPlacement) []const u8 {
        return switch (self) {
            .top => "top",
            .bottom => "bottom",
            .left => "center left",
            .right => "center right",
            .top_left => "top left",
            .top_right => "top right",
            .bottom_left => "bottom left",
            .bottom_right => "bottom right",
            // Callers skip .none; exhaustive so a new placement is a compile error.
            .none => "center",
        };
    }
};

pub const ThemeDefinition = struct {
    default: bool = false,
    name: []const u8,
    theme: Theme.Colors,
};

pub fn switchColorTheme() void {
    switch (color_theme.theme) {
        .dark => color_theme.theme = .light,
        .light => color_theme.theme = .dark,
    }
}

const SizingModule = @import("types/sizing.zig");
pub const Direction = SizingModule.Direction;
pub const SizingType = SizingModule.SizingType;
pub const SizingConstraint = SizingModule.SizingConstraint;
pub const Size = SizingModule.Size;
pub const Sizing = SizingModule.Sizing;
pub const SizeType = SizingModule.SizeType;
pub const PosType = SizingModule.PosType;
pub const Pos = SizingModule.Pos;

const MinMax = packed struct {
    min: f32 = 0,
    max: f32 = 0,

    pub fn eql(self: MinMax, other: MinMax) bool {
        return self.min == other.min and self.max == other.max;
    }
};

const Tag = enum {
    minmax,
    clamp,
};

// Make it a tagged union by adding an enum

pub const Platform = enum(u8) {
    mobile,
    desktop,
    tablet,
};

pub const Responsive = struct {
    mobile: ?ResponsiveStyle = null,
    desktop: ?ResponsiveStyle = null,
    tablet: ?ResponsiveStyle = null,
};

const PackedModule = @import("types/packed.zig");
pub const PackedResponsive = PackedModule.PackedResponsive;
pub const PackedCaret = PackedModule.PackedCaret;
pub const PackedLayout = PackedModule.PackedLayout;
pub const PackedPosition = PackedModule.PackedPosition;
pub const PackedMarginsPaddings = PackedModule.PackedMarginsPaddings;
pub const PackedGrid = PackedModule.PackedGrid;
pub const PackedLines = PackedModule.PackedLines;
pub const PackedDots = PackedModule.PackedDots;
pub const PackedGradient = PackedModule.PackedGradient;
pub const PackedLayer = PackedModule.PackedLayer;
pub const PackedShadow = PackedModule.PackedShadow;
pub const PackedTransform = PackedModule.PackedTransform;
pub const PackedLayers = PackedModule.PackedLayers;
pub const PackedTextDecoration = PackedModule.PackedTextDecoration;
pub const PackedVisual = PackedModule.PackedVisual;
pub const PackedInteractive = PackedModule.PackedInteractive;
pub const PackedAnimations = PackedModule.PackedAnimations;
pub const PackedTransforms = PackedModule.PackedTransforms;

pub const SizingUnit = enum(u8) {
    px,
    percent,
};

// Represents a single background image source and its properties.
const BackgroundModule = @import("types/background.zig");
pub const Image = BackgroundModule.Image;
pub const Grid = BackgroundModule.Grid;
pub const Dot = BackgroundModule.Dot;
pub const GradientDirection = BackgroundModule.GradientDirection;
pub const GradientType = BackgroundModule.GradientType;
pub const Lines = BackgroundModule.Lines;
pub const LinesDirection = BackgroundModule.LinesDirection;
pub const BackgroundLayer = BackgroundModule.BackgroundLayer;
pub const BackgroundClip = BackgroundModule.BackgroundClip;
pub const Gradient = BackgroundModule.Gradient;

// Represents a generated grid pattern.

pub const DirectionType = enum(u8) {
    none,
    to_top,
    to_bottom,
    to_left,
    to_right,
    to_top_right,
    to_top_left,
    angle,
};

// A BackgroundLayer can be one of several mutually exclusive types,
// like an image or a generated pattern. This is a perfect use for a union.

const ColorModule = @import("types/color.zig");
pub const Thematic = ColorModule.Thematic;
pub const Rgba = ColorModule.Rgba;
pub const Color = ColorModule.Color;
pub const ColorProp = ColorModule.ColorProp;
pub const ColorMix = ColorModule.ColorMix;
pub const PackedColorMix = ColorModule.PackedColorMix;
pub const PackedColor = ColorModule.PackedColor;

const BoxModule = @import("types/box.zig");
pub const Padding = BoxModule.Padding;
pub const Margin = BoxModule.Margin;
pub const BorderRadius = BoxModule.BorderRadius;
pub const Border = BoxModule.Border;
pub const BorderStyle = BoxModule.BorderStyle;
pub const BorderGrouped = BoxModule.BorderGrouped;
pub const Overflow = BoxModule.Overflow;
pub const Scroll = BoxModule.Scroll;
pub const Outline = BoxModule.Outline;

pub const Shadow = NewShadow;

pub const Alignment = enum(u8) {
    none,
    center,
    top,
    bottom,
    start,
    end,
    between,
    even,
    in_line,
    anchor_start,
    anchor_end,
    anchor_center,
};

pub const BoundingBox = struct {
    /// X coordinate of the top-left corner
    x: f32,
    /// Y coordinate of the top-left corner
    y: f32,
    /// Width of the bounding box
    width: f32,
    /// Height of the bounding box
    height: f32,
};

pub const FloatType = enum(u8) {
    right,
    left,
    top,
    bottom,
};

pub const PositionType = enum(u8) {
    none,
    relative,
    absolute,
    fixed,
    sticky,
};

pub const Position = struct {
    right: ?Pos = null,
    left: ?Pos = null,
    top: ?Pos = null,
    bottom: ?Pos = null,
    type: PositionType = .none,
    z_index: ?i16 = null,

    pub const relative = Position{ .type = .relative };
    pub const absolute = Position{ .type = .absolute };
    pub const fixed = Position{ .type = .fixed };

    pub const nav = Position{
        .left = .px(0),
        .right = .px(0),
        .type = .fixed,
        .top = .px(0),
        .z_index = 999,
    };

    pub fn full(pos_type: PositionType) Position {
        return .{
            .top = .px(0),
            .right = .px(0),
            .bottom = .px(0),
            .left = .px(0),
            .type = pos_type,
        };
    }

    /// Creates a top bottom left right position
    pub fn tblr(top: Pos, bottom: Pos, left: Pos, right: Pos, pos_type: PositionType) Position {
        return .{
            .top = top,
            .bottom = bottom,
            .left = left,
            .right = right,
            .type = pos_type,
        };
    }
    /// Creates a top bottom position
    pub fn tb(top: Pos, bottom: Pos, pos_type: PositionType) Position {
        return .{
            .top = top,
            .bottom = bottom,
            .type = pos_type,
        };
    }
    /// Creates a left right position
    pub fn lr(left: Pos, right: Pos, pos_type: PositionType) Position {
        return .{
            .left = left,
            .right = right,
            .type = pos_type,
        };
    }
    /// Creates a bottom right position
    pub fn br(bottom: Pos, right: Pos, pos_type: PositionType) Position {
        return .{
            .bottom = bottom,
            .right = right,
            .type = pos_type,
        };
    }
    /// Creates a top left position
    pub fn tl(top: Pos, left: Pos, pos_type: PositionType) Position {
        return .{
            .top = top,
            .left = left,
            .type = pos_type,
        };
    }
    /// Creates a bottom left position
    pub fn bl(bottom: Pos, left: Pos, pos_type: PositionType) Position {
        return .{
            .bottom = bottom,
            .left = left,
            .type = pos_type,
        };
    }
    /// Creates a top right position
    pub fn tr(top: Pos, right: Pos, pos_type: PositionType) Position {
        return .{
            .top = top,
            .right = right,
            .type = pos_type,
        };
    }
};

pub const TransformType = enum(u8) {
    none,
    translateX,
    translateY,
    scale,
    scaleY,
    scaleX,
    rotate,
    rotateX,
    rotateY,
    rotateXYZ,
};

pub const Transform = struct {
    const Direction = enum(u8) {
        up,
        down,
        left,
        right,
        up_and_left,
        up_and_right,
        down_and_left,
        down_and_right,
    };
    size_type: SizeType = .none,
    scale_size: f32 = 1,
    trans_x: f32 = 0,
    trans_y: f32 = 0,
    deg: f16 = 0,
    x: f16 = 0,
    y: f16 = 0,
    z: f16 = 0,
    type: []const TransformType = &.{.none},
    opacity: f16 = 1,

    pub fn scale() Transform {
        return .{ .scale_size = 1.04, .type = &.{.scale}, .size_type = .scale };
    }

    pub fn translate(x: f32, y: f32, unit: SizeType) Transform {
        return .{ .trans_x = x, .trans_y = y, .type = &.{ .translateX, .translateY }, .size_type = unit };
    }

    pub fn scaleDecimal(value: f16) Transform {
        return .{ .scale_size = value, .type = &.{.scale}, .size_type = .scale };
    }

    pub fn up(dist: f32) Transform {
        return .{ .trans_y = -dist, .type = &.{.translateY}, .size_type = .px };
    }

    pub fn direction_scale(dir: Transform.Direction, dist: f32, scale_size: f32) Transform {
        switch (dir) {
            .up => return .{ .trans_y = -dist, .scale_size = scale_size, .type = &.{ .translateY, .scale }, .size_type = .px },
            .down => return .{ .trans_y = dist, .scale_size = scale_size, .type = &.{ .translateY, .scale }, .size_type = .px },
            .left => return .{ .trans_x = -dist, .scale_size = scale_size, .type = &.{ .translateX, .scale }, .size_type = .px },
            .right => return .{ .trans_x = dist, .scale_size = scale_size, .type = &.{ .translateX, .scale }, .size_type = .px },
            .up_and_left => return .{ .trans_y = -dist, .trans_x = -dist, .scale_size = scale_size, .type = &.{ .translateY, .translateX, .scale }, .size_type = .px },
            .up_and_right => return .{ .trans_y = -dist, .trans_x = dist, .scale_size = scale_size, .type = &.{ .translateY, .translateX, .scale }, .size_type = .px },
            .down_and_left => return .{ .trans_y = dist, .trans_x = -dist, .scale_size = scale_size, .type = &.{ .translateY, .translateX, .scale }, .size_type = .px },
            .down_and_right => return .{ .trans_y = dist, .trans_x = dist, .scale_size = scale_size, .type = &.{ .translateY, .translateX, .scale }, .size_type = .px },
        }
    }

    pub fn distAndScale(dir: Transform.Direction, dist: f32, scale_size: f32) Transform {
        switch (dir) {
            .up => return .{ .trans_y = -dist, .scale_size = scale_size, .type = &.{ .translateY, .scale }, .size_type = .px },
            .down => return .{ .trans_y = dist, .scale_size = scale_size, .type = &.{ .translateY, .scale }, .size_type = .px },
            .left => return .{ .trans_x = -dist, .scale_size = scale_size, .type = &.{ .translateX, .scale }, .size_type = .px },
            .right => return .{ .trans_x = dist, .scale_size = scale_size, .type = &.{ .translateX, .scale }, .size_type = .px },
            .up_and_left => return .{ .trans_y = -dist, .trans_x = -dist, .scale_size = scale_size, .type = &.{ .translateY, .translateX, .scale }, .size_type = .px },
            .up_and_right => return .{ .trans_y = -dist, .trans_x = dist, .scale_size = scale_size, .type = &.{ .translateY, .translateX, .scale }, .size_type = .px },
            .down_and_left => return .{ .trans_y = dist, .trans_x = -dist, .scale_size = scale_size, .type = &.{ .translateY, .translateX, .scale }, .size_type = .px },
            .down_and_right => return .{ .trans_y = dist, .trans_x = dist, .scale_size = scale_size, .type = &.{ .translateY, .translateX, .scale }, .size_type = .px },
        }
    }

    pub fn down(dist: f32) Transform {
        return .{ .trans_y = dist, .type = &.{.translateY}, .size_type = .px };
    }

    pub fn left(dist: f32) Transform {
        return .{ .trans_x = -dist, .type = &.{.translateX}, .size_type = .px };
    }
    pub fn right(dist: f32) Transform {
        return .{ .trans_x = dist, .type = &.{.translateX}, .size_type = .px };
    }

    pub fn left_percent(percent: f32) Transform {
        return .{ .trans_x = percent, .type = &.{.translateX}, .size_type = .percent };
    }

    pub fn top_percent(percent: f32) Transform {
        return .{ .trans_y = percent, .type = &.{.translateY}, .size_type = .percent };
    }

    pub fn rotate(deg: f16) Transform {
        return .{ .deg = deg, .type = &.{.rotate}, .size_type = .deg };
    }

    pub fn rotateX(deg: f16) Transform {
        return .{ .deg = deg, .type = &.{.rotateX}, .size_type = .deg };
    }

    pub fn rotateY(deg: f16) Transform {
        return .{ .deg = deg, .type = &.{.rotateY}, .size_type = .deg };
    }

    pub fn rotateXYZ(x: f16, y: f16, z: f16) Transform {
        return .{ .x = x, .y = y, .z = z, .type = &.{.rotateXYZ}, .size_type = .deg };
    }
};

pub const Focus = struct {
    position: ?Position = null,
    display: ?FlexType = null,
    direction: ?Direction = null,
    width: ?Sizing = null,
    height: ?Sizing = null,
    font_size: ?i32 = null,
    letter_spacing: ?i32 = null,
    line_height: ?i32 = null,
    font_weight: ?usize = null,
    border_radius: ?BorderRadius = null,
    border_thickness: ?Border = null,
    border_color: ?Color = null,
    text_color: ?Color = null,
    padding: ?Padding = null,
    child_alignment: ?struct { x: Alignment, y: Alignment } = null,
    child_gap: u16 = 0,
    background: ?Color = null,
    shadow: Shadow = .{},
    transform: Transform = .{},
    opacity: f16 = 1,
    child_style: ?ChildStyle = null,
};

// pub const Hover = struct {
//     position: ?Position = null,
//     display: ?FlexType = null,
//     direction: ?Direction = null,
//     width: ?Sizing = null,
//     height: ?Sizing = null,
//     font_size: ?i32 = null,
//     letter_spacing: ?i32 = null,
//     line_height: ?i32 = null,
//     font_weight: ?usize = null,
//
//     border_radius: ?BorderRadius = null,
//     border_thickness: ?Border = null,
//     border_color: ?Color = null,
//
//     border: ?struct {
//         thickness: Border = .all(1),
//         color: ?Color = null,
//         radius: ?BorderRadius = null,
//     } = null,
//
//     text_color: ?Color = null,
//     padding: ?Padding = null,
//     child_alignment: ?struct { x: Alignment, y: Alignment } = null,
//     child_gap: u16 = 0,
//     background: ?Color = null,
//     shadow: Shadow = .{},
//     transform: Transform = .{},
//     opacity: f32 = 1,
//     child_style: ?ChildStyle = null,
// };

pub const Hover = struct {
    position: ?Position = null,
    // display: ?FlexType = null,
    // direction: ?Direction = null,

    /// Size configuration for the element
    size: ?Size = null,

    font_size: ?i32 = null,
    letter_spacing: ?i32 = null,
    line_height: ?i32 = null,
    font_weight: ?usize = null,

    border: ?struct {
        thickness: Border = .all(1),
        color: ?Color = null,
        radius: ?BorderRadius = null,
    } = null,

    border_radius: ?BorderRadius = null,
    border_thickness: ?Border = null,
    border_color: ?Color = null,

    text_color: ?Color = null,
    padding: ?Padding = null,

    /// External spacing configuration
    margin: ?Margin = .{},

    // child_alignment: ?struct { x: Alignment, y: Alignment } = null,
    child_gap: u16 = 0,
    background: ?Color = null,
    shadow: Shadow = .{},
    transform: Transform = .{},
    // opacity: f32 = 1,
    child_style: ?ChildStyle = null,
};

pub const CheckMark = struct {
    position: ?Position = null,
    display: ?FlexType = null,
    direction: ?Direction = null,
    width: ?Sizing = null,
    height: ?Sizing = null,
    font_size: ?i32 = null,
    letter_spacing: ?i32 = null,
    line_height: ?i32 = null,
    font_weight: ?usize = null,
    border_radius: ?BorderRadius = null,
    border_thickness: ?Border = null,
    border_color: ?Color = null,
    text_color: ?Color = null,
    padding: ?Padding = null,
    child_alignment: ?struct { x: Alignment, y: Alignment } = null,
    child_gap: u16 = 0,
    background: ?Color = null,
    shadow: Shadow = .{},
    transform: Transform = .{},
    opacity: f16 = 1,
    child_style: ?ChildStyle = null,
};

pub const Dim = struct {
    type: SizingType = .fit,
    pub const grow = Sizing{ .type = .grow, .size = .{ .min = 0, .max = 0 } };
    pub const fit = Sizing{ .type = .fit, .size = .{ .min = 0, .max = 0 } };
    pub fn fixed(size: f32) Sizing {
        return .{ .type = .fixed, .size = .{
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
};

pub const Resize = enum(u8) {
    default,
    none,
    both,
    horizontal,
    vertical,
};

pub const TextDecoration = struct {
    pub const none = TextDecoration{ .type = .none };
    pub const overline = TextDecoration{ .type = .overline };
    pub const underline = TextDecoration{ .type = .underline };
    pub const line_through = TextDecoration{ .type = .line_through };
    pub const blink = TextDecoration{ .type = .blink };
    type: TextDecorationType = .none,
    style: TextDecorationStyle = .default,
    color: ?Color = null,
};

pub const TextDecorationStyle = enum(u8) {
    default,
    solid,
    double,
    dotted,
    dashed,
    wavy,
};

pub const TextDecorationType = enum(u8) {
    default,
    none,
    overline,
    underline,
    inherit,
    initial,
    revert,
    unset,
    line_through,
    blink,
};

pub const WhiteSpace = enum(u8) {
    default,
    normal, // Collapses whitespace and breaks on necessary
    nowrap, // Collapses whitespace but prevents breaking
    pre, // Preserves whitespace and breaks on newlines
    pre_wrap, // Preserves whitespace and breaks as needed
    pre_line, // Collapses whitespace but preserves line breaks
    break_spaces, // Like pre-wrap but also breaks at spaces
    inherit, // Inherits from parent
    initial, // Default value
    revert, // Reverts to inherited value
    unset, // Resets to inherited value or initial
};

// Enum definition for CSS list-style-type property
pub const ListStyle = enum(u8) {
    default,
    none, // No bullet or marker
    disc, // Filled circle (default for unordered lists)
    circle, // Open circle
    square, // Square marker
    decimal, // Decimal numbers (default for ordered lists)
    decimal_leading_zero, // Decimal numbers with a leading zero (e.g. 01, 02, 03, ...)
    lower_roman, // Lowercase roman numerals (i, ii, iii, ...)
    upper_roman, // Uppercase roman numerals (I, II, III, ...)
    lower_alpha, // Lowercase alphabetic (a, b, c, ...)
    upper_alpha, // Uppercase alphabetic (A, B, C, ...)
    lower_greek, // Lowercase Greek letters (α, β, γ, ...)
    armenian, // Armenian numbering
    georgian, // Georgian numbering
    inherit, // Inherits from parent element
    initial, // Resets to the default value
    revert, // Reverts to the inherited value if explicitly changed
    unset, // Resets to inherited or initial value
};

pub const FlexType = enum(u8) {
    default,
    flex, // "flex"
    flow, // "inline"
    center,
    stack, // "inline-flex"
    hidden,
};

// Enum definition for flex-wrap property
pub const FlexWrap = enum(u8) {
    none,
    nowrap, // Single-line, no wrapping
    wrap, // Multi-line, wrapping if needed
    wrap_reverse, // Multi-line, reverse wrapping direction
    inherit, // Inherits from parent
    initial, // Default value
    revert, // Reverts to inherited value
    unset, // Resets to inherited value or initial
};

pub const KeyFrame = struct {
    tag: []const u8,
    from: Transform = .{},
    to: Transform = .{},
};

const Iteration = struct {
    iter_count: u32 = 1,
    pub fn infinite() Iteration {
        return .{
            .iter_count = 0,
        };
    }
    pub fn count(c: u32) Iteration {
        return .{
            .iter_count = c,
        };
    }
};

pub const ChildStyle = struct {
    style_id: []const u8,
    display: ?FlexType = null,
    position: ?Position = null,
    direction: Direction = .row,
    background: ?Color = null,
    width: ?Sizing = null,
    height: ?Sizing = null,
    font_size: ?i32 = null,
    letter_spacing: ?i32 = null,
    line_height: ?i32 = null,
    font_weight: ?usize = null,
    border_radius: ?BorderRadius = null,
    border_thickness: ?Border = null,
    border_color: ?Color = null,
    text_color: ?Color = null,
    padding: ?Padding = null,
    margin: ?Margin = null,
    overflow: ?Overflow = null,
    overflow_x: ?Overflow = null,
    overflow_y: ?Overflow = null,
    child_alignment: ?struct { x: Alignment, y: Alignment } = null,
    child_gap: u32 = 0,
    flex_shrink: ?u32 = null,
    font_family_file: []const u8 = "",
    font_family: []const u8 = "",
    opacity: f16 = 1,
    text_decoration: ?TextDecoration = null,
    shadow: ?Shadow = .{},
    white_space: ?WhiteSpace = null,
    flex_wrap: ?FlexWrap = null,
    key_frame: ?KeyFrame = null,
    key_frames: ?[]const KeyFrame = null,
    // animation: ?Animation.Specs = null,
    z_index: ?i16 = null,
    list_style: ?ListStyle = null,
    blur: ?u32 = null,
    outline: ?Outline = null,
    transition: ?Transition = null,
    show_scrollbar: bool = true,
    btn_id: u32 = 0,
    dialog_id: ?[]const u8 = null,
    accent_color: ?[4]u8 = null,
};

pub const Cursor = enum(u8) {
    default,
    pointer,
    help,
    grab,
    zoom_in,
    zoom_out,
    ew_resize,
    ns_resize,
    col_resize,
    row_resize,
    all_scroll,
    crosshair,
    grabbing,
};

pub const Appearance = enum(u8) {
    none = 0, // Remove default styling completely
    auto = 1, // Default browser styling
    button = 2, // Style as a button
    textfield = 3, // Style as a text input field
    menulist = 4, // Style as a dropdown menu
    searchfield = 5, // Style as a search input
    textarea = 6, // Style as a multiline text area
    checkbox = 7, // Style as a checkbox
    radio = 8, // Style as a radio button
    inherit = 9, // Inherit from parent
    initial = 10, // Default value
    revert = 11, // Revert to inherited value
    unset = 12, // Reset to inherited value or initial
};

pub const BoxSizing = enum(u8) {
    content_box = 0, // Default CSS box model
    border_box = 1, // Alternative CSS box model (padding and border included in width/height)
    padding_box = 2, // Experimental value (width/height includes content and padding)
    inherit = 3, // Inherits from parent
    initial = 4, // Default value
    revert = 5, // Reverts to inherited value
    unset = 6, // Resets to inherited value or initial
};

pub const TransformOrigin = enum(u8) {
    default,
    top,
    bottom,
    right,
    left,
    top_center,
    bottom_center,
    center_right,
    center_left,
};

pub const Layout = packed struct {
    x: Alignment = .none,
    y: Alignment = .none,
    pub const in_line = Layout{ .x = .in_line, .y = .in_line };
    pub const flex = Layout{};
    pub const center = Layout{ .x = .center, .y = .center };
    pub const top_center = Layout{ .x = .center, .y = .start };
    pub const left_center = Layout{ .x = .start, .y = .center };
    pub const right_center = Layout{ .x = .end, .y = .center };
    pub const bottom_center = Layout{ .x = .center, .y = .end };
    pub const top_right = Layout{ .x = .end, .y = .start };
    pub const top_left = Layout{ .x = .start, .y = .start };
    pub const left_top = Layout{ .x = .start, .y = .start };
    pub const bottom_right = Layout{ .x = .end, .y = .end };
    pub const bottom_left = Layout{ .x = .start, .y = .end };
    pub const x_even = Layout{ .x = .even, .y = .start };
    pub const x_even_center = Layout{ .x = .even, .y = .center };
    pub const y_even = Layout{ .x = .start, .y = .even };
    pub const y_even_center = Layout{ .x = .center, .y = .even };
    pub const x_between = Layout{ .x = .between, .y = .start };
    pub const x_between_center = Layout{ .x = .between, .y = .center };
    pub const x_between_bottom = Layout{ .x = .between, .y = .end };
    pub const x_between_top = Layout{ .x = .between, .y = .start };
    pub const y_between = Layout{ .x = .start, .y = .between };
    pub const y_between_center = Layout{ .x = .center, .y = .between };
    pub const anchor_start = Layout{ .x = .anchor_start, .y = .start };
    pub const anchor_end = Layout{ .x = .anchor_end, .y = .end };
    pub const anchor_center = Layout{ .x = .anchor_center, .y = .anchor_center };
};

const FontParams = struct {
    _size: i32,
    _weight: ?usize = null,
    _color: ?Color = null,
    pub fn size(font_size: i32) FontParams {
        return .{
            ._size = font_size,
        };
    }
    pub fn weight(font_weight: ?u16) FontParams {
        return .{
            ._weight = font_weight,
        };
    }

    pub fn color(font_color: ?Color) FontParams {
        return .{
            ._color = font_color,
        };
    }
    pub fn all(font_size: u8, font_weight: ?u16, font_color: ?Color) FontParams {
        return .{
            ._size = font_size,
            ._weight = font_weight,
            ._color = font_color,
        };
    }
    pub fn size_weight(font_size: u8, font_weight: ?u16) FontParams {
        return .{
            ._size = font_size,
            ._weight = font_weight,
        };
    }
    pub fn size_color(font_size: i32, font_color: ?Color) FontParams {
        return .{
            ._size = font_size,
            ._color = font_color,
        };
    }
};

pub const FontStyle = enum(u8) { default, normal, italic };

pub const CaretType = enum(u8) {
    none,
    block,
    line,
};

pub const Caret = struct {
    type: CaretType = .none,
    color: ?Color = null,
};

pub const AnimationPlayState = enum(u8) {
    none,
    paused,
};

pub const Visual = struct {
    /// Color color as RGBA array [red, green, blue, alpha] (0-255 each)
    /// Default: transparent black
    animation_name: ?[]const u8 = null,

    animation: ?[]const u8 = null,

    animation_play_state: ?AnimationPlayState = null,

    background: ?Color = null,

    layer: ?BackgroundLayer = null,
    layers: ?[]const BackgroundLayer = null,

    /// Font size in pixels
    font_size: ?u8 = null,

    /// Letter spacing in pixels (can be negative for tighter spacing)
    letter_spacing: ?u8 = null,

    /// Line height in pixels for text content
    line_height: ?u8 = null,

    /// Font weight (100-900, where 400 is normal, 700 is bold)
    font_weight: ?u16 = null,

    /// Font style (normal, italic)
    font_style: ?FontStyle = null,

    /// Border radius configuration for rounded corners
    border_radius: ?BorderRadius = null,

    /// Border thickness specification
    border_thickness: ?Border = null,

    /// Border color as RGBA array [red, green, blue, alpha]
    border_color: ?Color = null,

    border: ?BorderGrouped = null,

    /// Text color as RGBA array [red, green, blue, alpha]
    /// Default: solid black
    text_color: ?Color = null,

    /// Ellipsis configuration
    ellipsis: ?Ellipsis = null,

    /// Gradient color as RGBA array [red, green, blue, alpha]
    // gradient: ?[]const Color = null,

    /// Element opacity (0.0 = fully transparent, 1.0 = fully opaque)
    opacity: ?f16 = null,

    /// Shadow configuration for drop shadows
    shadow: ?NewShadow = null,
    text_shadow: ?NewShadow = null,

    new_shadow: ?NewShadow = null,

    edges: ?[]const u8 = null,

    /// 2D/3D transformation configuration
    transform: ?Transform = null,

    /// Text decoration (underline, strikethrough, etc.)
    text_decoration: ?TextDecoration = null,

    cursor: ?Cursor = null,

    fill: ?Color = null,
    stroke: ?Color = null,
    blur: ?u8 = 0,

    caret: ?Caret = null,

    /// Outline configuration (different from border)
    outline: ?Outline = null,
    outline_color: ?Color = null,

    /// White space handling (normal, nowrap, pre, pre-wrap)
    white_space: ?WhiteSpace = null,

    resize: ?Resize = null,

    color_mix: ?ColorMix = null,

    pub fn font(size: u8, weight: ?u16, color: ?Color) Visual {
        return .{
            .font_size = size,
            .font_weight = weight,
            .text_color = color,
        };
    }

    pub fn textColor(color: Color) Visual {
        return .{
            .text_color = color,
        };
    }

    pub fn borderSolid(thickness: Border, color: Color) Visual {
        return .{
            .border = BorderGrouped{
                .thickness = thickness,
                .color = color,
            },
        };
    }

    // Background shortcuts
    pub fn bg(background: Color) Visual {
        return .{ .background = background };
    }

    pub fn pill(color: Color) Visual {
        return .{ .border = .pill(color) };
    }

    pub fn when(condition: bool, visual_true: Visual, visual_false: Visual) Visual {
        if (condition) {
            return visual_true;
        } else {
            return visual_false;
        }
    }
};

pub const Interactive = struct {
    hover_layout: ?Layout = null,
    hover_position: ?Position = null,
    hover: ?Visual = null,
    focus: ?Visual = null,
    focus_within: ?Visual = null,
    cursor: ?Cursor = null,
};

pub const AspectRatio = enum(u8) {
    none = 0,
    square = 1,
    portrait = 2,
    landscape = 3,
};

pub const Ellipsis = enum(u8) {
    none,
    dot,
    dash,
};

/// Global user-defined default style that overrides system defaults
var user_defaults: ?Style = null;
pub const default: Style = Style{};

pub const ResponsiveStyle = struct {
    position: ?Position = null,
    direction: ?Direction = null,
    size: ?Size = null,
    aspect_ratio: ?AspectRatio = null,
    padding: ?Padding = null,
    margin: ?Margin = null,
    visual: ?Visual = null,
    layout: ?Layout = null,
    placement: ?AnchorPlacement = null,
    child_gap: ?u8 = null,
    spacing: ?u8 = null,
    font_family: ?[]const u8 = null,
    flex_wrap: ?FlexWrap = null,
    flex_type: ?FlexType = null,
    scroll: ?Scroll = null,
};

/// Comprehensive styling struct that provides CSS-like properties for UI components.
/// Supports layout, visual styling, typography, animations, and interactions.
/// Uses a three-tier inheritance system: system defaults -> user defaults -> component styles.
///
/// # Usage Example:
/// ```zig
/// const button_style = Style.with(.{
///     .background = .{ 70, 130, 180, 255 }, // Steel blue
///     .border_radius = .all(8),
///     .padding = .all(12),
///     .font_weight = 600,
/// });
/// ```
pub const Style = struct {
    /// Unique identifier for the element id="92d7dd45a43f36e4_Text_0-genk...
    /// this defaults to the uuid of the element, which is autogenerated
    /// It is used during reconciliation to find the correct node to update
    /// duplicate ids on the same page are considered undefined behaviour
    id: ?[]const u8 = null,

    /// Class-like identifier for grouping styles
    style_id: ?[]const u8 = null,

    /// Positioning method (static, relative, absolute, fixed)
    position: ?Position = null,

    /// Flex direction for child elements (row, column, row-reverse, column-reverse)
    direction: ?Direction = null,

    /// Size configuration for the element
    size: ?Size = null,

    /// Aspect ratio configuration for the element
    aspect_ratio: ?AspectRatio = null,

    /// Internal spacing configuration
    padding: ?Padding = null,

    /// External spacing configuration
    margin: ?Margin = null,

    /// Style Props
    visual: ?Visual = null,
    target_visual: ?Visual = null,

    /// Horizontal overflow behavior
    scroll: ?Scroll = null,

    /// Alignment configuration for child elements
    layout: ?Layout = null,

    /// Placement configuration for child elements
    placement: ?AnchorPlacement = null,

    /// Gap between child elements in pixels
    child_gap: ?u8 = null,
    spacing: ?u8 = null,

    /// Font family name (e.g., "Arial", "Helvetica", "Montserrat")
    font_family: ?[]const u8 = null,

    /// Flex wrap behavior (nowrap, wrap, wrap-reverse)
    flex_wrap: ?FlexWrap = null,

    /// Single keyframe for simple animations
    key_frame: ?KeyFrame = null,

    /// Array of keyframes for complex animations
    key_frames: ?[]const KeyFrame = null,

    /// Animation specifications (duration, timing, etc.)
    // animation: ?Animation.Specs = null,

    /// Animation name for exit/removal animations
    exit_animation: ?[]const u8 = null,

    /// List styling for ul/ol elements
    list_style: ?ListStyle = null,

    /// Transition specifications for smooth property changes
    transition: ?Transition = null,

    /// Whether to show scrollbars when content overflows
    show_scrollbar: ?bool = null,

    /// Interactive
    interactive: ?Interactive = null,

    /// Button identifier for click handling
    btn_id: u32 = 0,

    /// Dialog identifier for modal/popup elements
    dialog_id: ?[]const u8 = null,

    /// Array of child-specific style overrides
    child_styles: ?[]*const ChildStyle = null,

    /// Element appearance override
    appearance: ?Appearance = null,

    /// Custom checkmark styling for checkboxes
    checkmark_style: ?CheckMark = null,

    /// Hint to browser about which properties will change (optimization)
    will_change: ?TransitionProperty = null,

    /// Origin point for transformations
    transform_origin: ?TransformOrigin = null,

    /// Backface visibility for 3D transforms
    backface_visibility: ?[]const u8 = null,

    anchor: ?[]const u8 = null,

    flex_type: ?FlexType = null,

    responsive: ?Responsive = null,

    /// Gets the current base style to use for inheritance.
    /// Returns user-defined defaults if set, otherwise returns system defaults.
    ///
    /// # Returns:
    /// Style - The base style configuration
    ///
    /// # Usage:
    /// ```zig
    /// const base = Style.getDefault();
    /// const custom = Style{ .font_size = 16 }.merge(base);
    /// ```
    pub fn getDefault() Style {
        return user_defaults orelse default;
    }

    /// Merges this style with a base style, creating a new style where
    /// non-default properties from this style override the base style.
    /// Only properties that differ from system defaults are applied.
    ///
    /// # Parameters:
    /// - `base`: *const Style - The style with base properties
    /// - `override`: Style - The override style to merge with
    ///
    /// # Returns:
    /// Style - New style with merged properties
    ///
    /// # Usage:
    /// ```zig
    /// const base_style = Style{ .font_size = 14, .padding = .all(8) };
    /// const override_style = Style{ .font_size = 18 }; // Only override font size
    /// const merged = base_style.merge(override_style);
    /// // Result: font_size = 18, padding = .all(8)
    /// ```
    pub fn merge(base: *const Style, override: Style) Style {
        var result = base.*;

        if (override.id != null) result.id = override.id;
        if (override.style_id != null) result.style_id = override.style_id;
        if (override.position != null) result.position = override.position;
        if (override.direction != .row) result.direction = override.direction;
        if (override.size != null) result.size = override.size;
        if (override.padding != null) result.padding = override.padding;
        if (override.margin != null) result.margin = override.margin;
        if (override.visual != null) result.visual = override.visual;
        if (override.scroll != null) result.scroll = override.scroll;
        if (override.layout != null) result.layout = override.layout;
        if (override.font_family != null) result.font_family = override.font_family;
        if (override.flex_wrap != null) result.flex_wrap = override.flex_wrap;
        if (override.key_frame != null) result.key_frame = override.key_frame;
        if (override.key_frames != null) result.key_frames = override.key_frames;
        // if (override.animation != null) result.animation = override.animation;
        // if (override.exit_animation != null) result.exit_animation = override.exit_animation;
        if (override.list_style != null) result.list_style = override.list_style;
        if (override.transition != null) result.transition = override.transition;
        if (override.show_scrollbar != true) result.show_scrollbar = override.show_scrollbar;
        if (override.interactive != null) result.interactive = override.interactive;
        if (override.btn_id != 0) result.btn_id = override.btn_id;
        if (override.dialog_id != null) result.dialog_id = override.dialog_id;
        if (override.child_styles != null) result.child_styles = override.child_styles;
        if (override.appearance != null) result.appearance = override.appearance;
        if (override.checkmark_style != null) result.checkmark_style = override.checkmark_style;
        if (override.will_change != null) result.will_change = override.will_change;
        if (override.transform_origin != null) result.transform_origin = override.transform_origin;
        if (override.backface_visibility != null) result.backface_visibility = override.backface_visibility;
        if (override.child_gap != null) result.child_gap = override.child_gap;
        if (override.spacing != null) result.spacing = override.spacing;

        return result;
    }

    pub fn extend(self: *Style, target: Style) void {
        if (target.id != null) self.id = target.id;
        if (target.style_id != null) self.style_id = target.style_id;
        if (target.position != null) self.position = target.position;
        if (target.direction != .row) self.direction = target.direction;
        if (target.size != null) self.size = target.size;
        if (target.padding != null) self.padding = target.padding;
        if (target.margin != null) self.margin = target.margin;
        if (target.visual != null) self.visual = target.visual;
        if (target.scroll != null) self.scroll = target.scroll;
        if (target.layout != null) self.layout = target.layout;
        if (target.font_family != null) self.font_family = target.font_family;
        if (target.flex_wrap != null) self.flex_wrap = target.flex_wrap;
        if (target.key_frame != null) self.key_frame = target.key_frame;
        if (target.key_frames != null) self.key_frames = target.key_frames;
        // if (target.animation != null) self.animation = target.animation;
        // if (target.exit_animation != null) self.exit_animation = target.exit_animation;
        if (target.list_style != null) self.list_style = target.list_style;
        if (target.transition != null) self.transition = target.transition;
        if (target.show_scrollbar != true) self.show_scrollbar = target.show_scrollbar;
        if (target.interactive != null) self.interactive = target.interactive;
        if (target.btn_id != 0) self.btn_id = target.btn_id;
        if (target.dialog_id != null) self.dialog_id = target.dialog_id;
        if (target.child_styles != null) self.child_styles = target.child_styles;
        if (target.appearance != null) self.appearance = target.appearance;
        if (target.checkmark_style != null) self.checkmark_style = target.checkmark_style;
        if (target.will_change != null) self.will_change = target.will_change;
        if (target.transform_origin != null) self.transform_origin = target.transform_origin;
        if (target.backface_visibility != null) self.backface_visibility = target.backface_visibility;
        if (target.child_gap != null) self.child_gap = target.child_gap;
        if (target.spacing != null) self.spacing = target.spacing;
    }
};

pub const StyleFields = enum {
    background,
    border,
    border_radius,
    border_thickness,
    border_color,
    text_color,
    font_style,
    font_size,
    font_weight,
    letter_spacing,
    line_height,
    opacity,
    padding,
    margin,
    size,
    position,
    direction,
    flex_wrap,
    list_style,
    transition,
    show_scrollbar,
    fill,
    stroke,
    animation_play_state,
};

pub const Config = struct {
    style: Style,
};

pub const HooksIds = struct {
    created_id: u32 = 0,
    mounted_id: u32 = 0,
    updated_id: u32 = 0,
    destroy_id: u32 = 0,
};

pub const Callback = *const fn (*Event) void;
const InputModule = @import("types/input.zig");
pub const InputParamsStr = InputModule.InputParamsStr;
pub const InputParamsEmail = InputModule.InputParamsEmail;
pub const InputParamsPassword = InputModule.InputParamsPassword;
pub const InputParamsTelephone = InputModule.InputParamsTelephone;
pub const InputParamsFloat = InputModule.InputParamsFloat;
pub const InputParamsInt = InputModule.InputParamsInt;
pub const InputParamsString = InputModule.InputParamsString;
pub const InputParamsDate = InputModule.InputParamsDate;
pub const InputParamsRadio = InputModule.InputParamsRadio;
pub const InputParamsFile = InputModule.InputParamsFile;
pub const TextFieldConfig = InputModule.TextFieldConfig;
pub const InputTypes = InputModule.InputTypes;
pub const TextFieldParams = InputModule.TextFieldParams;

pub const StateType = enum {
    static,
    pure,
    dynamic,
    animation,
    grain,
    err,
    removed,
    added,
    moved,
    inert,
};

pub const ButtonType = enum {
    submit,
    button,
};

pub const ElementDeclaration = struct {
    hooks: HooksIds = .{},
    style: ?*const Style = null,
    elem_type: ElementType,
    text: ?[]const u8 = null,
    svg: []const u8 = "",
    href: ?[]const u8 = null,
    alt: ?[]const u8 = null,
    show: bool = true,
    text_field_params: ?TextFieldParams = null,
    event_type: ?EventType = null,
    state_type: StateType = .static,
    aria_label: ?[]const u8 = null,
    tooltip: ?*const Tooltip = null,
    animation_enter: ?[]const u8 = null,
    animation: ?[]const u8 = null,
    animation_exit: ?[]const u8 = null,
    video: ?*const Video = null,
    /// Used for passing ect data
    udata: usize = 0,
    level: ?u8 = null,
    name: ?[]const u8 = null,
    style_fields: ?[]const StyleFields = null,
    hover_style_fields: ?[]const StyleFields = null,
    inlineStyle: ?[]const u8 = null,
    accessibility: ?Accessibility = null,
    can_have_children: bool = true,
    src: ?[]const u8 = null,
    morph: bool = false,
    target: ?[]const u8 = null,
};

pub const Tooltip = struct {
    text: []const u8,
    style: ?Style = null,
};

pub const RenderCommand = struct {
    /// Rectangular box that fully encloses this UI element
    elem_type: ElementType,
    text: []const u8 = "",
    href: []const u8 = "",
    style: ?*const Style = null,
    id: []const u8 = "",
    index: usize = 0,
    hooks: HooksIds,
    node_ptr: *UINode,
    hover: bool = false,
    focus: bool = false,
    focus_within: bool = false,
    class: ?[]const u8 = null,
    render_type: StateType = .static,
    tooltip: ?*Tooltip = null,
    has_children: bool = true,
    hash: u32 = 0,
    style_changed: bool = false,
    props_changed: bool = false,
};

pub const EventType = enum(u8) {
    // Mouse events
    none = 0,
    click, // Fired when a pointing device button is clicked.
    dblclick, // Fired when a pointing device button is double-clicked.
    mousedown, // Fired when a pointing device button is pressed.
    mouseup, // Fired when a pointing device button is released.
    mousemove, // Fired when a pointing device is moved.
    mouseover, // Fired when a pointing device is moved onto an element.
    mouseout, // Fired when a pointing device is moved off an element.
    mouseenter, // Similar to mouseover but does not bubble.
    mouseleave, // Similar to mouseout but does not bubble.
    rightclick, // Fired when the right mouse button is clicked.

    // Keyboard events
    keydown, // Fired when a key is pressed.
    keyup, // Fired when a key is released.
    keypress, // Fired when a key that produces a character value is pressed.

    // Focus events
    focus, // Fired when an element gains focus.
    blur, // Fired when an element loses focus.
    focusin, // Fired when an element is about to receive focus.
    focusout, // Fired when an element is about to lose focus.

    // Form events
    change, // Fired when the value of an element changes.
    input, // Fired every time the value of an element changes.
    submit, // Fired when a form is submitted.
    reset, // Fired when a form is reset.

    // Window events
    resize, // Fired when the window is resized.
    scroll, // Fired when the document view is scrolled.
    wheel, // Fired when the mouse wheel is rotated.

    // Drag & Drop events
    drag, // Fired continuously while an element or text selection is being dragged.
    dragstart, // Fired at the start of a drag operation.
    dragend, // Fired at the end of a drag operation.
    dragover, // Fired when an element is being dragged over a valid drop target.
    dragenter, // Fired when a dragged element enters a valid drop target.
    dragleave, // Fired when a dragged element leaves a valid drop target.
    drop, // Fired when a dragged element is dropped on a valid drop target.

    // Clipboard events
    copy, // Fired when the user initiates a copy action.
    cut, // Fired when the user initiates a cut action.
    paste, // Fired when the user initiates a paste action.

    // Touch events
    touchstart, // Fired when one or more touch points are placed on the touch surface.
    touchmove, // Fired when one or more touch points are moved along the touch surface.
    touchend, // Fired when one or more touch points are removed from the touch surface.
    touchcancel, // Fired when a touch point is disrupted (e.g., by a modal interruption).

    // Pointer events (unify mouse, touch, and pen input)
    pointerover, // Fired when a pointer enters the hit test boundaries of an element.
    pointerenter, // Similar to pointerover but does not bubble.
    pointerdown, // Fired when a pointer becomes active.
    pointermove, // Fired when a pointer changes coordinates.
    pointerup, // Fired when a pointer is no longer active.
    pointercancel, // Fired when a pointer is canceled.
    pointerout, // Fired when a pointer moves out of an element.
    pointerleave, // Similar to pointerout but does not bubble.

    // Document / Media / Error events
    load, // Fired when a resource and its dependent resources have finished loading.
    unload, // Fired when the document is being unloaded.
    abort, // Fired when the loading of a resource is aborted.
    show,
    close,
    cancel,

    // Media events
    play, // Fired when playback has begun.
    pause, // Fired when playback has been paused.
    ended, // Fired when playback has stopped because the end of the media was reached.
    volumechange, // Fired when the volume has been changed.
    waiting, // Fired when playback has stopped because of a temporary lack of data.

    // Progress events
    loadstart, // Fired when the browser has started to load a resource.
    progress, // Fired periodically as the browser loads a resource.
    loadend, // Fired when a request has completed (success or failure).

    // Transition & Animation events
    transitionend, // Fired when a CSS transition has completed.
    animationstart, // Fired when a CSS animation has started.
    animationend, // Fired when a CSS animation has completed.
    animationiteration, // Fired when an iteration of a CSS animation has completed.
    beforeinput, // Fired when an iteration of a CSS animation has completed.
};

pub const Video = struct {
    src: ?[]const u8 = null,
    autoplay: bool = false,
    muted: bool = false,
    loop: bool = false,
    controls: bool = false,
    lazy: bool = false,
};
