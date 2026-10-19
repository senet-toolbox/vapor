// Render-loop flags shared across the runtime modules.
export const state = {
  initial_render: true,
  // A flag to ensure we don't schedule more than one render per frame.
  isRenderScheduled: false,
  currentDepthNode: "",
  // The path the DOM shows, and whether the render in progress changes it.
  // Ids are positional, so another page reuses elements at the same spots;
  // their style changes must not animate.
  renderedPath: null,
  routeChanged: false,
};

/** Call before walking a render's nodes into the DOM. */
export function beginTraversal(path) {
  state.routeChanged = state.renderedPath !== path;
  state.renderedPath = path;
}
