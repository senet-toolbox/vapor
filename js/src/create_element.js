/** Building DOM elements from UINodes: per-type construction, link routing, listeners and accessibility. */
import { debug } from "./debug.js";
import { COMPONENT_TYPES } from "./traversal.js";
import { safeUrl, setSafeHref } from "./url.js";
import { DynamicStructReader } from "./wasi.js";
import {
  currentPath,
  readWasmString,
  rerenderRoute,
  text_data,
  wasmInstance,
} from "./wasi_obj.js";

/**
 * Routes plain clicks on same-origin links client-side. Attached once per
 * element: links are bound both when created and when hydrated.
 */
function bindLinkRouting(element) {
  if (element.__vaporLink) return;
  element.__vaporLink = true;
  element.addEventListener("click", onLinkClick);
}

function onLinkClick(event) {
  // Everything but a plain left click on a same-origin link is the browser's:
  // new-tab/window clicks, other origins (they used to be routed internally to
  // their path), and target or download links.
  if (
    event.defaultPrevented ||
    event.button !== 0 ||
    event.metaKey ||
    event.ctrlKey ||
    event.shiftKey ||
    event.altKey
  ) {
    return;
  }
  const anchor = event.currentTarget;
  if ((anchor.target && anchor.target !== "_self") || anchor.hasAttribute("download")) {
    return;
  }
  if (!anchor.hasAttribute("href")) return; // blocked or empty: nothing to follow
  const url = new URL(anchor.href);
  if (url.origin !== window.location.origin) return;
  event.preventDefault();

  const path = url.pathname;
  const samePage = path === window.location.pathname;
  requestAnimationFrame(() => {
    // rerenderRoute pushes the history entry for the new path.
    if (!samePage) rerenderRoute(path);
    if (!url.hash) return;
    requestAnimationFrame(() => {
      const target = document.getElementById(url.hash.substring(1));
      if (target) target.scrollIntoView({ block: "center" });
      // One history entry per click: a new page already got one above.
      if (samePage) window.history.pushState({}, "", path + url.hash);
      else window.history.replaceState({}, "", path + url.hash);
    });
  });
}

/**
 * Create a link element with route handling
 * @param {Object} renderCmd - The render command
 * @param {HTMLElement} tree_node - The current tree node
 * @param {Object} layout - The layout information
 * @returns {HTMLAnchorElement} - The created link element
 */
function createLinkElement(element, uinode) {
  const href =
    uinode.hrefLen > 0 ? readWasmString(uinode.hrefPtr, uinode.hrefLen) : "";
  setSafeHref(element, href);

  const label = wasmInstance.getAriaLabel(uinode.offset);
  if (label) {
    const length = wasmInstance.getAriaLabelLen();
    element.ariaLabel = readWasmString(label, length);
  }

  bindLinkRouting(element);

  return element;
}

function getTextData(route, id) {
  if (text_data !== undefined) {
    if (text_data[route] === undefined) {
      return null;
    }
    return text_data[route][id];
  }
  return null;
}

/**
 * Create an element based on its type
 * @param {Object} uinode - The render command
 * @returns {HTMLElement} - The created element
 */
export function attachElementListeners(element, renderCmd) {
  switch (renderCmd.elemType) {
    case COMPONENT_TYPES.GRAPHIC:
      const href = readWasmString(renderCmd.hrefPtr, renderCmd.hrefLen);
      fetch(href)
        .then((res) => res.text())
        .then((text) => {
          element.innerHTML = text.replace(/^\s+|\s+$/g, "");
        })
        .catch((err) => {
          console.error("Fetch failed:", err);
        });
      break;

    case COMPONENT_TYPES.VIDEO:
      debug("Video");
      const offset = wasmInstance.getVideo(renderCmd.nodePtr);
      debug("Offset", offset);
      if (offset === 0) break; // Use break, not return
      const videoView = new DataView(wasmInstance.memory.buffer, offset);
      const srcPtr = videoView.getUint32(0, true);
      if (srcPtr) {
        const srcLen = videoView.getUint32(4, true);
        element.src = readWasmString(srcPtr, srcLen);
      }
      element.autoplay = videoView.getUint8(8) === 1;
      break;

    case COMPONENT_TYPES.LINK:
      bindLinkRouting(element);
      break;

    default:
      break;
  }
}

/**
 * Apply accessibility attributes to an element
 * @param {HTMLElement} element
 * @param {number} offset - The node offset
 */
