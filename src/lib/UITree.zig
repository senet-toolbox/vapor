const std = @import("std");
const Vapor = @import("Vapor.zig");
const KeyGenerator = @import("Key.zig").KeyGenerator;
const utils = @import("utils.zig");
const hashKey = utils.hashKey;
const Writer = @import("Writer.zig");
const Packer = @import("Packer.zig");
const ClassType = @import("ClassCache.zig").ClassType;
const Configuration = @import("Configuration.zig");
const Accessibility = @import("Accessibility.zig").Accessibility;
const Abstractions = @import("Abstractions.zig");

const ManagedMemoryPool = Abstractions.ManagedMemoryPool;

const types = @import("types.zig");

pub const Item = struct {
    ptr: ?*UINode,
    next: ?*Item = null,
};

const Style = types.Style;
const EType = types.ElementType;
const RenderCommand = types.RenderCommand;
const ElemDecl = types.ElementDeclaration;
const Direction = types.Direction;
const HooksIds = types.HooksIds;
const InputParams = types.InputParams;

pub const StyleInfo = struct {
    packed_field_ptrs: PackedFieldPtrs,
    style_hashes: [10]u32,
    style_hash: u32,
    class: ?[]const u8 = null,
};

pub var style_info_map: std.AutoHashMap(u32, *StyleInfo) = undefined;
pub const PackedFieldPtrs = struct {
    visual_ptr: ?*const types.PackedVisual = null,
    layout_ptr: ?*const types.PackedLayout = null,
    position_ptr: ?*const types.PackedPosition = null,
    margins_paddings_ptr: ?*const types.PackedMarginsPaddings = null,
    animations_ptr: ?*const types.PackedAnimations = null,
    interactive_ptr: ?*const types.PackedInteractive = null,
    transforms_ptr: ?*const types.PackedTransforms = null,
    responsive_ptr: ?*const types.PackedResponsive = null,
    target_ptr: ?*const types.PackedVisual = null,
};

pub var ui_nodes: []UINode = undefined;
pub const UIContext = @This();
root: ?*UINode = null,
current_parent: ?*UINode = null,
stack: ?*Item = null,
root_stack_ptr: ?*Item = null,
node_pool: ManagedMemoryPool(UINode),
memory_pool: ManagedMemoryPool(Item),
current_offset: f32 = 0,
ui_tree: ?*CommandsTree = null,

pub const CommandsTree = struct {
    node: *RenderCommand,
    children: std.ArrayListUnmanaged(*CommandsTree) = undefined,
};

