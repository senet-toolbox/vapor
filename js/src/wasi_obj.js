import { debug } from "./debug.js";
import { importObject } from "./wasi_env.js";
import { EventType, setWasiInstance } from "./wasi.js";
import {
  domNodeRegistry,
  moduleCache,
  moduleRoutes,
  beforeHooksHandlers,
  observeredSections,
  loadedSections,
  afterHooksHandlers,
  eventStorage,
  invokedHooks,
} from "./maps.js";
import {
  COMPONENT_TYPES,
  traverseUINodes,
  animateExit,
  resetTimers,
} from "./traversal.js";
import { state } from "./state.js";
import { styleRuleCache, styleClassCache } from "./wasi_styling.js";
import { parseWasmError } from "./formatter.js";
// import { initCacheModule } from "./cachebindings.js";

export let wasmInstance;
export let activeNodeIds = new Set();
export let rootNodeId = "root";
export let layoutInfo;
export let UINodelayoutInfo;

let tree_node;
// const socket = new WebSocket("ws://localhost:3003");
// const reloadIndicator = document.getElementById("reload-indicator");
// const reloadTimer = document.getElementById("reload-timer");
//
// This fires when the connection is successfully established
// socket.onopen = function (event) {
//   console.log("WebSocket connection established!");
//   // Maybe update UI to show connected status
// };

// let reloadStartTime = null;
// let reloadTimerInterval = null;
//
// function showReloading() {
//   reloadStartTime = performance.now();
//   reloadIndicator.classList.add("visible");
//
//   // Update timer every 100ms
//   reloadTimerInterval = setInterval(() => {
//     const elapsed = (performance.now() - reloadStartTime) / 1000;
//     reloadTimer.textContent = elapsed.toFixed(1);
//   }, 100);
// }
//
// function hideReloading() {
//   // Show final time briefly before hiding
//   if (reloadStartTime) {
//     const elapsed = (performance.now() - reloadStartTime) / 1000;
//     reloadTimer.textContent = elapsed.toFixed(2);
//   }
//
//   clearInterval(reloadTimerInterval);
//   reloadTimerInterval = null;
//   reloadStartTime = null;
//
//   // Small delay so you can see the final time
//   setTimeout(() => {
//     reloadIndicator.classList.remove("visible");
//   }, 300);
// }

// // Handle incoming messages
// socket.onmessage = async function (event) {
//   if (event.data === "reloading") {
//     showReloading();
//     return;
//   }
//
//   // Your existing reload logic here...
//   // After WASM loads:
//   if (event.data === "refresh") {
//     const rootElement = document.getElementById("contents");
//     rootElement.innerHTML = "";
//     window.location.reload();
//   }
//   hideReloading();
// };

// // Handle errors
// socket.onerror = function (error) {
//   console.error("WebSocket error:", error);
// };
//
// // Handle disconnection
// socket.onclose = function (event) {
//   console.log("WebSocket connection closed:", event.code, event.reason);
// };

let uiNodeLayoutInfoPtr;

const mq = window.matchMedia("(max-width: 767px)");

mq.addEventListener("change", (e) => {
  debug("Media query changed. Is mobile:", e.matches);
  if (e.matches) {
    const path = window.location.pathname;
    wasmInstance.rerenderEverything();
    wasmInstance.resetPacker();

    rerenderRoute(path);
  } else {
    const path = window.location.pathname;
    wasmInstance.rerenderEverything();
    wasmInstance.resetPacker();

    rerenderRoute(path);
  }
});

window.addEventListener("popstate", async function(event) {
  const path = window.location.pathname;
  rerenderRoute(path);
  requestAnimationFrame(() => {
    wasmInstance.onPopStateCallback();
  });
});


async function loadWasm(path, imports = {}) {
  const response = await fetch(path); // cache-bust
  const bytes = await response.arrayBuffer();
  const { instance } = await WebAssembly.instantiate(bytes, imports);
  return instance;
}

let pathname;
export let text_data;
async function loadWasiModule() {
  pathname = "vapor";
  (async () => {
    try {
      const instance = await loadWasm(
        `/zig-out/bin/${pathname}.wasm`,
        importObject,
      );
      const exports = instance.exports;
      moduleCache.set(pathname, exports);
      moduleRoutes.add(pathname);
      wasmInstance = exports;
      setWasiInstance(wasmInstance);

      text_data = {};
      init();
    } catch (err) {
      console.error("Fatal error loading WASM:", err);
    }
  })();
}
async function initWasi() {
  wasmInstance = await loadWasiModule();
}

export const encodeString = (string) => {
  const buffer = new TextEncoder().encode(string);
  const pointer = wasmInstance.allocUint8(buffer.length + 1); // ask Zig to allocate memory
  const slice = new Uint8Array(
    wasmInstance.memory.buffer, // memory exported from Zig
    pointer,
    buffer.length + 1,
  );
  slice.set(buffer);
  slice[buffer.length] = 0; // null byte to null-terminate the string
  wasmInstance.setRouteRenderTree(pointer);
};

// After the first render the page is live: handlers are attached and, for a
// prerendered page, the server HTML is hydrated. Until then a click on
// prerendered HTML goes nowhere. Announced once, for apps and test tools:
//   <html data-vapor-ready>    and    window "vapor:ready" event
let ready = false;
function markReady() {
  if (ready) return;
  ready = true;
  document.documentElement.setAttribute("data-vapor-ready", "");
  window.dispatchEvent(new Event("vapor:ready"));
}

