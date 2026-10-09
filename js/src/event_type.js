/** DOM event names and the numeric ids wasm uses for them. */
export const EventType = {
  // Mouse events
  none: 0,
  click: 1, // Fired when a pointing device button is clicked.
  dblclick: 2, // Fired when a pointing device button is double-clicked.
  mousedown: 3, // Fired when a pointing device button is pressed.
  mouseup: 4, // Fired when a pointing device button is released.
  mousemove: 5, // Fired when a pointing device is moved.
  mouseover: 6, // Fired when a pointing device is moved onto an element.
  mouseout: 7, // Fired when a pointing device is moved off an element.
  mouseenter: 8, // Similar to mouseover but does not bubble.
  mouseleave: 9, // Similar to mouseout but does not bubble.
  contextmenu: 10, // Fired when the right mouse button is clicked.

  // Keyboard events
  keydown: 11, // Fired when a key is pressed.
  keyup: 12, // Fired when a key is released.
  keypress: 13, // Fired when a key that produces a character value is pressed.

  // Focus events
  focus: 14, // Fired when an element gains focus.
  blur: 15, // Fired when an element loses focus.
  focusin: 16, // Fired when an element is about to receive focus.
  focusout: 17, // Fired when an element is about to lose focus.

  // Form events
  change: 18, // Fired when the value of an element changes.
  input: 19, // Fired every time the value of an element changes.
  submit: 20, // Fired when a form is submitted.
  reset: 21, // Fired when a form is reset.

  // Window events
  resize: 22, // Fired when the window is resized.
  scroll: 23, // Fired when the document view is scrolled.
  wheel: 24, // Fired when the mouse wheel is rotated.

  // Drag & Drop events
  drag: 25, // Fired continuously while an element or text selection is being dragged.
  dragstart: 26, // Fired at the start of a drag operation.
  dragend: 27, // Fired at the end of a drag operation.
  dragover: 28, // Fired when an element is being dragged over a valid drop target.
  dragenter: 29, // Fired when a dragged element enters a valid drop target.
  dragleave: 30, // Fired when a dragged element leaves a valid drop target.
  drop: 31, // Fired when a dragged element is dropped on a valid drop target.

  // Clipboard events
  copy: 32, // Fired when the user initiates a copy action.
  cut: 33, // Fired when the user initiates a cut action.
  paste: 34, // Fired when the user initiates a paste action.

  // Touch events
  touchstart: 35, // Fired when one or more touch points are placed on the touch surface.
  touchmove: 36, // Fired when one or more touch points are moved along the touch surface.
  touchend: 37, // Fired when one or more touch points are removed from the touch surface.
  touchcancel: 38, // Fired when a touch point is disrupted (e.g., by a modal interruption).

  // Pointer events
  pointerover: 39, // Fired when a pointer enters the hit test boundaries of an element.
  pointerenter: 40, // Similar to pointerover but does not bubble.
  pointerdown: 41, // Fired when a pointer becomes active.
  pointermove: 42, // Fired when a pointer changes coordinates.
  pointerup: 43, // Fired when a pointer is no longer active.
  pointercancel: 44, // Fired when a pointer is canceled.
  pointerout: 45, // Fired when a pointer moves out of an element.
  pointerleave: 46, // Similar to pointerout but does not bubble.

  // Document / Media / Error events
  load: 47, // Fired when a resource and its dependent resources have finished loading.
  unload: 48, // Fired when the document is being unloaded.
  abort: 49,
  show: 50,
  close: 51,
  cancel: 52,

  // Media events
  play: 53,
  pause: 54,
  ended: 55,
  volumechange: 56,
  waiting: 57,

  // Progress events
  loadstart: 58,
  progress: 59,
  loadend: 60,

  // Transition & Animation events
  transitionend: 61,
  animationstart: 62,
  animationend: 63,
  animationiteration: 64,
};