pub const UINode = struct {
    dirty: bool = false,
    parent: ?*UINode = null,
    type: EType = EType.FlexBox,
    text: ?[]const u8 = null,
    uuid: []const u8 = "",
    uuid_buf: [32]u8 = undefined,
    href: ?[]const u8 = null,
    src: ?[]const u8 = null,
    index: usize = 0,
    hooks: HooksIds = .{},
    text_field_params: ?*types.TextFieldParams = null,
    event_type: ?types.EventType = null,
    state_type: types.StateType = .pure,
    aria_label: ?[]const u8 = null,
    alt: ?[]const u8 = null,
    class: ?[]const u8 = null,
    animation_exit: ?[]const u8 = null,
    packed_field_ptrs: ?PackedFieldPtrs = null, // TODO: This is 28 bytes
    children_count: usize = 0,
    finger_print: u32 = 0,
    subtree_hash: u32 = 0,
    style_hash: u32 = 0,
    style_changed: bool = false,
    props_hash: u32 = 0,
    props_changed: bool = false,
    hooks_hash: u32 = 0,
    hooks_changed: bool = false,
    hash: u32 = 0,
    prev_style_hash: u32 = 0,
    prev_style_hash_computed: u32 = 0,
    level: ?u8 = null,
    video: ?*const types.Video = null,
    event_handlers: ?*Vapor.EventHandlers = null,
    on_hover: bool = false,
    on_leave: bool = false,
    name: ?[]const u8 = null,
    accessibility: bool = false,
    direction: Direction = .row,
    column_count: ?u8 = null,
    spacing: ?u8 = null,

    first_child: ?*UINode = null, // "child" in React terms
    next_sibling: ?*UINode = null, // "sibling" in React terms
    last_child: ?*UINode = null, // +4 bytes, but O(1) append
    hover_style_fields: ?*[]const types.StyleFields = null,
    inlineStyle: ?[]const u8 = null,
    style_hashes: [10]u32 = .{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }, // Direct access, no hashmap
    can_have_children: bool = true,
    // mount, update, destroy, unknown, resizer,
    on_callbacks: [5]u32 = [5]u32{ 0, 0, 0, 0, 0 },
    morph: bool = false,
    prev_uuid: []const u8 = "", // the uuid this node had in the DOM before this frame
    uuid_changed: bool = false, // DOM needs a rename / re-id
    unkeyed_child_count: usize = 0,
    /// True once `.id()` or `.src()` has replaced the generated uuid. The
    /// unkeyed slot taken by `setUUID` is refunded on the first override only;
    /// refunding twice would renumber every later sibling, or underflow.
    uuid_is_user_set: bool = false,

    // uuid
    identity_hash: u32 = 0,
    content_hash: u32 = 0,
    structural_hash: u32 = 0,
    layer: Vapor.Types.Layers = .none,
    target: ?[]const u8 = null,
    cycle: bool = true,

    /// Add a child to this node (prepends - O(1))
    /// Note: Children will be in reverse order of insertion
    pub fn addChild(parent: *UINode, child: *UINode) void {
        child.parent = parent;
        child.next_sibling = parent.first_child;
        parent.first_child = child;
        parent.children_count += 1;
    }

    pub fn appendChild(parent: *UINode, child: *UINode) void {
        child.parent = parent;
        child.next_sibling = null;
        parent.children_count += 1;

        if (parent.last_child) |last| {
            last.next_sibling = child;
        } else {
            parent.first_child = child;
        }
        parent.last_child = child;
    }

    /// Get the next child (for iteration)
    /// Usage:
    ///   var child = node.first_child;
    ///   while (child) |c| {
    ///       // process c
    ///       child = c.nextChild();
    ///   }
    pub fn nextChild(self: *UINode) ?*UINode {
        return self.next_sibling;
    }

    /// Get child by index - O(n)
    /// Returns null if index is out of bounds
    pub fn childAt(self: *UINode, target_index: usize) ?*UINode {
        var current = self.first_child;
        var i: usize = 0;

        while (current) |child| {
            if (i == target_index) {
                return child;
            }
            i += 1;
            current = child.next_sibling;
        }

        return null;
    }

    /// Returns the unkeyed numbering slot that `setUUID` took for this node.
    ///
    /// Children without an explicit id are named from a running count of their
    /// unkeyed siblings. When a caller overrides the uuid with `.id()` or
    /// `.src()` the node stops being unkeyed, so its slot goes back and later
    /// siblings keep the names they already had.
    ///
    /// Only the first override refunds. `.src(...).id(...)`, or two `.id()`
    /// calls, would otherwise decrement twice for one slot — renumbering every
    /// later sibling, and underflowing the usize once the count reaches zero.
    pub fn refundUnkeyedSlot(self: *UINode) void {
        if (self.uuid_is_user_set) return;
        self.uuid_is_user_set = true;
        if (self.uuid.len == 0) return; // setUUID has not run; nothing was taken
        const parent = self.parent orelse return;
        if (parent.unkeyed_child_count == 0) return;
        parent.unkeyed_child_count -= 1;
    }

    /// Iterator for convenient for-loop syntax
    /// Usage:
    ///   for (node.children()) |child| {
    ///       // process child
    ///   }
    pub fn children(self: *UINode) ChildIterator {
        return .{ .current = self.first_child };
    }

    pub const ChildIterator = struct {
        current: ?*UINode,

        pub fn next(self: *ChildIterator) ?*UINode {
            const node = self.current orelse return null;
            self.current = node.next_sibling;
            return node;
        }
    };
};

