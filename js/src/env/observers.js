/** IntersectionObserver and ResizeObserver. */
import { wasmInstance } from "../instance.js";
import { observers } from "../maps.js";
import { DynamicStructReader, WasmObjectBuilder } from "../struct_bridge.js";
import { readWasmString } from "../wasi_obj.js";

// Separate map for resize observers (don't share with IntersectionObservers)
const resizeObservers = new Map();
// Map: observerId -> Map<elementId, callbackId>
const resizeCallbacks = new Map();

export const observersBindings = {
  // Intersection Observer
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

  // Resize Observer
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
};
