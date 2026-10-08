import { rt } from "./runtime.js";

const audioElements = new Map();
let nextAudioHandle = 1;

// ============================================================================
// AUDIO
// ============================================================================

export const audioBindings = {
  createAudioElementWasm: (srcPtr, srcLen) => {
    const src = rt.readWasmString(srcPtr, srcLen);
    const audio = new Audio(src);
    const handle = nextAudioHandle++;
    audioElements.set(handle, audio);
    return handle;
  },

  audioPlayWasm: (handle) => {
    const audio = audioElements.get(handle);
    if (audio) audio.play();
  },

  audioPauseWasm: (handle) => {
    const audio = audioElements.get(handle);
    if (audio) audio.pause();
  },

  audioStopWasm: (handle) => {
    const audio = audioElements.get(handle);
    if (audio) {
      audio.pause();
      audio.currentTime = 0;
    }
  },

  audioSetVolumeWasm: (handle, volume) => {
    const audio = audioElements.get(handle);
    if (audio) audio.volume = Math.max(0, Math.min(1, volume));
  },

  audioGetVolumeWasm: (handle) => {
    const audio = audioElements.get(handle);
    return audio ? audio.volume : 0;
  },

  audioSetMutedWasm: (handle, muted) => {
    const audio = audioElements.get(handle);
    if (audio) audio.muted = muted;
  },

  audioGetMutedWasm: (handle) => {
    const audio = audioElements.get(handle);
    return audio?.muted ? 1 : 0;
  },

  audioSetLoopWasm: (handle, loop) => {
    const audio = audioElements.get(handle);
    if (audio) audio.loop = loop;
  },

  audioSetCurrentTimeWasm: (handle, time) => {
    const audio = audioElements.get(handle);
    if (audio) audio.currentTime = time;
  },

  audioGetCurrentTimeWasm: (handle) => {
    const audio = audioElements.get(handle);
    return audio ? audio.currentTime : 0;
  },

  audioGetDurationWasm: (handle) => {
    const audio = audioElements.get(handle);
    return audio ? audio.duration : 0;
  },

  audioGetReadyStateWasm: (handle) => {
    const audio = audioElements.get(handle);
    return audio ? audio.readyState : 0;
  },

  audioSetPlaybackRateWasm: (handle, rate) => {
    const audio = audioElements.get(handle);
    if (audio) audio.playbackRate = rate;
  },

  audioOnEndedWasm: (handle, callbackId) => {
    const audio = audioElements.get(handle);
    if (audio) {
      audio.onended = () => rt.wasmInstance.callbackCtx(callbackId, 0);
    }
  },

  audioOnErrorWasm: (handle, callbackId) => {
    const audio = audioElements.get(handle);
    if (audio) {
      audio.onerror = () => rt.wasmInstance.callbackCtx(callbackId, 0);
    }
  },

  audioOnCanPlayWasm: (handle, callbackId) => {
    const audio = audioElements.get(handle);
    if (audio) {
      audio.oncanplay = () => rt.wasmInstance.callbackCtx(callbackId, 0);
    }
  },

  destroyAudioElementWasm: (handle) => {
    const audio = audioElements.get(handle);
    if (audio) {
      audio.pause();
      audio.src = "";
      audioElements.delete(handle);
    }
  },
};
