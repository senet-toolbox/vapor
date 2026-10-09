/** Core runtime: panics, rerender requests, logging, timers, hooks and debug highlighting. */
import { debug } from "../debug.js";
import { requireWasm, wasmInstance } from "../instance.js";
import { afterHooksHandlers, beforeHooksHandlers, timeouts } from "../maps.js";
import { checkMemoryGrowth, readWasmString, requestRerender } from "../wasi_obj.js";
import { batchRemoveTombStones } from "../wasi_styling.js";

export const coreBindings = {
  // Core / System
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
  frame_arena_init: () => { },

  // Console / Debugging
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

  // Timers & Scheduling
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

  // Hooks
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

  // Debug Highlighting
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
};
