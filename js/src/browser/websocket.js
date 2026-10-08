import { rt } from "./runtime.js";

const websocketHandles = new Map();
let nextWebsocketHandle = 1;

// ============================================================================
// WEBSOCKET
// ============================================================================

export const websocketBindings = {
  websocketConnectWasm: (
    urlPtr,
    urlLen,
    openCallbackId,
    messageCallbackId,
    closeCallbackId,
    errorCallbackId,
  ) => {
    if (!rt.requireWasm()) return 0;

    const url = rt.readWasmString(urlPtr, urlLen);
    const handle = nextWebsocketHandle++;

    try {
      const ws = new WebSocket(url);

      ws.onopen = () => {
        rt.wasmInstance.callbackCtx(openCallbackId, handle);
      };

      ws.onmessage = (event) => {
        const ptr = rt.allocString(event.data);
        rt.wasmInstance.callbackCtx(messageCallbackId, ptr);
      };

      ws.onclose = (event) => {
        const info = {
          code: event.code,
          reason: event.reason,
          wasClean: event.wasClean,
        };
        const ptr = rt.allocString(JSON.stringify(info));
        rt.wasmInstance.callbackCtx(closeCallbackId, ptr);
        websocketHandles.delete(handle);
      };

      ws.onerror = () => {
        rt.wasmInstance.callbackCtx(errorCallbackId, handle);
      };

      websocketHandles.set(handle, ws);
      return handle;
    } catch (e) {
      console.error("WebSocket connection failed:", e);
      return 0;
    }
  },

  websocketSendWasm: (handle, dataPtr, dataLen) => {
    const ws = websocketHandles.get(handle);
    if (!ws || ws.readyState !== WebSocket.OPEN) return 0;

    const data = rt.readWasmString(dataPtr, dataLen);
    try {
      ws.send(data);
      return 1;
    } catch (e) {
      return 0;
    }
  },

  websocketSendBinaryWasm: (handle, dataPtr, dataLen) => {
    const ws = websocketHandles.get(handle);
    if (!ws || ws.readyState !== WebSocket.OPEN) return 0;

    const data = new Uint8Array(rt.wasmInstance.memory.buffer, dataPtr, dataLen);
    try {
      ws.send(data);
      return 1;
    } catch (e) {
      return 0;
    }
  },

  websocketCloseWasm: (handle, code, reasonPtr, reasonLen) => {
    const ws = websocketHandles.get(handle);
    if (!ws) return;

    const reason = rt.readWasmString(reasonPtr, reasonLen);
    ws.close(code, reason);
  },

  websocketStateWasm: (handle) => {
    const ws = websocketHandles.get(handle);
    if (!ws) return -1;
    return ws.readyState;
  },

  websocketBufferedAmountWasm: (handle) => {
    const ws = websocketHandles.get(handle);
    if (!ws) return 0;
    return ws.bufferedAmount;
  },
};
