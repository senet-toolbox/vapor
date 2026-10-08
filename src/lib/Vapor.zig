const std = @import("std");
const builtin = @import("builtin");
pub var isGenerated = !isWasi;
pub const isWasi = builtin.target.cpu.arch == .wasm32;
pub const debug = builtin.mode == .Debug;
const types = @import("types.zig");
const UIContext = @import("UITree.zig");
const UINode = @import("UITree.zig").UINode;
pub const CommandsTree = UIContext.CommandsTree;
const TransitionState = @import("Transition.zig").TransitionState;
const Router = @import("Router.zig");
pub const Element = @import("Element.zig").Element;
const KeyGenerator = @import("Key.zig").KeyGenerator;
const Reconciler = @import("Reconciler.zig");
pub const KeyStone = @import("keystone/KeyStone.zig");
pub const Wasm = @import("WASM.zig");
const getVisualStyle = @import("convertStyleCustomWriter.zig").getVisualStyle;
pub const Bridge = @import("Bridge.zig");
pub const Event = @import("Event.zig");
const CSSGenerator = @import("CSSGenerator.zig");
const hashKey = utils.hashKey;
const Pool = @import("Pool.zig");
const mutateDomElementStyleString = @import("Element.zig").mutateDomElementStyleString;
const HtmlGenerator = @import("HtmlGenerator.zig");
const Fetch = @import("Fetch.zig");
const Packer = @import("Packer.zig");
const ClassCache = @import("ClassCache.zig").ClassCache;
const DynamicObject = @import("Dynamic.zig").DynamicObject;
const StringTable = @import("StringTable.zig").StringTable;
const TextFieldTable = @import("TextFieldTable.zig").StringTable;
const Components = @import("Components.zig");
const Accessibility = @import("Accessibility.zig");
const Polygons = @import("Polygon.zig").Polygons;
const StorageTable = @import("StorageTable.zig").StorageTable;
const Structures = @import("structures/Structures.zig");

const DebugLevel = enum(u8) { all = 0, debug = 1, info = 2, warn = 3, none = 4 };

pub var build_options = struct {
    enable_debug: bool = true,
    debug_level: DebugLevel = .none,
}{};

pub var Timer = struct {
    generation_time: f64 = 0,
    reconcile_time: f64 = 0,
    commit_time: f64 = 0,
    total_time: f64 = 0,
}{};
const getStyle = @import("convertStyleCustomWriter.zig").getStyle;
const StyleCompiler = @import("convertStyleCustomWriter.zig");
const utils = @import("utils.zig");
const getAriaLabel = utils.getAriaLabel;
pub const setGlobalStyleVariables = @import("convertStyleCustomWriter.zig").setGlobalStyleVariables;

pub const Component = fn (void) void;

pub const on_change_hash = "onChange";
pub const on_leave_hash = "onLeave";
pub const on_hover_hash = "onHover";
pub const on_submit_hash = "onSubmit";
pub const on_focus_hash = "onFocus";
pub const on_blur_hash = "onBlur";
pub const on_mount_hash = "onMount";
pub const on_create_hash = "onCreate";
pub const on_update_hash = "onUpdate";
pub const on_destroy_hash = "onDestroy";

const EventType = types.EventType;
const Active = types.Active;
pub const ElementDecl = types.ElementDeclaration;
const RenderCommand = types.RenderCommand;
pub const ElementType = types.ElementType;
pub const StateType = types.StateType;
const Hover = types.Hover;
const Focus = types.Focus;
pub var has_context: bool = false;
pub var current_ctx: *UIContext = undefined;
pub var ctx_map: std.AutoHashMap(u32, *UIContext) = undefined;
pub var page_map: std.StringHashMap(void) = undefined;
const LayoutItem = struct {
    reset: bool = false,
    call_fn: *const fn (*const fn () void) void,
};
pub var layout_map: std.AutoHashMap(u32, LayoutItem) = undefined;
pub var page_deinit_map: std.AutoHashMap(u32, *const fn () void) = undefined;
pub var global_rerender: bool = false;
pub var has_dirty: bool = false;
pub var rerender_everything: bool = false;
pub var grain_rerender: bool = false;
pub var grain_element_uuid: []const u8 = "";
pub var current_depth_node_id: []const u8 = "";
pub var router: Router = undefined;

const Vapor = @This();
pub const Kit = @import("kit/Kit.zig");
// pub const Chart = @import("components/charts/Chart.zig");
pub const Style = types.Style;
pub const Types = types;
pub const DateTime = @import("DateTime.zig");
pub const Animation = @import("Animation.zig");
pub const Edges = @import("Edges.zig").Edges;
pub const Transition = @import("Transition.zig");
// pub const Error = @import("routes/nightwatch/Error.zig");

const StorageModule = @import("Storage.zig");
pub const clearPersitantStorage = StorageModule.clearPersitantStorage;
pub const store = StorageModule.store;
pub const getStore = StorageModule.getStore;
pub const setCookie = StorageModule.setCookie;
pub const getCookies = StorageModule.getCookies;
pub const getCookie = StorageModule.getCookie;

pub fn getWindowPath() []const u8 {
    if (isWasi) {
        return std.mem.span(Wasm.getWindowInformationWasm());
    } else {
        return "";
    }
}

pub const EventHandler = struct {
    type: EventType,
    ctx_aware: bool = false,
    cb_opaque: *const anyopaque,
};

pub const EventHandlers = struct {
    // handlers: std.ArrayListUnmanaged(EventHandler),
    handlers: std.ArrayListUnmanaged(ErasedEventCallback),
};

pub const Action = struct {
    dynamic_object: ?*DynamicObject = null,
    runFn: ActionProto,
    deinitFn: NodeProto,
    argsFn: ?ArgsProto = null,
};

pub const Node = struct { data: Action };

pub const ActionProto = *const fn (*Action) void;
pub const NodeProto = *const fn (*Node) void;
pub const ArgsProto = *const fn (*Action) []const u8;

pub fn ArgsTuple(comptime Fn: type) type {
    const out = std.meta.ArgsTuple(Fn);
    return if (std.meta.fields(out).len == 0) @TypeOf(.{}) else out;
}

pub var callback_registry: std.AutoHashMap(u32, *const fn () void) = undefined;
pub var ctx_callback_registry: std.AutoHashMap(u32, *Node) = undefined;

pub const EventNode = struct { cb: *const fn (*Event) void, ui_node: ?*UINode = null, evt_type: EventType };
pub var events_callbacks: std.AutoHashMap(u32, EventNode) = undefined;
pub var nodes_with_events: std.AutoHashMap(u32, *UINode) = undefined;
pub var cached_event_handlers: std.AutoHashMap(u32, EventHandlers) = undefined;
pub var hooks_inst_callbacks: std.AutoHashMap(u32, *const fn (HookContext) void) = undefined;
pub var on_end_funcs: std.array_list.Managed(*const fn () void) = undefined;
pub var on_end_ctx_funcs: std.array_list.Managed(*Node) = undefined;
pub var route_funcs: std.AutoHashMap(u32, ArrayArena(ErasedCallback)) = undefined;
pub var pop_state_funcs: std.array_list.Managed(*const fn () void) = undefined;
pub var push_state_funcs: std.array_list.Managed(*const fn () void) = undefined;
pub var on_commit_funcs: std.array_list.Managed(*const fn () void) = undefined;
pub var on_commit_ctx_funcs: std.array_list.Managed(*Node) = undefined;
// pub var mounted_ctx_funcs: std.AutoHashMap(u32, *Node) = undefined;
pub var on_create_node_funcs: std.AutoHashMap(u32, *Node) = undefined;
pub var hooks_funcs: std.AutoHashMap(u32, *const fn () void) = undefined;

pub var string_table: StringTable = undefined;
pub var storage_table: StorageTable = undefined;
pub var text_field_table: TextFieldTable = undefined;
pub var shadows: std.AutoHashMap(u32, Vapor.Types.NewShadow) = undefined;
pub var packed_layers: std.AutoHashMap(u32, []Vapor.Types.PackedLayer) = undefined;
pub var packed_colors: std.AutoHashMap(u32, []Vapor.Types.PackedColor) = undefined;
pub var packed_transitions: std.AutoHashMap(u32, []Vapor.Types.TransitionProperty) = undefined;
pub var packed_transforms: std.AutoHashMap(u32, []Vapor.Types.TransformType) = undefined;
pub var element_registry: std.AutoHashMap(u32, *Binded) = undefined;

pub const ObserverNode = union(enum) {
    type: ElementType,
    uuid: []const u8,
};
// pub var removed_nodes: std.array_list.Managed(RemovedNode) = undefined;
pub var observer_nodes: std.StringHashMap(std.array_list.Managed(ObserverNode)) = undefined;
pub var added_nodes: std.array_list.Managed(*UINode) = undefined;
pub var dirty_nodes: std.array_list.Managed(*UINode) = undefined;
// Potential nodes is an set to chekc if the potential nodes that are either shifted or removed on in the dom currently
// instead of an active set, we only record the nodes that are different from the current tree
// pub var potential_nodes: std.StringHashMap(void) = undefined;
const Class = struct {
    element_id: []const u8,
    style_id: []const u8,
};
pub var animations: ?std.StringHashMap(Animation) = null;
pub var edges_table: ?std.StringHashMap(Edges) = null;
pub var polygons_table: ?std.StringHashMap(Polygons) = null;
// Define a type for continuation functions

// Global array to store continuations

pub var allocator_global: std.mem.Allocator = undefined;
pub var browser_width: f32 = 0;
pub var browser_height: f32 = 0;
pub var page_node_count: u32 = 256;
const FrameAllocator = @import("FrameAllocator.zig");
pub var frame_arena: FrameAllocator = undefined;

pub fn getFrameAllocator() std.mem.Allocator {
    return arena(.frame);
}

pub const ArenaType = enum {
    frame,
    view,
    persist,
    request,
};

pub const Arena = ArenaType;

pub fn arena(arena_type: ArenaType) std.mem.Allocator {
    if (generating) return frame_arena.persistentAllocator();
    return switch (arena_type) {
        .frame => frame_arena.frameAllocator(),
        .view => frame_arena.viewAllocator(),
        .persist => frame_arena.persistentAllocator(),
        .request => frame_arena.requestAllocator(),
    };
}

pub fn array(comptime T: type, arena_type: ArenaType) Array(T) {
    var array_list: std.array_list.Managed(T) = undefined;
    const allocator = arena(arena_type);
    array_list = std.array_list.Managed(T).init(allocator);
    return array_list;
}

pub const Array = std.array_list.Managed;

pub const VaporConfig = struct {
    // screen_width: f32,
    // screen_height: f32,
    page_node_count: u32 = 256,
    mode: Mode = .atomic,
};

const Mode = enum {
    immediate,
    atomic,
    retained,
    static,
};

pub var pool: Pool = undefined;
pub var mode: Mode = .atomic;
pub var class_cache: ClassCache = undefined;
pub var trace_arena: std.heap.ArenaAllocator = undefined;

extern fn frame_arena_init(frame_arena: *FrameAllocator, backing_allocator: *std.mem.Allocator) void;

// 17kb is just the exports and externs

