import { rt } from "./runtime.js";

// ============================================================================
// TEXT SELECTION
// ============================================================================

export const selectionBindings = {
  getSelectionTextWasm: () => {
    const selection = window.getSelection();
    return rt.allocString(selection?.toString() || "");
  },

  getSelectionRangeWasm: (idPtr, idLen) => {
    const id = rt.readWasmString(idPtr, idLen);
    const element = document.getElementById(id);

    const ptr = rt.wasmInstance.allocate(8);
    const view = new Uint32Array(rt.wasmInstance.memory.buffer, ptr, 2);

    if (element && "selectionStart" in element) {
      view[0] = element.selectionStart;
      view[1] = element.selectionEnd;
    } else {
      view[0] = 0;
      view[1] = 0;
    }
    return ptr;
  },

  setSelectionRangeWasm: (idPtr, idLen, start, end, direction) => {
    const id = rt.readWasmString(idPtr, idLen);
    const element = document.getElementById(id);
    if (element && "setSelectionRange" in element) {
      const dirs = ["none", "forward", "backward"];
      element.setSelectionRange(start, end, dirs[direction] || "none");
    }
  },

  selectAllWasm: (idPtr, idLen) => {
    const id = rt.readWasmString(idPtr, idLen);
    const element = document.getElementById(id);
    if (element && "select" in element) {
      element.select();
    }
  },
};
