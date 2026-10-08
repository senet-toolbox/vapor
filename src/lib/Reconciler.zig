const std = @import("std");
const UIContext = @import("UITree.zig");
const Vapor = @import("Vapor.zig");
const Style = @import("types.zig").Style;
const Color = @import("types.zig").Color;
const UINode = @import("UITree.zig").UINode;
const utils = @import("utils.zig");
const hashKey = utils.hashKey;
const Self = @This();

pub fn reconcile(old_ctx: *UIContext, new_ctx: *UIContext) void {
    if (old_ctx.root == null or new_ctx.root == null) {
        return;
    }

    traverseNodes(old_ctx.root.?, new_ctx.root.?);
}

// --- Child Iteration Helpers ---

/// Get child at index (O(n))
fn childAt(node: *UINode, index: usize) ?*UINode {
    var i: usize = 0;
    var child = node.first_child;
    while (child) |c| {
        if (i == index) return c;
        i += 1;
        child = c.next_sibling;
    }
    return null;
}

// --- Child Reconciliation Helpers ---

/// Case: Old children exist, new children list is empty.
fn removeAllChildren(old_node: *UINode) void {
    var j: usize = 0;
    var child = old_node.first_child;
    while (child) |old_child| {
        // Vapor.removed_nodes.append(.{ .uuid = old_child.uuid, .index = j }) catch {};
        Vapor.Animation.removal_queue.enqueue(old_child, j) catch {};
        j += 1;
        child = old_child.next_sibling;
    }
    if (j > 0) {
        Vapor.has_dirty = true;
    }
}

/// Case: Old children list is empty, new children exist.
fn addAllChildren(new_node: *UINode) void {
    var child = new_node.first_child;
    while (child) |node| {
        Vapor.markChildrenDirty(node);
        child = node.next_sibling;
    }
    Vapor.has_dirty = true;
}

/// Build arrays from linked lists for keyed diffing
/// Returns allocated slices that should be used within the same frame
fn buildChildArray(node: *UINode, count: usize) ?[]*UINode {
    if (count == 0) return null;

    const items = Vapor.arena(.frame).alloc(*UINode, count) catch return null;
    var i: usize = 0;
    var child = node.first_child;
    while (child) |c| {
        if (i >= count) break;
        items[i] = c;
        i += 1;
        child = c.next_sibling;
    }
    return items;
}

/// Case: Keyed-diffing when old_items.len > new_items.len (Deletions)
fn reconcileDeletions(old_node: *UINode, new_node: *UINode, len_old: usize, len_new: usize) void {
    // Build temporary arrays for keyed diffing
    const old_items = buildChildArray(old_node, len_old) orelse return;
    const new_items = buildChildArray(new_node, len_new) orelse return;

    var node_map = std.StringHashMap(usize).init(Vapor.arena(.frame));
    defer node_map.deinit();

    // 1. Sync from start
    var i: usize = 0;
    while (i < len_new) : (i += 1) {
        if (std.mem.eql(u8, old_items[i].uuid, new_items[i].uuid)) {
            traverseNodes(old_items[i], new_items[i]);
        } else {
            break;
        }
    }

    // 2. Sync from end
    var back_i_old: usize = len_old;
    var back_i_new: usize = len_new;
    while (back_i_new > i and back_i_old > i) {
        const old_child = old_items[back_i_old - 1];
        const new_child = new_items[back_i_new - 1];

        if (std.mem.eql(u8, old_child.uuid, new_child.uuid)) {
            traverseNodes(old_child, new_child);
            back_i_old -= 1;
            back_i_new -= 1;
        } else {
            break;
        }
    }

    // 3. Process the middle "un-synced" section
    const start = i;
    const end_new = back_i_new;

    // Add all *old* nodes from the middle section to the map
    for (old_items[start..back_i_old], start..) |old_child, j| {
        node_map.put(old_child.uuid, j) catch {
            Vapor.printlnSrcErr("Could not put node into node_map {any}\n", .{old_child.uuid}, @src());
        };
    }

    // Iterate *new* nodes in the middle section
    if (end_new > start) {
        for (new_items[start..end_new]) |new_child| {
            if (node_map.fetchRemove(new_child.uuid)) |old_child_entry| {
                const old_child = old_items[old_child_entry.value];
                traverseNodes(old_child, new_child);
                Vapor.has_dirty = true;
            } else {
                new_child.dirty = true;
                Vapor.has_dirty = true;
                new_child.state_type = .added;
                Vapor.markChildrenDirty(new_child);
            }
        }
    }

    // 4. Any nodes left in the map are deletions
    var node_itr = node_map.iterator();
    while (node_itr.next()) |entry| {
        const j = entry.value_ptr.*;
        // const uuid = entry.key_ptr.*;
        const old_child = old_items[j];
        // Vapor.removed_nodes.append(.{ .uuid = uuid, .index = j }) catch {};
        Vapor.Animation.removal_queue.enqueue(old_child, j) catch {};
        Vapor.has_dirty = true;
    }
}

