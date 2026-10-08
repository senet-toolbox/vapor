// State the optional browser bindings share with the core runtime. The core
// fills it in (see ./index.js `install` / `setInstance`): this bundle is
// loaded separately, so it cannot import the core's modules directly.
export const rt = {
  wasmInstance: null,
  readWasmString: null,
  allocString: null,
  requireWasm() {
    if (!rt.wasmInstance) {
      console.error("WASM instance not initialized");
      return false;
    }
    return true;
  },
};
