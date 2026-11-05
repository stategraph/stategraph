"use client";

import { useId, useMemo } from "react";
import {
  CartesianGrid,
  Line,
  LineChart,
  ReferenceLine,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";

import { StateCostHistoryPoint } from "@/lib/cost/history";
import { formatCurrency, parseCost } from "@/lib/cost/format";
import { isChangeEvent, provenanceMeta } from "@/lib/cost/provenance";

interface CostHistoryChartProps {
  points: StateCostHistoryPoint[];
  height?: number;
}

interface ChartPoint {
  ts: number;
  monthly: number;
  coverage: number;
  currency: string;
  triggeredBy: string;
  label: string;
}

function formatTick(ts: number): string {
  const d = new Date(ts);
  return d.toLocaleDateString(undefined, { month: "short", day: "numeric" });
}

interface CostTooltipPayload {
  payload: ChartPoint;
}

interface CostTooltipProps {
  active?: boolean;
  payload?: CostTooltipPayload[];
}

function CostTooltip({ active, payload }: CostTooltipProps) {
  if (!active || !payload || payload.length === 0) return null;
  const point = payload[0].payload;
  return (
    <div
      style={{
        backgroundColor: "var(--sg-bg-2)",
        border: "1px solid var(--sg-border)",
        borderRadius: "6px",
        padding: "8px 12px",
        color: "var(--sg-text)",
        fontSize: "12px",
      }}
    >
      <div style={{ color: "var(--sg-text-muted)", marginBottom: "4px" }}>
        {new Date(point.ts).toLocaleString()}
      </div>
      <div style={{ fontFamily: "var(--font-mono)" }}>
        {formatCurrency(point.monthly, point.currency)} / mo
      </div>
      <div style={{ color: "var(--sg-text-muted)", marginTop: "2px" }}>
        Coverage: {point.coverage.toFixed(1)}%
      </div>
      {point.triggeredBy && (
        <div style={{ color: "var(--sg-text-muted)", marginTop: "2px" }}>
          {provenanceMeta(point.triggeredBy).label}
        </div>
      )}
    </div>
  );
}

interface DotRenderProps {
  cx?: number;
  cy?: number;
  payload?: ChartPoint;
  index?: number;
}

/** Colour points produced by an apply/actuator change (amber) vs the rest. */
function renderDot(props: DotRenderProps) {
  const { cx, cy, payload, index } = props;
  if (cx == null || cy == null || !payload) {
    return <g key={`dot-empty-${index ?? 0}`} />;
  }
  const change = isChangeEvent(payload.triggeredBy);
  return (
    <circle
      key={`dot-${payload.ts}`}
      cx={cx}
      cy={cy}
      r={change ? 4.5 : 3}
      fill={change ? "var(--sg-warning)" : "var(--sg-accent)"}
    />
  );
}

/**
 * LineChart of monthly_cost over time for a single state's cost history.
 * Snapshots caused by an apply / actuator commit are marked with a dashed
 * reference line and a highlighted dot, so a cost change can be traced to the
 * infrastructure change that drove it.
 */
export function CostHistoryChart({ points, height = 320 }: CostHistoryChartProps) {
  const data = useMemo<ChartPoint[]>(() => {
    const out: ChartPoint[] = [];
    for (const p of points) {
      const monthly = parseCost(p.monthly_cost);
      if (monthly === null) continue;
      const ts = new Date(p.calculated_at).getTime();
      if (!Number.isFinite(ts)) continue;
      out.push({
        ts,
        monthly,
        coverage: p.coverage_percent,
        currency: p.currency,
        triggeredBy: p.triggered_by,
        label: formatTick(ts),
      });
    }
    out.sort((a, b) => a.ts - b.ts);
    return out;
  }, [points]);

  const currency = data[0]?.currency ?? "USD";
  const events = useMemo(() => data.filter((d) => isChangeEvent(d.triggeredBy)), [data]);

  // Recharts renders a raw <svg> with no accessible name. Provide an
  // off-screen summary describing what the chart actually shows so screen
  // readers don't see an opaque "<image>"-like element.
  const summary = useMemo(() => {
    if (data.length === 0) return "Cost history chart: no priced snapshots in range.";
    const first = data[0];
    const last = data[data.length - 1];
    const fmt = (v: number) => formatCurrency(v, currency);
    return `Cost history chart: ${data.length} snapshot${data.length === 1 ? "" : "s"} from ${formatTick(first.ts)} (${fmt(first.monthly)}) to ${formatTick(last.ts)} (${fmt(last.monthly)}). ${events.length} change-event${events.length === 1 ? "" : "s"} highlighted.`;
  }, [data, events, currency]);
  const summaryId = useId();

  return (
    <div className="sg-fade-in" role="img" aria-describedby={summaryId}>
      <span id={summaryId} className="sr-only">
        {summary}
      </span>
      <ResponsiveContainer width="100%" height={height}>
        <LineChart data={data} margin={{ top: 16, right: 24, bottom: 8, left: 8 }}>
          <CartesianGrid strokeDasharray="3 3" stroke="var(--sg-border)" />
          <XAxis
            dataKey="ts"
            type="number"
            domain={["dataMin", "dataMax"]}
            scale="time"
            tickFormatter={formatTick}
            tick={{ fill: "var(--sg-text-muted)", fontSize: 11 }}
            stroke="var(--sg-border)"
          />
          <YAxis
            tickFormatter={(v: number) => formatCurrency(v, currency)}
            tick={{ fill: "var(--sg-text-muted)", fontSize: 11 }}
            stroke="var(--sg-border)"
            width={88}
          />
          <Tooltip content={<CostTooltip />} />
          {events.map((e) => (
            <ReferenceLine
              key={`event-${e.ts}`}
              x={e.ts}
              stroke="var(--sg-warning)"
              strokeDasharray="4 4"
              strokeOpacity={0.6}
            />
          ))}
          <Line
            type="monotone"
            dataKey="monthly"
            stroke="var(--sg-accent)"
            strokeWidth={2}
            dot={renderDot}
            activeDot={{ r: 5 }}
            animationDuration={400}
          />
        </LineChart>
      </ResponsiveContainer>
    </div>
  );
}
