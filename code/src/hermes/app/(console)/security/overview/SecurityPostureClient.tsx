"use client";

import { CostRangeSelector, KpiCard } from "@/components/cost";
import { PageHeader, PageSurface } from "@/components/page";
import {
  SecurityDisabledNotice,
  SecurityTrendChart,
  type SecurityDimension,
} from "@/components/security";
import { useTenant } from "@/contexts";
import {
  useSecurityAvailability,
  useTenantCostRange,
  useTenantSecurityHistory,
  useUrlSyncedNullable,
} from "@/hooks";
import type { TenantSecurityBreakdownEntry } from "@/lib/api/client";

const DIMENSIONS: { id: SecurityDimension; label: string }[] = [
  { id: "severity", label: "By severity" },
  { id: "blast", label: "By blast impact" },
];

function DimensionSelector({
  value,
  onChange,
}: {
  value: SecurityDimension;
  onChange: (next: SecurityDimension) => void;
}) {
  return (
    <div className="flex flex-wrap gap-1 p-1 bg-[var(--sg-bg-1)] border border-[var(--sg-border-light)] rounded-md w-fit">
      {DIMENSIONS.map((d) => {
        const active = d.id === value;
        return (
          <button
            key={d.id}
            onClick={() => onChange(d.id)}
            className={`px-3 py-1 text-sm rounded transition-colors ${
              active
                ? "bg-[var(--sg-accent)] text-[var(--sg-bg-0)]"
                : "text-[var(--sg-text-muted)] hover:text-[var(--sg-text)] hover:bg-[var(--sg-bg-2)]"
            }`}
          >
            {d.label}
          </button>
        );
      })}
    </div>
  );
}

function severityCount(entry: TenantSecurityBreakdownEntry, key: string): number {
  const rec = entry.severity_breakdown as Record<string, number | undefined>;
  return rec[key] ?? 0;
}

function formatScannedAt(iso: string | undefined): string {
  if (!iso) return "Never";
  const d = new Date(iso);
  return Number.isNaN(d.getTime()) ? "Never" : d.toLocaleString();
}

export function SecurityPostureClient() {
  const { currentTenant, isLoading: tenantLoading } = useTenant();
  const { capability, isLoading: securityLoading } = useSecurityAvailability();
  const [range, setRange] = useTenantCostRange();
  const [dimParam, setDimParam] = useUrlSyncedNullable("dim");

  const dimension: SecurityDimension = dimParam === "blast" ? "blast" : "severity";
  const setDimension = (next: SecurityDimension) =>
    // Keep the URL clean: the default (severity) is omitted.
    setDimParam(next === "severity" ? null : next);

  const { history, isLoading: historyLoading, error } = useTenantSecurityHistory({ range });

  const securitySupported = !securityLoading && capability?.enabled === true;

  // Current-posture snapshot = the latest day of the series, present only when
  // the tenant has at least one scanned state. The KPI cards read from it.
  const snapshot: TenantSecurityBreakdownEntry | null =
    history && history.states_scanned > 0 && history.points.length > 0
      ? history.points[history.points.length - 1]
      : null;

  // While the security capability is resolving, hold off so we don't flash the
  // disabled notice before we know.
  if (securityLoading || tenantLoading) {
    return (
      <div className="flex items-center justify-center min-h-[40vh] text-[var(--sg-text-muted)]">
        Loading security posture…
      </div>
    );
  }

  if (!securitySupported) {
    return <SecurityDisabledNotice />;
  }

  if (!currentTenant) {
    return (
      <div className="flex items-center justify-center min-h-[40vh] text-[var(--sg-text-muted)]">
        No tenant selected.
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-6 p-6">
      <PageHeader
        title="Security"
        subtitle="Tenant-wide security posture across all states"
      />

      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <KpiCard label="Open findings" value={String(snapshot?.findings_total_count ?? 0)} />
        <KpiCard
          label="Critical"
          value={String(snapshot ? severityCount(snapshot, "critical") : 0)}
        />
        <KpiCard
          label="States scanned"
          value={`${history?.states_scanned ?? 0} / ${history?.states_total ?? 0}`}
          hint="states with a completed scan"
        />
        <KpiCard label="Last scan" value={formatScannedAt(history?.last_scanned_at)} />
      </div>

      <div className="flex flex-wrap items-center gap-3">
        <DimensionSelector value={dimension} onChange={setDimension} />
        <CostRangeSelector value={range} onChange={setRange} />
      </div>

      <PageSurface className="p-4">
        {historyLoading ? (
          <div className="flex items-center justify-center h-[320px] text-[var(--sg-text-muted)]">
            Loading…
          </div>
        ) : error ? (
          <div className="flex items-center justify-center h-[320px] text-[var(--sg-text-muted)]">
            Couldn&apos;t load security history: {error}
          </div>
        ) : !history || history.points.length === 0 || !snapshot ? (
          <div className="flex items-center justify-center h-[320px] text-[var(--sg-text-muted)]">
            No security scans in this range yet.
          </div>
        ) : (
          <SecurityTrendChart points={history.points} dimension={dimension} />
        )}
      </PageSurface>
    </div>
  );
}