export function applyAccessibility(element, offset) {
  const ptr = wasmInstance.getAccessibilityAttributes(offset);
  if (ptr === 0) return;

  const len = wasmInstance.getAccessibilityAttributesLen();
  if (len === 0) return;

  const attrString = readWasmString(ptr, len);

  // Parse and apply attributes
  // The string looks like: ' role="dialog" aria-modal="true" aria-label="Search"'
  const attrRegex = /(\S+)="([^"]*)"/g;
  let match;
  while ((match = attrRegex.exec(attrString)) !== null) {
    const [, name, value] = match;
    element.setAttribute(name, value);
  }
}

/**
 * Create an element based on its type
 * @param {Object} renderCmd - The render command
 * @returns {HTMLElement} - The created element
 */
export function createElementByType(uinode) {
  let element;
  let text;
  let label;
  let route = currentPath === "/" ? "/root" : `/root${currentPath}`;

  switch (uinode.elemType) {
    case COMPONENT_TYPES.TEXT:
      element = document.createElement("p");
      text = readWasmString(uinode.textPtr, uinode.textLen);
      element.textContent = text;
      break;

    case COMPONENT_TYPES.TEXT_GRADIENT:
      element = document.createElement("p");
      element.style.background =
        "-webkit-linear-gradient(45deg, #E04F67, #C72C4A, #4800FF)";
      element.style["-webkit-background-clip"] = "text";
      element.style["-webkit-text-fill-color"] = "transparent";
      element.textContent = uinode.text;
      break;

    case COMPONENT_TYPES.TEXT_AREA:
      element = document.createElement("textarea");

      text = readWasmString(uinode.textPtr, uinode.textLen);
      const text_field_ptr = wasmInstance.getFieldName(uinode.offset) >>> 0;
      if (text_field_ptr) {
        const field_len = wasmInstance.getFieldNameLen();
        const field = readWasmString(text_field_ptr, field_len);
        element.setAttribute("name", field);
      }
      const text_instansePtr = wasmInstance.getTextFieldParams(uinode.offset);
      if (text_instansePtr) {
        const fieldCount = wasmInstance.getTextFieldCount(uinode.offset);
        const reader = new DynamicStructReader(
          wasmInstance,
          wasmInstance.memory,
        );
        const fieldStruct = reader.readStruct(
          uinode.offset,
          text_instansePtr,
          fieldCount,
          "getTextFieldDescriptor",
        );
        element.placeholder =
          fieldStruct.default !== null ? String(fieldStruct.default) : "";
        element.value =
          fieldStruct.value !== null ? String(fieldStruct.value) : "";
      }
      break;

    case COMPONENT_TYPES.HTML_TEXT:
      element = document.createElement("p");
      text =
        getTextData(route, uinode.id) ??
        readWasmString(uinode.textPtr, uinode.textLen);
      element.innerHTML = text;
      break;

    case COMPONENT_TYPES.CODE:
      element = document.createElement("code");
      text = readWasmString(uinode.textPtr, uinode.textLen);
      element.textContent = text;
      break;

    case COMPONENT_TYPES.SPAN:
      element = document.createElement("span");
      text = readWasmString(uinode.textPtr, uinode.textLen);
      element.innerText = text;
      break;

    case COMPONENT_TYPES.JSON_EDITOR:
      element = document.createElement("textarea");
      text = readWasmString(uinode.textPtr, uinode.textLen);
      element.textContent = text;
      break;

    case COMPONENT_TYPES.ALLOC_TEXT:
      element = document.createElement("p");
      text = readWasmString(uinode.textPtr, uinode.textLen);
      element.textContent = text;
      break;

    case COMPONENT_TYPES.IMAGE:
      element = document.createElement("img");
      const alt = wasmInstance.getAlt(uinode.offset);
      if (alt >>> 0) {
        const length = wasmInstance.getAltLen();
        const altText = readWasmString(alt, length);
        element.setAttribute("alt", altText);
      }
      const src = readWasmString(uinode.hrefPtr, uinode.hrefLen);
      element.setAttribute("src", src);
      break;

    case COMPONENT_TYPES.LAZY_IMAGE:
      element = document.createElement("img");
      element.src = readWasmString(uinode.hrefPtr, uinode.hrefLen);
      element.loading = "lazy";
      break;

    case COMPONENT_TYPES.PRE_IMAGE:
      element = document.createElement("img");
      element.src = readWasmString(uinode.hrefPtr, uinode.hrefLen);
      element.setAttribute("fetchpriority", "high");
      break;

    case COMPONENT_TYPES.INTERSECTION:
      element = document.createElement("section");
      break;

    case COMPONENT_TYPES.FLEXBOX:
    case COMPONENT_TYPES.BOX:
    case COMPONENT_TYPES.BLOCK:
    case COMPONENT_TYPES.DRAGGABLE:
    case COMPONENT_TYPES.GRADIENT:
    case COMPONENT_TYPES.GRAPHIC:
      element = document.createElement("div");
      if (uinode.elemType === COMPONENT_TYPES.GRADIENT) {
        element.style.background =
          "-webkit-linear-gradient(45deg, #8886f2, #e04597, #ee6994)";
      } else if (uinode.elemType === COMPONENT_TYPES.GRAPHIC) {
        const href = readWasmString(uinode.hrefPtr, uinode.hrefLen);
        fetch(href)
          .then((res) => res.text())
          .then((text) => {
            element.innerHTML = text.replace(/^\s+|\s+$/g, "");
          })
          .catch((err) => {
            // console.error("Fetch failed:", err);
          });
      }
      break;
    case COMPONENT_TYPES.ANCHOR:
      element = document.createElement("div");
      break;

    case COMPONENT_TYPES.TEXT_FIELD:
      element = document.createElement("input");
      text = readWasmString(uinode.textPtr, uinode.textLen);
      const field_ptr = wasmInstance.getFieldName(uinode.offset) >>> 0;
      if (field_ptr) {
        const field_len = wasmInstance.getFieldNameLen();
        const field = readWasmString(field_ptr, field_len);
        element.setAttribute("name", field);
      }
      const instansePtr = wasmInstance.getTextFieldParams(uinode.offset);
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
        element.placeholder =
          fieldStruct.default !== null ? String(fieldStruct.default) : "";
        element.value =
          fieldStruct.value !== null ? String(fieldStruct.value) : "";

        element.required =
          fieldStruct.required !== null ? fieldStruct.required : "";

        switch (fieldStruct.type) {
          case 0:
            element.type = "number";
            break;
          case 1:
            element.type = "number";
            break;
          case 2:
            element.type = "text";
            break;
          case 3:
            element.type = "checkbox";
            break;
          case 4:
            debug("Radio", fieldCount);
            element.type = "radio";
            break;
          case 5:
            element.type = "password";
            break;
          case 6:
            element.type = "email";
            break;
          case 7:
            element.type = "file";
            break;
          case 8:
            element.type = "tel";
            break;
          case 9:
            debug("Date");
            element.type = "date";
            break;
        }
        if (element.type !== "number") {
          if (fieldStruct.max_len) {
            element.maxLength = fieldStruct.max_len;
          }
          if (fieldStruct.min_len) {
            element.minLength = fieldStruct.min_len;
          }
        } else {
          element.max = fieldStruct.max_len;
          element.min = fieldStruct.min_len;
        }
      }
      break;

    case COMPONENT_TYPES.BUTTON:
    case COMPONENT_TYPES.BUTTON_CYCLE:
      element = document.createElement("button");
      element.type = "button";
      label = wasmInstance.getAriaLabel(uinode.offset);
      if (label) {
        const length = wasmInstance.getAriaLabelLen();
        element.ariaLabel = readWasmString(label, length);
      }
      break;

    case COMPONENT_TYPES.BUTTON_CTX:
      element = document.createElement("button");
      element.type = "button";
      label = wasmInstance.getAriaLabel(uinode.offset);
      if (label) {
        const length = wasmInstance.getAriaLabelLen();
        element.ariaLabel = readWasmString(label, length);
      }
      break;

    case COMPONENT_TYPES.SUBMIT_BUTTON:
      element = document.createElement("button");
      element.type = "submit";
      break;

    case COMPONENT_TYPES.HEADER:
      element = document.createElement("h1"); // Will be replaced by HEADING
      text = readWasmString(uinode.textPtr, uinode.textLen);
      element.textContent = text;
      break;

    case COMPONENT_TYPES.SVG:
      const svgString =
        getTextData(route, uinode.id) ??
        readWasmString(uinode.textPtr, uinode.textLen);
      const cleanSvg = svgString.replace(/^\s+|\s+$/g, "");
      const parser = new DOMParser();
      const doc = parser.parseFromString(cleanSvg, "image/svg+xml");
      element = doc.documentElement;
      break;

    case COMPONENT_TYPES.LINK:
      element = document.createElement("a");
      element = createLinkElement(element, uinode);
      break;

    case COMPONENT_TYPES.REDIRECT_LINK:
      element = document.createElement("a");
      const aria_label = wasmInstance.getAriaLabel(uinode.offset);
      if (aria_label) {
        const length = wasmInstance.getAriaLabelLen();
        element.ariaLabel = readWasmString(aria_label, length);
      }

      setSafeHref(element, readWasmString(uinode.hrefPtr, uinode.hrefLen));
      break;

    case COMPONENT_TYPES.EMBEDLINK:
    case COMPONENT_TYPES.EMBEDICON:
      element = document.createElement("link");
      element.rel =
        uinode.elemType === COMPONENT_TYPES.EMBEDLINK ? "stylesheet" : "icon";
      element.crossorigin = "anonymous";
      element.href = readWasmString(uinode.hrefPtr, uinode.hrefLen);
      break;

    case COMPONENT_TYPES.ICON:
      element = document.createElement("i");
      break;

    case COMPONENT_TYPES.LIST:
      element = document.createElement("ul");
      break;

    case COMPONENT_TYPES.LISTITEM:
      element = document.createElement("li");
      break;

    case COMPONENT_TYPES.SELECT:
      element = document.createElement("select");
      break;

    case COMPONENT_TYPES.SELECT_ITEM:
      element = document.createElement("option");
      break;

    case COMPONENT_TYPES.LABEL:
      element = document.createElement("label");
      const label_name_ptr = wasmInstance.getFieldName(uinode.offset) >>> 0;
      if (label_name_ptr) {
        const label_name_len = wasmInstance.getFieldNameLen();
        const field = readWasmString(label_name_ptr, label_name_len);
        element.setAttribute("for", field);
      }
      // element.htmlFor = readWasmString(
      //   uinode.hrefPtr,
      //   uinode.hrefLen,
      // );
      text = readWasmString(uinode.textPtr, uinode.textLen);
      element.textContent = text;
      break;

    case COMPONENT_TYPES.FORM:
      element = document.createElement("form");
      element.action = "";
      break;

    case COMPONENT_TYPES.TABLE:
      element = document.createElement("table");
      break;

    case COMPONENT_TYPES.TABLE_ROW:
      element = document.createElement("tr");
      break;

    case COMPONENT_TYPES.TABLE_CELL:
      element = document.createElement("td");
      break;

    case COMPONENT_TYPES.TABLE_HEADER:
      element = document.createElement("thead");
      break;

    case COMPONENT_TYPES.TABLE_BODY:
      element = document.createElement("tbody");
      break;

    case COMPONENT_TYPES.TABLE_HEAD:
      element = document.createElement("th");
      break;

    case COMPONENT_TYPES.CANVAS:
      element = document.createElement("canvas");
      break;

    case COMPONENT_TYPES.HEADING:
      const level = wasmInstance.getHeadingLevel(uinode.offset); // Use template literal to create h1-h6, defaulting to h1
      element = document.createElement(
        `h${level > 0 && level < 7 ? level : 1}`,
      );
      text = readWasmString(uinode.textPtr, uinode.textLen);
      element.textContent = text;
      break;

    case COMPONENT_TYPES.VIDEO:
      element = document.createElement("video");
      const offset = wasmInstance.getVideo(uinode.offset);
      if (offset === 0) break; // Use break, not return
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
      break;

    case COMPONENT_TYPES.IFRAME:
      element = document.createElement("iframe");
      element.src = safeUrl(readWasmString(uinode.hrefPtr, uinode.hrefLen));
      break;

    case COMPONENT_TYPES.FIELDSET:
      element = document.createElement("fieldset");
      break;

    case COMPONENT_TYPES.SPACER:
      element = document.createElement("div");
      break;

    case COMPONENT_TYPES.NOOP:
      // element = document.createElement("div");
      // element.style.display = "none";
      break;

    default:
      element = document.createElement("div");
      break;
  }

  if (element) {
    element.id = uinode.id;

    // After creating the element, apply accessibility
    if (uinode.accessibility) {
      applyAccessibility(element, uinode.offset);
    }
  }
  return element;
}
