// Browser tests for vapor: builds nothing, serves tests/browser/app, drives it
// in headless Chrome over the DevTools protocol, and checks the DOM.
//
//   node tests/browser/run.mjs            (after `zig build` in tests/browser/app)
//   zig build browser-test                (does both)
//
// No npm dependencies: Node >= 22 provides fetch and WebSocket. Chrome is found
// via $CHROME, then the usual install locations.

import { spawn } from "node:child_process";
import { createServer } from "node:http";
import { existsSync, mkdtempSync, readFileSync, rmSync, statSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, extname, join, normalize, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const appDir = resolve(dirname(fileURLToPath(import.meta.url)), "app");
// An app whose wasm imports every binding vapor declares; see its main.zig.
const bindingsDir = resolve(dirname(fileURLToPath(import.meta.url)), "bindings");
// Arguments, in any order:
//   --static   serve the prerendered pages (`zig build -Dgenerate=true` in the
//              app) the way a static host would, so every test runs against
//              hydrated HTML instead of a client-rendered shell
//   --serve    only serve the app, for poking at in a real browser
//   <text>     run only tests whose name contains it
const flags = new Set(process.argv.slice(2).filter((a) => a.startsWith("--")));
const only = process.argv.slice(2).find((a) => !a.startsWith("--"));
const staticMode = flags.has("--static");

// ── static server ───────────────────────────────────────────────────────────

const mime = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript",
  ".wasm": "application/wasm",
  ".txt": "text/plain; charset=utf-8",
  ".json": "application/json",
};

// Paths each server was asked for, so tests can assert what a page loaded.
const requested = { app: [], bindings: [] };
// Crash reports the runtime posted to /errors/report, as reverb-errors' route
// would receive them: `{ body, contentType }`.
const crashReports = [];

function makeServer(dir, log, staticSite) {
  return createServer((req, res) => serve(dir, log, staticSite, req, res));
}

function serve(appDir, log, staticMode, req, res) {
  const url = new URL(req.url, "http://x");
  let path = decodeURIComponent(url.pathname);
  log.push(path);
  if (req.method === "POST" && path === "/errors/report") {
    let body = "";
    req.on("data", (chunk) => (body += chunk));
    req.on("end", () => {
      crashReports.push({ body, contentType: req.headers["content-type"] });
      res.writeHead(201, { "content-type": "application/json" }).end("{}");
    });
    return;
  }
  if (staticMode) {
    // A static host: release/ is the site root, plus the wasm the runtime
    // fetches from /zig-out/bin/.
    if (!extname(path)) {
      // A prerendered page if there is one, else the host's fallback to the
      // client-rendered shell (dynamic routes, unknown paths).
      const page = path.replace(/\/$/, "") + "/index.html";
      path = existsSync(join(appDir, "release", page)) ? page : "/app.html";
    }
    // Anything not in release/ (the wasm, the /api fixtures) is what the
    // backend would serve.
    if (existsSync(join(appDir, "release", path))) path = "/release" + path;
  } else if (path === "/bundle.min.js" || path === "/browser.min.js") path = "/zig-out/bin" + path;
  const file = normalize(join(appDir, path));
  if (!file.startsWith(appDir)) return res.writeHead(400).end();

  if (extname(path)) {
    if (!existsSync(file) || !statSync(file).isFile()) return res.writeHead(404).end("not found");
    res.writeHead(200, { "content-type": mime[extname(path)] ?? "application/octet-stream" });
    return res.end(readFileSync(file));
  }
  // Routes are client-side: every extensionless path gets the app shell.
  res.writeHead(200, { "content-type": mime[".html"] });
  res.end(readFileSync(join(appDir, "template.html")));
}

// ── chrome + CDP ────────────────────────────────────────────────────────────

