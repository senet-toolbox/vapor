// =============================================================================
// WASM External Bindings for Zig
// JavaScript interop declarations organized by functional domain
// =============================================================================

const Vapor = @import("Vapor.zig");

// =============================================================================
// CORE / SYSTEM
// =============================================================================

/// Requests a UI re-render cycle.
pub extern fn requestRerenderWasm() void;

/// Checks for WASM memory growth.
// pub extern fn checkMemoryGrowthWasm() void;

// =============================================================================
// CONSOLE / DEBUGGING
// =============================================================================

/// Logs a message to the console.
pub extern fn consoleLogWasm(ptr: [*]const u8, len: usize) i32;

/// Logs a styled/colored message to the console.
pub extern fn consoleLogColoredWasm(
    ptr: [*]const u8,
    len: usize,
    style_ptr_1: [*]const u8,
    style_len_1: usize,
    style_ptr_2: [*]const u8,
    style_len_2: usize,
) void;

/// Logs a styled/colored warning to the console.
pub extern fn consoleLogColoredWarnWasm(
    ptr: [*]const u8,
    len: usize,
    style_ptr_1: [*]const u8,
    style_len_1: usize,
    style_ptr_2: [*]const u8,
    style_len_2: usize,
) void;

/// Shows a browser alert dialog.
pub extern fn alertWasm(ptr: [*]const u8, len: usize) void;

// =============================================================================
// EVENT HANDLING - Document Level
// =============================================================================

/// Registers a global event listener for a given event type and callback.
pub extern fn createEventListenerGlobal(
    event_ptr: [*]const u8,
    event_type_len: usize,
    cb_id: u32,
) void;

/// Removes a global event listener.
pub extern fn removeEventListener(
    event_ptr: [*]const u8,
    event_type_len: usize,
    cb_id: u32,
) void;

// =============================================================================
// EVENT HANDLING - Element Level
// =============================================================================

/// Registers an event listener on a specific element.
pub extern fn createElementEventListener(
    element_ptr: [*]const u8,
    element_len: usize,
    event_ptr: [*]const u8,
    event_type_len: usize,
    cb_id: u32,
) void;

/// Removes a previously registered event listener from an element.
pub extern fn removeElementEventListener(
    element_ptr: [*]const u8,
    element_len: usize,
    event_ptr: [*]const u8,
    event_type_len: usize,
    cb_id: u32,
) void;

// =============================================================================
// EVENT DATA EXTRACTION
// =============================================================================

/// Retrieves event data as a string or byte sequence.
pub extern fn getEventDataWasm(id: u32, ptr: [*]const u8, len: usize) [*:0]u8;

/// Gets input value associated with an event.
pub extern fn getEventDataInputWasm(id: u32) [*:0]u8;

/// Extracts a numeric property from event data.
pub extern fn getEventDataNumberWasm(id: u32, ptr: [*]const u8, len: usize) f32;

/// Prevents the default action for the specified event.
pub extern fn eventPreventDefault(id: u32) void;

/// Stops the propagation of the specified event.
pub extern fn eventStopPropagation(id: u32) void;

/// Extracts form data from a form submission event.
pub extern fn formDataWasm(event_id: u32) u32;

// =============================================================================
// DOM ELEMENT CREATION & MANIPULATION
// =============================================================================

/// Creates a new DOM element with an ID, type, and optional text.
pub extern fn createElement(
    id_ptr: [*]const u8,
    id_len: usize,
    elem_type: u8,
    btn_id: u32,
    text_ptr: [*]const u8,
    text_len: usize,
) void;

// =============================================================================
// DOM ELEMENT ATTRIBUTES & PROPERTIES
// =============================================================================

/// Sets a numeric attribute on an element.
pub extern fn mutateDomElementWasm(
    id_ptr: [*]const u8,
    id_len: usize,
    attribute: [*]const u8,
    attribute_len: usize,
    value: f32,
) void;

/// Retrieves numeric attributes (e.g., width, height).
pub extern fn getAttributeWasmNumber(
    ptr: [*]const u8,
    len: usize,
    attribute_ptr: [*]const u8,
    attribute_len: usize,
) u32;

pub extern fn mutateDomElementStringWasm(
    id_ptr: [*]const u8,
    id_len: usize,
    attribute: [*]const u8,
    attribute_len: usize,
    value_ptr: [*]const u8,
    value_len: usize,
) void;

pub extern fn mutateDomElementI32Wasm(
    id_ptr: [*]const u8,
    id_len: usize,
    attribute: [*]const u8,
    attribute_len: usize,
    value: i32,
) void;

pub extern fn mutateDomElementF32Wasm(
    id_ptr: [*]const u8,
    id_len: usize,
    attribute: [*]const u8,
    attribute_len: usize,
    value: f32,
) void;

pub extern fn consoleLogColoredErrorWasm(
    ptr: [*]const u8,
    len: usize,
    style_ptr_1: [*]const u8,
    style_len_1: usize,
    style_ptr_2: [*]const u8,
    style_len_2: usize,
) void;

// =============================================================================
// DOM STYLING
// =============================================================================

/// Modifies a style attribute using a numeric value.
pub extern fn mutateDomElementStyleWasm(
    id_ptr: [*]const u8,
    id_len: usize,
    attribute: [*]const u8,
    attribute_len: usize,
    value: f32,
) void;