pub fn init(_: *UIContext, parent: ?*UINode, etype: EType) !*UINode {
    const node = Vapor.frame_arena.nodeAlloc() orelse return error.NodeAllocFailed;
    Vapor.frame_arena.incrementNodeCount();
    node.* = .{
        .parent = parent,
        .type = etype,
    };
    return node;
}

/// initContext initializes the UIContext and its associated memory pools
pub fn initContext(ui_ctx: *UIContext) !void {
    const allocator = Vapor.arena(.frame);
    ui_ctx.* = .{
        .node_pool = ManagedMemoryPool(UINode).init(allocator),
        .memory_pool = ManagedMemoryPool(Item).init(allocator),
    };

    // Either change the init function to return a pointer directly
    const node_ptr = try ui_ctx.init(null, EType.Block);
    node_ptr.uuid = "fabric_root_id";
    node_ptr.dirty = false;
    ui_ctx.root = node_ptr;
    const item: *Item = try ui_ctx.memory_pool.create();
    item.* = .{
        .ptr = node_ptr,
    };
    ui_ctx.root_stack_ptr = item;
    ui_ctx.stack = item;
}

pub fn deinit(_: *UIContext) void {}

pub fn stackRegister(ui_ctx: *UIContext, ui_node: *UINode) !void {
    uuid_depth += 1;
    Vapor.frame_arena.incrementItemCount();
    const item: *Item = try ui_ctx.memory_pool.create();
    const current_stack = ui_ctx.stack;
    item.* = .{
        .ptr = ui_node,
    };

    if (current_stack) |stack| {
        item.next = stack;
    }

    ui_ctx.stack = item;
}

pub fn stackPop(ui_ctx: *UIContext) void {
    const current_stack = ui_ctx.stack orelse return;
    ui_ctx.stack = current_stack.next;
}

pub var uuid_depth: usize = 0;
fn setUUID(parent: *UINode, child: *UINode) void {
    child.index = parent.children_count - 1; // positional index for layout/whatever

    if (child.uuid.len == 0) {
        const unkeyed_index = parent.unkeyed_child_count;
        parent.unkeyed_child_count += 1;

        const key = KeyGenerator.generateKey(
            &child.uuid_buf,
            child.type,
            parent.uuid,
            uuid_depth,
            unkeyed_index, // pass it in instead of using global state
        );
        child.uuid = key;
    }
}

pub var cache_count: u32 = 0;
pub var prev_style_hashes: std.AutoHashMap(u32, u32) = undefined;
pub fn captureHash(node: *UINode) void {
    // The hash cache is an optimisation; a miss just means recomputing.
    prev_style_hashes.put(node.hash, node.prev_style_hash_computed) catch return;
    if (node.packed_field_ptrs == null) return;
    if (style_info_map.get(node.prev_style_hash_computed) != null) return;
    const style_info = Vapor.arena(.persist).create(StyleInfo) catch return;
    style_info.* = .{
        .packed_field_ptrs = node.packed_field_ptrs.?,
        .style_hashes = node.style_hashes,
        .style_hash = node.style_hash,
        .class = node.class,
    };
    style_info_map.put(node.prev_style_hash_computed, style_info) catch return;
}

// Open takes a current stack and adds the elements depth first search
// Open and close get called in sequence
// depth first search
pub fn currentNode(ui_ctx: *UIContext) ?*UINode {
    const stack = ui_ctx.stack.?;
    return stack.ptr;
}

pub fn open(ui_ctx: *UIContext, elem_decl: ElemDecl) !*UINode {
    const stack = ui_ctx.stack.?;
    // Parent node
    const current_open = stack.ptr orelse @panic("vapor: a component was created outside a render function");
    var node = try ui_ctx.init(current_open, elem_decl.elem_type);
    node.level = elem_decl.level;
    node.can_have_children = elem_decl.can_have_children;

    current_open.appendChild(node);
    ui_ctx.stackRegister(node) catch |err| {
        Vapor.printlnSrcErr("Could not register node {any}", .{err}, @src());
        return err;
    };

    const style = elem_decl.style;
    if (style != null and style.?.id != null) {
        node.uuid = style.?.id.?;
    }

    setUUID(current_open, node);

    node.hash = hashKey(node.uuid);

    // Lookup previous hash
    if (prev_style_hashes.get(node.hash)) |old_hash| {
        node.prev_style_hash = old_hash;
    }

    if (!node.can_have_children) {
        ui_ctx.close();
    }

    return node;
}

