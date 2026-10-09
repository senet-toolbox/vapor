import { debug } from "./debug.js";
import { safeUrl, setSafeHref } from "./url.js";
import {
  wasmInstance,
  readRenderCommand,
  readUINode,
  activeNodeIds,
  readWasmString,
  rerenderRoute,
  text_data,
  currentPath,
} from "./wasi_obj.js";
import { updateComponentStyle, setRuleStyle } from "./wasi_styling.js";
import {
  domNodeRegistry,
  eventHandlers,
  hooksCtxCreated,
  hooksDestroyCtx,
  hooksMounted,
  hooksMountedCtx,
  invokedHooks,
  loadedSections,
  observeredSections,
  pureNodeRegistry,
} from "./maps.js";
import { state } from "./state.js";
import { DynamicStructReader, elementCache } from "./wasi.js";
import {
  applyAccessibility,
  attachElementListeners,
  createElementByType,
} from "./create_element.js";

export { animateExit, clearIntervalsForRoute, recurseDestroy } from "./teardown.js";
export { attachElementListeners, createElementByType } from "./create_element.js";

// Component type constants
export const COMPONENT_TYPES = {
  RECTANGLE: 0,
  TEXT: 1,
  IMAGE: 2,
  FLEXBOX: 3,
  TEXT_FIELD: 4,
  BUTTON: 5,
  BLOCK: 6,
  BOX: 7,
  HEADER: 8,
  SVG: 9,
  LINK: 10,
  EMBEDLINK: 11,
  LIST: 12,
  LISTITEM: 13,
  IF: 14,
  HOOKS: 15,
  LAYOUT: 16,
  PAGE: 17,
  BIND: 18,
  DIALOG: 19,
  DIALOG_SHOW: 20,
  DIALOG_CLOSE: 21,
  DRAGGABLE: 22,
  REDIRECT_LINK: 23,
  SELECT: 24,
  SELECT_ITEM: 25,
  BUTTON_CTX: 26,
  EMBEDICON: 27,
  ICON: 28,
  LABEL: 29,
  FORM: 30,
  ALLOC_TEXT: 31,
  TABLE: 32,
  TABLE_ROW: 33,
  TABLE_CELL: 34,
  TABLE_HEADER: 35,
  TABLE_BODY: 36,
  TEXT_AREA: 37,
  CANVAS: 38,
  SUBMIT_BUTTON: 39,
  HOOKS_CTX: 40,
  JSON_EDITOR: 41,
  HTML_TEXT: 42,
  CODE: 43,
  SPAN: 44,
  LAZY_IMAGE: 45,
  INTERSECTION: 46,
  PRE_IMAGE: 47,
  TEXT_GRADIENT: 48,
  GRADIENT: 49,
  VIRTUALIZE: 50,
  BUTTON_CYCLE: 51,
  GRAPHIC: 52,
  HEADING: 53,
  VIDEO: 54,
  NOOP: 55,
  TABLE_HEAD: 56,
  ANCHOR: 57,
  SPACER: 58,
  IFRAME: 59,
  FIELDSET: 60,
};

const STATE_TYPES = {
  STATIC: 0,
  PURE: 1,
  DYNAMIC: 2,
  GRAIN: 3,
};

export let tStyle = 0,
  tRegistry = 0;

/**
 * Setup element with common properties and register it
 * @param {HTMLElement} element - The element to set up
 * @param {Object} renderCmd - The render command
 */
