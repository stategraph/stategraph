"use client";

import { useEffect, useState } from "react";

/**
 * Subscribe to a CSS media query and return whether it currently matches.
 *
 * Evaluated synchronously in the `useState` initializer so the first client
 * render already has the correct value (no false→true flash). On the server
 * (`window` undefined) it returns `false`, i.e. the desktop layout, which is
 * the safe default for these client-rendered console pages.
 */
export function useMediaQuery(query: string): boolean {
  const [matches, setMatches] = useState(() =>
    typeof window === "undefined" ? false : window.matchMedia(query).matches
  );

  useEffect(() => {
    const mql = window.matchMedia(query);
    const update = () => setMatches(mql.matches);
    update();
    mql.addEventListener("change", update);
    return () => mql.removeEventListener("change", update);
  }, [query]);

  return matches;
}

/**
 * True below the Tailwind `lg` breakpoint (1024px) — i.e. phones and most
 * tablets in portrait. This is the breakpoint at which the app switches from
 * the multi-column desktop layout to single-column / drawer layouts.
 */
export function useIsMobile(): boolean {
  return useMediaQuery("(max-width: 1023px)");
}