pub fn openUnattached(ui_ctx: *UIContext, elem_decl: ElemDecl) !*UINode {
    const stack = ui_ctx.stack.?;
    // Parent node
    const current_open = stack.ptr orelse @panic("vapor: a component was created outside a render function");
    var node = try ui_ctx.init(current_open, elem_decl.elem_type);
    node.level = elem_decl.level;

    current_open.appendChild(node);
    uuid_depth += 1;

    const style = elem_decl.style;
    if (style != null and style.?.id != null) {
        node.uuid = style.?.id.?;
    }

    setUUID(current_open, node);

    node.hash = hashKey(node.uuid);

    // Lookup previous hash
    if (prev_style_hashes.get(node.hash)) |old_hash| {
        node.prev_style_hash = old_hash;
    }

    uuid_depth -= 1;

    return node;
}

// -----------------------------------------------------------------------------
// NEW HELPER FUNCTIONS
// -----------------------------------------------------------------------------

/// Helper to pack a color union (`.Literal` or `.Thematic`) into a PackedColor struct.
fn packColor(source_color: types.Color, packed_color: *types.PackedColor) void {
    switch (source_color) {
        .Literal => |color| {
            packed_color.* = .{ .has_color = true, .color = color };
        },
        .Thematic => |token| {
            packed_color.* = .{ .has_token = true, .token = token };
        },
    }
}

fn getOrPutAndUpdateHashLayout(
    hash: u32,
    data: types.PackedLayout,
) !*const @TypeOf(data) {
    if (Packer.layouts.get(hash)) |ptr| {
        return ptr;
    }

    const new_ptr = try Packer.layouts_pool.create();
    new_ptr.* = data;
    try Packer.layouts.put(hash, new_ptr);

    return new_ptr;
}

fn getOrPutAndUpdateHashPosition(
    hash: u32,
    data: types.PackedPosition,
) !*const @TypeOf(data) {
    if (Packer.positions.get(hash)) |ptr| {
        return ptr;
    }

    const new_ptr = try Packer.positions_pool.create();
    new_ptr.* = data;
    try Packer.positions.put(hash, new_ptr);

    return new_ptr;
}

fn getOrPutAndUpdateHashMarginsPadding(
    hash: u32,
    data: types.PackedMarginsPaddings,
) !*const @TypeOf(data) {
    if (Packer.margins_paddings.get(hash)) |ptr| {
        return ptr;
    }

    const new_ptr = try Packer.margins_paddings_pool.create();
    new_ptr.* = data;
    try Packer.margins_paddings.put(hash, new_ptr);

    return new_ptr;
}

fn getOrPutAndUpdateHashVisual(
    hash: u32,
    data: types.PackedVisual,
) !*const @TypeOf(data) {
    if (Packer.visuals.get(hash)) |ptr| {
        return ptr;
    }

    const new_ptr = try Packer.visuals_pool.create();
    new_ptr.* = data;
    try Packer.visuals.put(hash, new_ptr);

    return new_ptr;
}

fn getOrPutAndUpdateHashInteractive(
    hash: u32,
    data: types.PackedInteractive,
) !*const @TypeOf(data) {
    if (Packer.interactives.get(hash)) |ptr| {
        return ptr;
    }

    const new_ptr = try Packer.interactives_pool.create();
    new_ptr.* = data;
    try Packer.interactives.put(hash, new_ptr);

    return new_ptr;
}

fn getOrPutAndUpdateHashAnimation(
    hash: u32,
    data: types.PackedAnimations,
) !*const @TypeOf(data) {
    if (Packer.animations.get(hash)) |ptr| {
        return ptr;
    }

    const new_ptr = try Packer.animations_pool.create();
    new_ptr.* = data;
    try Packer.animations.put(hash, new_ptr);

    return new_ptr;
}

