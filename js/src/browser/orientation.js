import { rt } from "./runtime.js";

// ============================================================================
// SCREEN ORIENTATION
// ============================================================================

export const orientationBindings = {
  getScreenOrientationWasm: () => {
    if (!screen.orientation) return rt.allocString("unknown");
    return rt.allocString(screen.orientation.type);
  },

  getScreenOrientationAngleWasm: () => {
    if (!screen.orientation) return 0;
    return screen.orientation.angle;
  },

  lockScreenOrientationWasm: (orientationPtr, orientationLen, callbackId) => {
    const orientation = rt.readWasmString(orientationPtr, orientationLen);

    if (!screen.orientation?.lock) {
      rt.wasmInstance.callbackCtx(callbackId, 0);
      return;
    }

    screen.orientation
      .lock(orientation)
      .then(() => rt.wasmInstance.callbackCtx(callbackId, 1))
      .catch(() => rt.wasmInstance.callbackCtx(callbackId, 0));
  },

  unlockScreenOrientationWasm: () => {
    if (screen.orientation?.unlock) {
      screen.orientation.unlock();
    }
  },

  onOrientationChangeWasm: (callbackId) => {
    if (screen.orientation) {
      screen.orientation.addEventListener("change", () => {
        rt.wasmInstance.callbackCtx(
          callbackId,
          rt.allocString(screen.orientation.type),
        );
      });
    }
  },
};
