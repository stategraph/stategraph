/**
 * Shared by the root layout's boot watchdog (an inline script, which gets these
 * interpolated) and the root error boundary. Both retry a failed chunk load
 * once through a cache-busting URL, so they must agree on the marker, the loop
 * guard, and what counts as a chunk failure.
 */

/** Query parameter carrying the cache-busting retry. */
export const RELOAD_MARK = "_sgreload";

/** sessionStorage key holding the time of the last automatic retry. */
export const RELOAD_GUARD_KEY = "sg-chunk-reload";

/** No second automatic retry within this window of the last one. */
export const RELOAD_GUARD_MS = 30_000;

/** Messages of a chunk that failed to load. */
export const CHUNK_ERROR = /ChunkLoadError|Loading chunk|dynamically imported module/;