pub fn init(config: VaporConfig) void {
    switch (builtin.target.cpu.arch) {
        .wasm32 => {
            allocator_global = std.heap.wasm_allocator;
        },
        else => {
            allocator_global = std.heap.c_allocator;
        },
    }
    if (isWasi) {
        browser_width = Wasm.windowWidth();
        browser_height = Wasm.windowHeight();
    }
    page_node_count = config.page_node_count;
    mode = config.mode;

    // Reconciler.init();
    // Init the frame allocator;
    frame_arena = FrameAllocator.init(allocator_global);
    trace_arena = std.heap.ArenaAllocator.init(allocator_global);
    // The persistent allocator is used for the Initialization of the registries as these persist over the lifetime of the program.
    const allocator = frame_arena.persistentAllocator();

    // Init Router // This adds 1kb
    router.init(allocator) catch |err| {
        println("Could not init Router {any}\n", .{err});
    };

    // >4kb
    Packer.init(allocator);
    initRegistries(allocator);
    initCalls(allocator);
    initContextData(allocator);

    // Eveyrhtuing up to here is 35kb

    class_cache.init(allocator) catch |err| {
        printlnErr("Could not init ClassCache {any}\n", .{err});
        @panic("vapor: ClassCache init failed");
    };
    UIContext.element_style_hash_map = std.AutoHashMap(u32, [10]u32).init(allocator);
    UIContext.class_string_cache = std.AutoHashMap(u32, []const u8).init(allocator);
    UIContext.prev_style_hashes = std.AutoHashMap(u32, u32).init(allocator);
    UIContext.style_info_map = std.AutoHashMap(u32, *UIContext.StyleInfo).init(allocator);

    Components.text_string_table = std.AutoHashMap(u32, Components.StringEntry).init(allocator);
    Accessibility.a11y_map = std.AutoHashMap(u32, Accessibility.Accessibility).init(allocator);

    string_table = StringTable.init(allocator);
    storage_table = StorageTable.init(allocator);
    text_field_table = TextFieldTable.init(allocator);
    shadows = std.AutoHashMap(u32, Vapor.Types.NewShadow).init(allocator);
    packed_layers = std.AutoHashMap(u32, []Types.PackedLayer).init(allocator);
    packed_colors = std.AutoHashMap(u32, []Types.PackedColor).init(allocator);
    packed_transitions = std.AutoHashMap(u32, []Types.TransitionProperty).init(allocator);
    packed_transitions = std.AutoHashMap(u32, []Types.TransitionProperty).init(allocator);
    packed_transforms = std.AutoHashMap(u32, []Types.TransformType).init(allocator);
    KeyGenerator.initWriter();
    // These subsystems keep registries in the persist arena set up above, and
    // used to need separate init calls that only the docs site knew about.
    // Without them the first fetch(), and the first removed node (which goes
    // through the animation removal queue), trap on an undefined container
    // ("RuntimeError: null function"); animations, edges and polygons were
    // silently dropped. Calling any of these again later is harmless.
    Fetch.Request.init();
    @import("Animation.zig").new();
    @import("Edges.zig").new();
    @import("Polygon.zig").new();

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    observer_nodes = std.StringHashMap(std.array_list.Managed(ObserverNode)).init(allocator);
    added_nodes = std.array_list.Managed(*UINode).init(allocator);
    dirty_nodes = std.array_list.Managed(*UINode).init(allocator);
    element_registry = std.AutoHashMap(u32, *Binded).init(allocator);

    // action_log = Structures.BoundedArray(ErrorReport, 512).init(512) catch unreachable;

    // Everything up to here is 42 kb
}

fn initRegistries(persistent_allocator: std.mem.Allocator) void {
    callback_registry = std.AutoHashMap(u32, *const fn () void).init(persistent_allocator);
    ctx_callback_registry = std.AutoHashMap(u32, *Node).init(persistent_allocator);
}

pub var erased_registry: std.AutoHashMap(u32, ErasedCallback) = undefined;
pub var erased_hooks_registry: std.AutoHashMap(u32, ErasedCallback) = undefined;
pub var erased_event_registry: std.AutoHashMap(u32, ErasedEventCallback) = undefined;
pub var resize_callbacks: std.AutoHashMap(u32, Kit.ResizeCallback) = undefined;
fn initCalls(persistent_allocator: std.mem.Allocator) void {
    events_callbacks = std.AutoHashMap(u32, EventNode).init(persistent_allocator);
    nodes_with_events = std.AutoHashMap(u32, *UINode).init(persistent_allocator);
    cached_event_handlers = std.AutoHashMap(u32, EventHandlers).init(persistent_allocator);
    hooks_inst_callbacks = std.AutoHashMap(u32, *const fn (HookContext) void).init(persistent_allocator);
    on_end_funcs = std.array_list.Managed(*const fn () void).init(persistent_allocator);
    on_end_ctx_funcs = std.array_list.Managed(*Node).init(persistent_allocator);
    pop_state_funcs = std.array_list.Managed(*const fn () void).init(persistent_allocator);
    push_state_funcs = std.array_list.Managed(*const fn () void).init(persistent_allocator);
    on_commit_funcs = std.array_list.Managed(*const fn () void).init(persistent_allocator);
    on_commit_ctx_funcs = std.array_list.Managed(*Node).init(persistent_allocator);
    // mounted_ctx_funcs = std.AutoHashMap(u32, *Node).init(persistent_allocator);
    on_create_node_funcs = std.AutoHashMap(u32, *Node).init(persistent_allocator);
    hooks_funcs = std.AutoHashMap(u32, *const fn () void).init(persistent_allocator);
    route_funcs = std.AutoHashMap(u32, ArrayArena(ErasedCallback)).init(persistent_allocator);
    erased_registry = std.AutoHashMap(u32, ErasedCallback).init(persistent_allocator);
    erased_hooks_registry = std.AutoHashMap(u32, ErasedCallback).init(persistent_allocator);
    erased_event_registry = std.AutoHashMap(u32, ErasedEventCallback).init(persistent_allocator);
    resize_callbacks = std.AutoHashMap(u32, Kit.ResizeCallback).init(persistent_allocator);
}

fn initContextData(persistent_allocator: std.mem.Allocator) void {
    ctx_map = std.AutoHashMap(u32, *UIContext).init(persistent_allocator);
    page_map = std.StringHashMap(void).init(persistent_allocator);
    layout_map = std.AutoHashMap(u32, LayoutItem).init(persistent_allocator);
    page_deinit_map = std.AutoHashMap(u32, *const fn () void).init(persistent_allocator);
}

pub fn getCurrentNode() ?*UINode {
    const stack = current_ctx.stack.?;
    // Parent node
    return stack.ptr;
}

/// The LifeCycle struct
/// allows control over ui node in the tree
/// exposes open, configure, and close, must be called in this order to attach the node to the tree
pub const LifeCycle = struct {
    /// open takes an element decl and return a *UINode
    /// this opens the element to allow for children
    /// within the dom tree, node this current opened node is the current top stack node, ie any children
    /// will reference this node as their parent
    pub fn open(elem_decl: ElementDecl) ?*UINode {
        const ui_node = current_ctx.open(elem_decl) catch |err| {
            println("{any}\n", .{err});
            return null;
        };
        return ui_node;
    }
    /// close, closes the current UINode
    pub fn close(_: void) void {
        _ = current_ctx.close();
        return;
    }
    /// configure is used internally to configure the UINode, used for adding text props, or hover props ect
    /// within configure, we check if the node has a id if so we use that, otherwise later we generate one
    /// we also set various props, such as text, style, is an SVG or not
    /// Any mainpulation of the node after this point is considered undefined behaviour be cautious;
    pub fn configure(elem_decl: ElementDecl) void {
        _ = current_ctx.configure(elem_decl);
    }
};

/// Force rerender forces the entire dom tree to check props of all dynamic and pure components and rerender the ui
/// since Vapor is built with zig and wasm, checking all props of 10000s of nodes and ui components is cheap
/// feel free to abuse force, its essentially a global signal
pub fn cycle() void {
    if (isWasi) {
        Vapor.global_rerender = true;
        // render_phase = .generating;
        Wasm.requestRerenderWasm();
    }
}

pub fn batch() void {
    if (isWasi) {
        Vapor.global_rerender = true;
        // render_phase = .generating;
        Wasm.requestRerenderWasm();
    }
}

// /// Force rerender forces the entire dom tree to check props of all dynamic and pure components and rerender the ui
// /// since Vapor is built with zig and wasm, checking all props of 10000s of nodes and ui components is cheap
// /// feel free to abuse force, its essentially a global signal
// pub fn cycleGrain() void {
//     Vapor.grain_rerender = true;
//     Vapor.println("Grain rerender", .{});
//     Wasm.requestRerenderWasm();
// }

/// Force rerender forces the entire dom tree to check props and rerender the entire ui
/// since Vapor is built with zig and wasm, checking all props of 10000s of nodes and ui components is cheap
/// feel free to abuse force, its essentially a global signal
pub fn forceEverything() void {
    if (isWasi) {
        Vapor.rerender_everything = true;
        Vapor.global_rerender = true;
        Wasm.requestRerenderWasm();
    }
}

/// This function adds the route to the tether radix tree.
/// Deinitializes the tether instance recursively calls routes deinit routes from radix tree
/// # Parameters:
pub var route_segments: [][]const u8 = undefined;
var deepest_reset_layout: ?LayoutItem = null;
var deepest_reset_layout_path: []const u8 = "";
var target_min_layout_path: []const u8 = "";

pub fn findResetLayout() void {
    var potential_path: []const u8 = "";
    for (route_segments, 0..) |segment, i| {
        potential_path = std.fmt.allocPrint(Vapor.arena(.frame), "{s}/{s}", .{ potential_path, segment }) catch return;
        const target_layout = layout_map.get(hashKey(potential_path)) orelse continue;
        if (target_layout.reset) {
            deepest_reset_layout = target_layout;
            deepest_reset_layout_path = potential_path;
            route_segments = route_segments[i + 1 ..];
        }
    }
    if (deepest_reset_layout) |_| {
        target_min_layout_path = deepest_reset_layout_path;
    } else {
        target_min_layout_path = current_route;
    }
}

pub var next_layout_path_to_check: []const u8 = "";
pub fn callNestedLayouts() void {
    if (route_segments.len == 0) {
        if (deepest_reset_layout) |layout| {
            const layout_fn = layout.call_fn;
            deepest_reset_layout = null;
            deepest_reset_layout_path = "";
            layout_fn(render_page);
        } else {
            // TODO: This is taking a lot of time we need to create a better hashmap system, currently the hashmap compare
            // with the node is long and slow
            // const time = nowMs();
            render_page();
            // Vapor.println("Render time {any}", .{nowMs() - time});
        }
        return;
    }

    // Get the current layout
    next_layout_path_to_check = fmtln("{s}/{s}", .{ next_layout_path_to_check, route_segments[0] });
    if (layout_map.get(hashKey(next_layout_path_to_check))) |entry| {
        const layout_path = next_layout_path_to_check; // "/root" or "/root/docs"
        const layout_fn = entry.call_fn;
        // We check if the layout path and current path are the same
        // Here we need to check if the layout_path starts with the target_min_layout_path
        // if the target path is /root/docs and the layout_path is /root
        if (std.mem.startsWith(u8, target_min_layout_path, layout_path)) {
            route_segments = route_segments[1..];
            layout_fn(callNestedLayouts);
        }
    } else {
        if (route_segments.len == 0) {
            return;
        }
        // No layout found, continue with remaining segments
        route_segments = route_segments[1..];
        callNestedLayouts();
    }
}