export const rerenderRoute = (navigatedPath) => {
  currentPath = window.location.pathname;

  for (const [key, handler] of afterHooksHandlers.entries()) {
    const pathEnd = key.indexOf("-");
    const path = key.substring(0, pathEnd);

    // Check if currentPath starts with the hook path
    if (currentPath === path || currentPath.startsWith(path + "/")) {
      handler();
    }
  }

  for (const [key, handler] of beforeHooksHandlers.entries()) {
    const pathEnd = key.indexOf("-");
    const path = key.substring(0, pathEnd);

    // Check if currentPath starts with the hook path
    if (navigatedPath === path || navigatedPath.startsWith(path + "/")) {
      handler();
    }
  }

  window.history.pushState({}, "", navigatedPath);

  wasmInstance.forceRerender();
  wasmInstance.resetPacker();
  render();
};

export const navToRoute = (string) => {
  const buffer = new TextEncoder().encode(string);
  const pointer = wasmInstance.allocUint8(buffer.length + 1); // ask Zig to allocate memory
  const slice = new Uint8Array(
    wasmInstance.memory.buffer, // memory exported from Zig
    pointer,
    buffer.length + 1,
  );
  slice.set(buffer);
  slice[buffer.length] = 0; // null byte to null-terminate the string
  wasmInstance.setRouteRenderTree(pointer);
};

export function f32View(ptr, len) {
  return new Float32Array(wasmInstance.memory.buffer, ptr, len);
}

export const allocStringFrame = (string) => {
  const buffer = new TextEncoder().encode(string);
  const pointer = wasmInstance.allocUint8Frame(buffer.length + 1); // ask Zig to allocate memory
  const slice = new Uint8Array(
    wasmInstance.memory.buffer, // memory exported from Zig
    pointer,
    buffer.length + 1,
  );
  slice.set(buffer);
  slice[buffer.length] = 0; // null byte to null-terminate the string
  return pointer;
};

export const allocString = (string) => {
  const buffer = new TextEncoder().encode(string);
  const pointer = wasmInstance.allocUint8(buffer.length + 1); // ask Zig to allocate memory
  const slice = new Uint8Array(
    wasmInstance.memory.buffer, // memory exported from Zig
    pointer,
    buffer.length + 1,
  );
  slice.set(buffer);
  slice[buffer.length] = 0; // null byte to null-terminate the string
  return pointer;
};

export let root;

function setupLayoutInfo() {
  // Set up listener for back/forward buttons
  // Get the memory layout information
  // So we grab the memory layout of each render command
  // layoutInfoPtr = wasmInstance.allocateLayoutInfo();

  // Corrected JavaScript code to read layout info
  // layoutInfoPtr = wasmInstance.allocateLayoutInfo();
  uiNodeLayoutInfoPtr = wasmInstance.allocateUINodeLayoutInfo();

  UINodelayoutInfo = {
    // Corresponds directly to the corrected Zig struct order
    UINodeSize: new DataView(
      wasmInstance.memory.buffer,
      uiNodeLayoutInfoPtr + 0,
      4,
    ).getUint32(0, true),

    // --- Direct offsets in RenderCommand ---
    elemTypeOffset: new DataView(
      wasmInstance.memory.buffer,
      uiNodeLayoutInfoPtr + 4,
      4,
    ).getUint32(0, true),
    textPtrOffset: new DataView(
      wasmInstance.memory.buffer,
      uiNodeLayoutInfoPtr + 8,
      4,
    ).getUint32(0, true),
    hrefPtrOffset: new DataView(
      wasmInstance.memory.buffer,
      uiNodeLayoutInfoPtr + 12,
      4,
    ).getUint32(0, true),
    idPtrOffset: new DataView(
      wasmInstance.memory.buffer,
      uiNodeLayoutInfoPtr + 16,
      4,
    ).getUint32(0, true),
    indexOffset: new DataView(
      wasmInstance.memory.buffer,
      uiNodeLayoutInfoPtr + 20,
      4,
    ).getUint32(0, true),
    classnamePtrOffset: new DataView(
      wasmInstance.memory.buffer,
      uiNodeLayoutInfoPtr + 24,
      4,
    ).getUint32(0, true),

    hashOffset: new DataView(
      wasmInstance.memory.buffer,
      uiNodeLayoutInfoPtr + 28,
      4,
    ).getUint32(0, true),
    styleChangedOffset: new DataView(
      wasmInstance.memory.buffer,
      uiNodeLayoutInfoPtr + 32,
      4,
    ).getUint32(0, true),
    propsChangedOffset: new DataView(
      wasmInstance.memory.buffer,
      uiNodeLayoutInfoPtr + 36,
      4,
    ).getUint32(0, true),
    dirtyOffset: new DataView(
      wasmInstance.memory.buffer,
      uiNodeLayoutInfoPtr + 40,
      4,
    ).getUint32(0, true),
    hooksOffset: new DataView(
      wasmInstance.memory.buffer,
      uiNodeLayoutInfoPtr + 44,
      4,
    ).getUint32(0, true),
    styleHashOffset: new DataView(
      wasmInstance.memory.buffer,
      uiNodeLayoutInfoPtr + 48,
      4,
    ).getUint32(0, true),
    accessibilityOffset: new DataView(
      wasmInstance.memory.buffer,
      uiNodeLayoutInfoPtr + 52,
      4,
    ).getUint32(0, true),
    onCallbacksOffset: new DataView(
      wasmInstance.memory.buffer,
      uiNodeLayoutInfoPtr + 56,
      4,
    ).getUint32(0, true),
    hooksChangedOffset: new DataView(
      wasmInstance.memory.buffer,
      uiNodeLayoutInfoPtr + 60,
      4,
    ).getUint32(0, true),
    morphOffset: new DataView(
      wasmInstance.memory.buffer,
      uiNodeLayoutInfoPtr + 64,
      4,
    ).getUint32(0, true),
    layerOffset: new DataView(
      wasmInstance.memory.buffer,
      uiNodeLayoutInfoPtr + 68,
      4,
    ).getUint32(0, true),
  };
}

