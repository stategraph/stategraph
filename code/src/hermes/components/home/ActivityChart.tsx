"use client";

import { Bar, BarChart, CartesianGrid, ResponsiveContainer, Tooltip, XAxis, YAxis } from "recharts";
import { activityTotal, type ActivityDay } from "@/app/(console)/home/dashboard";
import { SETUP_COPY } from "@/lib/getting-started/setup-progress";

const COPY = SETUP_COPY.activity;

/** Stacked bottom to top. */
const SERIES = [
  { key: "plans", label: COPY.series.plans, color: "var(--sg-chart-plan)" },
  { key: "applies", label: COPY.series.applies, color: "var(--sg-chart-apply)" },
  { key: "failed", label: COPY.series.failed, color: "var(--sg-chart-failed)" },
] as const;

function dayLabel(start: number): string {
  return new Date(start).toLocaleDateString(undefined, { month: "short", day: "numeric" });
}

function ActivityTooltip({ active, payload }: { active?: boolean; payload?: { payload: ActivityDay }[] }) {
  if (!active || !payload || payload.length === 0) return null;
  const day = payload[0].payload;
  return (
    <div className="min-w-[140px] rounded-md border border-[var(--sg-border)] bg-[var(--sg-bg-2)] px-3 py-2 text-xs text-[var(--sg-text)]">
      <div className="mb-1 text-[var(--sg-text-muted)]">{dayLabel(day.start)}</div>
      {[...SERIES].reverse().map((s) => (
        <div key={s.key} className="flex items-center justify-between gap-3 font-mono">
          <span className="inline-flex items-center gap-1.5">
            <span className="inline-block h-2 w-2 rounded-[2px]" style={{ background: s.color }} />
            {s.label}
          </span>
          <span className="tabular-nums">{day[s.key]}</span>
        </div>
      ))}
    </div>
  );
}

/** Plans, applies and failures per day over the last ACTIVITY_DAYS days. */
export function ActivityChart({ days }: { days: ActivityDay[] }) {
  const total = activityTotal(days);
  const failed = days.reduce((sum, d) => sum + d.failed, 0);

  return (
    <div className="rounded-lg border border-[var(--sg-border)] bg-[var(--sg-bg-1)] px-4 py-3">
      <div className="mb-2 flex flex-wrap items-baseline justify-between gap-x-4 gap-y-1">
        <div className="text-sm font-medium text-[var(--sg-text)]">
          {COPY.chartTitle} <span className="font-normal text-[var(--sg-text-muted)]">· {COPY.chartRange}</span>
        </div>
        {total > 0 ? (
          <ul className="flex flex-wrap items-center gap-x-3 gap-y-1 text-xs text-[var(--sg-text-muted)]">
            {SERIES.map((s) => (
              <li key={s.key} className="inline-flex items-center gap-1.5">
                <span aria-hidden="true" className="inline-block h-2.5 w-2.5 rounded-[2px]" style={{ background: s.color }} />
                {s.label}
              </li>
            ))}
          </ul>
        ) : null}
      </div>
      {total === 0 ? (
        <p className="py-8 text-center text-sm text-[var(--sg-text-muted)]">{COPY.chartEmpty}</p>
      ) : (
        <div role="img" aria-label={COPY.summary(total, failed)}>
          <ResponsiveContainer width="100%" height={180}>
            <BarChart data={days} margin={{ top: 4, right: 0, bottom: 0, left: 0 }} barCategoryGap="18%">
              <CartesianGrid vertical={false} stroke="var(--sg-border)" strokeDasharray="3 3" />
              <XAxis
                dataKey="start"
                tickFormatter={dayLabel}
                tick={{ fill: "var(--sg-text-muted)", fontSize: 11 }}
                stroke="var(--sg-border)"
                tickLine={false}
                interval="preserveStartEnd"
                minTickGap={12}
              />
              <YAxis
                allowDecimals={false}
                width={32}
                tick={{ fill: "var(--sg-text-muted)", fontSize: 11 }}
                axisLine={false}
                tickLine={false}
              />
              <Tooltip content={<ActivityTooltip />} cursor={{ fill: "var(--sg-bg-2)" }} />
              {SERIES.map((s) => (
                <Bar
                  key={s.key}
                  dataKey={s.key}
                  name={s.label}
                  stackId="runs"
                  fill={s.color}
                  stroke="var(--sg-bg-1)"
                  strokeWidth={1}
                  isAnimationActive={false}
                />
              ))}
            </BarChart>
          </ResponsiveContainer>
        </div>
      )}
    </div>
  );
}