fn getOrPutAndUpdateHashTransform(
    hash: u32,
    data: types.PackedTransforms,
) !*const @TypeOf(data) {
    if (Packer.transforms.get(hash)) |ptr| {
        return ptr;
    }

    const new_ptr = try Packer.transforms_pool.create();
    new_ptr.* = data;
    try Packer.transforms.put(hash, new_ptr);

    return new_ptr;
}

pub var packed_layout: types.PackedLayout = .{};
pub var packed_position: types.PackedPosition = .{};
pub var packed_margins_paddings: types.PackedMarginsPaddings = .{};
pub var packed_visual: types.PackedVisual = .{};
pub var packed_animations: types.PackedAnimations = .{};
pub var packed_interactive: types.PackedInteractive = .{};
pub var packed_transition: types.PackedTransition = .{};
pub var packed_layer: types.PackedLayer = .{ .Grid = .{} };
pub var packed_transforms: types.PackedTransforms = .{};

pub var element_style_hash_map: std.AutoHashMap(u32, [10]u32) = undefined;
pub var class_string_cache: std.AutoHashMap(u32, []const u8) = undefined;
pub var global_classes: [10]u32 = .{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };
var buf: [128]u8 = undefined;

/// Compares the old class hash with the new class hash and decrements the old class if it exists
fn compareClobber(old_optional: ?[10]u32, new_class_hash: u32, index: usize, class_type: ClassType) !void {
    if (old_optional) |old| {
        if (old[index] != new_class_hash and old[index] != 0) {
            try Vapor.class_cache.decrement(old[index]);
            try Vapor.class_cache.set(new_class_hash, class_type);
        }
        return;
    }

    // If the old class is null we need to create a new class
    try Vapor.class_cache.set(new_class_hash, class_type);
}

fn updateClassRefCounts(old: [10]u32, new: [10]u32) void {
    inline for (1..8) |i| {
        if (old[i] != new[i]) {
            if (old[i] != 0) Vapor.class_cache.decrement(old[i]) catch {};
            if (new[i] != 0) Vapor.class_cache.set(new[i], classTypeFromIndex(i)) catch {};
        }
    }
}

fn classTypeFromIndex(comptime i: usize) ClassType {
    return switch (i) {
        0 => .base,
        1 => .layout,
        2 => .position,
        3 => .margin_padding,
        4 => .visual,
        5 => .animation,
        6 => .interactive,
        7 => .transform,
        else => unreachable,
    };
}

