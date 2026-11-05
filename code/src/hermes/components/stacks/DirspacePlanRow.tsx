"use client";

import { useState, type ReactNode } from "react";
import { executeMQL } from "@/lib/api/client";
import { useDeepLinkRouter } from "@/hooks/useDeepLinkRouter";
import { asText } from "@/lib/mql/providers";
import type { VcsProvider } from "@/lib/vcs/links";
import { latestPlanQuery, planRunHref, type PrScope } from "@/app/(console)/stacks/mqlQueries";

type Lookup = "idle" | "opening" | "none" | "failed";

/**
 * A dirspace row that opens the dirspace's newest plan run on click. The run
 * is looked up on click, so a row costs no query until it is used.
 */
export function DirspacePlanRow({
  provider,
  pr,
  dir,
  workspace,
  className,
  children,
}: {
  provider: VcsProvider;
  pr: PrScope;
  dir: string;
  workspace: string;
  className: string;
  children: ReactNode;
}) {
  const router = useDeepLinkRouter();
  const [lookup, setLookup] = useState<Lookup>("idle");

  const open = async () => {
    setLookup("opening");
    try {
      const res = await executeMQL(latestPlanQuery(provider, pr, dir, workspace));
      const row = res.data[0] as Record<string, unknown> | undefined;
      if (!row) {
        setLookup("none");
        return;
      }
      router.push(planRunHref(asText(row.id), dir, workspace));
    } catch (e: unknown) {
      console.warn("Plan lookup failed", e);
      setLookup("failed");
    }
  };

  const note =
    lookup === "opening" ? (
      <span className="shrink-0 text-[var(--sg-text-dim)]">Opening plan…</span>
    ) : lookup === "none" ? (
      <span className="shrink-0 text-[var(--sg-text-dim)]">No plan run</span>
    ) : lookup === "failed" ? (
      <span className="shrink-0 text-[var(--sg-error)]">Could not load plan</span>
    ) : null;

  if (lookup === "none") {
    return (
      <div className={className}>
        {children}
        {note}
      </div>
    );
  }
  return (
    <button
      type="button"
      onClick={() => void open()}
      disabled={lookup === "opening"}
      aria-label={`Open the latest plan for ${dir} workspace ${workspace}`}
      className={`${className} w-full text-left cursor-pointer rounded hover:bg-[var(--sg-bg-2)] hover:text-[var(--sg-accent)] disabled:cursor-wait`}
    >
      {children}
      {note}
    </button>
  );
}