pub var clean_up_ctx: *UIContext = undefined;
pub var current_route: []const u8 = "";
var previous_route: []const u8 = "";
pub var render_page: *const fn () void = undefined;
pub var generator: CSSGenerator = undefined;

const Status = struct {
    render_cycle: bool = true,
    valid_url: bool = true,
};

var status: Status = .{};

pub fn getStatus() Status {
    return status;
}

pub fn resetStatus() void {
    status = .{};
}

fn DefaultPage() void {
    Components.Builder(.pure).Stack().children({});
}

pub var old_ctx_op: ?*UIContext = null;

// pub var render_phase: RenderPhase = .idle;
var changed_route: bool = false;
pub fn renderCycle(route_ptr: [*:0]u8) !void {
    UIContext.cache_count = 0;
    status = .{};

    const route = std.mem.span(route_ptr);

    // Get the old context for current route
    const old_route_op = router.searchRoute(route) orelse blk: {
        printlnSrcErr("No Route found", .{}, @src());
        break :blk router.searchRoute("/root/error") orelse {
            printlnSrcErr("No Error Route found", .{}, @src());
            status.valid_url = false;
            break :blk null;
        };
    };

    if (old_route_op) |old_route| {
        render_page = old_route.page;
        route_params = old_route.params;
        frame_arena.setCurrentRoute(old_route.route_arena);
    } else {
        render_page = DefaultPage;
        route_params = &.{};
    }

    frame_arena.beginFrame(); // For double-buffered approach
    frame_arena.resetScratchArena();

    if (!std.mem.eql(u8, current_route, route)) {
        changed_route = true;
        // We need to start a new route allocator
        // otherwise we are on the same route
        frame_arena.beginView();
    }

    current_route = route;
    added_nodes.clearRetainingCapacity();
    dirty_nodes.clearRetainingCapacity();
    nodes_with_events.clearRetainingCapacity();

    packed_layers.clearRetainingCapacity();
    packed_colors.clearRetainingCapacity();
    packed_transitions.clearRetainingCapacity();
    packed_transforms.clearRetainingCapacity();
    shadows.clearRetainingCapacity();
    route_funcs.clearRetainingCapacity();

    const old_ctx = current_ctx;
    old_ctx_op = old_ctx;
    // Create new context
    const new_ctx: *UIContext = arena(.frame).create(UIContext) catch {
        status.render_cycle = false;
        println("Failed to allocate UIContext\n", .{});
        return;
    };

    UIContext.initContext(new_ctx) catch |err| {
        status.render_cycle = false;
        println("Allocator ran out of space {any}\n", .{err});
        new_ctx.deinit();
        allocator_global.destroy(new_ctx);
        return;
    };

    new_ctx.root.?.uuid = old_ctx.root.?.uuid;

    current_ctx = new_ctx;
    var route_itr = std.mem.tokenizeScalar(u8, route, '/');
    var count: usize = 0;
    while (route_itr.next()) |_| {
        count += 1;
    }
    route_segments = allocator_global.alloc([]const u8, count) catch return;
    count = 0;
    route_itr.reset();
    while (route_itr.next()) |route_token| {
        route_segments[count] = route_token;
        count += 1;
    }

    // Init the generator
    generator.init();
    next_layout_path_to_check = "";

    findResetLayout();
    // This calls the render tree, with render_page as the root function call
    // First it traverses the layouts calling them in order, and then it calls the render_page
    callNestedLayouts(); // 4.5ms

    onCommitCtxCallback();

    on_commit_funcs.clearRetainingCapacity();
    on_commit_ctx_funcs.clearRetainingCapacity();

    Reconciler.reconcile(old_ctx, new_ctx); // 3kb
    // We generate the render commands tree
    endPage(new_ctx);
    if (!std.mem.eql(u8, previous_route, current_route)) {
        Vapor.has_dirty = true;
    }

    if (build_options.enable_debug and build_options.debug_level == .all) {
        frame_arena.printStats();
    }

    // Replace old context with new context in the map
    clean_up_ctx = old_ctx;
    changed_route = false;
    class_cache.batchRemove();
    if (old_route_op != null and router.updateRouteTree(old_route_op.?.path, new_ctx)) {
        previous_route = current_route;
        return;
    }

    allocator_global.free(route); // return host‑allocated buffer
    previous_route = current_route;
}

pub fn createPage(path: []const u8, page: fn () void, page_deinit: ?fn () void) !void {
    if (isWasi) {
        has_context = true;
    }

    const route_arena = frame_arena.createRouteArena();
    frame_arena.setCurrentRoute(route_arena);

    const path_ctx: *UIContext = try allocator_global.create(UIContext);
    // Initial render
    UIContext.initContext(path_ctx) catch |err| {
        println("Allocator ran out of space {any}\n", .{err});
        return;
    };

    current_ctx = path_ctx;

    router.addRoute(path, path_ctx, page, route_arena) catch |err| {
        println("Could not put route {any}\n", .{err});
    };
    page_map.put(path, {}) catch |err| {
        println("Could not put route {any}\n", .{err});
    };

    if (page_deinit) |de| {
        page_deinit_map.put(path, de) catch |err| {
            println("Could not put route {any}\n", .{err});
        };
    }
    return;
}
extern fn performance_now() f64; // imported from JS, for example

var animation_frame_callback: ?*Node = null;
pub fn runOnAnimationFrame(callback: anytype, args: anytype) u32 {
    const Args = @TypeOf(args);
    const Closure = struct {
        arguments: Args,
        run_node: Node = .{ .data = .{ .runFn = runFn, .deinitFn = deinitFn } },
        //
        fn runFn(action: *Action) void {
            const run_node: *Node = @fieldParentPtr("data", action);
            const closure: *@This() = @alignCast(@fieldParentPtr("run_node", run_node));
            @call(.auto, callback, closure.arguments);
        }
        //
        fn deinitFn(node: *Node) void {
            const closure: *@This() = @alignCast(@fieldParentPtr("run_node", node));
            allocator_global.destroy(closure);
        }
    };

    const closure = Vapor.arena(.frame).create(Closure) catch |err| {
        printlnErr("runOnAnimationFrame: could not allocate closure, frame not scheduled: {any}", .{err});
        return 0;
    };
    closure.* = .{
        .arguments = args,
    };

    animation_frame_callback = &closure.run_node;
    ctx_callback_registry.put(@intFromPtr(animation_frame_callback), &closure.run_node) catch |err| {
        printlnErr("runOnAnimationFrame: could not register callback, frame not scheduled: {any}", .{err});
        return 0;
    };

    if (isWasi) {
        return Wasm.requestAnimationFrameWasm(@intFromPtr(animation_frame_callback));
    }
    return 0;
}

export fn callAnimationFrameCallback(callback_ptr: u32) void {
    const node = Vapor.ctx_callback_registry.get(callback_ptr) orelse {
        std.log.err("Ctx Callback Not found {any}\n", .{callback_ptr});
        return;
    };
    @call(.auto, node.data.runFn, .{&node.data});
    if (Vapor.mode == .atomic) {
        Vapor.cycle();
    }
}

pub fn nowMs() f64 {
    if (isWasi) {
        return performance_now();
    } else {
        return 0;
    }
}
pub fn endPage(_: *UIContext) void {
    if (changed_route) {
        ////// BE CAREFUL WITH THIS the configuration system does not run if the value has been created already i think?
        ///// uncommenting the above and then usign the search fucntion casues errors on the layers style fucntionality
        generator.writeAllStyles();
    }
}

// Okay so we need to change the node in the tree depending on the page route
// for example we add the commads tree to the router tree
const Path = union(enum) {
    route: []const u8,
    src: std.builtin.SourceLocation,
};
pub fn Page(path: Path, page: fn () void, page_deinit: ?fn () void) void {
    const allocator = Vapor.frame_arena.persistentAllocator();
    var full_route: []const u8 = "";
    var itr: std.mem.TokenIterator(u8, std.mem.DelimiterType.scalar) = undefined;
    if (path == .src) {
        full_route = path.src.file[0..path.src.file.len];
        itr = std.mem.tokenizeScalar(u8, full_route[7..], '/');
    } else {
        full_route = path.route;
        itr = std.mem.tokenizeScalar(u8, full_route, '/');
    }
    var buf = std.array_list.Managed(u8).init(allocator);

    buf.appendSlice("/root") catch |err| {
        println("Allocator ran out of space {any}\n", .{err});
        return;
    };

    var file_name: []const u8 = "";
    blk: while (itr.next()) |sub| {
        if (itr.peek() == null and path == .src) {
            file_name = sub;
            break :blk;
        }
        buf.append('/') catch |err| {
            println("Allocator ran out of space {any}\n", .{err});
            return;
        };

        buf.appendSlice(sub) catch |err| {
            println("Allocator ran out of space {any}\n", .{err});
            return;
        };
    }

    // else
    if (std.mem.startsWith(u8, file_name, "Error")) {
        buf.appendSlice("/error") catch |err| {
            println("Allocator ran out of space {any}\n", .{err});
            return;
        };
    }

    const route = buf.toOwnedSlice() catch |err| {
        println("Could not parse route {any}\n", .{err});
        return;
    };

    createPage(route, page, page_deinit) catch |err| {
        println("Could not add page {any}\n", .{err});
        return;
    };
}
const LayoutOptions = struct {
    reset: bool = false,
};

pub const PageFn = *const fn () void;
pub const LayoutFn = fn (*const fn () void) void;
/// Dynamic segment values of the route being rendered.
pub var route_params: []const Router.Param = &.{};

/// The value of a dynamic segment of the current route, e.g. for a page
/// registered as `/users/:id`, `routeParam("id")` is "42" on /users/42.
/// Valid during render; copy it (Vapor.dupe) to keep it longer.
pub fn routeParam(name: []const u8) ?[]const u8 {
    for (route_params) |param| {
        if (std.mem.eql(u8, param.name, name)) return param.value;
    }
    return null;
}

pub fn registerLayout(path: []const u8, layout: LayoutFn, options: LayoutOptions) !void {
    if (std.mem.eql(u8, path, "/root")) return error.CannotRegisterRootPath;
    if (std.mem.eql(u8, path, "/")) {
        layout_map.put(hashKey("/root"), .{ .call_fn = layout, .reset = options.reset }) catch |err| {
            printlnSrcErr("Could not add layout to registry {}", .{err}, @src());
        };
    } else {
        const layout_route = std.fmt.allocPrint(Vapor.arena(.persist), "/root{s}", .{path}) catch return;
        layout_map.put(hashKey(layout_route), .{ .call_fn = layout, .reset = options.reset }) catch |err| {
            printlnSrcErr("Could not add layout to registry {}", .{err}, @src());
        };
    }
}
pub const HooksFuncs = struct {
    created: ?*const fn () void = null,
    mounted: ?*const fn () void = null,
    destroy: ?*const fn () void = null,
    updated: ?*const fn () void = null,
};

pub const HooksCtxFuncs = enum(u8) { mounted, destroy };

pub fn toggleTheme() void {
    if (isWasi) {
        Wasm.toggleThemeWasm();
    }
}

