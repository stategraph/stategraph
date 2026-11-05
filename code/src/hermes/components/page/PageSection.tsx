import React from "react";

interface PageSectionProps {
  title?: string;
  children: React.ReactNode;
  actions?: React.ReactNode;
  className?: string;
}

/**
 * PageSection - Container for major content areas
 *
 * Groups related content with an optional section title.
 * Provides consistent spacing between page sections.
 */
export function PageSection({ title, children, actions, className }: PageSectionProps) {
  return (
    <div className={className ? `mt-4 ${className}` : "mt-4"}>
      {(title || actions) && (
        <div className="flex flex-wrap items-center justify-between gap-2 mb-3">
          {title && (
            <h2 className="text-base font-medium text-[var(--sg-text)]">
              {title}
            </h2>
          )}
          {actions && <div>{actions}</div>}
        </div>
      )}
      {children}
    </div>
  );
}
