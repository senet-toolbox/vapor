import { rt } from "./runtime.js";

// ============================================================================
// NOTIFICATIONS
// ============================================================================

export const notificationBindings = {
  notificationPermissionWasm: () => {
    if (!("Notification" in window)) return -1;
    switch (Notification.permission) {
      case "denied":
        return 0;
      case "granted":
        return 1;
      default:
        return 2;
    }
  },

  requestNotificationPermissionWasm: (callbackId) => {
    if (!("Notification" in window)) {
      rt.wasmInstance.callbackCtx(callbackId, -1);
      return;
    }

    Notification.requestPermission().then((permission) => {
      let result;
      switch (permission) {
        case "denied":
          result = 0;
          break;
        case "granted":
          result = 1;
          break;
        default:
          result = 2;
      }
      rt.wasmInstance.callbackCtx(callbackId, result);
    });
  },

  showNotificationWasm: (
    titlePtr,
    titleLen,
    bodyPtr,
    bodyLen,
    iconPtr,
    iconLen,
    tagPtr,
    tagLen,
  ) => {
    if (!("Notification" in window) || Notification.permission !== "granted")
      return 0;

    const title = rt.readWasmString(titlePtr, titleLen);
    const options = {
      body: rt.readWasmString(bodyPtr, bodyLen),
      icon: rt.readWasmString(iconPtr, iconLen),
      tag: rt.readWasmString(tagPtr, tagLen),
    };

    try {
      new Notification(title, options);
      return 1;
    } catch (e) {
      return 0;
    }
  },
};