function getSystemTheme() {
  return window.matchMedia("(prefers-color-scheme: dark)").matches
    ? "dark"
    : "light";
}

function loadTheme() {
  const savedTheme = localStorage.getItem("theme") || getSystemTheme();
  if (savedTheme === "dark") {
    document.documentElement.setAttribute("data-theme", "dark");
    try {
      wasmInstance.setTheme(1);
    } catch (e) {
      console.warn("Error setting theme", e);
    }
  } else {
    const savedTheme = localStorage.getItem("theme");
    if (savedTheme === "dark") {
      document.documentElement.setAttribute("data-theme", "dark");
      wasmInstance.setTheme(1);
    }
  }
}

export const styleSheet = new CSSStyleSheet();
export let breadcrumbs = [];

export let currentPath;
function setupWasiInstance() {
  // checkMemoryGrowth();
  wasmInstance.init(); // Example UI function

  // new PerformanceMonitor();

  const rootContainer = document.getElementById("contents");
  let hovered = null;

  // 1. Define all the events you want your framework to listen to globally
  const delegatedEvents = [
    "click",
    "dblclick",
    "input",
    "change",
    "keydown",
    "keyup",
    "submit",
    "focusin", // Bubbling version of focus
    "focusout", // Bubbling version of blur
    "mouseover", // Bubbling version of blur
    "mouseout", // Bubbling version of blur
  ];

  // 2. The single master function that handles EVERYTHING
  function handleGlobalEvent(event) {
    // Find the closest element that has an ID (so we can look it up in the registry)
    let targetElement = event.target.closest("[id]");

    if (event.type === "click" || event.type === "dbclick") {
      targetElement = event.target.closest("button");
    }

    if (!targetElement) return;

    if (targetElement.id === null || targetElement.id === undefined) {
      return;
    }

    const nodeInfo = domNodeRegistry.get(targetElement.id);
    if (!nodeInfo) return;

    const callback_id = nodeInfo.hash + EventType[event.type];
    eventStorage[callback_id] = event;

    const type = nodeInfo.elementType;

    if ("mouseover" === event.type || "mouseout" === event.type) {
      wasmInstance.dispatchNodeEvent(nodeInfo.node_ptr, EventType[event.type]);
    }

    // --- BUTTON LOGIC ---
    if (
      type === COMPONENT_TYPES.BUTTON_CTX ||
      type === COMPONENT_TYPES.BUTTON
    ) {
      if (event.type === "click" || event.type === "dbclick") {
        event.preventDefault();
        event.stopPropagation();
        try {
          wasmInstance.invokeErasedCallback(nodeInfo.hash);
        } catch (e) {
          handleWasmError(e, targetElement.id);
        }
      }
      return;
    }

    // --- INPUT LOGIC (Example for focus/blur) ---
    if (
      type === COMPONENT_TYPES.TEXT_FIELD ||
      type === COMPONENT_TYPES.TEXT_AREA
    ) {
      if (event.type === "focusin") {
        const callback_id = nodeInfo.hash + EventType["focus"];
        eventStorage[callback_id] = event;

        wasmInstance.dispatchNodeEvent(nodeInfo.node_ptr, EventType["focus"]);
      }
      if (event.type === "focusout") {
        const callback_id = nodeInfo.hash + EventType["blur"];
        eventStorage[callback_id] = event;

        wasmInstance.dispatchNodeEvent(nodeInfo.node_ptr, EventType["blur"]);
      }
      if (event.type === "input") {
        wasmInstance.dispatchNodeEvent(nodeInfo.node_ptr, EventType["input"]);
      }
      return;
    }

    if (type === COMPONENT_TYPES.FORM) {
      if (event.type === "submit") {
        const callback_id = nodeInfo.hash + EventType["submit"];
        eventStorage[callback_id] = event;

        wasmInstance.dispatchNodeEvent(nodeInfo.node_ptr, EventType["submit"]);
      }
      return;
    }

    if ("keydown" === event.type || "keyup" === event.type) {
      wasmInstance.dispatchNodeEvent(nodeInfo.node_ptr, EventType[event.type]);
    }
  }

  // 3. Loop through the array and attach the master function to the root
  delegatedEvents.forEach((eventType) => {
    rootContainer.addEventListener(eventType, handleGlobalEvent);
  });

  // 4. (Bonus) Extracted your error handler so the main function isn't cluttered
  function handleWasmError(e, elementId) {
    if (e instanceof WebAssembly.RuntimeError) {
      const parsed = parseWasmError(e);
      const idPtr = allocStringFrame(JSON.stringify(parsed));

      const eventData = { id: elementId };
      debug(eventData);

      const eventPtr = allocStringFrame(JSON.stringify(eventData));
      wasmInstance.recordState(idPtr, eventPtr);
    }
    throw e;
  }

  currentPath = window.location.pathname;

  for (const [key, handler] of beforeHooksHandlers.entries()) {
    const pathEnd = key.indexOf("-");
    const path = key.substring(0, pathEnd);

    // Check if currentPath starts with the hook path
    if (currentPath === path || currentPath.startsWith(path + "/")) {
      handler();
    }
  }

  loadTheme();
  if (currentPath === "/") {
    route_ptr = allocString("/root");
  } else {
    route_ptr = allocString(`/root${currentPath}`);
  }
  wasmInstance.renderUI(route_ptr);
  const global_style_ptr = wasmInstance.getGlobalVariablesPtr();
  const global_style_len = wasmInstance.getGlobalVariablesLen();
  if (global_style_ptr !== 0) {
    const global_css = readWasmString(global_style_ptr, global_style_len);
    injectCSS(global_css);
  }

  const css = readWasmString(wasmInstance.getCSS(), wasmInstance.getCSSLen());
  injectCSS(css);

  const animations_ptr = wasmInstance.getAnimationsPtr();
  if (animations_ptr > 0) {
    const animations_len = wasmInstance.getAnimationsLen();
    const animations_css = readWasmString(animations_ptr, animations_len);
    injectCSS(animations_css);
  }

  const edges_ptr = wasmInstance.getEdgesPtr();
  if (edges_ptr > 0) {
    const edges_len = wasmInstance.getEdgesLen();
    const edges_css = readWasmString(edges_ptr, edges_len);
    injectCSS(edges_css);
  }

  const polygons_ptr = wasmInstance.getPolygonsPtr();
  if (polygons_ptr > 0) {
    const polygons_len = wasmInstance.getPolygonsLen();
    const polygons_css = readWasmString(polygons_ptr, polygons_len);
    injectCSS(polygons_css);
  }

  // render();
  // const start = performance.now();
  activeNodeIds = new Set();
  const rootUINode = wasmInstance.getRenderUINodeRootPtr();
  traverseUINodes(root, rootUINode);
  if (state.initial_render) {
    sweep();
  }
  state.initial_render = false;
  markReady();
  // callDestroyFncs();
  removeInactiveNodes();
  wasmInstance.markCurrentTreeNotDirty();
  wasmInstance.resetRerender();

  const hash = window.location.hash;
  if (hash) {
    const id = window.location.hash.substring(1, hash.length);
    const element = document.getElementById(id);
    if (element) {
      element.scrollIntoView({});
    }
  }

  requestAnimationFrame(() => {
    requestAnimationFrame(() => {
      const toFire = Array.from(invokedHooks.keys());
      invokedHooks.clear();
      for (const key of toFire) {
        wasmInstance.invokeHooksErasedCallback(key);
      }
    });
  });

  // queueMicrotask(() => {
  //   const toFire = Array.from(invokedHooks.keys());
  //   invokedHooks.clear();
  //   for (const key of toFire) {
  //     wasmInstance.invokeHooksErasedCallback(key);
  //   }
  // });
}

