"use client";

import { Info } from "lucide-react";
import { useId, type ReactNode } from "react";

/**
 * A small ⓘ affordance that reveals explanatory copy on hover or keyboard focus.
 * Progressive disclosure: keep the surface tight, keep the depth one interaction away.
 * CSS-only (no state, no portal) so it is static-export safe. Best for short captions
 * placed near the left/centre of a line; the bubble opens below and centred.
 */
export function InfoTip({ children, label = "More information", width = "w-72" }: { children: ReactNode; label?: string; width?: string }) {
  const tipId = useId();
  return (
    <span className="relative inline-flex group align-middle">
      <button
        type="button"
        aria-label={label}
        aria-describedby={tipId}
        // iOS Safari doesn't focus buttons on tap, so without this the bubble
        // is unreachable on touch; focusing keeps the reveal purely
        // focus-within-driven (tap elsewhere blurs and closes).
        onClick={(e) => e.currentTarget.focus()}
        className="inline-flex text-[var(--sg-text-muted)] hover:text-[var(--sg-text)] focus:outline-none focus-visible:ring-1 focus-visible:ring-[var(--sg-accent)] rounded-full"
      >
        <Info className="w-3.5 h-3.5" />
      </button>
      <span
        id={tipId}
        role="tooltip"
        className={`pointer-events-none absolute left-1/2 top-full z-30 mt-1.5 ${width} -translate-x-1/2 rounded-md border border-[var(--sg-border)] bg-[var(--sg-bg-2)] px-3 py-2 text-xs leading-relaxed text-[var(--sg-text-muted)] shadow-lg opacity-0 transition-opacity duration-100 group-hover:opacity-100 group-focus-within:opacity-100`}
      >
        {children}
      </span>
    </span>
  );
}
