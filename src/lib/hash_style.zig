//! Hashes a `Style` so unchanged styles can be recognised and reused.

const std = @import("std");
const types = @import("types.zig");
const Style = types.Style;
const Visual = types.Visual;
const Color = types.Color;
const BackgroundLayer = types.BackgroundLayer;
const Transform = types.Transform;
const Interactive = types.Interactive;
const Transition = @import("transition.zig").Transition;

/// Compute a content hash that captures the logical style.
/// This hashes the actual values (including string contents) rather than pointers,
/// so two styles with identical content will produce the same hash even if
/// their string pointers differ.
pub fn hashStyle(style: *const Style) u32 {
    var hasher = std.hash.XxHash32.init(0);

    // ============================================================
    // Top-level Style fields
    // ============================================================

    // String fields - hash contents
    if (style.id) |id| hasher.update(id);
    if (style.style_id) |sid| hasher.update(sid);
    if (style.font_family) |ff| hasher.update(ff);
    if (style.exit_animation) |ea| hasher.update(ea);
    if (style.backface_visibility) |bv| hasher.update(bv);
    if (style.anchor) |anchor| hasher.update(anchor);

    // Position struct (contains optional Pos fields with pointers - but Pos is packed)
    if (style.position) |pos| {
        hasher.update(std.mem.asBytes(&pos.type));
        if (pos.top) |t| hasher.update(std.mem.asBytes(&t));
        if (pos.right) |r| hasher.update(std.mem.asBytes(&r));
        if (pos.bottom) |b| hasher.update(std.mem.asBytes(&b));
        if (pos.left) |l| hasher.update(std.mem.asBytes(&l));
        if (pos.z_index) |z| hasher.update(std.mem.asBytes(&z));
    }

    // Simple packed/enum fields
    hasher.update(std.mem.asBytes(&style.direction));

    if (style.size) |s| hasher.update(std.mem.asBytes(&s));
    if (style.aspect_ratio) |ar| hasher.update(std.mem.asBytes(&ar));
    if (style.padding) |p| hasher.update(std.mem.asBytes(&p));
    if (style.margin) |m| hasher.update(std.mem.asBytes(&m));
    if (style.scroll) |s| hasher.update(std.mem.asBytes(&s));
    if (style.layout) |l| hasher.update(std.mem.asBytes(&l));
    if (style.placement) |p| hasher.update(std.mem.asBytes(&p));
    if (style.child_gap) |cg| hasher.update(std.mem.asBytes(&cg));
    if (style.flex_wrap) |fw| hasher.update(std.mem.asBytes(&fw));
    if (style.list_style) |ls| hasher.update(std.mem.asBytes(&ls));
    if (style.appearance) |a| hasher.update(std.mem.asBytes(&a));
    if (style.will_change) |wc| hasher.update(std.mem.asBytes(&wc));
    if (style.transform_origin) |to| hasher.update(std.mem.asBytes(&to));

    hasher.update(std.mem.asBytes(&style.show_scrollbar));
    hasher.update(std.mem.asBytes(&style.btn_id));

    if (style.dialog_id) |did| hasher.update(did);

    // ============================================================
    // Visual struct
    // ============================================================
    if (style.visual) |v| {
        hashVisual(&hasher, &v);
    }

    // ============================================================
    // Interactive struct
    // ============================================================
    if (style.interactive) |interactive| {
        hashInteractive(&hasher, &interactive);
    }

    // ============================================================
    // Transition struct
    // ============================================================
    if (style.transition) |t| {
        hashTransition(&hasher, &t);
    }

    // ============================================================
    // KeyFrames (slices - hash contents)
    // ============================================================
    if (style.key_frame) |kf| {
        hashKeyFrame(&hasher, &kf);
    }
    if (style.key_frames) |kfs| {
        for (kfs) |kf| {
            hashKeyFrame(&hasher, &kf);
        }
    }

    // ============================================================
    // CheckMark style (complex struct)
    // ============================================================
    if (style.checkmark_style) |cm| {
        hashCheckMark(&hasher, &cm);
    }

    // ============================================================
    // Child styles (slice of pointers)
    // ============================================================
    if (style.child_styles) |cs| {
        for (cs) |child_style_ptr| {
            hashChildStyle(&hasher, child_style_ptr);
        }
    }

    return hasher.final();
}

