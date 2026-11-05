"use client";

import { Fragment, useMemo, useState, type ReactNode } from "react";
import Link from "next/link";
import { ChevronDown, ChevronRight } from "lucide-react";

import type { CostComponent, InstanceCost, StateCostActualResource } from "@/lib/api/client";
import { formatWindow, monthlyRunRate, MIN_COMPARE_WINDOW_DAYS } from "@/lib/cost/actuals";
import { formatCurrency, parseCost } from "@/lib/cost/format";
import { matchesSearch } from "@/lib/ui/search";

type GroupBy = "none" | "type" | "provider";
type SortBy = "monthly_desc" | "hourly_desc" | "address";

export interface ResourceCostTableProps {
  instanceCosts: InstanceCost[];
  currency: string;
  /**
   * Optional builder for the per-resource deep link. Defaults to the instances
   * list filtered to the resource address.
   */
  resourceHref?: (ic: InstanceCost) => string;
  /**
   * Actual (FOCUS) spend by address, for the estimate-vs-actual comparison.
   * When present an "Actual" column is added: a monthly run rate where the
   * resource's billed window supports one, otherwise the raw billed sum. A
   * resource with no entry shows "—" (no billing line matched its cloud
   * identifiers) -- never zero. Omit for the pure estimated view.
   */
  actuals?: Map<string, StateCostActualResource>;
}

/**
 * The per-resource cost breakdown for a state: one row per instance with an
 * expandable detail showing each cost component, the resource's tags, and its
 * cloud resource id. Supports search, group-by (type / provider), and sort.
 * This is the richest cost data we produce and was previously rendered nowhere.
 */
