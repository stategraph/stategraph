"use client";

import { adoptDocumentNonce } from "@/lib/boot/cspNonce";

// Runs when this module loads, before hydration, so the nonce is in place
// before any overlay mounts.
if (typeof document !== "undefined") adoptDocumentNonce(document);

/** Rendered once in the root layout so that this module loads on every page. */
export function CspNonceBoot() {
  return null;
}
