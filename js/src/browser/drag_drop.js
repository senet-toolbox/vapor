import { rt } from "./runtime.js";

// ============================================================================
// DRAG & DROP
// ============================================================================

export const dragDropBindings = {
  getDragDataWasm: (eventId, formatPtr, formatLen) => {
    const event = window._eventStorage?.[eventId];
    if (!event?.dataTransfer) return rt.allocString("");

    const format = rt.readWasmString(formatPtr, formatLen);
    const data = event.dataTransfer.getData(format);
    return rt.allocString(data);
  },

  setDragDataWasm: (eventId, formatPtr, formatLen, dataPtr, dataLen) => {
    const event = window._eventStorage?.[eventId];
    if (!event?.dataTransfer) return;

    const format = rt.readWasmString(formatPtr, formatLen);
    const data = rt.readWasmString(dataPtr, dataLen);
    event.dataTransfer.setData(format, data);
  },

  setDragEffectWasm: (eventId, effect) => {
    const event = window._eventStorage?.[eventId];
    if (!event?.dataTransfer) return;

    const effects = ["none", "copy", "move", "link"];
    event.dataTransfer.dropEffect = effects[effect] || "none";
  },

  setDragEffectAllowedWasm: (eventId, effect) => {
    const event = window._eventStorage?.[eventId];
    if (!event?.dataTransfer) return;

    const effects = [
      "none",
      "copy",
      "move",
      "link",
      "copyMove",
      "copyLink",
      "linkMove",
      "all",
    ];
    event.dataTransfer.effectAllowed = effects[effect] || "none";
  },

  getDroppedFilesCountWasm: (eventId) => {
    const event = window._eventStorage?.[eventId];
    if (!event?.dataTransfer?.files) return 0;
    return event.dataTransfer.files.length;
  },

  getDroppedFileInfoWasm: (eventId, fileIndex) => {
    const event = window._eventStorage?.[eventId];
    const file = event?.dataTransfer?.files?.[fileIndex];
    if (!file) return rt.allocString("{}");

    const info = {
      name: file.name,
      size: file.size,
      type: file.type,
      lastModified: file.lastModified,
    };
    return rt.allocString(JSON.stringify(info));
  },

  readDroppedFileAsTextWasm: (eventId, fileIndex, callbackId) => {
    const event = window._eventStorage?.[eventId];
    const file = event?.dataTransfer?.files?.[fileIndex];
    if (!file) {
      rt.wasmInstance.resumeCallback(callbackId, rt.allocString(""));
      return;
    }

    const reader = new FileReader();
    reader.onload = () => {
      const ptr = rt.allocString(reader.result);
      rt.wasmInstance.resumeCallback(callbackId, ptr);
    };
    reader.onerror = () => {
      rt.wasmInstance.resumeCallback(callbackId, rt.allocString(""));
    };
    reader.readAsText(file);
  },

  readDroppedFileAsBase64Wasm: (eventId, fileIndex, callbackId) => {
    const event = window._eventStorage?.[eventId];
    const file = event?.dataTransfer?.files?.[fileIndex];
    if (!file) {
      rt.wasmInstance.resumeCallback(callbackId, rt.allocString(""));
      return;
    }

    const reader = new FileReader();
    reader.onload = () => {
      const base64 = reader.result.split(",")[1] || "";
      const ptr = rt.allocString(base64);
      rt.wasmInstance.resumeCallback(callbackId, ptr);
    };
    reader.onerror = () => {
      rt.wasmInstance.resumeCallback(callbackId, rt.allocString(""));
    };
    reader.readAsDataURL(file);
  },
};
