/** Readers and writers for structs shared between wasm memory and JS. */
import { wasmInstance } from "./instance.js";
import { allocStringFrame, readWasmString } from "./wasi_obj.js";

// ============================================================================
// Utility Classes
// ============================================================================

/**
 * Performance monitoring for FPS and frame time tracking
 */
export class PerformanceMonitor {
  constructor() {
    this.fps = 0;
    this.frameTime = 0;
    this.frameTimes = [];
    this.maxSamples = 60;
    this.lastFrameTime = performance.now();
    this.startMonitoring();
  }

  startMonitoring() {
    const measure = (currentTime) => {
      const delta = currentTime - this.lastFrameTime;
      this.lastFrameTime = currentTime;

      this.frameTimes.push(delta);
      if (this.frameTimes.length > this.maxSamples) {
        this.frameTimes.shift();
      }

      const avgFrameTime =
        this.frameTimes.reduce((a, b) => a + b, 0) / this.frameTimes.length;
      this.fps = Math.round(1000 / avgFrameTime);
      this.frameTime = Math.round(avgFrameTime * 100) / 100;

      const fpsElement = document.getElementById("fps");
      const frameTimeElement = document.getElementById("frameTime");

      if (fpsElement) fpsElement.textContent = this.fps;
      if (frameTimeElement) frameTimeElement.textContent = this.frameTime;

      requestAnimationFrame(measure);
    };

    requestAnimationFrame(measure);
  }
}

/**
 * Bridge for reading WASM struct schemas
 */
export class WasmStructBridge {
  constructor(wasmInstance) {
    this.wasm = wasmInstance;
    this.schemas = new Map();
  }

  registerSchema(name, getSchemaFn, getSchemaLengthFn) {
    const length = this.wasm[getSchemaLengthFn]();
    const schemaPtr = this.wasm[getSchemaFn]();

    const fields = [];
    const memory = new DataView(this.wasm.memory.buffer);
    const FIELD_DESCRIPTOR_SIZE = 16;

    for (let i = 0; i < length; i++) {
      const offset = schemaPtr + i * FIELD_DESCRIPTOR_SIZE;

      const fieldType = memory.getUint8(offset);
      const fieldOffset = memory.getUint32(offset + 1, true);
      const namePtr = memory.getUint32(offset + 5, true);
      const nameLen = memory.getUint32(offset + 9, true);

      const fieldName = readWasmString(namePtr, nameLen);

      fields.push({
        name: fieldName,
        type: fieldType,
        offset: fieldOffset,
      });
    }

    this.schemas.set(name, fields);
  }

  readField(memory, ptr, fieldType) {
    const FieldType = {
      u8_type: 0,
      i8_type: 1,
      u16_type: 2,
      i16_type: 3,
      u32_type: 4,
      i32_type: 5,
      u64_type: 6,
      i64_type: 7,
      f32_type: 8,
      f64_type: 9,
      bool_type: 10,
      string_type: 11,
    };

    switch (fieldType) {
      case FieldType.u8_type:
        return memory.getUint8(ptr);
      case FieldType.i8_type:
        return memory.getInt8(ptr);
      case FieldType.u16_type:
        return memory.getUint16(ptr, true);
      case FieldType.i16_type:
        return memory.getInt16(ptr, true);
      case FieldType.u32_type:
        return memory.getUint32(ptr, true);
      case FieldType.i32_type:
        return memory.getInt32(ptr, true);
      case FieldType.u64_type:
        return memory.getBigUint64(ptr, true);
      case FieldType.i64_type:
        return memory.getBigInt64(ptr, true);
      case FieldType.f32_type:
        return memory.getFloat32(ptr, true);
      case FieldType.f64_type:
        return memory.getFloat64(ptr, true);
      case FieldType.bool_type:
        return memory.getUint8(ptr) !== 0;
      case FieldType.string_type:
        const strPtr = memory.getUint32(ptr, true);
        const strLen = memory.getUint32(ptr + 4, true);
        return readWasmString(strPtr, strLen);
      default:
        throw new Error(`Unknown field type: ${fieldType}`);
    }
  }
}

/**
 * Dynamic struct reader using field descriptors
 */
export class DynamicStructReader {
  constructor(wasmInstance, memory) {
    this.wasm = wasmInstance;
    this.memory = memory;
    this.decoder = new TextDecoder();
  }

