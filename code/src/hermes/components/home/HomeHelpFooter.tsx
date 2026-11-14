"use client";

import { BookOpen, LifeBuoy } from "lucide-react";
import { DeepLink } from "@/components/navigation";
import { HELP_DOCS_HREF, HELP_SUPPORT_HREF, SETUP_COPY } from "@/lib/getting-started/setup-progress";

const COPY = SETUP_COPY.help;

const LINK =
  "inline-flex items-center gap-2 text-sm text-[var(--sg-text-muted)] transition-colors hover:text-[var(--sg-accent)]";

/** The docs and support, at the foot of Home. Slack sits in the sidebar. */
export function HomeHelpFooter() {
  return (
    <nav
      aria-label={COPY.label}
      className="flex flex-wrap items-center gap-x-6 gap-y-2 border-t border-[var(--sg-border)] pt-4"
    >
      <a href={HELP_DOCS_HREF} target="_blank" rel="noopener noreferrer" className={LINK}>
        <BookOpen className="h-4 w-4" />
        {COPY.docs}
      </a>
      <DeepLink href={HELP_SUPPORT_HREF} className={LINK}>
        <LifeBuoy className="h-4 w-4" />
        {COPY.support}
      </DeepLink>
    </nav>
  );
}
