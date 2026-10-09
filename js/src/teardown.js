/** Removing elements: exit animations, interval cleanup and registry teardown. */
import {
  domNodeRegistry,
  eventHandlers,
  loadedSections,
  pureNodeRegistry,
} from "./maps.js";
import { elementCache } from "./wasi.js";
import { activeNodeIds, readWasmString, wasmInstance } from "./wasi_obj.js";

// Store intervals by route for cleanup
const routeIntervals = new Map();

/**
 * Clear all intervals for a specific route
 * @param {string} path - The route path to clear intervals for
 */
export function clearIntervalsForRoute(path) {
  if (routeIntervals.has(path)) {
    routeIntervals.get(path).forEach((intervalId) => {
      clearInterval(intervalId);
    });
    routeIntervals.delete(path);
  }
}

export async function animateExit(el, index = -1, skipAnimation = false) {
  if (!el || el.dataset.removing === "true") return;
  el.dataset.removing = "true";

  // Run exit animation on the ROOT element only
  if (!skipAnimation && index > -1) {
    const animPtr = wasmInstance.getRemovalAnimationPtr(index);
    if (animPtr > 0) {
      const animLen = wasmInstance.getRemovalAnimationLen(index);
      const css = readWasmString(animPtr, animLen);
      if (css) {
        el.style.animation = css;
        void el.offsetWidth;
        await new Promise((resolve) => {
          el.addEventListener("animationend", resolve, { once: true });
          // Timeout fallback in case animation doesn't fire
          setTimeout(resolve, 1000);
        });
      }
    }
  }

  // Collect ALL descendant IDs before removal
  const idsToCleanup = collectDescendantIds(el);

  // Remove from DOM (children go with it)
  el.remove();

  // NOW clean up registries
  for (const id of idsToCleanup) {
    cleanupRegistryEntry(id);
  }
}

function collectDescendantIds(el) {
  const ids = [el.id];
  const walker = document.createTreeWalker(el, NodeFilter.SHOW_ELEMENT);
  while (walker.nextNode()) {
    if (walker.currentNode.id) {
      ids.push(walker.currentNode.id);
    }
  }
  return ids;
}

function cleanupRegistryEntry(id) {
  const entry = domNodeRegistry.get(id);
  if (entry?.domNode) {
    // Remove event listeners
    const eventData = eventHandlers.get(id);
    if (eventData) {
      for (const [eventType, handler] of Object.entries(eventData)) {
        entry.domNode.removeEventListener(eventType, handler);
      }
      eventHandlers.delete(id);
    }
  }

  if (entry?.destroy_hash > 0) {
    wasmInstance.invokeHooksErasedCallback(entry.destroy_hash);
  }

  domNodeRegistry.delete(id);
  pureNodeRegistry.delete(id);
  loadedSections.delete(id);
  elementCache.delete(id);
  activeNodeIds.delete(id);
}

export async function recurseDestroy(el, skipAnimation = false) {
  if (!el) return;

  el.dataset.removing = "true";
  const domNode = domNodeRegistry.get(el.id);
  const nodePtr = domNode?.node_ptr;

  let shouldAnimate = !skipAnimation;

  if (shouldAnimate && nodePtr) {
    const exitAnimationPtr = wasmInstance.getExitAnimationStyle(nodePtr);

    if (exitAnimationPtr > 0) {
      const exitAnimationLen = wasmInstance.getAnimationLen();
      const exitAnimationCss = readWasmString(
        exitAnimationPtr,
        exitAnimationLen,
      );

      if (exitAnimationCss) {
        // DEBUG: Check if element is still in DOM
        el.style.animation = exitAnimationCss;

        // Force reflow
        void el.offsetWidth;

        // DEBUG: Check computed style
        await new Promise((resolve) => {
          el.addEventListener(
            "animationend",
            () => {
              resolve();
            },
            { once: true },
          );
        });
      }
    }
  }

  // Cleanup children (skip their animations)
  for (const child of Array.from(el.children)) {
    await recurseDestroy(child, true);
  }

  // Cleanup registries
  domNodeRegistry.delete(el.id);
  pureNodeRegistry.delete(el.id);
  loadedSections.delete(el.id);

  const eventData = eventHandlers.get(el.id);
  if (eventData) {
    for (const [eventType, handler] of Object.entries(eventData)) {
      el.removeEventListener(eventType, handler);
    }
    eventHandlers.delete(el.id);
  }

  el.remove();
}