  readStruct(node_ptr, structPtr, fieldCount, getFieldDescriptor) {
    const result = {};

    for (let i = 0; i < fieldCount; i++) {
      let descPtr;
      if (node_ptr === null) {
        descPtr = this.wasm[getFieldDescriptor](i);
      } else {
        descPtr = this.wasm[getFieldDescriptor](node_ptr, i);
      }
      const descriptor = this.readDescriptor(descPtr);
      const fieldName = readWasmString(descriptor.namePtr, descriptor.nameLen);
      let fieldValue;

      if (descriptor.typeId === 7) {
        // Pointer - check for slice pattern
        const view = new DataView(this.memory.buffer, structPtr);
        const ptr = view.getUint32(descriptor.offset, true);

        if (i + 1 < fieldCount) {
          const nextDescPtr = this.wasm[getFieldDescriptor](node_ptr, i + 1);
          const nextDescriptor = this.readDescriptor(nextDescPtr);
          const len = this.readField(
            structPtr + nextDescriptor.offset,
            nextDescriptor.typeId,
            nextDescriptor.size,
            nextDescriptor.canBeNull,
          );
          if (len === 0) {
            fieldValue = "";
          } else {
            fieldValue = readWasmString(ptr, len);
          }
          i++;
        } else {
          fieldValue = ptr;
        }
      } else {
        fieldValue = this.readField(
          structPtr + descriptor.offset,
          descriptor.typeId,
          descriptor.size,
          descriptor.canBeNull,
        );
        if (descriptor.typeId === 3 && fieldValue !== null) {
          const num = fieldValue;
          fieldValue = Number(num.toFixed(2));
        }
      }
      result[fieldName.replace("_ptr", "")] = fieldValue;
    }
    return result;
  }

  readDescriptor(ptr) {
    const view = new DataView(this.memory.buffer, ptr);
    return {
      namePtr: view.getUint32(0, true),
      nameLen: view.getUint32(4, true),
      offset: view.getUint32(8, true),
      typeId: view.getUint8(12),
      size: view.getUint32(16, true),
      canBeNull: view.getUint32(20, true),
    };
  }

  readField(ptr, typeId, size, canBeNull) {
    const view = new DataView(this.memory.buffer, ptr);

    if (canBeNull) {
      const isNull = view.getUint32(0, true);
      if (isNull === 0) return null;
    }

    switch (typeId) {
      case 1: // unsigned int
        return size === 1
          ? view.getUint8(0)
          : size === 2
            ? view.getUint16(0, true)
            : size === 4
              ? view.getUint32(0, true)
              : view.getBigUint64(0, true);
      case 2: // signed int
        return size === 1
          ? view.getInt8(0)
          : size === 2
            ? view.getInt16(0, true)
            : size === 4
              ? view.getInt32(0, true)
              : size === 8
                ? view.getInt32(0, true)
                : view.getBigInt64(0, true);
      case 3: // float
        return size === 4 ? view.getFloat32(0, true) : view.getFloat64(0, true);
      case 4: // bool
        return Boolean(view.getUint8(0));
      case 5: // string (fixed-size u8 array)
        return readWasmString(ptr, size);
      case 7: // pointer
        return;
      case 8: // enum
        return view.getUint8(0, true);
      default:
        return null;
    }
  }
}

/**
 * Builds JS objects to pass to WASM
 */
export class WasmObjectBuilder {
  constructor(wasmInstance, memory) {
    this.wasm = wasmInstance;
    this.memory = memory;
  }

  passObject(obj) {
    const handle = this.wasm.startObject();

    for (const [key, value] of Object.entries(obj)) {
      const keyPtr = allocStringFrame(key);

      switch (typeof value) {
        case "string":
          const strPtr = allocStringFrame(value);
          this.wasm.addStringField(handle, keyPtr, strPtr);
          break;
        case "number":
          if (Number.isInteger(value)) {
            this.wasm.addIntField(handle, keyPtr, value);
          } else {
            this.wasm.addFloatField(handle, keyPtr, value);
          }
          break;
        case "boolean":
          this.wasm.addBoolField(handle, keyPtr, value ? 1 : 0);
          break;
      }
    }

    return handle;
  }
}
