import { debug } from "./debug.js";
import { safeUrl, BLOCKED_URL } from "./url.js";
/**
 * WASM-JavaScript Bindings
 * Organized by functional domain
 */

import { parseWasmError } from "./formatter.js";
import {
  eventHandlers,
  elementDimensions,
  eventStorage,
  beforeHooksHandlers,
  afterHooksHandlers,
  observers,
  timeouts,
  sockets,
  domNodeRegistry,
  elementEvents,
} from "./maps.js";

import {
  allocString,
  readWasmString,
  rerenderRoute,
  requestRerender,
  styleSheet,
  checkMemoryGrowth,
  allocStringFrame,
  f32View,
} from "./wasi_obj.js";
import { batchRemoveTombStones } from "./wasi_styling.js";

// ============================================================================
// WASM Instance Management
// ============================================================================

export let wasmInstance = null;
let structBridge = undefined;

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

// Define a cache outside the function to store DOM references
export const elementCache = new Map();

// Separate map for resize observers (don't share with IntersectionObservers)
const resizeObservers = new Map();
// Map: observerId -> Map<elementId, callbackId>
const resizeCallbacks = new Map();

export function setWasiInstance(instance) {
  wasmInstance = instance;
}

export function setWasiStructBridge() {
  structBridge = new WasmStructBridge(wasmInstance);
  structBridge.registerSchema(
    "ObserverOptions",
    "getObserverOptionsSchema",
    "getObserverOptionsSchemaLength",
  );
}

// ============================================================================
// Utility Classes
// ============================================================================

/**
 * Performance monitoring for FPS and frame time tracking
 */
export class PerformanceMonitor {
  constructor() {
    this.fps = 0;
    this.frameTime = 0;
    this.frameTimes = [];
    this.maxSamples = 60;
    this.lastFrameTime = performance.now();
    this.startMonitoring();
  }

  startMonitoring() {
    const measure = (currentTime) => {
      const delta = currentTime - this.lastFrameTime;
      this.lastFrameTime = currentTime;

      this.frameTimes.push(delta);
      if (this.frameTimes.length > this.maxSamples) {
        this.frameTimes.shift();
      }

      const avgFrameTime =
        this.frameTimes.reduce((a, b) => a + b, 0) / this.frameTimes.length;
      this.fps = Math.round(1000 / avgFrameTime);
      this.frameTime = Math.round(avgFrameTime * 100) / 100;

      const fpsElement = document.getElementById("fps");
      const frameTimeElement = document.getElementById("frameTime");

      if (fpsElement) fpsElement.textContent = this.fps;
      if (frameTimeElement) frameTimeElement.textContent = this.frameTime;

      requestAnimationFrame(measure);
    };

    requestAnimationFrame(measure);
  }
}

/**
 * Bridge for reading WASM struct schemas
 */
export class WasmStructBridge {
  constructor(wasmInstance) {
    this.wasm = wasmInstance;
    this.schemas = new Map();
  }

  registerSchema(name, getSchemaFn, getSchemaLengthFn) {
    const length = this.wasm[getSchemaLengthFn]();
    const schemaPtr = this.wasm[getSchemaFn]();

    const fields = [];
    const memory = new DataView(this.wasm.memory.buffer);
    const FIELD_DESCRIPTOR_SIZE = 16;

    for (let i = 0; i < length; i++) {
      const offset = schemaPtr + i * FIELD_DESCRIPTOR_SIZE;

      const fieldType = memory.getUint8(offset);
      const fieldOffset = memory.getUint32(offset + 1, true);
      const namePtr = memory.getUint32(offset + 5, true);
      const nameLen = memory.getUint32(offset + 9, true);

      const fieldName = readWasmString(namePtr, nameLen);

      fields.push({
        name: fieldName,
        type: fieldType,
        offset: fieldOffset,
      });
    }

    this.schemas.set(name, fields);
  }

  readField(memory, ptr, fieldType) {
    const FieldType = {
      u8_type: 0,
      i8_type: 1,
      u16_type: 2,
      i16_type: 3,
      u32_type: 4,
      i32_type: 5,
      u64_type: 6,
      i64_type: 7,
      f32_type: 8,
      f64_type: 9,
      bool_type: 10,
      string_type: 11,
    };

    switch (fieldType) {
      case FieldType.u8_type:
        return memory.getUint8(ptr);
      case FieldType.i8_type:
        return memory.getInt8(ptr);
      case FieldType.u16_type:
        return memory.getUint16(ptr, true);
      case FieldType.i16_type:
        return memory.getInt16(ptr, true);
      case FieldType.u32_type:
        return memory.getUint32(ptr, true);
      case FieldType.i32_type:
        return memory.getInt32(ptr, true);
      case FieldType.u64_type:
        return memory.getBigUint64(ptr, true);
      case FieldType.i64_type:
        return memory.getBigInt64(ptr, true);
      case FieldType.f32_type:
        return memory.getFloat32(ptr, true);
      case FieldType.f64_type:
        return memory.getFloat64(ptr, true);
      case FieldType.bool_type:
        return memory.getUint8(ptr) !== 0;
      case FieldType.string_type:
        const strPtr = memory.getUint32(ptr, true);
        const strLen = memory.getUint32(ptr + 4, true);
        return readWasmString(strPtr, strLen);
      default:
        throw new Error(`Unknown field type: ${fieldType}`);
    }
  }
}

/**
 * Dynamic struct reader using field descriptors
 */
export class DynamicStructReader {
  constructor(wasmInstance, memory) {
    this.wasm = wasmInstance;
    this.memory = memory;
    this.decoder = new TextDecoder();
  }

  readStruct(node_ptr, structPtr, fieldCount, getFieldDescriptor) {
    const result = {};

    for (let i = 0; i < fieldCount; i++) {
      let descPtr;
      if (node_ptr === null) {
        descPtr = this.wasm[getFieldDescriptor](i);
      } else {
        descPtr = this.wasm[getFieldDescriptor](node_ptr, i);
      }
      const descriptor = this.readDescriptor(descPtr);
      const fieldName = readWasmString(descriptor.namePtr, descriptor.nameLen);
      let fieldValue;

      if (descriptor.typeId === 7) {
        // Pointer - check for slice pattern
        const view = new DataView(this.memory.buffer, structPtr);
        const ptr = view.getUint32(descriptor.offset, true);

        if (i + 1 < fieldCount) {
          const nextDescPtr = this.wasm[getFieldDescriptor](node_ptr, i + 1);
          const nextDescriptor = this.readDescriptor(nextDescPtr);
          const len = this.readField(
            structPtr + nextDescriptor.offset,
            nextDescriptor.typeId,
            nextDescriptor.size,
            nextDescriptor.canBeNull,
          );
          if (len === 0) {
            fieldValue = "";
          } else {
            fieldValue = readWasmString(ptr, len);
          }
          i++;
        } else {
          fieldValue = ptr;
        }
      } else {
        fieldValue = this.readField(
          structPtr + descriptor.offset,
          descriptor.typeId,
          descriptor.size,
          descriptor.canBeNull,
        );
        if (descriptor.typeId === 3 && fieldValue !== null) {
          const num = fieldValue;
          fieldValue = Number(num.toFixed(2));
        }
      }
      result[fieldName.replace("_ptr", "")] = fieldValue;
    }
    return result;
  }

  readDescriptor(ptr) {
    const view = new DataView(this.memory.buffer, ptr);
    return {
      namePtr: view.getUint32(0, true),
      nameLen: view.getUint32(4, true),
      offset: view.getUint32(8, true),
      typeId: view.getUint8(12),
      size: view.getUint32(16, true),
      canBeNull: view.getUint32(20, true),
    };
  }

  readField(ptr, typeId, size, canBeNull) {
    const view = new DataView(this.memory.buffer, ptr);

    if (canBeNull) {
      const isNull = view.getUint32(0, true);
      if (isNull === 0) return null;
    }

    switch (typeId) {
      case 1: // unsigned int
        return size === 1
          ? view.getUint8(0)
          : size === 2
            ? view.getUint16(0, true)
            : size === 4
              ? view.getUint32(0, true)
              : view.getBigUint64(0, true);
      case 2: // signed int
        return size === 1
          ? view.getInt8(0)
          : size === 2
            ? view.getInt16(0, true)
            : size === 4
              ? view.getInt32(0, true)
              : size === 8
                ? view.getInt32(0, true)
                : view.getBigInt64(0, true);
      case 3: // float
        return size === 4 ? view.getFloat32(0, true) : view.getFloat64(0, true);
      case 4: // bool
        return Boolean(view.getUint8(0));
      case 5: // string (fixed-size u8 array)
        return readWasmString(ptr, size);
      case 7: // pointer
        return;
      case 8: // enum
        return view.getUint8(0, true);
      default:
        return null;
    }
  }
}

