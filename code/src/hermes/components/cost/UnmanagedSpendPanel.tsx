"use client";

import { useEffect, useState } from "react";

import { DeepLink } from "@/components/navigation";
import { useTenant } from "@/contexts";
import {
  getTenantCostUnmanaged,
  type TenantCostAttribution,
  type TenantCostUnmanagedEntry,
} from "@/lib/api/client";
import { hasNextPage, hasPrevPage, parseLinkHeader, type ParsedLinks } from "@/lib/api/pagination";
import { PaginationControls } from "@/components/instances/PaginationControls";
import { attributionCurrencyFor, gapAnalysisHref } from "@/lib/cost/actuals";
import { formatCurrency, parseCost } from "@/lib/cost/format";

const PAGE_SIZE = 25;

/**
 * The unmanaged-spend drill-down: every resource the bill names that matches
 * no managed resource, with its summed billed cost, and per-row links into
 * the gap-analysis import flow -- "you're paying for this and Stategraph
 * doesn't manage it" is the on-ramp to bringing it under management.
 *
 * Server-ordered by (resource id, provider) and cursor-paginated; the
 * headline total comes from the attribution summary, not from summing pages.
 */
export function UnmanagedSpendPanel({
  attribution,
}: {
  attribution: TenantCostAttribution;
}) {
  const { currentTenant } = useTenant();
  const tenantId = currentTenant?.id ?? null;

  // A cursor belongs to the tenant it was minted for: pair them, so a tenant
  // switch derives back to the first page instead of sending a foreign cursor.
  // pageNumber is display-only (the API paginates by cursor).
  const [pageState, setPageState] = useState<{
    tenantId: string;
    cursor: string[] | undefined;
    pageNumber: number;
  } | null>(null);
  const onTenant = pageState !== null && pageState.tenantId === tenantId;
  const cursor = onTenant ? pageState.cursor : undefined;
  const pageNumber = onTenant ? pageState.pageNumber : 1;
  const [entries, setEntries] = useState<TenantCostUnmanagedEntry[] | null>(null);
  const [links, setLinks] = useState<ParsedLinks>({});
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!tenantId) return;
    let cancelled = false;
    getTenantCostUnmanaged(tenantId, { page: cursor, limit: PAGE_SIZE })
      .then(({ data, linkHeader }) => {
        if (cancelled) return;
        setEntries(data.results);
        setLinks(parseLinkHeader(linkHeader));
        setError(null);
      })
      .catch((err: unknown) => {
        if (cancelled) return;
        setError(err instanceof Error ? err.message : "Failed to load unmanaged spend");
      });
    return () => {
      cancelled = true;
    };
  }, [tenantId, cursor]);

  const { currency } = attributionCurrencyFor(attribution);
  const totalUnmanaged = parseCost(attribution.unmanaged_cost);

  return (
    <div className="flex flex-col gap-2">
      <div className="flex items-baseline justify-between gap-3 flex-wrap">
        <div className="flex items-baseline gap-2 flex-wrap">
          <span className="text-xs text-[var(--sg-text-muted)] uppercase tracking-wide">
            Unmanaged spend
          </span>
          <span className="text-sm font-mono" style={{ color: "var(--sg-warning)" }}>
            {totalUnmanaged !== null ? formatCurrency(totalUnmanaged, currency) : "—"}
          </span>
          <span className="text-xs text-[var(--sg-text-dim)]">
            billed to cloud resources Stategraph does not manage · ordered by resource id
          </span>
        </div>
        <DeepLink
          href={gapAnalysisHref(attribution)}
          className="text-xs text-[var(--sg-accent)] hover:underline"
        >
          Bring these under management →
        </DeepLink>
      </div>

      {error && <div className="text-sm text-[var(--sg-error)]">{error}</div>}

      <div className="bg-[var(--sg-bg-1)] border border-[var(--sg-border-light)] rounded-md overflow-hidden">
        <table className="w-full text-sm">
          <thead>
            <tr className="text-[var(--sg-text-muted)] text-xs uppercase border-b border-[var(--sg-border-light)]">
              <th className="text-left px-3 py-2 font-medium">Resource</th>
              <th className="text-left px-3 py-2 font-medium">Provider</th>
              <th className="text-left px-3 py-2 font-medium">Service</th>
              <th className="text-left px-3 py-2 font-medium">Region</th>
              <th className="text-right px-3 py-2 font-medium">Lines</th>
              <th className="text-right px-3 py-2 font-medium">Billed</th>
              <th className="text-right px-3 py-2 font-medium"></th>
            </tr>
          </thead>
          <tbody>
            {entries === null && (
              <tr>
                <td colSpan={7} className="px-3 py-6 text-center text-[var(--sg-text-muted)]">
                  Loading unmanaged spend…
                </td>
              </tr>
            )}
            {entries !== null && entries.length === 0 && (
              <tr>
                <td colSpan={7} className="px-3 py-6 text-center text-[var(--sg-text-muted)]">
                  No unmanaged spend — every billed resource maps to a managed one.
                </td>
              </tr>
            )}
            {entries?.map((e) => {
              const billed = parseCost(e.billed_cost);
              return (
                <tr
                  key={`${e.resource_id}|${e.provider}`}
                  className="border-b last:border-b-0 border-[var(--sg-border-light)]"
                >
                  <td
                    className="px-3 py-2 font-mono text-xs text-[var(--sg-text)] truncate max-w-[360px]"
                    title={e.resource_id}
                  >
                    {e.resource_id}
                  </td>
                  <td className="px-3 py-2 text-[var(--sg-text-muted)]">{e.provider}</td>
                  <td
                    className="px-3 py-2 text-[var(--sg-text-muted)] truncate max-w-[160px]"
                    title={e.service_name ?? undefined}
                  >
                    {e.service_name ?? e.resource_type ?? "—"}
                  </td>
                  <td className="px-3 py-2 text-[var(--sg-text-muted)]">{e.region_id ?? "—"}</td>
                  <td className="px-3 py-2 text-right font-mono text-[var(--sg-text-muted)]">
                    {e.line_count}
                  </td>
                  <td className="px-3 py-2 text-right font-mono">
                    {billed !== null ? formatCurrency(billed, e.currency ?? "") : "—"}
                  </td>
                  <td className="px-3 py-2 text-right">
                    <DeepLink
                      href={`/gap-analysis?cloud=${encodeURIComponent(e.provider)}`}
                      className="text-xs text-[var(--sg-accent)] hover:underline whitespace-nowrap"
                      title="Open gap analysis to import unmanaged resources for this provider"
                    >
                      Import →
                    </DeepLink>
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>

      {(hasPrevPage(links) || hasNextPage(links)) && (
        <PaginationControls
          currentPage={pageNumber}
          hasNext={hasNextPage(links)}
          hasPrevious={hasPrevPage(links)}
          onNext={() =>
            tenantId &&
            setPageState({ tenantId, cursor: links.next, pageNumber: pageNumber + 1 })
          }
          onPrevious={() =>
            tenantId &&
            setPageState({
              tenantId,
              cursor: links.prev,
              pageNumber: Math.max(1, pageNumber - 1),
            })
          }
          isLoading={entries === null}
        />
      )}
    </div>
  );
}
