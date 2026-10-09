/**
 * WASM-JavaScript bindings: the `env` import object, assembled from
 * js/src/env/ by domain, plus re-exports of the shared runtime state.
 */

import { coreBindings } from "./env/core.js";
import { eventsBindings } from "./env/events.js";
import { domBindings } from "./env/dom.js";
import { navigationBindings } from "./env/navigation.js";
import { storageBindings } from "./env/storage.js";
import { networkBindings } from "./env/network.js";
import { observersBindings } from "./env/observers.js";
import { mediaBindings } from "./env/media.js";

export { wasmInstance, structBridge, elementCache, setWasiInstance, setWasiStructBridge, requireWasm, getElement } from "./instance.js";
export { EventType } from "./event_type.js";
export { PerformanceMonitor, WasmStructBridge, DynamicStructReader, WasmObjectBuilder } from "./struct_bridge.js";

export const env = {
  ...coreBindings,
  ...eventsBindings,
  ...domBindings,
  ...navigationBindings,
  ...storageBindings,
  ...networkBindings,
  ...observersBindings,
  ...mediaBindings,
};