/// Modifies a style attribute using a string value.
pub extern fn mutateDomElementStyleStringWasm(
    id_ptr: [*]const u8,
    id_len: usize,
    attribute: [*]const u8,
    attribute_len: usize,
    value_ptr: [*]const u8,
    value_len: usize,
) void;

/// Applies a 3D transform to an element.
pub extern fn translate3dWasm(
    id_ptr: [*]const u8,
    id_len: usize,
    x: f32,
    y: f32,
    z: f32,
) void;

// =============================================================================
// CSS CLASSES
// =============================================================================

/// Adds a CSS class to the specified element.
pub extern fn addClass(
    id_ptr: [*]const u8,
    id_len: usize,
    class_id_ptr: [*]const u8,
    class_id_len: usize,
) void;

/// Removes a CSS class from the specified element.
pub extern fn removeClass(
    id_ptr: [*]const u8,
    id_len: usize,
    class_id_ptr: [*]const u8,
    class_id_len: usize,
) void;

/// Defines a new CSS class dynamically.
pub extern fn createClass(class_ptr: [*]const u8, class_len: usize) void;

/// Toggles between light and dark themes.
pub extern fn toggleThemeWasm() void;

// =============================================================================
// ELEMENT DIMENSIONS & POSITION
// =============================================================================

/// Gets element's bounding rectangle (x, y, width, height).
pub extern fn getBoundingClientRectWasm(ptr: [*]const u8, len: usize) [*]f32;

/// Gets element offsets relative to its parent.
pub extern fn getOffsetsWasm(ptr: [*]const u8, len: usize) [*]f32;

/// Gets the element ID at given mouse coordinates.
pub extern fn getElementUnderMouse(x: f32, y: f32) [*:0]u8;

// =============================================================================
// ELEMENT FOCUS & INTERACTIONS
// =============================================================================

/// Focuses a DOM element (e.g., input).
pub extern fn elementFocusWasm(element_ptr: [*]const u8, element_len: usize) void;

/// Checks if a DOM element is currently focused.
pub extern fn elementFocusedWasm(element_ptr: [*]const u8, element_len: usize) bool;

/// Programmatically triggers a click on an element.
pub extern fn callClickWASM(id_ptr: [*]const u8, id_len: usize) void;

// =============================================================================
// INPUT ELEMENTS
// =============================================================================

/// Retrieves the current value of an input element.
pub extern fn getInputValueWasm(ptr: [*]const u8, len: usize) [*:0]u8;

/// Sets the value of an input element.
pub extern fn setInputValueWasm(
    ptr: [*]const u8,
    len: usize,
    text_ptr: [*]const u8,
    text_len: usize,
) void;

/// Sets the cursor position in a text input.
pub extern fn setCursorPositionWasm(
    id_ptr: [*]const u8,
    id_len: usize,
    pos: usize,
) void;

/// Gets the current selection in a text input.
pub extern fn selectionWasm(
    id_ptr: [*]const u8,
    id_len: usize,
) [*]u32;

pub extern fn replaceRangeWasm(
    id_ptr: [*]const u8,
    id_len: usize,
    start: usize,
    end: usize,
    replacement_ptr: [*]const u8,
    replacement_len: usize,
) void;

// =============================================================================
// DEBUG HIGHLIGHTING
// =============================================================================

/// Highlights a DOM node visually (useful for debugging).
pub extern fn highlightTargetNode(ptr: [*]const u8, len: usize, highlight_type: u32) void;

/// Highlights a DOM node on hover.
pub extern fn highlightHoverTargetNode(ptr: [*]const u8, len: usize, highlight_type: u32) void;

/// Clears all highlight overlays.
pub extern fn clearHighlight() void;

/// Clears hover highlight overlays.
pub extern fn clearHoverHighlight() void;

// =============================================================================
// TIMERS & SCHEDULING
// =============================================================================

/// Registers a JS timeout with callback.
pub extern "env" fn timeout(ms: u32, callbackId: u32) void;

/// Timeout with context preservation.
pub extern "env" fn timeoutCtx(ms: u32, callbackId: u32) void;

/// Cancels a previously set timeout.
pub extern "env" fn cancelTimeoutWasm(id: u32) void;

/// Registers a repeating interval.
pub extern "env" fn createInterval(
    callback_id: u32,
    delay: u32,
) void;

// =============================================================================
// NAVIGATION & ROUTING
// =============================================================================

/// Retrieves window path information.
pub extern fn getWindowInformationWasm() [*:0]u8;

/// Gets URL search parameters.
pub extern fn getWindowParamsWasm() [*:0]u8;

/// Gets URL hash fragment.
pub extern fn getWindowHashWasm() [*:0]u8;

/// Sets URL hash fragment.
pub extern fn setWindowHashWasm(hash_ptr: [*]const u8, hash_len: usize) void;

/// Sets the full window location (causes navigation).
pub extern fn setWindowLocationWasm(url_ptr: [*]const u8, url_len: usize) void;
pub extern fn getWindowOriginWasm() [*:0]u8;

/// Navigate to a path without full page reload.
pub extern fn navigateWasm(path_ptr: [*]const u8, path_len: usize) void;

/// Navigate back in browser history.
pub extern fn backWasm() void;

/// Navigate forward in browser history.
pub extern fn forwardWasm() void;

/// Replace current history entry without adding new entry.
pub extern fn replaceStateWasm(path_ptr: [*]const u8, path_len: usize) void;

