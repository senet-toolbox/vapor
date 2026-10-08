import { rt } from "./runtime.js";

// ============================================================================
// SHARE API
// ============================================================================

export const shareBindings = {
  canShareWasm: () => {
    return "share" in navigator ? 1 : 0;
  },

  shareWasm: (
    titlePtr,
    titleLen,
    textPtr,
    textLen,
    urlPtr,
    urlLen,
    callbackId,
  ) => {
    if (!("share" in navigator)) {
      rt.wasmInstance.callbackCtx(callbackId, 0);
      return;
    }

    const data = {
      title: rt.readWasmString(titlePtr, titleLen),
      text: rt.readWasmString(textPtr, textLen),
      url: rt.readWasmString(urlPtr, urlLen),
    };

    navigator
      .share(data)
      .then(() => rt.wasmInstance.callbackCtx(callbackId, 1))
      .catch(() => rt.wasmInstance.callbackCtx(callbackId, 0));
  },
};
