const std = @import("std");

const Vapor = @import("Vapor.zig");

const UINode = @import("UITree.zig").UINode;

const utils = @import("utils.zig");
const Accessibility = @import("Accessibility.zig");

const hashKey = utils.hashKey;

const println = Vapor.println;

var writer: *std.Io.Writer = undefined;

const mode_options =
    struct {
        pub const static_mode = false;
        pub const enable_atomic = true;
    };

/// Aborts static generation with a diagnostic.
///
/// Generation runs in the CLI, not the browser, so failing hard is right — but
/// `unreachable` is undefined behaviour under ReleaseFast/ReleaseSmall and
/// prints nothing. This aborts identically in every optimize mode and says
/// what went wrong.
fn fatal(comptime what: []const u8, err: anyerror) noreturn {
    std.debug.print("vapor: html generation failed: " ++ what ++ ": {any}\n", .{err});
    @panic("html generation failed");
}

fn fatalMsg(comptime msg: []const u8) noreturn {
    std.debug.print("vapor: html generation failed: " ++ msg ++ "\n", .{});
    @panic("html generation failed");
}

/// Writes to the output document.
///
/// `Io.Writer.write` is allowed to write fewer bytes than asked and report the
/// count; every call site here discarded that count, so a short write silently
/// truncated the page. `writeAll` loops until the whole slice is out.
fn emit(bytes: []const u8) void {
    writer.writeAll(bytes) catch |err| fatal("writing output", err);
}

pub fn generate(root: *UINode, new_writer: *std.Io.Writer, style_path: []const u8) void {
    var threaded: std.Io.Threaded = .init_single_threaded;
    const io = threaded.io();
    const cwd = std.Io.Dir.cwd();

    var gpa = std.heap.DebugAllocator(.{}){};
    defer if (gpa.deinit() != .ok) @panic("Failed to deinit gpa");
    var arena_alloc = std.heap.ArenaAllocator.init(gpa.allocator());
    const allocator = arena_alloc.allocator();
    defer arena_alloc.deinit();
    writer = new_writer;

    // template.html lives in the source tree, not the release dir
    const html_template = cwd.readFileAlloc(io, "template.html", allocator, .unlimited) catch |err|
        fatal("reading template.html from the project root", err);

    // Write everything before </head>
    const head_target = "</head>";
    const start = std.mem.indexOf(u8, html_template, head_target) orelse
        fatalMsg("template.html has no </head>");
    emit(html_template[0..start]);

    // CSS links point to /static/ for the browser
    const style_link = std.fmt.allocPrint(allocator, "  <link rel=\"stylesheet\" href=\"{s}\" />", .{style_path}) catch |err|
        fatal("building the stylesheet link", err);
    emit(style_link);
    emit("\n  <link rel=\"stylesheet\" href=\"/static/style_variables.css\" />");

    // Find the contents div
    const target = "<main id=\"contents\" style=\"display: contents\">";
    var end = std.mem.indexOf(u8, html_template, target) orelse
        fatalMsg("template.html has no <main id=\"contents\" style=\"display: contents\"> element");
    end += target.len;

    // Write from </head> through the contents div
    emit(html_template[start..end]);

    var children = root.children();
    while (children.next()) |child| {
        createHtmlTree(child);
    }
    emit("</main>\n</body>\n</html>");
}

/// Writes `text` with the HTML metacharacters replaced by entities.
///
/// This is the boundary between application data and markup. Without it any
/// value containing `<` stops being content and becomes tags in the served
/// page. The same escape set covers both text nodes and double-quoted
/// attribute values, so there is only one function to get right; escaping
/// quotes inside text content is harmless, they render as themselves.
///
/// Deliberate raw markup — `Vapor.Html(...)` and `Svg` — does not come through
/// here. Those are the documented escape hatches and are the caller's
/// responsibility, exactly like `dangerouslySetInnerHTML`.
fn writeEscaped(text: []const u8) void {
    var start: usize = 0;
    for (text, 0..) |c, i| {
        const entity = switch (c) {
            '&' => "&amp;",
            '<' => "&lt;",
            '>' => "&gt;",
            '"' => "&quot;",
            '\'' => "&#39;",
            else => continue,
        };
        if (i > start) emit(text[start..i]);
        emit(entity);
        start = i + 1;
    }
    if (start < text.len) emit(text[start..]);
}