/// This function creates an eventListener on the element.
/// Takes a callback function to be called when an event is received;
/// # Parameters:
/// - `element_id`: []const u8,
/// - `event_type`: *EventType,
/// - `cb`: *const fn (event: *Event) void,
///
/// # Returns:
/// !void
pub inline fn destroyElementEventListener(
    element_uuid: []const u8,
    event_type: types.EventType,
    cb_id: usize,
) ?bool {
    const event_type_str = std.enums.tagName(types.EventType, event_type) orelse return null;
    Wasm.removeElementEventListener(element_uuid.ptr, element_uuid.len, event_type_str.ptr, event_type_str.len, @intCast(cb_id));
    Vapor.printlnSrc("Callback id {}", .{cb_id}, @src());
    return false;
}

/// This function creates an eventListener on the element.
/// Takes a callback function to be called when an event is received;
/// # Parameters:
/// - `element_id`: []const u8,
/// - `event_type`: *EventType,
/// - `cb`: *const fn (event: *Event) void,
///
/// # Returns:
/// !void
pub inline fn destroyElementInstEventListener(
    element_uuid: []const u8,
    event_type: types.EventType,
    cb_id: usize,
) ?bool {
    const event_type_str = std.enums.tagName(types.EventType, event_type) orelse return null;
    Wasm.removeElementEventListener(element_uuid.ptr, element_uuid.len, event_type_str.ptr, event_type_str.len, @intCast(cb_id));
    return false;
}

/// This function creates an focuses on the element.
/// # Parameters:
/// - `element_id`: []const u8,
///
/// # Returns:
/// void
pub inline fn focus(element_uuid: []const u8) void {
    if (Vapor.isWasi) {
        Wasm.elementFocusWasm(element_uuid.ptr, element_uuid.len);
    }
}

/// This function creates an focuses on the element.
/// # Parameters:
/// - `element_id`: []const u8,
///
/// # Returns:
/// void
pub inline fn focused(element_uuid: []const u8) bool {
    if (Vapor.isWasi) {
        return Wasm.elementFocusedWasm(element_uuid.ptr, element_uuid.len);
    }
    return false;
}

const serializeArgs = utils.serializeArgs;

pub const ErasedEventCallback = struct {
    ctx: *anyopaque,
    callFn: *const fn (*anyopaque, *Event) void,
    event_type: EventType,
    dynamic_object: ?*DynamicObject = null,

    pub fn call(self: *const ErasedEventCallback, evt: *Event) void {
        self.callFn(self.ctx, evt);
    }

    pub fn make(allocator: std.mem.Allocator, event_type: EventType, cb: anytype, args: anytype) !ErasedEventCallback {
        const Args = @TypeOf(args);

        const Closure = struct {
            arguments: Args,

            fn run(ptr: *anyopaque, evt: *Event) void {
                const self: *@This() = @ptrCast(@alignCast(ptr));
                // cb is comptime-captured, append evt to the args
                @call(.auto, cb, self.arguments ++ .{evt});
            }
        };

        const closure = try allocator.create(Closure);
        closure.* = .{ .arguments = args };

        return .{
            .ctx = @ptrCast(closure),
            .callFn = Closure.run,
            .event_type = event_type,
        };
    }
};

export fn dispatchEvent(event_type_int: u32, callback_id: u32) void {
    const event_type: EventType = @enumFromInt(event_type_int);

    var event = Event{
        .id = callback_id,
        .type = event_type,
    };

    const erased = erased_event_registry.get(callback_id) orelse {
        std.log.err("Event Callback not found {s}\n", .{@tagName(event_type)});
        Vapor.printlnSrcErr("Event Callback not found\n", .{}, @src());
        return;
    };

    erased.call(&event);

    if (Vapor.mode == .atomic and event_type != .pointermove) {
        Vapor.cycle();
    }
}

/// We cannot use hash here since has is determeined by the node itself, so if a user create an id, then the hash will be different,
/// the hash is basied on depth ect, while id is user diefined so we must hash the id
export fn dispatchNodeEvent(ui_node: *UINode, event_type_int: u32) void {
    const handlers = ui_node.event_handlers orelse return;
    const event_type: EventType = @enumFromInt(event_type_int);

    var type_onid = hashKey(ui_node.uuid);
    type_onid +%= @intFromEnum(event_type);
    var event = Event{
        .id = type_onid,
        .type = event_type,
    };

    for (handlers.handlers.items) |*handler| {
        if (handler.event_type == event_type) {
            handler.call(&event);

            if (Vapor.mode == .atomic and event_type != .pointermove and event_type != .scroll and ui_node.cycle == true) {
                if (ui_node.type != .Form) {
                    if (event_type == .rightclick) {
                        std.log.info("rightclick", .{});
                    }
                    Vapor.cycle();
                }
            }
            return;
        }
    }
}

pub fn attachEventCtxCallback(ui_node: *UINode, event_type: EventType, cb: anytype, args: anytype) !void {
    if (!isWasi) return;

    // Check for duplicates
    if (ui_node.event_handlers) |handlers| {
        for (handlers.handlers.items) |handler| {
            if (handler.event_type == event_type) {
                std.log.err("Event: {any}", .{event_type});
                return error.EventAlreadyAttached;
            }
        }
    }

    const erased = try ErasedEventCallback.make(arena(.frame), event_type, cb, args);

    // Ensure handlers list exists
    if (ui_node.event_handlers == null) {
        const handlers = try arena(.frame).create(EventHandlers);
        handlers.* = .{ .handlers = .empty };
        ui_node.event_handlers = handlers;
    }

    try ui_node.event_handlers.?.handlers.append(arena(.frame), erased);

    var type_onid = hashKey(ui_node.uuid);
    type_onid +%= @intFromEnum(event_type);
    try erased_event_registry.put(type_onid, erased);

    const onid = hashKey(ui_node.uuid);
    try nodes_with_events.put(onid, ui_node);
}

pub fn attachEventCallback(ui_node: *UINode, event_type: EventType, cb: fn (event: *Event) void) !void {
    if (!isWasi) return;

    // Check for duplicates
    if (ui_node.event_handlers) |handlers| {
        for (handlers.handlers.items) |handler| {
            if (handler.event_type == event_type) {
                return error.EventCtxCallbackError;
            }
        }
    }

    const erased = try ErasedEventCallback.make(arena(.frame), event_type, cb, .{});

    // Ensure handlers list exists
    if (ui_node.event_handlers == null) {
        const handlers = try arena(.frame).create(EventHandlers);
        handlers.* = .{ .handlers = .{} };
        ui_node.event_handlers = handlers;
    }

    try ui_node.event_handlers.?.handlers.append(arena(.frame), erased);

    const onid = hashKey(ui_node.uuid);
    try nodes_with_events.put(onid, ui_node);
}

/// This function creates an eventListener on the element.
/// Takes a callback function to be called when an event is received;
/// # Parameters:
/// - `element_id`: []const u8,
/// - `event_type`: *EventType,
/// - `cb`: *const fn (event: *Event) void,
///
/// # Returns:
/// !void
pub inline fn elementEventListener(
    ui_node: *UINode,
    event_type: types.EventType,
    cb: *const fn (event: *Event) void,
) ?usize {
    if (isWasi) {
        var onid = hashKey(ui_node.uuid);
        onid +%= @intFromEnum(event_type);
        events_callbacks.put(onid, .{ .cb = cb, .ui_node = ui_node, .evt_type = event_type }) catch |err| {
            println("Event Callback Error: {any}\n", .{err});
        };

        const event_type_str = std.enums.tagName(types.EventType, event_type) orelse return null;
        Wasm.createElementEventListener(ui_node.uuid.ptr, ui_node.uuid.len, event_type_str.ptr, event_type_str.len, onid);
        return onid;
    }
    return null;
}

pub inline fn removeElementEventListener(
    ui_node: *UINode,
    event_type: types.EventType,
) ?usize {
    if (isWasi) {
        var onid = hashKey(ui_node.uuid);
        onid +%= @intFromEnum(event_type);
        const event_type_str = std.enums.tagName(types.EventType, event_type) orelse return null;
        Wasm.removeElementEventListener(ui_node.uuid.ptr, ui_node.uuid.len, event_type_str.ptr, event_type_str.len, onid);
        return onid;
    }
    return null;
}

pub fn addGlobalListener(event_type: EventType, cb: fn (*Event) void) ?u32 {
    if (!isWasi) return null;

    const erased = ErasedEventCallback.make(arena(.persist), event_type, cb, .{}) catch |err| {
        printlnErr("addGlobalListener: could not allocate callback, listener not attached: {any}", .{err});
        return null;
    };

    const id = erased_event_registry.count() + 1;
    erased_event_registry.put(id, erased) catch |err| {
        printlnErr("addGlobalListener: could not register, listener not attached: {any}", .{err});
        return null;
    };

    const event_type_str: []const u8 = std.enums.tagName(types.EventType, event_type) orelse return null;
    if (isWasi) {
        Wasm.createEventListenerGlobal(event_type_str.ptr, event_type_str.len, id);
    }
    return @intCast(id);
}

/// USes persist under the hood
pub fn addGlobalListenerCtx(event_type: EventType, cb: anytype, args: anytype) ?u32 {
    if (!isWasi) return null;

    const erased = ErasedEventCallback.make(arena(.persist), event_type, cb, args) catch |err| {
        printlnErr("addGlobalListenerCtx: could not allocate callback, listener not attached: {any}", .{err});
        return null;
    };

    const id = erased_event_registry.count() + 1;
    erased_event_registry.put(id, erased) catch |err| {
        printlnErr("addGlobalListenerCtx: could not register, listener not attached: {any}", .{err});
        return null;
    };

    const event_type_str: []const u8 = std.enums.tagName(types.EventType, event_type) orelse return null;
    if (isWasi) {
        Wasm.createEventListenerGlobal(event_type_str.ptr, event_type_str.len, id);
    }
    return @intCast(id);
}

pub fn removeGlobalListener(event_type: EventType, cb_idx: u32) ?bool {
    const event_type_str = std.enums.tagName(types.EventType, event_type) orelse return null;
    Wasm.removeEventListener(event_type_str.ptr, event_type_str.len, cb_idx);
    return true;
}

pub const HookInst = struct {
    hook_cb: HookInstProto,
};

pub const HookInstProto = *const fn (*HookInst) void;
pub const HookInstNodeProto = *const fn (*HookInstNode) void;

pub const HookInstNode = struct { data: HookInst };

pub const HookContext = struct {
    from_path: []const u8,
    to_path: []const u8,
    params: std.StringHashMap([]const u8),
    query: std.StringHashMap([]const u8),
};

pub const HookType = enum(u8) {
    before = 0,
    after = 1,
};

/// cb(Self)
pub inline fn registerHook(
    url: []const u8,
    cb: anytype,
    hook_type: HookType,
) ?usize {
    if (!isWasi) return null;
    const id = hooks_inst_callbacks.count();
    hooks_inst_callbacks.put(id, cb) catch |err| {
        println("Event Callback Error: {any}\n", .{err});
    };

    Wasm.createHookWASM(url.ptr, url.len, id, @intFromEnum(hook_type));
    return id;
}