pub fn buildClassString(
    field_ptrs: *const PackedFieldPtrs,
    current_open: *UINode,
    hash_l: u32,
    hash_p: u32,
    hash_m: u32,
    hash_v: u32,
    hash_a: u32,
    hash_i: u32,
    hash_t: u32,
    hash_r: u32,
    hash_tv: u32,
    additonal_classes: ?[]const u8,
) !void {
    const hashes = [10]u32{ 0, hash_l, hash_p, hash_m, hash_v, hash_a, hash_i, hash_t, hash_r, hash_tv };
    const old = current_open.style_hashes;
    if (std.mem.eql(u32, &old, &hashes)) return;

    // Compute combined hash for class string cache
    var combined: u32 = 0;
    inline for (hashes) |h| combined = combined *% 31 +% h;

    // Check class string cache
    if (class_string_cache.get(combined)) |cached| {
        current_open.class = cached;
        current_open.style_hashes = hashes;
        updateClassRefCounts(old, hashes);
        return;
    }

    var writer: Writer = undefined;
    var writer_buf: [512]u8 = undefined;
    writer.init(&writer_buf);

    if (current_open.class) |class| {
        writer.write(class) catch return error.CouldNotAllocate;
        writer.writeByte(' ') catch return error.CouldNotAllocate;
    }

    if (field_ptrs.responsive_ptr != null and hash_r > 0) {
        const common = KeyGenerator.generateHashKey(&buf, hash_r, "resp");
        writer.write(common) catch return error.CouldNotAllocate;
        writer.writeByte(' ') catch return error.CouldNotAllocate;
        global_classes[8] = hash_r;
        try compareClobber(old, hash_r, 8, .responsive);
    }

    if (field_ptrs.layout_ptr != null and hash_l > 0) {
        const common = KeyGenerator.generateHashKey(&buf, hash_l, "lay");
        writer.write(common) catch return error.CouldNotAllocate;
        writer.writeByte(' ') catch return error.CouldNotAllocate;
        global_classes[1] = hash_l;
        try compareClobber(old, hash_l, 1, .layout);
    }

    if (field_ptrs.position_ptr != null and hash_p > 0) {
        const common = KeyGenerator.generateHashKey(&buf, hash_p, "pos");
        writer.write(common) catch return error.CouldNotAllocate;
        writer.writeByte(' ') catch return error.CouldNotAllocate;
        global_classes[2] = hash_p;
        try compareClobber(old, hash_p, 2, .position);
    }

    if (field_ptrs.margins_paddings_ptr != null and hash_m > 0) {
        const common = KeyGenerator.generateHashKey(&buf, hash_m, "mapa");
        writer.write(common) catch return error.CouldNotAllocate;
        writer.writeByte(' ') catch return error.CouldNotAllocate;
        global_classes[3] = hash_m;
        try compareClobber(old, hash_m, 3, .margin_padding);
    }

    if (field_ptrs.visual_ptr != null and hash_v > 0) {
        const common = KeyGenerator.generateHashKey(&buf, hash_v, "vis");
        writer.write(common) catch return error.CouldNotAllocate;
        writer.writeByte(' ') catch return error.CouldNotAllocate;
        global_classes[4] = hash_v;
        try compareClobber(old, hash_v, 4, .visual);
    }

    if (field_ptrs.animations_ptr != null and hash_a > 0) {
        const common = KeyGenerator.generateHashKey(&buf, hash_a, "anim");
        writer.write(common) catch return error.CouldNotAllocate;
        writer.writeByte(' ') catch return error.CouldNotAllocate;
        global_classes[5] = hash_a;
        try compareClobber(old, hash_a, 5, .animation);
    }

    if (field_ptrs.interactive_ptr != null and hash_i > 0) {
        const common = KeyGenerator.generateHashKey(&buf, hash_i, "intr");
        writer.write(common) catch return error.CouldNotAllocate;
        writer.writeByte(' ') catch return error.CouldNotAllocate;
        global_classes[6] = hash_i;
        try compareClobber(old, hash_i, 6, .interactive);
    }

    if (field_ptrs.transforms_ptr != null and hash_t > 0) {
        const common = KeyGenerator.generateHashKey(&buf, hash_t, "tran");
        writer.write(common) catch return error.CouldNotAllocate;
        writer.writeByte(' ') catch return error.CouldNotAllocate;
        global_classes[7] = hash_t;
        try compareClobber(old, hash_t, 7, .transform);
    }

    if (hash_tv > 0) {
        const common = KeyGenerator.generateHashKey(&buf, hash_tv, "t_vis");
        writer.write(common) catch return error.CouldNotAllocate;
        writer.writeByte(' ') catch return error.CouldNotAllocate;
        global_classes[9] = hash_tv;
        try compareClobber(old, hash_tv, 9, .responsive);
    }

    if (writer.buffer[0..writer.pos].len == 0) return;

    // We store the new class hash and list inside the element_style_hash_map
    // and clobber the old class if it exists this way we ensure each element has only one

    current_open.style_hashes = global_classes;

    const full_class = std.fmt.allocPrint(Vapor.arena(.persist), "{s}{s}", .{ writer.buffer[0..writer.pos], additonal_classes orelse "" }) catch |err| {
        Vapor.printlnErr("Could not create string {any} To many classes have been created\n", .{err});
        return err;
    };
    class_string_cache.put(combined, full_class) catch |err| {
        Vapor.printlnErr("Could not put class string {any}\n", .{err});
        @panic("vapor: Could not put class string");
    };
    current_open.class = full_class;
}