// =============================================================================
// SCROLLING
// =============================================================================

/// Scrolls window to specified coordinates.
pub extern fn scrollToWasm(x: f32, y: f32) void;

/// Gets current scroll position.
pub extern fn getScrollPositionWasm() [*]f32;

const ScrollBehavior = Vapor.Event.ScrollBehavior;
const ScrollBlock = Vapor.Event.ScrollBlock;

/// Scrolls element into view with options.
pub extern fn scrollIntoViewWasm(
    id_ptr: [*]const u8,
    id_len: usize,
    behavior: ScrollBehavior,
    block: ScrollBlock,
) void;

pub extern fn scrollToBehaviorWasm(id_ptr: [*]const u8, id_len: usize, top: f32, left: f32, behavior: ScrollBehavior, block: ScrollBlock) void;

/// Gets element's scroll properties.
pub extern fn getElementScrollWasm(id_ptr: [*]const u8, id_len: usize) [*]f32;

/// Sets element's scroll position.
pub extern fn setElementScrollWasm(
    id_ptr: [*]const u8,
    id_len: usize,
    top: f32,
    left: f32,
) void;

// =============================================================================
// WINDOW INFORMATION
// =============================================================================

/// Returns the window inner width.
pub extern fn windowWidth() f32;

/// Returns the window inner height.
pub extern fn windowHeight() f32;

/// Returns the device pixel ratio.
pub extern fn getDevicePixelRatioWasm() f32;

/// Returns the user agent string.
pub extern fn getUserAgentWasm() [*:0]u8;

/// Returns the browser language.
pub extern fn getLanguageWasm() [*:0]u8;

/// Returns whether the browser is online.
pub extern fn isOnlineWasm() u32;

/// Returns whether the document is visible.
pub extern fn isDocumentVisibleWasm() u32;

/// Returns whether the window is focused.
pub extern fn isWindowFocusedWasm() u32;

/// Registers a visibility change callback.
pub extern fn onVisibilityChangeWasm(callback_id: u32) void;

// =============================================================================
// LOCAL STORAGE
// =============================================================================

/// Stores a string value in local storage.
pub extern fn setLocalStorageStringWasm(
    ptr: [*]const u8,
    len: usize,
    value_ptr: [*]const u8,
    value_len: usize,
) void;

/// Retrieves a string value from local storage.
pub extern fn getLocalStorageStringWasm(ptr: [*]const u8, len: usize) ?[*:0]u8;

/// Stores a number in local storage.
pub extern fn setLocalStorageNumberWasm(ptr: [*]const u8, len: usize, value: u32) void;

/// Retrieves a signed integer from local storage.
pub extern fn getLocalStorageI32Wasm(ptr: [*]const u8, len: usize) i32;

/// Retrieves an unsigned integer from local storage.
pub extern fn getLocalStorageU32Wasm(ptr: [*]const u8, len: usize) u32;

/// Removes a key from local storage.
pub extern fn removeLocalStorageWasm(ptr: [*]const u8, len: usize) void;

/// Clears all stored values in local storage.
pub extern fn clearLocalStorageWasm() void;

// =============================================================================
// COOKIES
// =============================================================================

/// Sets a cookie.
pub extern fn setCookieWasm(cookie_ptr: [*]const u8, cookie_len: usize) void;

/// Retrieves a cookie by name.
pub extern fn getCookieWasm(name_ptr: [*]const u8, name_len: usize) ?[*:0]u8;

/// Gets all cookies as a string.
pub extern fn getCookiesWasm() [*:0]u8;

// =============================================================================
// CLIPBOARD
// =============================================================================

/// Copies text to the clipboard.
pub extern fn copyTextWasm(ptr: [*]const u8, len: usize) void;

/// Reads text from clipboard (async, uses callback).
pub extern fn readClipboardWasm(callback_id: u32) void;

// =============================================================================
// NETWORK / FETCH
// =============================================================================

/// Performs a fetch request with full options.
pub extern fn fetchWasm(
    url_ptr: [*]const u8,
    url_len: usize,
    callback_id: u32,
    http_ptr: [*]const u8,
    http_len: usize,
) void;

// =============================================================================
// HOOKS
// =============================================================================

/// Creates a network hook with callback.
pub extern fn createHookWASM(
    url_ptr: [*]const u8,
    url_len: usize,
    cb_id: u32,
    hook_type: u8,
) void;

// =============================================================================
// INTERSECTION OBSERVER
// =============================================================================

/// Creates an intersection observer with options.
pub extern fn createObserverWasm(id: u32, options_ptr: *const Vapor.Kit.ObserverOptions) void;

/// Starts observing an element.
pub extern fn observeWasm(
    id: u32,
    element_ptr: [*]const u8,
    element_len: usize,
    index: usize,
) void;

/// Disconnects an observer (stops observing all elements).
pub extern fn reinitObserverWasm(id: u32) void;

/// Destroys an observer completely.
pub extern fn destroyObserverWasm(ptr: [*]const u8, len: usize) void;

// =============================================================================
// VIDEO / MEDIA
// =============================================================================

/// Starts video capture from camera.
pub extern fn startVideoWasm(id_ptr: [*]const u8, id_len: usize) void;

/// Plays a video element.
pub extern fn playVideoWasm(id_ptr: [*]const u8, id_len: usize) void;

/// Pauses a video element.
pub extern fn pauseVideoWasm(id_ptr: [*]const u8, id_len: usize) void;

