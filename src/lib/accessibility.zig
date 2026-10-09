const std = @import("std");
const Writer = @import("Writer.zig");
const UINode = @import("UITree.zig").UINode;
const utils = @import("utils.zig");

pub var a11y_map: std.AutoHashMap(u32, Accessibility) = undefined;

// In your exports or wherever you expose to JS

var a11y_string_ptr: [*]const u8 = undefined;
var a11y_string_len: u32 = 0;

export fn getAccessibilityAttributes(ui_node: *UINode) usize {
    if (a11y_map.get(utils.hashKey(ui_node.uuid))) |acc| {
        const str = toAttributeString(acc);
        a11y_string_ptr = str.ptr;
        a11y_string_len = @intCast(str.len);
        return @intFromPtr(str.ptr);
    }
    a11y_string_len = 0;
    return 0;
}

export fn getAccessibilityAttributesLen() u32 {
    return a11y_string_len;
}

/// Writes all non-null accessibility attributes as HTML attribute string
/// Returns the length written
pub fn writeAttributes(self: Accessibility) !void {
    // Role
    if (self.role) |r| {
        try writer.write(" role=\"");
        try writer.write(r.toCss());
        try writer.write("\"");
    }

    // Labeling
    if (self.label) |l| {
        try writer.write(" aria-label=\"");
        try writer.write(l); // Escape quotes in label
        try writer.write("\"");
    }

    if (self.labelled_by) |l| {
        try writer.write(" aria-labelledby=\"");
        try writer.write(l);
        try writer.write("\"");
    }

    if (self.described_by) |d| {
        try writer.write(" aria-describedby=\"");
        try writer.write(d);
        try writer.write("\"");
    }

    // Boolean states
    if (self.expanded) |e| {
        try writer.write(if (e) " aria-expanded=\"true\"" else " aria-expanded=\"false\"");
    }

    if (self.selected) |s| {
        try writer.write(if (s) " aria-selected=\"true\"" else " aria-selected=\"false\"");
    }

    if (self.checked) |c| {
        try writer.write(" aria-checked=\"");
        try writer.write(c.toCss());
        try writer.write("\"");
    }

    if (self.pressed) |p| {
        try writer.write(" aria-pressed=\"");
        try writer.write(p.toCss());
        try writer.write("\"");
    }

    if (self.disabled) |d| {
        if (d) try writer.write(" aria-disabled=\"true\"");
    }

    if (self.hidden) |h| {
        try writer.write(if (h) " aria-hidden=\"true\"" else " aria-hidden=\"false\"");
    }

    if (self.invalid) |i| {
        if (i) try writer.write(" aria-invalid=\"true\"");
    }

    if (self.required) |r| {
        if (r) try writer.write(" aria-required=\"true\"");
    }

    if (self.readonly) |r| {
        if (r) try writer.write(" aria-readonly=\"true\"");
    }

    if (self.busy) |b| {
        if (b) try writer.write(" aria-busy=\"true\"");
    }

    // Relationships
    if (self.controls) |c| {
        try writer.write(" aria-controls=\"");
        try writer.write(c);
        try writer.write("\"");
    }

    if (self.owns) |o| {
        try writer.write(" aria-owns=\"");
        try writer.write(o);
        try writer.write("\"");
    }

    if (self.active_descendant) |ad| {
        try writer.write(" aria-activedescendant=\"");
        try writer.write(ad);
        try writer.write("\"");
    }

    if (self.flow_to) |f| {
        try writer.write(" aria-flowto=\"");
        try writer.write(f);
        try writer.write("\"");
    }

    // Live regions
    if (self.live) |l| {
        try writer.write(" aria-live=\"");
        try writer.write(l.toCss());
        try writer.write("\"");
    }

    if (self.atomic) |a| {
        if (a) try writer.write(" aria-atomic=\"true\"");
    }

    if (self.relevant) |r| {
        try writer.write(" aria-relevant=\"");
        try writer.write(r.toCss());
        try writer.write("\"");
    }

    // Widget properties
    if (self.has_popup) |h| {
        try writer.write(" aria-haspopup=\"");
        try writer.write(h.toCss());
        try writer.write("\"");
    }

    if (self.modal) |m| {
        if (m) try writer.write(" aria-modal=\"true\"");
    }

    if (self.orientation) |o| {
        try writer.write(" aria-orientation=\"");
        try writer.write(o.toCss());
        try writer.write("\"");
    }

    if (self.autocomplete) |a| {
        try writer.write(" aria-autocomplete=\"");
        try writer.write(a.toCss());
        try writer.write("\"");
    }

    if (self.multiselectable) |m| {
        if (m) try writer.write(" aria-multiselectable=\"true\"");
    }

    // Value properties
    if (self.value_now) |v| {
        try writer.write(" aria-valuenow=\"");
        try writer.writeF32(v);
        try writer.write("\"");
    }

    if (self.value_min) |v| {
        try writer.write(" aria-valuemin=\"");
        try writer.writeF32(v);
        try writer.write("\"");
    }

    if (self.value_max) |v| {
        try writer.write(" aria-valuemax=\"");
        try writer.writeF32(v);
        try writer.write("\"");
    }

    if (self.value_text) |v| {
        try writer.write(" aria-valuetext=\"");
        try writer.write(v);
        try writer.write("\"");
    }

    // Positional
    if (self.pos_in_set) |p| {
        try writer.write(" aria-posinset=\"");
        try writer.writeU32(p);
        try writer.write("\"");
    }

    if (self.set_size) |s| {
        try writer.write(" aria-setsize=\"");
        try writer.writeU32(s);
        try writer.write("\"");
    }

    if (self.level) |l| {
        try writer.write(" aria-level=\"");
        try writer.writeU8Num(l);
        try writer.write("\"");
    }

    if (self.col_index) |c| {
        try writer.write(" aria-colindex=\"");
        try writer.writeU32(c);
        try writer.write("\"");
    }

    if (self.row_index) |r| {
        try writer.write(" aria-rowindex=\"");
        try writer.writeU32(r);
        try writer.write("\"");
    }

    // Keyboard
    if (self.tab_index) |t| {
        try writer.write(" tabindex=\"");
        try writer.writeI16(t);
        try writer.write("\"");
    }

    // Add these to writeAttributes after row_index:
    if (self.col_span) |c| {
        try writer.write(" aria-colspan=\"");
        try writer.writeU32(c);
        try writer.write("\"");
    }

    if (self.row_span) |r| {
        try writer.write(" aria-rowspan=\"");
        try writer.writeU32(r);
        try writer.write("\"");
    }
}

