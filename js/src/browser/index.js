// Optional browser-API bindings: canvas, audio, geolocation, IndexedDB,
// websockets, drag and drop, and more. Built as browser.min.js, separate from
// the core runtime. The core loads it only when an app's wasm imports one of
// these functions, so apps that use none never download it.
import { rt } from "./runtime.js";
import { dragDropBindings } from "./dragDrop.js";
import { websocketBindings } from "./websocket.js";
import { sessionStorageBindings } from "./sessionStorage.js";
import { canvasBindings } from "./canvas.js";
import { audioBindings } from "./audio.js";
import { geolocationBindings } from "./geolocation.js";
import { notificationBindings } from "./notification.js";
import { fullscreenBindings } from "./fullscreen.js";
import { selectionBindings } from "./selection.js";
import { mutationObserverBindings } from "./mutationObserver.js";
import { performanceBindings } from "./performance.js";
import { indexedDBBindings } from "./indexedDB.js";
import { pointerLockBindings } from "./pointerLock.js";
import { vibrationBindings } from "./vibration.js";
import { orientationBindings } from "./orientation.js";
import { batteryBindings } from "./battery.js";
import { shareBindings } from "./share.js";

/// Called by the core before instantiating; returns the env functions.
export function install(runtime) {
  rt.readWasmString = runtime.readWasmString;
  rt.allocString = runtime.allocString;
  return {
    ...dragDropBindings,
    ...websocketBindings,
    ...sessionStorageBindings,
    ...canvasBindings,
    ...audioBindings,
    ...geolocationBindings,
    ...notificationBindings,
    ...fullscreenBindings,
    ...selectionBindings,
    ...mutationObserverBindings,
    ...performanceBindings,
    ...indexedDBBindings,
    ...pointerLockBindings,
    ...vibrationBindings,
    ...orientationBindings,
    ...batteryBindings,
    ...shareBindings,
  };
}

/// Called by the core once the instance exists.
export function setInstance(instance) {
  rt.wasmInstance = instance;
}
