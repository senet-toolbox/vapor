/** DOM event listeners and reading event data back into wasm. */
import { debug } from "../debug.js";
import { EventType } from "../event_type.js";
import { parseWasmError } from "../formatter.js";
import { getElement, requireWasm, wasmInstance } from "../instance.js";
import { domNodeRegistry, eventHandlers, eventStorage } from "../maps.js";
import { WasmObjectBuilder } from "../struct_bridge.js";
import { allocStringFrame, readWasmString } from "../runtime.js";

/**
 * Document listeners by the id wasm gave them. Keyed by id, not event type,
 * so two listeners for the same event can be added and removed separately.
 */
const documentListeners = new Map();

function addDocumentListener(ptr, len, onid) {
  if (!requireWasm()) return;
  const callback_id = onid >>> 0;
  const event_type = readWasmString(ptr, len);

  const handler = (event) => {
    try {
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

  documentListeners.get(callback_id)?.remove();
  document.addEventListener(event_type, handler);
  documentListeners.set(callback_id, {
    remove: () => document.removeEventListener(event_type, handler),
  });
}

/**
 * Element listeners from `Element.listen`, by the id wasm gave them. They
 * outlive renders; `dropElementListeners` detaches them when their element
 * leaves the page.
 */
const elementListeners = new Map();
/** Ids in `elementListeners` per element id. */
const listenersByElement = new Map();

function detachElementListener(id) {
  const entry = elementListeners.get(id);
  if (!entry) return;
  entry.remove();
  elementListeners.delete(id);
  delete eventStorage[id];
  const ids = listenersByElement.get(entry.elementId);
  ids?.delete(id);
  if (ids?.size === 0) listenersByElement.delete(entry.elementId);
}

/**
 * Detaches the `Element.listen` listeners of the element `elementId`, which
 * is leaving the page, and lets wasm free their callbacks.
 */
export function dropElementListeners(elementId) {
  const ids = listenersByElement.get(elementId);
  if (!ids) return;
  for (const id of [...ids]) {
    detachElementListener(id);
    wasmInstance?.dropElementListener(id);
  }
}

export const eventsBindings = {
  addElementListener: (idPtr, idLen, ptr, len, onid) => {
    if (!requireWasm()) return false;
    const [elementId, element] = getElement(idPtr, idLen);
    if (!element) return false;

    const id = onid >>> 0;
    const name = readWasmString(ptr, len);
    const code = EventType[name];
    const domType = name === "rightclick" ? "contextmenu" : name;
    const handler = (event) => {
      eventStorage[id] = event;
      wasmInstance.dispatchElementListener(code, id);
    };

    element.addEventListener(domType, handler);
    elementListeners.set(id, {
      elementId,
      remove: () => element.removeEventListener(domType, handler),
    });
    if (!listenersByElement.has(elementId)) listenersByElement.set(elementId, new Set());
    listenersByElement.get(elementId).add(id);
    return true;
  },
  removeElementListener: (onid) => {
    if (!requireWasm()) return;
    detachElementListener(onid >>> 0);
  },

  // Event Handling - Document Level
  createEventListenerGlobal: addDocumentListener,
  createEventListener: addDocumentListener,
  createEventListenerCtx: addDocumentListener,
  removeEventListener: (_ptr, _len, onid) => {
    if (!requireWasm()) return;
    const callback_id = onid >>> 0;
    documentListeners.get(callback_id)?.remove();
    documentListeners.delete(callback_id);
    delete eventStorage[callback_id];
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

  // Event Data Extraction
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
};
