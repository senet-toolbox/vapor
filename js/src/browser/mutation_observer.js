import { rt } from "./runtime.js";

const mutationObservers = new Map();
let nextMutationObserverHandle = 1;

// ============================================================================
// MUTATION OBSERVER
// ============================================================================

export const mutationObserverBindings = {
  createMutationObserverWasm: (callbackId) => {
    const handle = nextMutationObserverHandle++;

    const observer = new MutationObserver((mutations) => {
      for (const mutation of mutations) {
        const data = {
          type: mutation.type,
          targetId: mutation.target.id,
          attributeName: mutation.attributeName,
          oldValue: mutation.oldValue,
          addedNodesCount: mutation.addedNodes.length,
          removedNodesCount: mutation.removedNodes.length,
        };
        rt.wasmInstance.callbackCtx(callbackId, rt.allocString(JSON.stringify(data)));
      }
    });

    mutationObservers.set(handle, observer);
    return handle;
  },

  observeMutationWasm: (
    handle,
    elementPtr,
    elementLen,
    childList,
    attributes,
    characterData,
    subtree,
    attributeOldValue,
    characterDataOldValue,
  ) => {
    const observer = mutationObservers.get(handle);
    if (!observer) return 0;

    const id = rt.readWasmString(elementPtr, elementLen);
    const element = document.getElementById(id);
    if (!element) return 0;

    observer.observe(element, {
      childList,
      attributes,
      characterData,
      subtree,
      attributeOldValue,
      characterDataOldValue,
    });
    return 1;
  },

  disconnectMutationObserverWasm: (handle) => {
    const observer = mutationObservers.get(handle);
    if (observer) {
      observer.disconnect();
    }
  },

  destroyMutationObserverWasm: (handle) => {
    const observer = mutationObservers.get(handle);
    if (observer) {
      observer.disconnect();
      mutationObservers.delete(handle);
    }
  },
};
