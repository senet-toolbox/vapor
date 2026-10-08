import { rt } from "./runtime.js";

// ============================================================================
// SESSION STORAGE
// ============================================================================

export const sessionStorageBindings = {
  setSessionStorageStringWasm: (keyPtr, keyLen, valuePtr, valueLen) => {
    const key = rt.readWasmString(keyPtr, keyLen);
    const value = rt.readWasmString(valuePtr, valueLen);
    sessionStorage.setItem(key, value);
  },

  getSessionStorageStringWasm: (keyPtr, keyLen) => {
    const key = rt.readWasmString(keyPtr, keyLen);
    const value = sessionStorage.getItem(key);
    return rt.allocString(value || "");
  },

  setSessionStorageNumberWasm: (keyPtr, keyLen, value) => {
    const key = rt.readWasmString(keyPtr, keyLen);
    sessionStorage.setItem(key, value.toString());
  },

  getSessionStorageNumberWasm: (keyPtr, keyLen) => {
    const key = rt.readWasmString(keyPtr, keyLen);
    const value = sessionStorage.getItem(key);
    return value ? parseFloat(value) : 0;
  },

  removeSessionStorageWasm: (keyPtr, keyLen) => {
    const key = rt.readWasmString(keyPtr, keyLen);
    sessionStorage.removeItem(key);
  },

  clearSessionStorageWasm: () => {
    sessionStorage.clear();
  },

  sessionStorageLengthWasm: () => {
    return sessionStorage.length;
  },

  sessionStorageKeyWasm: (index) => {
    const key = sessionStorage.key(index);
    return rt.allocString(key || "");
  },
};
