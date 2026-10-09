/** Reading render commands, UINodes and strings out of wasm memory. */
import { COMPONENT_TYPES } from "./traversal.js";
import { UINodelayoutInfo, layoutInfo, wasmInstance } from "./wasi_obj.js";
import { styleClassCache } from "./wasi_styling.js";

// Function to read a RenderCommand from memory
// Essentially we are just reading out a giant memory file and using alignment
// and ptr to access the data then we convert the values to readable js values
export function readRenderCommand(offset, layout) {
  const view = new DataView(
    wasmInstance.memory.buffer,
    offset,
    layoutInfo.renderCommandSize,
  );

  let css = "";
  let keyFrames = "";
  let styleId = "";
  let id = "";
  let btnId = 0;
  let hoverCss = "";
  let focusCss = "";
  let focusWithinCss = "";
  let tooltipCss = "";
  let tooltipTitle = "";
  let exitAnimationId = null;

  const elemType = view.getUint8(layoutInfo.elemTypeOffset);

  const nodePtr = view.getUint32(layoutInfo.nodePtrOffset, true);
  const isDirty = wasmInstance.getDirtyValue(nodePtr);

  // For text, you need to handle the string slice differently
  const textPtr = view.getUint32(layoutInfo.textPtrOffset, true);
  const textLen = view.getUint32(layoutInfo.textPtrOffset + 4, true);

  const hrefPtr = view.getUint32(layoutInfo.hrefPtrOffset, true);
  const hrefLen = view.getUint32(layoutInfo.hrefPtrOffset + 4, true);
  const hasChildren = view.getUint8(layoutInfo.hasChildrenOffset, true);

  const idPtr = view.getUint32(layoutInfo.idPtrOffset, true);
  const idLen = view.getUint32(layoutInfo.idPtrOffset + 4, true);
  id = idPtr ? readWasmString(idPtr, idLen) : "";
  const index = view.getUint32(layoutInfo.indexOffset, true);
  let hooks = {};
  let changedStyle = 0;
  let changedProps = 0;

  if (isDirty) {
    changedStyle = view.getUint8(layoutInfo.styleChangedOffset, true);
    changedProps = view.getUint8(layoutInfo.propsChangedOffset, true);
    hooks = {
      createdId: view.getUint32(layoutInfo.hooksOffset, true),
      mountedId: view.getUint32(layoutInfo.hooksOffset + 4, true),
      updatedId: view.getUint32(layoutInfo.hooksOffset + 8, true),
      destroyId: view.getUint32(layoutInfo.hooksOffset + 12, true),
    };

    // if (cssStylePtr !== 0) {
    // 1. Get the offset of the classname's POINTER from our new layout object.
    const classnamePtrOffset = layoutInfo.classnamePtrOffset;

    // 2. Read the actual pointer value from the RenderCommand struct.
    const classnamePtr = view.getUint32(classnamePtrOffset, true);

    // 3. If the pointer is not null, read the length and then the string.
    if (classnamePtr) {
      // The length is ALWAYS 4 bytes after the pointer for a slice.
      const classnameLen = view.getUint32(classnamePtrOffset + 4, true);

      const classname = readWasmString(classnamePtr, classnameLen);
      styleId = classname;
    }
  }

  const stateType = view.getUint32(layoutInfo.renderTypeOffset, true);

  const props = {
    css,
    hoverCss,
    focusCss,
    focusWithinCss,
    btnId,
    keyFrames,
    textPtr,
    textLen,
    tooltipCss,
    tooltipTitle,
    hasChildren,
    hrefPtr,
    hrefLen,
  };

  return {
    elemType,
    props,
    id,
    index,
    hooks,
    nodePtr,
    exitAnimationId,
    styleId,
    isDirty,
    stateType,
    changedStyle,
    changedProps,
    // ... other fields
  };
}

let memoryView = null;

let memoryBuffer = null;

function getMemoryView() {
  // Only recreate if buffer changed (after memory growth)
  if (memoryBuffer !== wasmInstance.memory.buffer) {
    memoryBuffer = wasmInstance.memory.buffer;
    memoryView = new DataView(memoryBuffer);
  }
  return memoryView;
}