export function ResourceCostTable({
  instanceCosts,
  currency,
  resourceHref,
  actuals,
}: ResourceCostTableProps) {
  const numCols = actuals ? 6 : 5;
  const [search, setSearch] = useState("");
  const [groupBy, setGroupBy] = useState<GroupBy>("none");
  const [sortBy, setSortBy] = useState<SortBy>("monthly_desc");
  const [expanded, setExpanded] = useState<Set<string>>(new Set());

  const toggle = (address: string) =>
    setExpanded((prev) => {
      const next = new Set(prev);
      if (next.has(address)) next.delete(address);
      else next.add(address);
      return next;
    });

  const rows = useMemo(() => {
    const filtered = instanceCosts.filter((ic) =>
      matchesSearch(search, ic.address, ic.type, ic.provider ?? "")
    );
    return [...filtered].sort((a, b) => compareInstance(a, b, sortBy));
  }, [instanceCosts, search, sortBy]);

  const groups = useMemo(() => {
    if (groupBy === "none") return null;
    const map = new Map<string, InstanceCost[]>();
    for (const ic of rows) {
      const key = (groupBy === "type" ? ic.type : ic.provider) || "—";
      const arr = map.get(key);
      if (arr) arr.push(ic);
      else map.set(key, [ic]);
    }
    return [...map.entries()].sort((a, b) => groupTotal(b[1]) - groupTotal(a[1]));
  }, [rows, groupBy]);

  const href = (ic: InstanceCost) =>
    resourceHref ? resourceHref(ic) : `/instances?q=${encodeURIComponent(ic.address)}`;

  const renderRow = (ic: InstanceCost): ReactNode => {
    const monthly = parseCost(ic.monthly_cost);
    const hourly = parseCost(ic.hourly_cost);
    const hasTags = !!ic.tags && Object.keys(ic.tags).length > 0;
    const canExpand = (ic.components?.length ?? 0) > 0 || hasTags || !!ic.cloud_resource_id;
    const isOpen = expanded.has(ic.address);
    return (
      <Fragment key={ic.address}>
        <tr
          className={`border-b last:border-b-0 border-[var(--sg-border-light)] ${
            canExpand ? "cursor-pointer hover:bg-[var(--sg-bg-2)]" : ""
          }`}
          onClick={canExpand ? () => toggle(ic.address) : undefined}
        >
          <td className="px-3 py-2">
            <div className="flex items-center gap-1.5">
              {canExpand ? (
                isOpen ? (
                  <ChevronDown className="w-3.5 h-3.5 text-[var(--sg-text-dim)] shrink-0" />
                ) : (
                  <ChevronRight className="w-3.5 h-3.5 text-[var(--sg-text-dim)] shrink-0" />
                )
              ) : (
                <span className="w-3.5 shrink-0" />
              )}
              <Link
                href={href(ic)}
                onClick={(e) => e.stopPropagation()}
                className="font-mono text-[var(--sg-accent)] hover:underline truncate max-w-[360px]"
                title={ic.address}
              >
                {ic.address}
              </Link>
              {ic.provider && <ProviderPill provider={ic.provider} />}
            </div>
          </td>
          <td className="px-3 py-2 font-mono text-[var(--sg-text-muted)]">{ic.type}</td>
          <td className="px-3 py-2 text-[var(--sg-text-muted)]">{ic.region || "—"}</td>
          <td className="px-3 py-2 text-right font-mono">{monthlyCell(ic, monthly, currency)}</td>
          <td className="px-3 py-2 text-right font-mono text-[var(--sg-text-muted)]">
            {hourly !== null ? formatCurrency(hourly, currency) : "—"}
          </td>
          {actuals && (
            <td className="px-3 py-2 text-right font-mono">
              {actualCell(actuals.get(ic.address), currency)}
            </td>
          )}
        </tr>
        {isOpen && canExpand && (
          <tr className="border-b last:border-b-0 border-[var(--sg-border-light)] bg-[var(--sg-bg-0)]">
            <td colSpan={numCols} className="px-3 py-3">
              <ResourceDetail ic={ic} currency={currency} />
            </td>
          </tr>
        )}
      </Fragment>
    );
  };

  // Mobile equivalent of renderRow: the same row data as a stacked card, with
  // the same expand-to-detail behaviour (shared `expanded` set + `toggle`).
  const renderCard = (ic: InstanceCost): ReactNode => {
    const monthly = parseCost(ic.monthly_cost);
    const hourly = parseCost(ic.hourly_cost);
    const hasTags = !!ic.tags && Object.keys(ic.tags).length > 0;
    const canExpand = (ic.components?.length ?? 0) > 0 || hasTags || !!ic.cloud_resource_id;
    const isOpen = expanded.has(ic.address);
    return (
      <div
        key={ic.address}
        className="rounded-lg border border-[var(--sg-border-light)] bg-[var(--sg-bg-1)] p-3"
      >
        <div
          className={`flex items-start justify-between gap-2 ${canExpand ? "cursor-pointer" : ""}`}
          onClick={canExpand ? () => toggle(ic.address) : undefined}
        >
          <div className="flex items-start gap-1.5 min-w-0">
            {canExpand ? (
              isOpen ? (
                <ChevronDown className="w-3.5 h-3.5 mt-0.5 text-[var(--sg-text-dim)] shrink-0" />
              ) : (
                <ChevronRight className="w-3.5 h-3.5 mt-0.5 text-[var(--sg-text-dim)] shrink-0" />
              )
            ) : (
              <span className="w-3.5 shrink-0" />
            )}
            <Link
              href={href(ic)}
              onClick={(e) => e.stopPropagation()}
              className="font-mono text-[var(--sg-accent)] hover:underline break-all min-w-0"
              title={ic.address}
            >
              {ic.address}
            </Link>
          </div>
          {ic.provider && <ProviderPill provider={ic.provider} />}
        </div>
        <div className="mt-2 space-y-1.5 text-sm">
          <div className="flex items-start justify-between gap-3">
            <span className="text-[var(--sg-text-muted)]">Type</span>
            <span className="font-mono text-[var(--sg-text-muted)] break-all text-right min-w-0">
              {ic.type}
            </span>
          </div>
          <div className="flex items-center justify-between gap-3">
            <span className="text-[var(--sg-text-muted)]">Region</span>
            <span className="font-mono text-[var(--sg-text-muted)]">{ic.region || "—"}</span>
          </div>
          <div className="flex items-center justify-between gap-3">
            <span className="text-[var(--sg-text-muted)]">Monthly</span>
            <span className="font-mono text-[var(--sg-text)]">
              {monthlyCell(ic, monthly, currency)}
            </span>
          </div>
          <div className="flex items-center justify-between gap-3">
            <span className="text-[var(--sg-text-muted)]">Hourly</span>
            <span className="font-mono text-[var(--sg-text-muted)]">
              {hourly !== null ? formatCurrency(hourly, currency) : "—"}
            </span>
          </div>
        </div>
        {isOpen && canExpand && (
          <div className="mt-3 pt-3 border-t border-[var(--sg-border-light)]">
            <ResourceDetail ic={ic} currency={currency} />
          </div>
        )}
      </div>
    );
  };

  return (
    <div className="flex flex-col gap-3">
      <div className="flex flex-wrap items-center gap-2">
        <input
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder="Filter resources…"
          className="h-8 px-2 text-sm rounded-md bg-[var(--sg-bg-1)] border border-[var(--sg-border-light)] text-[var(--sg-text)] w-full sm:w-56"
        />
        <LabeledSelect
          label="Group"
          value={groupBy}
          onChange={(v) => setGroupBy(v as GroupBy)}
          options={[
            { value: "none", label: "No grouping" },
            { value: "type", label: "By type" },
            { value: "provider", label: "By provider" },
          ]}
        />
        <LabeledSelect
          label="Sort"
          value={sortBy}
          onChange={(v) => setSortBy(v as SortBy)}
          options={[
            { value: "monthly_desc", label: "Monthly ↓" },
            { value: "hourly_desc", label: "Hourly ↓" },
            { value: "address", label: "Address" },
          ]}
        />
        <span className="text-xs text-[var(--sg-text-muted)] ml-auto">{rows.length} resources</span>
      </div>

      {/* Desktop / tablet table (lg+) */}
      <div className="hidden lg:block bg-[var(--sg-bg-1)] border border-[var(--sg-border-light)] rounded-md overflow-hidden">
        <table className="w-full text-sm">
          <thead>
            <tr className="text-[var(--sg-text-muted)] text-xs uppercase border-b border-[var(--sg-border-light)]">
              <th className="text-left px-3 py-2 font-medium">Resource</th>
              <th className="text-left px-3 py-2 font-medium">Type</th>
              <th className="text-left px-3 py-2 font-medium">Region</th>
              <th className="text-right px-3 py-2 font-medium">Monthly</th>
              <th className="text-right px-3 py-2 font-medium">Hourly</th>
              {actuals && (
                <th
                  className="text-right px-3 py-2 font-medium"
                  title={`Billed (FOCUS) spend attributed to this resource: a monthly run rate when its billed window spans at least ${MIN_COMPARE_WINDOW_DAYS} days, otherwise the raw billed sum. — means no billing line matched the resource's cloud identifiers.`}
                >
                  Actual
                </th>
              )}
            </tr>
          </thead>
          <tbody>
            {rows.length === 0 && (
              <tr>
                <td colSpan={numCols} className="px-3 py-6 text-center text-[var(--sg-text-muted)]">
                  No resources match.
                </td>
              </tr>
            )}
            {groups
              ? groups.map(([key, ics]) => (
                  <Fragment key={`g-${key}`}>
                    <tr className="bg-[var(--sg-bg-2)] border-b border-[var(--sg-border-light)]">
                      <td
                        colSpan={3}
                        className="px-3 py-1.5 text-xs uppercase tracking-wide text-[var(--sg-text-muted)]"
                      >
                        {key} · {ics.length}
                      </td>
                      <td className="px-3 py-1.5 text-right font-mono text-xs text-[var(--sg-text-muted)]">
                        {formatCurrency(groupTotal(ics), currency)}
                      </td>
                      <td />
                      {actuals && <td />}
                    </tr>
                    {ics.map((ic) => renderRow(ic))}
                  </Fragment>
                ))
              : rows.map((ic) => renderRow(ic))}
          </tbody>
        </table>
      </div>

      {/* Mobile card list (below lg) */}
      <div className="lg:hidden space-y-3">
        {rows.length === 0 && (
          <div className="rounded-lg border border-[var(--sg-border-light)] bg-[var(--sg-bg-1)] p-6 text-center text-[var(--sg-text-muted)]">
            No resources match.
          </div>
        )}
        {groups
          ? groups.map(([key, ics]) => (
              <div key={`gc-${key}`} className="space-y-3">
                <div className="flex items-center justify-between gap-3 px-1 text-xs uppercase tracking-wide text-[var(--sg-text-muted)]">
                  <span className="break-all min-w-0">
                    {key} · {ics.length}
                  </span>
                  <span className="font-mono shrink-0">{formatCurrency(groupTotal(ics), currency)}</span>
                </div>
                {ics.map((ic) => renderCard(ic))}
              </div>
            ))
          : rows.map((ic) => renderCard(ic))}
      </div>
    </div>
  );
}

