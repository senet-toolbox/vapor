/**
 * File input and download bindings (core runtime).
 * Optional browser APIs live in ./browser/ and load on demand.
 */

import { eventStorage } from "./maps.js";
import { WasmObjectBuilder, wasmInstance } from "./wasi.js";
import { readWasmString, allocString } from "./wasi_obj.js";

// ============================================================================
// Storage for handles and state
// ============================================================================

const fileInputCallbacks = new Map();

function requireWasm() {
  if (!wasmInstance) {
    console.error("WASM instance not initialized");
    return false;
  }
  return true;
}

// ============================================================================
// FILE HANDLING
// ============================================================================

export const fileBindings = {
  triggerFileInputWasm: (idPtr, idLen) => {
    if (!requireWasm()) return;
    const id = readWasmString(idPtr, idLen);
    const input = document.getElementById(id);
    if (input) {
      input.click();
    }
  },

  getFileCountWasm: (eventId) => {
    const event = window._eventStorage?.[eventId];
    if (!event?.target?.files) return 0;
    return event.target.files.length;
  },

  getFileInfoWasm: (eventId, fileIndex) => {
    const id = eventId >>> 0;
    const event = eventStorage[id];

    const file = event.target.files[fileIndex];
    const info = {
      name: file.name,
      size: file.size,
      type: file.type,
      // lastModified: file.lastModified,
    };
    const builder = new WasmObjectBuilder(wasmInstance, wasmInstance.memory);
    const handle = builder.passObject(info);
    return handle;
  },

  readFileAsTextWasm: (eventId, fileIndex, callbackId) => {
    const id = eventId >>> 0;
    const callback = callbackId >>> 0;
    const event = eventStorage[id];
    const file = event?.target?.files?.[fileIndex];
    if (!file) {
      // wasmInstance.resumeCallback(callbackId, allocString(""));
      return null;
    }

    const reader = new FileReader();
    reader.onload = () => {
      if (!requireWasm()) return;
      const fileData = {
        contents: reader.result,
      };
      const builder = new WasmObjectBuilder(wasmInstance, wasmInstance.memory);
      const handle = builder.passObject(fileData);
      wasmInstance.readObject(callback, handle);
    };
    reader.onerror = () => {
      // wasmInstance.resumeCallback(callbackId, allocString(""));
    };
    reader.readAsText(file);
  },

  readFileAsBase64Wasm: (eventId, fileIndex, callbackId) => {
    const event = window._eventStorage?.[eventId];
    const file = event?.target?.files?.[fileIndex];
    if (!file) {
      wasmInstance.resumeCallback(callbackId, allocString(""));
      return;
    }

    const reader = new FileReader();
    reader.onload = () => {
      // Remove data URL prefix to get just base64
      const base64 = reader.result.split(",")[1] || "";
      const ptr = allocString(base64);
      wasmInstance.resumeCallback(callbackId, ptr);
    };
    reader.onerror = () => {
      wasmInstance.resumeCallback(callbackId, allocString(""));
    };
    reader.readAsDataURL(file);
  },

  readFileAsArrayBufferWasm: (eventId, fileIndex, callbackId) => {
    const event = window._eventStorage?.[eventId];
    const file = event?.target?.files?.[fileIndex];
    if (!file) {
      wasmInstance.resumeCallback(callbackId, 0);
      return;
    }

    const reader = new FileReader();
    reader.onload = () => {
      const buffer = new Uint8Array(reader.result);
      const ptr = wasmInstance.allocate(buffer.length);
      new Uint8Array(wasmInstance.memory.buffer, ptr, buffer.length).set(
        buffer,
      );
      wasmInstance.resumeCallback(callbackId, ptr);
    };
    reader.onerror = () => {
      wasmInstance.resumeCallback(callbackId, 0);
    };
    reader.readAsArrayBuffer(file);
  },

  downloadFileWasm: (namePtr, nameLen, dataPtr, dataLen, mimePtr, mimeLen) => {
    if (!requireWasm()) return;
    const name = readWasmString(namePtr, nameLen);
    const data = readWasmString(dataPtr, dataLen);
    const mime = readWasmString(mimePtr, mimeLen);

    const blob = new Blob([data], { type: mime });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = name;
    a.click();
    URL.revokeObjectURL(url);
  },

  downloadBinaryFileWasm: (
    namePtr,
    nameLen,
    dataPtr,
    dataLen,
    mimePtr,
    mimeLen,
  ) => {
    if (!requireWasm()) return;
    const name = readWasmString(namePtr, nameLen);
    const mime = readWasmString(mimePtr, mimeLen);
    const data = new Uint8Array(wasmInstance.memory.buffer, dataPtr, dataLen);

    const blob = new Blob([data], { type: mime });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = name;
    a.click();
    URL.revokeObjectURL(url);
  },

  // 1. Create a Blob URL (e.g., "blob:http://localhost/...")
  // Returns a pointer to the string that you can use as an <img> src
  createObjectURLWasm: (eventId, fileIndex) => {
    if (!requireWasm()) return 0;

    // Normalize event ID and lookup
    const id = eventId >>> 0;
    const event = eventStorage[id];
    const file = event?.target?.files?.[fileIndex];

    if (!file) return 0; // Return null pointer if file not found

    const url = URL.createObjectURL(file);

    // Allocates the string in WASM memory and returns the pointer.
    // NOTE: This assumes `allocString` is available in your scope
    // (as implied by your usage in readFileAsBase64Wasm)
    return allocString(url);
  },

  // 2. Revoke the Blob URL to free up browser memory
  // Should be called when the image is unloaded or component is destroyed
  revokeObjectURLWasm: (urlPtr, urlLen) => {
    if (!requireWasm()) return;

    const url = readWasmString(urlPtr, urlLen);
    if (url) {
      URL.revokeObjectURL(url);
    }
  },
  /**
   * Reads a file and returns the full Data URL string (e.g., "data:image/png;base64,...").
   * Useful for directly setting an <img> src attribute without needing to modify the string in WASM.
   * * @param eventId The stored event ID.
   * @param fileIndex Index of the file in the event's file list.
   * @param callbackId The WASM callback ID to resume execution.
   */
  readFileAsDataURLWasm: (eventId, fileIndex, callbackId) => {
    if (!requireWasm()) return;
    const event = eventStorage[eventId];
    const file = event?.target?.files?.[fileIndex];

    if (!file) {
      wasmInstance.resumeCallback(callbackId, allocString(""));
      return;
    }

    const reader = new FileReader();
    reader.onload = () => {
      if (!requireWasm()) return;
      // reader.result contains the full Data URL string
      const dataURL = reader.result;
      const ptr = allocString(dataURL);
      wasmInstance.resumeCallback(callbackId, ptr);
    };
    reader.onerror = () => {
      // Error handling: return an empty string or null pointer
      wasmInstance.resumeCallback(callbackId, allocString(""));
    };
    reader.readAsDataURL(file); // Reads file and returns full Data URL string
  },

  /**
   * Reads a file and provides a progress update callback during reading.
   * * @param eventId The stored event ID.
   * @param fileIndex Index of the file.
   * @param onloadCallbackId Callback for when the file is finished reading.
   * @param onprogressCallbackId Callback for progress updates (called multiple times).
   */
  readFileWithProgressWasm: (
    eventId,
    fileIndex,
    onloadCallbackId,
    onprogressCallbackId,
  ) => {
    if (!requireWasm()) return;
    const event = eventStorage[eventId];
    const file = event?.target?.files?.[fileIndex];

    if (!file) {
      wasmInstance.resumeCallback(onloadCallbackId, 0);
      return;
    }

    const reader = new FileReader();

    // 1. onload event (Same as readFileAsArrayBufferWasm, returning the data)
    reader.onload = () => {
      if (!requireWasm()) return;
      const buffer = new Uint8Array(reader.result);
      const ptr = wasmInstance.allocate(buffer.length);
      new Uint8Array(wasmInstance.memory.buffer, ptr, buffer.length).set(
        buffer,
      );
      // Resume WASM execution with the allocated data pointer
      wasmInstance.resumeCallback(onloadCallbackId, ptr);
    };

    // 2. onprogress event
    reader.onprogress = (e) => {
      if (!requireWasm() || !e.lengthComputable) return;

      // Pass a data object containing total, loaded, and percentage
      const progressInfo = {
        loaded: e.loaded,
        total: e.total,
        percent: Math.round((e.loaded / e.total) * 100),
      };

      const builder = new WasmObjectBuilder(wasmInstance, wasmInstance.memory);
      const handle = builder.passObject(progressInfo);

      // This assumes your WASM side can handle a separate, non-resuming callback (readObject)
      wasmInstance.readObject(onprogressCallbackId, handle);
    };

    reader.onerror = () => {
      // Resume onload callback with error/null data
      wasmInstance.resumeCallback(onloadCallbackId, 0);
    };

    // We use readAsArrayBuffer since the progress logic is typically used for large binary files
    reader.readAsArrayBuffer(file);
  },
};
