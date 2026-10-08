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

function serve(req, res) {
  const url = new URL(req.url, "http://x");
  let path = decodeURIComponent(url.pathname);
  if (staticMode) {
    // A static host: release/ is the site root, plus the wasm the runtime
    // fetches from /zig-out/bin/.
    if (!extname(path)) path = path.replace(/\/$/, "") + "/index.html";
    // Anything not in release/ (the wasm, the /api fixtures) is what the
    // backend would serve.
    if (existsSync(join(appDir, "release", path))) path = "/release" + path;
  } else if (path === "/bundle.min.js") path = "/zig-out/bin/bundle.min.js";
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
  const port = 9200 + Math.floor(Math.random() * 700);
  const proc = spawn(findChrome(), [
    "--headless=new",
    "--disable-gpu",
    "--no-first-run",
    "--no-default-browser-check",
    "--no-sandbox", // CI containers run as root
    `--remote-debugging-port=${port}`,
    `--user-data-dir=${profile}`,
    "about:blank",
  ], { stdio: "ignore" });

  let targets;
  for (let i = 0; i < 100 && !targets; i++) {
    try {
      targets = await (await fetch(`http://127.0.0.1:${port}/json`)).json();
    } catch {
      await sleep(100);
    }
  }
  if (!targets) throw new Error("Chrome did not start");
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
      await cdp.send("Page.navigate", { url: origin + path });
      await waitFor(`document.readyState === "complete"`, "page load");
      // Prerendered HTML is visible before it is live; wait for hydration.
      await waitFor(`document.documentElement.hasAttribute("data-vapor-ready")`, "vapor:ready");
    },
    async waitForText(id, expected) {
      await waitFor(
        `document.getElementById(${JSON.stringify(id)})?.textContent === ${JSON.stringify(expected)}`,
        `#${id} to read ${JSON.stringify(expected)} (is ${JSON.stringify(await text(id))})`,
      );
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

function assertEqual(actual, expected, what) {
  const a = JSON.stringify(actual);
  const e = JSON.stringify(expected);
  if (a !== e) throw new Error(`${what}: expected ${e}, got ${a}`);
}

// ── tests ───────────────────────────────────────────────────────────────────

const tests = {
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

  async "typing reaches Zig state"(p) {
    await p.goto("/input");
    await p.waitForText("greeting", "Hello, !");
    await p.type("name", "Ziggy");
    await p.waitForText("greeting", "Hello, Ziggy!");
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

if (staticMode && !existsSync(join(appDir, "release/index.html"))) {
  console.error("--static needs prerendered pages: run `zig build -Dgenerate=true` in tests/browser/app");
  process.exit(2);
}
if (!existsSync(join(appDir, "zig-out/bin/vapor.wasm"))) {
  console.error(`missing ${appDir}/zig-out/bin/vapor.wasm; run \`zig build\` in tests/browser/app first`);
  process.exit(2);
}

// The app serves the runtime its own build installed. Run directly after
// editing js/, that copy is stale and the tests would exercise old code.
const served = readFileSync(join(appDir, "zig-out/bin/bundle.min.js"));
const current = readFileSync(resolve(appDir, "../../../js/dist/bundle.min.js"));
if (!served.equals(current)) {
  console.error("tests/browser/app has a stale bundle.min.js; use `zig build browser-test`, or `zig build` in the app first");
  process.exit(2);
}

const server = createServer(serve);
await new Promise((r) => server.listen(flags.has("--serve") ? 8090 : 0, "127.0.0.1", r));
const origin = `http://127.0.0.1:${server.address().port}`;
if (flags.has("--serve")) {
  console.log(`serving ${appDir} at ${origin}`);
  await new Promise(() => {});
}
const cdp = await launch();
const page = makePage(cdp, origin);

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
console.log(`${failed ? `\n${failed} failed` : "\nall passed"}${staticMode ? " (static pages)" : ""}`);
process.exit(failed ? 1 : 0);