function readAllRenderCommands(baseOffset, count) {
  const view = new DataView(wasmInstance.memory.buffer);
  // const mem = new Uint8Array(wasmInstance.memory.buffer);

  const commands = new Array(count);

  for (let i = 0; i < count; i++) {
    const offset = baseOffset + i * layoutInfo.renderCommandSize;

    let css = "";
    let keyFrames = "";
    let styleId = "";
    let id = "";
    let btnId = 0;
    let hoverCss = "";
    let focusCss = "";
    let focusWithinCss = "";
    let tooltipCss = "";
    let tooltipTitle = "";
    let exitAnimationId = null;

    const elemType = view.getUint8(offset + layoutInfo.elemTypeOffset);

    const nodePtr = view.getUint32(offset + layoutInfo.nodePtrOffset, true);
    const isDirty = wasmInstance.getDirtyValue(nodePtr);

    // For text, you need to handle the string slice differently
    const textPtr = view.getUint32(offset + layoutInfo.textPtrOffset, true);
    const textLen = view.getUint32(offset + layoutInfo.textPtrOffset + 4, true);

    const hrefPtr = view.getUint32(offset + layoutInfo.hrefPtrOffset, true);
    const hrefLen = view.getUint32(offset + layoutInfo.hrefPtrOffset + 4, true);
    const changedStyle = view.getUint8(
      offset + layoutInfo.styleChangedOffset,
      true,
    );
    // const hasChildren = view.getUint8(
    //   offset + layoutInfo.hasChildrenOffset,
    //   true,
    // );

    const idPtr = view.getUint32(offset + layoutInfo.idPtrOffset, true);
    const idLen = view.getUint32(offset + layoutInfo.idPtrOffset + 4, true);
    id = idPtr ? readWasmString(idPtr, idLen) : "";
    const hash = view.getUint32(offset + layoutInfo.hashOffset, true);
    const index = view.getUint32(offset + layoutInfo.indexOffset, true);

    let hooks = {};
    if (isDirty) {
      hooks = {
        createdId: view.getUint32(offset + layoutInfo.hooksOffset, true),
        mountedId: view.getUint32(offset + layoutInfo.hooksOffset + 4, true),
        updatedId: view.getUint32(offset + layoutInfo.hooksOffset + 8, true),
        destroyId: view.getUint32(offset + layoutInfo.hooksOffset + 12, true),
      };

      const classnamePtrOffset = layoutInfo.classnamePtrOffset;

      // 2. Read the actual pointer value from the RenderCommand struct.
      const classnamePtr = view.getUint32(offset + classnamePtrOffset, true);

      // 3. If the pointer is not null, read the length and then the string.
      if (classnamePtr) {
        // The length is ALWAYS 4 bytes after the pointer for a slice.
        const classnameLen = view.getUint32(
          offset + classnamePtrOffset + 4,
          true,
        );

        const classname = readWasmString(classnamePtr, classnameLen);
        styleId = classname;
      }
    }

    const stateType = view.getUint32(
      offset + layoutInfo.renderTypeOffset,
      true,
    );

    const props = {
      css,
      hoverCss,
      focusCss,
      focusWithinCss,
      btnId,
      keyFrames,
      tooltipCss,
      tooltipTitle,
      textPtr,
      textLen,
      hrefPtr,
      hrefLen,
      // hasChildren,
    };

    commands[i] = {
      elemType,
      props,
      id,
      index,
      hooks,
      nodePtr,
      exitAnimationId,
      styleId,
      hash,
      isDirty,
      stateType,
      changedStyle,
    };
  }

  return commands;
}

