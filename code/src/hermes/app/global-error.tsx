"use client";

import { useEffect } from "react";
import { CHUNK_ERROR, RELOAD_GUARD_KEY, RELOAD_GUARD_MS, RELOAD_MARK } from "@/lib/boot/chunkReload";

/**
 * Root error boundary. A failed chunk load (the demo proxy shedding a request)
 * is transient: reload once automatically; anything else, or a repeat within
 * 30 seconds, shows a manual reload prompt instead of a blank page.
 */
export default function GlobalError({ error }: { error: Error & { digest?: string } }) {
  useEffect(() => {
    const transient = CHUNK_ERROR.test(`${error.name} ${error.message}`);
    // Retry through a cache-busting URL, once: a plain reload would re-serve
    // the same stale HTML that caused the failure (see the boot watchdog in
    // the root layout). If the marker is already present the retry itself
    // failed, so leave the message up rather than loop.
    if (!transient || new URLSearchParams(window.location.search).has(RELOAD_MARK)) return;
    // The root layout strips the marker once a retry boots, so a later failure
    // would bust again; the time window shared with that watchdog stops it.
    try {
      const last = Number(sessionStorage.getItem(RELOAD_GUARD_KEY) || 0);
      if (Date.now() - last < RELOAD_GUARD_MS) return;
      sessionStorage.setItem(RELOAD_GUARD_KEY, String(Date.now()));
    } catch {
      // Storage unavailable: no loop guard, so leave the manual prompt up.
      return;
    }
    const url = new URL(window.location.href);
    url.searchParams.set(RELOAD_MARK, String(Date.now()));
    window.location.replace(url.toString());
  }, [error]);

  return (
    <html lang="en">
      <body style={{ fontFamily: "system-ui, sans-serif", background: "#0d1117", color: "#c9d1d9" }}>
        <div style={{ display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", minHeight: "100vh", gap: 12 }}>
          <div style={{ fontSize: 15 }}>Something went wrong while loading the console.</div>
          <button
            onClick={() => window.location.reload()}
            style={{ padding: "6px 14px", borderRadius: 6, border: "1px solid #30363d", background: "#161b22", color: "#c9d1d9", cursor: "pointer" }}
          >
            Reload
          </button>
        </div>
      </body>
    </html>
  );
}