fn reconcileSame(old_node: *UINode, new_node: *UINode, len: usize) void {
    // Build temporary arrays for keyed diffing
    const old_items = buildChildArray(old_node, len) orelse return;
    const new_items = buildChildArray(new_node, len) orelse return;

    var node_map = std.StringHashMap(usize).init(Vapor.arena(.frame));
    defer node_map.deinit();

    // 1. Sync from start
    var i: usize = 0;
    while (i < len) : (i += 1) {
        if (std.mem.eql(u8, old_items[i].uuid, new_items[i].uuid)) {
            traverseNodes(old_items[i], new_items[i]);
        } else {
            break;
        }
    }

    // 2. Sync from end
    var back_i: usize = len;
    while (back_i > i) {
        const old_child = old_items[back_i - 1];
        const new_child = new_items[back_i - 1];

        if (std.mem.eql(u8, old_child.uuid, new_child.uuid)) {
            traverseNodes(old_child, new_child);
            back_i -= 1;
        } else {
            break;
        }
    }

    // 3. Process the middle "un-synced" section
    const start = i;
    const end = back_i;
    var structural_change = false;

    // Add all *new* nodes from the middle section to the map
    for (new_items[start..end], start..) |new_child, j| {
        node_map.put(new_child.uuid, j) catch {
            Vapor.printlnSrcErr("Could not put node into node_map {any}\n", .{new_child.uuid}, @src());
        };
    }

    // Iterate *old* nodes in the middle section
    for (old_items[start..end], start..) |old_child, offset| {
        if (node_map.fetchRemove(old_child.uuid)) |new_child_entry| {
            const new_child = new_items[new_child_entry.value];
            traverseNodes(old_child, new_child);
            structural_change = true;
        } else {
            // Vapor.removed_nodes.append(.{ .uuid = old_child.uuid, .index = offset }) catch {};
            Vapor.Animation.removal_queue.enqueue(old_child, offset) catch {};
            structural_change = true;
        }
    }

    // 4. Any nodes left in the map are additions
    var node_itr = node_map.iterator();
    while (node_itr.next()) |entry| {
        const new_child_index = entry.value_ptr.*;
        const new_child = new_items[new_child_index];
        new_child.state_type = .added;
        Vapor.markChildrenDirty(new_child);
        structural_change = true;
    }
    if (structural_change) {
        Vapor.has_dirty = true;
    }
}

/// Case: Keyed-diffing when new_items.len > old_items.len (Additions)
fn reconcileAdditions(old_node: *UINode, new_node: *UINode, len_old: usize, len_new: usize) void {
    // Build temporary arrays for keyed diffing
    const old_items = buildChildArray(old_node, len_old) orelse return;
    const new_items = buildChildArray(new_node, len_new) orelse return;

    var node_map = std.StringHashMap(usize).init(Vapor.arena(.frame));
    defer node_map.deinit();

    // 1. Sync from start
    var i: usize = 0;
    while (i < len_old) : (i += 1) {
        if (std.mem.eql(u8, old_items[i].uuid, new_items[i].uuid)) {
            traverseNodes(old_items[i], new_items[i]);
        } else {
            break;
        }
    }

    // 2. Sync from end
    var back_i_old: usize = len_old;
    var back_i_new: usize = len_new;
    while (back_i_old > i and back_i_new > i) {
        const old_child = old_items[back_i_old - 1];
        const new_child = new_items[back_i_new - 1];

        if (std.mem.eql(u8, old_child.uuid, new_child.uuid)) {
            traverseNodes(old_child, new_child);
            back_i_old -= 1;
            back_i_new -= 1;
        } else {
            break;
        }
    }

    // 3. Process the middle "un-synced" section
    const start = i;
    const end_old = back_i_old;
    const end_new = back_i_new;

    // Add all *new* nodes from the middle section to the map
    for (new_items[start..end_new], start..) |new_child, j| {
        node_map.put(new_child.uuid, j) catch {
            Vapor.printlnSrcErr("Could not put node into node_map {any}\n", .{new_child.uuid}, @src());
        };
    }

    // Iterate *old* nodes in the middle section
    for (old_items[start..end_old], start..) |old_child, offset| {
        if (node_map.fetchRemove(old_child.uuid)) |new_child_entry| {
            const new_child = new_items[new_child_entry.value];
            traverseNodes(old_child, new_child);
            Vapor.has_dirty = true;
        } else {
            // Vapor.removed_nodes.append(.{ .uuid = old_child.uuid, .index = offset }) catch {};
            Vapor.Animation.removal_queue.enqueue(old_child, offset) catch {};
        }
    }

    // 4. Any nodes left in the map are additions
    var node_itr = node_map.iterator();
    while (node_itr.next()) |entry| {
        const new_child_index = entry.value_ptr.*;
        const new_child = new_items[new_child_index];
        new_child.state_type = .added;
        Vapor.markChildrenDirty(new_child);
    }
    Vapor.has_dirty = true;
}