export function readUINode(offset) {
  const view = getMemoryView();

  const isDirty = view.getUint8(offset + UINodelayoutInfo.dirtyOffset);

  const onCallbacksOffsetMount = view.getUint32(
    offset + UINodelayoutInfo.onCallbacksOffset,
    true,
  );

  const onCallbacksOffsetUpdate = view.getUint32(
    offset + UINodelayoutInfo.onCallbacksOffset + 4,
    true,
  );

  const onCallbacksOffsetDestroy = view.getUint32(
    offset + UINodelayoutInfo.onCallbacksOffset + 8,
    true,
  );

  // Fast path for non-dirty nodes
  if (!isDirty) {
    const hash = Number(
      view.getUint32(offset + UINodelayoutInfo.hashOffset, true),
    );
    const idPtr = view.getUint32(offset + UINodelayoutInfo.idPtrOffset, true);
    const idLen = view.getUint32(
      offset + UINodelayoutInfo.idPtrOffset + 4,
      true,
    );
    const id = idPtr ? readWasmString(idPtr, idLen) : "";
    return {
      id,
      isDirty: false,
      // Minimal fields - rest undefined/default
      elemType: 0,
      index: 0,
      textPtr: 0,
      textLen: 0,
      hrefPtr: 0,
      hrefLen: 0,
      offset,
      styleId: "",
      changedStyle: 0,
      changedProps: 0,
      hooks: {},
      hash,
      onCallbacks: [
        onCallbacksOffsetMount >>> 0,
        onCallbacksOffsetUpdate >>> 0,
        onCallbacksOffsetDestroy >>> 0,
      ],
      hooksChanged: 0,
      morph: false,
      layer: 0,
    };
  }

  // Full read for dirty nodes
  const elemType = view.getUint8(offset + UINodelayoutInfo.elemTypeOffset);
  const index = view.getUint32(offset + UINodelayoutInfo.indexOffset, true);
  const idPtr = view.getUint32(offset + UINodelayoutInfo.idPtrOffset, true);
  const idLen = view.getUint32(offset + UINodelayoutInfo.idPtrOffset + 4, true);
  const id = idPtr ? readWasmString(idPtr, idLen) : "";
  const hash = Number(
    view.getUint32(offset + UINodelayoutInfo.hashOffset, true),
  );
  // const hash = id;
  // readtime += performance.now() - start;

  let textPtr = 0,
    textLen = 0;
  let hrefPtr = 0,
    hrefLen = 0;
  let hooks = {};

  if (
    elemType === COMPONENT_TYPES.TEXT ||
    elemType === COMPONENT_TYPES.LABEL ||
    elemType === COMPONENT_TYPES.HEADING ||
    elemType === COMPONENT_TYPES.ALLOC_TEXT ||
    elemType === COMPONENT_TYPES.HEADER ||
    elemType === COMPONENT_TYPES.TEXT_AREA ||
    elemType === COMPONENT_TYPES.TEXT_FIELD ||
    elemType === COMPONENT_TYPES.CODE ||
    elemType === COMPONENT_TYPES.SVG ||
    elemType === COMPONENT_TYPES.HTML_TEXT ||
    elemType === COMPONENT_TYPES.TEXT_AREA
  ) {
    textPtr = view.getUint32(offset + UINodelayoutInfo.textPtrOffset, true);
    textLen = view.getUint32(offset + UINodelayoutInfo.textPtrOffset + 4, true);
  }

  if (
    elemType === COMPONENT_TYPES.LINK ||
    elemType === COMPONENT_TYPES.REDIRECT_LINK ||
    elemType === COMPONENT_TYPES.EMBEDLINK ||
    elemType === COMPONENT_TYPES.EMBEDICON ||
    elemType === COMPONENT_TYPES.IMAGE ||
    elemType === COMPONENT_TYPES.GRAPHIC ||
    elemType === COMPONENT_TYPES.ICON ||
    elemType === COMPONENT_TYPES.IFRAME
  ) {
    hrefPtr = view.getUint32(offset + UINodelayoutInfo.hrefPtrOffset, true);
    hrefLen = view.getUint32(offset + UINodelayoutInfo.hrefPtrOffset + 4, true);
  }

  if (
    elemType === COMPONENT_TYPES.HOOKS ||
    elemType === COMPONENT_TYPES.HOOKS_CTX
  ) {
    hooks = {
      createdId: view.getUint32(offset + UINodelayoutInfo.hooksOffset, true),
      mountedId: view.getUint32(
        offset + UINodelayoutInfo.hooksOffset + 4,
        true,
      ),
      updatedId: view.getUint32(
        offset + UINodelayoutInfo.hooksOffset + 8,
        true,
      ),
      destroyId: view.getUint32(
        offset + UINodelayoutInfo.hooksOffset + 12,
        true,
      ),
    };
  }

  const style_hash = view.getUint32(
    offset + UINodelayoutInfo.styleHashOffset,
    true,
  );

  const accessibility = view.getUint8(
    offset + UINodelayoutInfo.accessibilityOffset,
    true,
  );

  // In hot path
  let styleId = "";
  if (style_hash) {
    styleId = styleClassCache[style_hash]; // Direct property access
    if (styleId === undefined) {
      const classnamePtr = view.getUint32(
        offset + UINodelayoutInfo.classnamePtrOffset,
        true,
      );
      if (classnamePtr) {
        const classnameLen = view.getUint32(
          offset + UINodelayoutInfo.classnamePtrOffset + 4,
          true,
        );
        styleId = readWasmString(classnamePtr, classnameLen);
        styleClassCache[style_hash] = styleId;
      }
    }
  }

  return {
    id,
    elemType,
    index,
    textPtr,
    textLen,
    hrefPtr,
    hrefLen,
    offset,
    styleId,
    isDirty: true,
    changedStyle: view.getUint8(offset + UINodelayoutInfo.styleChangedOffset),
    changedProps: view.getUint8(offset + UINodelayoutInfo.propsChangedOffset),
    hooks,
    hash,
    accessibility,
    onCallbacks: [
      onCallbacksOffsetMount >>> 0,
      onCallbacksOffsetUpdate >>> 0,
      onCallbacksOffsetDestroy >>> 0,
    ],
    hooksChanged: view.getUint8(offset + UINodelayoutInfo.hooksChangedOffset),
    morph:
      view.getUint8(offset + UINodelayoutInfo.morphOffset) > 0 ? true : false,
    layer: view.getUint8(offset + UINodelayoutInfo.layerOffset),
  };
}

// ✅ Faster: Reuse decoder (2-3x faster)
const textDecoder = new TextDecoder();

export function readWasmString(ptr, len) {
  if (len === 0) return "";
  const bytes = new Uint8Array(wasmInstance.memory.buffer, ptr, len);
  return textDecoder.decode(bytes);
}
