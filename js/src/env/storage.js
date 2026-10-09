/** localStorage, cookies and the clipboard. */
import { requireWasm, wasmInstance } from "../instance.js";
import { allocStringFrame, readWasmString } from "../wasi_obj.js";

export const storageBindings = {
  // Local Storage
  setLocalStorageStringWasm: (ptr, len, valuePtr, valueLen) => {
    if (!requireWasm()) return;
    const key = readWasmString(ptr, len);
    const value = readWasmString(valuePtr, valueLen);
    localStorage.setItem(key, value);
  },
  getLocalStorageStringWasm: (ptr, len) => {
    if (!requireWasm()) return;
    const key = readWasmString(ptr, len);
    const value = localStorage.getItem(key);
    if (value === null) return null;
    return allocStringFrame(value);
  },
  setLocalStorageNumberWasm: (ptr, len, value) => {
    if (!requireWasm()) return;
    const key = readWasmString(ptr, len);
    localStorage.setItem(key, value);
  },
  getLocalStorageNumberWasm: (ptr, len) => {
    if (!requireWasm()) return;
    const key = readWasmString(ptr, len);
    const value = localStorage.getItem(key);
    return value;
  },
  getLocalStorageI32Wasm: (ptr, len) => {
    if (!requireWasm()) return;
    const key = readWasmString(ptr, len);
    const value = localStorage.getItem(key);
    return value;
  },
  getLocalStorageU32Wasm: (ptr, len) => {
    if (!requireWasm()) return;
    const key = readWasmString(ptr, len);
    const value = localStorage.getItem(key);
    return value;
  },
  removeLocalStorageWasm: (ptr, len) => {
    if (!requireWasm()) return;
    const key = readWasmString(ptr, len);
    localStorage.removeItem(key);
  },
  clearLocalStorageWasm: () => {
    localStorage.clear();
  },

  // Cookies
  setCookieWasm: (cookieStrPtr, cookieStrLen) => {
    const cookie = readWasmString(cookieStrPtr, cookieStrLen);
    document.cookie = cookie;
  },
  getCookiesWasm: () => {
    return allocStringFrame(document.cookie);
  },
  getCookieWasm: (cookieStrPtr, cookieStrLen) => {
    const cookie = readWasmString(cookieStrPtr, cookieStrLen);
    const match = document.cookie.match(new RegExp(`(^| )${cookie}=([^;]+)`));
    return match ? allocStringFrame(decodeURIComponent(match[2])) : null;
  },

  // Clipboard
  copyTextWasm: (ptr, len) => {
    if (!requireWasm()) return;
    const text = readWasmString(ptr, len);

    if (navigator.clipboard && window.isSecureContext) {
      navigator.clipboard.writeText(text).catch((err) => {
        console.error("Clipboard write failed:", err);
      });
    }
  },
  readClipboardWasm: (callbackId) => {
    navigator.clipboard
      .readText()
      .then((text) => {
        const ptr = allocStringFrame(text);
        wasmInstance.resumeCallback(callbackId, ptr);
      })
      .catch((err) => {
        wasmInstance.resumeCallback(callbackId, 0);
      });
  },
};
