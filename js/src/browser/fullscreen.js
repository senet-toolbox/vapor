import { rt } from "./runtime.js";

// ============================================================================
// FULLSCREEN
// ============================================================================

export const fullscreenBindings = {
  requestFullscreenWasm: (idPtr, idLen) => {
    const id = rt.readWasmString(idPtr, idLen);
    const element = document.getElementById(id);
    if (!element) return 0;

    try {
      const fn =
        element.requestFullscreen ||
        element.webkitRequestFullscreen ||
        element.mozRequestFullScreen;
      if (fn) {
        fn.call(element);
        return 1;
      }
    } catch (e) {
      console.error("Fullscreen request failed:", e);
    }
    return 0;
  },

  exitFullscreenWasm: () => {
    try {
      const fn =
        document.exitFullscreen ||
        document.webkitExitFullscreen ||
        document.mozCancelFullScreen;
      if (fn) {
        fn.call(document);
        return 1;
      }
    } catch (e) {
      console.error("Exit fullscreen failed:", e);
    }
    return 0;
  },

  isFullscreenWasm: () => {
    return document.fullscreenElement ||
      document.webkitFullscreenElement ||
      document.mozFullScreenElement
      ? 1
      : 0;
  },

  getFullscreenElementIdWasm: () => {
    const el =
      document.fullscreenElement ||
      document.webkitFullscreenElement ||
      document.mozFullScreenElement;
    return rt.allocString(el?.id || "");
  },

  onFullscreenChangeWasm: (callbackId) => {
    document.addEventListener("fullscreenchange", () => {
      rt.wasmInstance.callbackCtx(
        callbackId,
        fullscreenBindings.isFullscreenWasm(),
      );
    });
  },
};
