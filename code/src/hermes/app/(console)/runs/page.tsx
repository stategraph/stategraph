"use client";

import { Suspense, useCallback } from "react";
import { useSearchParams } from "next/navigation";
import { useDeepLinkRouter, useInitialLoad } from "@/hooks";
import { RunsContent } from "./content";

// Transaction-scoped params from when this page hosted the "State changes"
// feed as a second tab. A deep link carrying one belongs on /state-changes.
// NB: "state" is deliberately absent — it is the console-wide state-id param
// carried by useDeepLinkRouter, not a state-changes filter (that is "sname").
const STATE_CHANGE_PARAMS = ["status", "sname", "range", "from", "to"] as const;

const loading = (
  <div className="p-8 text-sm text-[var(--sg-text-muted)]">Loading runs…</div>
);

function RunsPageBody() {
  const router = useDeepLinkRouter();
  const searchParams = useSearchParams();

  const tab = searchParams.get("tab");
  const legacyStateChanges =
    tab === "state-changes" ||
    (tab === null && STATE_CHANGE_PARAMS.some((k) => searchParams.get(k) !== null));

  const redirectLegacy = useCallback(() => {
    if (!legacyStateChanges) return;
    const params = new URLSearchParams(searchParams.toString());
    params.delete("tab");
    const rest = params.toString();
    router.replace(rest ? `/state-changes?${rest}` : "/state-changes");
  }, [legacyStateChanges, router, searchParams]);
  useInitialLoad(redirectLegacy);

  if (legacyStateChanges) return loading;
  return <RunsContent />;
}

export default function RunsPage() {
  return (
    <Suspense fallback={loading}>
      <RunsPageBody />
    </Suspense>
  );
}
