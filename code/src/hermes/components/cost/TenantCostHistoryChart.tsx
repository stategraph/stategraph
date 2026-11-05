"use client";

import { useId, useMemo } from "react";
import {
  Area,
  AreaChart,
  CartesianGrid,
  Line,
  LineChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";

import { TenantCostHistoryPoint } from "@/lib/api/client";
import { formatCurrency, parseCost } from "@/lib/cost/format";

/**
 * Tenant cost over time. Sibling to {@link CostHistoryChart} (per-state).
 *
 * Two display modes:
 *  - Total: a single line of monthly cost per day.
 *  - Grouped: a stacked area, one band per group (provider / resource type /
 *    tag value), driven by the per-point `groups` the backend returns when
 *    the caller passed `?group_by`.
 *
 * In grouped mode we keep the chart legible by drawing the top
 * {@link MAX_GROUP_SERIES} bands and lumping the rest into "Other".
 */
export interface TenantCostHistoryChartProps {
  points: TenantCostHistoryPoint[];
  /** If true and points carry `groups`, render the stacked-area mode. */
  grouped: boolean;
  /** Currency string used to format axis ticks + tooltip values. */
  currency: string;
  height?: number;
}

const MAX_GROUP_SERIES = 7;

/** A small fixed palette; index modulo length to handle the rare overflow. */
const PALETTE = [
  "var(--sg-accent)",
  "#f97316",
  "#22c55e",
  "#a855f7",
  "#eab308",
  "#06b6d4",
  "#ef4444",
];
const OTHER_COLOR = "#a3a3a3";
const OTHER_LABEL = "Other";

interface TotalPoint {
  ts: number;
  monthly: number;
}

interface GroupedPoint {
  ts: number;
  /** One entry per series name, costs in JS number form for stacking math. */
  [seriesName: string]: number;
}

function pointTs(p: TenantCostHistoryPoint): number {
  // `date` is an ISO date (YYYY-MM-DD); treat as UTC midnight so day-buckets
  // line up regardless of viewer timezone.
  return new Date(`${p.date}T00:00:00Z`).getTime();
}

function formatDateTick(ts: number): string {
  return new Date(ts).toLocaleDateString(undefined, { month: "short", day: "numeric" });
}

function buildTotal(points: TenantCostHistoryPoint[]): TotalPoint[] {
  const out: TotalPoint[] = [];
  for (const p of points) {
    const monthly = parseCost(p.monthly_cost);
    if (monthly === null) continue;
    const ts = pointTs(p);
    if (!Number.isFinite(ts)) continue;
    out.push({ ts, monthly });
  }
  out.sort((a, b) => a.ts - b.ts);
  return out;
}

/**
 * Pivot the grouped points into a per-day record keyed by series name, and
 * pick the top {@link MAX_GROUP_SERIES} series by total cost so the chart
 * stays readable.
 */
function buildGrouped(points: TenantCostHistoryPoint[]): {
  data: GroupedPoint[];
  seriesNames: string[];
} {
  // First pass: total cost per series name (for top-N selection).
  const totalByName = new Map<string, number>();
  for (const p of points) {
    for (const g of p.groups) {
      const cost = parseCost(g.monthly_cost);
      if (cost === null) continue;
      totalByName.set(g.name, (totalByName.get(g.name) ?? 0) + cost);
    }
  }
  const ranked = [...totalByName.entries()].sort((a, b) => b[1] - a[1]);
  const topNames = new Set(ranked.slice(0, MAX_GROUP_SERIES).map(([name]) => name));
  const hasOther = ranked.length > MAX_GROUP_SERIES;
  const seriesNames = [...topNames];
  if (hasOther) seriesNames.push(OTHER_LABEL);

  // Second pass: per-day point.
  const data: GroupedPoint[] = [];
  for (const p of points) {
    const ts = pointTs(p);
    if (!Number.isFinite(ts)) continue;
    const row: GroupedPoint = { ts } as GroupedPoint;
    for (const name of seriesNames) row[name] = 0;
    for (const g of p.groups) {
      const cost = parseCost(g.monthly_cost);
      if (cost === null) continue;
      if (topNames.has(g.name)) {
        row[g.name] = (row[g.name] ?? 0) + cost;
      } else if (hasOther) {
        row[OTHER_LABEL] = (row[OTHER_LABEL] ?? 0) + cost;
      }
    }
    data.push(row);
  }
  data.sort((a, b) => a.ts - b.ts);
  return { data, seriesNames };
}

interface TooltipEntry {
  name: string;
  value: number;
  color: string;
}

interface CostTooltipProps {
  active?: boolean;
  payload?: { payload: TotalPoint | GroupedPoint; name: string; value: number; color: string }[];
  currency: string;
  mode: "total" | "grouped";
}

function CostTooltip({ active, payload, currency, mode }: CostTooltipProps) {
  if (!active || !payload || payload.length === 0) return null;
  const ts = (payload[0].payload as { ts: number }).ts;
  const entries: TooltipEntry[] =
    mode === "total"
      ? [{ name: "Monthly", value: (payload[0].payload as TotalPoint).monthly, color: payload[0].color }]
      : // Largest band on top of the tooltip list.
        payload
          .map((p) => ({ name: p.name, value: p.value, color: p.color }))
          .filter((e) => e.value > 0)
          .sort((a, b) => b.value - a.value);
  const total = entries.reduce((sum, e) => sum + e.value, 0);
  return (
    <div
      style={{
        backgroundColor: "var(--sg-bg-2)",
        border: "1px solid var(--sg-border)",
        borderRadius: "6px",
        padding: "8px 12px",
        color: "var(--sg-text)",
        fontSize: "12px",
        minWidth: 160,
      }}
    >
      <div style={{ color: "var(--sg-text-muted)", marginBottom: "4px" }}>
        {new Date(ts).toLocaleDateString(undefined, {
          year: "numeric",
          month: "short",
          day: "numeric",
        })}
      </div>
      {entries.map((e) => (
        <div
          key={e.name}
          style={{
            display: "flex",
            justifyContent: "space-between",
            gap: 12,
            fontFamily: "var(--font-mono)",
          }}
        >
          <span style={{ display: "inline-flex", alignItems: "center", gap: 6 }}>
            <span
              style={{
                display: "inline-block",
                width: 8,
                height: 8,
                borderRadius: 2,
                background: e.color,
              }}
            />
            {e.name}
          </span>
          <span>{formatCurrency(e.value, currency)}</span>
        </div>
      ))}
      {mode === "grouped" && entries.length > 1 && (
        <div
          style={{
            display: "flex",
            justifyContent: "space-between",
            gap: 12,
            borderTop: "1px solid var(--sg-border)",
            marginTop: 6,
            paddingTop: 6,
            fontFamily: "var(--font-mono)",
          }}
        >
          <span>Total</span>
          <span>{formatCurrency(total, currency)}</span>
        </div>
      )}
    </div>
  );
}

export function TenantCostHistoryChart({
  points,
  grouped,
  currency,
  height = 320,
}: TenantCostHistoryChartProps) {
  const totalData = useMemo(() => buildTotal(points), [points]);
  const { data: groupedData, seriesNames } = useMemo(() => buildGrouped(points), [points]);

  // Off-screen description so screen readers see something meaningful when
  // they land on the chart's raw <svg>.
  const summaryId = useId();
  const summary = useMemo(() => {
    const days = grouped ? groupedData.length : totalData.length;
    if (days === 0) {
      return "Tenant cost history chart: no priced days in range.";
    }
    if (grouped) {
      const first = groupedData[0]?.ts;
      const last = groupedData[groupedData.length - 1]?.ts;
      return `Tenant cost history chart, stacked by ${seriesNames.length} group${seriesNames.length === 1 ? "" : "s"} (${seriesNames.join(", ")}), ${days} day${days === 1 ? "" : "s"} from ${formatDateTick(first)} to ${formatDateTick(last)}.`;
    }
    const first = totalData[0];
    const last = totalData[totalData.length - 1];
    const fmt = (v: number) => formatCurrency(v, currency);
    return `Tenant cost history chart, total monthly cost over ${days} day${days === 1 ? "" : "s"}, from ${formatDateTick(first.ts)} (${fmt(first.monthly)}) to ${formatDateTick(last.ts)} (${fmt(last.monthly)}).`;
  }, [grouped, groupedData, totalData, seriesNames, currency]);

  if (grouped) {
    return (
      <div className="sg-fade-in" role="img" aria-describedby={summaryId}>
        <span id={summaryId} className="sr-only">
          {summary}
        </span>
        <ResponsiveContainer width="100%" height={height}>
          <AreaChart data={groupedData} margin={{ top: 16, right: 24, bottom: 8, left: 8 }}>
            <CartesianGrid strokeDasharray="3 3" stroke="var(--sg-border)" />
            <XAxis
              dataKey="ts"
              type="number"
              domain={["dataMin", "dataMax"]}
              scale="time"
              tickFormatter={formatDateTick}
              tick={{ fill: "var(--sg-text-muted)", fontSize: 11 }}
              stroke="var(--sg-border)"
            />
            <YAxis
              tickFormatter={(v: number) => formatCurrency(v, currency)}
              tick={{ fill: "var(--sg-text-muted)", fontSize: 11 }}
              stroke="var(--sg-border)"
              width={88}
            />
            <Tooltip content={<CostTooltip currency={currency} mode="grouped" />} />
            {seriesNames.map((name, idx) => {
              const color =
                name === OTHER_LABEL ? OTHER_COLOR : PALETTE[idx % PALETTE.length];
              return (
                <Area
                  key={name}
                  type="monotone"
                  dataKey={name}
                  stackId="1"
                  stroke={color}
                  fill={color}
                  fillOpacity={0.55}
                  strokeWidth={1}
                  animationDuration={400}
                />
              );
            })}
          </AreaChart>
        </ResponsiveContainer>
      </div>
    );
  }

  return (
    <div className="sg-fade-in" role="img" aria-describedby={summaryId}>
      <span id={summaryId} className="sr-only">
        {summary}
      </span>
      <ResponsiveContainer width="100%" height={height}>
        <LineChart data={totalData} margin={{ top: 16, right: 24, bottom: 8, left: 8 }}>
          <CartesianGrid strokeDasharray="3 3" stroke="var(--sg-border)" />
          <XAxis
            dataKey="ts"
            type="number"
            domain={["dataMin", "dataMax"]}
            scale="time"
            tickFormatter={formatDateTick}
            tick={{ fill: "var(--sg-text-muted)", fontSize: 11 }}
            stroke="var(--sg-border)"
          />
          <YAxis
            tickFormatter={(v: number) => formatCurrency(v, currency)}
            tick={{ fill: "var(--sg-text-muted)", fontSize: 11 }}
            stroke="var(--sg-border)"
            width={88}
          />
          <Tooltip content={<CostTooltip currency={currency} mode="total" />} />
          <Line
            type="monotone"
            dataKey="monthly"
            stroke="var(--sg-accent)"
            strokeWidth={2}
            dot={{ r: 3, fill: "var(--sg-accent)" }}
            activeDot={{ r: 5 }}
            animationDuration={400}
          />
        </LineChart>
      </ResponsiveContainer>
    </div>
  );
}
