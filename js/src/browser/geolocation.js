import { rt } from "./runtime.js";

// ============================================================================
// GEOLOCATION
// ============================================================================

export const geolocationBindings = {
  geolocationAvailableWasm: () => {
    return "geolocation" in navigator ? 1 : 0;
  },

  getCurrentPositionWasm: (
    callbackId,
    errorCallbackId,
    enableHighAccuracy,
    timeout,
    maximumAge,
  ) => {
    if (!("geolocation" in navigator)) {
      rt.wasmInstance.callbackCtx(
        errorCallbackId,
        rt.allocString(
          JSON.stringify({ code: 0, message: "Geolocation not supported" }),
        ),
      );
      return;
    }

    navigator.geolocation.getCurrentPosition(
      (position) => {
        const data = {
          latitude: position.coords.latitude,
          longitude: position.coords.longitude,
          accuracy: position.coords.accuracy,
          altitude: position.coords.altitude,
          altitudeAccuracy: position.coords.altitudeAccuracy,
          heading: position.coords.heading,
          speed: position.coords.speed,
          timestamp: position.timestamp,
        };
        rt.wasmInstance.callbackCtx(callbackId, rt.allocString(JSON.stringify(data)));
      },
      (error) => {
        const data = { code: error.code, message: error.message };
        rt.wasmInstance.callbackCtx(
          errorCallbackId,
          rt.allocString(JSON.stringify(data)),
        );
      },
      {
        enableHighAccuracy: enableHighAccuracy,
        timeout: timeout,
        maximumAge: maximumAge,
      },
    );
  },

  watchPositionWasm: (
    callbackId,
    errorCallbackId,
    enableHighAccuracy,
    timeout,
    maximumAge,
  ) => {
    if (!("geolocation" in navigator)) return -1;

    return navigator.geolocation.watchPosition(
      (position) => {
        const data = {
          latitude: position.coords.latitude,
          longitude: position.coords.longitude,
          accuracy: position.coords.accuracy,
          altitude: position.coords.altitude,
          altitudeAccuracy: position.coords.altitudeAccuracy,
          heading: position.coords.heading,
          speed: position.coords.speed,
          timestamp: position.timestamp,
        };
        rt.wasmInstance.callbackCtx(callbackId, rt.allocString(JSON.stringify(data)));
      },
      (error) => {
        const data = { code: error.code, message: error.message };
        rt.wasmInstance.callbackCtx(
          errorCallbackId,
          rt.allocString(JSON.stringify(data)),
        );
      },
      {
        enableHighAccuracy: enableHighAccuracy,
        timeout: timeout,
        maximumAge: maximumAge,
      },
    );
  },

  clearWatchPositionWasm: (watchId) => {
    navigator.geolocation.clearWatch(watchId);
  },
};