/// Stops camera and removes stream.
pub extern fn stopCameraWasm(id_ptr: [*]const u8, id_len: usize) void;

/// Seeks video to specified time in seconds.
pub extern fn seekVideoWasm(id_ptr: [*]const u8, id_len: usize, seconds: f32) void;

/// Sets video volume (0.0 - 1.0).
pub extern fn setVolumeWasm(id_ptr: [*]const u8, id_len: usize, volume: f32) void;

/// Mutes or unmutes video.
pub extern fn muteVideoWasm(id_ptr: [*]const u8, id_len: usize, mute: bool) void;

/// Gets video duration in seconds.
pub extern fn getVideoDurationWasm(id_ptr: [*]const u8, id_len: usize) f32;

/// Gets current video playback time in seconds.
pub extern fn getVideoCurrentTimeWasm(id_ptr: [*]const u8, id_len: usize) f32;

// =============================================================================
// =============================================================================
// =============================================================================
// =============================================================================
// =============================================================================
// =============================================================================
// =============================================================================
// =============================================================================
// =============================================================================
// =============================================================================
// =============================================================================
// =============================================================================
// =============================================================================
// =============================================================================
// =============================================================================
// =============================================================================
// =============================================================================
// =============================================================================
// ADDITIONAL WASM EXTERN DECLARATIONS - Zig Side
// =============================================================================

// =============================================================================
// FILE HANDLING
// =============================================================================

/// Programmatically triggers a file input element.
pub extern fn triggerFileInputWasm(id_ptr: [*]const u8, id_len: usize) void;

/// Gets the number of files selected in a file input.
pub extern fn getFileCountWasm(event_id: u32) u32;

/// Gets file metadata as JSON string.
pub extern fn getFileInfoWasm(event_id: u32, file_index: u32) u32;

/// Reads a file as text (async).
pub extern fn readFileAsTextWasm(event_id: u32, file_index: u32, callback_ptr: u32) void;

/// Reads a file as base64 (async).
pub extern fn readFileAsBase64Wasm(event_id: u32, file_index: u32, callback_id: u32) void;

/// Reads a file as array buffer (async).
pub extern fn readFileAsArrayBufferWasm(event_id: u32, file_index: u32, callback_id: u32) void;

/// Creates a Blob URL (e.g., "blob:http://localhost/...")
pub extern fn createObjectURLWasm(event_id: u32, file_index: u32) [*:0]u8;

/// Downloads text content as a file.
pub extern fn downloadFileWasm(
    name_ptr: [*]const u8,
    name_len: usize,
    data_ptr: [*]const u8,
    data_len: usize,
    mime_ptr: [*]const u8,
    mime_len: usize,
) void;

/// Downloads binary content as a file.
pub extern fn downloadBinaryFileWasm(
    name_ptr: [*]const u8,
    name_len: usize,
    data_ptr: [*]const u8,
    data_len: usize,
    mime_ptr: [*]const u8,
    mime_len: usize,
) void;

// =============================================================================
// DRAG & DROP
// =============================================================================

/// Gets data from a drag event.
pub extern fn getDragDataWasm(event_id: u32, format_ptr: [*]const u8, format_len: usize) [*:0]u8;

/// Sets data on a drag event.
pub extern fn setDragDataWasm(
    event_id: u32,
    format_ptr: [*]const u8,
    format_len: usize,
    data_ptr: [*]const u8,
    data_len: usize,
) void;

/// Sets the drop effect (none=0, copy=1, move=2, link=3).
pub extern fn setDragEffectWasm(event_id: u32, effect: u32) void;

/// Sets the allowed effect for drag operations.
pub extern fn setDragEffectAllowedWasm(event_id: u32, effect: u32) void;

/// Gets the number of dropped files.
pub extern fn getDroppedFilesCountWasm(event_id: u32) u32;

/// Gets dropped file metadata as JSON.
pub extern fn getDroppedFileInfoWasm(event_id: u32, file_index: u32) [*:0]u8;

/// Reads a dropped file as text (async).
pub extern fn readDroppedFileAsTextWasm(event_id: u32, file_index: u32, callback_id: u32) void;

/// Reads a dropped file as base64 (async).
pub extern fn readDroppedFileAsBase64Wasm(event_id: u32, file_index: u32, callback_id: u32) void;

// =============================================================================
// WEBSOCKET
// =============================================================================

/// Connects to a WebSocket server. Returns handle.
pub extern fn websocketConnectWasm(
    url_ptr: [*]const u8,
    url_len: usize,
    open_callback_id: u32,
    message_callback_id: u32,
    close_callback_id: u32,
    error_callback_id: u32,
) u32;

/// Sends text data over WebSocket. Returns 1 on success, 0 on failure.
pub extern fn websocketSendWasm(handle: u32, data_ptr: [*]const u8, data_len: usize) u32;

/// Sends binary data over WebSocket. Returns 1 on success, 0 on failure.
pub extern fn websocketSendBinaryWasm(handle: u32, data_ptr: [*]const u8, data_len: usize) u32;

/// Closes a WebSocket connection.
pub extern fn websocketCloseWasm(handle: u32, code: u16, reason_ptr: [*]const u8, reason_len: usize) void;

/// Gets WebSocket state (0=CONNECTING, 1=OPEN, 2=CLOSING, 3=CLOSED, -1=invalid).
pub extern fn websocketStateWasm(handle: u32) i32;

