//! Raw bindings to browser APIs beyond what rendering needs: canvas, audio,
//! geolocation, IndexedDB, websockets, drag and drop, and more.
//!
//! Their JS lives in the optional runtime file `browser.min.js`. The core
//! runtime loads it automatically, and only when the app's wasm imports one
//! of these functions, so an app that calls none of them never downloads it.
//! Calling one is all it takes.
//!
//! These are thin externs; higher-level Zig APIs can be built on top of them.

// =============================================================================
// Audio
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
// Battery
// =============================================================================

/// Gets battery status as JSON (async).
pub extern fn getBatteryStatusWasm(callback_id: u32) void;

// =============================================================================
// Canvas 2D
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
// Drag and drop
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
// Fullscreen
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
// Geolocation
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
// IndexedDB
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
// Mutation observer
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
// Notifications
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
// Screen orientation
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
// Performance timing
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
// Pointer lock
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
// Text selection
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
// Session storage
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
// Web Share
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

// =============================================================================
// Vibration
// =============================================================================

/// Vibrates for specified duration in ms.
pub extern fn vibrateWasm(duration: u32) u32;

/// Vibrates with a pattern.
pub extern fn vibratePatternWasm(pattern_ptr: [*]const u32, pattern_len: usize) u32;

/// Cancels vibration.
pub extern fn vibrateCancelWasm() void;

// =============================================================================
// WebSocket
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
