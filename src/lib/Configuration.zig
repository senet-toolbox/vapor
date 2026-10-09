const UINode = @import("UITree.zig").UINode;
const std = @import("std");
const UIContext = @import("UITree.zig").UIContext;
const types = @import("types.zig");
const ElemDecl = types.ElementDeclaration;
const Vapor = @import("Vapor.zig");
const utils = @import("utils.zig");
const Shadow = @import("Shadow.zig");
const hashKey = utils.hashKey;
const Reconciler = @import("Reconciler.zig");
pub var packed_layout: types.PackedLayout = .{};
pub var packed_position: types.PackedPosition = .{};
pub var packed_margins_paddings: types.PackedMarginsPaddings = .{};
pub var packed_visual: types.PackedVisual = .{};
pub var target_packed_visual: types.PackedVisual = .{};
pub var packed_animations: types.PackedAnimations = .{};
pub var packed_interactive: types.PackedInteractive = .{};
pub var packed_transition: types.PackedTransition = .{};
pub var packed_layer: types.PackedLayer = .{ .Grid = .{} };
pub var packed_transforms: types.PackedTransforms = .{};
pub var packed_responsive: types.PackedResponsive = .{};
const hashStyle = @import("HashStyle.zig").hashStyle;
const StringTable = @import("StringTable.zig").StringTable;

const PackedFieldPtrs = @import("UITree.zig").PackedFieldPtrs;
const Packer = @import("Packer.zig");
const buildClassString = @import("UITree.zig").buildClassString;

const Accessibility = @import("Accessibility.zig");

const VisualModule = @import("configure/visual.zig");
const configureVisual = VisualModule.configureVisual;
pub const checkVisual = VisualModule.checkVisual;

pub fn getOrPutAndUpdateHash(hash: u32, comptime T: type, data: T, cache: anytype, pool: anytype) !*const T {
    if (cache.get(hash)) |ptr| {
        // 1. The Logic: Value Identity vs. Memory Identity
        // Two things can be "Value Identical" but "Memory Distinct."
        //
        // Value Identity (The Hash): The definition of the style hasn't changed
        // (e.g., it's still "Red Button with 10px Padding"). The hash is the same.
        //
        // Memory Identity (The Pointers): The underlying data (e.g., the slice of transitions or the string name)
        // lives in the frame arena. Since the arena is wiped every frame, the address of that data changes every
        // single frame (e.g., from 0xAAAA in Frame 1 to 0xBBBB in Frame 2).
        //
        // If you returned the cached pointer without updating the data, your frameent ptr would point to 0xAAAA (Frame 1's memory), which is now garbage/overwritten.
        // "Stable Container, Volatile Content" (or "Flyweight with Frame-Local Backing").
        // We replace the current value with the new generated one, as during transition creation we only allcoate on the frame,
        // so if we create a new style with new transition, then the old one will be used if we do not update the data
        // Imagine we have frame 1, have a transition packed visual, then frame 2 deallocates this sicne it uses the frame arena,
        // then we check in the cache if the hash exists, it does since it's the same style, but we must update the ptr value data, with the new data
        // event though its the same since teh transition allocation is on this frame now.
        ptr.* = data;
        return ptr;
    }

    const new_ptr = try pool.create();
    new_ptr.* = data;
    try cache.put(hash, new_ptr);

    return new_ptr;
}

const LayoutModule = @import("configure/layout.zig");
const configureLayouts = LayoutModule.configureLayouts;
const configureResponsive = LayoutModule.configureResponsive;
const configurePositions = LayoutModule.configurePositions;
const configureMarginsPaddings = LayoutModule.configureMarginsPaddings;

const MotionModule = @import("configure/motion.zig");
const configureTransforms = MotionModule.configureTransforms;
const configureAnimations = MotionModule.configureAnimations;
const configureInteractive = MotionModule.configureInteractive;

pub var inherited_color: ?Vapor.Types.Color = null;

