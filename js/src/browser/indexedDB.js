import { rt } from "./runtime.js";

const idbDatabases = new Map();
let nextIdbHandle = 1;

// ============================================================================
// INDEXED DB
// ============================================================================

export const indexedDBBindings = {
  idbOpenWasm: (namePtr, nameLen, version, callbackId, errorCallbackId) => {
    const name = rt.readWasmString(namePtr, nameLen);

    const request = indexedDB.open(name, version);

    request.onerror = () => {
      rt.wasmInstance.callbackCtx(
        errorCallbackId,
        rt.allocString(request.error?.message || "Unknown error"),
      );
    };

    request.onsuccess = () => {
      const handle = nextIdbHandle++;
      idbDatabases.set(handle, request.result);
      rt.wasmInstance.callbackCtx(callbackId, handle);
    };

    request.onupgradeneeded = (event) => {
      // Store the database for object store creation during upgrade
      const handle = nextIdbHandle++;
      idbDatabases.set(handle, request.result);
    };
  },

  idbCloseWasm: (handle) => {
    const db = idbDatabases.get(handle);
    if (db) {
      db.close();
      idbDatabases.delete(handle);
    }
  },

  idbCreateObjectStoreWasm: (
    handle,
    namePtr,
    nameLen,
    keyPathPtr,
    keyPathLen,
    autoIncrement,
  ) => {
    const db = idbDatabases.get(handle);
    if (!db) return 0;

    const name = rt.readWasmString(namePtr, nameLen);
    const keyPath = rt.readWasmString(keyPathPtr, keyPathLen);

    try {
      db.createObjectStore(name, {
        keyPath: keyPath || undefined,
        autoIncrement,
      });
      return 1;
    } catch (e) {
      console.error("Create object store failed:", e);
      return 0;
    }
  },

  idbDeleteObjectStoreWasm: (handle, namePtr, nameLen) => {
    const db = idbDatabases.get(handle);
    if (!db) return 0;

    const name = rt.readWasmString(namePtr, nameLen);

    try {
      db.deleteObjectStore(name);
      return 1;
    } catch (e) {
      return 0;
    }
  },

  idbPutWasm: (
    handle,
    storeNamePtr,
    storeNameLen,
    keyPtr,
    keyLen,
    valuePtr,
    valueLen,
    callbackId,
  ) => {
    const db = idbDatabases.get(handle);
    if (!db) {
      rt.wasmInstance.callbackCtx(callbackId, 0);
      return;
    }

    const storeName = rt.readWasmString(storeNamePtr, storeNameLen);
    const key = rt.readWasmString(keyPtr, keyLen);
    const value = rt.readWasmString(valuePtr, valueLen);

    try {
      const transaction = db.transaction(storeName, "readwrite");
      const store = transaction.objectStore(storeName);
      const request = store.put(JSON.parse(value), key);

      request.onsuccess = () => rt.wasmInstance.callbackCtx(callbackId, 1);
      request.onerror = () => rt.wasmInstance.callbackCtx(callbackId, 0);
    } catch (e) {
      rt.wasmInstance.callbackCtx(callbackId, 0);
    }
  },

  idbGetWasm: (
    handle,
    storeNamePtr,
    storeNameLen,
    keyPtr,
    keyLen,
    callbackId,
  ) => {
    const db = idbDatabases.get(handle);
    if (!db) {
      rt.wasmInstance.callbackCtx(callbackId, rt.allocString("null"));
      return;
    }

    const storeName = rt.readWasmString(storeNamePtr, storeNameLen);
    const key = rt.readWasmString(keyPtr, keyLen);

    try {
      const transaction = db.transaction(storeName, "readonly");
      const store = transaction.objectStore(storeName);
      const request = store.get(key);

      request.onsuccess = () => {
        rt.wasmInstance.callbackCtx(
          callbackId,
          rt.allocString(JSON.stringify(request.result)),
        );
      };
      request.onerror = () => {
        rt.wasmInstance.callbackCtx(callbackId, rt.allocString("null"));
      };
    } catch (e) {
      rt.wasmInstance.callbackCtx(callbackId, rt.allocString("null"));
    }
  },

  idbDeleteWasm: (
    handle,
    storeNamePtr,
    storeNameLen,
    keyPtr,
    keyLen,
    callbackId,
  ) => {
    const db = idbDatabases.get(handle);
    if (!db) {
      rt.wasmInstance.callbackCtx(callbackId, 0);
      return;
    }

    const storeName = rt.readWasmString(storeNamePtr, storeNameLen);
    const key = rt.readWasmString(keyPtr, keyLen);

    try {
      const transaction = db.transaction(storeName, "readwrite");
      const store = transaction.objectStore(storeName);
      const request = store.delete(key);

      request.onsuccess = () => rt.wasmInstance.callbackCtx(callbackId, 1);
      request.onerror = () => rt.wasmInstance.callbackCtx(callbackId, 0);
    } catch (e) {
      rt.wasmInstance.callbackCtx(callbackId, 0);
    }
  },

  idbGetAllWasm: (handle, storeNamePtr, storeNameLen, callbackId) => {
    const db = idbDatabases.get(handle);
    if (!db) {
      rt.wasmInstance.callbackCtx(callbackId, rt.allocString("[]"));
      return;
    }

    const storeName = rt.readWasmString(storeNamePtr, storeNameLen);

    try {
      const transaction = db.transaction(storeName, "readonly");
      const store = transaction.objectStore(storeName);
      const request = store.getAll();

      request.onsuccess = () => {
        rt.wasmInstance.callbackCtx(
          callbackId,
          rt.allocString(JSON.stringify(request.result)),
        );
      };
      request.onerror = () => {
        rt.wasmInstance.callbackCtx(callbackId, rt.allocString("[]"));
      };
    } catch (e) {
      rt.wasmInstance.callbackCtx(callbackId, rt.allocString("[]"));
    }
  },

  idbClearStoreWasm: (handle, storeNamePtr, storeNameLen, callbackId) => {
    const db = idbDatabases.get(handle);
    if (!db) {
      rt.wasmInstance.callbackCtx(callbackId, 0);
      return;
    }

    const storeName = rt.readWasmString(storeNamePtr, storeNameLen);

    try {
      const transaction = db.transaction(storeName, "readwrite");
      const store = transaction.objectStore(storeName);
      const request = store.clear();

      request.onsuccess = () => rt.wasmInstance.callbackCtx(callbackId, 1);
      request.onerror = () => rt.wasmInstance.callbackCtx(callbackId, 0);
    } catch (e) {
      rt.wasmInstance.callbackCtx(callbackId, 0);
    }
  },

  idbDeleteDatabaseWasm: (namePtr, nameLen, callbackId) => {
    const name = rt.readWasmString(namePtr, nameLen);

    const request = indexedDB.deleteDatabase(name);
    request.onsuccess = () => rt.wasmInstance.callbackCtx(callbackId, 1);
    request.onerror = () => rt.wasmInstance.callbackCtx(callbackId, 0);
  },
};