/**
 * Builds JS objects to pass to WASM
 */
export class WasmObjectBuilder {
  constructor(wasmInstance, memory) {
    this.wasm = wasmInstance;
    this.memory = memory;
  }

  passObject(obj) {
    const handle = this.wasm.startObject();

    for (const [key, value] of Object.entries(obj)) {
      const keyPtr = allocStringFrame(key);

      switch (typeof value) {
        case "string":
          const strPtr = allocStringFrame(value);
          this.wasm.addStringField(handle, keyPtr, strPtr);
          break;
        case "number":
          if (Number.isInteger(value)) {
            this.wasm.addIntField(handle, keyPtr, value);
          } else {
            this.wasm.addFloatField(handle, keyPtr, value);
          }
          break;
        case "boolean":
          this.wasm.addBoolField(handle, keyPtr, value ? 1 : 0);
          break;
      }
    }

    return handle;
  }
}

// ============================================================================
// Helper Functions
// ============================================================================

export function requireWasm() {
  if (!wasmInstance) {
    console.error("WASM instance not initialized");
    return false;
  }
  return true;
}

function getElement(idPtr, idLen) {
  const id = readWasmString(idPtr, idLen);
  return [id, document.getElementById(id)];
}

// ============================================================================
// ENV BINDINGS - Organized by Domain
// ============================================================================

