import { rt } from "./runtime.js";

const canvasContexts = new Map();
let nextCanvasHandle = 1;

// ============================================================================
// CANVAS 2D
// ============================================================================

export const canvasBindings = {
  getCanvas2dContextWasm: (idPtr, idLen) => {
    const id = rt.readWasmString(idPtr, idLen);
    const canvas = document.getElementById(id);
    if (!canvas) return 0;

    const ctx = canvas.getContext("2d");
    if (!ctx) return 0;

    const handle = nextCanvasHandle++;
    canvasContexts.set(handle, ctx);
    return handle;
  },

  canvasSetFillStyleWasm: (handle, colorPtr, colorLen) => {
    const ctx = canvasContexts.get(handle);
    if (!ctx) return;
    ctx.fillStyle = rt.readWasmString(colorPtr, colorLen);
  },

  canvasSetStrokeStyleWasm: (handle, colorPtr, colorLen) => {
    const ctx = canvasContexts.get(handle);
    if (!ctx) return;
    ctx.strokeStyle = rt.readWasmString(colorPtr, colorLen);
  },

  canvasSetLineWidthWasm: (handle, width) => {
    const ctx = canvasContexts.get(handle);
    if (!ctx) return;
    ctx.lineWidth = width;
  },

  canvasSetLineCapWasm: (handle, cap) => {
    const ctx = canvasContexts.get(handle);
    if (!ctx) return;
    const caps = ["butt", "round", "square"];
    ctx.lineCap = caps[cap] || "butt";
  },

  canvasSetLineJoinWasm: (handle, join) => {
    const ctx = canvasContexts.get(handle);
    if (!ctx) return;
    const joins = ["miter", "round", "bevel"];
    ctx.lineJoin = joins[join] || "miter";
  },

  canvasFillRectWasm: (handle, x, y, w, h) => {
    const ctx = canvasContexts.get(handle);
    if (!ctx) return;
    ctx.fillRect(x, y, w, h);
  },

  canvasStrokeRectWasm: (handle, x, y, w, h) => {
    const ctx = canvasContexts.get(handle);
    if (!ctx) return;
    ctx.strokeRect(x, y, w, h);
  },

  canvasClearRectWasm: (handle, x, y, w, h) => {
    const ctx = canvasContexts.get(handle);
    if (!ctx) return;
    ctx.clearRect(x, y, w, h);
  },

  canvasBeginPathWasm: (handle) => {
    const ctx = canvasContexts.get(handle);
    if (!ctx) return;
    ctx.beginPath();
  },

  canvasClosePathWasm: (handle) => {
    const ctx = canvasContexts.get(handle);
    if (!ctx) return;
    ctx.closePath();
  },

  canvasMoveToWasm: (handle, x, y) => {
    const ctx = canvasContexts.get(handle);
    if (!ctx) return;
    ctx.moveTo(x, y);
  },

  canvasLineToWasm: (handle, x, y) => {
    const ctx = canvasContexts.get(handle);
    if (!ctx) return;
    ctx.lineTo(x, y);
  },

  canvasArcWasm: (
    handle,
    x,
    y,
    radius,
    startAngle,
    endAngle,
    counterclockwise,
  ) => {
    const ctx = canvasContexts.get(handle);
    if (!ctx) return;
    ctx.arc(x, y, radius, startAngle, endAngle, counterclockwise);
  },

  canvasArcToWasm: (handle, x1, y1, x2, y2, radius) => {
    const ctx = canvasContexts.get(handle);
    if (!ctx) return;
    ctx.arcTo(x1, y1, x2, y2, radius);
  },

  canvasBezierCurveToWasm: (handle, cp1x, cp1y, cp2x, cp2y, x, y) => {
    const ctx = canvasContexts.get(handle);
    if (!ctx) return;
    ctx.bezierCurveTo(cp1x, cp1y, cp2x, cp2y, x, y);
  },

  canvasQuadraticCurveToWasm: (handle, cpx, cpy, x, y) => {
    const ctx = canvasContexts.get(handle);
    if (!ctx) return;
    ctx.quadraticCurveTo(cpx, cpy, x, y);
  },

  canvasFillWasm: (handle) => {
    const ctx = canvasContexts.get(handle);
    if (!ctx) return;
    ctx.fill();
  },

  canvasStrokeWasm: (handle) => {
    const ctx = canvasContexts.get(handle);
    if (!ctx) return;
    ctx.stroke();
  },

  canvasClipWasm: (handle) => {
    const ctx = canvasContexts.get(handle);
    if (!ctx) return;
    ctx.clip();
  },

  canvasRectWasm: (handle, x, y, w, h) => {
    const ctx = canvasContexts.get(handle);
    if (!ctx) return;
    ctx.rect(x, y, w, h);
  },

  canvasEllipseWasm: (
    handle,
    x,
    y,
    radiusX,
    radiusY,
    rotation,
    startAngle,
    endAngle,
    counterclockwise,
  ) => {
    const ctx = canvasContexts.get(handle);
    if (!ctx) return;
    ctx.ellipse(
      x,
      y,
      radiusX,
      radiusY,
      rotation,
      startAngle,
      endAngle,
      counterclockwise,
    );
  },

  canvasFillTextWasm: (handle, textPtr, textLen, x, y, maxWidth) => {
    const ctx = canvasContexts.get(handle);
    if (!ctx) return;
    const text = rt.readWasmString(textPtr, textLen);
    if (maxWidth > 0) {
      ctx.fillText(text, x, y, maxWidth);
    } else {
      ctx.fillText(text, x, y);
    }
  },

  canvasStrokeTextWasm: (handle, textPtr, textLen, x, y, maxWidth) => {
    const ctx = canvasContexts.get(handle);
    if (!ctx) return;
    const text = rt.readWasmString(textPtr, textLen);
    if (maxWidth > 0) {
      ctx.strokeText(text, x, y, maxWidth);
    } else {
      ctx.strokeText(text, x, y);
    }
  },

  canvasSetFontWasm: (handle, fontPtr, fontLen) => {
    const ctx = canvasContexts.get(handle);
    if (!ctx) return;
    ctx.font = rt.readWasmString(fontPtr, fontLen);
  },

  canvasSetTextAlignWasm: (handle, align) => {
    const ctx = canvasContexts.get(handle);
    if (!ctx) return;
    const aligns = ["start", "end", "left", "right", "center"];
    ctx.textAlign = aligns[align] || "start";
  },

  canvasSetTextBaselineWasm: (handle, baseline) => {
    const ctx = canvasContexts.get(handle);
    if (!ctx) return;
    const baselines = [
      "alphabetic",
      "top",
      "hanging",
      "middle",
      "ideographic",
      "bottom",
    ];
    ctx.textBaseline = baselines[baseline] || "alphabetic";
  },

  canvasMeasureTextWasm: (handle, textPtr, textLen) => {
    const ctx = canvasContexts.get(handle);
    if (!ctx) return 0;
    const text = rt.readWasmString(textPtr, textLen);
    return ctx.measureText(text).width;
  },

  canvasDrawImageWasm: (handle, imgIdPtr, imgIdLen, dx, dy) => {
    const ctx = canvasContexts.get(handle);
    if (!ctx) return;
    const imgId = rt.readWasmString(imgIdPtr, imgIdLen);
    const img = document.getElementById(imgId);
    if (img) {
      ctx.drawImage(img, dx, dy);
    }
  },

  canvasDrawImageScaledWasm: (handle, imgIdPtr, imgIdLen, dx, dy, dw, dh) => {
    const ctx = canvasContexts.get(handle);
    if (!ctx) return;
    const imgId = rt.readWasmString(imgIdPtr, imgIdLen);
    const img = document.getElementById(imgId);
    if (img) {
      ctx.drawImage(img, dx, dy, dw, dh);
    }
  },

  canvasDrawImageSlicedWasm: (
    handle,
    imgIdPtr,
    imgIdLen,
    sx,
    sy,
    sw,
    sh,
    dx,
    dy,
    dw,
    dh,
  ) => {
    const ctx = canvasContexts.get(handle);
    if (!ctx) return;
    const imgId = rt.readWasmString(imgIdPtr, imgIdLen);
    const img = document.getElementById(imgId);
    if (img) {
      ctx.drawImage(img, sx, sy, sw, sh, dx, dy, dw, dh);
    }
  },

  canvasSaveWasm: (handle) => {
    const ctx = canvasContexts.get(handle);
    if (!ctx) return;
    ctx.save();
  },

  canvasRestoreWasm: (handle) => {
    const ctx = canvasContexts.get(handle);
    if (!ctx) return;
    ctx.restore();
  },

  canvasTranslateWasm: (handle, x, y) => {
    const ctx = canvasContexts.get(handle);
    if (!ctx) return;
    ctx.translate(x, y);
  },

  canvasRotateWasm: (handle, angle) => {
    const ctx = canvasContexts.get(handle);
    if (!ctx) return;
    ctx.rotate(angle);
  },

  canvasScaleWasm: (handle, x, y) => {
    const ctx = canvasContexts.get(handle);
    if (!ctx) return;
    ctx.scale(x, y);
  },

  canvasSetTransformWasm: (handle, a, b, c, d, e, f) => {
    const ctx = canvasContexts.get(handle);
    if (!ctx) return;
    ctx.setTransform(a, b, c, d, e, f);
  },

  canvasResetTransformWasm: (handle) => {
    const ctx = canvasContexts.get(handle);
    if (!ctx) return;
    ctx.resetTransform();
  },

  canvasSetGlobalAlphaWasm: (handle, alpha) => {
    const ctx = canvasContexts.get(handle);
    if (!ctx) return;
    ctx.globalAlpha = alpha;
  },

  canvasSetGlobalCompositeOperationWasm: (handle, op) => {
    const ctx = canvasContexts.get(handle);
    if (!ctx) return;
    const ops = [
      "source-over",
      "source-in",
      "source-out",
      "source-atop",
      "destination-over",
      "destination-in",
      "destination-out",
      "destination-atop",
      "lighter",
      "copy",
      "xor",
      "multiply",
      "screen",
      "overlay",
      "darken",
      "lighten",
      "color-dodge",
      "color-burn",
      "hard-light",
      "soft-light",
      "difference",
      "exclusion",
      "hue",
      "saturation",
      "color",
      "luminosity",
    ];
    ctx.globalCompositeOperation = ops[op] || "source-over";
  },

  canvasToDataUrlWasm: (idPtr, idLen, typePtr, typeLen, quality) => {
    const id = rt.readWasmString(idPtr, idLen);
    const type = rt.readWasmString(typePtr, typeLen);
    const canvas = document.getElementById(id);
    if (!canvas) return rt.allocString("");
    return rt.allocString(canvas.toDataURL(type || "image/png", quality));
  },

  canvasGetImageDataWasm: (handle, x, y, w, h) => {
    const ctx = canvasContexts.get(handle);
    if (!ctx) return 0;

    const imageData = ctx.getImageData(x, y, w, h);
    const ptr = rt.wasmInstance.allocate(imageData.data.length);
    new Uint8Array(rt.wasmInstance.memory.buffer, ptr, imageData.data.length).set(
      imageData.data,
    );
    return ptr;
  },

  canvasPutImageDataWasm: (handle, dataPtr, dataLen, x, y, w, h) => {
    const ctx = canvasContexts.get(handle);
    if (!ctx) return;

    const data = new Uint8ClampedArray(
      rt.wasmInstance.memory.buffer,
      dataPtr,
      dataLen,
    );
    const imageData = new ImageData(data, w, h);
    ctx.putImageData(imageData, x, y);
  },

  canvasSetShadowWasm: (handle, colorPtr, colorLen, blur, offsetX, offsetY) => {
    const ctx = canvasContexts.get(handle);
    if (!ctx) return;
    ctx.shadowColor = rt.readWasmString(colorPtr, colorLen);
    ctx.shadowBlur = blur;
    ctx.shadowOffsetX = offsetX;
    ctx.shadowOffsetY = offsetY;
  },

  destroyCanvasContextWasm: (handle) => {
    canvasContexts.delete(handle);
  },
};
