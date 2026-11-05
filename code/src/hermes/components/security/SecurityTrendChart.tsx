"use client";

import { useId, useMemo } from "react";
import {
  Area,
  AreaChart,
  CartesianGrid,
  Legend,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";

import type { TenantSecurityBreakdownEntry } from "@/lib/api/client";

/** Which breakdown the chart stacks. */
export type SecurityDimension = "severity" | "blast";

interface Series {
  /** Key in the per-day row / data key for the <Area>. */
  key: string;
  label: string;
  color: string;
}

/**
 * Severity series, most-severe first. Colors track the SeverityBadge palette
 * (critical red → info slate); unknown uses a concrete grey so it renders in
 * the SVG fill. Kept most-severe-first here; the stack is drawn in reverse so
 * critical sits on top.
 */
const SEVERITY_SERIES: Series[] = [
  { key: "critical", label: "Critical", color: "#dc2626" },
  { key: "high", label: "High", color: "#ea580c" },
  { key: "medium", label: "Medium", color: "#ca8a04" },
  { key: "low", label: "Low", color: "#2563eb" },
  { key: "info", label: "Info", color: "#64748b" },
  { key: "unknown", label: "Unknown", color: "#94a3b8" },
];

/** Blast-impact series, largest-impact first (high blast on top of the stack). */
const BLAST_SERIES: Series[] = [
  { key: "high", label: "High blast", color: "#dc2626" },
  { key: "medium", label: "Medium blast", color: "#f97316" },
  { key: "low", label: "Low blast", color: "#eab308" },
];

interface ChartRow {
  ts: number;
  [series: string]: number;
}

function pointTs(date: string): number {
  // `date` is an ISO date (YYYY-MM-DD); treat as UTC midnight so day-buckets
  // line up regardless of viewer timezone.
  return new Date(`${date}T00:00:00Z`).getTime();
}

function formatDateTick(ts: number): string {
  return new Date(ts).toLocaleDateString(undefined, { month: "short", day: "numeric" });
}

/** Severity counts are an object of optional ints; read one bucket safely. */
function severityCount(entry: TenantSecurityBreakdownEntry, key: string): number {
  const rec = entry.severity_breakdown as Record<string, number | undefined>;
  return rec[key] ?? 0;
}

function blastCount(entry: TenantSecurityBreakdownEntry, bucket: string): number {
  return entry.blast_breakdown.find((b) => b.bucket === bucket)?.count ?? 0;
}

function buildRows(
  points: TenantSecurityBreakdownEntry[],
  series: Series[],
  valueFor: (entry: TenantSecurityBreakdownEntry, key: string) => number
): ChartRow[] {
  const out: ChartRow[] = [];
  for (const p of points) {
    const ts = pointTs(p.date);
    if (!Number.isFinite(ts)) continue;
    const row: ChartRow = { ts };
    for (const s of series) row[s.key] = valueFor(p, s.key);
    out.push(row);
  }
  out.sort((a, b) => a.ts - b.ts);
  return out;
}

interface SecurityTooltipProps {
  active?: boolean;
  payload?: { payload: ChartRow }[];
  series: Series[];
}

function SecurityTooltip({ active, payload, series }: SecurityTooltipProps) {
  if (!active || !payload || payload.length === 0) return null;
  const row = payload[0].payload;
  const entries = series
    .map((s) => ({ label: s.label, value: row[s.key] ?? 0, color: s.color }))
    .filter((e) => e.value > 0);
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
        {new Date(row.ts).toLocaleDateString(undefined, {
          year: "numeric",
          month: "short",
          day: "numeric",
        })}
      </div>
      {entries.length === 0 && <div style={{ color: "var(--sg-text-muted)" }}>No findings</div>}
      {entries.map((e) => (
        <div
          key={e.label}
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
            {e.label}
          </span>
          <span>{e.value}</span>
        </div>
      ))}
      {entries.length > 1 && (
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
          <span>{total}</span>
        </div>
      )}
    </div>
  );
}

export interface SecurityTrendChartProps {
  points: TenantSecurityBreakdownEntry[];
  dimension: SecurityDimension;
  height?: number;
}

/**
 * Tenant security posture over time as a stacked area, one band per
 * severity (critical → unknown) or per blast-impact bucket (high / medium /
 * low). Sibling to {@link TenantCostHistoryChart}; counts rather than currency.
 * The most-significant band is drawn on top of the stack.
 */
export function SecurityTrendChart({ points, dimension, height = 320 }: SecurityTrendChartProps) {
  const series = dimension === "severity" ? SEVERITY_SERIES : BLAST_SERIES;
  const valueFor = dimension === "severity" ? severityCount : blastCount;
  const data = useMemo(() => buildRows(points, series, valueFor), [points, series, valueFor]);

  // Off-screen description so screen readers get something meaningful on the
  // raw <svg>.
  const summaryId = useId();
  const summary = useMemo(() => {
    if (data.length === 0) return "Tenant security history chart: no data in range.";
    const first = data[0].ts;
    const last = data[data.length - 1].ts;
    return `Tenant security history chart, findings stacked by ${dimension}, ${data.length} day${data.length === 1 ? "" : "s"} from ${formatDateTick(first)} to ${formatDateTick(last)}.`;
  }, [data, dimension]);

  return (
    <div className="sg-fade-in" role="img" aria-describedby={summaryId}>
      <span id={summaryId} className="sr-only">
        {summary}
      </span>
      <ResponsiveContainer width="100%" height={height}>
        <AreaChart data={data} margin={{ top: 16, right: 24, bottom: 8, left: 8 }}>
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
            allowDecimals={false}
            tick={{ fill: "var(--sg-text-muted)", fontSize: 11 }}
            stroke="var(--sg-border)"
            width={48}
          />
          <Tooltip content={<SecurityTooltip series={series} />} />
          <Legend
            wrapperStyle={{ fontSize: 12, color: "var(--sg-text-muted)" }}
            iconType="square"
          />
          {/* Reverse so the most-significant series renders last (on top). */}
          {[...series].reverse().map((s) => (
            <Area
              key={s.key}
              type="monotone"
              dataKey={s.key}
              name={s.label}
              stackId="1"
              stroke={s.color}
              fill={s.color}
              fillOpacity={0.55}
              strokeWidth={1}
              animationDuration={400}
            />
          ))}
        </AreaChart>
      </ResponsiveContainer>
    </div>
  );
}
