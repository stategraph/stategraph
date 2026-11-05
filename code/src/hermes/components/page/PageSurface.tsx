import React from "react";

interface PageSurfaceProps {
  children: React.ReactNode;
  className?: string;
  style?: React.CSSProperties;
}

/**
 * PageSurface - Surface block for grouping content
 *
 * A styled panel with consistent background, border, radius, and shadow.
 * Used to visually separate content sections within a page.
 */
export function PageSurface({ children, className = "", style }: PageSurfaceProps) {
  return (
    <div
      className={`bg-[var(--sg-bg-1)] border border-[var(--sg-border)] rounded-[8px] p-4 sg-card-text ${className}`}
      style={{
        boxShadow: 'var(--sg-shadow-sm)',
        ...style
      }}
    >
      {children}
    </div>
  );
}