/// This function creates an eventListener on the document.
/// Takes a callback function to be called when an event is received;
/// # Parameters:
/// - `event_type`: *EventType,
/// - `cb`: *const fn (event: *Event) void,
///
/// # Returns:
/// !void
pub inline fn eventListener(
    event_type: types.EventType,
    cb: *const fn (event: *Event) void,
) ?u32 {
    var id: u32 = events_callbacks.count() + 1;
    id +%= @intFromEnum(event_type);
    events_callbacks.put(id, .{ .cb = cb, .ui_node = null, .evt_type = event_type }) catch |err| {
        println("Event Callback Error: {any}\n", .{err});
        return null;
    };

    const event_type_str: []const u8 = std.enums.tagName(types.EventType, event_type) orelse return null;
    if (isWasi) {
        Wasm.createEventListener(event_type_str.ptr, event_type_str.len, id);
    }
    return id;
}

// The first node needs to be marked as false always
pub fn markChildrenDirty(node: *UINode) void {
    if (node.parent != null) {
        node.dirty = true;
    }
    var children = node.children();
    while (children.next()) |child| {
        markChildrenDirty(child);
    }
}
// The first node needs to be marked as false always
pub fn markChildrenNotDirty(node: *UINode) void {
    if (node.parent != null) {
        node.dirty = false;
    }
    var children = node.children();
    while (children.next()) |child| {
        markChildrenNotDirty(child);
    }
}

var buffer: [5_000_000]u8 = undefined;
pub var writer: std.Io.Writer = undefined;
var generated_file: std.Io.File = undefined;
var generating: bool = false;
const release_dir = "release";

/// Aborts static generation with a diagnostic.
///
/// Generation runs in the CLI, not the browser, so failing hard on a bad path
/// or a full disk is right. `unreachable` is the wrong way to say that: it is
/// undefined behaviour under ReleaseFast/ReleaseSmall, and it prints nothing.
/// This names the operation and the path, and aborts identically in every
/// optimize mode.
fn generatorFatal(comptime what: []const u8, err: anyerror, path: []const u8) noreturn {
    std.debug.print("vapor: static generation failed: " ++ what ++ ": '{s}': {any}\n", .{ path, err });
    @panic("static generation failed");
}

/// `createDirPath` when the directory already existing is success.
fn ensureDir(io: anytype, cwd: std.Io.Dir, path: []const u8) void {
    cwd.createDirPath(io, path) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => generatorFatal("creating directory", err, path),
    };
}

pub fn generate() void {
    generating = true;
    const cwd = std.Io.Dir.cwd();
    var threaded: std.Io.Threaded = .init_single_threaded;
    const io = threaded.io();

    // Create release/ and release/static/
    ensureDir(io, cwd, release_dir);
    const static_dir = std.fmt.allocPrint(allocator_global, "{s}/static", .{release_dir}) catch |err|
        generatorFatal("building the static/ path", err, release_dir);
    ensureDir(io, cwd, static_dir);

    // CSS variables into release/static/
    const css_vars_path = std.fmt.allocPrint(allocator_global, "{s}/static/style_variables.css", .{release_dir}) catch |err|
        generatorFatal("building the style_variables.css path", err, release_dir);
    var css_variables = cwd.createFile(io, css_vars_path, .{}) catch |err|
        generatorFatal("creating file", err, css_vars_path);
    css_variables.writePositionalAll(io, StyleCompiler.global_style, 0) catch |err|
        generatorFatal("writing file", err, css_vars_path);

    // The client-rendered shell, for paths no prerendered page covers:
    // dynamic routes and unknown paths (which render the /error page). Point
    // the host's fallback for unmatched paths at it.
    const shell_path = std.fmt.allocPrint(allocator_global, "{s}/app.html", .{release_dir}) catch |err|
        generatorFatal("building the app.html path", err, release_dir);
    cwd.copyFile("template.html", cwd, shell_path, io, .{}) catch |err|
        generatorFatal("copying template.html to", err, shell_path);

    var page_itr = page_map.iterator();
    while (page_itr.next()) |entry| {
        writer = std.Io.Writer.fixed(&buffer);
        const route = entry.key_ptr.*;

        // A dynamic route has no single page to prerender; it renders on the
        // client from app.html. (Writing it out produced literal `:id`
        // directories that no URL maps to.)
        if (std.mem.indexOf(u8, route, "/:") != null) {
            std.debug.print("client-rendered only (dynamic): {s}\n", .{route[@min(route.len, 5)..]});
            continue;
        }

        // Strip "/root" — "/root/components" becomes "/components"
        const stripped = if (route.len > 5) route[5..] else "/";
        const dir = if (stripped.len > 1) stripped[1..] else "";

        // Create nested dirs under release/
        if (dir.len > 0) {
            var sub_dirs = std.mem.tokenizeScalar(u8, dir, '/');
            var current_dir: []const u8 = release_dir;
            while (sub_dirs.next()) |sub_dir| {
                current_dir = std.fmt.allocPrint(allocator_global, "{s}/{s}", .{
                    current_dir,
                    sub_dir,
                }) catch |err| generatorFatal("building a route directory path", err, sub_dir);
                ensureDir(io, cwd, current_dir);
            }
        }

        // release/index.html or release/components/index.html
        const path = if (dir.len == 0)
            std.fmt.allocPrint(allocator_global, "{s}/index.html", .{release_dir}) catch |err|
                generatorFatal("building the index.html path", err, release_dir)
        else
            std.fmt.allocPrint(allocator_global, "{s}/{s}/index.html", .{ release_dir, dir }) catch |err|
                generatorFatal("building the index.html path", err, dir);
        defer allocator_global.free(path);

        generated_file = cwd.createFile(io, path, .{}) catch |err|
            generatorFatal("creating file", err, path);
        defer generated_file.close(io);

        generateHtml(route, dir);
        _ = generated_file.writePositionalAll(io, writer.buffer[0..writer.end], 0) catch |err|
            generatorFatal("writing file", err, path);
    }
    const assets_dest = std.fmt.allocPrint(allocator_global, "{s}/assets", .{release_dir}) catch |err|
        generatorFatal("building the assets/ path", err, release_dir);
    copyDirRecursive(io, cwd, "assets", assets_dest);

    // Copy the JS runtime into release/. The build installs the copy that
    // ships with this vapor version to zig-out/bin/, which is the one that
    // matches the wasm; the other locations are for projects that predate it.
    var dest_dir = cwd.openDir(io, release_dir, .{}) catch return;
    defer dest_dir.close(io);
    // browser.min.js (optional browser-API bindings) is loaded from beside the
    // core bundle, so it goes along when the build installed it.
    cwd.copyFile("zig-out/bin/browser.min.js", dest_dir, "browser.min.js", io, .{}) catch {};
    const bundle_sources = [_][]const u8{ "zig-out/bin/bundle.min.js", "bundle.min.js", "static/bundle.min.js" };
    const copied = for (bundle_sources) |src| {
        cwd.copyFile(src, dest_dir, "bundle.min.js", io, .{}) catch continue;
        break true;
    } else false;
    if (!copied) {
        if (dest_dir.access(io, "bundle.min.js", .{})) |_| {} else |_| {
            std.debug.print("warning: no bundle.min.js found (looked in zig-out/bin/, ./ and static/); {s}/ will not load\n", .{release_dir});
        }
    }

    generating = false;
}

pub fn generateHtml(route: []const u8, dir: []const u8) void {
    _ = dir;
    const cwd = std.Io.Dir.cwd();
    var threaded: std.Io.Threaded = .init_single_threaded;
    const io = threaded.io();

    status = .{};
    frame_arena.beginFrame(); // For double-buffered approach
    frame_arena.resetScratchArena();

    if (!std.mem.eql(u8, current_route, route)) {
        changed_route = true;
        // We need to start a new route allocator
        // otherwise we are on the same route
        frame_arena.beginView();
    }

    current_route = route;
    added_nodes.clearRetainingCapacity();
    dirty_nodes.clearRetainingCapacity();
    nodes_with_events.clearRetainingCapacity();

    const old_route_op = router.searchRoute(route) orelse blk: {
        printlnSrcErr("No Route found", .{}, @src());
        break :blk router.searchRoute("/root/error") orelse {
            printlnSrcErr("No Error Route found", .{}, @src());
            status.valid_url = false;
            break :blk null;
        };
    };
    if (old_route_op) |old_route| {
        render_page = old_route.page;
        route_params = old_route.params;
    } else {
        render_page = DefaultPage;
        route_params = &.{};
    }

    const old_ctx = current_ctx;
    // Create new context
    const new_ctx: *UIContext = arena(.frame).create(UIContext) catch {
        status.render_cycle = false;
        println("Failed to allocate UIContext\n", .{});
        return;
    };

    UIContext.initContext(new_ctx) catch |err| {
        status.render_cycle = false;
        println("Allocator ran out of space {any}\n", .{err});
        new_ctx.deinit();
        allocator_global.destroy(new_ctx);
        return;
    };

    new_ctx.root.?.uuid = old_ctx.root.?.uuid;

    current_ctx = new_ctx;
    var route_itr = std.mem.tokenizeScalar(u8, route, '/');
    var count: usize = 0;
    while (route_itr.next()) |_| {
        count += 1;
    }
    route_segments = allocator_global.alloc([]const u8, count) catch return;
    count = 0;
    route_itr.reset();
    while (route_itr.next()) |route_token| {
        route_segments[count] = route_token;
        count += 1;
    }

    // Init the generator
    generator.init();
    next_layout_path_to_check = "";
    findResetLayout();
    // This calls the render tree, with render_page as the root function call
    // First it traverses the layouts calling them in order, and then it calls the render_page
    callNestedLayouts(); // 4.5ms

    changed_route = false;
    generator.writeAllStyles();
    const css = generator.getCSS();
    const frames = generator.getAnimations();

    // Write CSS to release/static/
    const style_fs_path = std.fmt.allocPrint(allocator_global, "{s}/static/style.css", .{release_dir}) catch |err|
        generatorFatal("building the style.css path", err, release_dir);

    var generated_css = cwd.createFile(io, style_fs_path, .{}) catch |err|
        generatorFatal("creating file", err, style_fs_path);
    defer generated_css.close(io);
    generated_css.writePositionalAll(io, css, 0) catch |err|
        generatorFatal("writing css", err, style_fs_path);
    const stat = generated_css.stat(io) catch |err|
        generatorFatal("stat", err, style_fs_path);
    generated_css.writePositionalAll(io, frames, stat.size) catch |err|
        generatorFatal("writing keyframes", err, style_fs_path);

    // Browser URL — not filesystem path
    HtmlGenerator.generate(new_ctx.root.?, &writer, "/static/style.css");
}

fn copyDirRecursive(io: anytype, cwd: std.Io.Dir, src: []const u8, dest: []const u8) void {
    // Ensure destination exists
    ensureDir(io, cwd, dest);

    var src_dir = cwd.openDir(io, src, .{ .iterate = true }) catch return;
    defer src_dir.close(io);

    var dest_dir = cwd.openDir(io, dest, .{}) catch return;
    defer dest_dir.close(io);

    var iter = src_dir.iterate();
    while (iter.next(io) catch return) |entry| {
        switch (entry.kind) {
            .directory => {
                const src_path = std.fmt.allocPrint(allocator_global, "{s}/{s}", .{ src, entry.name }) catch |err|
                    generatorFatal("building a source path", err, src);
                const dest_path = std.fmt.allocPrint(allocator_global, "{s}/{s}", .{ dest, entry.name }) catch |err|
                    generatorFatal("building a destination path", err, dest);
                copyDirRecursive(io, cwd, src_path, dest_path);
            },
            .file => {
                src_dir.copyFile(entry.name, dest_dir, entry.name, io, .{}) catch |err| {
                    std.debug.print("Copy error: {any} {s}/{s}\n", .{ err, src, entry.name });
                };
            },
            else => {},
        }
    }
}

