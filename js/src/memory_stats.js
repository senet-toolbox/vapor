/** Debug helpers that watch wasm memory growth. */
import { debug } from "./debug.js";
import { wasmInstance } from "./wasi_obj.js";

function getWasmMemoryUsage() {
  const memory = wasmInstance.memory;
  return memory.buffer.byteLength;
}

// Monitor memory growth
let lastMemorySize = 0;

export function checkMemoryGrowth() {
  const currentSize = getWasmMemoryUsage();
  const pages = currentSize / (64 * 1024); // WASM pages are 64KB

  debug(`Total memory: ${currentSize / 1024 / 1024} MB (${pages} pages)`);

  if (currentSize > lastMemorySize) {
    debug(`Memory grew by ${(currentSize - lastMemorySize) / 1024} KB`);
  }
  lastMemorySize = currentSize;
  return pages;
}

// Get more detailed info if your WASM exports these functions
function getDetailedMemoryInfo() {
  if (wasmInstance.get_stack_pointer) {
    const stackPtr = wasmInstance.get_stack_pointer();
    debug(`Stack pointer: 0x${stackPtr.toString(16)}`);
  }

  if (wasmInstance.get_heap_size) {
    const heapSize = wasmInstance.get_heap_size();
    debug(`Heap usage: ${heapSize / 1024} KB`);
  }
}
