"use client";

import { useEffect, useMemo, useState } from "react";
import { Globe } from "lucide-react";

import { StateFilter } from "@/components/filters";
import { KpiCard } from "@/components/cost";
import {
  SecurityDisabledNotice,
  SeverityBadge,
  SEVERITY_ORDER,
  severityRank,
} from "@/components/security";
import { PageHeader, PageSection, PageSurface } from "@/components/page";
import { useStates } from "@/contexts";
import {
  useDeepLinkRouter,
  useSecurityAvailability,
  useStateSelection,
  useUrlSyncedNullable,
} from "@/hooks";
import {
  getStateSecurityFindings,
  getStateSecurityFindingsSummary,
  type SecurityFinding,
  type SecurityFindingsSummary,
  type SecurityScan,
} from "@/lib/api/client";
import { capitalize } from "@/lib/utils";
import { fetchStateIdsWithFindings } from "@/lib/security/states";

// First-page cap. The endpoint paginates via Link header, which this page does
// not yet follow; surface the cap so a truncated list never reads as complete.
const FINDINGS_LIMIT = 200;

const SEVERITY_FILTERS: { id: string | null; label: string }[] = [
  { id: null, label: "All" },
  ...SEVERITY_ORDER.map((s) => ({ id: s, label: capitalize(s) })),
];

function formatRelative(iso: string): string {
  const then = new Date(iso).getTime();
  if (!Number.isFinite(then)) return iso;
  const seconds = Math.max(0, Math.round((Date.now() - then) / 1000));
  if (seconds < 60) return `${seconds}s ago`;
  const minutes = Math.round(seconds / 60);
  if (minutes < 60) return `${minutes}m ago`;
  const hours = Math.round(minutes / 60);
  if (hours < 24) return `${hours}h ago`;
  const days = Math.round(hours / 24);
  if (days < 30) return `${days}d ago`;
  const months = Math.round(days / 30);
  if (months < 12) return `${months}mo ago`;
  return `${Math.round(months / 12)}y ago`;
}

function SeverityFilterControl({
  value,
  onChange,
}: {
  value: string | null;
  onChange: (next: string | null) => void;
}) {
  return (
    <div className="flex flex-wrap gap-1 p-1 bg-[var(--sg-bg-1)] border border-[var(--sg-border-light)] rounded-md w-fit">
      {SEVERITY_FILTERS.map((f) => {
        const active = f.id === value;
        return (
          <button
            key={f.id ?? "all"}
            onClick={() => onChange(f.id)}
            className={`px-3 py-1 text-sm rounded transition-colors ${
              active
                ? "bg-[var(--sg-accent)] text-[var(--sg-bg-0)]"
                : "text-[var(--sg-text-muted)] hover:text-[var(--sg-text)] hover:bg-[var(--sg-bg-2)]"
            }`}
          >
            {f.label}
          </button>
        );
      })}
    </div>
  );
}