// function injectCSS(cssString) {
//   const sheet = new CSSStyleSheet();
//   sheet.replaceSync(cssString);
//   document.adoptedStyleSheets = [sheet, ...document.adoptedStyleSheets];
//   console.log(document.adoptedStyleSheets);
// }

// Create ONE global stylesheet
// const styleSheet = new CSSStyleSheet();
document.adoptedStyleSheets = [...document.adoptedStyleSheets, styleSheet];

function clearCSS() {
  styleSheet.replaceSync("");
  // document.adoptedStyleSheets = [];
}

export function injectCSS(cssString) {
  const existingRules = Array.from(styleSheet.cssRules)
    .map((rule) => rule.cssText)
    .join("\n");

  const finalCSS = `${existingRules}\n${cssString}`;
  styleSheet.replaceSync(finalCSS);
  rebuildCacheFromStylesheet();
}

export function rebuildCacheFromStylesheet() {
  styleRuleCache.clear();

  for (let i = 0; i < styleSheet.cssRules.length; i++) {
    const rule = styleSheet.cssRules[i];
    // CSSStyleRule has selectorText, other rule types (like @keyframes) don't
    if (rule.selectorText) {
      // Handle pseudo-selectors like .intr_123:hover
      // We want to cache as ".intr_123" not ".intr_123:hover"
      let selector = rule.selectorText;

      // If you want the full selector including :hover
      styleRuleCache.set(selector, i);

      // Or if you want to normalize (strip pseudo-selectors):
      // const baseSelector = selector.split(':')[0];
      // styleRuleCache.set(baseSelector, i);
    }
  }
}

const frag = document.createDocumentFragment();
export let U8;
export let U32;
async function init() {
  root = document.getElementById("contents");

  // Show a loading state or basic structure immediately
  // root.innerHTML = '<div class="loading">Loading...</div>';
  // document.body.appendChild(root);

  // requestAnimationFrame(() => {
  setupLayoutInfo();
  setupWasiInstance();

  // });
}

export function loadSection(element) {
  const id = element.id;
  // if it does not include the id then we have already loaded this section
  if (!observeredSections.has(id)) {
    return;
  }
  const section = observeredSections.get(id);
  wasmInstance.markUINodeTreeDirty(section.renderCmd.nodePtr);
  traverse(element, true, section.treeNodePtr, layoutInfo);
}
export function handleIntersection() {
  const options = {
    root: null,
    rootMargin: "0px", // Only 50px buffer at bottom
    threshold: 0.1,
  };
  const observer = new IntersectionObserver((entries) => {
    entries.forEach((entry) => {
      if (entry.isIntersecting && !loadedSections.has(entry.target.id)) {
        debug("Intersection", entry.target.id);
        loadedSections.add(entry.target.id);
        loadSection(entry.target);
      }
    });
  }, options);

  // Observe all <section> elements
  document.querySelectorAll("section").forEach((section) => {
    observer.observe(section);
  });
}

let route_ptr = null;

export function requestRerender() {
  if (!state.isRenderScheduled) {
    state.isRenderScheduled = true;
    requestAnimationFrame(render);
  }
}

