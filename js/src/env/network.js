/** fetch and the core websocket bindings. */
import { wasmInstance } from "../instance.js";
import { sockets } from "../maps.js";
import { allocStringFrame, readWasmString } from "../wasi_obj.js";

export const networkBindings = {
  // Network / Fetch
  createWss: (port, onid, query_ptr, query_len) => {
    const query = readWasmString(query_ptr, query_len);
    const id = onid >>> 0;
    const url = `ws://localhost:${port}${query}`;
    const socket = new WebSocket(url);
    socket.onopen = function(event) {
      wasmInstance.onWssConnection(id);
    };
    socket.onmessage = function(event) {
      const ptr = allocStringFrame(event.data);
      wasmInstance.onWssMessage(id, ptr);
    };
    socket.onclose = function(event) {
      wasmInstance.onWssClose(id);
    };
    sockets.set(id, socket);
  },
  sendWss: (onid, dataPtr, dataLen) => {
    const id = onid >>> 0;
    const data = readWasmString(dataPtr, dataLen);
    const socket = sockets.get(id);

    if (!socket) {
      console.error("Socket not found for id:", id);
      return;
    }

    if (socket.readyState !== WebSocket.OPEN) {
      console.error("Socket not open, state:", socket.readyState);
      return;
    }

    socket.send(data);
  },
  fetchWasm: async (urlPtr, urlLen, callback_id, httpPtr, httpLen) => {
    const url = readWasmString(urlPtr, urlLen);
    const data = readWasmString(httpPtr, httpLen);
    const Request = JSON.parse(data);

    if (Request.body && typeof Request.body === "object") {
      Request.body = JSON.stringify(Request.body);
    }

    const startTime = performance.now();

    fetch(url, Request)
      .then(async (res) => {
        const elapsed = Math.round(performance.now() - startTime);

        const headers = {};
        res.headers.forEach((value, key) => {
          headers[key] = value;
        });

        const body = await res.text();

        // Wire format: flat object matching ParsedResponseWire in Zig.
        // - `ok: bool` is the variant discriminant (no outer Ok/Err wrapper)
        // - `status` (not `code`)
        // - For HTTP errors (4xx/5xx), ok=false and error_kind="http"
        const wire = {
          ok: res.ok,
          status: res.status,
          message: res.statusText,
          body: body,
          url: res.url,
          redirected: res.redirected,
          content_type: res.headers.get("content-type") || "",
          content_length: body.length,
          elapsed_ms: elapsed,
          headers: headers,
        };

        if (!res.ok) {
          wire.error_kind = "http";
          wire.error_name = "HttpError";
        }

        const respString = JSON.stringify(wire);
        const ptr = allocStringFrame(respString);
        wasmInstance.resumecallback(callback_id, ptr);
      })
      .catch((err) => {
        const elapsed = Math.round(performance.now() - startTime);

        // Categorize into one of the values Zig's parseErrorKind recognizes:
        //   "network" | "timeout" | "abort" | "parse" | "http"
        // Anything else lands in Zig's `.unknown` bucket. We keep the JS-side
        // detail (cors, dns, tls, etc.) in error_name for diagnostics.
        let error_kind = "unknown";
        let error_name = err.name || "Error";

        const msg = (err.message || "").toLowerCase();

        if (err.name === "AbortError" || msg.includes("abort")) {
          error_kind = "abort";
        } else if (msg.includes("timeout")) {
          error_kind = "timeout";
        } else if (
          err.name === "TypeError" &&
          (msg.includes("failed to fetch") ||
            msg.includes("networkerror") ||
            msg.includes("network request failed"))
        ) {
          // Browsers conflate CORS, DNS, and TLS into a generic "TypeError: Failed to fetch".
          // We bucket all of these as "network" for the Zig enum, but preserve detail in
          // error_name so users can disambiguate when debugging.
          error_kind = "network";
          if (msg.includes("cors")) error_name = "CorsError";
          else if (msg.includes("dns") || msg.includes("not found"))
            error_name = "DnsError";
          else if (
            msg.includes("ssl") ||
            msg.includes("cert") ||
            msg.includes("tls")
          )
            error_name = "TlsError";
        } else if (msg.includes("cors")) {
          error_kind = "network";
          error_name = "CorsError";
        } else if (msg.includes("dns") || msg.includes("not found")) {
          error_kind = "network";
          error_name = "DnsError";
        } else if (msg.includes("ssl") || msg.includes("cert")) {
          error_kind = "network";
          error_name = "TlsError";
        }

        const wire = {
          ok: false,
          status: 0,
          message: err.message || String(err),
          body: "",
          url: url,
          redirected: false,
          content_type: "",
          content_length: 0,
          elapsed_ms: elapsed,
          headers: null,
          error_kind: error_kind,
          error_name: error_name,
        };

        const respString = JSON.stringify(wire);
        const ptr = allocStringFrame(respString);
        wasmInstance.resumecallback(callback_id, ptr);
      });
  },
};