function monthlyCell(ic: InstanceCost, monthly: number | null, currency: string): ReactNode {
  if (!ic.supported) return <span className="text-[var(--sg-text-dim)]">unsupported</span>;
  if (ic.no_price) return <span className="text-[var(--sg-text-dim)]">no price</span>;
  return monthly !== null ? formatCurrency(monthly, currency) : "—";
}

function actualCell(
  actual: StateCostActualResource | undefined,
  fallbackCurrency: string
): ReactNode {
  if (!actual) {
    return (
      <span
        className="text-[var(--sg-text-dim)]"
        title="No billing line matched this resource's cloud identifiers"
      >
        —
      </span>
    );
  }
  const currency = actual.currency ?? fallbackCurrency;
  const billed = parseCost(actual.billed_cost);
  const window = formatWindow(actual.window_start, actual.window_end);
  const lines = `${actual.line_count} billing line${actual.line_count === 1 ? "" : "s"}`;
  const rate = monthlyRunRate(actual.billed_cost, actual.window_start, actual.window_end);
  if (rate !== null) {
    return (
      <span
        title={`${billed !== null ? formatCurrency(billed, currency) : "?"} billed${window ? ` over ${window}` : ""} · ${lines}`}
      >
        {formatCurrency(rate, currency)}/mo
      </span>
    );
  }
  // Window too short to normalise honestly: show the billed fact, not a rate.
  return (
    <span
      className="text-[var(--sg-text-muted)]"
      title={`Billed window${window ? ` ${window}` : ""} is under ${MIN_COMPARE_WINDOW_DAYS} days — too short for a monthly run rate · ${lines}`}
    >
      {billed !== null ? `${formatCurrency(billed, currency)} billed` : "—"}
    </span>
  );
}