export function setupElement(element, uinode) {
  // let s = performance.now();
  if (state.initial_render && uinode.styleId.length > 0) {
    const inlineStylePtr = wasmInstance.getInlineStyle(uinode.offset);
    const inlineStyleLen = wasmInstance.getInlineStyleLen(uinode.offset);
    if (inlineStylePtr !== 0) {
      const inlineStyle = readWasmString(inlineStylePtr, inlineStyleLen);
      element.setAttribute("style", inlineStyle);
    }
    setRuleStyle(uinode.styleId, element);
  } else if (!state.initial_render && uinode.styleId.length > 0) {
    const inlineStylePtr = wasmInstance.getInlineStyle(uinode.offset);
    if (inlineStylePtr !== 0) {
      const inlineStyleLen = wasmInstance.getInlineStyleLen(uinode.offset);
      const inlineStyle = readWasmString(inlineStylePtr, inlineStyleLen);
      element.setAttribute("style", inlineStyle);
    }

    // Update styling
    updateComponentStyle(uinode.offset, uinode.styleId, "", element);
  }

  // tStyle += performance.now() - s;

  // Register the element

  if (uinode.elemType === COMPONENT_TYPES.ICON) {
    const iconName = readWasmString(uinode.hrefPtr, uinode.hrefLen);
    element.className = iconName + " " + uinode.styleId;
  }

  // s = performance.now();
  domNodeRegistry.set(uinode.id, {
    elementType: uinode.elemType,
    node_ptr: uinode.offset,
    domNode: element,
    exitAnimationId: uinode.exitAnimationId,
    destroyId: uinode.hooks.destroyId > 0 ? uinode.hooks.destroyId : null,
    hash: uinode.hash,
    destroy_hash: uinode.onCallbacks[2],
  });
  // tRegistry += performance.now() - s;
}

/**
 * Update an existing element
 * @param {HTMLElement} element - The element to update
 * @param {Object} renderCmd - The render command
 */