let dirty_count = 0;
export async function render() {
  dirty_count = 0;
  resetTimers();
  // Reset the flag since the scheduled render is now running.
  state.isRenderScheduled = false;

  const globalRerender = wasmInstance.shouldRerender();

  if (!globalRerender) {
    // queueMicrotask(() => {
    //   const toFire = Array.from(invokedHooks.keys());
    //   invokedHooks.clear();
    //   for (const key of toFire) {
    //     wasmInstance.invokeHooksErasedCallback(key);
    //   }
    //
    //   // A hook may have dirtied state and scheduled another render.
    //   // If so, that render is now the "last" pass — let IT call onLayout.
    //   if (state.isRenderScheduled || wasmInstance.shouldRerender()) {
    //     return;
    //   }
    //
    //   // Nothing pending: DOM is final. Wait for paint, then measure.
    //   requestAnimationFrame(() => {
    //     requestAnimationFrame(() => {
    //       console.log("Calling onLayoutCallback");
    //       wasmInstance.onLayoutCallback();
    //     });
    //   });
    // });
    return;
  }

  try {
    if (globalRerender) {
      currentPath = window.location.pathname;
      const route_ptr = allocString(
        currentPath === "/" ? "/root" : `/root${currentPath}`,
      );

      wasmInstance.renderUI(route_ptr);

      const has_dirty = wasmInstance.hasDirty();

      const count = wasmInstance.removalCount();

      for (let i = 0; i < count; i++) {
        const ptr = wasmInstance.getRemovalIdPtr(i);
        const len = wasmInstance.getRemovalIdLen(i);
        const id = readWasmString(ptr, len);

        const elements = document.querySelectorAll(`[id="${id}"]`);
        if (elements.length === 1) {
          animateExit(elements[0], i).catch((e) =>
            console.error("Error destroying node:", e, elements[0]),
          );
        }
      }

      wasmInstance.clearRemovalQueueRetainingCapacity();

      if (has_dirty) {
        tree_node = wasmInstance.getRenderTreePtr();
        const rootUINode = wasmInstance.getRenderUINodeRootPtr();

        activeNodeIds = new Set();

        root = document.getElementById("contents");
        traverseUINodes(root, rootUINode);

        state.initial_render = false;
        markReady();
        removeInactiveNodes();
        wasmInstance.markCurrentTreeNotDirty();
        wasmInstance.resetRerender();
        wasmInstance.registerAllListenerCallbacks();

        queueMicrotask(() => {
          const toFire = Array.from(invokedHooks.keys());
          invokedHooks.clear();
          for (const key of toFire) {
            wasmInstance.invokeHooksErasedCallback(key);
          }

          // A hook may have dirtied state and scheduled another render.
          // If so, that render is now the "last" pass — let IT call onLayout.
          if (state.isRenderScheduled || wasmInstance.shouldRerender()) {
            return;
          }

          // Nothing pending: DOM is final. Wait for paint, then measure.
          if (wasmInstance.hasLayoutFunctions()) {
            requestAnimationFrame(() => {
              requestAnimationFrame(() => {
                wasmInstance.onLayoutCallback();
              });
            });
          }
        });
      }
    } else {
      debug("Grain Rerender");
    }
  } catch (error) {
    console.error("An error occurred during the render cycle:", error);
  }
}

export function callDestroyFncs() {
  // Remove any nodes that aren't active in this render
  domNodeRegistry.forEach((node, nodeId) => {
    if (!activeNodeIds.has(nodeId)) {
      if (node.destroy_hash === undefined) {
        debug("destroy_hash", nodeId, node);
      }
      try {
        if (node.destroy_hash > 0) {
          debug("destroy_hash", node.destroy_hash);
          wasmInstance.invokeErasedCallback(node.destroy_hash);
        }
      } catch (e) {
        console.error("Error calling destroy callback", e, nodeId, node);
      }
    }
  });
}

function removeAnimatedNodeTree(el) {
  for (const child of el.children) {
    toRemove = removeByIdSwap(toRemove, child.id);
    removeAnimatedNodeTree(child);
  }
}

const removeByIdSwap = (arr, idToRemove) => {
  const idx = arr.findIndex((item) => item.nodeId === idToRemove);
  if (idx !== -1) {
    // Move the last element into the “hole” and pop
    arr[idx] = arr[arr.length - 1];
    arr.pop();
  }
  return arr;
};

let toRemove = [];
export function removeInactiveNodes() {
  // Remove any nodes that aren't active in this render
  toRemove = [];
  // 3) schedule each’s exit animation
  toRemove.forEach(({ node, nodeId }) => {
    const el = node.domNode;
    const exitClass = node.exitAnimationId;
    if (exitClass) {
      removeAnimatedNodeTree(el);
      // listen → add class → on end remove
      const onEnd = (e) => {
        if (e.animationName === exitClass) {
          el.removeEventListener("animationend", onEnd);
          el.remove();
        }
      };
      el.addEventListener("animationend", onEnd);
      el.classList.add(exitClass);
    } else {
      // no animation, just yank it
      if (node.elementType === COMPONENT_TYPES.HOOKS) {
        const idPtr = allocString(nodeId);
        wasmInstance.hooksRemoveMountedKey(idPtr);
      }
      el.remove();
    }
  });
}

function sweep() {
  const managed = root.querySelectorAll("[data-vp]");
  for (const el of managed) {
    if (!domNodeRegistry.has(el.id)) {
      el.remove();
    }
  }
}