pub var hash_id: bool = false;
pub fn configure(ui_ctx: *UIContext, elem_decl: ElemDecl) *UINode {
    hash_id = false;
    const stack = ui_ctx.stack orelse @panic("vapor: a component was created outside a render function");
    const current_open = stack.ptr orelse @panic("vapor: a component was created outside a render function");
    const parent = current_open.parent orelse @panic("vapor: element has no parent");
    const style = elem_decl.style;

    // Early exit if style hasn't changed

    if (elem_decl.elem_type == .ListItem) {
        if (parent.type != .List) {
            Vapor.printlnErr("ListItem must be a child of a List, Otherwise reconciliation will fail\n", .{});
        }
    }

    if (style != null and style.?.id != null) {
        current_open.uuid = style.?.id.?;
    }
    current_open.finger_print +%= parent.finger_print;
    current_open.finger_print +%= @intFromEnum(current_open.type);
    if (elem_decl.elem_type == .Svg) {
        current_open.text = elem_decl.svg;
        current_open.finger_print +%= hashKey(elem_decl.svg);
    } else if (elem_decl.text) |text| {
        current_open.text = text;
        current_open.finger_print +%= hashKey(text);
    }

    if (elem_decl.hover_style_fields) |fields| {
        const hover_style_fields = Vapor.arena(.frame).create([]const types.StyleFields) catch |err| blk_hover: {
            Vapor.printlnErr("hover style: could not allocate, hover styles skipped: {any}", .{err});
            break :blk_hover null;
        } orelse return current_open;
        hover_style_fields.* = fields;
        current_open.hover_style_fields = hover_style_fields;
    }

    if (elem_decl.target) |target| {
        current_open.target = target;
        current_open.finger_print +%= hashKey(target);
    }

    if (elem_decl.text_field_params) |params| blk_tfp: {
        const text_field_params = Vapor.arena(.frame).create(types.TextFieldParams) catch |err| {
            Vapor.printlnErr("text field: could not allocate params, field renders without them: {any}", .{err});
            break :blk_tfp;
        };
        text_field_params.* = params;
        current_open.text_field_params = text_field_params;
        switch (params) {
            .string => |string| {
                var value: []const u8 = "";
                if (string.value_ptr) |ptr| {
                    value = ptr[0..string.value_len];
                }
                var default_value: []const u8 = "";
                if (string.default_ptr) |ptr| {
                    default_value = ptr[0..string.default_len];
                }
                current_open.finger_print +%= hashKey(value);
                current_open.finger_print +%= hashKey(default_value);
                // current_open.finger_print +%= hashKey(string.default orelse "");
                current_open.finger_print +%= @intFromEnum(string.type);
            },
            else => {},
        }
    }

    if (elem_decl.accessibility) |accessibility| {
        Accessibility.a11y_map.put(hashKey(current_open.uuid), accessibility) catch |err| {
            std.log.err("Error adding accessibility {any}\n", .{err});
        };
        current_open.accessibility = true;
        current_open.finger_print +%= hashKey(Accessibility.toAttributeString(accessibility));
    }

    current_open.href = elem_decl.href;
    current_open.type = elem_decl.elem_type;
    current_open.name = elem_decl.name;
    current_open.morph = elem_decl.morph;

    if (current_open.href) |href| {
        current_open.finger_print +%= hashKey(href);
    }

    if (elem_decl.inlineStyle) |inlineStyle| {
        if (inlineStyle.len > 0) {
            current_open.inlineStyle = inlineStyle;
            current_open.style_hash +%= hashKey(inlineStyle);
        }
    }

    if (elem_decl.video) |video| {
        current_open.video = video;
        if (video.src) |src| {
            current_open.finger_print +%= hashKey(src);
        }
        current_open.finger_print +%= @intFromBool(video.autoplay);
        current_open.finger_print +%= @intFromBool(video.muted);
        current_open.finger_print +%= @intFromBool(video.loop);
        current_open.finger_print +%= @intFromBool(video.controls);
    }

    if (current_open.event_handlers) |handlers| {
        for (handlers.handlers.items) |handler| {
            current_open.finger_print +%= @intFromEnum(handler.event_type);
        }
    }

    current_open.props_hash = current_open.finger_print;
    // current_open.finger_print +%= hashKey(current_open.uuid);

    // this adds 60ms
    if (style) |s| outer_style: {
        var hash_l: u32 = 0;
        var hash_v: u32 = 0;
        var hash_p: u32 = 0;
        var hash_mp: u32 = 0;
        var hash_i: u32 = 0;
        var hash_a: u32 = 0;
        var hash_t: u32 = 0;
        var hash_r: u32 = 0;
        var hash_tv: u32 = 0;

        packed_position = .{};
        packed_layout = .{};
        packed_margins_paddings = .{};
        packed_visual = .{};
        packed_animations = .{};
        packed_interactive = .{};
        packed_transition = .{};
        packed_layer = .{ .Grid = .{} };
        packed_transforms = .{};
        packed_responsive = .{};
        target_packed_visual = .{};

        current_open.packed_field_ptrs = PackedFieldPtrs{};
        if (s.style_id != null) {
            hash_id = true;
            current_open.class = s.style_id.?;
        }

        var additonal_classes: ?[]const u8 = null;

        if (s.visual) |visual| {
            if (visual.edges) |e| {
                additonal_classes = e;
            }
        }

        hash_l = configureLayouts(current_open, s);
        hash_v = configureVisual(current_open, s);

        if (s.target_visual) |visual| {
            checkVisual(&visual, &target_packed_visual);
            hash_tv = std.hash.XxHash32.hash(0, std.mem.asBytes(&target_packed_visual));
        }

        hash_p = configurePositions(current_open, s);
        hash_mp = configureMarginsPaddings(current_open, s);
        hash_i = configureInteractive(current_open, s);
        hash_a = configureAnimations(current_open, elem_decl);
        hash_t = configureTransforms(current_open, s);
        hash_r = configureResponsive(current_open, s);

        // ** Packed Animations and Interactive **

        current_open.style_hash +%= hash_l;
        current_open.style_hash +%= hash_p;
        current_open.style_hash +%= hash_mp;
        current_open.style_hash +%= hash_v;
        current_open.style_hash +%= hash_a;
        current_open.style_hash +%= hash_i;
        current_open.style_hash +%= hash_t;
        current_open.style_hash +%= hash_r;
        current_open.style_hash +%= hash_tv;

        // This adds 40ms for 10000 rows
        if (current_open.target) |target| {
            const class = Vapor.frame.fmt("t_vis-{s}", .{target});
            const new_class_hash = hashKey(class);
            _ = Vapor.class_cache.get(new_class_hash) orelse {
                Vapor.class_cache.set(new_class_hash, .defined) catch |err| {
                    Vapor.printlnErr("class cache: not recorded, rule may be re-emitted: {any}", .{err});
                };
                Vapor.generator.writeTargetStyle(current_open, hash_tv, &target_packed_visual);
            };
        }

        if (s.style_id != null) {
            const class = current_open.class.?;
            const new_class_hash = hashKey(class);
            _ = Vapor.class_cache.get(new_class_hash) orelse {
                Vapor.class_cache.set(new_class_hash, .defined) catch |err| {
                    Vapor.printlnErr("class cache: not recorded, rule may be re-emitted: {any}", .{err});
                };
                Vapor.generator.writeNodeStyle(current_open);
            };
        } else {
            if (2316552965 == current_open.style_hash) {
                current_open.class = "";
                current_open.style_hash = 0;
                break :outer_style;
            }
            // This adds 2ms for 10000 nodes
            buildClassString(
                &current_open.packed_field_ptrs.?,
                current_open,
                hash_l,
                hash_p,
                hash_mp,
                hash_v,
                hash_a,
                hash_i,
                hash_t,
                hash_r,
                hash_tv,
                additonal_classes,
            ) catch |err| {
                Vapor.printlnErr("Could not build class string {any}\n", .{err});
            };
        }
    }

    current_open.state_type = elem_decl.state_type;
    current_open.aria_label = elem_decl.aria_label;
    current_open.alt = elem_decl.alt;

    current_open.hooks_hash +%= current_open.on_callbacks[0];

    current_open.finger_print +%= current_open.style_hash;
    current_open.finger_print +%= current_open.hooks_hash;

    current_open.identity_hash +%= current_open.props_hash;
    current_open.identity_hash +%= current_open.style_hash;
    current_open.identity_hash +%= @intFromEnum(current_open.type);

    return current_open;
}