export function updateElement(element, uinode, force = false) {
  // Update text content if needed
  if (uinode.changedProps > 0 || force) {
    if (
      (uinode.textLen >= 0 && uinode.elemType === COMPONENT_TYPES.TEXT) ||
      uinode.elemType === COMPONENT_TYPES.HEADER ||
      uinode.elemType === COMPONENT_TYPES.ALLOC_TEXT ||
      uinode.elemType === COMPONENT_TYPES.HEADING ||
      uinode.elemType === COMPONENT_TYPES.LABEL
    ) {
      const text = readWasmString(uinode.textPtr, uinode.textLen);
      element.textContent = text;
    } else if (
      uinode.elemType === COMPONENT_TYPES.TEXT_FIELD ||
      uinode.elemType === COMPONENT_TYPES.TEXT_AREA
    ) {
      const instansePtr = wasmInstance.getTextFieldParams(uinode.offset) >>> 0;
      if (instansePtr) {
        const fieldCount = wasmInstance.getTextFieldCount(uinode.offset);
        const reader = new DynamicStructReader(
          wasmInstance,
          wasmInstance.memory,
        );
        const fieldStruct = reader.readStruct(
          uinode.offset,
          instansePtr,
          fieldCount,
          "getTextFieldDescriptor",
        );
        element.value =
          fieldStruct.value !== null ? String(fieldStruct.value) : "";
      }

    } else if (uinode.elemType === COMPONENT_TYPES.ICON) {
      const iconName = readWasmString(uinode.hrefPtr, uinode.hrefLen);
      element.className = iconName + " " + uinode.styleId;
    } else if (uinode.elemType === COMPONENT_TYPES.HTML_TEXT) {
      const text = readWasmString(uinode.textPtr, uinode.textLen);
      element.innerHTML = text;
    } else if (uinode.elemType === COMPONENT_TYPES.IMAGE) {
      const src = readWasmString(uinode.hrefPtr, uinode.hrefLen);
      element.src = src;
    } else if (uinode.elemType === COMPONENT_TYPES.SVG) {
      const svgString = readWasmString(uinode.textPtr, uinode.textLen);
      const cleanSvg = svgString.replace(/^\s+|\s+$/g, "");
      const parser = new DOMParser();
      const doc = parser.parseFromString(cleanSvg, "image/svg+xml");
      element.innerHTML = doc.documentElement.outerHTML;
    } else if (
      uinode.elemType === COMPONENT_TYPES.LINK ||
      uinode.elemType === COMPONENT_TYPES.REDIRECT_LINK
    ) {
      const href = readWasmString(uinode.hrefPtr, uinode.hrefLen);
      setSafeHref(element, href);
    } else if (uinode.elemType === COMPONENT_TYPES.VIDEO) {
      const offset = wasmInstance.getVideo(uinode.offset);
      const videoView = new DataView(wasmInstance.memory.buffer, offset);
      const srcPtr = videoView.getUint32(0, true);
      if (srcPtr) {
        const srcLen = videoView.getUint32(4, true);
        element.src = readWasmString(srcPtr, srcLen);
      }
      element.autoplay = videoView.getUint8(8) === 1;
      element.muted = videoView.getUint8(9) === 1;
      element.loop = videoView.getUint8(10) === 1;
      element.controls = videoView.getUint8(11) === 1;
      element.setAttribute(
        "loading",
        videoView.getUint8(12) === 1 ? "lazy" : "eager",
      );
    }
    if (uinode.accessibility) {
      applyAccessibility(element, uinode.offset);
    }
  }

  // This means that the style hash has changed and we need to update
  if (uinode.changedStyle > 0 || force) {

    // Update styling

    const isReusedNode = !force; // force=true means freshly created/attached
    if (isReusedNode) {
      // element.style = "";
      const prevTransition = element.style.transition;
      if (!uinode.morph) {
        element.style.transition = "none";
      } else {
        if (element.style.transition === "") {
          element.style.transition = "all 0.3s ease-in-out";
        }
      }

      updateComponentStyle(uinode.offset, uinode.styleId, "", element);

      const inlineStylePtr = wasmInstance.getInlineStyle(uinode.offset);
      if (inlineStylePtr !== 0) {
        const inlineStyleLen = wasmInstance.getInlineStyleLen(uinode.offset);
        const inlineStyle = readWasmString(inlineStylePtr, inlineStyleLen);
        element.setAttribute("style", inlineStyle);
      } else if (uinode.elemType === COMPONENT_TYPES.ICON) {
        const iconName = readWasmString(uinode.hrefPtr, uinode.hrefLen);
        element.className = iconName + " " + uinode.styleId;
        uinode.styleId = iconName + " " + uinode.styleId;
      } else {
        // element.setAttribute("style", "");
      }

      if (!uinode.morph) {
        // Force style flush so the new width/etc commits with transition:none
        void element.offsetHeight;

        // Restore on next frame
        requestAnimationFrame(() => {
          element.style.transition = prevTransition; // usually '' so class rules win
        });
      }
    } else {
      updateComponentStyle(uinode.offset, uinode.styleId, "", element);
      const inlineStylePtr = wasmInstance.getInlineStyle(uinode.offset);
      if (inlineStylePtr !== 0) {
        const inlineStyleLen = wasmInstance.getInlineStyleLen(uinode.offset);
        const inlineStyle = readWasmString(inlineStylePtr, inlineStyleLen);
        element.setAttribute("style", inlineStyle);
      } else if (uinode.elemType === COMPONENT_TYPES.ICON) {
        const iconName = readWasmString(uinode.hrefPtr, uinode.hrefLen);
        element.className = iconName + " " + uinode.styleId;
        uinode.styleId = iconName + " " + uinode.styleId;
      }
    }
  } else {
    const inlineStylePtr = wasmInstance.getInlineStyle(uinode.offset);
  }
}

/**
 * Traverse and render the component tree
 * @param {HTMLElement} parent - The parent element html element
 * @param {HTMLElement} tree_node - The current tree node  *UINode
 * @param {Object} layout - The layout information
 */
export function generateSections(virtual, virtual_ptr, layout) {
  if (!virtual) return;

  const children_count = wasmInstance.getTreeNodeChildrenCount(virtual_ptr);

  for (let i = 0; i < children_count; i++) {
    const child_ptr = wasmInstance.getTreeNodeChild(virtual_ptr, i);
    const rndcmd_ptr = wasmInstance.getRenderCommandPtr(child_ptr);
    const renderCmd = readRenderCommand(rndcmd_ptr, layout);

    if (renderCmd.elemType !== COMPONENT_TYPES.INTERSECTION) {
      console.error(
        "Virtualized element must contain only intersection elements",
      );
      return;
    }

    activeNodeIds.add(renderCmd.id);

    let element = createElementByType(renderCmd);

    if (!element) continue; // Skip if element creation failed

    // Set up the element
    setupElement(element, renderCmd);

    // Append to parent
    virtual.appendChild(element);
    observeredSections.set(renderCmd.id, {
      renderCmd,
      treeNodePtr: child_ptr,
    });
  }
}

