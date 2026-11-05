"use client";

import { ChevronRight } from "lucide-react";
import { DeepLink } from "@/components/navigation/DeepLink";

export interface Crumb {
  label: string;
  href?: string;
}

/** Consistent breadcrumb trail for detail pages. The last crumb is the current
 *  page (never a link); earlier crumbs with an href navigate. */
export function Breadcrumbs({ items }: { items: Crumb[] }) {
  return (
    <nav className="flex items-center gap-1 text-xs text-[var(--sg-text-muted)]" aria-label="Breadcrumb">
      {items.map((c, i) => {
        const last = i === items.length - 1;
        return (
          <span key={`${c.label}-${i}`} className="flex items-center gap-1 min-w-0">
            {i > 0 && <ChevronRight className="w-3 h-3 shrink-0 text-[var(--sg-text-dim)]" />}
            {c.href && !last ? (
              <DeepLink
                href={c.href}
                className="truncate hover:text-[var(--sg-text)] hover:underline"
              >
                {c.label}
              </DeepLink>
            ) : (
              <span className={`truncate ${last ? "text-[var(--sg-text)]" : ""}`}>{c.label}</span>
            )}
          </span>
        );
      })}
    </nav>
  );
}