fn hashVisual(hasher: *std.hash.XxHash32, v: *const Visual) void {
    // String fields
    if (v.animation_name) |name| hasher.update(name);

    // `animation` is the generated CSS text, so hash its contents for value
    // equality rather than the slice address, which changes every frame.
    if (v.animation) |anim| hasher.update(anim);

    // Background is a plain colour; the pattern layers are hashed just below.
    if (v.background) |bg| {
        hashColor(hasher, &bg);
    }

    // Layers
    if (v.layer) |layer| {
        hashBackgroundLayer(hasher, &layer);
    }
    if (v.layers) |layers| {
        for (layers) |layer| {
            hashBackgroundLayer(hasher, &layer);
        }
    }

    // Simple fields
    if (v.font_size) |fs| hasher.update(std.mem.asBytes(&fs));
    if (v.letter_spacing) |ls| hasher.update(std.mem.asBytes(&ls));
    if (v.line_height) |lh| hasher.update(std.mem.asBytes(&lh));
    if (v.font_weight) |fw| hasher.update(std.mem.asBytes(&fw));
    if (v.font_style) |fs| hasher.update(std.mem.asBytes(&fs));
    if (v.text_color) |tc| hashColor(hasher, &tc);
    if (v.fill) |f| hashColor(hasher, &f);
    if (v.stroke) |s| hashColor(hasher, &s);

    // Border grouped
    if (v.border) |b| {
        if (b.thickness) |t| hasher.update(std.mem.asBytes(&t));
        if (b.color) |c| hashColor(hasher, &c);
        if (b.radius) |r| hasher.update(std.mem.asBytes(&r));
        if (b.style) |s| hasher.update(std.mem.asBytes(&s));
    }

    if (v.ellipsis) |e| hasher.update(std.mem.asBytes(&e));
    if (v.opacity) |o| hasher.update(std.mem.asBytes(&o));

    // Shadow
    if (v.shadow) |s| hashShadow(hasher, &s);

    if (v.new_shadow) |ns| hashShadow(hasher, &ns);

    // Transform
    if (v.transform) |t| {
        hashTransform(hasher, &t);
    }

    // Text decoration
    if (v.text_decoration) |td| {
        hasher.update(std.mem.asBytes(&td.type));
        hasher.update(std.mem.asBytes(&td.style));
        if (td.color) |c| hashColor(hasher, &c);
    }

    if (v.cursor) |c| hasher.update(std.mem.asBytes(&c));
    if (v.blur) |b| hasher.update(std.mem.asBytes(&b));
    if (v.outline) |o| hasher.update(std.mem.asBytes(&o));
    if (v.white_space) |ws| hasher.update(std.mem.asBytes(&ws));
    if (v.resize) |r| hasher.update(std.mem.asBytes(&r));

    // Caret
    if (v.caret) |caret| {
        hasher.update(std.mem.asBytes(&caret.type));
        if (caret.color) |c| hashColor(hasher, &c);
    }
}

/// `Shadow` is a fixed array of optional layers, so hash the populated layers
/// field by field. Hashing the struct's bytes would fold in padding and the
/// unused tail slots.
fn hashShadow(hasher: *std.hash.XxHash32, shadow: *const types.NewShadow) void {
    hasher.update(std.mem.asBytes(&shadow.layer_count));
    for (shadow.layers) |maybe_layer| {
        const layer = maybe_layer orelse continue;
        hasher.update(std.mem.asBytes(&layer.inset));
        hasher.update(std.mem.asBytes(&layer.x));
        hasher.update(std.mem.asBytes(&layer.y));
        hasher.update(std.mem.asBytes(&layer.blur));
        hasher.update(std.mem.asBytes(&layer.spread));
        hashColor(hasher, &layer.color);
    }
}

fn hashColor(hasher: *std.hash.XxHash32, color: *const Color) void {
    switch (color.*) {
        .Literal => |rgba| {
            hasher.update(std.mem.asBytes(&rgba));
        },
        .Thematic => |thematic| {
            hasher.update(std.mem.asBytes(&thematic));
        },
    }
}