const QueryModule = @import("Query.zig");
pub const printUIRouteTree = QueryModule.printUIRouteTree;
pub const printUITree = QueryModule.printUITree;
pub const escapeForJson = QueryModule.escapeForJson;
pub const replace_dash = QueryModule.replace_dash;
pub const queryComponentIds = QueryModule.queryComponentIds;
pub const queryByUUID = QueryModule.queryByUUID;
pub const mutateById = QueryModule.mutateById;
pub const MutationType = QueryModule.MutationType;
pub const mutateElementById = QueryModule.mutateElementById;
pub const Bounds = QueryModule.Bounds;
pub const Offsets = QueryModule.Offsets;
pub const getComponentOffsets = QueryModule.getComponentOffsets;
pub const getComponentBounds = QueryModule.getComponentBounds;
pub const iterateTreeChildren = QueryModule.iterateTreeChildren;

pub var ui_node_layout_info = packed struct {
    ui_node_size: u32,

    // Offsets within UINode
    elem_type_offset: u32,
    text_ptr_offset: u32,
    href_ptr_offset: u32,
    id_ptr_offset: u32,
    index_offset: u32,
    classname_ptr_offset: u32,

    hash_offset: u32,
    style_changed_offset: u32,
    props_changed_offset: u32,
    dirty_offset: u32,
    hooks_offset: u32,
    style_hash_offset: u32,
    accessibility_offset: u32,
    on_callbacks_offset: u32,
    hooks_changed_offset: u32,
    morph_offset: u32,
    layer_offset: u32,
}{
    .ui_node_size = @sizeOf(UINode),

    // --- Direct fields of RenderCommand ---
    .elem_type_offset = @offsetOf(UINode, "type"),
    .text_ptr_offset = @offsetOf(UINode, "text"),
    .href_ptr_offset = @offsetOf(UINode, "href"),
    .id_ptr_offset = @offsetOf(UINode, "uuid"),
    .index_offset = @offsetOf(UINode, "index"),
    .classname_ptr_offset = @offsetOf(UINode, "class"),

    // --- Nested struct sizes and offsets ---
    .hash_offset = @offsetOf(UINode, "hash"),
    .style_changed_offset = @offsetOf(UINode, "style_changed"),
    .props_changed_offset = @offsetOf(UINode, "props_changed"),
    .dirty_offset = @offsetOf(UINode, "dirty"),
    .hooks_offset = @offsetOf(UINode, "hooks"),
    .style_hash_offset = @offsetOf(UINode, "style_hash"),
    .accessibility_offset = @offsetOf(UINode, "accessibility"),
    .on_callbacks_offset = @offsetOf(UINode, "on_callbacks"),
    .hooks_changed_offset = @offsetOf(UINode, "hooks_changed"),
    .morph_offset = @offsetOf(UINode, "morph"),
    .layer_offset = @offsetOf(UINode, "layer"),
};

// Make sure this function is not evaluated at compile time
const HexModule = @import("Hex.zig");
pub const hexToRgba = HexModule.hexToRgba;

/// fmtln is a wrapper around std.fmt.allocPrint that allocates memory from the frame allocator
/// this means that this slice is deallocated on each frame
/// this is useful for formatting ids passed into the style struct
pub fn fmtln(
    comptime fmt: []const u8,
    args: anytype,
) []const u8 {
    const allocator = arena(.frame);
    const buf = std.fmt.allocPrint(allocator, fmt, args) catch |err| {
        println("Formatting, Error Could not format argument alloc Error details: {any}\n", .{err});
        return "";
    };
    return buf;
}

pub fn fmtArena(
    comptime fmt: []const u8,
    args: anytype,
    arena_type: ArenaType,
) []const u8 {
    const allocator = arena(arena_type);
    const buf = std.fmt.allocPrint(allocator, fmt, args) catch |err| {
        println("Formatting, Error Could not format argument alloc Error details: {any}\n", .{err});
        return "";
    };
    return buf;
}

pub fn dupe(
    args: []const u8,
    allocator_type: ArenaType,
) []const u8 {
    const allocator = arena(allocator_type);
    const buf = allocator.dupe(u8, args) catch |err| {
        println("Formatting, Error Could not format argument alloc Error details: {any}\n", .{err});
        return "";
    };
    return buf;
}

pub fn pin(value: []const u8) void {
    _ = string_table.intern(value) catch |err| {
        printlnErr("pin: could not intern, string stays unpinned: {any}", .{err});
    };
}

pub fn unpin(value: []const u8) void {
    const handle = string_table.handleOf(value) orelse return;
    _ = string_table.remove(handle);
}

pub fn compact() void {
    string_table.compact() catch |err| {
        printlnErr("compact: string table left as-is: {any}", .{err});
    };
}

pub fn cloneFrame(
    value: anytype,
) []const u8 {
    const T = @TypeOf(value);
    if (T == []const u8) return fmtln("{s}", .{value});
    const allocator = arena(.frame);
    const memory: *@TypeOf(value) = allocator.create(T) catch |err| {
        printlnErr("cloneFrame: could not allocate: {any}", .{err});
        return "";
    };
    memory.* = value;
    return memory.*;
}

const LogModule = @import("Log.zig");
pub const printlnErr = LogModule.printlnErr;
pub const print = LogModule.print;
pub const printErr = LogModule.printErr;
pub const printWarn = LogModule.printWarn;
pub const printInfo = LogModule.printInfo;
pub const printDebug = LogModule.printDebug;
pub const printlnSrcErr = LogModule.printlnSrcErr;
pub const printlnWithColor = LogModule.printlnWithColor;
pub const printlnColor = LogModule.printlnColor;
pub const printlnAllocation = LogModule.printlnAllocation;
pub const printlnSrc = LogModule.printlnSrc;
pub const println = LogModule.println;
pub const log = LogModule.log;
pub const alert = LogModule.alert;

pub extern "env" fn consoleLogWasm(
    level: u32,
    msg_ptr: [*]const u8,
    msg_len: usize,
    style_ptr: [*]const u8,
    style_len: usize,
) callconv(.c) void;

// Convenience wrappers (optional)

/// name: name of the interval
/// cb: callback function
/// args: arguments to pass to the callback function
/// delay: delay in ms
pub fn loopInterval(name: []const u8, delay_ms: u32, callback: anytype, args: anytype) void {
    const erased = Vapor.ErasedCallback.make(Vapor.arena(.frame), callback, args) catch |err| {
        printlnErr("loopInterval '{s}': could not allocate closure, interval not started: {any}", .{ name, err });
        return;
    };

    const callback_id: u32 = hashKey(name);
    // Store just the ErasedCallback instead of *Node
    Vapor.erased_registry.put(callback_id, erased) catch |err| {
        printlnErr("loopInterval '{s}': could not register, interval not started: {any}", .{ name, err });
        return;
    };

    if (isWasi) {
        Wasm.createInterval(callback_id, delay_ms);
    }
}

pub fn timeout(callback_name: []const u8, ms: u32, cb: anytype, args: anytype) void {
    const Args = @TypeOf(args);
    const Closure = struct {
        arguments: Args,
        run_node: Node = .{ .data = .{ .runFn = runFn, .deinitFn = deinitFn } },
        //
        fn runFn(action: *Action) void {
            const run_node: *Node = @fieldParentPtr("data", action);
            const closure: *@This() = @alignCast(@fieldParentPtr("run_node", run_node));
            @call(.auto, cb, closure.arguments);
        }
        //
        fn deinitFn(node: *Node) void {
            const closure: *@This() = @alignCast(@fieldParentPtr("run_node", node));
            allocator_global.destroy(closure);
        }
    };

    const closure = allocator_global.create(Closure) catch |err| {
        printlnErr("timeout: could not allocate closure, callback not scheduled: {any}", .{err});
        return;
    };
    closure.* = .{
        .arguments = args,
    };

    const callback_id = hashKey(callback_name);
    ctx_callback_registry.put(callback_id, &closure.run_node) catch |err| {
        println("Button Function Registry {any}\n", .{err});
    };

    if (isWasi) {
        Wasm.timeoutCtx(ms, callback_id);
    } else {
        return;
    }
}

pub fn cancelTimeout(callback_name: []const u8) void {
    const callback_id = hashKey(callback_name);
    if (isWasi) {
        Wasm.cancelTimeoutWasm(callback_id);
    }
}

pub fn registerTimeout(ms: u32, cb: *const fn () void) void {
    const id = callback_registry.count() + 1;
    callback_registry.put(id, cb) catch |err| {
        println("Button Function Registry {any}\n", .{err});
    };
    if (isWasi) {
        Wasm.timeout(ms, id);
    } else {
        return;
    }
}

pub const Clipboard = struct {
    pub fn copy(text: []const u8) void {
        if (isWasi) {
            Wasm.copyTextWasm(text.ptr, text.len);
        }
    }
    fn paste(_: []const u8) void {}
};

pub fn onPopState(callback: *const fn () void) void {
    pop_state_funcs.append(callback) catch |err| {
        printlnErr("Button Function Registry {any}\n", .{err});
    };
}

pub fn onPushState(callback: *const fn () void) void {
    push_state_funcs.append(callback) catch |err| {
        printlnErr("Button Function Registry {any}\n", .{err});
    };
}

pub const Binded = Element;

/// onMount should be called inside the UI
pub fn onMount(callback: anytype, args: anytype) void {
    if (@typeInfo(@TypeOf(callback)) != .@"fn") {
        @compileError("onMount callback must be a function, got " ++ @typeName(@TypeOf(callback)));
    }

    const callback_id: u32 = @intFromPtr(&callback);

    const ui_node = current_ctx.currentNode() orelse {
        std.log.err("No current node found", .{});
        return;
    };

    if (ui_node.on_callbacks[0] != 0) {
        std.log.err("onMount callback already exists on Element: {s}\n Using first created callback", .{ui_node.uuid});
        return;
    }

    const erased = Vapor.ErasedCallback.make(Vapor.arena(.frame), callback, args) catch |err| {
        Vapor.println("Error could not create closure {any}\n", .{err});
        return;
    };

    Vapor.erased_hooks_registry.put(callback_id, erased) catch |err| {
        Vapor.printlnErr("Could Not add mount callback {any}", .{err});
        return;
    };
    ui_node.on_callbacks[0] = callback_id;
}

