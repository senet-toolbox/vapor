//! Pools and lookup tables for packed style data, shared by nodes with equal
//! styles.

const std = @import("std");
const types = @import("types.zig");
const Abstractions = @import("abstractions.zig");
const ManagedMemoryPool = Abstractions.ManagedMemoryPool;
const ManagedAutoHashMap = Abstractions.ManagedAutoHashMap;

const Packer = @This();

// Now use these wrappers — the rest of your code barely changes
pub var visuals: ManagedAutoHashMap(u32, *types.PackedVisual) = undefined;
pub var layouts: ManagedAutoHashMap(u32, *types.PackedLayout) = undefined;
pub var positions: ManagedAutoHashMap(u32, *types.PackedPosition) = undefined;
pub var margins_paddings: ManagedAutoHashMap(u32, *types.PackedMarginsPaddings) = undefined;
pub var animations: ManagedAutoHashMap(u32, *types.PackedAnimations) = undefined;
pub var interactives: ManagedAutoHashMap(u32, *types.PackedInteractive) = undefined;
pub var transforms: ManagedAutoHashMap(u32, *types.PackedTransforms) = undefined;
pub var responsives: ManagedAutoHashMap(u32, *types.PackedResponsive) = undefined;

pub var layouts_pool: ManagedMemoryPool(types.PackedLayout) = undefined;
pub var positions_pool: ManagedMemoryPool(types.PackedPosition) = undefined;
pub var margins_paddings_pool: ManagedMemoryPool(types.PackedMarginsPaddings) = undefined;
pub var visuals_pool: ManagedMemoryPool(types.PackedVisual) = undefined;
pub var animations_pool: ManagedMemoryPool(types.PackedAnimations) = undefined;
pub var interactives_pool: ManagedMemoryPool(types.PackedInteractive) = undefined;
pub var transforms_pool: ManagedMemoryPool(types.PackedTransforms) = undefined;
pub var responsive_pool: ManagedMemoryPool(types.PackedResponsive) = undefined;

pub fn init(allocator: std.mem.Allocator) void {
    initPackedData(allocator);
    initPools(allocator);
}

fn initPackedData(persistent_allocator: std.mem.Allocator) void {
    visuals = ManagedAutoHashMap(u32, *types.PackedVisual).init(persistent_allocator);
    layouts = ManagedAutoHashMap(u32, *types.PackedLayout).init(persistent_allocator);
    positions = ManagedAutoHashMap(u32, *types.PackedPosition).init(persistent_allocator);
    margins_paddings = ManagedAutoHashMap(u32, *types.PackedMarginsPaddings).init(persistent_allocator);
    animations = ManagedAutoHashMap(u32, *types.PackedAnimations).init(persistent_allocator);
    interactives = ManagedAutoHashMap(u32, *types.PackedInteractive).init(persistent_allocator);
    transforms = ManagedAutoHashMap(u32, *types.PackedTransforms).init(persistent_allocator);
    responsives = ManagedAutoHashMap(u32, *types.PackedResponsive).init(persistent_allocator);
}

fn initPools(persistent_allocator: std.mem.Allocator) void {
    layouts_pool = ManagedMemoryPool(types.PackedLayout).init(persistent_allocator);
    positions_pool = ManagedMemoryPool(types.PackedPosition).init(persistent_allocator);
    margins_paddings_pool = ManagedMemoryPool(types.PackedMarginsPaddings).init(persistent_allocator);
    visuals_pool = ManagedMemoryPool(types.PackedVisual).init(persistent_allocator);
    animations_pool = ManagedMemoryPool(types.PackedAnimations).init(persistent_allocator);
    interactives_pool = ManagedMemoryPool(types.PackedInteractive).init(persistent_allocator);
    transforms_pool = ManagedMemoryPool(types.PackedTransforms).init(persistent_allocator);
    responsive_pool = ManagedMemoryPool(types.PackedResponsive).init(persistent_allocator);
}
