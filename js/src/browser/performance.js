import { rt } from "./runtime.js";

// ============================================================================
// PERFORMANCE TIMING
// ============================================================================

export const performanceBindings = {
  performanceMarkWasm: (namePtr, nameLen) => {
    const name = rt.readWasmString(namePtr, nameLen);
    performance.mark(name);
  },

  performanceMeasureWasm: (
    namePtr,
    nameLen,
    startMarkPtr,
    startMarkLen,
    endMarkPtr,
    endMarkLen,
  ) => {
    const name = rt.readWasmString(namePtr, nameLen);
    const startMark = rt.readWasmString(startMarkPtr, startMarkLen);
    const endMark = rt.readWasmString(endMarkPtr, endMarkLen);

    try {
      performance.measure(name, startMark, endMark);
      return 1;
    } catch (e) {
      return 0;
    }
  },

  performanceGetEntriesByNameWasm: (namePtr, nameLen) => {
    const name = rt.readWasmString(namePtr, nameLen);
    const entries = performance.getEntriesByName(name);
    return rt.allocString(JSON.stringify(entries));
  },

  performanceClearMarksWasm: (namePtr, nameLen) => {
    const name = rt.readWasmString(namePtr, nameLen);
    if (name) {
      performance.clearMarks(name);
    } else {
      performance.clearMarks();
    }
  },

  performanceClearMeasuresWasm: (namePtr, nameLen) => {
    const name = rt.readWasmString(namePtr, nameLen);
    if (name) {
      performance.clearMeasures(name);
    } else {
      performance.clearMeasures();
    }
  },

  performanceNowWasm: () => {
    return performance.now();
  },
};
