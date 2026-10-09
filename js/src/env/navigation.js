/** History, routing, scrolling and window information. */
import { debug } from "../debug.js";
import { wasmInstance } from "../instance.js";
import { BLOCKED_URL, safeUrl } from "../url.js";
import {
  allocString,
  allocStringFrame,
  readWasmString,
  rerenderRoute,
} from "../wasi_obj.js";

export const navigationBindings = {
  // Navigation & Routing
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

  // Scrolling
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

  // Window Information
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
};
