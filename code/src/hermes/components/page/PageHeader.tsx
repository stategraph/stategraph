import React from "react";

interface PageHeaderProps {
  title: string;
  subtitle?: string;
  children?: React.ReactNode;
}

/**
 * PageHeader - Full-width header for product pages
 *
 * Displays page title, optional subtitle, and toolbar actions.
 * Used at the top of every product page for consistent layout.
 */
export function PageHeader({ title, subtitle, children }: PageHeaderProps) {
  return (
    <div className="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between w-full px-4 sm:px-6 py-4 bg-[var(--sg-bg-0)] border-b border-[var(--sg-border)]">
      <div className="flex flex-col gap-1">
        <h1 className="text-xl sm:text-2xl font-semibold text-[var(--sg-text)]">
          {title}
        </h1>
        {subtitle && (
          <p className="text-sm text-[var(--sg-text-muted)]">{subtitle}</p>
        )}
      </div>
      {children && <div>{children}</div>}
    </div>
  );
}
