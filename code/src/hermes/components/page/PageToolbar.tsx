import React from "react";

interface PageToolbarProps {
  children: React.ReactNode;
}

/**
 * PageToolbar - Right-aligned toolbar for PageHeader actions
 *
 * Container for filters, export buttons, state selectors, etc.
 * Used inside PageHeader for consistent action placement.
 */
export function PageToolbar({ children }: PageToolbarProps) {
  return <div className="flex items-center gap-2">{children}</div>;
}
