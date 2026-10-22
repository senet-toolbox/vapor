/**
 * Crash reports: when the app's wasm panics or traps, posts what happened to
 * the URL the app gave `Vapor.reportErrors`, as the JSON reverb-errors
 * records. Off until the app calls it.
 *
 * Everything here runs in JS, from what JS already holds: the error and its
 * stack, the panic message Zig wrote to stderr, and the last events the
 * runtime dispatched. It never calls back into the wasm that just crashed.
 */
import { parseWasmError } from "./formatter.js";

/** Events kept for a report, the latest last. */
const keptEvents = 20;
/** Reports one page sends at most, so a crash in every frame is not a flood. */
const maxReports = 10;

let config = null;
let sentCount = 0;
const reported = new WeakSet();
const recentEvents = [];
/** What Zig wrote to stderr lately; a panic's message is in it. */
let stderrTail = "";
/** A page load is a session: reports from one share the id. */
const sessionId = crypto.randomUUID();

export function configureErrorReports(url, release, environment) {
  config = { url, release: release || null, environment: environment || null };
}

/** Called for each event the runtime hands to wasm. */
export function recordEvent(eventType, elementId) {
  if (!config) return;
  recentEvents.push({ timestamp: nowMicros(), event_type: eventType, element_id: elementId || null });
  if (recentEvents.length > keptEvents) recentEvents.shift();
}

/** Called with what Zig writes to stderr (`std.debug.print`, panics). */
export function noteStderr(text) {
  stderrTail = (stderrTail + text).slice(-4096);
}

/**
 * Reports `error` if it came out of the wasm: a trap, which a panic ends
 * in. Safe to call more than once for the same error.
 */
export function reportCrash(error, elementId) {
  if (!config || !(error instanceof WebAssembly.RuntimeError)) return;
  if (reported.has(error)) return;
  reported.add(error);
  if (sentCount >= maxReports) return;
  sentCount++;

  const parsed = parseWasmError(error);
  // Zig's panic handler prints "panic: <message>" before it aborts.
  const panic = /(?:^|\n)(?:thread \d+ )?panic: ([^\n]*)/.exec(stderrTail);
  stderrTail = "";
  const report = {
    element_id: elementId || null,
    wasmError: {
      type: panic ? "Panic" : parsed.type,
      message: panic ? panic[1] : parsed.message,
      is_wasm_trap: true,
      crash_site: parsed.crashSite ? frame(parsed.crashSite) : null,
      user_stack: parsed.userStack.map(frame),
    },
    events: recentEvents.slice(),
    timestamp: nowMicros(),
    route: location.pathname,
    url: location.href,
    session_id: sessionId,
    user_agent: navigator.userAgent,
    environment: config.environment,
    release: config.release,
  };
  // text/plain, so a backend on another origin gets it without a preflight;
  // keepalive, so it is sent even if the page goes away.
  fetch(config.url, {
    method: "POST",
    headers: { "Content-Type": "text/plain" },
    body: JSON.stringify(report),
    keepalive: true,
    credentials: "same-origin",
  }).catch(() => {});
}

function frame(f) {
  return {
    function: f.function ?? f.raw ?? null,
    wasm_function_index: f.wasmFunctionIndex ?? null,
    wasm_offset: f.wasmOffset ?? null,
    file: f.file ?? null,
    line: f.line ?? null,
    column: f.column ?? null,
    frame_type: f.type,
  };
}

function nowMicros() {
  return Math.round((performance.timeOrigin + performance.now()) * 1000);
}

// Whatever the runtime did not catch itself: timers, fetch callbacks,
// listeners.
window.addEventListener("error", (e) => reportCrash(e.error));
window.addEventListener("unhandledrejection", (e) => reportCrash(e.reason));