export let t1 = 0,
  t2 = 0,
  t3 = 0,
  t4 = 0,
  t5 = 0,
  t6 = 0,
  t7 = 0,
  t8 = 0;

export function resetTimers() {
  t1 = 0;
  t2 = 0;
  t3 = 0;
  t4 = 0;
  t5 = 0;
  t6 = 0;
  t7 = 0;
  t8 = 0;
  tStyle = 0;
  tRegistry = 0;
}

function invokeCallbacks(uinode) {
  for (const item of uinode.onCallbacks) {
    if (item === 0) continue;
    wasmInstance.invokeErasedCallback(item);
  }
}

function invokeCallback(callback_hash) {
  if (callback_hash === 0) return;
  wasmInstance.invokeHooksErasedCallback(callback_hash);
}

const LAYER_ROOTS = {
  0: null, // LAYER_NONE — normal placement
  1: "layer-tooltip",
  2: "layer-popover",
  3: "layer-modal",
  4: "layer-toast",
};

function getLayerRoot(layerKind) {
  if (!layerKind) return null;
  const id = LAYER_ROOTS[layerKind];
  return id ? document.getElementById(id) : null;
}

function getValidAnchor(parent, nextUinode) {
  if (!nextUinode) return null;
  const nextId = nextUinode[0]?.id;
  if (!nextId) return null;
  const candidate = document.getElementById(nextId);
  // Only use it if it's actually a child of the parent we're inserting into
  if (candidate && candidate.parentNode === parent) {
    return candidate;
  }
  return null;
}

function placeElement(element, parent, anchor, uinode) {
  if (uinode.layer && uinode.layer > 0) {
    const layerRoot = getLayerRoot(uinode.layer);
    if (layerRoot) {
      element.dataset.layer = uinode.layer;
      if (element.parentNode !== layerRoot) {
        layerRoot.appendChild(element);
      }
      return;
    }
  }

  // Defensive: if anchor isn't actually in parent, just append
  if (anchor && anchor.parentNode !== parent) {
    anchor = null;
  }
  parent.insertBefore(element, anchor);
}
/**
 * Traverse and render the component tree
 * @param {HTMLElement} parent - The parent element html element
 * @param {HTMLElement} tree_node - The current tree node  *UINode
 * @param {Object} layout - The layout information
 */