// TODO: Hashing the value is slow, we need to create a better hashmap system
// running a comparison on each st.mem.bytes is expensive
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/// NOTE: creating pointers to anyhting and then hashing will corrupt the memory, sicne the pointers are not static,
/// they will appear different during runtime, for  hashing it should always be a static pointer
pub fn configureByNode(_: *UIContext, node: ?*UINode, elem_decl: ElemDecl) *UINode {
    const ui_node = Configuration.configureByNode(node, elem_decl);
    captureHash(ui_node);
    return ui_node;
}

pub fn configurePlainByNode(_: *UIContext, node: ?*UINode, elem_decl: ElemDecl) *UINode {
    const ui_node = Configuration.configurePlainByNode(node, elem_decl);
    captureHash(ui_node);
    return ui_node;
}

pub fn configure(ui_ctx: *UIContext, elem_decl: ElemDecl) *UINode {
    const ui_node = Configuration.configure(ui_ctx, elem_decl);
    captureHash(ui_node);
    return ui_node;
}

// close is breadth post order first
pub fn close(ui_ctx: *UIContext) void {
    if (uuid_depth > 0) {
        uuid_depth -= 1;
    } else {
        Vapor.printlnSrcErr("Depth is negative {}", .{uuid_depth}, @src());
    }
    ui_ctx.stackPop();
}

/// Finds the first index of a `needle` within a `haystack` using SIMD acceleration.
/// Returns the starting byte index of the `needle` if found, otherwise `null`.
pub fn indexOf(haystack: []const u8, needle: []const u8) ?usize {
    // Basic edge cases
    if (needle.len == 0) return 0;
    if (haystack.len < needle.len) return null;

    const first_char = needle[0];
    const last_possible_start = haystack.len - needle.len;

    // SIMD setup for 16-byte vectors (128-bit)
    const vec_len = 16;
    const Vec16 = @Vector(vec_len, u8);

    // Create a vector where every element is the first character of the needle.
    // This will be used to compare against 16 bytes of the haystack at once.
    const first_char_vec: Vec16 = @splat(first_char);

    var i: usize = 0;

    // Main SIMD loop. It processes the haystack in 16-byte chunks.
    // The loop condition ensures we don't read past the end of the haystack.
    while (i + vec_len <= haystack.len) : (i += vec_len) {
        // Load a 16-byte chunk from the haystack into a vector.
        const chunk = haystack[i..][0..vec_len].*;
        const haystack_vec: Vec16 = @bitCast(chunk);

        // Perform 16 parallel comparisons. The result is a mask vector.
        const eq_mask = haystack_vec == first_char_vec;

        // Convert the mask vector into a single u16 integer. Each bit in this
        // integer corresponds to a match for the first character in the chunk.
        var bits: u16 = @bitCast(eq_mask);

        // If bits is 0, no potential matches were found in this chunk, so we continue.
        if (bits == 0) continue;

        // If there are potential matches, iterate through each of them.
        while (bits != 0) {
            // `@ctz` (count trailing zeros) finds the index of the first match in our 16-byte chunk.uituint
            const offset = @ctz(bits);
            const potential_idx = i + offset;

            // Ensure the potential match is not too close to the end of the haystack
            // for the full needle to fit.
            if (potential_idx > last_possible_start) {
                // Since offsets are processed in increasing order, no further
                // matches in this chunk can be valid.
                break;
            }

            // Now, verify if the full substring matches at this position.
            if (std.mem.eql(u8, haystack[potential_idx..][0..needle.len], needle)) {
                // We found it!
                return potential_idx;
            }

            // Clear the bit we just checked so we can find the next one.
            // This is a common trick to iterate over set bits.
            bits &= (bits - 1);
        }
    }

    // Scalar fallback loop for the remaining part of the haystack that didn't
    // fit into a full 16-byte chunk.
    while (i <= last_possible_start) : (i += 1) {
        // A simple check is sufficient here.
        if (haystack[i] == first_char and std.mem.eql(u8, haystack[i..][0..needle.len], needle)) {
            return i;
        }
    }

    return null;
}