/// Gets the amount of data buffered for sending.
pub extern fn websocketBufferedAmountWasm(handle: u32) u32;

// =============================================================================
// SESSION STORAGE
// =============================================================================

/// Stores a string in session storage.
pub extern fn setSessionStorageStringWasm(
    key_ptr: [*]const u8,
    key_len: usize,
    value_ptr: [*]const u8,
    value_len: usize,
) void;

/// Retrieves a string from session storage.
pub extern fn getSessionStorageStringWasm(key_ptr: [*]const u8, key_len: usize) [*:0]u8;

/// Stores a number in session storage.
pub extern fn setSessionStorageNumberWasm(key_ptr: [*]const u8, key_len: usize, value: f32) void;

/// Retrieves a number from session storage.
pub extern fn getSessionStorageNumberWasm(key_ptr: [*]const u8, key_len: usize) f32;

/// Removes an item from session storage.
pub extern fn removeSessionStorageWasm(key_ptr: [*]const u8, key_len: usize) void;

/// Clears all session storage.
pub extern fn clearSessionStorageWasm() void;

/// Gets the number of items in session storage.
pub extern fn sessionStorageLengthWasm() u32;

/// Gets the key at specified index.
pub extern fn sessionStorageKeyWasm(index: u32) [*:0]u8;

// =============================================================================
// CANVAS 2D
// =============================================================================

/// Gets a 2D rendering context for a canvas. Returns handle.
pub extern fn getCanvas2dContextWasm(id_ptr: [*]const u8, id_len: usize) u32;

/// Sets the fill style color.
pub extern fn canvasSetFillStyleWasm(handle: u32, color_ptr: [*]const u8, color_len: usize) void;

/// Sets the stroke style color.
pub extern fn canvasSetStrokeStyleWasm(handle: u32, color_ptr: [*]const u8, color_len: usize) void;

/// Sets the line width.
pub extern fn canvasSetLineWidthWasm(handle: u32, width: f32) void;

/// Sets line cap style (0=butt, 1=round, 2=square).
pub extern fn canvasSetLineCapWasm(handle: u32, cap: u32) void;

/// Sets line join style (0=miter, 1=round, 2=bevel).
pub extern fn canvasSetLineJoinWasm(handle: u32, join: u32) void;

/// Fills a rectangle.
pub extern fn canvasFillRectWasm(handle: u32, x: f32, y: f32, w: f32, h: f32) void;

/// Strokes a rectangle.
pub extern fn canvasStrokeRectWasm(handle: u32, x: f32, y: f32, w: f32, h: f32) void;

/// Clears a rectangle.
pub extern fn canvasClearRectWasm(handle: u32, x: f32, y: f32, w: f32, h: f32) void;

/// Begins a new path.
pub extern fn canvasBeginPathWasm(handle: u32) void;

/// Closes the current path.
pub extern fn canvasClosePathWasm(handle: u32) void;

/// Moves to a point.
pub extern fn canvasMoveToWasm(handle: u32, x: f32, y: f32) void;

/// Draws a line to a point.
pub extern fn canvasLineToWasm(handle: u32, x: f32, y: f32) void;

/// Draws an arc.
pub extern fn canvasArcWasm(
    handle: u32,
    x: f32,
    y: f32,
    radius: f32,
    start_angle: f32,
    end_angle: f32,
    counterclockwise: bool,
) void;

/// Draws an arc using control points.
pub extern fn canvasArcToWasm(handle: u32, x1: f32, y1: f32, x2: f32, y2: f32, radius: f32) void;

/// Draws a bezier curve.
pub extern fn canvasBezierCurveToWasm(
    handle: u32,
    cp1x: f32,
    cp1y: f32,
    cp2x: f32,
    cp2y: f32,
    x: f32,
    y: f32,
) void;

/// Draws a quadratic curve.
pub extern fn canvasQuadraticCurveToWasm(handle: u32, cpx: f32, cpy: f32, x: f32, y: f32) void;

/// Fills the current path.
pub extern fn canvasFillWasm(handle: u32) void;

/// Strokes the current path.
pub extern fn canvasStrokeWasm(handle: u32) void;

/// Sets the clipping region.
pub extern fn canvasClipWasm(handle: u32) void;

/// Adds a rectangle to the path.
pub extern fn canvasRectWasm(handle: u32, x: f32, y: f32, w: f32, h: f32) void;

/// Draws an ellipse.
pub extern fn canvasEllipseWasm(
    handle: u32,
    x: f32,
    y: f32,
    radius_x: f32,
    radius_y: f32,
    rotation: f32,
    start_angle: f32,
    end_angle: f32,
    counterclockwise: bool,
) void;

/// Fills text at position.
pub extern fn canvasFillTextWasm(
    handle: u32,
    text_ptr: [*]const u8,
    text_len: usize,
    x: f32,
    y: f32,
    max_width: f32,
) void;

/// Strokes text at position.
pub extern fn canvasStrokeTextWasm(
    handle: u32,
    text_ptr: [*]const u8,
    text_len: usize,
    x: f32,
    y: f32,
    max_width: f32,
) void;

/// Sets the font.
pub extern fn canvasSetFontWasm(handle: u32, font_ptr: [*]const u8, font_len: usize) void;

/// Sets text alignment (0=start, 1=end, 2=left, 3=right, 4=center).
pub extern fn canvasSetTextAlignWasm(handle: u32, _align: u32) void;