pub fn onLayout(callback: anytype, args: anytype) void {
    const Args = @TypeOf(args);
    const Closure = struct {
        arguments: Args,
        run_node: Vapor.Node = .{ .data = .{ .runFn = runFn, .deinitFn = deinitFn } },
        //
        fn runFn(action: *Vapor.Action) void {
            const run_node: *Vapor.Node = @fieldParentPtr("data", action);
            const closure: *@This() = @alignCast(@fieldParentPtr("run_node", run_node));
            @call(.auto, callback, closure.arguments);
        }
        //
        fn deinitFn(node: *Vapor.Node) void {
            const closure: *@This() = @alignCast(@fieldParentPtr("run_node", node));
            Vapor.allocator_global.destroy(closure);
        }
    };

    const closure = Vapor.allocator_global.create(Closure) catch |err| {
        printlnErr("onLayout: could not allocate closure, callback not scheduled: {any}", .{err});
        return;
    };
    closure.* = .{
        .arguments = args,
    };

    Vapor.on_end_ctx_funcs.append(&closure.run_node) catch |err| {
        println("Hooks Function Registry {any}\n", .{err});
    };
}

/// This hook takes a function callback and calls it after the virtual dom has been created
/// WARNING: This is a dangerous hook, and can cause infinite loops
pub fn onCommit(callback: *const fn () void) void {
    on_commit_funcs.append(callback) catch |err| {
        printlnErr("Button Function Registry {any}\n", .{err});
    };
}

pub fn onCommitCtx(callback: anytype, args: anytype) void {
    const Args = @TypeOf(args);
    const Closure = struct {
        arguments: Args,
        run_node: Vapor.Node = .{ .data = .{ .runFn = runFn, .deinitFn = deinitFn } },
        //
        fn runFn(action: *Vapor.Action) void {
            const run_node: *Vapor.Node = @fieldParentPtr("data", action);
            const closure: *@This() = @alignCast(@fieldParentPtr("run_node", run_node));
            @call(.auto, callback, closure.arguments);
        }
        //
        fn deinitFn(node: *Vapor.Node) void {
            const closure: *@This() = @alignCast(@fieldParentPtr("run_node", node));
            Vapor.allocator_global.destroy(closure);
        }
    };

    const closure = Vapor.arena(.frame).create(Closure) catch |err| {
        printlnErr("onCommitCtx: could not allocate closure, callback not scheduled: {any}", .{err});
        return;
    };
    closure.* = .{
        .arguments = args,
    };

    Vapor.on_commit_ctx_funcs.append(&closure.run_node) catch |err| {
        println("Hooks Function Registry {any}\n", .{err});
    };
}

pub fn onCommitCtxCallback() void {
    const length = Vapor.on_commit_ctx_funcs.items.len;
    if (length == 0) return;
    var i: usize = length - 1;
    while (i >= 0) : (i -= 1) {
        const node = Vapor.on_commit_ctx_funcs.orderedRemove(i);
        @call(.auto, node.data.runFn, .{&node.data});
        if (i == 0) return;
    }
}

pub export fn hasLayoutFunctions() bool {
    const length = Vapor.on_end_ctx_funcs.items.len;
    if (length == 0) return false;
    return true;
}

pub export fn onLayoutCallback() callconv(.c) void {
    const length = Vapor.on_end_ctx_funcs.items.len;
    if (length == 0) return;
    var i: usize = length - 1;
    while (i >= 0) : (i -= 1) {
        const node = Vapor.on_end_ctx_funcs.orderedRemove(i);
        @call(.auto, node.data.runFn, .{&node.data});
        if (i == 0) return;
    }
}

pub export fn getVideo(uinode: *UINode) callconv(.c) ?*const types.Video {
    if (uinode.video) |video| {
        return video;
    }
    return null;
}

pub export fn onPopStateCallback() callconv(.c) void {
    const length = Vapor.pop_state_funcs.items.len;
    if (length == 0) return;
    var i: usize = length - 1;
    while (i >= 0) : (i -= 1) {
        const call = Vapor.pop_state_funcs.items[i];
        @call(.auto, call, .{});
        if (i == 0) return;
    }
}

pub export fn callbackCtx(callback_ptr: u32, object_ptr: ?*DynamicObject) callconv(.c) void {
    const node = Vapor.ctx_callback_registry.get(callback_ptr) orelse {
        std.log.err("Ctx Callback Not found {any}\n", .{callback_ptr});
        return;
    };
    node.data.dynamic_object = object_ptr;
    @call(.auto, node.data.runFn, .{&node.data});
    if (Vapor.mode == .atomic) {
        Vapor.cycle();
    }
}

pub export fn resizeCallback(resize_callback: u32, object_ptr: ?*DynamicObject) callconv(.c) void {
    if (object_ptr == null) {
        std.log.err("Resize Entry is Null", .{});
        return;
    }
    const erased = Vapor.resize_callbacks.get(resize_callback) orelse {
        std.log.err("Resize Ctx Callback Not found {any}\n", .{resize_callback});
        return;
    };

    erased.call(object_ptr.?);
}

// --- Rendering & Tree Management ---
pub export fn renderUI(route: [*:0]u8) callconv(.c) u32 {
    Vapor.renderCycle(route) catch |err| {
        printlnSrcErr("Error while rendering", .{}, @src());
        switch (err) {
            error.NoRouteFound => {
                printlnSrcErr("No Route found", .{}, @src());
            },
        }
        return 0;
    };
    return 1;
}

pub export fn getRenderTreePtr() callconv(.c) ?*UIContext.CommandsTree {
    const tree_op = Vapor.current_ctx.ui_tree;
    if (tree_op != null) {
        return Vapor.current_ctx.ui_tree.?;
    }
    return null;
}

pub export fn getRenderUINodeRootPtr() callconv(.c) ?*UINode {
    if (Vapor.current_ctx.root == null) return null;
    return Vapor.current_ctx.root.?;
}

pub export fn getUINodeChildrenCount(node_ptr: ?*UINode) callconv(.c) usize {
    const node = node_ptr orelse return 0;
    return node.children_count;
}

pub export fn getUINodeChild(node_ptr: ?*UINode, index: u32) callconv(.c) ?*UINode {
    const node = node_ptr orelse return null;
    return node.childAt(index);
}

// Zig side - export first child and next sibling
pub export fn getUINodeFirstChild(node_ptr: ?*UINode) callconv(.c) ?*UINode {
    const node = node_ptr orelse return null;
    return node.first_child;
}

pub export fn getUINodeNextSibling(node_ptr: ?*UINode) callconv(.c) ?*UINode {
    const node = node_ptr orelse return null;
    return node.next_sibling;
}

pub export fn markCurrentTreeNotDirty() callconv(.c) void {
    if (!Vapor.has_context) return;
    const root = Vapor.current_ctx.root orelse return;
    Vapor.markChildrenNotDirty(root);
}

// --- Layout & Allocation ---

pub export fn allocateUINodeLayoutInfo() callconv(.c) *u8 {
    const ui_info_ptr: *u8 = @ptrCast(&Vapor.ui_node_layout_info);
    return ui_info_ptr;
}

pub export fn allocUint8(length: u32) callconv(.c) [*]const u8 {
    const slice = Vapor.allocator_global.alloc(u8, length) catch
        @panic("failed to allocate memory");
    return slice.ptr;
}

pub export fn allocUint8Frame(length: u32) callconv(.c) [*]const u8 {
    const slice = Vapor.getFrameAllocator().alloc(u8, length) catch
        @panic("failed to allocate memory");
    return slice.ptr;
}

pub export fn allocate(size: usize) callconv(.c) ?[*]f32 {
    const buf = Vapor.allocator_global.alloc(f32, size) catch |err| {
        Vapor.println("{any}\n", .{err});
        return null;
    };
    return buf.ptr;
}

pub export fn allocateU32(size: usize) callconv(.c) ?[*]u32 {
    const buf = Vapor.arena(.persist).alloc(u32, size) catch |err| {
        Vapor.println("{any}\n", .{err});
        return null;
    };
    return buf.ptr;
}

// --- CSS & Commands ---

pub export fn getCSS() callconv(.c) ?[*]const u8 {
    return Vapor.generator.getCSS().ptr;
}

pub export fn getCSSLen() callconv(.c) usize {
    return Vapor.generator.end;
}

pub export fn getRenderCommandPtr(tree: *CommandsTree) callconv(.c) [*]u8 {
    if (std.mem.eql(u8, tree.node.id, "global-style")) {
        Vapor.println("getRenderCommandPtr {any}\n", .{tree.node.node_ptr.dirty});
    }
    return @ptrCast(tree.node);
}

pub export fn getTreeNodeChildrenCount(tree: *CommandsTree) callconv(.c) usize {
    return tree.children.items.len;
}

pub export fn getTreeNodeChild(tree: *CommandsTree, index: usize) callconv(.c) *CommandsTree {
    const child = tree.children.items[index];
    return child;
}

// --- Removal Handling ---
pub export fn shouldRerender() callconv(.c) bool {
    return Vapor.global_rerender;
}

pub export fn forceRerender() callconv(.c) void {
    Vapor.global_rerender = true;
}

pub export fn rerenderEverything() callconv(.c) void {
    if (!Vapor.isWasi) return;
    browser_width = Wasm.windowWidth();
    browser_height = Wasm.windowHeight();
    Vapor.global_rerender = true;
    Vapor.rerender_everything = true;
}

pub export fn hasDirty() callconv(.c) bool {
    return Vapor.has_dirty;
}

pub export fn resetRerender() callconv(.c) void {
    Vapor.global_rerender = false;
    Vapor.rerender_everything = false;
    Vapor.has_dirty = false;
    Vapor.status = .{};
}

pub export fn resetPacker() callconv(.c) void {
    Packer.animations.clearRetainingCapacity();
    Packer.layouts.clearRetainingCapacity();
    Packer.positions.clearRetainingCapacity();
    Packer.margins_paddings.clearRetainingCapacity();
    Packer.visuals.clearRetainingCapacity();
    Packer.interactives.clearRetainingCapacity();
    Packer.transforms.clearRetainingCapacity();
    Packer.responsives.clearRetainingCapacity();
    UIContext.element_style_hash_map.clearRetainingCapacity();
}

pub export fn setRouteRenderTree(ptr: [*:0]u8) callconv(.c) u32 {
    Vapor.renderCycle(ptr) catch |err| {
        printlnSrcErr("Error while rendering", .{}, @src());
        switch (err) {
            error.NoRouteFound => {
                printlnSrcErr("No Route found", .{}, @src());
            },
        }
        return 0;
    };
    return 1;
}

pub export fn getDirtyValue(node: *UINode) callconv(.c) bool {
    return node.dirty;
}

pub const std_options = std.Options{
    .log_level = .debug,
    .logFn = log,
};

export fn recordState(err_str: [*:0]u8, event_str: ?[*:0]u8) void {
    _ = err_str;
    _ = event_str;
}

pub const ErasedCallback = struct {
    ctx: *anyopaque,
    callFn: *const fn (*anyopaque) void,
    deinitFn: *const fn (*anyopaque) void,

    pub fn call(self: *const ErasedCallback) void {
        self.callFn(self.ctx);
    }

    pub fn deinit(self: *ErasedCallback) void {
        self.deinitFn(self.ctx);
    }

    pub fn make(allocator: std.mem.Allocator, cb: anytype, args: anytype) !ErasedCallback {
        const Args = @TypeOf(args);

        // cb is captured by the comptime closure below — not stored in the struct
        const Closure = struct {
            arguments: Args,

            fn run(ptr: *anyopaque) void {
                const self: *@This() = @ptrCast(@alignCast(ptr));
                @call(.auto, cb, self.arguments);
            }

            fn destroy(_: *anyopaque) void {
                // const self: *@This() = @ptrCast(@alignCast(ptr));
                // allocator.destroy(self);
            }
        };

        const closure = try allocator.create(Closure);
        closure.* = .{
            .arguments = args,
        };

        return .{
            .ctx = @ptrCast(closure),
            .callFn = Closure.run,
            .deinitFn = Closure.destroy,
        };
    }
};

