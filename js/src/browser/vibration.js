import { rt } from "./runtime.js";

// ============================================================================
// VIBRATION (Mobile)
// ============================================================================

export const vibrationBindings = {
  vibrateWasm: (duration) => {
    if (!("vibrate" in navigator)) return 0;
    return navigator.vibrate(duration) ? 1 : 0;
  },

  vibratePatternWasm: (patternPtr, patternLen) => {
    if (!("vibrate" in navigator)) return 0;

    const pattern = new Uint32Array(
      rt.wasmInstance.memory.buffer,
      patternPtr,
      patternLen,
    );
    return navigator.vibrate(Array.from(pattern)) ? 1 : 0;
  },

  vibrateCancelWasm: () => {
    if ("vibrate" in navigator) {
      navigator.vibrate(0);
    }
  },
};
