/** IntersectionObserver and ResizeObserver. */
import { wasmInstance } from "../instance.js";
import { observers } from "../maps.js";
import { DynamicStructReader, WasmObjectBuilder } from "../struct_bridge.js";
import { readWasmString } from "../runtime.js";

// Separate map for resize observers (don't share with IntersectionObservers)
const resizeObservers = new Map();
// Map: observerId -> Map<elementId, callbackId>
const resizeCallbacks = new Map();
// Per observer, the elements it watches, so a render that asks again does not
// observe again (which would report the size again and rerender).
const resizeWatched = new Map();

export const observersBindings = {
  // Intersection Observer
  createObserverWasm(id_ptr, optionsPtr) {
    const id = id_ptr >>> 0;
    optionsPtr = optionsPtr >>> 0;

    const instancePtr = wasmInstance.getObserverOptions(optionsPtr);
    if (instancePtr) {
      const fieldCount = wasmInstance.getObserverFieldCount();
      const reader = new DynamicStructReader(wasmInstance, wasmInstance.memory);
      const fieldStruct = reader.readStruct(
        null,
        instancePtr,
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
    resizeWatched.set(id, new WeakSet());

    const builder = new WasmObjectBuilder(wasmInstance, wasmInstance.memory);

    const observer = new ResizeObserver(
      (entries) => {
        for (const entry of entries) {
          const target = entry.target;
          const elementId = target.id;

          // An element that left the page reports one last resize, and its
          // callback may be gone with it. Stop watching it; keep the id's
          // callback if a new element under the same id took its place.
          if (!target.isConnected) {
            observer.unobserve(target);
            resizeWatched.get(id)?.delete(target);
            if (!document.getElementById(elementId)) callbackMap.delete(elementId);
            continue;
          }

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
          if (!wasmInstance.resizeCallback(callbackId, entryPtr)) {
            // The element no longer asks for resizes (vapor dropped its
            // callback when a render stopped calling .onResize).
            observer.unobserve(target);
            resizeWatched.get(id)?.delete(target);
            callbackMap.delete(elementId);
          }
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
    // Track callbackId per element so we can dispatch correctly
    resizeCallbacks.get(id).set(elementId, callbackId);

    // The element is looked up once this render is on the page: the render
    // calling this can still replace the element that has the id now (a
    // prerendered one is rebuilt when the app takes the page over).
    requestAnimationFrame(() => {
      const element = document.getElementById(elementId);
      if (!element) {
        console.warn(`Element ${elementId} not found for resize observation`);
        return;
      }
      const watched = resizeWatched.get(id);
      if (watched.has(element)) return;
      watched.add(element);
      observer.observe(element);
    });
  },
  unobserveResizeWasm(id_ptr, elementPtr, elementLen) {
    const id = id_ptr >>> 0;
    const elementId = readWasmString(elementPtr, elementLen);
    const observer = resizeObservers.get(id);
    if (!observer) return;
    const element = document.getElementById(elementId);
    if (element) {
      observer.unobserve(element);
      resizeWatched.get(id)?.delete(element);
    }
    resizeCallbacks.get(id)?.delete(elementId);
  },
  disconnectResizeObserverWasm(id_ptr) {
    const id = id_ptr >>> 0;
    const observer = resizeObservers.get(id);
    if (!observer) return;
    observer.disconnect();
    resizeCallbacks.get(id)?.clear();
    resizeWatched.set(id, new WeakSet());
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