function compareInstance(a: InstanceCost, b: InstanceCost, sortBy: SortBy): number {
  if (sortBy === "address") return a.address.localeCompare(b.address);
  const av = parseCost(sortBy === "hourly_desc" ? a.hourly_cost : a.monthly_cost);
  const bv = parseCost(sortBy === "hourly_desc" ? b.hourly_cost : b.monthly_cost);
  if (av === null && bv === null) return a.address.localeCompare(b.address);
  if (av === null) return 1;
  if (bv === null) return -1;
  return bv - av;
}

function groupTotal(ics: InstanceCost[]): number {
  return ics.reduce((sum, ic) => sum + (parseCost(ic.monthly_cost) ?? 0), 0);
}

function formatComponentLine(c: CostComponent, currency: string): string {
  const monthly = parseCost(c.monthly_cost);
  const hourly = parseCost(c.hourly_cost);
  if (monthly !== null) {
    const qty = c.monthly_quantity ?? c.hourly_quantity;
    const qtyStr = qty ? `${qty} ${c.unit} × ${c.price} = ` : "";
    return `${c.name} · ${qtyStr}${formatCurrency(monthly, currency)}/mo`;
  }
  if (hourly !== null) {
    const qty = c.hourly_quantity;
    const qtyStr = qty ? `${qty} ${c.unit} × ${c.price} = ` : "";
    return `${c.name} · ${qtyStr}${formatCurrency(hourly, currency)}/hr`;
  }
  return `${c.name} · usage-based · not estimated`;
}

function ProviderPill({ provider }: { provider: string }) {
  return (
    <span className="inline-flex items-center px-1.5 py-0.5 rounded text-[10px] uppercase tracking-wide bg-[var(--sg-bg-2)] text-[var(--sg-text-muted)] shrink-0">
      {provider}
    </span>
  );
}

function ResourceDetail({ ic, currency }: { ic: InstanceCost; currency: string }) {
  const components = ic.components ?? [];
  const tags = ic.tags ? Object.entries(ic.tags) : [];
  return (
    <div className="flex flex-col gap-3">
      {components.length > 0 ? (
        <div className="flex flex-col gap-1">
          <div className="text-xs uppercase tracking-wide text-[var(--sg-text-muted)]">
            Cost components
          </div>
          <ul className="flex flex-col gap-0.5">
            {components.map((c, i) => (
              <li key={`${c.name}-${i}`} className="text-xs font-mono text-[var(--sg-text)]">
                {formatComponentLine(c, currency)}
              </li>
            ))}
          </ul>
        </div>
      ) : (
        <div className="text-xs text-[var(--sg-text-muted)]">No cost components.</div>
      )}
      {(tags.length > 0 || ic.cloud_resource_id) && (
        <div className="flex flex-col gap-1.5">
          {tags.length > 0 && (
            <div className="flex flex-wrap gap-1.5">
              {tags.map(([k, v]) => (
                <span
                  key={k}
                  className="inline-flex items-center px-1.5 py-0.5 rounded text-[10px] font-mono bg-[var(--sg-bg-2)] text-[var(--sg-text-muted)] break-all max-w-full"
                >
                  {k}={String(v)}
                </span>
              ))}
            </div>
          )}
          {ic.cloud_resource_id && (
            <div className="text-xs text-[var(--sg-text-dim)] font-mono break-all">
              {ic.cloud_resource_id}
            </div>
          )}
        </div>
      )}
    </div>
  );
}

function LabeledSelect({
  label,
  value,
  onChange,
  options,
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
  options: { value: string; label: string }[];
}) {
  return (
    <label className="flex items-center gap-1 text-xs text-[var(--sg-text-muted)]">
      {label}
      <select
        value={value}
        onChange={(e) => onChange(e.target.value)}
        className="h-8 px-2 text-sm rounded-md bg-[var(--sg-bg-1)] border border-[var(--sg-border-light)] text-[var(--sg-text)]"
      >
        {options.map((o) => (
          <option key={o.value} value={o.value}>
            {o.label}
          </option>
        ))}
      </select>
    </label>
  );
}
