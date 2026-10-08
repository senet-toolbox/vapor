const types = @import("../types.zig");
const NewShadow = @import("../Shadow.zig");
const Transition = @import("../Transition.zig").Transition;
const TransitionProperty = @import("../Transition.zig").TransitionProperty;

pub const Visual = struct {
    /// Color color as RGBA array [red, green, blue, alpha] (0-255 each)
    /// Default: transparent black
    animation_name: ?[]const u8 = null,

    animation: ?[]const u8 = null,

    animation_play_state: ?types.AnimationPlayState = null,

    background: ?types.Color = null,

    layer: ?types.BackgroundLayer = null,
    layers: ?[]const types.BackgroundLayer = null,

    /// Font size in pixels
    font_size: ?u8 = null,

    /// Letter spacing in pixels (can be negative for tighter spacing)
    letter_spacing: ?u8 = null,

    /// Line height in pixels for text content
    line_height: ?u8 = null,

    /// Font weight (100-900, where 400 is normal, 700 is bold)
    font_weight: ?u16 = null,

    /// Font style (normal, italic)
    font_style: ?types.FontStyle = null,

    /// Border radius configuration for rounded corners
    border_radius: ?types.BorderRadius = null,

    /// Border thickness specification
    border_thickness: ?types.Border = null,

    /// Border color as RGBA array [red, green, blue, alpha]
    border_color: ?types.Color = null,

    border: ?types.BorderGrouped = null,

    /// Text color as RGBA array [red, green, blue, alpha]
    /// Default: solid black
    text_color: ?types.Color = null,

    /// Ellipsis configuration
    ellipsis: ?types.Ellipsis = null,

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
    transform: ?types.Transform = null,

    /// Text decoration (underline, strikethrough, etc.)
    text_decoration: ?types.TextDecoration = null,

    cursor: ?types.Cursor = null,

    fill: ?types.Color = null,
    stroke: ?types.Color = null,
    blur: ?u8 = 0,

    caret: ?types.Caret = null,

    /// Outline configuration (different from border)
    outline: ?types.Outline = null,
    outline_color: ?types.Color = null,

    /// White space handling (normal, nowrap, pre, pre-wrap)
    white_space: ?types.WhiteSpace = null,

    resize: ?types.Resize = null,

    color_mix: ?types.ColorMix = null,

    pub fn font(size: u8, weight: ?u16, color: ?types.Color) Visual {
        return .{
            .font_size = size,
            .font_weight = weight,
            .text_color = color,
        };
    }

    pub fn textColor(color: types.Color) Visual {
        return .{
            .text_color = color,
        };
    }

    pub fn borderSolid(thickness: types.Border, color: types.Color) Visual {
        return .{
            .border = types.BorderGrouped{
                .thickness = thickness,
                .color = color,
            },
        };
    }

    // Background shortcuts
    pub fn bg(background: types.Color) Visual {
        return .{ .background = background };
    }

    pub fn pill(color: types.Color) Visual {
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
    hover_layout: ?types.Layout = null,
    hover_position: ?types.Position = null,
    hover: ?Visual = null,
    focus: ?Visual = null,
    focus_within: ?Visual = null,
    cursor: ?types.Cursor = null,
};

pub const ResponsiveStyle = struct {
    position: ?types.Position = null,
    direction: ?types.Direction = null,
    size: ?types.Size = null,
    aspect_ratio: ?types.AspectRatio = null,
    padding: ?types.Padding = null,
    margin: ?types.Margin = null,
    visual: ?Visual = null,
    layout: ?types.Layout = null,
    placement: ?types.AnchorPlacement = null,
    child_gap: ?u8 = null,
    spacing: ?u8 = null,
    font_family: ?[]const u8 = null,
    flex_wrap: ?types.FlexWrap = null,
    flex_type: ?types.FlexType = null,
    scroll: ?types.Scroll = null,
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
    position: ?types.Position = null,

    /// Flex direction for child elements (row, column, row-reverse, column-reverse)
    direction: ?types.Direction = null,

    /// Size configuration for the element
    size: ?types.Size = null,

    /// Aspect ratio configuration for the element
    aspect_ratio: ?types.AspectRatio = null,

    /// Internal spacing configuration
    padding: ?types.Padding = null,

    /// External spacing configuration
    margin: ?types.Margin = null,

    /// Style Props
    visual: ?Visual = null,
    target_visual: ?Visual = null,

    /// Horizontal overflow behavior
    scroll: ?types.Scroll = null,

    /// Alignment configuration for child elements
    layout: ?types.Layout = null,

    /// Placement configuration for child elements
    placement: ?types.AnchorPlacement = null,

    /// Gap between child elements in pixels
    child_gap: ?u8 = null,
    spacing: ?u8 = null,

    /// Font family name (e.g., "Arial", "Helvetica", "Montserrat")
    font_family: ?[]const u8 = null,

    /// Flex wrap behavior (nowrap, wrap, wrap-reverse)
    flex_wrap: ?types.FlexWrap = null,

    /// Single keyframe for simple animations
    key_frame: ?types.KeyFrame = null,

    /// Array of keyframes for complex animations
    key_frames: ?[]const types.KeyFrame = null,

    /// Animation specifications (duration, timing, etc.)
    // animation: ?Animation.Specs = null,

    /// Animation name for exit/removal animations
    exit_animation: ?[]const u8 = null,

    /// List styling for ul/ol elements
    list_style: ?types.ListStyle = null,

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
    child_styles: ?[]*const types.ChildStyle = null,

    /// Element appearance override
    appearance: ?types.Appearance = null,

    /// Custom checkmark styling for checkboxes
    checkmark_style: ?types.CheckMark = null,

    /// Hint to browser about which properties will change (optimization)
    will_change: ?TransitionProperty = null,

    /// Origin point for transformations
    transform_origin: ?types.TransformOrigin = null,

    /// Backface visibility for 3D transforms
    backface_visibility: ?[]const u8 = null,

    anchor: ?[]const u8 = null,

    flex_type: ?types.FlexType = null,

    responsive: ?types.Responsive = null,

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
        return types.user_defaults orelse types.default;
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