/// Sets text baseline.
pub extern fn canvasSetTextBaselineWasm(handle: u32, baseline: u32) void;

/// Measures text width.
pub extern fn canvasMeasureTextWasm(handle: u32, text_ptr: [*]const u8, text_len: usize) f32;

/// Draws an image at position.
pub extern fn canvasDrawImageWasm(
    handle: u32,
    img_id_ptr: [*]const u8,
    img_id_len: usize,
    dx: f32,
    dy: f32,
) void;

/// Draws an image scaled.
pub extern fn canvasDrawImageScaledWasm(
    handle: u32,
    img_id_ptr: [*]const u8,
    img_id_len: usize,
    dx: f32,
    dy: f32,
    dw: f32,
    dh: f32,
) void;

/// Draws a slice of an image.
pub extern fn canvasDrawImageSlicedWasm(
    handle: u32,
    img_id_ptr: [*]const u8,
    img_id_len: usize,
    sx: f32,
    sy: f32,
    sw: f32,
    sh: f32,
    dx: f32,
    dy: f32,
    dw: f32,
    dh: f32,
) void;

/// Saves the current state.
pub extern fn canvasSaveWasm(handle: u32) void;

/// Restores the previous state.
pub extern fn canvasRestoreWasm(handle: u32) void;

/// Translates the canvas.
pub extern fn canvasTranslateWasm(handle: u32, x: f32, y: f32) void;

/// Rotates the canvas.
pub extern fn canvasRotateWasm(handle: u32, angle: f32) void;

/// Scales the canvas.
pub extern fn canvasScaleWasm(handle: u32, x: f32, y: f32) void;

/// Sets the transform matrix.
pub extern fn canvasSetTransformWasm(handle: u32, a: f32, b: f32, c: f32, d: f32, e: f32, f: f32) void;

/// Resets the transform to identity.
pub extern fn canvasResetTransformWasm(handle: u32) void;

/// Sets global alpha.
pub extern fn canvasSetGlobalAlphaWasm(handle: u32, alpha: f32) void;

/// Sets global composite operation.
pub extern fn canvasSetGlobalCompositeOperationWasm(handle: u32, op: u32) void;

/// Exports canvas to data URL.
pub extern fn canvasToDataUrlWasm(
    id_ptr: [*]const u8,
    id_len: usize,
    type_ptr: [*]const u8,
    type_len: usize,
    quality: f32,
) [*:0]u8;

/// Gets image data as raw bytes.
pub extern fn canvasGetImageDataWasm(handle: u32, x: f32, y: f32, w: f32, h: f32) [*]u8;

/// Puts image data to canvas.
pub extern fn canvasPutImageDataWasm(
    handle: u32,
    data_ptr: [*]const u8,
    data_len: usize,
    x: f32,
    y: f32,
    w: f32,
    h: f32,
) void;

/// Sets shadow properties.
pub extern fn canvasSetShadowWasm(
    handle: u32,
    color_ptr: [*]const u8,
    color_len: usize,
    blur: f32,
    offset_x: f32,
    offset_y: f32,
) void;

/// Destroys a canvas context.
pub extern fn destroyCanvasContextWasm(handle: u32) void;

// =============================================================================
// AUDIO
// =============================================================================

/// Creates an audio element. Returns handle.
pub extern fn createAudioElementWasm(src_ptr: [*]const u8, src_len: usize) u32;

/// Plays audio.
pub extern fn audioPlayWasm(handle: u32) void;

/// Pauses audio.
pub extern fn audioPauseWasm(handle: u32) void;

/// Stops audio and resets to beginning.
pub extern fn audioStopWasm(handle: u32) void;

/// Sets volume (0.0 to 1.0).
pub extern fn audioSetVolumeWasm(handle: u32, volume: f32) void;

/// Gets current volume.
pub extern fn audioGetVolumeWasm(handle: u32) f32;

/// Sets muted state.
pub extern fn audioSetMutedWasm(handle: u32, muted: bool) void;

/// Gets muted state.
pub extern fn audioGetMutedWasm(handle: u32) u32;

/// Sets loop state.
pub extern fn audioSetLoopWasm(handle: u32, loop: bool) void;

/// Sets current playback time.
pub extern fn audioSetCurrentTimeWasm(handle: u32, time: f32) void;

/// Gets current playback time.
pub extern fn audioGetCurrentTimeWasm(handle: u32) f32;

/// Gets total duration.
pub extern fn audioGetDurationWasm(handle: u32) f32;

/// Gets ready state.
pub extern fn audioGetReadyStateWasm(handle: u32) u32;

/// Sets playback rate.
pub extern fn audioSetPlaybackRateWasm(handle: u32, rate: f32) void;

/// Registers callback for when audio ends.
pub extern fn audioOnEndedWasm(handle: u32, callback_id: u32) void;

/// Registers callback for audio errors.
pub extern fn audioOnErrorWasm(handle: u32, callback_id: u32) void;

/// Registers callback for when audio can play.
pub extern fn audioOnCanPlayWasm(handle: u32, callback_id: u32) void;

/// Destroys an audio element.
pub extern fn destroyAudioElementWasm(handle: u32) void;

// =============================================================================
// GEOLOCATION
// =============================================================================

/// Checks if geolocation is available.
pub extern fn geolocationAvailableWasm() u32;