/// Escapes into a caller-supplied writer. Exposed so the escaping rules can be
/// tested without standing up a whole render.
pub fn escapeInto(out: *std.Io.Writer, text: []const u8) void {
    const previous = writer;
    defer writer = previous;
    writer = out;
    writeEscaped(text);
}

/// Writes an optional HTML attribute if the value is not null.
fn writeOptionalProp(name: []const u8, value: ?[]const u8) void {
    if (value) |v| {
        emit(name);
        emit("=\"");
        writeEscaped(v);
        emit("\"");
    }
}

/// Writes all common HTML attributes from the UINode.
fn writeAllProps(ui_node: *UINode) void {
    // Write mandatory ID
    emit(" ");
    emit(" id=\"");
    writeEscaped(ui_node.uuid);
    emit("\"");
    writeOptionalProp(" data-vp", "");

    if (ui_node.inlineStyle) |inlineStyle| {
        writeOptionalProp(" style", inlineStyle);
    }

    // Write optional props
    if (ui_node.type == .Icon) {
        // An icon's token lives in `href`. Both the missing-token case and a
        // class list longer than the buffer are reachable from ordinary user
        // input, so neither may be an assertion.
        const icon_token = ui_node.href orelse "";
        const class = ui_node.class orelse "";
        var buf: [256]u8 = undefined;
        if (std.fmt.bufPrint(&buf, "{s} {s}", .{ icon_token, class })) |icon_class| {
            writeOptionalProp(" class", icon_class);
        } else |_| {
            // Too long for the buffer — emit the parts separately rather than
            // dropping the class, and without returning early, since the
            // attributes below still need writing.
            emit(" class=\"");
            writeEscaped(icon_token);
            emit(" ");
            writeEscaped(class);
            emit("\"");
        }
    } else {
        writeOptionalProp(" class", ui_node.class);
    }

    if (ui_node.accessibility) blk: {
        const acc = Accessibility.a11y_map.get(hashKey(ui_node.uuid)) orelse {
            break :blk;
        };
        writeOptionalProp("aria-label", acc.label);
    }

    if (ui_node.type != .Graphic and ui_node.type != .Icon) {
        if (ui_node.type == .Image) {
            writeOptionalProp(" src", ui_node.href);
        } else {
            writeOptionalProp(" href", ui_node.href);
        }
    } else if (ui_node.type == .Graphic and mode_options.static_mode) {
        writeOptionalProp(" src", ui_node.href);
    }

    // TODO: Add other attributes as needed, e.g., 'src' for 'video'
}

pub fn createDivOpen(ui_node: *UINode) void {
    emit("<div");
    writeAllProps(ui_node);
    emit(">");
}

pub fn createDivClose() void {
    emit("</div>");
}

pub fn createButtonOpen(ui_node: *UINode) void {
    emit("<button");
    writeAllProps(ui_node);
    emit(">");
}

pub fn createButtonClose() void {
    emit("</button>");
}

pub fn createParagraphOpen(ui_node: *UINode) void {
    emit("<p");
    writeAllProps(ui_node);
    emit(">");
    if (ui_node.text) |text| {
        writeEscaped(text);
    }
}

pub fn createParagraphClose() void {
    emit("</p>");
}

/// Writes `Vapor.Html(...)` content verbatim.
///
/// `.HtmlText` is the library's deliberate raw-markup escape hatch — the whole
/// point of the `Html` component is to emit tags — so this is the one text path
/// that must not be escaped. Anything reaching it is trusted by the caller, the
/// same contract as React's `dangerouslySetInnerHTML`.
pub fn createRawHtml(ui_node: *UINode) void {
    emit("<p");
    writeAllProps(ui_node);
    emit(">");
    if (ui_node.text) |text| {
        emit(text);
    }
    emit("</p>");
}

