/** Creating, mutating, styling and measuring DOM elements. */
import { debug } from "../debug.js";
import { elementCache, requireWasm, wasmInstance } from "../instance.js";
import { elementDimensions } from "../maps.js";
import {
  allocStringFrame,
  f32View,
  readWasmString,
  styleSheet,
} from "../wasi_obj.js";

export const domBindings = {
  // DOM Element Creation & Manipulation
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
  startViewTransitionWasm: (callback_id) => {
    const transition = document.startViewTransition(() => {
      wasmInstance.invokeErasedCallback(callback_id);
    });

    transition.ready.catch((err) => console.error("Transition failed:", err));
    transition.finished.catch((err) => console.error("Transition error:", err));
  },

  // DOM Element Attributes & Properties
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

  // DOM Styling
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

  // CSS Classes
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

  // Element Dimensions & Position
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

  // Element Focus & Interactions
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

  // Input Elements
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

  // Dialog Elements
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
};