fn hashBackgroundLayer(hasher: *std.hash.XxHash32, layer: *const BackgroundLayer) void {
    // Hash the tag first
    const tag = std.meta.activeTag(layer.*);
    hasher.update(std.mem.asBytes(&tag));

    switch (layer.*) {
        .Image => |img| {
            hasher.update(img.url);
        },
        .Grid => |grid| {
            hasher.update(std.mem.asBytes(&grid.size));
            hasher.update(std.mem.asBytes(&grid.thickness));
            hashColor(hasher, &grid.color);
        },
        .Dot => |dot| {
            hasher.update(std.mem.asBytes(&dot.radius));
            hasher.update(std.mem.asBytes(&dot.spacing));
            hashColor(hasher, &dot.color);
        },
        .Gradient => |grad| {
            hasher.update(std.mem.asBytes(&grad.type));
            hasher.update(std.mem.asBytes(&grad.direction));
            for (grad.colors) |c| {
                hashColor(hasher, &c);
            }
        },
        .Lines => |lines| {
            hasher.update(std.mem.asBytes(&lines.direction));
            hasher.update(std.mem.asBytes(&lines.thickness));
            hasher.update(std.mem.asBytes(&lines.spacing));
            hashColor(hasher, &lines.color);
        },
    }
}

fn hashTransform(hasher: *std.hash.XxHash32, t: *const Transform) void {
    hasher.update(std.mem.asBytes(&t.size_type));
    hasher.update(std.mem.asBytes(&t.scale_size));
    hasher.update(std.mem.asBytes(&t.trans_x));
    hasher.update(std.mem.asBytes(&t.trans_y));
    hasher.update(std.mem.asBytes(&t.deg));
    hasher.update(std.mem.asBytes(&t.x));
    hasher.update(std.mem.asBytes(&t.y));
    hasher.update(std.mem.asBytes(&t.z));
    hasher.update(std.mem.asBytes(&t.opacity));

    // Hash the transform type slice contents
    for (t.type) |tt| {
        hasher.update(std.mem.asBytes(&tt));
    }
}

fn hashInteractive(hasher: *std.hash.XxHash32, interactive: *const Interactive) void {
    if (interactive.hover_layout) |hl| hasher.update(std.mem.asBytes(&hl));

    if (interactive.hover_position) |hp| {
        hasher.update(std.mem.asBytes(&hp.type));
        if (hp.top) |t| hasher.update(std.mem.asBytes(&t));
        if (hp.right) |r| hasher.update(std.mem.asBytes(&r));
        if (hp.bottom) |b| hasher.update(std.mem.asBytes(&b));
        if (hp.left) |l| hasher.update(std.mem.asBytes(&l));
        if (hp.z_index) |z| hasher.update(std.mem.asBytes(&z));
    }

    if (interactive.hover) |h| hashVisual(hasher, &h);
    if (interactive.focus) |f| hashVisual(hasher, &f);
    if (interactive.focus_within) |fw| hashVisual(hasher, &fw);
}

fn hashTransition(hasher: *std.hash.XxHash32, t: *const Transition) void {
    hasher.update(std.mem.asBytes(&t.duration));
    hasher.update(std.mem.asBytes(&t.delay));
    hasher.update(std.mem.asBytes(&t.timing));

    // Hash property slice contents
    for (t.properties) |prop| {
        hasher.update(std.mem.asBytes(&prop));
    }
}

fn hashKeyFrame(hasher: *std.hash.XxHash32, kf: *const types.KeyFrame) void {
    hasher.update(kf.tag);
    hashTransform(hasher, &kf.from);
    hashTransform(hasher, &kf.to);
}

fn hashCheckMark(hasher: *std.hash.XxHash32, cm: *const types.CheckMark) void {
    if (cm.position) |p| {
        hasher.update(std.mem.asBytes(&p.type));
        if (p.top) |t| hasher.update(std.mem.asBytes(&t));
        if (p.right) |r| hasher.update(std.mem.asBytes(&r));
        if (p.bottom) |b| hasher.update(std.mem.asBytes(&b));
        if (p.left) |l| hasher.update(std.mem.asBytes(&l));
        if (p.z_index) |z| hasher.update(std.mem.asBytes(&z));
    }
    if (cm.display) |d| hasher.update(std.mem.asBytes(&d));
    hasher.update(std.mem.asBytes(&cm.direction));
    if (cm.width) |w| hasher.update(std.mem.asBytes(&w));
    if (cm.height) |h| hasher.update(std.mem.asBytes(&h));
    if (cm.font_size) |fs| hasher.update(std.mem.asBytes(&fs));
    if (cm.letter_spacing) |ls| hasher.update(std.mem.asBytes(&ls));
    if (cm.line_height) |lh| hasher.update(std.mem.asBytes(&lh));
    if (cm.font_weight) |fw| hasher.update(std.mem.asBytes(&fw));
    if (cm.border_radius) |br| hasher.update(std.mem.asBytes(&br));
    if (cm.border_thickness) |bt| hasher.update(std.mem.asBytes(&bt));
    if (cm.border_color) |bc| hashColor(hasher, &bc);
    if (cm.text_color) |tc| hashColor(hasher, &tc);
    if (cm.padding) |p| hasher.update(std.mem.asBytes(&p));
    if (cm.child_alignment) |ca| hasher.update(std.mem.asBytes(&ca));
    hasher.update(std.mem.asBytes(&cm.child_gap));
    if (cm.background) |bg| hashColor(hasher, &bg);
    hasher.update(std.mem.asBytes(&cm.shadow));
    hashTransform(hasher, &cm.transform);
    hasher.update(std.mem.asBytes(&cm.opacity));
    // child_style would need recursive handling if non-null
}