function findChrome() {
  const candidates = [
    process.env.CHROME,
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    "/usr/bin/google-chrome",
    "/usr/bin/google-chrome-stable",
    "/usr/bin/chromium",
    "/usr/bin/chromium-browser",
  ].filter(Boolean);
  const found = candidates.find((c) => existsSync(c));
  if (!found) throw new Error("Chrome not found; set $CHROME");
  return found;
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function launch() {
  const profile = mkdtempSync(join(tmpdir(), "vapor-browser-"));
  // Port 0: Chrome picks a free port and writes it to DevToolsActivePort in
  // the profile. A port picked here could be taken, and CI failed with
  // "Chrome did not start" now and then.
  const proc = spawn(findChrome(), [
    "--headless=new",
    "--disable-gpu",
    "--no-first-run",
    "--no-default-browser-check",
    "--no-sandbox", // CI containers run as root
    "--remote-debugging-port=0",
    `--user-data-dir=${profile}`,
    "about:blank",
  ], { stdio: ["ignore", "ignore", "pipe"] });
  let chromeErr = "";
  proc.stderr.on("data", (d) => (chromeErr = (chromeErr + d).slice(-4000)));
  let exited = null;
  proc.on("exit", (code, signal) => (exited = signal ?? code));

  // A cold start on a CI runner can take a while.
  let targets;
  const activePort = join(profile, "DevToolsActivePort");
  for (let i = 0; i < 300 && !targets && exited === null; i++) {
    try {
      const port = readFileSync(activePort, "utf8").split("\n")[0];
      targets = await (await fetch(`http://127.0.0.1:${port}/json`)).json();
    } catch {
      await sleep(100);
    }
  }
  if (!targets) {
    proc.kill();
    throw new Error(`Chrome did not start (${exited === null ? "no DevTools port after 30 s" : `exited: ${exited}`}):\n${chromeErr}`);
  }
  const ws = new WebSocket(targets.find((t) => t.type === "page").webSocketDebuggerUrl);
  await new Promise((r, j) => { ws.onopen = r; ws.onerror = j; });

  let nextId = 0;
  const pending = new Map();
  const problems = []; // uncaught exceptions and console.error, per test
  const consoleMessages = []; // every console call, per test
  ws.onmessage = (ev) => {
    const msg = JSON.parse(ev.data);
    if (msg.id && pending.has(msg.id)) {
      pending.get(msg.id)(msg);
      pending.delete(msg.id);
    } else if (msg.method === "Runtime.exceptionThrown") {
      const d = msg.params.exceptionDetails;
      problems.push(`exception: ${d.exception?.description ?? d.text}`);
    } else if (msg.method === "Runtime.consoleAPICalled") {
      const text = msg.params.args.map((a) => a.value ?? a.description).join(" ");
      consoleMessages.push(`console.${msg.params.type}: ${text}`);
      if (msg.params.type === "error") problems.push(`console.error: ${text}`);
    }
  };
  const send = (method, params = {}) => new Promise((res, rej) => {
    const id = ++nextId;
    pending.set(id, (m) => (m.error ? rej(new Error(`${method}: ${m.error.message}`)) : res(m.result)));
    ws.send(JSON.stringify({ id, method, params }));
  });
  await send("Runtime.enable");
  await send("Page.enable");
  // Headless pages never have focus, so focus/blur events would not fire.
  await send("Emulation.setFocusEmulationEnabled", { enabled: true });

  const close = () => {
    ws.close();
    proc.kill();
    try { rmSync(profile, { recursive: true, force: true }); } catch {}
  };
  return { send, problems, consoleMessages, close };
}

// ── test helpers ────────────────────────────────────────────────────────────

function makePage(cdp, origin) {
  const problems = cdp.problems;
  const consoleMessages = cdp.consoleMessages;
  const evaluate = async (expression) => {
    const r = await cdp.send("Runtime.evaluate", { expression, returnByValue: true, awaitPromise: true });
    if (r.exceptionDetails) throw new Error(`evaluate failed: ${r.exceptionDetails.exception?.description ?? r.exceptionDetails.text}`);
    return r.result.value;
  };
  const waitFor = async (expression, what, timeout = 5000) => {
    const end = Date.now() + timeout;
    let last;
    while (Date.now() < end) {
      last = await evaluate(expression).catch((e) => e.message);
      if (last === true) return;
      await sleep(25);
    }
    throw new Error(`timed out waiting for ${what ?? expression} (last: ${JSON.stringify(last)})`);
  };
  const text = (id) => evaluate(`document.getElementById(${JSON.stringify(id)})?.textContent ?? null`);
  return {
    problems,
    consoleMessages,
    // Drops expected console errors (e.g. the runtime reporting a blocked URL)
    // so they do not fail the test; returns how many matched.
    allowErrors(substring) {
      const keep = problems.filter((m) => !m.includes(substring));
      const dropped = problems.length - keep.length;
      problems.splice(0, problems.length, ...keep);
      return dropped;
    },
    evaluate,
    waitFor,
    text,
    async goto(path) {
      await cdp.send("Page.navigate", { url: path.startsWith("http") ? path : origin + path });
      await waitFor(`document.readyState === "complete"`, "page load");
      // Prerendered HTML is visible before it is live; wait for hydration.
      await waitFor(`document.documentElement.hasAttribute("data-vapor-ready")`, "vapor:ready");
    },
    async waitForText(id, expected) {
      try {
        await waitFor(
          `document.getElementById(${JSON.stringify(id)})?.textContent === ${JSON.stringify(expected)}`,
          `#${id} to read ${JSON.stringify(expected)}`,
        );
      } catch (err) {
        // The text when the wait gave up, not when it started.
        throw new Error(`${err.message.replace(/ \(last: .*\)$/, "")} (is ${JSON.stringify(await text(id))})`);
      }
    },
    async click(id) {
      const ok = await evaluate(`(() => { const e = document.getElementById(${JSON.stringify(id)}); if (!e) return false; e.click(); return true; })()`);
      if (!ok) throw new Error(`no element #${id} to click`);
    },
    async type(id, value) {
      const ok = await evaluate(`(() => { const e = document.getElementById(${JSON.stringify(id)}); if (!e) return false; e.focus(); return true; })()`);
      if (!ok) throw new Error(`no element #${id} to type into`);
      await cdp.send("Input.insertText", { text: value });
    },
    childIds: (id) => evaluate(`[...document.getElementById(${JSON.stringify(id)}).children].map((c) => c.id)`),
    async wasmMemoryBytes() {
      const proto = await cdp.send("Runtime.evaluate", { expression: "WebAssembly.Memory.prototype" });
      const found = await cdp.send("Runtime.queryObjects", { prototypeObjectId: proto.result.objectId });
      const r = await cdp.send("Runtime.callFunctionOn", {
        objectId: found.objects.objectId,
        functionDeclaration: "function () { return this.map((m) => m.buffer.byteLength); }",
        returnByValue: true,
      });
      return Math.max(0, ...r.result.value);
    },
  };
}

function assert(cond, what) {
  if (!cond) throw new Error(what);
}

function assertEqual(actual, expected, what) {
  const a = JSON.stringify(actual);
  const e = JSON.stringify(expected);
  if (a !== e) throw new Error(`${what}: expected ${e}, got ${a}`);
}

// ── tests ───────────────────────────────────────────────────────────────────

const tests = {
  async "a crash is reported once, with its panic, element, route and the events before it"(p) {
    p.crashReports.length = 0;
    await p.goto("/crash");
    await p.type("crash-note", "x");
    await p.click("crash-panic");
    const [panic] = await crashReportsArrive(p, 1);
    // A text body: a cross-origin backend gets it without a preflight.
    assert(panic.contentType.startsWith("text/plain"), `content type ${panic.contentType}`);
    assertEqual(panic.wasmError.type, "Panic", "type");
    assertEqual(panic.wasmError.message, "boom: the crash test panics", "the panic's message");
    assertEqual(panic.wasmError.is_wasm_trap, true, "a trap");
    assert(panic.wasmError.user_stack.length > 0, "a stack");
    // Where the app panicked, not the panic machinery it went through.
    assert(!/abort|Panic/.test(panic.wasmError.crash_site?.function ?? ""), `crash site ${JSON.stringify(panic.wasmError.crash_site)}`);
    assertEqual(panic.element_id, "crash-panic", "the button");
    assertEqual(panic.route, "/crash", "route");
    assert(panic.url.endsWith("/crash"), `url ${panic.url}`);
    assertEqual([panic.release, panic.environment], ["browser-test", "test"], "release and environment");
    assert(typeof panic.session_id === "string" && panic.session_id.length > 0, "a session id");
    assert(Math.abs(panic.timestamp / 1000 - Date.now()) < 60_000, `timestamp ${panic.timestamp} is microseconds, now`);
    const kinds = panic.events.map((e) => `${e.event_type} ${e.element_id}`);
    assert(kinds.includes("input crash-note") && kinds.at(-1) === "click crash-panic", `events ${JSON.stringify(kinds)}`);
    // The error also reaches window "error"; it is still one report.
    await sleep(300);
    assertEqual(p.crashReports.length, 1, "reports after the error settled");
    p.allowErrors("boom");
    p.allowErrors("unreachable");

    await p.goto("/crash");
    await p.click("crash-trap");
    const [, trap] = await crashReportsArrive(p, 2);
    assertEqual([trap.wasmError.type, trap.wasmError.message, trap.wasmError.is_wasm_trap], ["RuntimeError", "unreachable", true], "a bare trap");
    assertEqual(trap.element_id, "crash-trap", "the trap's button");
    assert(trap.session_id !== panic.session_id, "a new page is a new session");
    p.allowErrors("unreachable");
  },

  async "clicks update state and the DOM"(p) {
    await p.goto("/");
    await p.waitForText("count", "0");
    for (let i = 1; i <= 3; i++) {
      await p.click("inc");
      await p.waitForText("count", String(i));
    }
  },

  async "keyed list keeps DOM nodes across reorder, insert and remove"(p) {
    await p.goto("/list");
    await p.waitFor(`!!document.getElementById("item-5")`, "list to render");
    assertEqual(await p.childIds("items"), ["item-1", "item-2", "item-3", "item-4", "item-5"], "initial order");
    await p.evaluate(`document.getElementById("item-3").__mark = "kept"`);

    await p.click("reverse");
    await p.waitFor(`document.getElementById("items").firstElementChild?.id === "item-5"`, "reverse");
    assertEqual(await p.childIds("items"), ["item-5", "item-4", "item-3", "item-2", "item-1"], "after reverse");
    assertEqual(await p.evaluate(`document.getElementById("item-3").__mark ?? null`), "kept", "item-3 node identity after reverse");

    await p.click("prepend");
    await p.waitFor(`document.getElementById("items").firstElementChild?.id === "item-6"`, "prepend");
    assertEqual(await p.childIds("items"), ["item-6", "item-5", "item-4", "item-3", "item-2", "item-1"], "after prepend");
    assertEqual(await p.text("item-6"), "Item 6", "new item text");
    assertEqual(await p.evaluate(`document.getElementById("item-3").__mark ?? null`), "kept", "item-3 node identity after prepend");

    await p.click("remove-first");
    await p.waitFor(`!document.getElementById("item-6")`, "remove");
    assertEqual(await p.childIds("items"), ["item-5", "item-4", "item-3", "item-2", "item-1"], "after remove");
    assertEqual(await p.evaluate(`document.querySelectorAll("#items > *").length`), 5, "no leftover nodes");
  },

  async "a conditional sibling does not disturb keyed or unkeyed siblings"(p) {
    await p.goto("/cond");
    await p.waitFor(`!!document.getElementById("stable")`, "cond page");
    await p.evaluate(`document.getElementById("stable").__mark = "kept"`);
    // Unkeyed elements get generated DOM ids, so compare by text.
    const contents = `[...document.getElementById("cond-page").children].map((c) => c.textContent.trim())`;

    await p.click("toggle");
    await p.waitFor(`!!document.getElementById("banner")`, "banner to appear");
    assertEqual(await p.evaluate(contents), ["Toggle", "Banner", "Stable", "Unkeyed after"], "with banner");
    assertEqual(await p.evaluate(`document.getElementById("stable").__mark ?? null`), "kept", "#stable identity");

    await p.click("toggle");
    await p.waitFor(`!document.getElementById("banner")`, "banner to go");
    assertEqual(await p.evaluate(contents), ["Toggle", "Stable", "Unkeyed after"], "without banner");
  },

  async ".hidden(false) shows an element .hidden(true) hid"(p) {
    await p.goto("/hide");
    await p.waitFor(`!!document.getElementById("panel")`, "hide page");
    const display = `getComputedStyle(document.getElementById("panel")).display`;
    assertEqual((await p.evaluate(display)) !== "none", true, "panel shown at first");
    await p.click("toggle-hidden");
    await p.waitFor(`${display} === "none"`, "panel hidden");
    await p.click("toggle-hidden");
    await p.waitFor(`${display} !== "none"`, "panel shown again");
  },

  async "onFocus and onBlur fire on ordinary elements"(p) {
    await p.goto("/focus");
    await p.waitForText("focus-count", "0/0");
    await p.evaluate(`document.getElementById("focus-target").focus()`);
    await p.waitForText("focus-count", "1/0");
    await p.evaluate(`document.getElementById("focus-target").blur()`);
    await p.waitForText("focus-count", "1/1");

    // Text fields get focus and input through the delegated root listener;
    // each event must reach Zig exactly once.
    await p.evaluate(`document.getElementById("focus-field").focus()`);
    await p.waitForText("field-count", "1/0");
    await p.type("focus-field", "a");
    await p.waitForText("field-count", "1/1");
    await sleep(200);
    assertEqual(await p.text("field-count"), "1/1", "each event dispatched once");
  },

  async "Hooks runs mounted and destroy around its block"(p) {
    await p.goto("/hooks");
    await p.waitForText("hooks-count", "0/0");
    await p.click("toggle-hooks");
    await p.waitFor(`!!document.getElementById("hooked")`, "hooked block");
    await sleep(50);
    await p.click("hooks-refresh");
    await p.waitForText("hooks-count", "1/0");
    await p.click("toggle-hooks");
    await p.waitFor(`!document.getElementById("hooked")`, "hooked block removed");
    await sleep(50);
    await p.click("hooks-refresh");
    await p.waitForText("hooks-count", "1/1");
  },

  async "unused CSS rules are removed and responsive rules insert"(p) {
    await p.goto("/styles");
    await p.waitFor(`!!document.getElementById("styled")`, "styles page");
    const rules = `[...document.styleSheets, ...document.adoptedStyleSheets].flatMap((s) => [...s.cssRules])`;
    const media = `${rules}.filter((r) => r.media && r.cssRules[0]?.selectorText.startsWith(".resp_")).map((r) => r.cssText.replace(/resp_\\w+/, "resp"))`;
    // Both breakpoints of #responsive made it into the sheet.
    assertEqual(await p.evaluate(media), [
      "@media (max-width: 767px) {\n  .resp { display: flex; flex-direction: row; gap: 4px; }\n}",
      "@media (min-width: 1024px) {\n  .resp { display: flex; flex-direction: row; gap: 8px; }\n}",
    ], "@media rules");

    const classOf = (id) => p.evaluate(`document.getElementById("${id}").className`);
    assertEqual((await classOf("class-a")).includes("user-a"), true, "#class-a has user-a");
    assertEqual((await classOf("class-b")).includes("user-b"), true, "#class-b has user-b");
    assertEqual((await classOf("class-b")).includes("user-a"), false, "#class-b lacks user-a");

    const width = `getComputedStyle(document.getElementById("styled")).width`;
    const count = `${rules}.length`;
    for (let i = 1; i <= 5; i++) {
      await p.click("restyle");
      await p.waitFor(`${width} === "${100 + i}px"`, `width ${100 + i}`);
    }
    const before = await p.evaluate(count);
    // Past the grace period, the next render drops the five old classes.
    await sleep(3500);
    await p.click("restyle");
    await p.waitFor(`${width} === "106px"`, "width 106");
    await p.waitFor(`${count} <= ${before} - 4`, "old rules removed");
    // Styling still applies after the sheet shrank, including to a class
    // string seen before the removal.
    assertEqual((await p.evaluate(media)).length, 2, "@media rules kept");
    // A hover rule is cached under its real selector, so rebuilding the cache
    // after the removal does not make the next render insert it again.
    await p.click("restyle");
    await p.waitFor(`${width} === "107px"`, "width 107");
    const hovers = `${rules}.filter((r) => /^\\.intr_\\w+:hover$/.test(r.selectorText ?? "")).length`;
    assertEqual(await p.evaluate(hovers), 1, "one hover rule");
  },

  async "document listeners for one event are removed one at a time"(p) {
    await p.goto("/listeners");
    await p.waitForText("key-count", "0/0");
    await p.click("add-listeners");
    const key = `document.dispatchEvent(new KeyboardEvent("keydown", { key: "k" }))`;
    await p.evaluate(key);
    await p.click("listeners-refresh");
    await p.waitForText("key-count", "1/1");
    // Removing A used to remove whichever keydown handler was stored last.
    await p.click("remove-a");
    await p.evaluate(key);
    await p.click("listeners-refresh");
    await p.waitForText("key-count", "1/2");
  },

  async "events after renders that change nothing reach the current node"(p) {
    await p.goto("/stale");
    await p.waitForText("stale-hovers", "hovers=0");
    // These renders change nothing, so the DOM is not walked; the runtime
    // must still point its registry at the nodes of the latest render.
    for (let i = 0; i < 3; i++) {
      await p.click("stale-refresh");
      await sleep(50);
    }
    await p.evaluate(`document.getElementById("stale-target").dispatchEvent(new MouseEvent("mouseover", { bubbles: true }))`);
    await p.waitFor(`/^hovers=[1-9]/.test(document.getElementById("stale-hovers").textContent)`, "the hover handler to run");
  },

  async ".createDraggable moves its element with the pointer"(p) {
    await p.goto("/drag");
    await p.waitFor(`!!document.getElementById("drag-target")`, "the draggable");
    await p.evaluate(`(() => {
      const el = document.getElementById("drag-target");
      const r = el.getBoundingClientRect();
      const x = r.left + 5, y = r.top + 5;
      const at = (dx, dy) => ({ bubbles: true, clientX: x + dx, clientY: y + dy });
      el.dispatchEvent(new PointerEvent("pointerdown", at(0, 0)));
      document.dispatchEvent(new PointerEvent("pointermove", at(30, 10)));
      document.dispatchEvent(new PointerEvent("pointerup", at(30, 10)));
    })()`);
    await p.waitFor(`document.getElementById("drag-target").style.transform.startsWith("translate3d(30px, 10px")`, "the element to follow the pointer");
  },

  async "one key press or mouseover runs an element's handler once"(p) {
    await p.goto("/once");
    await p.waitForText("once-count", "keys=0 overs=0");
    await p.evaluate(`document.getElementById("once-target").focus()`);
    await p.evaluate(`document.getElementById("once-target").dispatchEvent(new KeyboardEvent("keydown", { key: "a", bubbles: true }))`);
    await p.evaluate(`document.getElementById("once-target").dispatchEvent(new MouseEvent("mouseover", { bubbles: true }))`);
    // A render to show the counts.
    await p.evaluate(`document.getElementById("once-target").dispatchEvent(new KeyboardEvent("keydown", { key: "b", bubbles: true }))`);
    await p.waitFor(`/^keys=\\d+ overs=\\d+$/.test(document.getElementById("once-count").textContent) && document.getElementById("once-count").textContent !== "keys=0 overs=0"`, "the counts to update");
    await sleep(100);
    assertEqual(await p.text("once-count"), "keys=2 overs=1", "handler calls for 2 key presses and 1 mouseover");
  },

  async "an accessibility attribute that goes away is removed"(p) {
    await p.goto("/aria");
    const disabled = `document.getElementById("aria-target").getAttribute("aria-disabled")`;
    assertEqual(await p.evaluate(disabled), "true", "aria-disabled at first");
    await p.click("aria-toggle");
    await p.waitFor(`${disabled} === null`, "aria-disabled to go when it no longer applies");
    await p.click("aria-toggle");
    await p.waitFor(`${disabled} === "true"`, "aria-disabled to come back");
  },

  async "Element.focus focuses any element, not only text fields"(p) {
    await p.goto("/focus-any");
    await p.click("focus-any-go");
    await p.waitFor(`document.activeElement?.id === "focus-any-target"`, "the button to take focus");
    assertEqual(p.consoleMessages.filter((m) => m.includes("focus")), [], "focus complaints");
  },

  async "a named timeout armed twice fires once, and fired ones are freed"(p) {
    await p.goto("/timeout");
    await p.waitForText("timeout-state", "fires=0 last=0 pending=0");
    await p.click("timeout-arm");
    await p.click("timeout-arm");
    await p.waitForText("timeout-state", "fires=1 last=2 pending=0");
    await sleep(300);
    assertEqual(await p.text("timeout-state"), "fires=1 last=2 pending=0", "state once both timers would have fired");
    assertEqual(p.consoleMessages, [], "console output");
  },

  async "a timeout that re-arms its own name keeps running"(p) {
    await p.goto("/timeout");
    await p.click("timeout-chain");
    await p.waitForText("timeout-state", "fires=3 last=0 pending=0");
    assertEqual(p.consoleMessages, [], "console output");
  },

  async "a declared transition runs when state changes the style"(p) {
    await p.goto("/transition");
    await p.waitFor(`document.getElementById("transition-box")?.getBoundingClientRect().width === 60`, "the narrow box");
    // The box's width every frame for 200ms after the click.
    const sampleWidths = () => p.evaluate(`new Promise((done) => {
      const out = []; const t0 = performance.now();
      const tick = () => {
        const e = document.getElementById("transition-box");
        out.push(e ? Math.round(e.getBoundingClientRect().width) : -1);
        if (performance.now() - t0 < 200) requestAnimationFrame(tick); else done(out);
      };
      requestAnimationFrame(tick);
    })`);
    const sampling = sampleWidths();
    await p.click("transition-toggle");
    const seen = await sampling;
    // A 300ms linear transition from 60 to 300 passes through the middle.
    assert(seen.some((w) => w > 70 && w < 290), `width went straight from 60 to 300: ${seen.join(" ")}`);
    // With the box's own transition, not one the runtime put inline.
    assertEqual(await p.evaluate(`document.getElementById("transition-box").style.transition`), "", "inline transition");
  },

  async "navigating to a page does not animate the elements it reuses"(p) {
    await p.goto("/transition");
    await p.waitFor(`document.getElementById("transition-box")?.getBoundingClientRect().width === 60`, "the narrow box");
    // The box's width every frame for 200ms after the click.
    const sampleWidths = () => p.evaluate(`new Promise((done) => {
      const out = []; const t0 = performance.now();
      const tick = () => {
        const e = document.getElementById("transition-box");
        out.push(e ? Math.round(e.getBoundingClientRect().width) : -1);
        if (performance.now() - t0 < 200) requestAnimationFrame(tick); else done(out);
      };
      requestAnimationFrame(tick);
    })`);
    const sampling = sampleWidths();
    await p.click("transition-to-b");
    const seen = await sampling;
    assertEqual(await p.evaluate("location.pathname"), "/transition-b", "path after the link");
    // Page B's box is a different element as far as the user is concerned.
    assert(!seen.some((w) => w > 60 && w < 400), `width animated across the navigation: ${seen.join(" ")}`);
  },

  async "a .morph(true) element animates across a navigation"(p) {
    await p.goto("/transition");
    await p.waitFor(`document.getElementById("morph-box")?.getBoundingClientRect().width === 60`, "the narrow morph box");
    const sampling = p.evaluate(`new Promise((done) => {
      const out = []; const t0 = performance.now();
      const tick = () => {
        const e = document.getElementById("morph-box");
        out.push(e ? Math.round(e.getBoundingClientRect().width) : -1);
        if (performance.now() - t0 < 200) requestAnimationFrame(tick); else done(out);
      };
      requestAnimationFrame(tick);
    })`);
    await p.click("transition-to-b");
    const seen = await sampling;
    assertEqual(await p.evaluate("location.pathname"), "/transition-b", "path after the link");
    assert(seen.some((w) => w > 70 && w < 390), `morph box jumped from 60 to 400: ${seen.join(" ")}`);
  },

  async "an element that loses its onMount hook calls nothing"(p) {
    await p.goto("/mount-off");
    await p.waitFor(`!!document.getElementById("mount-off-target")`, "the target");
    await p.click("mount-off-toggle");
    await sleep(100);
    await p.click("mount-off-toggle");
    await sleep(100);
    const reports = p.consoleMessages.filter((m) => m.includes("Callback not found"));
    assertEqual(reports, [], "hook lookups that found nothing");
  },

  async "Element.listen outlives renders, does not rerender, and leaves with its element"(p) {
    await p.goto("/listen");
    await p.waitForText("listen-state", "hits=0 listeners=0");
    await p.click("listen-start");
    await p.waitForText("listen-state", "hits=0 listeners=1");

    // Its events reach Zig without a render.
    const renders = await p.text("listen-renders");
    for (let i = 0; i < 3; i++) await p.click("listen-target");
    await sleep(100);
    assertEqual(await p.text("listen-renders"), renders, "renders after listener events");
    assertEqual(await p.text("listen-state"), "hits=0 listeners=1", "state before a render");
    await p.click("listen-refresh");
    await p.waitForText("listen-state", "hits=6 listeners=1");

    // It is still attached after more renders.
    await p.click("listen-refresh");
    await p.click("listen-refresh");
    await p.click("listen-target");
    await p.click("listen-refresh");
    await p.waitForText("listen-state", "hits=8 listeners=1");

    // remove() detaches it.
    await p.click("listen-stop");
    await p.waitForText("listen-state", "hits=8 listeners=0");
    await p.click("listen-target");
    await p.click("listen-refresh");
    await p.waitForText("listen-state", "hits=8 listeners=0");

    // It goes when its element leaves the page.
    await p.click("listen-start");
    await p.waitForText("listen-state", "hits=8 listeners=1");
    await p.click("listen-toggle");
    await p.waitFor(`!document.getElementById("listen-target")`, "target removed");
    await sleep(50);
    await p.click("listen-refresh");
    await p.waitForText("listen-state", "hits=8 listeners=0");
  },

  async "typing reaches Zig state"(p) {
    await p.goto("/input");
    await p.waitForText("greeting", "Hello, !");
    await p.type("name", "Ziggy");
    await p.waitForText("greeting", "Hello, Ziggy!");
  },

  async "number fields show and write back their bound values"(p) {
    // A .float field's bind did not compile (it parsed the input as an
    // integer) and did not show the value it was bound to.
    await p.goto("/numbers");
    await p.waitForText("order", "3 at 2.5");
    assertEqual(await p.evaluate(`document.getElementById("quantity").value`), "3", "int field's value");
    assertEqual(await p.evaluate(`document.getElementById("price").value`), "2.5", "float field's value");
    await p.evaluate(`document.getElementById("price").value = ""`);
    await p.type("price", "4.75");
    await p.waitForText("order", "3 at 4.75");
    await p.evaluate(`document.getElementById("quantity").value = ""`);
    await p.type("quantity", "7");
    await p.waitForText("order", "7 at 4.75");
  },

  async "OAuth state is random, and a callback needs a sign-in this browser started"(p) {
    // KeyStone made the state from the clock, so it could be guessed, and
    // it exchanged a callback's code when no sign-in was pending: another
    // site could sign this browser into an account of its choosing.
    const signIn = async () => {
      await p.goto("/signin");
      await p.click("sign-in");
      // Google is blocked, so the page ends on the browser's error page.
      await p.waitFor(`location.pathname !== "/signin"`, "the redirect to Google");
      await p.goto("/signin");
      return p.evaluate(`localStorage.getItem("keystone_oauth_state")`);
    };
    const exchanged = () => p.requested.app.includes("/exchange/google/token");
    await p.send("Network.enable");
    await p.send("Network.setBlockedURLs", { urls: ["https://accounts.google.com/*"] });
    try {
      const first = await signIn();
      const second = await signIn();
      assertEqual(/^[0-9a-f]{32}$/.test(first), true, `state is 128 random bits (${first})`);
      assertEqual(first === second, false, "each sign-in gets its own state");

      await p.evaluate(`localStorage.clear()`);
      p.requested.app.length = 0;
      await p.goto(`/auth/callback?code=theirs&state=${first}`);
      await p.waitForText("auth-error", "oauth_guard_mismatch");
      assertEqual(exchanged(), false, "no sign-in pending: no code exchanged");

      await signIn();
      p.requested.app.length = 0;
      await p.goto("/auth/callback?code=theirs&state=0123456789abcdef0123456789abcdef");
      await p.waitForText("auth-error", "oauth_guard_mismatch");
      assertEqual(exchanged(), false, "the wrong state: no code exchanged");

      const state = await signIn();
      p.requested.app.length = 0;
      await p.goto(`/auth/callback?code=ours&state=${state}`);
      const end = Date.now() + 5000;
      while (!exchanged() && Date.now() < end) await sleep(25);
      assertEqual(exchanged(), true, "the state this browser holds: the code is exchanged");
    } finally {
      await p.send("Network.setBlockedURLs", { urls: [] });
      await p.send("Network.disable");
      await p.evaluate(`localStorage.clear()`);
    }
  },

  async "text is escaped, never parsed as HTML"(p) {
    await p.goto("/escape");
    await p.waitFor(`!!document.getElementById("payload")`, "payload");
    assertEqual(await p.text("payload"), `<img src=x onerror="window.__xss = 1">`, "payload text");
    assertEqual(await p.evaluate(`document.querySelectorAll("#payload img").length`), 0, "no <img> created");
    await sleep(200);
    assertEqual(await p.evaluate(`window.__xss ?? null`), null, "onerror never ran");
  },

  async "links navigate client-side and back works"(p) {
    await p.goto("/a");
    await p.waitFor(`!!document.getElementById("page-a")`, "page A");
    await p.evaluate(`window.__sameDocument = true`);
    await p.click("to-b");
    await p.waitFor(`!!document.getElementById("page-b") && !document.getElementById("page-a")`, "page B");
    assertEqual(await p.evaluate(`location.pathname`), "/b", "URL after link");
    assertEqual(await p.evaluate(`window.__sameDocument ?? null`), true, "no full page load");
    await p.evaluate(`history.back()`);
    await p.waitFor(`!!document.getElementById("page-a") && !document.getElementById("page-b")`, "back to A");
  },

  async "fetch result reaches the DOM"(p) {
    await p.goto("/fetch");
    await p.waitForText("fetch-state", "ok:hello from the server");
  },

  async "localStorage round-trips ints, floats and strings"(p) {
    await p.goto("/storage");
    await p.evaluate(`localStorage.clear()`);
    await p.goto("/storage");
    await p.waitForText("stored", "int=null float=null text=null");
    await p.click("save");
    // Values are read during render; the click triggers one.
    await p.waitForText("stored", "int=42 float=2.5 text=zig");
  },

  async "script URLs are blocked in links"(p) {
    await p.goto("/urls");
    await p.waitFor(`!!document.getElementById("js-link")`, "urls page");
    for (const id of ["js-link", "js-link-obfuscated"]) {
      assertEqual(await p.evaluate(`document.getElementById("${id}").getAttribute("href")`), null, `${id} has no href`);
    }
    await p.click("js-link");
    await p.click("js-link-obfuscated");
    await sleep(200);
    assertEqual(await p.evaluate(`window.__pwned ?? null`), null, "script never ran");
    assertEqual(await p.evaluate(`location.pathname`), "/urls", "clicking a blocked link goes nowhere");
    // The runtime reports each block with console.error; expected here.
    assertEqual(p.allowErrors("vapor: blocked a javascript: URL") >= 2, true, "blocks were reported");
  },

  async "only plain same-origin link clicks are routed client-side"(p) {
    await p.goto("/urls");
    await p.waitFor(`!!document.getElementById("external")`, "urls page");
    // Record whether vapor's handler took over the click, then stop the
    // navigation ourselves so the test stays on the page.
    await p.evaluate(`window.addEventListener("click", (e) => {
      window.__routed = e.defaultPrevented;
      e.preventDefault();
    })`);
    const click = (id, init = "{}") =>
      p.evaluate(`(document.getElementById("${id}").dispatchEvent(new MouseEvent("click", Object.assign({ bubbles: true, cancelable: true, button: 0 }, ${init}))), window.__routed)`);
    assertEqual(await click("external"), false, "external link left to the browser");
    assertEqual(await click("internal", "{ metaKey: true }"), false, "cmd-click left to the browser");
    assertEqual(await click("internal", "{ ctrlKey: true }"), false, "ctrl-click left to the browser");
    assertEqual(await click("internal"), true, "plain internal click routed");
    await p.waitFor(`location.pathname === "/a" && !!document.getElementById("page-a")`, "routed to /a");
    p.allowErrors("vapor: blocked a javascript: URL"); // the page renders the blocked links too
  },

  async "a link click adds exactly one history entry"(p) {
    await p.goto("/a");
    await p.waitFor(`!!document.getElementById("to-b")`, "page A");
    const before = await p.evaluate(`history.length`);
    await p.click("to-b");
    await p.waitFor(`!!document.getElementById("page-b") && !document.getElementById("page-a")`, "page B");
    await sleep(100);
    assertEqual((await p.evaluate(`history.length`)) - before, 1, "history entries added");
    await p.evaluate(`history.back()`);
    await p.waitFor(`location.pathname === "/a" && !!document.getElementById("page-a")`, "one back press returns to A");
  },

  async "an ordinary session leaves the console empty"(p) {
    // Internal diagnostics go through debug(), silent unless __VAPOR_DEBUG__.
    await p.goto("/");
    await p.waitForText("count", "0");
    await p.click("inc");
    await p.waitForText("count", "1");
    await p.goto("/list");
    await p.waitFor(`!!document.getElementById("item-1")`, "list");
    await p.click("reverse");
    await p.click("prepend");
    await p.click("remove-first");
    await p.goto("/input");
    await p.waitFor(`!!document.getElementById("name")`, "input page");
    await p.type("name", "quiet");
    await p.waitForText("greeting", "Hello, quiet!");
    await p.goto("/a");
    await p.waitFor(`!!document.getElementById("to-b")`, "page A");
    await p.click("to-b");
    await p.waitFor(`!!document.getElementById("page-b")`, "page B");
    await sleep(200);
    assertEqual(p.consoleMessages, [], "console output");
  },

  async "dynamic segments: params, nesting, static precedence, 404"(p) {
    await p.goto("/users/42");
    await p.waitForText("user-id", "user=42");
    await p.click("to-edit");
    await p.waitForText("user-edit-id", "editing=42");
    await p.goto("/users/7/edit");
    await p.waitForText("user-edit-id", "editing=7");
    await p.goto("/users/new");
    await p.waitFor(`!!document.getElementById("new-user")`, "/users/new beats /users/:id");
    for (const path of ["/users", "/users/42/edit/more", "/nope"]) {
      await p.goto(path);
      await p.waitFor(`!!document.getElementById("not-found")`, `${path} renders the /error page`);
    }
  },

  async "a playground iframe runs the wasm its parent hands it, at /"(p) {
    await p.goto("/playground");
    await p.click("playground-run");
    // runPlaygroundWasm swaps in a fresh frame, so look it up each time.
    const frame = `document.getElementById("playground-frame").contentDocument`;
    await p.waitFor(`${frame}?.getElementById("count")?.textContent === "0"`, "the app to render in the frame");
    assertEqual(
      await p.evaluate(`document.getElementById("playground-frame").contentWindow.location.pathname`),
      "/",
      "the path the app sees in the frame",
    );
    await p.evaluate(`${frame}.getElementById("inc").click()`);
    await p.waitFor(`${frame}.getElementById("count").textContent === "1"`, "a click in the frame to update it");
  },

  async "a playground iframe reports wasm that does not load"(p) {
    await p.goto("/playground");
    const reply = await p.evaluate(`new Promise((resolve) => {
      const frame = document.getElementById("playground-frame");
      setTimeout(() => resolve("no answer in 5 s"), 5000);
      addEventListener("message", (e) => {
        if (e.source !== frame.contentWindow) return;
        if (e.data.type === "playground-ready") {
          frame.contentWindow.postMessage({ type: "load-wasm", bytes: new ArrayBuffer(8) }, "*");
        } else {
          resolve(e.data.type);
        }
      });
      // It said it was ready before this listener existed; ask again.
      frame.contentWindow.location.reload();
    })`);
    assertEqual(reply, "playground-error", "the frame's answer to bytes that are not wasm");
    assertEqual(p.allowErrors("Playground WASM error"), 1, "errors logged by the frame");
  },

  async "every declared binding is wired into the runtime"(p) {
    // The bindings app imports all of Vapor.Wasm and Vapor.Browser. One
    // missing import and the browser refuses to instantiate it (LinkError),
    // so it never becomes ready.
    p.requested.bindings.length = 0;
    await p.goto(p.bindingsOrigin + "/");
    const text = await p.text("count");
    if (!/^\d+ bindings$/.test(text ?? "") || parseInt(text) < 200) throw new Error(`unexpected: ${text}`);
    assertEqual(p.requested.bindings.includes("/browser.min.js"), true, "browser.min.js loaded for browser APIs");
  },

  async "apps that use no browser API never download browser.min.js"(p) {
    p.requested.app.length = 0;
    for (const path of ["/", "/list", "/input", "/fetch", "/storage", "/a"]) await p.goto(path);
    assertEqual(p.requested.app.includes("/browser.min.js"), false, "browser.min.js requested");
  },

  async "wasm memory stays flat across many route changes"(p) {
    await p.goto("/a");
    await p.waitFor(`!!document.getElementById("page-a")`, "page A");
    const onPage = (here, gone) =>
      `!!document.getElementById("page-${here}") && !document.getElementById("page-${gone}")`;
    let trips = 0;
    // Chrome ignores history.pushState beyond ~200 calls per 10 seconds, so
    // navigations are paced; no real user clicks links faster than this.
    const roundTrip = async () => {
      trips++;
      await p.click("to-b");
      await p.waitFor(onPage("b", "a"), `page B (round trip ${trips})`);
      await sleep(55);
      await p.click("to-a");
      await p.waitFor(onPage("a", "b"), `page A (round trip ${trips})`);
      await sleep(55);
    };
    for (let i = 0; i < 20; i++) await roundTrip(); // warm up arenas and caches
    const before = await p.wasmMemoryBytes();
    const rounds = 150;
    for (let i = 0; i < rounds; i++) await roundTrip();
    const after = await p.wasmMemoryBytes();
    const growth = after - before;
    console.log(`    memory: ${before} -> ${after} bytes over ${rounds * 2} navigations`);
    // Wasm memory only grows, in 64 KiB pages. A leak of even a few hundred
    // bytes per navigation shows up as several pages here.
    if (growth > 2 * 65536) throw new Error(`wasm memory grew by ${growth} bytes over ${rounds * 2} navigations`);
  },
};

// ── main ────────────────────────────────────────────────────────────────────

// Waits for the test server to have `n` crash reports, and gives them parsed.
async function crashReportsArrive(p, n) {
  for (let i = 0; i < 200 && p.crashReports.length < n; i++) await sleep(25);
  assertEqual(p.crashReports.length, n, "crash reports received");
  return p.crashReports.map((r) => ({ ...JSON.parse(r.body), contentType: r.contentType }));
}

if (staticMode && !existsSync(join(appDir, "release/index.html"))) {
  console.error("--static needs prerendered pages: run `zig build -Dgenerate=true` in tests/browser/app");
  process.exit(2);
}

// The app serves the runtime its own build installed. Run directly after
// editing js/, that copy is stale and the tests would exercise old code.
for (const dir of [appDir, bindingsDir]) {
  if (!existsSync(join(dir, "zig-out/bin/vapor.wasm"))) {
    console.error(`missing ${dir}/zig-out/bin/vapor.wasm; use \`zig build browser-test\``);
    process.exit(2);
  }
  const stale = ["bundle.min.js", "browser.min.js"].some((f) => {
    const served = join(dir, "zig-out/bin", f);
    return !existsSync(served) || !readFileSync(served).equals(readFileSync(resolve(dir, "../../../js/dist", f)));
  });
  if (stale) {
    console.error(`${dir} has a stale runtime; use \`zig build browser-test\`, or \`zig build\` in it first`);
    process.exit(2);
  }
}

const server = makeServer(appDir, requested.app, staticMode);
const bindingsServer = makeServer(bindingsDir, requested.bindings, false);
await new Promise((r) => bindingsServer.listen(0, "127.0.0.1", r));
const bindingsOrigin = `http://127.0.0.1:${bindingsServer.address().port}`;
await new Promise((r) => server.listen(flags.has("--serve") ? 8090 : 0, "127.0.0.1", r));
const origin = `http://127.0.0.1:${server.address().port}`;
if (flags.has("--serve")) {
  console.log(`serving ${appDir} at ${origin}`);
  await new Promise(() => {});
}
const cdp = await launch();
const page = makePage(cdp, origin);
page.bindingsOrigin = bindingsOrigin;
page.requested = requested;
page.crashReports = crashReports;
page.send = cdp.send;

const selected = Object.entries(tests).filter(([name]) => !only || name.toLowerCase().includes(only.toLowerCase()));
if (selected.length === 0) {
  console.error(`no test name contains "${only}"`);
  process.exit(2);
}

let failed = 0;
for (const [name, fn] of selected) {
  cdp.problems.length = 0;
  cdp.consoleMessages.length = 0;
  try {
    await fn(page);
    if (cdp.problems.length) throw new Error(cdp.problems.join("\n      "));
    console.log(`ok   ${name}`);
  } catch (err) {
    failed++;
    console.log(`FAIL ${name}\n      ${err.message}`);
    if (cdp.problems.length) console.log(`      page errors:\n      ${cdp.problems.join("\n      ")}`);
  }
}

cdp.close();
server.close();
bindingsServer.close();
console.log(`${failed ? `\n${failed} failed` : "\nall passed"}${staticMode ? " (static pages)" : ""}`);
process.exit(failed ? 1 : 0);
