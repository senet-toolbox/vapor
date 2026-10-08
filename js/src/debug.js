// Internal diagnostics. Silent unless the page sets
//   globalThis.__VAPOR_DEBUG__ = true
// before the runtime loads, so a production app's console carries only real
// errors and what the app itself prints.
export function debug(...args) {
  if (globalThis.__VAPOR_DEBUG__) console.log("[vapor]", ...args);
}