// Function to read a RenderCommand from memory
// Essentially we are just reading out a giant memory file and using alignment
// and ptr to access the data then we convert the values to readable js values
export let view;
export function readRenderCommand(offset, layout) {
  const view = new DataView(
    wasmInstance.memory.buffer,
    offset,
    layoutInfo.renderCommandSize,
  );

  let css = "";
  let keyFrames = "";
  let styleId = "";
  let id = "";
  let btnId = 0;
  let hoverCss = "";
  let focusCss = "";
  let focusWithinCss = "";
  let tooltipCss = "";
  let tooltipTitle = "";
  let exitAnimationId = null;

  const elemType = view.getUint8(layoutInfo.elemTypeOffset);

  const nodePtr = view.getUint32(layoutInfo.nodePtrOffset, true);
  const isDirty = wasmInstance.getDirtyValue(nodePtr);

  // For text, you need to handle the string slice differently
  const textPtr = view.getUint32(layoutInfo.textPtrOffset, true);
  const textLen = view.getUint32(layoutInfo.textPtrOffset + 4, true);

  const hrefPtr = view.getUint32(layoutInfo.hrefPtrOffset, true);
  const hrefLen = view.getUint32(layoutInfo.hrefPtrOffset + 4, true);
  const hasChildren = view.getUint8(layoutInfo.hasChildrenOffset, true);

  const idPtr = view.getUint32(layoutInfo.idPtrOffset, true);
  const idLen = view.getUint32(layoutInfo.idPtrOffset + 4, true);
  id = idPtr ? readWasmString(idPtr, idLen) : "";
  const index = view.getUint32(layoutInfo.indexOffset, true);
  let hooks = {};
  let changedStyle = 0;
  let changedProps = 0;

  if (isDirty) {
    changedStyle = view.getUint8(layoutInfo.styleChangedOffset, true);
    changedProps = view.getUint8(layoutInfo.propsChangedOffset, true);
    hooks = {
      createdId: view.getUint32(layoutInfo.hooksOffset, true),
      mountedId: view.getUint32(layoutInfo.hooksOffset + 4, true),
      updatedId: view.getUint32(layoutInfo.hooksOffset + 8, true),
      destroyId: view.getUint32(layoutInfo.hooksOffset + 12, true),
    };

    // if (cssStylePtr !== 0) {
    // 1. Get the offset of the classname's POINTER from our new layout object.
    const classnamePtrOffset = layoutInfo.classnamePtrOffset;

    // 2. Read the actual pointer value from the RenderCommand struct.
    const classnamePtr = view.getUint32(classnamePtrOffset, true);

    // 3. If the pointer is not null, read the length and then the string.
    if (classnamePtr) {
      // The length is ALWAYS 4 bytes after the pointer for a slice.
      const classnameLen = view.getUint32(classnamePtrOffset + 4, true);

      const classname = readWasmString(classnamePtr, classnameLen);
      styleId = classname;
    }
    // }
    // if (wasmInstance.hasEctClasses(nodePtr)) {
    //   wasmInstance.addEctClasses(nodePtr);
    // }
  }

  const stateType = view.getUint32(layoutInfo.renderTypeOffset, true);

  const props = {
    css,
    hoverCss,
    focusCss,
    focusWithinCss,
    btnId,
    keyFrames,
    textPtr,
    textLen,
    tooltipCss,
    tooltipTitle,
    hasChildren,
    hrefPtr,
    hrefLen,
  };

  return {
    elemType,
    props,
    id,
    index,
    hooks,
    nodePtr,
    exitAnimationId,
    styleId,
    isDirty,
    stateType,
    changedStyle,
    changedProps,
    // ... other fields
  };
}
let memoryView = null;
let memoryBuffer = null;
function getMemoryView() {
  // Only recreate if buffer changed (after memory growth)
  if (memoryBuffer !== wasmInstance.memory.buffer) {
    memoryBuffer = wasmInstance.memory.buffer;
    memoryView = new DataView(memoryBuffer);
  }
  return memoryView;
}