export const env = {
  // ==========================================================================
  // Core / System
  // ==========================================================================

  jsPanic: (ptr, len) => {
    if (!requireWasm()) return;
    const msg = new TextDecoder().decode(
      new Uint8Array(wasmInstance.memory.buffer, ptr, len),
    );
    console.error("ZIG PANIC: " + msg);
    throw new Error(msg);
  },

  requestRerenderWasm: () => {
    requestRerender();
  },

  batchRemoveTombStonesWasm: () => {
    batchRemoveTombStones();
  },

  performance_now: () => performance.now(),

  checkMemoryGrowthWasm: () => {
    checkMemoryGrowth();
    return;
  },

  trackAlloc: () => {
    const err = new Error();
    Error.captureStackTrace(err, wasmInstance.trackAlloc);
    console.log(err.stack);
  },

  // ==========================================================================
  // Console / Debugging
  // ==========================================================================

  // consoleLogWasm: (ptr, len) => {
  //   if (!requireWasm()) return;
  //   const memory = new Uint8Array(wasmInstance.memory.buffer);
  //   const str = new TextDecoder().decode(memory.subarray(ptr, ptr + len));
  //   console.log(str);
  // },

  consoleLogWasm: (level, msgPtr, msgLen, stylePtr, styleLen) => {
    const consoleMethods = ["error", "warn", "info", "debug"];
    const msg = readWasmString(msgPtr, msgLen);
    const style = readWasmString(stylePtr, styleLen);
    const method = consoleMethods[level] || "log";
    console.log(msg, style, method);
    // console[method](msg, style);
  },

  consoleLogColoredWasm: (
    ptr,
    len,
    stylePtr1,
    styleLen1,
    stylePtr2,
    styleLen2,
  ) => {
    if (!requireWasm()) return;
    const str = readWasmString(ptr, len);
    const style1 = readWasmString(stylePtr1, styleLen1);
    const style2 = readWasmString(stylePtr2, styleLen2);
    console.log(str, style1, style2);
  },

  consoleLogColoredWarnWasm: (
    ptr,
    len,
    stylePtr1,
    styleLen1,
    stylePtr2,
    styleLen2,
  ) => {
    if (!requireWasm()) return;
    const str = readWasmString(ptr, len);
    const style1 = readWasmString(stylePtr1, styleLen1);
    const style2 = readWasmString(stylePtr2, styleLen2);
    console.warn(str, style1, style2);
  },

  consoleLogColoredErrorWasm: (
    ptr,
    len,
    stylePtr1,
    styleLen1,
    stylePtr2,
    styleLen2,
  ) => {
    if (!requireWasm()) return;
    const str = readWasmString(ptr, len);
    const style1 = readWasmString(stylePtr1, styleLen1);
    const style2 = readWasmString(stylePtr2, styleLen2);
    console.log(str, style1, style2);
  },

  alertWasm: (ptr, len) => {
    const memory = new Uint8Array(wasmInstance.memory.buffer);
    const str = new TextDecoder().decode(memory.subarray(ptr, ptr + len));
    alert(str);
  },

  // ==========================================================================
  // Event Handling - Document Level
  // ==========================================================================

  createEventListenerGlobal: (ptr, len, onid) => {
    if (!requireWasm()) return;
    const callback_id = onid >>> 0;
    const event_type = readWasmString(ptr, len);
    let eventData = eventHandlers.get("vapor-document");

    const handler = (event) => {
      try {
        eventStorage[callback_id] = event;
        eventStorage[callback_id] = event;
        wasmInstance.dispatchEvent(EventType[event_type], callback_id);
      } catch (e) {
        if (e instanceof WebAssembly.RuntimeError) {
          const parsed = parseWasmError(e);
          const stringified = JSON.stringify(parsed);
          const errorPtr = allocStringFrame(stringified);
          wasmInstance.recordState(errorPtr, null);
        }
        throw e;
      }
    };

    if (eventData === undefined) {
      eventData = {};
    }
    eventData[event_type] = handler;
    document.addEventListener(event_type, handler);
    eventHandlers.set("vapor-document", eventData);
  },

  createEventListener: (ptr, len, onid) => {
    if (!requireWasm()) return;
    const event_id = onid >>> 0;
    const event_type = readWasmString(ptr, len);
    let eventData = eventHandlers.get("vapor-document");

    const handler = (event) => {
      eventStorage[event_id] = event;
      try {
        wasmInstance.eventCallback(event_id);
      } catch (e) {
        if (e instanceof WebAssembly.RuntimeError) {
          const parsed = parseWasmError(e);
          const stringified = JSON.stringify(parsed);
          const errorPtr = allocStringFrame(stringified);
          wasmInstance.recordState(errorPtr, null);
        }
        throw e;
      }
    };

    if (eventData === undefined) {
      eventData = {};
    }
    eventData[event_type] = handler;
    document.addEventListener(event_type, handler);
    eventHandlers.set("vapor-document", eventData);
  },

  createEventListenerCtx: (ptr, len, onid) => {
    if (!requireWasm()) return;
    const event_id = onid >>> 0;
    const event_type = readWasmString(ptr, len);
    let eventData = eventHandlers.get("vapor-document");

    const handler = (event) => {
      eventStorage[event_id] = event;
      wasmInstance.eventInstCallback(event_id);
    };

    if (eventData === undefined) {
      eventData = {};
    }
    eventData[event_type] = handler;

    document.addEventListener(event_type, handler);
    eventHandlers.set("vapor-document", eventData);
  },

  removeEventListener: (ptr, len, onid) => {
    if (!requireWasm()) return;
    const eventType = readWasmString(ptr, len);
    const eventData = eventHandlers.get("vapor-document");
    if (!eventData) return;

    const handler = eventData[eventType];
    if (handler) {
      document.removeEventListener(eventType, handler);
      delete eventData[eventType];

      if (Object.keys(eventData).length === 0) {
        eventHandlers.delete("vapor-document");
      }
    }
  },

  setPointerCaptureWasm: (idPtr, idLen, onid) => {
    if (!requireWasm()) return;
    const eventId = onid >>> 0;
    const event = eventStorage[eventId];
    if (!event) {
      console.error("Event not found");
      return;
    }
    const [elementId, element] = getElement(idPtr, idLen);
    element.setPointerCapture(event.pointerId);
  },

  releasePointerCaptureWasm: (idPtr, idLen, onid) => {
    if (!requireWasm()) return;
    const eventId = onid >>> 0;
    const event = eventStorage[eventId];
    const [elementId, element] = getElement(idPtr, idLen);
    if (!event) {
      console.error("Event not found", element, eventId, elementId);
      return;
    }
    element.releasePointerCapture(event.pointerId);
  },

  // ==========================================================================
  // Event Handling - Element Level
  // ==========================================================================
  // createElementEventListener: (idPtr, idLen, ptr, len, onid) => {
  //   if (!requireWasm()) return;
  //
  //   const [elementId, element] = getElement(idPtr, idLen);
  //   if (element === null) {
  //     console.log("Could not attach listener element is Null", elementId);
  //     return;
  //   }
  //
  //   let event_type = readWasmString(ptr, len);
  //   if (event_type === "rightclick") {
  //     event_type = "contextmenu";
  //   }
  //
  //   let eventData = eventHandlers.get(elementId);
  //
  //   if (!eventData) {
  //     eventData = Object.create(null);
  //     eventHandlers.set(elementId, eventData);
  //   }
  //
  //   if (eventData[event_type]) {
  //     return;
  //   }
  //
  //   const handler = (event) => {
  //     const currentId = element.id;
  //     const nodeInfo = domNodeRegistry.get(currentId);
  //
  //     if (nodeInfo === undefined) {
  //       console.log("Could Not find domNode", element, currentId);
  //       return;
  //     }
  //
  //     const callback_id = onid >>> 0;
  //     eventStorage[callback_id] = event;
  //
  //     wasmInstance.dispatchNodeEvent(
  //       nodeInfo.node_ptr,
  //       EventType[event_type],
  //       callback_id,
  //     );
  //   };
  //
  //   eventData[event_type] = handler;
  //   element.addEventListener(event_type, handler);
  // },
  createElementEventListener: (idPtr, idLen, ptr, len, onid) => {
    if (!requireWasm()) return;
    const [elementId, element] = getElement(idPtr, idLen);
    if (element === null) {
      debug("Could not attach listener element is Null", elementId);
      return;
    }

    const callback_id = onid >>> 0;
    let event_type = readWasmString(ptr, len);
    const eventData = eventHandlers.get(elementId);

    if (event_type === "rightclick") {
      event_type = "contextmenu";
    }

    const handler = (event) => {
      const currentId = element.id;
      const nodeInfo = domNodeRegistry.get(currentId);
      if (nodeInfo === undefined) {
        debug("Could Not find domNode", element, currentId);
        return;
      }

      eventStorage[callback_id] = event;
      wasmInstance.dispatchNodeEvent(
        nodeInfo.node_ptr,
        EventType[event_type],
        callback_id,
      );
      return false;
    };

    if (!eventData) {
      eventHandlers.set(elementId, { [event_type]: handler });
      element.addEventListener(event_type, handler);
    } else if (!eventData[event_type]) {
      eventData[event_type] = handler;
      element.addEventListener(event_type, handler);
    }
  },

  // createElementEventListener: (idPtr, idLen, ptr, len, onid) => {
  //   if (!requireWasm()) return;
  //   const [elementId, element] = getElement(idPtr, idLen);
  //   if (element === null) {
  //     console.log("Could not attach listener element is Null", elementId);
  //     return;
  //   }
  //
  //   const callback_id = onid >>> 0;
  //   let event_type = readWasmString(ptr, len);
  //   const eventData = eventHandlers.get(elementId);
  //
  //   if (event_type === "rightclick") {
  //     event_type = "contextmenu";
  //     // return;
  //   }
  //
  //   const handler = (event) => {
  //     if (event_type === "pointerdown") {
  //       element.setPointerCapture(event.pointerId);
  //     }
  //     eventStorage[callback_id] = event;
  //
  //     if (event_type === "contextmenu") {
  //       console.log(event);
  //       console.log("Right Click", EventType[event_type]);
  //       console.log(callback_id, elementId);
  //     }
  //
  //     const nodeInfo = domNodeRegistry.get(elementId);
  //     eventStorage[callback_id] = event;
  //     wasmInstance.dispatchNodeEvent(
  //       nodeInfo.node_ptr,
  //       EventType[event_type],
  //       callback_id,
  //     );
  //     return false;
  //   };
  //
  //   if (eventData === undefined) {
  //     const newEventData = {};
  //     newEventData[event_type] = handler;
  //     element.addEventListener(event_type, handler);
  //     eventHandlers.set(elementId, newEventData);
  //   } else {
  //     if (eventData[event_type] === undefined) {
  //       eventData[event_type] = handler;
  //       element.addEventListener(event_type, handler);
  //       eventHandlers.set(elementId, eventData);
  //     }
  //   }
  // },

  requestAnimationFrameWasm: (onid) => {
    if (!requireWasm()) return 0;
    const handle = requestAnimationFrame(() => {
      wasmInstance.callAnimationFrameCallback(onid);
    });
    return handle;
  },

  cancelAnimationFrameWasm: (handle) => {
    if (!requireWasm()) return;
    if (handle === 0) return;
    cancelAnimationFrame(handle);
  },

  createElementEventInstListener: (idPtr, idLen, ptr, len, onid) => {
    if (!requireWasm()) return;

    const elementId = readWasmString(idPtr, idLen);

    const element = document.getElementById(elementId);
    if (element === null) {
      console.warn(
        "Element is not committed yet, please attach listeners after mounting to the DOM",
      );
      return;
    }

    const callback_id = onid >>> 0;
    const event_type = readWasmString(ptr, len);
    let eventData = eventHandlers.get(elementId);

    const handler = (event) => {
      eventStorage[callback_id] = event;
      wasmInstance.eventInstCallback(callback_id);
    };

    if (eventData === undefined) {
      eventData = {};
      eventData[event_type] = handler;
      element.addEventListener(event_type, handler);
    } else {
      if (eventData[event_type] === undefined) {
        eventData[event_type] = handler;
        element.addEventListener(event_type, handler);
      }
    }
    eventHandlers.set(elementId, eventData);
  },

  removeElementEventListener: (idPtr, idLen, ptr, len, onid) => {
    if (!requireWasm()) return;
    const memory = new Uint8Array(wasmInstance.memory.buffer);

    const elementId = new TextDecoder().decode(
      memory.subarray(idPtr, idPtr + idLen),
    );
    const element = document.getElementById(elementId);

    const eventType = readWasmString(ptr, len);
    const eventData = eventHandlers.get(elementId);
    if (!eventData) return;

    const handler = eventData[eventType];
    if (handler) {
      element.removeEventListener(eventType, handler);
      delete eventData[eventType];

      if (Object.keys(eventData).length === 0) {
        eventHandlers.delete(elementId);
      }
    }
  },

  // ==========================================================================
  // Event Data Extraction
  // ==========================================================================

  getEventDataWasm: (id, ptr, len) => {
    if (!requireWasm()) return;
    const memory = new Uint8Array(wasmInstance.memory.buffer);
    const key = new TextDecoder().decode(memory.subarray(ptr, ptr + len));
    id = id >>> 0;
    const event = eventStorage[id];
    const keyValue = event[key];
    return allocStringFrame(keyValue);
  },

  getEventDataInputWasm: (id) => {
    if (!requireWasm()) return;
    id = id >>> 0;
    const event = eventStorage[id];
    const value = event.target.value;
    return allocStringFrame(value);
  },

  getEventDataNumberWasm: (onid, ptr, len) => {
    if (!requireWasm()) return;
    const event_id = onid >>> 0;
    const key = readWasmString(ptr, len);

    const event = eventStorage[event_id];
    if (event === undefined) {
      console.warn(
        "Event Not found",
        Object.keys(eventStorage).slice(),
        event_id,
      );
      return;
    }
    const keyValue = event.target?.[key] ?? event[key];
    return keyValue;
  },

  eventPreventDefault: (onid, ptr, len) => {
    if (!requireWasm()) return;
    const eventId = onid >>> 0;
    const event = eventStorage[eventId];
    if (!event) {
      console.error("Event not found");
      return;
    }
    event.preventDefault();
  },

  eventStopPropagation: (onid) => {
    if (!requireWasm()) return;
    const eventId = onid >>> 0;
    const event = eventStorage[eventId];
    if (!event) {
      console.error("Event not found");
      return;
    }
    event.stopPropagation();
  },

  formDataWasm: (id) => {
    if (!requireWasm()) return;
    id = id >>> 0;
    const event = eventStorage[id];
    const formData = new FormData(event.target);
    // Option 1: Log all entries
    const data = Object.fromEntries(formData.entries());
    const builder = new WasmObjectBuilder(wasmInstance, wasmInstance.memory);
    const handle = builder.passObject(data);

    return handle;
  },

  getElementData: (id, ptr, len) => {
    if (!requireWasm()) return;
    const memory = new Uint8Array(wasmInstance.memory.buffer);
    const key = new TextDecoder().decode(memory.subarray(ptr, ptr + len));
    const event = eventStorage[id];
    const keyValue = event[key];
    return allocStringFrame(keyValue);
  },

  // ==========================================================================
  // DOM Element Creation & Manipulation
  // ==========================================================================

  createElement: (idPtr, idLen, elementType, btnId, textPtr, textLen) => {
    if (!requireWasm()) return;
    const memory = new Uint8Array(wasmInstance.memory.buffer);
    const id = new TextDecoder().decode(memory.subarray(idPtr, idPtr + idLen));
    const text = new TextDecoder().decode(
      memory.subarray(textPtr, textPtr + textLen),
    );

    const elementDetails = { id, elementType, btnId, text };
    debug(elementDetails);
  },

  removeFromParent: (idPtr, idLen) => {
    if (!requireWasm()) return;
    const memory = new Uint8Array(wasmInstance.memory.buffer);
    const id = new TextDecoder().decode(memory.subarray(idPtr, idPtr + idLen));
    const element = document.getElementById(id);
    if (element === null) {
      debug("Is Null");
      return;
    }
    const parent = element.parentNode;
    parent.removeChild(element);
  },

  addChild: (idPtr, idLen, idChildPtr, idChildLen) => {
    if (!requireWasm()) return;
    const memory = new Uint8Array(wasmInstance.memory.buffer);
    const id = new TextDecoder().decode(memory.subarray(idPtr, idPtr + idLen));
    const element = document.getElementById(id);
    if (element === null) {
      debug("Is Null");
      return;
    }
    const childId = new TextDecoder().decode(
      memory.subarray(idChildPtr, idChildPtr + idChildLen),
    );
    const childElement = document.getElementById(childId);
    if (childElement === null) {
      debug("Is Null");
      return;
    }
    element.appendChild(childElement);
  },

  // ==========================================================================
  // DOM Element Attributes & Properties
  // ==========================================================================

  mutateDomElementWasm: (idPtr, idLen, attributePtr, attributeLen, value) => {
    // We removed requestAnimationFrame, this is a blocking call which caaused lag in the scroll hover for the dialog combobox
    // basically thr scroll would happen in one frame nthe upate background in another frame causing a lag
    if (!requireWasm()) return;
    const id = readWasmString(idPtr, idLen);
    const attribute = readWasmString(attributePtr, attributeLen);
    let element = elementCache.get(id);
    if (!element) {
      element = document.getElementById(id);
      if (element) elementCache.set(id, element);
      else return;
    }
    element[attribute] = value;
  },

  mutateDomElementI32Wasm: (
    idPtr,
    idLen,
    attributePtr,
    attributeLen,
    value,
  ) => {
    if (!requireWasm()) return;
    const id = readWasmString(idPtr, idLen);
    const attribute = readWasmString(attributePtr, attributeLen);
    const element = document.getElementById(id);
    if (element === null) {
      console.warn("Cannot Set Attribute, Element Is Null");
      return;
    }
    element[attribute] = value;
  },

  mutateDomElementF32Wasm: (
    idPtr,
    idLen,
    attributePtr,
    attributeLen,
    value,
  ) => {
    if (!requireWasm()) return;
    const id = readWasmString(idPtr, idLen);
    const attribute = readWasmString(attributePtr, attributeLen);
    const element = document.getElementById(id);
    if (element === null) {
      console.warn("Cannot Set Attribute, Element Is Null");
      return;
    }
    element[attribute] = value;
  },

  mutateDomElementStringWasm: (
    idPtr,
    idLen,
    attributePtr,
    attributeLen,
    valuePtr,
    valueLen,
  ) => {
    if (!requireWasm()) return;
    const id = readWasmString(idPtr, idLen);
    const attribute = readWasmString(attributePtr, attributeLen);
    const value = readWasmString(valuePtr, valueLen);
    const element = document.getElementById(id);
    if (element === null) {
      console.warn("Cannot Set Attribute, Element: ", id, "is Not in DOM");
      return;
    }
    element[attribute] = value;
  },

  getAttributeWasmNumber: (ptr, len, attributePtr, attributeLen) => {
    if (!requireWasm()) return;
    const id = readWasmString(ptr, len);
    const attribute = readWasmString(attributePtr, attributeLen);
    const element = document.getElementById(id);
    const value = element[attribute];
    return value;
  },

  // ==========================================================================
  // DOM Styling
  // ==========================================================================

  mutateDomElementStyleWasm: (
    idPtr,
    idLen,
    attributePtr,
    attributeLen,
    value,
  ) => {
    requestAnimationFrame(() => {
      if (!requireWasm()) return;
      const memory = new Uint8Array(wasmInstance.memory.buffer);
      const id = new TextDecoder().decode(
        memory.subarray(idPtr, idPtr + idLen),
      );
      const attribute = new TextDecoder().decode(
        memory.subarray(attributePtr, attributePtr + attributeLen),
      );
      const element = document.getElementById(id);
      if (element === null) {
        debug("Is Null");
        return;
      }

      debug("element", element, attribute, value);
      if (attribute === "top" || attribute === "left") {
        element.style[attribute] = `${value}px`;
      } else {
        element.style[attribute] = value;
      }
    });
  },

  mutateDomElementStyleStringWasm: (
    idPtr,
    idLen,
    attributePtr,
    attributeLen,
    valuePtr,
    valueLen,
  ) => {
    if (!requireWasm()) return;
    const id = readWasmString(idPtr, idLen);
    const attribute = readWasmString(attributePtr, attributeLen);
    const value = readWasmString(valuePtr, valueLen);

    const element = document.getElementById(id);
    if (element === null) {
      debug("Is Null");
      return;
    }
    element.style[attribute] = value;
  },

  // ... inside your imports object ...
  translate3dWasm: (idPtr, idLen, x, y, z) => {
    const id = readWasmString(idPtr, idLen);

    let element = elementCache.get(id);
    if (!element) {
      element = document.getElementById(id);
      if (element) elementCache.set(id, element);
      else return;
    }

    // Construct the string in JS (Much faster than decoding from Wasm)
    // Using translate3d forces GPU acceleration
    element.style.transform = `translate3d(${x}px, ${y}px, ${z}px)`;
  },

  // ==========================================================================
  // CSS Classes
  // ==========================================================================

  addClass: (idPtr, idLen, idClassPtr, idClassLen) => {
    if (!requireWasm()) return;
    const memory = new Uint8Array(wasmInstance.memory.buffer);
    const id = new TextDecoder().decode(memory.subarray(idPtr, idPtr + idLen));
    const element = document.getElementById(id);
    if (element === null) {
      debug("Is Null");
      return;
    }
    const classId = new TextDecoder().decode(
      memory.subarray(idClassPtr, idClassPtr + idClassLen),
    );
    element.classList.add(classId);
  },

  removeClass: (idPtr, idLen, idClassPtr, idClassLen) => {
    if (!requireWasm()) return;
    const memory = new Uint8Array(wasmInstance.memory.buffer);
    const id = new TextDecoder().decode(memory.subarray(idPtr, idPtr + idLen));
    const element = document.getElementById(id);
    if (element === null) {
      debug("Is Null");
      return;
    }
    const classId = new TextDecoder().decode(
      memory.subarray(idClassPtr, idClassPtr + idClassLen),
    );
    element.classList.remove(classId);
  },

  createClass: (classPtr, classLen) => {
    if (!requireWasm()) return;
    const memory = new Uint8Array(wasmInstance.memory.buffer);
    const classStyle = new TextDecoder().decode(
      memory.subarray(classPtr, classPtr + classLen),
    );
    const newIndex = styleSheet.cssRules.length;
    styleSheet.insertRule(`${classStyle}`, newIndex);
  },

  toggleThemeWasm: () => {
    const body = document.documentElement;
    const currentTheme = body.getAttribute("data-theme");

    if (currentTheme === "dark") {
      body.removeAttribute("data-theme");
      localStorage.setItem("theme", "light");
    } else {
      body.setAttribute("data-theme", "dark");
      localStorage.setItem("theme", "dark");
    }
  },

  // ==========================================================================
  // Element Dimensions & Position
  // ==========================================================================

  getBoundingClientRectWasm: (idPtr, idLen) => {
    if (!requireWasm()) return 0;

    // Read the id BEFORE allocating (allocate can detach the buffer).
    const elementId = readWasmString(idPtr, idLen);

    const element = document.getElementById(elementId);
    if (!element) {
      console.error("Element not found", elementId);
      return 0;
    }

    // 6 floats * 4 bytes each
    const ptr = wasmInstance.allocate(6 * 4);

    // Re-fetch the buffer AFTER allocate — it may have been detached/replaced.
    const bounds = f32View(ptr, 6);

    try {
      const r = element.getBoundingClientRect();
      bounds[0] = r.top;
      bounds[1] = r.left;
      bounds[2] = r.right;
      bounds[3] = r.bottom;
      bounds[4] = r.width;
      bounds[5] = r.height;
      return ptr;
    } catch (e) {
      console.error("Error getting element bounds", e, elementId);
      return 0;
    }
  },

  getOffsetsWasm: (idPtr, idLen) => {
    if (!requireWasm()) return;
    const memory = new Uint8Array(wasmInstance.memory.buffer);
    const id = readWasmString(idPtr, idLen);
    const element = document.getElementById(id);

    if (!element) {
      console.error(`Element with id ${id} not found`);
      return 0;
    }

    const currentTime = performance.now();
    const cachedDimensions = elementDimensions.get(id);

    if (
      cachedDimensions &&
      currentTime - cachedDimensions.lastUpdateTime < 16
    ) {
      const ptr = wasmInstance.allocate(6);
      const bounds = new Float32Array(memory.buffer, ptr, 6);
      bounds[0] = cachedDimensions.offsetTop;
      bounds[1] = cachedDimensions.offsetLeft;
      bounds[2] = cachedDimensions.offsetRight;
      bounds[3] = cachedDimensions.offsetBottom;
      bounds[4] = cachedDimensions.offsetWidth;
      bounds[5] = cachedDimensions.offsetHeight;
      return ptr;
    }

    const dimensions = {
      offsetTop: element.offsetTop,
      offsetLeft: element.offsetLeft,
      offsetRight: element.offsetLeft + element.offsetWidth,
      offsetBottom: element.offsetTop + element.offsetHeight,
      offsetWidth: element.offsetWidth,
      offsetHeight: element.offsetHeight,
      lastUpdateTime: currentTime,
    };

    elementDimensions.set(id, dimensions);

    const ptr = wasmInstance.allocate(6);
    const bounds = new Float32Array(memory.buffer, ptr, 6);
    bounds[0] = dimensions.offsetTop;
    bounds[1] = dimensions.offsetLeft;
    bounds[2] = dimensions.offsetRight;
    bounds[3] = dimensions.offsetBottom;
    bounds[4] = dimensions.offsetWidth;
    bounds[5] = dimensions.offsetHeight;

    return ptr;
  },

  getClientPos: (idPtr, idLen) => {
    requestAnimationFrame(() => {
      if (!requireWasm()) return;
      const memory = new Uint8Array(wasmInstance.memory.buffer);
      const elementId = new TextDecoder().decode(
        memory.subarray(idPtr, idPtr + idLen),
      );

      const ptr = wasmInstance.allocate(6);
      const bounds = new Float32Array(memory.buffer, ptr, 6);

      const element = document.getElementById(elementId);
      const rectBounds = element.getBoundingClientRect();
      bounds[0] = rectBounds.top;
      bounds[1] = rectBounds.left;
      bounds[2] = rectBounds.right;
      bounds[3] = rectBounds.bottom;
      bounds[4] = rectBounds.width;
      bounds[5] = rectBounds.height;
      return ptr;
    });
  },

  getElementUnderMouse: (x, y) => {
    const element = document.elementFromPoint(x, y);
    if (element === null) {
      return 0;
    }
    const ptr = allocStringFrame(element.id);
    return ptr;
  },

  // ==========================================================================
  // Element Focus & Interactions
  // ==========================================================================

  elementFocusWasm: (idPtr, idLen) => {
    requestAnimationFrame(() => {
      if (!requireWasm()) return;
      const elementId = readWasmString(idPtr, idLen);
      const element = document.getElementById(elementId);
      if (element) {
        element.focus();
        return;
      }
      debug("Element is null, could not add focus", elementId);
    });
  },

  elementFocusedWasm: (idPtr, idLen) => {
    if (!requireWasm()) return;
    const elementId = readWasmString(idPtr, idLen);
    const element = document.getElementById(elementId);
    if (element) {
      const isFocused = document.activeElement === element;
      return isFocused;
    }
    debug("Element is null, could not add focus", elementId);
  },

  callClickWASM: (idPtr, idLen) => {
    if (!requireWasm()) return;
    const id = readWasmString(idPtr, idLen);
    const element = document.getElementById(id);
    if (element === null) {
      debug("Is Null");
      return;
    }
    debug(element);
    element.click();
  },

  // ==========================================================================
  // Input Elements
  // ==========================================================================

  getInputValueWasm: (ptr, len) => {
    if (!requireWasm()) return;
    const memory = new Uint8Array(wasmInstance.memory.buffer);
    const id = new TextDecoder().decode(memory.subarray(ptr, ptr + len));
    const element = document.getElementById(id);
    const value = element.value;
    return allocStringFrame(value);
  },

  setInputValueWasm: (ptr, len, textPtr, textLen) => {
    if (!requireWasm()) return;
    const id = readWasmString(ptr, len);
    const text = readWasmString(textPtr, textLen);
    const element = document.getElementById(id);
    element.value = text;
  },

  setCursorPositionWasm: (idPtr, idLen, pos) => {
    if (!requireWasm()) return;
    const id = readWasmString(idPtr, idLen);
    const element = document.getElementById(id);
    if (element === null) {
      debug("Is Null");
      return;
    }
    element.setSelectionRange(pos, pos);
  },

  replaceRangeWasm: (idPtr, idLen, start, end, textPtr, textLen) => {
    const id = readWasmString(idPtr >>> 0, idLen);
    const element = document.getElementById(id);
    if (!element) return;

    element.focus();
    element.selectionStart = start;
    element.selectionEnd = end;
    document.execCommand(
      "insertText",
      false,
      readWasmString(textPtr >>> 0, textLen),
    );
  },

  selectionWasm: (idPtr, idLen) => {
    const id = readWasmString(idPtr >>> 0, idLen);
    const element = document.getElementById(id);
    if (element === null) {
      debug("Is Null");
      return;
    }
    const ptr = wasmInstance.allocateU32(2);
    const selection = new Uint32Array(wasmInstance.memory.buffer, ptr, 6);
    selection[0] = element.selectionStart;
    selection[1] = element.selectionEnd;
    return ptr;
  },

  // ==========================================================================
  // Dialog Elements
  // ==========================================================================

  showDialog: (idPtr, idLen) => {
    requestAnimationFrame(() => {
      if (!requireWasm()) return;
      const memory = new Uint8Array(wasmInstance.memory.buffer);
      const id = new TextDecoder().decode(
        memory.subarray(idPtr, idPtr + idLen),
      );
      const dialog = document.getElementById(id);
      if (dialog === null) {
        debug("Is Null");
        return;
      }
      dialog.showModal();
    });
  },

  closeDialog: (idPtr, idLen) => {
    requestAnimationFrame(() => {
      if (!requireWasm()) return;
      const memory = new Uint8Array(wasmInstance.memory.buffer);
      const id = new TextDecoder().decode(
        memory.subarray(idPtr, idPtr + idLen),
      );
      const dialog = document.getElementById(id);
      if (dialog === null) {
        debug("Is Null");
        return;
      }
      dialog.close();
    });
  },

  // ==========================================================================
  // Debug Highlighting
  // ==========================================================================

  highlightTargetNode: (ptr, len, type) => {
    if (!requireWasm()) return;

    const target_id = readWasmString(ptr, len);
    const element = document.getElementById(target_id);
    if (!element) {
      console.warn(`Element with id "${target_id}" not found`);
      return;
    }

    const existingHighlight = document.getElementById("highlight-overlay");
    if (existingHighlight) {
      existingHighlight.remove();
    }

    const rect = element.getBoundingClientRect();

    const highlight = document.createElement("div");
    highlight.className = "highlight-overlay";
    highlight.style.position = "absolute";
    highlight.style.top = `${rect.top + window.scrollY - 4}px`;
    highlight.style.left = `${rect.left + window.scrollX - 4}px`;
    highlight.style.width = `${rect.width + 8}px`;
    highlight.style.height = `${rect.height + 8}px`;
    highlight.style.backgroundColor =
      type === 0 ? "rgba(255, 165, 0, 0.35)" : "rgba(255, 0, 0, 0.35)";
    highlight.style.outline =
      type === 0 ? "solid 2px #FF9100" : "solid 2px #ff0000";
    highlight.style.pointerEvents = "none";
    highlight.style.zIndex = "9999";

    document.body.appendChild(highlight);
  },

  highlightHoverTargetNode: (ptr, len, type) => {
    if (!requireWasm()) return;

    const target_id = readWasmString(ptr, len);
    const element = document.getElementById(target_id);
    if (!element) {
      console.warn(`Element with id "${target_id}" not found`);
      return;
    }

    const existingHighlight = document.getElementById("highlight-overlay");
    if (existingHighlight) {
      existingHighlight.remove();
    }

    const rect = element.getBoundingClientRect();

    const highlight = document.createElement("div");
    highlight.className = "highlight-hover-overlay";
    highlight.style.position = "absolute";
    highlight.style.top = `${rect.top + window.scrollY - 4}px`;
    highlight.style.left = `${rect.left + window.scrollX - 4}px`;
    highlight.style.width = `${rect.width + 8}px`;
    highlight.style.height = `${rect.height + 8}px`;
    highlight.style.backgroundColor =
      type === 0 ? "rgba(255, 165, 0, 0.35)" : "rgba(255, 0, 0, 0.35)";
    highlight.style.outline =
      type === 0 ? "solid 2px #FF9100" : "solid 2px #ff0000";
    highlight.style.pointerEvents = "none";
    highlight.style.zIndex = "9999";

    document.body.appendChild(highlight);
  },

  clearHighlight: () => {
    document
      .querySelectorAll(".highlight-overlay")
      .forEach((el) => el.remove());
  },

  clearHoverHighlight: () => {
    document
      .querySelectorAll(".highlight-hover-overlay")
      .forEach((el) => el.remove());
  },

  // ==========================================================================
  // Timers & Scheduling
  // ==========================================================================

  timeout: (ms, callbackId) => {
    setTimeout(() => {
      wasmInstance.timeoutCallBackId(callbackId);
    }, ms);
  },

  timeoutCtx: (ms, id) => {
    const callbackId = id >>> 0;

    // Cancel existing timeout/interval if one exists with this ID
    const existingTimeoutId = timeouts.get(callbackId);
    if (existingTimeoutId !== undefined) {
      console.warn(`Interval ${callbackId} already exists, replacing it`);
      clearTimeout(existingTimeoutId);
      clearInterval(existingTimeoutId);
    }

    const timeoutId = setTimeout(() => {
      try {
        wasmInstance.callbackCtx(callbackId, null);
      } catch (e) {
        // Ignore errors
      } finally {
        timeouts.delete(callbackId);
      }
    }, ms);
    timeouts.set(callbackId, timeoutId);
    return timeoutId;
  },

  cancelTimeoutWasm: (id) => {
    const callbackId = id >>> 0;
    const timeoutId = timeouts.get(callbackId);
    timeouts.delete(callbackId);
    clearInterval(timeoutId);
    clearTimeout(timeoutId);
  },

  createInterval: (id, delay) => {
    console.warn("WE NEED TO CREATE A SEPERATE HASHMAP FOR THE INTERVALS");
    const callbackId = id >>> 0;

    // Cancel existing interval if one exists with this ID
    const existingTimeoutId = timeouts.get(callbackId);
    if (existingTimeoutId !== undefined) {
      console.warn(`Interval ${callbackId} already exists, replacing it`);
      clearInterval(existingTimeoutId);
    }

    const timeoutId = setInterval(() => {
      try {
        wasmInstance.invokeErasedCallback(callbackId);
      } catch (e) {
        // Ignore errors
      }
    }, delay);
    timeouts.set(callbackId, timeoutId);
  },

  // ==========================================================================
  // Navigation & Routing
  // ==========================================================================

  getWindowInformationWasm: () => {
    return allocStringFrame(window.location.pathname);
  },

  getWindowParamsWasm: () => {
    return allocStringFrame(window.location.search);
  },

  getWindowHashWasm: () => {
    return allocStringFrame(window.location.hash);
  },

  getWindowOriginWasm: () => {
    return allocStringFrame(window.location.origin);
  },

  setWindowHashWasm: (hashPtr, hashLen) => {
    const hash = readWasmString(hashPtr, hashLen);
    window.location.hash = hash;
  },

  setWindowLocationWasm: (urlPtr, urlLen) => {
    const url = safeUrl(readWasmString(urlPtr, urlLen));
    if (url === BLOCKED_URL) return;
    window.location.href = url;
  },

  navigateWasm: (pathPtr, pathLen) => {
    const path = readWasmString(pathPtr, pathLen);
    const currentPath = window.location.pathname;
    requestAnimationFrame(() => {
      if (currentPath !== path) {
        rerenderRoute(path);
      }

      requestAnimationFrame(() => {
        const hash = window.location.hash;
        if (hash) {
          const id = window.location.hash.substring(1, hash.length);
          const element = document.getElementById(id);
          if (element) {
            element.scrollIntoView();
          }
        }
      });
    });
  },

  backWasm: () => {
    window.history.back();
  },

  // Push a history entry without navigating; Kit.routePush.
  routePushWASM: (pathPtr, pathLen) => {
    const path = readWasmString(pathPtr, pathLen);
    window.history.pushState({}, "", path);
  },

  forwardWasm: () => {
    window.history.forward();
  },

  replaceStateWasm: (pathPtr, pathLen) => {
    const path = readWasmString(pathPtr, pathLen);
    window.history.replaceState(null, "", path);
  },

  // ==========================================================================
  // Scrolling
  // ==========================================================================

  scrollToWasm: (x, y) => {
    window.scrollTo(x, y);
  },

  getScrollPositionWasm: () => {
    const ptr = wasmInstance.allocate(2);
    const view = new Float32Array(wasmInstance.memory.buffer, ptr, 2);
    view[0] = window.scrollX;
    view[1] = window.scrollY;
    return ptr;
  },

  getElementScrollWasm: (idPtr, idLen) => {
    const id = readWasmString(idPtr, idLen);
    const el = document.getElementById(id);
    if (!el) return 0;

    const ptr = wasmInstance.allocate(4);
    const view = new Float32Array(wasmInstance.memory.buffer, ptr, 4);
    view[0] = el.scrollTop;
    view[1] = el.scrollLeft;
    view[2] = el.scrollHeight;
    view[3] = el.scrollWidth;
    return ptr;
  },

  setElementScrollWasm: (idPtr, idLen, top, left) => {
    const id = readWasmString(idPtr, idLen);
    const el = document.getElementById(id);
    if (el) {
      el.scrollTop = top;
      el.scrollLeft = left;
    }
  },

  // ==========================================================================
  // Window Information
  // ==========================================================================

  windowWidth: () => {
    return window.innerWidth;
  },

  windowHeight: () => {
    return window.innerHeight;
  },

  getDevicePixelRatioWasm: () => {
    return window.devicePixelRatio;
  },

  getUserAgentWasm: () => {
    return allocString(navigator.userAgent);
  },

  getLanguageWasm: () => {
    return allocString(navigator.language);
  },

  isOnlineWasm: () => {
    return navigator.onLine ? 1 : 0;
  },

  isDocumentVisibleWasm: () => {
    return document.visibilityState === "visible" ? 1 : 0;
  },

  isWindowFocusedWasm: () => {
    return document.hasFocus() ? 1 : 0;
  },

  onVisibilityChangeWasm: (callbackId) => {
    document.addEventListener("visibilitychange", () => {
      wasmInstance.callbackCtx(callbackId, document.hidden ? 0 : 1);
    });
  },

  // ==========================================================================
  // Local Storage
  // ==========================================================================

  setLocalStorageStringWasm: (ptr, len, valuePtr, valueLen) => {
    if (!requireWasm()) return;
    const key = readWasmString(ptr, len);
    const value = readWasmString(valuePtr, valueLen);
    localStorage.setItem(key, value);
  },

  getLocalStorageStringWasm: (ptr, len) => {
    if (!requireWasm()) return;
    const key = readWasmString(ptr, len);
    const value = localStorage.getItem(key);
    if (value === null) return null;
    return allocStringFrame(value);
  },

  setLocalStorageNumberWasm: (ptr, len, value) => {
    if (!requireWasm()) return;
    const key = readWasmString(ptr, len);
    localStorage.setItem(key, value);
  },

  getLocalStorageNumberWasm: (ptr, len) => {
    if (!requireWasm()) return;
    const key = readWasmString(ptr, len);
    const value = localStorage.getItem(key);
    return value;
  },

  getLocalStorageI32Wasm: (ptr, len) => {
    if (!requireWasm()) return;
    const key = readWasmString(ptr, len);
    const value = localStorage.getItem(key);
    return value;
  },

  getLocalStorageU32Wasm: (ptr, len) => {
    if (!requireWasm()) return;
    const key = readWasmString(ptr, len);
    const value = localStorage.getItem(key);
    return value;
  },

  removeLocalStorageWasm: (ptr, len) => {
    if (!requireWasm()) return;
    const key = readWasmString(ptr, len);
    localStorage.removeItem(key);
  },

  clearLocalStorageWasm: () => {
    localStorage.clear();
  },

  // ==========================================================================
  // Cookies
  // ==========================================================================

  setCookieWasm: (cookieStrPtr, cookieStrLen) => {
    const cookie = readWasmString(cookieStrPtr, cookieStrLen);
    document.cookie = cookie;
  },

  getCookiesWasm: () => {
    return allocStringFrame(document.cookie);
  },

  getCookieWasm: (cookieStrPtr, cookieStrLen) => {
    const cookie = readWasmString(cookieStrPtr, cookieStrLen);
    const match = document.cookie.match(new RegExp(`(^| )${cookie}=([^;]+)`));
    return match ? allocStringFrame(decodeURIComponent(match[2])) : null;
  },

  // ==========================================================================
  // Clipboard
  // ==========================================================================

  copyTextWasm: (ptr, len) => {
    if (!requireWasm()) return;
    const text = readWasmString(ptr, len);

    if (navigator.clipboard && window.isSecureContext) {
      navigator.clipboard.writeText(text).catch((err) => {
        console.error("Clipboard write failed:", err);
      });
    }
  },

  readClipboardWasm: (callbackId) => {
    navigator.clipboard
      .readText()
      .then((text) => {
        const ptr = allocStringFrame(text);
        wasmInstance.resumeCallback(callbackId, ptr);
      })
      .catch((err) => {
        wasmInstance.resumeCallback(callbackId, 0);
      });
  },

  // ==========================================================================
  // Network / Fetch
  // ==========================================================================

  createWss: (port, onid, query_ptr, query_len) => {
    const query = readWasmString(query_ptr, query_len);
    const id = onid >>> 0;
    const url = `ws://localhost:${port}${query}`;
    const socket = new WebSocket(url);
    socket.onopen = function(event) {
      wasmInstance.onWssConnection(id);
    };
    socket.onmessage = function(event) {
      const ptr = allocStringFrame(event.data);
      wasmInstance.onWssMessage(id, ptr);
    };
    socket.onclose = function(event) {
      wasmInstance.onWssClose(id);
    };
    sockets.set(id, socket);
  },

  sendWss: (onid, dataPtr, dataLen) => {
    const id = onid >>> 0;
    const data = readWasmString(dataPtr, dataLen);
    const socket = sockets.get(id);

    if (!socket) {
      console.error("Socket not found for id:", id);
      return;
    }

    if (socket.readyState !== WebSocket.OPEN) {
      console.error("Socket not open, state:", socket.readyState);
      return;
    }

    socket.send(data);
  },

  fetchWasm: async (urlPtr, urlLen, callback_id, httpPtr, httpLen) => {
    const url = readWasmString(urlPtr, urlLen);
    const data = readWasmString(httpPtr, httpLen);
    const Request = JSON.parse(data);

    if (Request.body && typeof Request.body === "object") {
      Request.body = JSON.stringify(Request.body);
    }

    const startTime = performance.now();

    fetch(url, Request)
      .then(async (res) => {
        const elapsed = Math.round(performance.now() - startTime);

        const headers = {};
        res.headers.forEach((value, key) => {
          headers[key] = value;
        });

        const body = await res.text();

        // Wire format: flat object matching ParsedResponseWire in Zig.
        // - `ok: bool` is the variant discriminant (no outer Ok/Err wrapper)
        // - `status` (not `code`)
        // - For HTTP errors (4xx/5xx), ok=false and error_kind="http"
        const wire = {
          ok: res.ok,
          status: res.status,
          message: res.statusText,
          body: body,
          url: res.url,
          redirected: res.redirected,
          content_type: res.headers.get("content-type") || "",
          content_length: body.length,
          elapsed_ms: elapsed,
          headers: headers,
        };

        if (!res.ok) {
          wire.error_kind = "http";
          wire.error_name = "HttpError";
        }

        const respString = JSON.stringify(wire);
        const ptr = allocStringFrame(respString);
        wasmInstance.resumecallback(callback_id, ptr);
      })
      .catch((err) => {
        const elapsed = Math.round(performance.now() - startTime);

        // Categorize into one of the values Zig's parseErrorKind recognizes:
        //   "network" | "timeout" | "abort" | "parse" | "http"
        // Anything else lands in Zig's `.unknown` bucket. We keep the JS-side
        // detail (cors, dns, tls, etc.) in error_name for diagnostics.
        let error_kind = "unknown";
        let error_name = err.name || "Error";

        const msg = (err.message || "").toLowerCase();

        if (err.name === "AbortError" || msg.includes("abort")) {
          error_kind = "abort";
        } else if (msg.includes("timeout")) {
          error_kind = "timeout";
        } else if (
          err.name === "TypeError" &&
          (msg.includes("failed to fetch") ||
            msg.includes("networkerror") ||
            msg.includes("network request failed"))
        ) {
          // Browsers conflate CORS, DNS, and TLS into a generic "TypeError: Failed to fetch".
          // We bucket all of these as "network" for the Zig enum, but preserve detail in
          // error_name so users can disambiguate when debugging.
          error_kind = "network";
          if (msg.includes("cors")) error_name = "CorsError";
          else if (msg.includes("dns") || msg.includes("not found"))
            error_name = "DnsError";
          else if (
            msg.includes("ssl") ||
            msg.includes("cert") ||
            msg.includes("tls")
          )
            error_name = "TlsError";
        } else if (msg.includes("cors")) {
          error_kind = "network";
          error_name = "CorsError";
        } else if (msg.includes("dns") || msg.includes("not found")) {
          error_kind = "network";
          error_name = "DnsError";
        } else if (msg.includes("ssl") || msg.includes("cert")) {
          error_kind = "network";
          error_name = "TlsError";
        }

        const wire = {
          ok: false,
          status: 0,
          message: err.message || String(err),
          body: "",
          url: url,
          redirected: false,
          content_type: "",
          content_length: 0,
          elapsed_ms: elapsed,
          headers: null,
          error_kind: error_kind,
          error_name: error_name,
        };

        const respString = JSON.stringify(wire);
        const ptr = allocStringFrame(respString);
        wasmInstance.resumecallback(callback_id, ptr);
      });
  },

  // ==========================================================================
  // Hooks
  // ==========================================================================

  createHookWASM: (endpointPtr, endpointLen, id, hookType) => {
    const endpoint = readWasmString(endpointPtr, endpointLen);
    const hookId = `${endpoint}-${id}`;

    if (hookType === 0) {
      beforeHooksHandlers.set(hookId, () => {
        wasmInstance.hookInstCallback(id);
      });
    } else if (hookType === 1) {
      afterHooksHandlers.set(hookId, () => {
        wasmInstance.hookInstCallback(id);
      });
    }
  },

  // ==========================================================================
  // Intersection Observer
  // ==========================================================================
  createObserverWasm(id_ptr, optionsPtr) {
    const id = id_ptr >>> 0;
    optionsPtr = optionsPtr >>> 0;

    const instansePtr = wasmInstance.getObserverOptions(optionsPtr);
    if (instansePtr) {
      const fieldCount = wasmInstance.getObserverFieldCount();
      const reader = new DynamicStructReader(wasmInstance, wasmInstance.memory);
      const fieldStruct = reader.readStruct(
        null,
        instansePtr,
        fieldCount,
        "getObserverFieldDescriptor",
      );
      const opts = fieldStruct;

      const options = {
        threshold: reader.threshold,
        rootMargin: `${opts.rootMargin_top}px ${opts.rootMargin_right}px ${opts.rootMargin_bottom}px ${opts.rootMargin_left}px`,
        root: null,
      };

      const builder = new WasmObjectBuilder(wasmInstance, wasmInstance.memory);

      const observer = new IntersectionObserver((entries) => {
        entries.forEach((entry) => {
          const actualIndex = parseInt(entry.target.dataset.index, 10);
          const data = {
            id: entry.target.id,
            isIntersecting: entry.isIntersecting,
            actualIndex,
          };
          const object_ptr = builder.passObject(data);
          wasmInstance.callbackCtx(id, object_ptr);
        });
      }, options);
      observers.set(id, observer);
    }
  },

  observeWasm(id_ptr, elementPtr, elementLen, index) {
    const id = id_ptr >>> 0;
    const elementId = readWasmString(elementPtr, elementLen);
    const observer = observers.get(id);
    let element = document.getElementById(elementId);
    if (!element) {
      requestAnimationFrame(() => {
        element = document.getElementById(elementId);
        if (!element) {
          console.warn(
            `Could not Observe: Element with id ${elementId} not found`,
          );
          return;
        }
        element.dataset.index = index;
        observer.observe(element);
      });
      return;
    }

    element.dataset.index = index;
    observer.observe(element);
  },

  reinitObserverWasm(id_ptr) {
    const id = id_ptr >>> 0;
    const observer = observers.get(id);

    if (!observer) {
      console.warn(`Observer ${id} not found`);
      return;
    }

    observer.disconnect();
  },

  destroyObserverWasm(ptr, len) {
    observers.delete(readWasmString(ptr, len));
  },

  // ==========================================================================
  // Resize Observer
  // ==========================================================================

  createResizeObserverWasm(id_ptr, optionsPtr) {
    const id = id_ptr >>> 0;
    optionsPtr = optionsPtr >>> 0;

    // Read options struct (same pattern as IntersectionObserver)
    const instancePtr = wasmInstance.getResizeOptions(optionsPtr);
    let box = "content-box";
    if (instancePtr) {
      const fieldCount = wasmInstance.getResizeOptionsFieldCount();
      const reader = new DynamicStructReader(wasmInstance, wasmInstance.memory);
      const opts = reader.readStruct(
        null,
        instancePtr,
        fieldCount,
        "getResizeOptionsFieldDescriptor",
      );
      // box enum: 0=content-box, 1=border-box, 2=device-pixel-content-box
      box =
        ["content-box", "border-box", "device-pixel-content-box"][opts.box] ||
        "content-box";
    }

    const callbackMap = new Map();
    resizeCallbacks.set(id, callbackMap);

    const builder = new WasmObjectBuilder(wasmInstance, wasmInstance.memory);

    const observer = new ResizeObserver(
      (entries) => {
        for (const entry of entries) {
          const elementId = entry.target.id;
          const callbackId = callbackMap.get(elementId);

          if (callbackId === undefined) continue;

          // Pull dimensions. borderBoxSize is an array of {inlineSize, blockSize}
          const borderBox = entry.borderBoxSize?.[0];
          const contentBox = entry.contentBoxSize?.[0];

          const width = borderBox
            ? borderBox.inlineSize
            : entry.contentRect.width;
          const height = borderBox
            ? borderBox.blockSize
            : entry.contentRect.height;
          const contentWidth = contentBox
            ? contentBox.inlineSize
            : entry.contentRect.width;
          const contentHeight = contentBox
            ? contentBox.blockSize
            : entry.contentRect.height;

          const index = parseInt(entry.target.dataset.resizeIndex || "0", 10);

          // Write entry directly into Wasm memory at a scratch location
          // OR use your existing builder pattern:
          const data = {
            width,
            height,
            content_width: contentWidth,
            content_height: contentHeight,
            index,
          };

          const entryPtr = builder.passObject(data); // however you marshal structs in
          wasmInstance.resizeCallback(callbackId, entryPtr);
        }
      },
      { box },
    );

    resizeObservers.set(id, observer);
  },

  observeResizeWasm(id_ptr, elementPtr, elementLen, callback_Id) {
    const id = id_ptr >>> 0;
    const callbackId = callback_Id >>> 0;
    const elementId = readWasmString(elementPtr, elementLen);
    const observer = resizeObservers.get(id);
    if (!observer) {
      console.warn(`ResizeObserver ${id} not found`);
      return;
    }
    let element = document.getElementById(elementId);
    if (!element) {
      requestAnimationFrame(() => {
        element = document.getElementById(elementId);
        if (!element) {
          console.warn(`Element ${elementId} not found for resize observation`);
          return;
        }
        // Track callbackId per element so we can dispatch correctly
        const cbMap = resizeCallbacks.get(id);
        cbMap.set(elementId, callbackId);

        observer.observe(element);
      });
      return;
    }

    // Track callbackId per element so we can dispatch correctly
    const cbMap = resizeCallbacks.get(id);
    cbMap.set(elementId, callbackId);

    observer.observe(element);
  },

  unobserveResizeWasm(id_ptr, elementPtr, elementLen) {
    const id = id_ptr >>> 0;
    const elementId = readWasmString(elementPtr, elementLen);
    const observer = resizeObservers.get(id);
    if (!observer) return;
    const element = document.getElementById(elementId);
    if (element) observer.unobserve(element);
    resizeCallbacks.get(id)?.delete(elementId);
  },

  disconnectResizeObserverWasm(id_ptr) {
    const id = id_ptr >>> 0;
    const observer = resizeObservers.get(id);
    if (!observer) return;
    observer.disconnect();
    resizeCallbacks.get(id)?.clear();
  },

  destroyResizeObserverWasm(ptr, len) {
    const name = readWasmString(ptr, len);
    // If you key by hash on Zig side, you'll need to match that here
    // For now, assuming the JS side keys the same way
    const id = hashName(name); // or however your hashing aligns
    const observer = resizeObservers.get(id);
    if (observer) {
      observer.disconnect();
      resizeObservers.delete(id);
      resizeCallbacks.delete(id);
    }
  },

  // ==========================================================================
  // Video / Media
  // ==========================================================================

  startVideoWasm: (idPtr, idLen) => {
    const id = readWasmString(idPtr, idLen);
    const video = document.getElementById(id);
    if (video === null) return;

    async function startCamera() {
      try {
        const stream = await navigator.mediaDevices.getUserMedia({
          video: true,
          audio: false,
        });
        video.srcObject = stream;
      } catch (error) {
        console.error("Camera access denied:", error);
      }
    }

    startCamera();
  },

  playVideoWasm: (idPtr, idLen) => {
    const id = readWasmString(idPtr, idLen);
    const video = document.getElementById(id);
    video.play();
  },

  pauseVideoWasm: (idPtr, idLen) => {
    const id = readWasmString(idPtr, idLen);
    const video = document.getElementById(id);
    video.pause();
  },

  stopCameraWasm: (idPtr, idLen) => {
    const id = readWasmString(idPtr, idLen);
    const video = document.getElementById(id);

    if (video.srcObject) {
      const tracks = video.srcObject.getTracks();
      tracks.forEach((track) => track.stop());
      video.srcObject = null;
    }
  },

  seekVideoWasm: (idPtr, idLen, seconds) => {
    const id = readWasmString(idPtr, idLen);
    const video = document.getElementById(id);
    video.currentTime = seconds;
  },

  setVolumeWasm: (idPtr, idLen, volume) => {
    const id = readWasmString(idPtr, idLen);
    const video = document.getElementById(id);
    video.volume = volume;
  },

  muteVideoWasm: (idPtr, idLen, mute) => {
    const id = readWasmString(idPtr, idLen);
    const video = document.getElementById(id);
    video.muted = !!mute;
  },

  getVideoDurationWasm: (idPtr, idLen) => {
    const id = readWasmString(idPtr, idLen);
    const video = document.getElementById(id);
    return video.duration;
  },

  getVideoCurrentTimeWasm: (idPtr, idLen) => {
    const id = readWasmString(idPtr, idLen);
    const video = document.getElementById(id);
    return video.currentTime;
  },
  frame_arena_init: () => { },
  scrollIntoViewWasm: (idPtr, idLen, behavior_enum, block_enum) => {
    const id = readWasmString(idPtr, idLen);
    const element = document.getElementById(id);
    if (element === null) {
      debug("Element Is Null");
      return;
    }
    let behavior = "auto";
    let block = "start";

    switch (behavior_enum) {
      case 0:
        behavior = "auto";
        break;
      case 1:
        behavior = "smooth";
        break;
      case 2:
        behavior = "instant";
        break;
    }
    switch (block_enum) {
      case 0:
        block = "start";
        break;
      case 1:
        block = "center";
        break;
      case 2:
        block = "end";
        break;
      case 3:
        block = "nearest";
        break;
    }
    element.scrollIntoView({ block, behavior });
  },

  scrollToBehaviorWasm: (
    idPtr,
    idLen,
    top,
    left,
    behavior_enum,
    block_enum,
  ) => {
    const id = readWasmString(idPtr, idLen);
    const element = document.getElementById(id);
    if (element === null) {
      debug("Element Is Null");
      return;
    }
    let behavior = "auto";
    let block = "start";

    switch (behavior_enum) {
      case 0:
        behavior = "auto";
        break;
      case 1:
        behavior = "smooth";
        break;
      case 2:
        behavior = "instant";
        break;
    }
    switch (block_enum) {
      case 0:
        block = "start";
        break;
      case 1:
        block = "center";
        break;
      case 2:
        block = "end";
        break;
      case 3:
        block = "nearest";
        break;
    }

    element.scrollTo({ top, left, behavior });
  },

  setAttributeWasm: (idPtr, idLen, keyPtr, keyLen, valuePtr, valueLen) => {
    const id = readWasmString(idPtr, idLen);
    const key = readWasmString(keyPtr, keyLen);
    const value = readWasmString(valuePtr, valueLen);
    const element = document.getElementById(id);
    if (element === null) {
      console.warn("Cannot Set Attribute, Element Is Null", id);
      return;
    }
    element.setAttribute(key, value);
  },
  removeAttributeWasm: (idPtr, idLen, keyPtr, keyLen) => {
    const id = readWasmString(idPtr, idLen);
    const key = readWasmString(keyPtr, keyLen);
    const element = document.getElementById(id);
    if (element === null) {
      debug("Element Is Null");
      return;
    }
    element.removeAttribute(key);
  },
  startViewTransitionWasm: (callback_id) => {
    const transition = document.startViewTransition(() => {
      wasmInstance.invokeErasedCallback(callback_id);
    });

    transition.ready.catch((err) => console.error("Transition failed:", err));
    transition.finished.catch((err) => console.error("Transition error:", err));
  },

  runPlaygroundWasm: async (urlPtr, urlLen) => {
    const wasm_playground_url = readWasmString(urlPtr, urlLen);

    // Fetch the WASM binary
    const response = await fetch(wasm_playground_url);
    const bytes = await response.arrayBuffer();

    // Destroy the old iframe and create a fresh one
    const oldIframe = document.getElementById("playground-frame");
    const parent = oldIframe.parentElement;
    const newIframe = oldIframe.cloneNode(false); // clones attributes, not children/state
    parent.replaceChild(newIframe, oldIframe);

    // Wait for the new iframe to signal it's ready, then send the WASM
    window.addEventListener("message", function handler(e) {
      if (e.data.type === "playground-ready") {
        window.removeEventListener("message", handler);
        newIframe.contentWindow.postMessage({ type: "load-wasm", bytes }, "*");
      }
    });
  },
  windowOpenWasm: (urlPtr, urlLen) => {
    const url = readWasmString(urlPtr, urlLen);
    window.open(url, "_blank");
  },
};