pub fn configureByNode(ui_node: ?*UINode, elem_decl: ElemDecl) *UINode {
    hash_id = false;
    const current_open = ui_node orelse @panic("vapor: configure called without a node");
    const parent = current_open.parent orelse @panic("vapor: element has no parent");
    const style = elem_decl.style orelse @panic("vapor: configureByNode called without a style");
    inherited_color = null;

    // Early exit if style hasn't changed
    if (elem_decl.elem_type == .ListItem) {
        if (parent.type != .List) {
            Vapor.printlnErr("ListItem must be a child of a List, Otherwise reconciliation will fail\n", .{});
        }
    }

    if (style.id != null) {
        current_open.uuid = style.id.?;
    }
    current_open.finger_print +%= parent.finger_print;
    current_open.finger_print +%= @intFromEnum(current_open.type);
    if (elem_decl.elem_type == .Svg) {
        current_open.text = elem_decl.svg;
        current_open.finger_print +%= hashKey(elem_decl.svg);
    } else if (elem_decl.text) |text| {
        current_open.text = text;
        current_open.finger_print +%= hashKey(text);
    }

    if (elem_decl.text_field_params) |params| blk_tfp: {
        const text_field_params = Vapor.arena(.frame).create(types.TextFieldParams) catch |err| {
            Vapor.printlnErr("text field: could not allocate params, field renders without them: {any}", .{err});
            break :blk_tfp;
        };
        text_field_params.* = params;
        current_open.text_field_params = text_field_params;
        switch (params) {
            .radio => |radio| {
                var value: []const u8 = "";
                if (radio.value_ptr) |ptr| {
                    value = ptr[0..radio.value_len];
                }
                var default_value: []const u8 = "";
                if (radio.default_ptr) |ptr| {
                    default_value = ptr[0..radio.default_len];
                }
                current_open.finger_print +%= hashKey(value);
                current_open.finger_print +%= hashKey(default_value);
                current_open.finger_print +%= @intFromEnum(radio.type);
            },

            .string => |string| {
                var value: []const u8 = "";
                if (string.value_ptr) |ptr| {
                    value = ptr[0..string.value_len];
                }
                var default_value: []const u8 = "";
                if (string.default_ptr) |ptr| {
                    default_value = ptr[0..string.default_len];
                }
                current_open.finger_print +%= hashKey(value);
                current_open.finger_print +%= hashKey(default_value);
                current_open.finger_print +%= @intFromEnum(string.type);
            },
            .email => |email| {
                var value: []const u8 = "";
                if (email.value_ptr) |ptr| {
                    value = ptr[0..email.value_len];
                }
                var default_value: []const u8 = "";
                if (email.default_ptr) |ptr| {
                    default_value = ptr[0..email.default_len];
                }
                current_open.finger_print +%= hashKey(value);
                current_open.finger_print +%= hashKey(default_value);
                current_open.finger_print +%= @intFromEnum(email.type);
            },
            .telephone => |telephone| {
                var value: []const u8 = "";
                if (telephone.value_ptr) |ptr| {
                    value = ptr[0..telephone.value_len];
                }
                var default_value: []const u8 = "";
                if (telephone.default_ptr) |ptr| {
                    default_value = ptr[0..telephone.default_len];
                }
                current_open.finger_print +%= hashKey(value);
                current_open.finger_print +%= hashKey(default_value);
                current_open.finger_print +%= @intFromEnum(telephone.type);
            },
            .file => |file| {
                var value: []const u8 = "";
                if (file.value_ptr) |ptr| {
                    value = ptr[0..file.value_len];
                }
                var default_value: []const u8 = "";
                if (file.default_ptr) |ptr| {
                    default_value = ptr[0..file.default_len];
                }
                current_open.finger_print +%= hashKey(value);
                current_open.finger_print +%= hashKey(default_value);
                current_open.finger_print +%= @intFromEnum(file.type);
            },
            .date => |date| {
                var value: []const u8 = "";
                if (date.value_ptr) |ptr| {
                    value = ptr[0..date.value_len];
                }
                var default_value: []const u8 = "";
                if (date.default_ptr) |ptr| {
                    default_value = ptr[0..date.default_len];
                }
                current_open.finger_print +%= hashKey(value);
                current_open.finger_print +%= hashKey(default_value);
                current_open.finger_print +%= @intFromEnum(date.type);
            },
            .password => |password| {
                var value: []const u8 = "";
                if (password.value_ptr) |ptr| {
                    value = ptr[0..password.value_len];
                }
                var default_value: []const u8 = "";
                if (password.default_ptr) |ptr| {
                    default_value = ptr[0..password.default_len];
                }
                current_open.finger_print +%= hashKey(value);
                current_open.finger_print +%= hashKey(default_value);
                current_open.finger_print +%= @intFromEnum(password.type);
            },
            .int => |number| {
                current_open.finger_print +%= @as(u32, @intCast(number.value orelse 0));
                current_open.finger_print +%= @as(u32, @intCast(number.default orelse 0));
                current_open.finger_print +%= @intFromEnum(number.type);
            },
            .float => |number| {
                current_open.finger_print +%= @as(u32, @intFromFloat(number.value orelse 0));
                current_open.finger_print +%= @as(u32, @intFromFloat(number.default orelse 0));
                current_open.finger_print +%= @intFromEnum(number.type);
            },
        }
    }

    if (elem_decl.hover_style_fields) |fields| {
        const hover_style_fields = Vapor.arena(.frame).create([]const types.StyleFields) catch |err| blk_hover: {
            Vapor.printlnErr("hover style: could not allocate, hover styles skipped: {any}", .{err});
            break :blk_hover null;
        } orelse return current_open;
        hover_style_fields.* = fields;
        current_open.hover_style_fields = hover_style_fields;
    }

    if (elem_decl.accessibility) |accessibility| {
        Accessibility.a11y_map.put(hashKey(current_open.uuid), accessibility) catch |err| {
            std.log.err("Error adding accessibility {any}\n", .{err});
        };
        current_open.accessibility = true;
        current_open.finger_print +%= hashKey(Accessibility.toAttributeString(accessibility));
    }

    current_open.href = elem_decl.href;
    current_open.src = elem_decl.src;
    current_open.type = elem_decl.elem_type;
    current_open.name = elem_decl.name;

    if (current_open.href) |href| {
        current_open.finger_print +%= hashKey(href);
    }

    if (elem_decl.inlineStyle) |inlineStyle| {
        if (inlineStyle.len > 0) {
            current_open.inlineStyle = inlineStyle;
            current_open.style_hash +%= hashKey(inlineStyle);
        }
    }

    if (elem_decl.video) |video| {
        current_open.video = video;
        if (video.src) |src| {
            current_open.finger_print +%= hashKey(src);
        }
        current_open.finger_print +%= @intFromBool(video.autoplay);
        current_open.finger_print +%= @intFromBool(video.muted);
        current_open.finger_print +%= @intFromBool(video.loop);
        current_open.finger_print +%= @intFromBool(video.controls);
    }

    current_open.props_hash = current_open.finger_print;

    // this adds 60ms
    var hash_l: u32 = 0;
    var hash_v: u32 = 0;
    var hash_p: u32 = 0;
    var hash_mp: u32 = 0;
    var hash_i: u32 = 0;
    var hash_a: u32 = 0;
    var hash_t: u32 = 0;
    var hash_r: u32 = 0;
    var hash_tv: u32 = 0;

    hash_l = 0;
    hash_v = 0;
    hash_p = 0;
    hash_mp = 0;
    hash_i = 0;
    hash_a = 0;
    hash_t = 0;
    hash_r = 0;
    hash_tv = 0;

    packed_position = .{};
    packed_layout = .{};
    packed_margins_paddings = .{};
    packed_visual = .{};
    packed_animations = .{};
    packed_interactive = .{};
    packed_transition = .{};
    packed_layer = .{ .Grid = .{} };
    packed_transforms = .{};
    packed_responsive = .{};
    target_packed_visual = .{};

    current_open.packed_field_ptrs = PackedFieldPtrs{};
    if (style.style_id != null) {
        hash_id = true;
        current_open.class = style.style_id.?;
    }

    var additonal_classes: ?[]const u8 = null;

    if (style.visual) |visual| {
        if (visual.edges) |e| {
            additonal_classes = e;
        }
    }

    hash_l = configureLayouts(current_open, style);
    hash_v = configureVisual(current_open, style);

    if (style.target_visual) |visual| {
        checkVisual(&visual, &target_packed_visual);
        hash_tv = std.hash.XxHash32.hash(0, std.mem.asBytes(&target_packed_visual));
    }

    hash_p = configurePositions(current_open, style);
    hash_mp = configureMarginsPaddings(current_open, style);
    hash_i = configureInteractive(current_open, style);
    hash_a = configureAnimations(current_open, elem_decl);
    hash_t = configureTransforms(current_open, style);
    hash_r = configureResponsive(current_open, style);

    // ** Packed Animations and Interactive **

    current_open.style_hash +%= hash_l;
    current_open.style_hash +%= hash_p;
    current_open.style_hash +%= hash_mp;
    current_open.style_hash +%= hash_v;
    current_open.style_hash +%= hash_a;
    current_open.style_hash +%= hash_i;
    current_open.style_hash +%= hash_t;
    current_open.style_hash +%= hash_r;
    current_open.style_hash +%= hash_tv;

    // This adds 40ms for 10000 rows
    if (current_open.target) |target| {
        const class = Vapor.frame.fmt("t_vis-{s}", .{target});
        const new_class_hash = hashKey(class);
        _ = Vapor.class_cache.get(new_class_hash) orelse {
            Vapor.class_cache.set(new_class_hash, .defined) catch |err| {
                Vapor.printlnErr("class cache: not recorded, rule may be re-emitted: {any}", .{err});
            };
            Vapor.generator.writeTargetStyle(current_open, hash_tv, &target_packed_visual);
        };
    }

    if (style.style_id != null) {
        const class = current_open.class.?;
        const new_class_hash = hashKey(class);
        _ = Vapor.class_cache.get(new_class_hash) orelse {
            Vapor.class_cache.set(new_class_hash, .defined) catch |err| {
                Vapor.printlnErr("class cache: not recorded, rule may be re-emitted: {any}", .{err});
            };
            Vapor.generator.writeNodeStyle(current_open);
        };
    } else {
        // This adds 2ms for 10000 nodes
        buildClassString(
            &current_open.packed_field_ptrs.?,
            current_open,
            hash_l,
            hash_p,
            hash_mp,
            hash_v,
            hash_a,
            hash_i,
            hash_t,
            hash_r,
            hash_tv,
            additonal_classes,
        ) catch |err| {
            Vapor.printlnErr("Could not build class string {any}\n", .{err});
        };
    }

    current_open.state_type = elem_decl.state_type;
    current_open.aria_label = elem_decl.aria_label;
    current_open.alt = elem_decl.alt;

    current_open.hooks_hash +%= current_open.on_callbacks[0];
    current_open.finger_print +%= current_open.style_hash;
    current_open.finger_print +%= current_open.hooks_hash;

    current_open.identity_hash +%= current_open.props_hash;
    current_open.identity_hash +%= current_open.style_hash;
    current_open.identity_hash +%= @intFromEnum(current_open.type);

    return current_open;
}