pub fn createField(ui_node: *UINode) void {
    emit("<p");
    writeAllProps(ui_node);
    emit(">");
    if (ui_node.text) |text| {
        writeEscaped(text);
    }
    emit("</p>");
}

pub fn createInput(ui_node: *UINode) void {
    emit("<input");
    writeAllProps(ui_node);
    writeOptionalProp("name", ui_node.name);
    // Optional on the node: configuration skips it if its allocation failed.
    const params = ui_node.text_field_params orelse {
        emit(">");
        return;
    };
    switch (params.*) {
        .email => |email| {
            var default_value: []const u8 = "";
            if (email.default_ptr) |ptr| {
                default_value = ptr[0..email.default_len];
            }
            writeOptionalProp("type", "email");
            writeOptionalProp("placeholder", default_value);
        },
        .file => |file| {
            _ = file;
            writeOptionalProp("type", "file");
        },
        else => {},
    }
    emit("/>");
    // emit("</input>");
}

pub fn createTextArea(ui_node: *UINode) void {
    emit("<textarea");
    writeAllProps(ui_node);
    writeOptionalProp("name", ui_node.name);
    // Optional on the node: configuration skips it if its allocation failed.
    const params = ui_node.text_field_params orelse {
        emit(">");
        return;
    };
    var default_value: []const u8 = "";
    const string = params.string;
    if (string.default_ptr) |ptr| {
        default_value = ptr[0..string.default_len];
    }
    writeOptionalProp("type", "email");
    writeOptionalProp("placeholder", default_value);
    emit(">");
    emit("</textarea>");
}

pub fn createLabel(ui_node: *UINode) void {
    emit("<label ");
    writeOptionalProp("for", ui_node.name);
    writeAllProps(ui_node);
    emit(">");
    if (ui_node.text) |text| {
        writeEscaped(text);
    }
    emit("</label>");
}

pub fn createLinkOpen(ui_node: *UINode) void {
    emit("<a");
    writeAllProps(ui_node);
    emit(">");
}
pub fn createLinkClose() void {
    emit("</a>");
}

pub fn createIconOpen(ui_node: *UINode) void {
    emit("<i");
    writeAllProps(ui_node);
    emit(">");
}
pub fn createIconClose() void {
    emit("</i>");
}

pub fn createImageOpen(ui_node: *UINode) void {
    emit("<img");
    writeAllProps(ui_node);
    writeOptionalProp("alt", ui_node.alt);
    emit(">");
}
pub fn createImageClose() void {
    emit("</img>");
}

pub fn createGraphicOpen(ui_node: *UINode) void {
    if (mode_options.static_mode) {
        emit("<div");
        writeAllProps(ui_node);
        emit(">");
    } else {
        emit("<div");
        writeAllProps(ui_node);
        emit(">");
    }
}
pub fn createGraphicClose() void {
    if (mode_options.static_mode) {
        emit("</div>");
    } else {
        emit("</div>");
    }
}

pub fn createListOpen(ui_node: *UINode) void {
    emit("<ul");
    writeAllProps(ui_node);
    emit(">");
}

pub fn createListItemClose() void {
    emit("</li>");
}

pub fn createListItemOpen(ui_node: *UINode) void {
    emit("<li");
    writeAllProps(ui_node);
    emit("\">");
}
pub fn createListClose() void {
    emit("</ul>");
}

pub fn createSectionOpen(ui_node: *UINode) void {
    emit("<section");
    writeAllProps(ui_node);
    emit(">");
}
pub fn createSectionClose() void {
    emit("</section>");
}

pub fn createCodeOpen(ui_node: *UINode) void {
    emit("<code");
    writeAllProps(ui_node);
    emit(">");
    if (ui_node.text) |text| {
        writeEscaped(text);
    }
}
pub fn createCodeClose() void {
    emit("</code>");
}

