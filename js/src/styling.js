/**
 * Maintains the stylesheet: inserts, updates and removes the CSS rules the
 * wasm generates.
 */
import {
  wasmInstance,
  styleSheet,
  readWasmString,
  rebuildCacheFromStylesheet,
} from "./runtime.js";

/** Index of each rule in `styleSheet`, by its selector. */
export const styleRuleCache = new Map();
/** Class attributes by the node's style hash (see `memory_reader.js`). */
export const styleClassCache = new Map();
/** Class attributes whose rules are all in the sheet. */
const processedStyleIds = new Set();

/** The class a rule styles: ".lay_x" for ".lay_x:hover", or for the first
 * rule inside an @media block. */
function ruleClass(rule) {
  const selector = rule.selectorText ?? rule.cssRules?.[0]?.selectorText;
  if (!selector) return null;
  const match = /^\.[\w-]+/.exec(selector);
  return match ? match[0] : null;
}

/** Deletes the rules of the classes the wasm queued as unused. */
export function batchRemoveTombStones() {
  const tombstoneCount = wasmInstance.getTombstoneCount();
  if (tombstoneCount === 0) return;

  const toRemove = new Set();
  for (let i = 0; i < tombstoneCount; i++) {
    const ptr = wasmInstance.getTombstoneClassNamePtr(i);
    if (ptr === 0) continue;
    const len = wasmInstance.getTombstoneClassNameLength(i);
    toRemove.add(`.${readWasmString(ptr, len)}`);
  }

  // Back to front, so deleting a rule does not shift the ones still to visit.
  for (let i = styleSheet.cssRules.length - 1; i >= 0; i--) {
    if (toRemove.has(ruleClass(styleSheet.cssRules[i]))) {
      styleSheet.deleteRule(i);
    }
  }

  rebuildCacheFromStylesheet();
  // A class string seen before may name a removed class; check them again.
  processedStyleIds.clear();
  styleClassCache.clear();
  wasmInstance.clearTombstones();
}

/**
 * Classes vapor generates, by prefix: how to read the CSS for one from the
 * wasm, and the pseudo-class its rule targets. A `resp_` class's CSS is one
 * or more whole @media rules instead.
 */
const generatedClasses = [
  ["vis_", (node) => wasmInstance.getVisualStyle(node, 3), () => wasmInstance.getVisualLen(), ""],
  ["pos_", (node) => wasmInstance.getPositionStyle(node, 3), () => wasmInstance.getPositionLen(), ""],
  ["lay_", (node) => wasmInstance.getLayoutStyle(node, 3), () => wasmInstance.getLayoutLen(), ""],
  ["intr_", (node) => wasmInstance.getVisualStyle(node, 0), () => wasmInstance.getVisualLen(), ":hover"],
  ["mapa_", (node) => wasmInstance.getMapaStyle(node, 0), () => wasmInstance.getMapaLen(), ""],
  ["anim_", (node) => wasmInstance.getAnimationStyle(node, 0), () => wasmInstance.getAnimationLen(), ""],
  ["tran_", (node) => wasmInstance.getTransformsStyle(node, 0), () => wasmInstance.getTransformsLen(), ""],
  ["resp_", (node) => wasmInstance.getResponsiveStyle(node), () => wasmInstance.getStyleLen(), null],
];

function generatedClass(className) {
  for (const entry of generatedClasses) {
    if (className.startsWith(entry[0])) return entry;
  }
  return null;
}

/** Reads a string the wasm returned as a pointer, then its length. */
function readCss(ptr, len) {
  return ptr === 0 ? "" : readWasmString(ptr, len());
}

/** Appends `rule` and caches its index under `selector`. */
function appendRule(selector, rule) {
  const index = styleSheet.cssRules.length;
  styleSheet.insertRule(rule, index);
  styleRuleCache.set(selector, index);
}

/** Replaces the rule cached under `selector`, or appends it. */
function replaceRule(selector, rule) {
  const index = styleRuleCache.get(selector);
  if (index === undefined) {
    appendRule(selector, rule);
  } else {
    styleSheet.deleteRule(index);
    styleSheet.insertRule(rule, index);
  }
}

/** Writes the rule of a generated class the sheet does not have yet. */
function addGeneratedRule(nodePtr, className, [, read, len, pseudo]) {
  const css = readCss(read(nodePtr), len);
  const selector = `.${className}`;
  if (pseudo === null) {
    // One @media rule per breakpoint; insertRule takes a single rule.
    const index = styleSheet.cssRules.length;
    const parsed = new CSSStyleSheet();
    parsed.replaceSync(css);
    for (const rule of parsed.cssRules) {
      styleSheet.insertRule(rule.cssText, styleSheet.cssRules.length);
    }
    styleRuleCache.set(selector, index);
  } else {
    appendRule(selector + pseudo, `${selector}${pseudo} { ${css} }`);
  }
}

/** Writes the rules of a class the app named (`style_id`): its style, the
 * rule it gives its children, and its hover style. */
function addNamedRules(nodePtr, className) {
  const selector = `.${className}`;
  appendRule(selector, `${selector} { ${readCss(wasmInstance.getStyle(nodePtr), () => wasmInstance.getStyleLen())} }`);

  const inherited = readCss(wasmInstance.getInheritedStyle(nodePtr), () => wasmInstance.getInheritedLen());
  if (inherited.length > 0) {
    const inheritedSelector = inherited.slice(0, inherited.indexOf("{")).trim();
    if (!styleRuleCache.has(inheritedSelector)) appendRule(inheritedSelector, inherited);
  }

  const hover = readCss(wasmInstance.getVisualStyle(nodePtr, 0), () => wasmInstance.getVisualLen());
  const hoverSelector = `${selector}:hover`;
  if (hover.length > 0 || styleRuleCache.has(hoverSelector)) {
    replaceRule(hoverSelector, `${hoverSelector} { ${hover} }`);
  }
}

/**
 * Sets an element's class attribute, first adding any rule its classes need.
 * A class the app named is rewritten each time, since its style can change
 * under the same name.
 */
export function updateComponentStyle(nodePtr, classAttribute, _unused, element) {
  if (classAttribute.length === 0) {
    element.setAttribute("class", "");
    return;
  }

  // Every rule this exact attribute needs is already in the sheet.
  if (processedStyleIds.has(classAttribute)) {
    element.setAttribute("class", classAttribute);
    return classAttribute;
  }

  for (const className of classAttribute.split(" ")) {
    if (className.length === 0) continue;
    const generated = generatedClass(className);
    const selector = `.${className}${generated?.[3] ?? ""}`;

    if (!styleRuleCache.has(selector)) {
      if (generated) {
        addGeneratedRule(nodePtr, className, generated);
      } else {
        addNamedRules(nodePtr, className);
      }
    } else if (!generated && element.localName !== "i") {
      const css = readCss(wasmInstance.getStyle(nodePtr), () => wasmInstance.getStyleLen());
      replaceRule(selector, `${selector} { ${css} }`);
    }
  }

  processedStyleIds.add(classAttribute);
  element.setAttribute("class", classAttribute);
  return classAttribute;
}

/**
 * Sets the class attribute of an element from a prerendered page, whose
 * rules came with the page's stylesheet. An icon (`<i>`) keeps the class its
 * icon font gave it.
 */
export function setRuleStyle(classAttribute, element) {
  if (element.localName === "i" && !styleRuleCache.has(classAttribute)) return;
  element.setAttribute("class", classAttribute);
}