/// Returns the attribute string allocated in frame arena
var buffer: [4096]u8 = undefined;
var writer: Writer = undefined;
pub fn toAttributeString(self: Accessibility) []const u8 {
    writer.init(&buffer);
    writeAttributes(self) catch return "";
    return writer.buffer[0..writer.pos];
}

pub const Accessibility = struct {
    // Core ARIA role (often inferred from element type)
    role: ?Role = null,

    // Labeling
    label: ?[]const u8 = null, // aria-label
    labelled_by: ?[]const u8 = null, // aria-labelledby (ID reference)
    described_by: ?[]const u8 = null, // aria-describedby (ID reference)

    // States
    expanded: ?bool = null, // aria-expanded
    selected: ?bool = null, // aria-selected
    checked: ?Checked = null, // aria-checked (true/false/mixed)
    pressed: ?Pressed = null, // aria-pressed (true/false/mixed)
    disabled: ?bool = null, // aria-disabled
    hidden: ?bool = null, // aria-hidden
    invalid: ?bool = null, // aria-invalid
    required: ?bool = null, // aria-required
    readonly: ?bool = null, // aria-readonly
    busy: ?bool = null, // aria-busy

    // Relationships
    controls: ?[]const u8 = null, // aria-controls (ID reference)
    owns: ?[]const u8 = null, // aria-owns (ID reference)
    active_descendant: ?[]const u8 = null, // aria-activedescendant (ID reference)
    flow_to: ?[]const u8 = null, // aria-flowto (ID reference)

    // Live regions
    live: ?Live = null, // aria-live
    atomic: ?bool = null, // aria-atomic
    relevant: ?Relevant = null, // aria-relevant

    // Widget properties
    has_popup: ?HasPopup = null, // aria-haspopup
    modal: ?bool = null, // aria-modal
    orientation: ?Orientation = null, // aria-orientation
    autocomplete: ?Autocomplete = null, // aria-autocomplete
    multiselectable: ?bool = null, // aria-multiselectable

    // Value properties (for sliders, progress, etc.)
    value_now: ?f32 = null, // aria-valuenow
    value_min: ?f32 = null, // aria-valuemin
    value_max: ?f32 = null, // aria-valuemax
    value_text: ?[]const u8 = null, // aria-valuetext

    // Positional (for grids, lists)
    pos_in_set: ?u32 = null, // aria-posinset
    set_size: ?u32 = null, // aria-setsize
    level: ?u8 = null, // aria-level
    col_index: ?u32 = null, // aria-colindex
    row_index: ?u32 = null, // aria-rowindex
    col_span: ?u32 = null, // aria-colspan
    row_span: ?u32 = null, // aria-rowspan

    // Keyboard
    tab_index: ?i16 = null, // tabindex

    // Enums
    pub const Role = enum {
        // Landmark roles
        banner,
        complementary,
        content_info,
        form,
        main,
        navigation,
        region,
        search,

        // Widget roles
        alert,
        alert_dialog,
        button,
        checkbox,
        dialog,
        grid_cell,
        link,
        listbox,
        menu,
        menu_bar,
        menu_item,
        menu_item_checkbox,
        menu_item_radio,
        option,
        progress_bar,
        radio,
        scrollbar,
        search_box,
        slider,
        spin_button,
        status,
        switch_role,
        tab,
        tab_list,
        tab_panel,
        textbox,
        tooltip,
        tree_item,

        // Composite roles
        combobox,
        grid,
        listbox_option,
        radio_group,
        tree,
        tree_grid,

        // Document structure
        article,
        cell,
        column_header,
        definition,
        directory,
        document,
        feed,
        figure,
        group,
        heading,
        img,
        list,
        list_item,
        math,
        none,
        note,
        presentation,
        row,
        row_group,
        row_header,
        separator,
        table,
        term,
        toolbar,

        pub fn toCss(self: Role) []const u8 {
            return switch (self) {
                .banner => "banner",
                .complementary => "complementary",
                .content_info => "contentinfo",
                .form => "form",
                .main => "main",
                .navigation => "navigation",
                .region => "region",
                .search => "search",
                .alert => "alert",
                .alert_dialog => "alertdialog",
                .button => "button",
                .checkbox => "checkbox",
                .dialog => "dialog",
                .grid_cell => "gridcell",
                .link => "link",
                .listbox => "listbox",
                .menu => "menu",
                .menu_bar => "menubar",
                .menu_item => "menuitem",
                .menu_item_checkbox => "menuitemcheckbox",
                .menu_item_radio => "menuitemradio",
                .option => "option",
                .progress_bar => "progressbar",
                .radio => "radio",
                .scrollbar => "scrollbar",
                .search_box => "searchbox",
                .slider => "slider",
                .spin_button => "spinbutton",
                .status => "status",
                .switch_role => "switch",
                .tab => "tab",
                .tab_list => "tablist",
                .tab_panel => "tabpanel",
                .textbox => "textbox",
                .tooltip => "tooltip",
                .tree_item => "treeitem",
                .combobox => "combobox",
                .grid => "grid",
                .listbox_option => "option",
                .radio_group => "radiogroup",
                .tree => "tree",
                .tree_grid => "treegrid",
                .article => "article",
                .cell => "cell",
                .column_header => "columnheader",
                .definition => "definition",
                .directory => "directory",
                .document => "document",
                .feed => "feed",
                .figure => "figure",
                .group => "group",
                .heading => "heading",
                .img => "img",
                .list => "list",
                .list_item => "listitem",
                .math => "math",
                .none => "none",
                .note => "note",
                .presentation => "presentation",
                .row => "row",
                .row_group => "rowgroup",
                .row_header => "rowheader",
                .separator => "separator",
                .table => "table",
                .term => "term",
                .toolbar => "toolbar",
            };
        }
    };

    pub const Checked = enum {
        false_val,
        true_val,
        mixed,

        pub fn toCss(self: Checked) []const u8 {
            return switch (self) {
                .false_val => "false",
                .true_val => "true",
                .mixed => "mixed",
            };
        }
    };

    pub const Pressed = enum {
        false_val,
        true_val,
        mixed,

        pub fn toCss(self: Pressed) []const u8 {
            return switch (self) {
                .false_val => "false",
                .true_val => "true",
                .mixed => "mixed",
            };
        }
    };

    pub const Live = enum {
        off,
        polite,
        assertive,

        pub fn toCss(self: Live) []const u8 {
            return switch (self) {
                .off => "off",
                .polite => "polite",
                .assertive => "assertive",
            };
        }
    };

    pub const Relevant = enum {
        additions,
        removals,
        text,
        all,
        additions_text,

        pub fn toCss(self: Relevant) []const u8 {
            return switch (self) {
                .additions => "additions",
                .removals => "removals",
                .text => "text",
                .all => "all",
                .additions_text => "additions text",
            };
        }
    };

    pub const HasPopup = enum {
        false_val,
        true_val,
        menu,
        listbox,
        tree,
        grid,
        dialog,

        pub fn toCss(self: HasPopup) []const u8 {
            return switch (self) {
                .false_val => "false",
                .true_val => "true",
                .menu => "menu",
                .listbox => "listbox",
                .tree => "tree",
                .grid => "grid",
                .dialog => "dialog",
            };
        }
    };

    pub const Orientation = enum {
        horizontal,
        vertical,

        pub fn toCss(self: Orientation) []const u8 {
            return switch (self) {
                .horizontal => "horizontal",
                .vertical => "vertical",
            };
        }
    };

    pub const Autocomplete = enum {
        none,
        inline_val,
        list,
        both,

        pub fn toCss(self: Autocomplete) []const u8 {
            return switch (self) {
                .none => "none",
                .inline_val => "inline",
                .list => "list",
                .both => "both",
            };
        }
    };

    // ========================================
    // Fluent Builder Methods
    // ========================================

    pub fn init() Accessibility {
        return .{};
    }

    // Role
    pub fn setRole(self: Accessibility, role: Role) Accessibility {
        var a = self;
        a.role = role;
        return a;
    }

    // Labeling
    pub fn setLabel(self: Accessibility, label: []const u8) Accessibility {
        var a = self;
        a.label = label;
        return a;
    }

    pub fn setLabelledBy(self: Accessibility, id: []const u8) Accessibility {
        var a = self;
        a.labelled_by = id;
        return a;
    }

    pub fn setDescribedBy(self: Accessibility, id: []const u8) Accessibility {
        var a = self;
        a.described_by = id;
        return a;
    }

    // States
    pub fn setExpanded(self: Accessibility, expanded: bool) Accessibility {
        var a = self;
        a.expanded = expanded;
        return a;
    }

    pub fn setSelected(self: Accessibility, selected: bool) Accessibility {
        var a = self;
        a.selected = selected;
        return a;
    }

    pub fn setChecked(self: Accessibility, checked: Checked) Accessibility {
        var a = self;
        a.checked = checked;
        return a;
    }

    pub fn setPressed(self: Accessibility, pressed: Pressed) Accessibility {
        var a = self;
        a.pressed = pressed;
        return a;
    }

    pub fn setDisabled(self: Accessibility, disabled: bool) Accessibility {
        var a = self;
        a.disabled = disabled;
        return a;
    }

    pub fn setHidden(self: Accessibility, hidden_val: bool) Accessibility {
        var a = self;
        a.hidden = hidden_val;
        return a;
    }

    pub fn setInvalid(self: Accessibility, invalid_val: bool) Accessibility {
        var a = self;
        a.invalid = invalid_val;
        return a;
    }

    pub fn setRequired(self: Accessibility, required_val: bool) Accessibility {
        var a = self;
        a.required = required_val;
        return a;
    }

    pub fn setBusy(self: Accessibility, busy_val: bool) Accessibility {
        var a = self;
        a.busy = busy_val;
        return a;
    }

    // Relationships
    pub fn setControls(self: Accessibility, id: []const u8) Accessibility {
        var a = self;
        a.controls = id;
        return a;
    }

    pub fn setOwns(self: Accessibility, id: []const u8) Accessibility {
        var a = self;
        a.owns = id;
        return a;
    }

    pub fn setActiveDescendant(self: Accessibility, id: ?[]const u8) Accessibility {
        var a = self;
        a.active_descendant = id;
        return a;
    }

    // Live regions
    pub fn setLive(self: Accessibility, live_val: Live) Accessibility {
        var a = self;
        a.live = live_val;
        return a;
    }

    pub fn setAtomic(self: Accessibility, atomic_val: bool) Accessibility {
        var a = self;
        a.atomic = atomic_val;
        return a;
    }

    // Widget properties
    pub fn setHasPopup(self: Accessibility, popup: HasPopup) Accessibility {
        var a = self;
        a.has_popup = popup;
        return a;
    }

    pub fn setModal(self: Accessibility, modal_val: bool) Accessibility {
        var a = self;
        a.modal = modal_val;
        return a;
    }

    pub fn setOrientation(self: Accessibility, orient: Orientation) Accessibility {
        var a = self;
        a.orientation = orient;
        return a;
    }

    pub fn setMultiselectable(self: Accessibility, multi: bool) Accessibility {
        var a = self;
        a.multiselectable = multi;
        return a;
    }

    // Values
    pub fn setValue(self: Accessibility, now: f32, min: f32, max: f32) Accessibility {
        var a = self;
        a.value_now = now;
        a.value_min = min;
        a.value_max = max;
        return a;
    }

    pub fn setValueText(self: Accessibility, text: []const u8) Accessibility {
        var a = self;
        a.value_text = text;
        return a;
    }

    // Position
    pub fn setPosition(self: Accessibility, pos: u32, total: u32) Accessibility {
        var a = self;
        a.pos_in_set = pos;
        a.set_size = total;
        return a;
    }

    pub fn setLevel(self: Accessibility, lvl: u8) Accessibility {
        var a = self;
        a.level = lvl;
        return a;
    }

    // Keyboard
    pub fn setTabIndex(self: Accessibility, index: i16) Accessibility {
        var a = self;
        a.tab_index = index;
        return a;
    }

    pub fn focusable(self: Accessibility) Accessibility {
        return self.setTabIndex(0);
    }

    pub fn notFocusable(self: Accessibility) Accessibility {
        return self.setTabIndex(-1);
    }

    // ========================================
    // Preset Builders for Common Patterns
    // ========================================

    /// Creates accessibility for a dialog/modal
    pub fn dialog(label: []const u8) Accessibility {
        return Accessibility.init()
            .setRole(.dialog)
            .setModal(true)
            .setLabel(label);
    }

    /// Creates accessibility for an alert dialog
    pub fn alertDialog(label: []const u8) Accessibility {
        return Accessibility.init()
            .setRole(.alert_dialog)
            .setModal(true)
            .setLabel(label);
    }

    /// Creates accessibility for a combobox/dropdown trigger
    pub fn combobox(expanded: bool, controls_id: []const u8) Accessibility {
        return Accessibility.init()
            .setRole(.combobox)
            .setExpanded(expanded)
            .setHasPopup(.listbox)
            .setControls(controls_id);
    }

    /// Creates accessibility for a listbox
    pub fn listbox(label: []const u8) Accessibility {
        return Accessibility.init()
            .setRole(.listbox)
            .setLabel(label)
            .setOrientation(.vertical);
    }

    /// Creates accessibility for a listbox option
    pub fn option(selected: bool, pos: u32, total: u32) Accessibility {
        return Accessibility.init()
            .setRole(.option)
            .setSelected(selected)
            .setPosition(pos, total);
    }

    /// Creates accessibility for a tab
    pub fn tab(selected: bool, controls_panel_id: []const u8) Accessibility {
        return Accessibility.init()
            .setRole(.tab)
            .setSelected(selected)
            .setControls(controls_panel_id);
    }

    /// Creates accessibility for a tab panel
    pub fn tabPanel(labelled_by_tab_id: []const u8) Accessibility {
        return Accessibility.init()
            .setRole(.tab_panel)
            .setLabelledBy(labelled_by_tab_id);
    }

    /// Creates accessibility for a tab list
    pub fn tabList(label: []const u8) Accessibility {
        return Accessibility.init()
            .setRole(.tab_list)
            .setLabel(label)
            .setOrientation(.horizontal);
    }

    /// Creates accessibility for a menu
    pub fn menu(label: []const u8) Accessibility {
        return Accessibility.init()
            .setRole(.menu)
            .setLabel(label)
            .setOrientation(.vertical);
    }

    /// Creates accessibility for a menu item
    pub fn menuItem() Accessibility {
        return Accessibility.init()
            .setRole(.menu_item);
    }

    /// Creates accessibility for a checkbox
    pub fn checkbox(checked: bool) Accessibility {
        return Accessibility.init()
            .setRole(.checkbox)
            .setChecked(if (checked) .true_val else .false_val);
    }

    /// Creates accessibility for a switch/toggle
    pub fn switchToggle(on: bool) Accessibility {
        return Accessibility.init()
            .setRole(.switch_role)
            .setChecked(if (on) .true_val else .false_val);
    }

    /// Creates accessibility for a slider
    pub fn slider(value: f32, min: f32, max: f32) Accessibility {
        return Accessibility.init()
            .setRole(.slider)
            .setValue(value, min, max)
            .setOrientation(.horizontal);
    }

    /// Creates accessibility for a progress bar
    pub fn progressBar(value: f32, max: f32) Accessibility {
        return Accessibility.init()
            .setRole(.progress_bar)
            .setValue(value, 0, max);
    }

    /// Creates accessibility for a live region that announces updates
    pub fn liveRegion(priority: Live) Accessibility {
        return Accessibility.init()
            .setLive(priority)
            .setAtomic(true);
    }

    /// Creates accessibility for a status message area
    pub fn statusRegion() Accessibility {
        return Accessibility.init()
            .setRole(.status)
            .setLive(.polite)
            .setAtomic(true);
    }

    /// Creates accessibility for an alert (assertive announcement)
    pub fn alert() Accessibility {
        return Accessibility.init()
            .setRole(.alert)
            .setLive(.assertive)
            .setAtomic(true);
    }

    /// Creates accessibility for a tooltip
    pub fn tooltip() Accessibility {
        return Accessibility.init()
            .setRole(.tooltip);
    }

    /// Creates accessibility for a search input
    pub fn searchInput() Accessibility {
        return Accessibility.init()
            .setRole(.search_box);
    }

    /// Creates accessibility for a tree view
    pub fn tree(label: []const u8, multiselect: bool) Accessibility {
        return Accessibility.init()
            .setRole(.tree)
            .setLabel(label)
            .setMultiselectable(multiselect)
            .setOrientation(.vertical);
    }

    /// Creates accessibility for a tree item
    pub fn treeItem(expanded: ?bool, selected: bool, level: u8, pos: u32, total: u32) Accessibility {
        var a = Accessibility.init()
            .setRole(.tree_item)
            .setSelected(selected)
            .setLevel(level)
            .setPosition(pos, total);
        if (expanded) |e| {
            a = a.setExpanded(e);
        }
        return a;
    }

    /// Creates accessibility for toolbar
    pub fn toolbar(label: []const u8) Accessibility {
        return Accessibility.init()
            .setRole(.toolbar)
            .setLabel(label)
            .setOrientation(.horizontal);
    }

    /// Creates accessibility for a grid/table
    pub fn grid(label: []const u8) Accessibility {
        return Accessibility.init()
            .setRole(.grid)
            .setLabel(label);
    }

    /// Creates accessibility for a radio group
    pub fn radioGroup(label: []const u8) Accessibility {
        return Accessibility.init()
            .setRole(.radio_group)
            .setLabel(label);
    }

    /// Creates accessibility for a radio button
    pub fn radio(checked: bool, pos: u32, total: u32) Accessibility {
        return Accessibility.init()
            .setRole(.radio)
            .setChecked(if (checked) .true_val else .false_val)
            .setPosition(pos, total);
    }
    pub fn setRowIndex(self: Accessibility, index: u32) Accessibility {
        var a = self;
        a.row_index = index;
        return a;
    }

    pub fn setColIndex(self: Accessibility, index: u32) Accessibility {
        var a = self;
        a.col_index = index;
        return a;
    }

    // While you're at it, add these too since you have the fields:
    pub fn setColSpan(self: Accessibility, span: u32) Accessibility {
        var a = self;
        a.col_span = span;
        return a;
    }

    pub fn setRowSpan(self: Accessibility, span: u32) Accessibility {
        var a = self;
        a.row_span = span;
        return a;
    }
};
