// Render-loop flags shared across the runtime modules.
export const state = {
  initial_render: true,
  // A flag to ensure we don't schedule more than one render per frame.
  isRenderScheduled: false,
  currentDepthNode: "",
};