// --- Main Reconciler Function ---
pub fn traverseNodes(old_node: *UINode, new_node: *UINode) void {
    // --- 1. Reconcile current node properties ---
    const changed = (new_node.finger_print != old_node.finger_print);
    new_node.style_changed = (new_node.style_hash != old_node.style_hash);
    new_node.props_changed = (new_node.props_hash != old_node.props_hash);
    new_node.hooks_changed = (new_node.hooks_hash != old_node.hooks_hash);
    if (new_node.props_changed) {
        const old_handlers = old_node.event_handlers;
        const new_handlers = new_node.event_handlers;
        if (old_handlers) |old_h| {
            if (new_handlers) |new_h| {
                // Remove old handlers whose type isn't in the new set
                for (old_h.handlers.items) |old_handler| {
                    const still_exists = for (new_h.handlers.items) |new_handler| {
                        if (old_handler.event_type == new_handler.event_type) break true;
                    } else false;
                    if (!still_exists) {
                        _ = Vapor.removeElementEventListener(old_node, old_handler.event_type);
                    }
                }
            } else {
                // No new handlers at all, remove everything
                for (old_h.handlers.items) |old_handler| {
                    _ = Vapor.removeElementEventListener(old_node, old_handler.event_type);
                }
            }
        }
    }

    var is_dirty = changed or
        Vapor.rerender_everything or new_node.index != old_node.index;

    if (!std.mem.eql(u8, old_node.uuid, new_node.uuid)) {
        is_dirty = true;
    }

    new_node.dirty = is_dirty;
    if (is_dirty) {
        Vapor.has_dirty = true;
    }

    // --- 2. Reconcile children ---
    const old_count = old_node.children_count;
    const new_count = new_node.children_count;

    if (new_count == 0) {
        if (old_count > 0) {
            // Case: New is empty, Old had items -> Remove all old
            removeAllChildren(old_node);
        }
        // Else: Both empty -> Do nothing
    } else if (old_count == 0) {
        // Case: New has items, Old was empty -> Add all new
        addAllChildren(new_node);
    } else if (old_count == new_count) {
        // Case: Same length -> keyed diff with prefix/suffix fast paths
        reconcileSame(old_node, new_node, old_count);
    } else {
        // Case: Different lengths -> keyed diff.
        //
        // The diff matches children on uuid. For a child that never called
        // `.id()`, `KeyGenerator.generateKey` derives that uuid from the node's
        // position, so moving it changes its identity and the diff sees a
        // delete plus an insert rather than a move. Since removals are deferred
        // through the animation queue while additions apply immediately, both
        // copies are briefly live — the "duplicated button on switch toggle".
        //
        // `.id()` fixes this: it writes the uuid directly, so identity survives
        // the move and the suffix scan below matches the node. Callers with
        // reorderable lists are expected to use it. See the two tests
        // "keyed diff cannot recognise a node that moved" and "a caller-set id
        // survives a move".
        if (old_count > new_count) {
            reconcileDeletions(old_node, new_node, old_count, new_count);
        } else {
            reconcileAdditions(old_node, new_node, old_count, new_count);
        }
    }
}