export function traverseUINodes(parent, parentUINode) {
  if (!parent) return;

  // const children_count = wasmInstance.getUINodeChildrenCount(parentUINode);
  const uinodes = [];

  // Collect children by walking the linked list - O(n)
  let childPtr = wasmInstance.getUINodeFirstChild(parentUINode);

  while (childPtr) {
    const uiNode = readUINode(childPtr);
    uinodes.push([uiNode, childPtr]);
    childPtr = wasmInstance.getUINodeNextSibling(childPtr);
  }

  for (let i = uinodes.length - 1; i >= 0; i--) {
    const uinode = uinodes[i][0];
    const child_ptr = uinodes[i][1];
    activeNodeIds.add(uinode.id);
    let element = null;

    if (uinode.isDirty) {
      element = document.getElementById(uinode.id);

      if (uinode.hooksChanged) {
        debug("Hooks Change", uinode.id, uinode.hooksChanged);
        invokedHooks.set(uinode.onCallbacks[0], true);
      }

      if (element && state.initial_render) {
        // Create new element
        attachElementListeners(element, uinode);
        domNodeRegistry.set(uinode.id, {
          elementType: uinode.elemType,
          node_ptr: uinode.offset,
          domNode: element,
          exitAnimationId: uinode.exitAnimationId,
          destroyId: uinode.hooks.destroyId > 0 ? uinode.hooks.destroyId : null,
          hash: uinode.hash,
          destroy_hash: uinode.onCallbacks[2],
        });

        updateElement(element, uinode, true);

        // Append to parent
        const anchor = getValidAnchor(parent, uinodes[i + 1]);
        placeElement(element, parent, anchor, uinode);

        traverseUINodes(element, child_ptr);

        if (uinode.onCallbacks[0] > 0) {
          invokedHooks.set(uinode.onCallbacks[0], true);
        }

        invokeCallback(uinode.onCallbacks[1]);
      } else if (!element || state.initial_render) {
        // Create new element
        // s = performance.now();
        element = createElementByType(uinode);
        // t6 += performance.now() - s;

        if (!element) continue; // Skip if element creation failed

        // Set up the element
        // s = performance.now();
        setupElement(element, uinode);
        // t5 += performance.now() - s;

        // Append to parent
        const anchor = getValidAnchor(parent, uinodes[i + 1]);
        placeElement(element, parent, anchor, uinode);

        traverseUINodes(element, child_ptr);

        if (uinode.onCallbacks[0] > 0) {
          invokedHooks.set(uinode.onCallbacks[0], true);
        }

        invokeCallback(uinode.onCallbacks[1]);
      } else {
        // Update existing element
        updateElement(element, uinode);
        const node_info = domNodeRegistry.get(uinode.id);
        if (node_info !== undefined) {
          domNodeRegistry.set(uinode.id, {
            elementType: uinode.elemType,
            node_ptr: uinode.offset,
            domNode: element,
            exitAnimationId: uinode.exitAnimationId,
            destroyId:
              uinode.hooks.destroyId > 0 ? uinode.hooks.destroyId : null,
            hash: uinode.hash,
            destroy_hash: uinode.onCallbacks[2],
          });
        }

        if (uinode.layer && uinode.layer > 0) {
          // Layered node: make sure it's in the right layer root, skip sibling logic
          const layerRoot = getLayerRoot(uinode.layer);
          if (layerRoot && element.parentNode !== layerRoot) {
            element.dataset.layer = uinode.layer;
            layerRoot.appendChild(element);
          }
        } else {
          // Normal node: reposition within parent if needed
          const anchor = getValidAnchor(parent, uinodes[i + 1]);

          let actualNextSibling = element.nextSibling;
          while (actualNextSibling?.dataset?.removing) {
            actualNextSibling = actualNextSibling.nextSibling;
          }

          if (element.parentNode !== parent || actualNextSibling !== anchor) {
            parent.insertBefore(element, anchor);
          }
        }

        // Process children
        traverseUINodes(element, child_ptr);

        invokeCallback(uinode.onCallbacks[1]);
      }
    } else {
      const node_info = domNodeRegistry.get(uinode.id);
      if (node_info !== undefined) {
        node_info.node_ptr = uinode.offset;
        node_info.destroy_hash = uinode.onCallbacks[2];
        domNodeRegistry.set(uinode.id, node_info);
      }

      // Element is not dirty, just process its children
      const element = document.getElementById(uinode.id);
      traverseUINodes(element, child_ptr);
    }
  }
}

export function traverseRemove(parent, tree_node, layout) {
  debug("traverseRemove", parent, tree_node, layout);
  if (!parent) return;

  const children_count = wasmInstance.getTreeNodeChildrenCount(tree_node);

  for (let i = 0; i < children_count; i++) {
    const child_ptr = wasmInstance.getTreeNodeChild(tree_node, i);
    const rndcmd_ptr = wasmInstance.getRenderCommandPtr(child_ptr);
    const renderCmd = readRenderCommand(rndcmd_ptr, layout);

    if (renderCmd.isDirty) {
      // console.log("flkajsdfl;kajflkjafj", renderCmd.id);
      const node = domNodeRegistry.get(renderCmd.id);
      const el = node.domNode;
      domNodeRegistry.delete(renderCmd.id);
      pureNodeRegistry.delete(renderCmd.id);
      // el.remove();
      el.replaceWith(...Array.from(el.childNodes));
      wasmInstance.setDirtyToFalse(renderCmd.nodePtr);
    }
  }
}
