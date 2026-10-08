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
// ANIMATION FRAME
// =============================================================================

/// Requests an animation frame. Returns frame ID.
pub extern fn requestAnimationFrameWasm(callback_id: u32) u32;

/// Cancels an animation frame request.
pub extern fn cancelAnimationFrameWasm(frame_id: u32) void;

// =============================================================================
// SHARE API
// =============================================================================

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
