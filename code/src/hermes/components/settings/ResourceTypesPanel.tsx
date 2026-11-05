'use client';

import { useCallback, useEffect, useMemo, useState } from 'react';
import { TenantResourceTypes, getTenantResourceTypes } from '@/lib/api/client';
import { exportResourceTypesAsJSON } from '@/lib/resource-types/export';
import { Button } from '@/components/ui/button';
import { Download } from 'lucide-react';

/**
 * The tenant's resource-type totals, and a JSON export of the breakdown they
 * come from.
 *
 * The breakdown itself is per state and per resource type and runs to tens of
 * thousands of rows on a large installation (a 500-state tenant measured 29,571),
 * so it is not rendered — it goes in the export file. What is on screen is the
 * four numbers those rows add up to.
 *
 * The endpoint is not paginated: one request returns every row, which is what
 * makes both the totals and the export whole by construction.
 */
export function ResourceTypesPanel({ tenantId }: { tenantId: string }) {
  const [data, setData] = useState<TenantResourceTypes | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [exporting, setExporting] = useState(false);
  const [exportError, setExportError] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      setData(await getTenantResourceTypes(tenantId));
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load resource types');
    } finally {
      setLoading(false);
    }
  }, [tenantId]);

  useEffect(() => {
    refresh();
  }, [refresh]);

  // Re-fetches rather than exporting the loaded copy, and refuses to write a file
  // whose rows do not sum to the totals the server reported alongside them.
  const handleExport = useCallback(async () => {
    setExporting(true);
    setExportError(null);
    try {
      await exportResourceTypesAsJSON(tenantId);
    } catch (err) {
      setExportError(err instanceof Error ? err.message : 'Export failed');
    } finally {
      setExporting(false);
    }
  }, [tenantId]);

  const { types, states } = useMemo(() => {
    const rows = data?.resource_types ?? [];
    return {
      types: new Set(rows.map((row) => row.type)).size,
      states: new Set(rows.map((row) => row.state_id)).size,
    };
  }, [data]);

  if (loading && !data) {
    return <div className="p-6 text-center">Loading resource types...</div>;
  }

  if (error) {
    return (
      <div className="p-6 text-center text-[var(--sg-error)]">
        Error: {error}
        <Button onClick={refresh} className="ml-4" variant="outline" size="sm">
          Retry
        </Button>
      </div>
    );
  }

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-start justify-between gap-4">
        <div className="flex flex-wrap gap-8">
          <Total label="Instances" value={data?.total_instances ?? 0} />
          <Total label="Resources" value={data?.total_resources ?? 0} />
          <Total label="Types" value={types} />
          <Total label="States" value={states} />
        </div>
        <Button
          variant="outline"
          size="sm"
          onClick={handleExport}
          disabled={exporting}
          title="Download the full per state, per type breakdown as JSON"
          className="gap-1 shrink-0"
        >
          <Download className="h-4 w-4" />
          {exporting ? 'Exporting...' : 'Export JSON'}
        </Button>
      </div>

      <p className="text-sm text-[var(--sg-text-muted)]">
        Instances is every deployed object across the tenant&apos;s live states — the count
        that <code className="font-mono text-xs">count</code> and{' '}
        <code className="font-mono text-xs">for_each</code> multiply. Resources is the number of
        declared addresses behind them, and excludes any resource type with nothing deployed. The
        export holds one row per state and resource type, with both counts.
      </p>

      {exportError && (
        <div className="rounded-md border border-[var(--sg-error)]/40 bg-[var(--sg-error)]/10 p-3 text-sm text-[var(--sg-error)]">
          {exportError}
        </div>
      )}
    </div>
  );
}

function Total({ label, value }: { label: string; value: number }) {
  return (
    <div>
      <div className="text-xs uppercase tracking-wide text-[var(--sg-text-muted)]">{label}</div>
      <div className="text-2xl font-semibold tabular-nums text-[var(--sg-text)]">
        {value.toLocaleString()}
      </div>
    </div>
  );
}
