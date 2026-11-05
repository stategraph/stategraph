"use client";

import type { ReactNode } from "react";

/** The area a setup flow renders in: the full console width, with room above. */
export function SetupShell({ children }: { children: ReactNode }) {
  return <div className="w-full py-1 sm:py-6">{children}</div>;
}