pub fn createHeadingOpen(ui_node: *UINode) void {
    emit("<h");
    if (ui_node.level) |level| {
        // Write the slice to the file
        writer.print("{any}", .{level}) catch |err| fatal("writing heading level", err);
    }
    writeAllProps(ui_node);
    emit(">");
    if (ui_node.text) |text| {
        writeEscaped(text);
    }
}
pub fn createHeadingClose() void {
    emit("</h>");
}

pub fn createSvgOpen(ui_node: *UINode) void {
    const start = std.mem.find(u8, ui_node.text.?, ">") orelse return;
    const end = std.mem.indexOf(u8, ui_node.text.?, "</svg>") orelse return;

    emit(ui_node.text.?[0..start]);
    writer.writeByte(' ') catch |err| fatal("writing output", err);
    writeAllProps(ui_node);
    emit(">\n");
    emit(ui_node.text.?[start + 1 .. end]);
}

pub fn createSvgClose() void {
    emit("</svg>");
}

pub fn createElementOpen(ui_node: *UINode) void {
    switch (ui_node.type) {
        .FlexBox => {
            createDivOpen(ui_node);
        },

        .Text => {
            createParagraphOpen(ui_node);
            createParagraphClose();
        },
        .Icon => {
            createIconOpen(ui_node);
        },
        .TextFmt => {
            createField(ui_node);
        },
        .TextField => {
            createInput(ui_node);
        },
        .TextArea => {
            createTextArea(ui_node);
        },
        .Label => {
            createLabel(ui_node);
        },

        .Button, .CtxButton, .ButtonCycle => {
            createButtonOpen(ui_node);
        },
        // Assuming EType.Link exists for nodes with 'href'
        .Link, .RedirectLink => {
            createLinkOpen(ui_node);
        },

        .Image => {
            createImageOpen(ui_node);
        },

        .HtmlText => {
            createRawHtml(ui_node);
        },

        .List => {
            createListOpen(ui_node);
        },

        .ListItem => {
            createListItemOpen(ui_node);
        },

        .Graphic => {
            createGraphicOpen(ui_node);
        },

        .Intersection => {
            createSectionOpen(ui_node);
        },

        .Code => {
            createCodeOpen(ui_node);
        },
        .Heading => {
            createHeadingOpen(ui_node);
        },

        .Svg => {
            createSvgOpen(ui_node);
        },

        .Hooks, .HooksCtx => {
            createDivOpen(ui_node);
        },

        .Spacer => {
            createDivOpen(ui_node);
        },

        else => {
            // createDivOpen(ui_node);
        },
    }
}

pub fn createElementClose(ui_node: *UINode) void {
    switch (ui_node.type) {
        .FlexBox => {
            createDivClose();
        },

        .Button, .CtxButton, .ButtonCycle => {
            createButtonClose();
        },
        // Assuming EType.Link exists
        .Link, .RedirectLink => {
            createLinkClose();
        },

        .Icon => {
            createIconClose();
        },

        .Image => {
            createImageClose();
        },

        .Graphic => {
            createGraphicClose();
        },

        .List => {
            createListClose();
        },

        .ListItem => {
            createListItemClose();
        },

        .Intersection => {
            createSectionClose();
        },

        .Code => {
            createCodeClose();
        },

        .Heading => {
            createHeadingClose();
        },

        .HtmlText => {},

        .Svg => {
            createSvgClose();
        },

        .Hooks, .HooksCtx => {
            createDivClose();
        },

        .Spacer => {
            createDivClose();
        },

        else => {},
    }
}

pub fn createHtmlTree(node: *UINode) void {
    createElementOpen(node);

    // If node type is NOT .Text (which handles its own text)
    // and it HAS text, write it as content.
    // This is for <button>Text</button> or <a>Text</a>
    emit("\n");
    var children = node.children();
    while (children.next()) |child| {
        createHtmlTree(child);
    }

    // Only call close for non-atomic elements
    if (node.type != .Text and node.type != .HtmlText) {
        createElementClose(node);
        emit("\n");
    }
}