/// Gets current position (async).
pub extern fn getCurrentPositionWasm(
    callback_id: u32,
    error_callback_id: u32,
    enable_high_accuracy: bool,
    timeout: u32,
    maximum_age: u32,
) void;

/// Starts watching position changes. Returns watch ID.
pub extern fn watchPositionWasm(
    callback_id: u32,
    error_callback_id: u32,
    enable_high_accuracy: bool,
    timeout: u32,
    maximum_age: u32,
) i32;

/// Stops watching position.
pub extern fn clearWatchPositionWasm(watch_id: i32) void;

// =============================================================================
// NOTIFICATIONS
// =============================================================================

/// Gets notification permission status (-1=unsupported, 0=denied, 1=granted, 2=default).
pub extern fn notificationPermissionWasm() i32;

/// Requests notification permission (async).
pub extern fn requestNotificationPermissionWasm(callback_id: u32) void;

/// Shows a notification. Returns 1 on success.
pub extern fn showNotificationWasm(
    title_ptr: [*]const u8,
    title_len: usize,
    body_ptr: [*]const u8,
    body_len: usize,
    icon_ptr: [*]const u8,
    icon_len: usize,
    tag_ptr: [*]const u8,
    tag_len: usize,
) u32;

// =============================================================================
// FULLSCREEN
// =============================================================================

/// Requests fullscreen for an element.
pub extern fn requestFullscreenWasm(id_ptr: [*]const u8, id_len: usize) u32;

/// Exits fullscreen mode.
pub extern fn exitFullscreenWasm() u32;

/// Checks if currently in fullscreen.
pub extern fn isFullscreenWasm() u32;

/// Gets the ID of the fullscreen element.
pub extern fn getFullscreenElementIdWasm() [*:0]u8;

/// Registers callback for fullscreen changes.
pub extern fn onFullscreenChangeWasm(callback_id: u32) void;

// =============================================================================
// TEXT SELECTION
// =============================================================================

/// Gets the currently selected text.
pub extern fn getSelectionTextWasm() [*:0]u8;

/// Gets selection range (start, end) for an input element.
pub extern fn getSelectionRangeWasm(id_ptr: [*]const u8, id_len: usize) [*]u32;

/// Sets selection range for an input element.
pub extern fn setSelectionRangeWasm(
    id_ptr: [*]const u8,
    id_len: usize,
    start: u32,
    end: u32,
    direction: u32,
) void;

/// Selects all content in an input element.
pub extern fn selectAllWasm(id_ptr: [*]const u8, id_len: usize) void;

// =============================================================================
// RESIZE OBSERVER
// =============================================================================

/// Creates a resize observer. Returns handle.
pub extern fn createResizeObserverWasm(id: u32, options_ptr: *const Vapor.Kit.ResizeOptions) void;

/// Starts observing an element for resize.
pub extern fn observeResizeWasm(
    id: u32,
    element_ptr: [*]const u8,
    element_len: usize,
    index: u32,
) void;

/// Stops observing an element.
pub extern fn unobserveResizeWasm(handle: u32, element_ptr: [*]const u8, element_len: usize) void;

/// Disconnects observer from all elements.
pub extern fn disconnectResizeObserverWasm(handle: u32) void;

/// Destroys a resize observer.
pub extern fn destroyResizeObserverWasm(handle: u32) void;

// =============================================================================
// MUTATION OBSERVER
// =============================================================================

/// Creates a mutation observer. Returns handle.
pub extern fn createMutationObserverWasm(callback_id: u32) u32;

/// Starts observing an element for mutations.
pub extern fn observeMutationWasm(
    handle: u32,
    element_ptr: [*]const u8,
    element_len: usize,
    child_list: bool,
    attributes: bool,
    character_data: bool,
    subtree: bool,
    attribute_old_value: bool,
    character_data_old_value: bool,
) u32;

/// Disconnects mutation observer.
pub extern fn disconnectMutationObserverWasm(handle: u32) void;

/// Destroys a mutation observer.
pub extern fn destroyMutationObserverWasm(handle: u32) void;

// =============================================================================
// PERFORMANCE TIMING
// =============================================================================

/// Creates a performance mark.
pub extern fn performanceMarkWasm(name_ptr: [*]const u8, name_len: usize) void;

/// Creates a performance measure between two marks.
pub extern fn performanceMeasureWasm(
    name_ptr: [*]const u8,
    name_len: usize,
    start_mark_ptr: [*]const u8,
    start_mark_len: usize,
    end_mark_ptr: [*]const u8,
    end_mark_len: usize,
) u32;

/// Gets performance entries by name as JSON.
pub extern fn performanceGetEntriesByNameWasm(name_ptr: [*]const u8, name_len: usize) [*:0]u8;

/// Clears performance marks.
pub extern fn performanceClearMarksWasm(name_ptr: [*]const u8, name_len: usize) void;

/// Clears performance measures.
pub extern fn performanceClearMeasuresWasm(name_ptr: [*]const u8, name_len: usize) void;

/// Gets high-resolution timestamp.
pub extern fn performanceNowWasm() f64;

// =============================================================================
// INDEXED DB
// =============================================================================

/// Opens an IndexedDB database (async).
pub extern fn idbOpenWasm(
    name_ptr: [*]const u8,
    name_len: usize,
    version: u32,
    callback_id: u32,
    error_callback_id: u32,
) void;