function FindingsTable({
  findings,
  stateId,
}: {
  findings: SecurityFinding[];
  stateId: string;
}) {
  const router = useDeepLinkRouter();
  return (
    <div className="bg-[var(--sg-bg-1)] border border-[var(--sg-border-light)] rounded-md overflow-x-auto">
      <table className="w-full text-sm">
        <thead>
          <tr className="text-[var(--sg-text-muted)] text-xs uppercase border-b border-[var(--sg-border-light)]">
            <th className="text-left px-3 py-2 font-medium">Severity</th>
            <th className="text-left px-3 py-2 font-medium">Check</th>
            <th className="text-left px-3 py-2 font-medium">Resource</th>
            <th className="text-right px-3 py-2 font-medium">Blast resources</th>
            <th className="text-right px-3 py-2 font-medium">Blast modules</th>
            <th className="text-left px-3 py-2 font-medium">Internet</th>
            <th className="text-left px-3 py-2 font-medium">Workspace</th>
          </tr>
        </thead>
        <tbody>
          {findings.map((f) => {
            const sourceLocation = f.source_file
              ? `${f.source_file}${f.source_start_line ? `:${f.source_start_line}` : ""}`
              : null;
            return (
              <tr
                key={f.fingerprint}
                {...router.nav(`/security/findings/detail?state=${encodeURIComponent(stateId)}&fingerprint=${encodeURIComponent(f.fingerprint)}`)}
                title="View finding detail"
                className="border-b last:border-b-0 border-[var(--sg-border-light)] align-top cursor-pointer hover:bg-[var(--sg-bg-2)] transition-colors"
              >
                <td className="px-3 py-2">
                  <SeverityBadge severity={f.severity_effective} />
                  {f.severity_reason && (
                    <div
                      className="text-xs text-[var(--sg-text-dim)] mt-1 max-w-[180px]"
                      title={f.severity_reason}
                    >
                      {f.severity_reason}
                    </div>
                  )}
                </td>
                <td className="px-3 py-2 font-mono text-[var(--sg-text)] whitespace-nowrap">
                  {f.check_id}
                </td>
                <td className="px-3 py-2 text-[var(--sg-text)]">
                  <span className="font-mono break-all">{f.resource_fq_address}</span>
                  {sourceLocation && (
                    <div className="text-xs text-[var(--sg-text-dim)] mt-0.5 font-mono break-all">
                      {sourceLocation}
                    </div>
                  )}
                </td>
                <td className="px-3 py-2 text-right font-mono text-[var(--sg-text-muted)]">
                  {typeof f.blast_radius_resource_count === "number"
                    ? f.blast_radius_resource_count
                    : "—"}
                </td>
                <td className="px-3 py-2 text-right font-mono text-[var(--sg-text-muted)]">
                  {Array.isArray(f.blast_radius_modules) ? f.blast_radius_modules.length : "—"}
                </td>
                <td className="px-3 py-2">
                  {f.is_internet_reachable ? (
                    <span
                      className="inline-flex items-center gap-1 text-xs font-medium"
                      style={{ color: "var(--sg-error)" }}
                    >
                      <Globe className="h-3.5 w-3.5" />
                      Reachable
                    </span>
                  ) : (
                    <span className="text-xs text-[var(--sg-text-dim)]">—</span>
                  )}
                </td>
                <td className="px-3 py-2 text-[var(--sg-text-muted)] whitespace-nowrap">
                  {f.workspace ?? "—"}
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}

export function SecurityFindingsClient() {
  const { states, isLoading: statesLoading } = useStates();
  const { capability, isLoading: securityLoading } = useSecurityAvailability();

  const [selectedStateId, setSelectedStateId] = useStateSelection({ allowAll: false });
  const [severity, setSeverity] = useUrlSyncedNullable("severity");

  const [findings, setFindings] = useState<SecurityFinding[]>([]);
  const [scan, setScan] = useState<SecurityScan | null>(null);
  const [totalCount, setTotalCount] = useState(0);
  const [findingsLoading, setFindingsLoading] = useState(false);
  const [findingsError, setFindingsError] = useState<string | null>(null);

  const [summary, setSummary] = useState<SecurityFindingsSummary | null>(null);

  // Which states currently have findings, so the picker can grey out the rest
  // (same treatment Analysis gives states without cost data). Fetched once via
  // MQL; on failure we leave it null and grey out nothing rather than mislead.
  const [statesWithFindings, setStatesWithFindings] = useState<Set<string> | null>(null);
  useEffect(() => {
    let cancelled = false;
    fetchStateIdsWithFindings()
      .then((set) => {
        if (!cancelled) setStatesWithFindings(set);
      })
      .catch(() => {
        if (!cancelled) setStatesWithFindings(null);
      });
    return () => {
      cancelled = true;
    };
  }, []);
  const noFindingsStateIds = useMemo(
    () =>
      statesWithFindings
        ? states.filter((s) => !statesWithFindings.has(s.id)).map((s) => s.id)
        : undefined,
    [states, statesWithFindings]
  );

  // Findings list: refetched whenever the state or the severity filter changes.
  useEffect(() => {
    const stateId = selectedStateId;
    if (!stateId) return;
    let cancelled = false;
    async function load(id: string) {
      setFindingsLoading(true);
      setFindingsError(null);
      try {
        const res = await getStateSecurityFindings(id, {
          severity: severity ?? undefined,
          limit: FINDINGS_LIMIT,
        });
        if (cancelled) return;
        setFindings(res.findings);
        setScan(res.scan ?? null);
        setTotalCount(res.total_count);
      } catch (err: unknown) {
        if (cancelled) return;
        setFindingsError(err instanceof Error ? err.message : "Failed to load findings");
        setFindings([]);
        setScan(null);
        setTotalCount(0);
      } finally {
        if (!cancelled) setFindingsLoading(false);
      }
    }
    load(stateId);
    return () => {
      cancelled = true;
    };
  }, [selectedStateId, severity]);

  // Summary KPIs: scan-wide, so independent of the severity filter. Tolerant of
  // failure (a never-scanned state still renders the rest of the page).
  useEffect(() => {
    const stateId = selectedStateId;
    if (!stateId) {
      setSummary(null);
      return;
    }
    let cancelled = false;
    getStateSecurityFindingsSummary(stateId)
      .then((res) => {
        if (!cancelled) setSummary(res);
      })
      .catch(() => {
        if (!cancelled) setSummary(null);
      });
    return () => {
      cancelled = true;
    };
  }, [selectedStateId]);

  // Most-severe first, then widest blast radius -- the natural triage order.
  const sortedFindings = useMemo(() => {
    return [...findings].sort((a, b) => {
      const rank = severityRank(a.severity_effective) - severityRank(b.severity_effective);
      if (rank !== 0) return rank;
      return (b.blast_radius_resource_count ?? 0) - (a.blast_radius_resource_count ?? 0);
    });
  }, [findings]);

  const securitySupported = !securityLoading && capability?.enabled === true;

  if (statesLoading || securityLoading) {
    return (
      <div className="flex items-center justify-center min-h-[40vh] text-[var(--sg-text-muted)]">
        Loading…
      </div>
    );
  }

  if (!securitySupported) {
    return <SecurityDisabledNotice />;
  }

  if (states.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center min-h-[40vh] gap-2 text-center px-4">
        <div className="text-[var(--sg-text)] font-medium">No states available</div>
        <div className="text-sm text-[var(--sg-text-muted)] max-w-md">
          Import a Terraform state first; security findings are scanned per state.
        </div>
      </div>
    );
  }

  const selectedState = selectedStateId
    ? states.find((s) => s.id === selectedStateId) ?? null
    : null;

  const breakdown = summary?.severity_breakdown ?? {};
  const scannedAt = summary?.scan?.scanned_at ?? scan?.scanned_at;
  const scanner = summary?.scan?.scanner ?? scan?.scanner;
  // The state has a completed scan iff one of the endpoints returned a scan.
  const everScanned = Boolean(summary?.scan ?? scan);
  const truncated = totalCount > sortedFindings.length;

  return (
    <div className="flex flex-col">
      <PageHeader
        title="Findings"
        subtitle="Security findings from the latest scan of a state, with graph context"
      >
        <StateFilter
          value={selectedStateId}
          onChange={setSelectedStateId}
          disabledStateIds={noFindingsStateIds}
          disabledLabel="No findings"
          className="min-w-[220px]"
        />
      </PageHeader>

      <PageSection className="mx-6">
        <div className="flex flex-col gap-4">
          <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-5 gap-3">
            <KpiCard
              label="Total findings"
              value={`${summary?.total ?? totalCount}`}
              hint={everScanned ? undefined : "Not scanned yet"}
            />
            <KpiCard label="Critical" value={`${breakdown.critical ?? 0}`} />
            <KpiCard label="High" value={`${breakdown.high ?? 0}`} />
            <KpiCard
              label="Internet-reachable"
              value={`${summary?.internet_reachable_count ?? 0}`}
              hint={
                summary && summary.internet_reachable_count > 0
                  ? "Exposed to the internet"
                  : undefined
              }
            />
            <KpiCard
              label="Last scanned"
              value={scannedAt ? formatRelative(scannedAt) : "—"}
              hint={scanner ? `by ${scanner}` : undefined}
            />
          </div>

          <div className="flex items-center gap-2">
            <span className="text-xs uppercase tracking-wide text-[var(--sg-text-muted)]">
              Severity
            </span>
            <SeverityFilterControl value={severity} onChange={setSeverity} />
          </div>

          <PageSurface>
            {!selectedState && (
              <div className="flex items-center justify-center h-[240px] text-[var(--sg-text-muted)]">
                Select a state to view its security findings.
              </div>
            )}
            {selectedState && findingsLoading && (
              <div className="flex items-center justify-center h-[240px] text-[var(--sg-text-muted)]">
                Loading findings…
              </div>
            )}
            {selectedState && !findingsLoading && findingsError && (
              <div className="flex items-center justify-center h-[240px] text-[var(--sg-error)]">
                {findingsError}
              </div>
            )}
            {selectedState && !findingsLoading && !findingsError && !everScanned && (
              <div className="flex flex-col items-center justify-center h-[240px] gap-2 text-center px-4">
                <div className="text-[var(--sg-text)] font-medium">
                  No scan yet for {selectedState.name}
                </div>
                <div className="text-sm text-[var(--sg-text-muted)] max-w-md">
                  This state hasn&apos;t been scanned. Scans run automatically on import and
                  apply; pick another state to compare.
                </div>
              </div>
            )}
            {selectedState &&
              !findingsLoading &&
              !findingsError &&
              everScanned &&
              sortedFindings.length === 0 && (
                <div className="flex flex-col items-center justify-center h-[240px] gap-2 text-center px-4">
                  <div className="text-[var(--sg-text)] font-medium">
                    {severity ? `No ${severity} findings` : "No findings"}
                  </div>
                  <div className="text-sm text-[var(--sg-text-muted)]">
                    {severity
                      ? "Try a different severity, or clear the filter."
                      : "This state's latest scan came back clean."}
                  </div>
                </div>
              )}
            {selectedState &&
              !findingsLoading &&
              !findingsError &&
              sortedFindings.length > 0 && (
                <div className="flex flex-col gap-2">
                  <FindingsTable findings={sortedFindings} stateId={selectedState.id} />
                  {truncated && (
                    <div className="text-xs text-[var(--sg-text-dim)]">
                      Showing the first {sortedFindings.length} of {totalCount} findings.
                    </div>
                  )}
                </div>
              )}
          </PageSurface>
        </div>
      </PageSection>
    </div>
  );
}