pub fn configurePlainByNode(ui_node: ?*UINode, elem_decl: ElemDecl) *UINode {
    hash_id = false;
    const current_open = ui_node orelse @panic("vapor: configure called without a node");
    const parent = current_open.parent orelse @panic("vapor: element has no parent");
    inherited_color = null;

    // Early exit if style hasn't changed

    if (elem_decl.elem_type == .ListItem) {
        if (parent.type != .List) {
            Vapor.printlnErr("ListItem must be a child of a List, Otherwise reconciliation will fail\n", .{});
        }
    }

    current_open.finger_print +%= parent.finger_print;
    current_open.finger_print +%= @intFromEnum(current_open.type);
    if (elem_decl.elem_type == .Svg) {
        current_open.text = elem_decl.svg;
        current_open.finger_print +%= hashKey(elem_decl.svg);
    } else if (elem_decl.text) |text| {
        current_open.text = text;
        current_open.finger_print +%= hashKey(text);
    }

    if (elem_decl.text_field_params) |params| blk_tfp: {
        const text_field_params = Vapor.arena(.frame).create(types.TextFieldParams) catch |err| {
            Vapor.printlnErr("text field: could not allocate params, field renders without them: {any}", .{err});
            break :blk_tfp;
        };
        text_field_params.* = params;
        current_open.text_field_params = text_field_params;
        switch (params) {
            .string => |string| {
                var value: []const u8 = "";
                if (string.value_ptr) |ptr| {
                    value = ptr[0..string.value_len];
                }
                var default_value: []const u8 = "";
                if (string.default_ptr) |ptr| {
                    default_value = ptr[0..string.default_len];
                }
                current_open.finger_print +%= hashKey(value);
                current_open.finger_print +%= hashKey(default_value);
                current_open.finger_print +%= @intFromEnum(string.type);
            },
            .radio => |radio| {
                var value: []const u8 = "";
                if (radio.value_ptr) |ptr| {
                    value = ptr[0..radio.value_len];
                }
                var default_value: []const u8 = "";
                if (radio.default_ptr) |ptr| {
                    default_value = ptr[0..radio.default_len];
                }
                current_open.finger_print +%= hashKey(value);
                current_open.finger_print +%= hashKey(default_value);
                current_open.finger_print +%= @intFromEnum(radio.type);
            },
            .email => |email| {
                var value: []const u8 = "";
                if (email.value_ptr) |ptr| {
                    value = ptr[0..email.value_len];
                }
                var default_value: []const u8 = "";
                if (email.default_ptr) |ptr| {
                    default_value = ptr[0..email.default_len];
                }
                current_open.finger_print +%= hashKey(value);
                current_open.finger_print +%= hashKey(default_value);
                current_open.finger_print +%= @intFromEnum(email.type);
            },
            .telephone => |telephone| {
                var value: []const u8 = "";
                if (telephone.value_ptr) |ptr| {
                    value = ptr[0..telephone.value_len];
                }
                var default_value: []const u8 = "";
                if (telephone.default_ptr) |ptr| {
                    default_value = ptr[0..telephone.default_len];
                }
                current_open.finger_print +%= hashKey(value);
                current_open.finger_print +%= hashKey(default_value);
                current_open.finger_print +%= @intFromEnum(telephone.type);
            },
            .file => |file| {
                var value: []const u8 = "";
                if (file.value_ptr) |ptr| {
                    value = ptr[0..file.value_len];
                }
                var default_value: []const u8 = "";
                if (file.default_ptr) |ptr| {
                    default_value = ptr[0..file.default_len];
                }
                current_open.finger_print +%= hashKey(value);
                current_open.finger_print +%= hashKey(default_value);
                current_open.finger_print +%= @intFromEnum(file.type);
            },
            .date => |date| {
                var value: []const u8 = "";
                if (date.value_ptr) |ptr| {
                    value = ptr[0..date.value_len];
                }
                var default_value: []const u8 = "";
                if (date.default_ptr) |ptr| {
                    default_value = ptr[0..date.default_len];
                }
                current_open.finger_print +%= hashKey(value);
                current_open.finger_print +%= hashKey(default_value);
                current_open.finger_print +%= @intFromEnum(date.type);
            },
            .password => |password| {
                var value: []const u8 = "";
                if (password.value_ptr) |ptr| {
                    value = ptr[0..password.value_len];
                }
                var default_value: []const u8 = "";
                if (password.default_ptr) |ptr| {
                    default_value = ptr[0..password.default_len];
                }
                current_open.finger_print +%= hashKey(value);
                current_open.finger_print +%= hashKey(default_value);
                current_open.finger_print +%= @intFromEnum(password.type);
            },
            .int => |number| {
                current_open.finger_print +%= @as(u32, @intCast(number.value orelse 0));
                current_open.finger_print +%= @as(u32, @intCast(number.default orelse 0));
                current_open.finger_print +%= @intFromEnum(number.type);
            },
            .float => |number| {
                current_open.finger_print +%= @as(u32, @intFromFloat(number.value orelse 0));
                current_open.finger_print +%= @as(u32, @intFromFloat(number.default orelse 0));
                current_open.finger_print +%= @intFromEnum(number.type);
            },
        }
    }

    if (elem_decl.accessibility) |accessibility| {
        Accessibility.a11y_map.put(hashKey(current_open.uuid), accessibility) catch |err| {
            std.log.err("Error adding accessibility {any}\n", .{err});
        };
        current_open.accessibility = true;
        current_open.finger_print +%= hashKey(Accessibility.toAttributeString(accessibility));
    }

    current_open.href = elem_decl.href;
    current_open.src = elem_decl.src;
    current_open.type = elem_decl.elem_type;
    current_open.name = elem_decl.name;

    if (current_open.href) |href| {
        current_open.finger_print +%= hashKey(href);
    }

    if (elem_decl.inlineStyle) |inlineStyle| {
        if (inlineStyle.len > 0) {
            current_open.inlineStyle = inlineStyle;
            current_open.style_hash +%= hashKey(inlineStyle);
        }
    }

    if (elem_decl.video) |video| {
        current_open.video = video;
        if (video.src) |src| {
            current_open.finger_print +%= hashKey(src);
        }
        current_open.finger_print +%= @intFromBool(video.autoplay);
        current_open.finger_print +%= @intFromBool(video.muted);
        current_open.finger_print +%= @intFromBool(video.loop);
        current_open.finger_print +%= @intFromBool(video.controls);
    }

    current_open.props_hash = current_open.finger_print;

    // this adds 60ms
    current_open.state_type = elem_decl.state_type;
    current_open.aria_label = elem_decl.aria_label;
    current_open.alt = elem_decl.alt;

    current_open.finger_print +%= current_open.style_hash;

    return current_open;
}
