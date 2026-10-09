import { rt } from "./runtime.js";

// ============================================================================
// POINTER LOCK
// ============================================================================

export const pointerLockBindings = {
  requestPointerLockWasm: (idPtr, idLen) => {
    const id = rt.readWasmString(idPtr, idLen);
    const element = document.getElementById(id);
    if (!element) return 0;

    try {
      element.requestPointerLock();
      return 1;
    } catch (e) {
      return 0;
    }
  },

  exitPointerLockWasm: () => {
    document.exitPointerLock();
  },

  isPointerLockedWasm: () => {
    return document.pointerLockElement ? 1 : 0;
  },

  onPointerLockChangeWasm: (callbackId) => {
    document.addEventListener("pointerlockchange", () => {
      rt.wasmInstance.callbackCtx(callbackId, document.pointerLockElement ? 1 : 0);
    });
  },
};
