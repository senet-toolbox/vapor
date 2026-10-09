/** The live wasm instance and the DOM lookups every binding module shares. */
import { WasmStructBridge } from "./struct_bridge.js";
import { readWasmString } from "./wasi_obj.js";

// ============================================================================
// WASM Instance Management
// ============================================================================

export let wasmInstance = null;
export let structBridge = undefined;

// Define a cache outside the function to store DOM references
export const elementCache = new Map();

export function setWasiInstance(instance) {
  wasmInstance = instance;
}

export function setWasiStructBridge() {
  structBridge = new WasmStructBridge(wasmInstance);
  structBridge.registerSchema(
    "ObserverOptions",
    "getObserverOptionsSchema",
    "getObserverOptionsSchemaLength",
  );
}

// ============================================================================
// Helper Functions
// ============================================================================

export function requireWasm() {
  if (!wasmInstance) {
    console.error("WASM instance not initialized");
    return false;
  }
  return true;
}

export function getElement(idPtr, idLen) {
  const id = readWasmString(idPtr, idLen);
  return [id, document.getElementById(id)];
}
