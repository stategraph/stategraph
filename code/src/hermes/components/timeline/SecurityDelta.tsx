"use client";

import { useEffect, useState } from "react";
import {
  getTxSecurityImpact,
  type TxSecurityImpact,
  type SecurityFinding,
} from "@/lib/api/client";
import { useSecurityAvailability } from "@/hooks";
import { SeverityBadge, severityRank } from "@/components/security";

type DeltaState =
  | { kind: "loading" }
  | { kind: "ready"; impact: TxSecurityImpact }
  | { kind: "computing" }
  | { kind: "none" }
  | { kind: "error"; message: string };

// One finding row: severity pill + resource address, with the check id and the
// enrichment markers (internet-reachable, blast radius) underneath.
function FindingRow({ f }: { f: SecurityFinding }) {
  const blast = f.blast_radius_resource_count;
  return (
    <div className="flex items-start gap-2 py-1.5">
      <SeverityBadge severity={f.severity_effective} />
      <div className="min-w-0 flex-1">
        <div className="text-xs font-mono text-[var(--sg-text)] break-all">
          {f.resource_fq_address}
        </div>
        <div className="mt-0.5 flex flex-wrap items-center gap-x-2 gap-y-0.5 text-[11px] text-[var(--sg-text-dim)]">
          <span className="font-mono">{f.check_id}</span>
          {f.is_internet_reachable && (
            <span className="text-amber-400">internet-reachable</span>
          )}
          {typeof blast === "number" && blast > 0 && <span>blast {blast}</span>}
        </div>
      </div>
    </div>
  );
}

// One side of the delta (added or resolved): the count -- coloured red (added)
// or green (resolved) when non-zero -- and the finding list, severest first.
// Nothing is rendered below the count when the side is empty.
function DeltaSide({
  label,
  kind,
  findings,
}: {
  label: string;
  kind: "added" | "resolved";
  findings: SecurityFinding[];
}) {
  const sorted = [...findings].sort(
    (a, b) =>
      severityRank(a.severity_effective) - severityRank(b.severity_effective)
  );
  const countClass =
    findings.length === 0
      ? "text-[var(--sg-text)]"
      : kind === "added"
        ? "text-red-400"
        : "text-green-400";
  return (
    <div className="flex-1 min-w-[14rem]">
      <div className="flex items-baseline justify-between mb-1.5">
        <span className="text-xs font-medium text-[var(--sg-text-dim)]">
          {label}
        </span>
        <span className={`text-sm font-mono ${countClass}`}>
          {findings.length}
        </span>
      </div>
      {sorted.length > 0 && (
        <div className="rounded border border-[var(--sg-border)] bg-[var(--sg-bg-2)] px-2 divide-y divide-[var(--sg-border)]">
          {sorted.map((f, i) => (
            <FindingRow key={`${f.fingerprint}:${i}`} f={f} />
          ))}
        </div>
      )}
    </div>
  );
}

/**
 * The transaction's security delta (the per-tx impact). Hidden entirely when the
 * server has security disabled. Shows the findings the tx adds vs resolves, with
 * a source tag (plan-time preview vs post-commit).
 */
export function SecurityDelta({ txId }: { txId: string }) {
  const { capability, isLoading: capLoading } = useSecurityAvailability();
  const enabled = capability?.enabled ?? false;
  // Hold the settled result together with the txId it belongs to (the
  // useStateCosts pattern). Loading is then derived -- there is no synchronous
  // setState in the effect to reset it -- so a previous tx's delta is never
  // shown for the current one.
  const [settled, setSettled] = useState<{
    txId: string;
    state: DeltaState;
  } | null>(null);

  useEffect(() => {
    if (!enabled) return;
    let cancelled = false;
    getTxSecurityImpact(txId)
      .then((r) => {
        if (cancelled) return;
        if (r.status === "ready")
          setSettled({ txId, state: { kind: "ready", impact: r.impact } });
        else if (r.status === "computing")
          setSettled({ txId, state: { kind: "computing" } });
        else setSettled({ txId, state: { kind: "none" } });
      })
      .catch((e) => {
        if (cancelled) return;
        setSettled({
          txId,
          state: {
            kind: "error",
            message:
              e instanceof Error ? e.message : "Failed to load security delta",
          },
        });
      });
    return () => {
      cancelled = true;
    };
  }, [txId, enabled]);

  // Security off (or capabilities still loading): render no section at all.
  if (capLoading || !enabled) return null;

  // Until the fetch for *this* txId settles, show loading rather than a stale
  // result carried over from a previously rendered tx.
  const state: DeltaState =
    settled !== null && settled.txId === txId
      ? settled.state
      : { kind: "loading" };

  return (
    <div className="border-b border-[var(--sg-border)] pb-4 min-w-0">
      <div className="flex items-center justify-between mb-3 pb-2 border-b border-[var(--sg-border)]">
        <h3 className="text-sm font-semibold text-[var(--sg-text)]">
          Security delta
        </h3>
        {state.kind === "ready" && (
          <span className="text-[10px] uppercase tracking-wide px-2 py-0.5 rounded bg-[var(--sg-bg-2)] text-[var(--sg-text-muted)] border border-[var(--sg-border)]">
            {state.impact.source === "commit" ? "post-commit" : "plan-time"}
          </span>
        )}
      </div>

      {state.kind === "loading" && (
        <div className="text-xs text-[var(--sg-text-dim)]">Loading…</div>
      )}
      {state.kind === "computing" && (
        <div className="text-xs text-[var(--sg-text-dim)]">
          Analysis in progress — the planned scan is still running.
        </div>
      )}
      {state.kind === "none" && (
        <div className="text-xs text-[var(--sg-text-dim)]">
          No security delta for this transaction.
        </div>
      )}
      {state.kind === "error" && (
        <div className="text-xs text-red-400">{state.message}</div>
      )}
      {state.kind === "ready" && (
        <div className="space-y-4">
          {/* Side-by-side when the panel is wide enough; each column has a
              min-width, so they wrap to a vertical stack when it isn't. */}
          <div className="flex flex-wrap gap-x-8 gap-y-4">
            <DeltaSide
              label="Added"
              kind="added"
              findings={state.impact.findings_added}
            />
            <DeltaSide
              label="Resolved"
              kind="resolved"
              findings={state.impact.findings_resolved}
            />
          </div>
          {state.impact.cross_boundary_finding_count > 0 && (
            <div className="text-xs text-[var(--sg-text-dim)]">
              {state.impact.cross_boundary_finding_count} finding
              {state.impact.cross_boundary_finding_count === 1 ? "" : "s"} cross a
              state boundary.
            </div>
          )}
        </div>
      )}
    </div>
  );
}
