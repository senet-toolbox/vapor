/** Video and camera playback. */
import { readWasmString } from "../wasi_obj.js";

export const mediaBindings = {
  // Video / Media
  startVideoWasm: (idPtr, idLen) => {
    const id = readWasmString(idPtr, idLen);
    const video = document.getElementById(id);
    if (video === null) return;

    async function startCamera() {
      try {
        const stream = await navigator.mediaDevices.getUserMedia({
          video: true,
          audio: false,
        });
        video.srcObject = stream;
      } catch (error) {
        console.error("Camera access denied:", error);
      }
    }

    startCamera();
  },
  playVideoWasm: (idPtr, idLen) => {
    const id = readWasmString(idPtr, idLen);
    const video = document.getElementById(id);
    video.play();
  },
  pauseVideoWasm: (idPtr, idLen) => {
    const id = readWasmString(idPtr, idLen);
    const video = document.getElementById(id);
    video.pause();
  },
  stopCameraWasm: (idPtr, idLen) => {
    const id = readWasmString(idPtr, idLen);
    const video = document.getElementById(id);

    if (video.srcObject) {
      const tracks = video.srcObject.getTracks();
      tracks.forEach((track) => track.stop());
      video.srcObject = null;
    }
  },
  seekVideoWasm: (idPtr, idLen, seconds) => {
    const id = readWasmString(idPtr, idLen);
    const video = document.getElementById(id);
    video.currentTime = seconds;
  },
  setVolumeWasm: (idPtr, idLen, volume) => {
    const id = readWasmString(idPtr, idLen);
    const video = document.getElementById(id);
    video.volume = volume;
  },
  muteVideoWasm: (idPtr, idLen, mute) => {
    const id = readWasmString(idPtr, idLen);
    const video = document.getElementById(id);
    video.muted = !!mute;
  },
  getVideoDurationWasm: (idPtr, idLen) => {
    const id = readWasmString(idPtr, idLen);
    const video = document.getElementById(id);
    return video.duration;
  },
  getVideoCurrentTimeWasm: (idPtr, idLen) => {
    const id = readWasmString(idPtr, idLen);
    const video = document.getElementById(id);
    return video.currentTime;
  },
};