export function readUINode(offset) {
  const view = getMemoryView();

  const isDirty = view.getUint8(offset + UINodelayoutInfo.dirtyOffset);

  const onCallbacksOffsetMount = view.getUint32(
    offset + UINodelayoutInfo.onCallbacksOffset,
    true,
  );

  const onCallbacksOffsetUpdate = view.getUint32(
    offset + UINodelayoutInfo.onCallbacksOffset + 4,
    true,
  );

  const onCallbacksOffsetDestroy = view.getUint32(
    offset + UINodelayoutInfo.onCallbacksOffset + 8,
    true,
  );

  // Fast path for non-dirty nodes
  if (!isDirty) {
    const hash = Number(
      view.getUint32(offset + UINodelayoutInfo.hashOffset, true),
    );
    const idPtr = view.getUint32(offset + UINodelayoutInfo.idPtrOffset, true);
    const idLen = view.getUint32(
      offset + UINodelayoutInfo.idPtrOffset + 4,
      true,
    );
    const id = idPtr ? readWasmString(idPtr, idLen) : "";
    // const id = Number(
    //   view.getUint32(offset + UINodelayoutInfo.hashOffset, true),
    // );
    // const hash = id;
    return {
      id,
      isDirty: false,
      // Minimal fields - rest undefined/default
      elemType: 0,
      index: 0,
      textPtr: 0,
      textLen: 0,
      hrefPtr: 0,
      hrefLen: 0,
      offset,
      styleId: "",
      changedStyle: 0,
      changedProps: 0,
      hooks: {},
      hash,
      onCallbacks: [
        onCallbacksOffsetMount >>> 0,
        onCallbacksOffsetUpdate >>> 0,
        onCallbacksOffsetDestroy >>> 0,
      ],
      hooksChanged: 0,
      morph: false,
      layer: 0,
    };
  }

  dirty_count += 1;

  // Full read for dirty nodes
  const elemType = view.getUint8(offset + UINodelayoutInfo.elemTypeOffset);
  const index = view.getUint32(offset + UINodelayoutInfo.indexOffset, true);
  const idPtr = view.getUint32(offset + UINodelayoutInfo.idPtrOffset, true);
  const idLen = view.getUint32(offset + UINodelayoutInfo.idPtrOffset + 4, true);
  const id = idPtr ? readWasmString(idPtr, idLen) : "";
  const hash = Number(
    view.getUint32(offset + UINodelayoutInfo.hashOffset, true),
  );
  // const hash = id;
  // readtime += performance.now() - start;

  let textPtr = 0,
    textLen = 0;
  let hrefPtr = 0,
    hrefLen = 0;
  let hooks = {};

  if (
    elemType === COMPONENT_TYPES.TEXT ||
    elemType === COMPONENT_TYPES.LABEL ||
    elemType === COMPONENT_TYPES.HEADING ||
    elemType === COMPONENT_TYPES.ALLOC_TEXT ||
    elemType === COMPONENT_TYPES.HEADER ||
    elemType === COMPONENT_TYPES.TEXT_AREA ||
    elemType === COMPONENT_TYPES.TEXT_FIELD ||
    elemType === COMPONENT_TYPES.CODE ||
    elemType === COMPONENT_TYPES.SVG ||
    elemType === COMPONENT_TYPES.HTML_TEXT ||
    elemType === COMPONENT_TYPES.TEXT_AREA
  ) {
    textPtr = view.getUint32(offset + UINodelayoutInfo.textPtrOffset, true);
    textLen = view.getUint32(offset + UINodelayoutInfo.textPtrOffset + 4, true);
  }

  if (
    elemType === COMPONENT_TYPES.LINK ||
    elemType === COMPONENT_TYPES.REDIRECT_LINK ||
    elemType === COMPONENT_TYPES.EMBEDLINK ||
    elemType === COMPONENT_TYPES.EMBEDICON ||
    elemType === COMPONENT_TYPES.IMAGE ||
    elemType === COMPONENT_TYPES.GRAPHIC ||
    elemType === COMPONENT_TYPES.ICON ||
    elemType === COMPONENT_TYPES.IFRAME
  ) {
    hrefPtr = view.getUint32(offset + UINodelayoutInfo.hrefPtrOffset, true);
    hrefLen = view.getUint32(offset + UINodelayoutInfo.hrefPtrOffset + 4, true);
  }

  if (
    elemType === COMPONENT_TYPES.HOOKS ||
    elemType === COMPONENT_TYPES.HOOKS_CTX
  ) {
    hooks = {
      createdId: view.getUint32(offset + UINodelayoutInfo.hooksOffset, true),
      mountedId: view.getUint32(
        offset + UINodelayoutInfo.hooksOffset + 4,
        true,
      ),
      updatedId: view.getUint32(
        offset + UINodelayoutInfo.hooksOffset + 8,
        true,
      ),
      destroyId: view.getUint32(
        offset + UINodelayoutInfo.hooksOffset + 12,
        true,
      ),
    };
  }

  const style_hash = view.getUint32(
    offset + UINodelayoutInfo.styleHashOffset,
    true,
  );

  const accessibility = view.getUint8(
    offset + UINodelayoutInfo.accessibilityOffset,
    true,
  );

  // In hot path
  let styleId = "";
  if (style_hash) {
    styleId = styleClassCache[style_hash]; // Direct property access
    if (styleId === undefined) {
      const classnamePtr = view.getUint32(
        offset + UINodelayoutInfo.classnamePtrOffset,
        true,
      );
      if (classnamePtr) {
        const classnameLen = view.getUint32(
          offset + UINodelayoutInfo.classnamePtrOffset + 4,
          true,
        );
        styleId = readWasmString(classnamePtr, classnameLen);
        styleClassCache[style_hash] = styleId;
      }
    }
  }

  return {
    id,
    elemType,
    index,
    textPtr,
    textLen,
    hrefPtr,
    hrefLen,
    offset,
    styleId,
    isDirty: true,
    changedStyle: view.getUint8(offset + UINodelayoutInfo.styleChangedOffset),
    changedProps: view.getUint8(offset + UINodelayoutInfo.propsChangedOffset),
    hooks,
    hash,
    accessibility,
    onCallbacks: [
      onCallbacksOffsetMount >>> 0,
      onCallbacksOffsetUpdate >>> 0,
      onCallbacksOffsetDestroy >>> 0,
    ],
    hooksChanged: view.getUint8(offset + UINodelayoutInfo.hooksChangedOffset),
    morph:
      view.getUint8(offset + UINodelayoutInfo.morphOffset) > 0 ? true : false,
    layer: view.getUint8(offset + UINodelayoutInfo.layerOffset),
  };
}
// ✅ Faster: Reuse decoder (2-3x faster)
const textDecoder = new TextDecoder();

export function readWasmString(ptr, len) {
  if (len === 0) return "";
  const bytes = new Uint8Array(wasmInstance.memory.buffer, ptr, len);
  return textDecoder.decode(bytes);
}
// export function readWasmString(ptr, len) {
//   const bytes = new Uint8Array(wasmInstance.memory.buffer, ptr, len);
//   return new TextDecoder().decode(bytes);
// }

// Check if memory is growing over time
// Get total WASM memory size

function getWasmMemoryUsage() {
  const memory = wasmInstance.memory;
  return memory.buffer.byteLength;
}

// Monitor memory growth
let lastMemorySize = 0;
export function checkMemoryGrowth() {
  const currentSize = getWasmMemoryUsage();
  const pages = currentSize / (64 * 1024); // WASM pages are 64KB

  debug(`Total memory: ${currentSize / 1024 / 1024} MB (${pages} pages)`);

  if (currentSize > lastMemorySize) {
    debug(`Memory grew by ${(currentSize - lastMemorySize) / 1024} KB`);
  }
  lastMemorySize = currentSize;
  return pages;
}

// Get more detailed info if your WASM exports these functions
function getDetailedMemoryInfo() {
  if (wasmInstance.get_stack_pointer) {
    const stackPtr = wasmInstance.get_stack_pointer();
    debug(`Stack pointer: 0x${stackPtr.toString(16)}`);
  }

  if (wasmInstance.get_heap_size) {
    const heapSize = wasmInstance.get_heap_size();
    debug(`Heap usage: ${heapSize / 1024} KB`);
  }
}
initWasi();