/// Closes an IndexedDB database.
pub extern fn idbCloseWasm(handle: u32) void;

/// Creates an object store.
pub extern fn idbCreateObjectStoreWasm(
    handle: u32,
    name_ptr: [*]const u8,
    name_len: usize,
    key_path_ptr: [*]const u8,
    key_path_len: usize,
    auto_increment: bool,
) u32;

/// Deletes an object store.
pub extern fn idbDeleteObjectStoreWasm(handle: u32, name_ptr: [*]const u8, name_len: usize) u32;

/// Puts a value into an object store.
pub extern fn idbPutWasm(
    handle: u32,
    store_name_ptr: [*]const u8,
    store_name_len: usize,
    key_ptr: [*]const u8,
    key_len: usize,
    value_ptr: [*]const u8,
    value_len: usize,
    callback_id: u32,
) void;

/// Gets a value from an object store.
pub extern fn idbGetWasm(
    handle: u32,
    store_name_ptr: [*]const u8,
    store_name_len: usize,
    key_ptr: [*]const u8,
    key_len: usize,
    callback_id: u32,
) void;

/// Deletes a value from an object store.
pub extern fn idbDeleteWasm(
    handle: u32,
    store_name_ptr: [*]const u8,
    store_name_len: usize,
    key_ptr: [*]const u8,
    key_len: usize,
    callback_id: u32,
) void;

/// Gets all values from an object store.
pub extern fn idbGetAllWasm(
    handle: u32,
    store_name_ptr: [*]const u8,
    store_name_len: usize,
    callback_id: u32,
) void;

/// Clears all values from an object store.
pub extern fn idbClearStoreWasm(
    handle: u32,
    store_name_ptr: [*]const u8,
    store_name_len: usize,
    callback_id: u32,
) void;

/// Deletes an entire database.
pub extern fn idbDeleteDatabaseWasm(
    name_ptr: [*]const u8,
    name_len: usize,
    callback_id: u32,
) void;

// =============================================================================
// ANIMATION FRAME
// =============================================================================

/// Requests an animation frame. Returns frame ID.
pub extern fn requestAnimationFrameWasm(callback_id: u32) u32;

/// Cancels an animation frame request.
pub extern fn cancelAnimationFrameWasm(frame_id: u32) void;

// =============================================================================
// POINTER LOCK
// =============================================================================

/// Requests pointer lock on an element.
pub extern fn requestPointerLockWasm(id_ptr: [*]const u8, id_len: usize) u32;

/// Exits pointer lock.
pub extern fn exitPointerLockWasm() void;

/// Checks if pointer is currently locked.
pub extern fn isPointerLockedWasm() u32;

/// Registers callback for pointer lock changes.
pub extern fn onPointerLockChangeWasm(callback_id: u32) void;

// =============================================================================
// VIBRATION (Mobile)
// =============================================================================

/// Vibrates for specified duration in ms.
pub extern fn vibrateWasm(duration: u32) u32;

/// Vibrates with a pattern.
pub extern fn vibratePatternWasm(pattern_ptr: [*]const u32, pattern_len: usize) u32;

/// Cancels vibration.
pub extern fn vibrateCancelWasm() void;

// =============================================================================
// SCREEN ORIENTATION
// =============================================================================

/// Gets current screen orientation type.
pub extern fn getScreenOrientationWasm() [*:0]u8;

/// Gets current screen orientation angle.
pub extern fn getScreenOrientationAngleWasm() u32;

/// Locks screen to specified orientation (async).
pub extern fn lockScreenOrientationWasm(
    orientation_ptr: [*]const u8,
    orientation_len: usize,
    callback_id: u32,
) void;

/// Unlocks screen orientation.
pub extern fn unlockScreenOrientationWasm() void;

/// Registers callback for orientation changes.
pub extern fn onOrientationChangeWasm(callback_id: u32) void;

// =============================================================================
// BATTERY STATUS
// =============================================================================

/// Gets battery status as JSON (async).
pub extern fn getBatteryStatusWasm(callback_id: u32) void;

// =============================================================================
// SHARE API
// =============================================================================

/// Checks if Web Share API is available.
pub extern fn canShareWasm() u32;

/// Shares content using Web Share API (async).
pub extern fn shareWasm(
    title_ptr: [*]const u8,
    title_len: usize,
    text_ptr: [*]const u8,
    text_len: usize,
    url_ptr: [*]const u8,
    url_len: usize,
    callback_id: u32,
) void;

pub extern fn batchRemoveTombStonesWasm() void;

pub extern fn setAttributeWasm(
    id_ptr: [*]const u8,
    id_len: usize,
    attribute_ptr: [*]const u8,
    attribute_len: usize,
    value_ptr: [*]const u8,
    value_len: usize,
) void;

pub extern fn removeAttributeWasm(
    id_ptr: [*]const u8,
    id_len: usize,
    attribute_ptr: [*]const u8,
    attribute_len: usize,
) void;

pub extern fn runPlaygroundWasm(url_ptr: [*]const u8, url_len: usize) void;

pub extern fn startViewTransitionWasm(callback_id: u32) void;

pub extern fn windowOpenWasm(url_ptr: [*]const u8, url_len: usize) void;
pub extern fn releasePointerCaptureWasm(id_ptr: [*]const u8, id_len: usize, event_id: u32) void;
pub extern fn setPointerCaptureWasm(id_ptr: [*]const u8, id_len: usize, event_id: u32) void;