fn hashChildStyle(hasher: *std.hash.XxHash32, cs: *const types.ChildStyle) void {
    hasher.update(cs.style_id);
    if (cs.display) |d| hasher.update(std.mem.asBytes(&d));

    if (cs.position) |p| {
        hasher.update(std.mem.asBytes(&p.type));
        if (p.top) |t| hasher.update(std.mem.asBytes(&t));
        if (p.right) |r| hasher.update(std.mem.asBytes(&r));
        if (p.bottom) |b| hasher.update(std.mem.asBytes(&b));
        if (p.left) |l| hasher.update(std.mem.asBytes(&l));
        if (p.z_index) |z| hasher.update(std.mem.asBytes(&z));
    }

    hasher.update(std.mem.asBytes(&cs.direction));
    if (cs.background) |bg| hashColor(hasher, &bg);
    if (cs.width) |w| hasher.update(std.mem.asBytes(&w));
    if (cs.height) |h| hasher.update(std.mem.asBytes(&h));
    if (cs.font_size) |fs| hasher.update(std.mem.asBytes(&fs));
    if (cs.letter_spacing) |ls| hasher.update(std.mem.asBytes(&ls));
    if (cs.line_height) |lh| hasher.update(std.mem.asBytes(&lh));
    if (cs.font_weight) |fw| hasher.update(std.mem.asBytes(&fw));
    if (cs.border_radius) |br| hasher.update(std.mem.asBytes(&br));
    if (cs.border_thickness) |bt| hasher.update(std.mem.asBytes(&bt));
    if (cs.border_color) |bc| hashColor(hasher, &bc);
    if (cs.text_color) |tc| hashColor(hasher, &tc);
    if (cs.padding) |p| hasher.update(std.mem.asBytes(&p));
    if (cs.margin) |m| hasher.update(std.mem.asBytes(&m));
    if (cs.overflow) |o| hasher.update(std.mem.asBytes(&o));
    if (cs.overflow_x) |ox| hasher.update(std.mem.asBytes(&ox));
    if (cs.overflow_y) |oy| hasher.update(std.mem.asBytes(&oy));
    if (cs.child_alignment) |ca| hasher.update(std.mem.asBytes(&ca));
    hasher.update(std.mem.asBytes(&cs.child_gap));
    if (cs.flex_shrink) |fs| hasher.update(std.mem.asBytes(&fs));

    if (cs.font_family_file.len > 0) hasher.update(cs.font_family_file);
    if (cs.font_family.len > 0) hasher.update(cs.font_family);

    hasher.update(std.mem.asBytes(&cs.opacity));

    if (cs.text_decoration) |td| {
        hasher.update(std.mem.asBytes(&td.type));
        hasher.update(std.mem.asBytes(&td.style));
        if (td.color) |c| hashColor(hasher, &c);
    }

    if (cs.shadow) |s| hashShadow(hasher, &s);

    if (cs.white_space) |ws| hasher.update(std.mem.asBytes(&ws));
    if (cs.flex_wrap) |fw| hasher.update(std.mem.asBytes(&fw));
    if (cs.z_index) |z| hasher.update(std.mem.asBytes(&z));
    if (cs.list_style) |ls| hasher.update(std.mem.asBytes(&ls));
    if (cs.blur) |b| hasher.update(std.mem.asBytes(&b));
    if (cs.outline) |o| hasher.update(std.mem.asBytes(&o));

    if (cs.transition) |t| hashTransition(hasher, &t);

    hasher.update(std.mem.asBytes(&cs.show_scrollbar));
    hasher.update(std.mem.asBytes(&cs.btn_id));

    if (cs.dialog_id) |did| hasher.update(did);
    if (cs.accent_color) |ac| hasher.update(std.mem.asBytes(&ac));
}