pub fn startViewTransition(callback: anytype, args: anytype) void {
    const erased = Vapor.ErasedCallback.make(Vapor.arena(.frame), callback, args) catch |err| {
        printlnErr("view transition: could not allocate closure, transition skipped: {any}", .{err});
        return;
    };

    const callback_id: u32 = hashKey("view-transition");
    // Store just the ErasedCallback instead of *Node
    Vapor.erased_registry.put(callback_id, erased) catch |err| {
        printlnErr("view transition: could not register callback, transition skipped: {any}", .{err});
        return;
    };

    if (isWasi) {
        Wasm.startViewTransitionWasm(callback_id);
    }
}

/// Gives `node` a caller-chosen id (`.id()`, `.src()`).
///
/// Everything keyed by the node's hash has to follow the new id. JS reports a
/// button click by `node.hash`, and the generated id the node had is handed
/// back to its parent (`refundUnkeyedSlot`) for the next unkeyed sibling. Left
/// under the old hash, a button's callback was overwritten by that sibling's,
/// so every `.id()`'d button in a row ran the last one's handler.
pub fn assignUserId(node: *UINode, new_id: []const u8) void {
    const old_hash = node.hash;
    node.refundUnkeyedSlot();
    node.uuid = new_id;
    node.hash = hashKey(new_id);
    node.prev_style_hash = UIContext.prev_style_hashes.get(node.hash) orelse 0;
    if (old_hash == node.hash) return;
    moveEntry(&erased_registry, old_hash, node.hash);
    moveEntry(&element_registry, old_hash, node.hash);
}

fn moveEntry(map: anytype, from: u32, to: u32) void {
    const kv = map.fetchRemove(from) orelse return;
    map.put(to, kv.value) catch |err| {
        printlnErr("assignUserId: could not re-register entry, it is lost: {any}", .{err});
    };
}

// The JS/WASM side calls back with the id:
export fn invokeErasedCallback(id: u32) void {
    var erased = erased_registry.get(id) orelse {
        std.log.err("Erased Callback not found {d}", .{id});
        return;
    };
    erased.call();
    if (Vapor.mode == .atomic) {
        Vapor.cycle();
    }
}

// The JS/WASM side calls back with the id:
export fn invokeHooksErasedCallback(id: u32) void {
    var erased = erased_hooks_registry.get(id) orelse {
        std.log.err("Hooks Callback not found {d}", .{id});
        return;
    };
    erased.call();
}

pub const ArrayArena = @import("Array.zig").Array;

pub const persist = struct {
    pub fn dupe(value: []const u8) []const u8 {
        const _allocator = Vapor.arena(.persist);
        const buf = _allocator.dupe(u8, value) catch |err| {
            println("Formatting, Error Could not format argument alloc Error details: {any}\n", .{err});
            return "";
        };
        return buf;
    }

    pub fn free(memory: anytype) void {
        const _allocator = Vapor.arena(.persist);
        _allocator.free(memory);
    }

    pub fn alloc(comptime T: type, size: usize) ![]T {
        return Vapor.arena(.persist).alloc(T, size) catch |err| {
            println("Formatting, Error Could not format argument alloc Error details: {any}\n", .{err});
            return err;
        };
    }

    pub fn fmt(comptime _fmt: []const u8, args: anytype) []const u8 {
        const _allocator = Vapor.arena(.persist);
        const buf = std.fmt.allocPrint(_allocator, _fmt, args) catch |err| {
            println("Formatting, Error Could not format argument alloc Error details: {any}\n", .{err});
            return "";
        };
        return buf;
    }

    pub fn array(comptime T: type) ArrayArena(T) {
        return ArrayArena(T).init(.persist);
    }

    pub fn arena() std.mem.Allocator {
        return Vapor.arena(.persist);
    }

    pub fn allocator() std.mem.Allocator {
        return Vapor.arena(.persist);
    }

    pub fn Array(comptime T: type) ArrayArena(T) {
        return ArrayArena(T).init(.persist);
    }

    // Join slices: &.{"a", "b", "c"} with ", " -> "a, b, c"
    pub fn join(parts: []const []const u8, separator: []const u8) []const u8 {
        const _allocator = Vapor.arena(.persist);
        return std.mem.join(_allocator, separator, parts) catch |err| {
            println("join: could not allocate, returning empty. {any}\n", .{err});
            return "";
        };
    }

    // Split string into slice of slices
    pub fn split(str: []const u8, delimiter: []const u8) std.mem.SplitIterator(u8, .sequence) {
        const _allocator = Vapor.arena(.persist);
        var split_buffer = _allocator.alloc(u8, str.len) catch |err| {
            println("split: could not allocate, returning empty. {any}\n", .{err});
            return std.mem.splitSequence(u8, "", delimiter);
        };
        @memcpy(split_buffer[0..], str);
        return std.mem.splitSequence(u8, split_buffer[0..], delimiter);
    }

    // Repeat: repeat("ha", 3) -> "hahaha"
    pub fn repeat(str: []const u8, count: usize) []const u8 {
        const _allocator = Vapor.arena(.persist);
        const list = _allocator.alloc([]const u8, count) catch |err| {
            println("repeat: could not allocate, returning empty. {any}\n", .{err});
            return "";
        };
        @memset(list, str);
        return std.mem.join(_allocator, "", list) catch |err| {
            println("repeat: could not allocate, returning empty. {any}\n", .{err});
            return "";
        };
    }

    pub fn toLowerCase(str: []const u8) []const u8 {
        return utils.toLowerCase(str, .persist);
    }

    pub fn toUpperCase(str: []const u8) []const u8 {
        return utils.toUpperCase(str, .persist);
    }

    pub fn firstLetterToUpper(str: []const u8) []const u8 {
        return utils.firstLetterToUpper(str, .persist);
    }

    pub fn contains(str: []const u8, needle: []const u8) bool {
        return utils.contains(str, needle);
    }

    pub fn startsWith(str: []const u8, prefix: []const u8) bool {
        return utils.startsWith(str, prefix);
    }
};

pub const view = struct {
    pub fn dupe(value: []const u8) []const u8 {
        const allocator = Vapor.arena(.view);
        const buf = allocator.dupe(u8, value) catch |err| {
            println("Formatting, Error Could not format argument alloc Error details: {any}\n", .{err});
            return "";
        };
        return buf;
    }
    pub fn fmt(comptime _fmtln: []const u8, args: anytype) []const u8 {
        const allocator = Vapor.arena(.view);
        const buf = std.fmt.allocPrint(allocator, _fmtln, args) catch |err| {
            println("Formatting, Error Could not format argument alloc Error details: {any}\n", .{err});
            return "";
        };
        return buf;
    }

    pub fn HashMap(comptime K: type, comptime V: type) std.AutoHashMap(K, V) {
        return std.AutoHashMap(K, V).init(Vapor.view.arena());
    }

    pub fn array(comptime T: type) ArrayArena(T) {
        return ArrayArena(T).init(.view);
    }

    pub fn Array(comptime T: type) ArrayArena(T) {
        return ArrayArena(T).init(.view);
    }

    pub fn arena() std.mem.Allocator {
        return Vapor.arena(.view);
    }

    pub fn toLowerCase(str: []const u8) []const u8 {
        return utils.toLowerCase(str, .view);
    }

    pub fn toUpperCase(str: []const u8) []const u8 {
        return utils.toUpperCase(str, .view);
    }

    pub fn firstLetterToUpper(str: []const u8) []const u8 {
        return utils.firstLetterToUpper(str, .view);
    }

    pub fn contains(str: []const u8, needle: []const u8) bool {
        return utils.contains(str, needle);
    }

    pub fn startsWith(str: []const u8, prefix: []const u8) bool {
        return utils.startsWith(str, prefix);
    }
};

pub const frame = struct {
    pub fn dupe(value: []const u8) []const u8 {
        const allocator = Vapor.arena(.frame);
        const buf = allocator.dupe(u8, value) catch |err| {
            println("Formatting, Error Could not format argument alloc Error details: {any}\n", .{err});
            return "";
        };
        return buf;
    }
    pub fn fmt(comptime _fmtln: []const u8, args: anytype) []const u8 {
        // _ = args;
        // return _fmtln;
        const allocator = Vapor.arena(.frame);
        const buf = std.fmt.allocPrint(allocator, _fmtln, args) catch |err| {
            println("Formatting, Error Could not format argument alloc Error details: {any}\n", .{err});
            return "";
        };
        return buf;
    }

    pub fn free(memory: anytype) void {
        const _allocator = Vapor.arena(.frame);
        _allocator.free(memory);
    }

    pub fn alloc(comptime T: type, size: usize) ![]T {
        return Vapor.arena(.frame).alloc(T, size) catch |err| {
            println("Formatting, Error Could not format argument alloc Error details: {any}\n", .{err});
            return err;
        };
    }

    pub fn HashMap(comptime K: type, comptime V: type) std.AutoHashMap(K, V) {
        return std.AutoHashMap(K, V).init(Vapor.frame.arena());
    }

    pub fn array(comptime T: type) ArrayArena(T) {
        return ArrayArena(T).init(.frame);
    }

    pub fn Array(comptime T: type) ArrayArena(T) {
        return ArrayArena(T).init(.frame);
    }

    pub fn arena() std.mem.Allocator {
        return Vapor.arena(.frame);
    }

    // Join slices: &.{"a", "b", "c"} with ", " -> "a, b, c"
    pub fn join(parts: []const []const u8, separator: []const u8) []const u8 {
        const allocator = Vapor.arena(.frame);
        return std.mem.join(allocator, separator, parts) catch |err| {
            println("join: could not allocate, returning empty. {any}\n", .{err});
            return "";
        };
    }

    // Split string into slice of slices
    pub fn split(str: []const u8, delimiter: []const u8) std.mem.SplitIterator(u8, .sequence) {
        return std.mem.splitSequence(u8, str, delimiter);
    }

    // Repeat: repeat("ha", 3) -> "hahaha"
    pub fn repeat(str: []const u8, count: usize) []const u8 {
        const allocator = Vapor.arena(.frame);
        const list = allocator.alloc([]const u8, count) catch |err| {
            println("repeat: could not allocate, returning empty. {any}\n", .{err});
            return "";
        };
        @memset(list, str);
        return std.mem.join(allocator, "", list) catch |err| {
            println("repeat: could not allocate, returning empty. {any}\n", .{err});
            return "";
        };
    }

    pub fn toLowerCase(str: []const u8) []const u8 {
        return utils.toLowerCase(str, .frame);
    }

    pub fn toUpperCase(str: []const u8) []const u8 {
        return utils.toUpperCase(str, .frame);
    }

    pub fn firstLetterToUpper(str: []const u8) []const u8 {
        return utils.firstLetterToUpper(str, .frame);
    }

    pub fn contains(str: []const u8, needle: []const u8) bool {
        return utils.contains(str, needle);
    }

    pub fn startsWith(str: []const u8, prefix: []const u8) bool {
        return utils.startsWith(str, prefix);
    }
};
