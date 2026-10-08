// URLs from the app become link targets, iframe sources and navigations. A
// `javascript:` (or `vbscript:`) URL in any of those runs script in the app's
// origin, so a link built from user input would be an XSS hole. Browsers
// ignore case, and tabs, newlines and other control characters anywhere in
// the scheme ("java\tscript:"), so those are stripped before checking.
const SCRIPT_SCHEME = /^(?:javascript|vbscript):/i;

export const BLOCKED_URL = "about:blank#blocked";

export function safeUrl(url) {
  const normalized = String(url).replace(/[\u0000- ]/g, "");
  if (SCRIPT_SCHEME.test(normalized)) {
    console.error(`vapor: blocked a ${normalized.split(":")[0].toLowerCase()}: URL`);
    return BLOCKED_URL;
  }
  return url;
}

// Sets an element's href, or removes it when the URL is blocked: an anchor
// without href cannot be followed, where one pointing at a placeholder would
// still navigate the page away.
export function setSafeHref(element, url) {
  const safe = safeUrl(url ?? "");
  if (safe === BLOCKED_URL) element.removeAttribute("href");
  else element.setAttribute("href", safe);
}

