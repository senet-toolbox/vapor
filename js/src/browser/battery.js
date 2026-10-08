import { rt } from "./runtime.js";

// ============================================================================
// BATTERY STATUS
// ============================================================================

export const batteryBindings = {
  getBatteryStatusWasm: (callbackId) => {
    if (!("getBattery" in navigator)) {
      rt.wasmInstance.callbackCtx(
        callbackId,
        rt.allocString(JSON.stringify({ error: "Not supported" })),
      );
      return;
    }

    navigator
      .getBattery()
      .then((battery) => {
        const status = {
          charging: battery.charging,
          chargingTime: battery.chargingTime,
          dischargingTime: battery.dischargingTime,
          level: battery.level,
        };
        rt.wasmInstance.callbackCtx(
          callbackId,
          rt.allocString(JSON.stringify(status)),
        );
      })
      .catch((err) => {
        rt.wasmInstance.callbackCtx(
          callbackId,
          rt.allocString(JSON.stringify({ error: err.message })),
        );
      });
  },
};
