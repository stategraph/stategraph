"use client";

import { Workflow } from "lucide-react";

import { FeatureDisabledNotice } from "@/components/product";
import { ORCHESTRATION_COPY } from "@/lib/getting-started/orchestration-constants";

/**
 * Shown by orchestration screens when the server runs without the Terrateam
 * orchestration side (the MQL schema has no orchestration tables). Same shape
 * as the security/cost "not enabled on this server" notices. `compact` is the
 * one-line form for a surface that stays usable around it, such as the
 * getting-started chooser card.
 */
export function OrchestrationUnavailable({ compact = false }: { compact?: boolean }) {
  if (compact) {
    return (
      <div className="flex items-center gap-2 rounded-md border border-[var(--sg-warning)]/30 bg-[var(--sg-warning)]/10 px-3 py-2 text-sm text-[var(--sg-warning)]">
        <Workflow className="h-4 w-4 shrink-0" />
        <span>{ORCHESTRATION_COPY.availability.unavailable}</span>
      </div>
    );
  }

  return (
    <FeatureDisabledNotice
      icon={Workflow}
      title="Orchestration isn't enabled on this server"
      body="Stategraph orchestrates plans and applies from your pull requests once the orchestration service is enabled. See the docs to turn it on."
      docsHref="https://stategraph.com/docs"
      docsLabel="Read the docs"
    />
  );
}
