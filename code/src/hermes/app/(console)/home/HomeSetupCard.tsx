"use client";

import { Database, ExternalLink, Workflow } from "lucide-react";
import { Button } from "@/components/ui/button";
import { useDeepLinkRouter } from "@/hooks";
import {
  ORCHESTRATION_SETUP_HREF,
  SETUP_COPY,
  STATE_DOCS_HREF,
  STATE_SETUP_HREF,
} from "@/lib/getting-started/setup-progress";

/** The compact card on Home for the product the tenant has not set up. */
export function HomeSetupCard({ kind }: { kind: "orchestration" | "state" }) {
  const router = useDeepLinkRouter();
  const copy = SETUP_COPY.homeCards[kind];
  const Icon = kind === "orchestration" ? Workflow : Database;
  const href = kind === "orchestration" ? ORCHESTRATION_SETUP_HREF : STATE_SETUP_HREF;

  return (
    <section className="flex flex-col gap-4 rounded-[var(--sg-card-radius)] border border-[var(--sg-accent)]/20 bg-[var(--sg-accent-bg)] px-5 py-4 lg:flex-row lg:items-center">
      <Icon aria-hidden="true" className="hidden h-6 w-6 shrink-0 text-[var(--sg-accent)] lg:block" />
      <div className="min-w-0 flex-1 space-y-1">
        <h2 className="text-base font-semibold text-[var(--sg-text)]">{copy.title}</h2>
        <p className="text-sm text-[var(--sg-text-muted)]">{copy.body}</p>
      </div>
      <div className="flex shrink-0 flex-wrap items-center gap-2">
        <Button size="sm" {...router.nav(href)}>
          {copy.action}
        </Button>
        {kind === "state" ? (
          <Button asChild variant="outline" size="sm">
            <a href={STATE_DOCS_HREF} target="_blank" rel="noopener noreferrer">
              {SETUP_COPY.homeCards.state.docsAction}
              <ExternalLink className="h-4 w-4" />
            </a>
          </Button>
        ) : null}
      </div>
    </section>
  );
}
