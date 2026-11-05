"use client";

import { PieChart, Pie, Cell, ResponsiveContainer, Tooltip } from 'recharts';

interface ProviderBreakdownProps {
  data: Record<string, number>;
  height?: number;
}

const COLORS = [
  'var(--sg-accent)',
  '#10b981',
  '#f59e0b',
  '#ef4444',
  '#8b5cf6',
  '#ec4899',
  '#06b6d4',
  '#84cc16',
];

/**
 * ProviderBreakdown - Pie chart showing resource distribution by provider
 */
export function ProviderBreakdown({ data, height = 200 }: ProviderBreakdownProps) {
  const chartData = Object.entries(data)
    .map(([name, value]) => ({ name, value }))
    .sort((a, b) => b.value - a.value);

  if (chartData.length === 0) {
    return (
      <div className="flex items-center justify-center h-full sg-metadata">
        No provider data available
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-3 sg-fade-in">
      <ResponsiveContainer width="100%" height={height}>
        <PieChart>
          <Pie
            data={chartData}
            cx="50%"
            cy="50%"
            innerRadius={50}
            outerRadius={80}
            paddingAngle={2}
            dataKey="value"
            animationDuration={500}
          >
            {chartData.map((entry, index) => (
              <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
            ))}
          </Pie>
          <Tooltip
            contentStyle={{
              backgroundColor: 'var(--sg-bg-2)',
              border: '1px solid var(--sg-border)',
              borderRadius: '6px',
              padding: '8px 12px',
              color: 'var(--sg-text)',
            }}
            itemStyle={{ color: 'var(--sg-text)' }}
          />
        </PieChart>
      </ResponsiveContainer>

      {/* Legend */}
      <div className="grid grid-cols-2 gap-2">
        {chartData.slice(0, 6).map((entry, index) => (
          <div key={entry.name} className="flex items-center gap-2 sg-metadata">
            <div
              className="w-3 h-3 rounded-sm flex-shrink-0"
              style={{ backgroundColor: COLORS[index % COLORS.length] }}
            />
            <span className="text-[var(--sg-text)] truncate flex-1 font-medium">{entry.name}</span>
            <span className="text-[var(--sg-text-muted)] font-mono sg-numeric-value">
              {entry.value}
            </span>
          </div>
        ))}
        {chartData.length > 6 && (
          <div className="col-span-2 sg-metadata text-center pt-1">
            +{chartData.length - 6} more
          </div>
        )}
      </div>
    </div>
  );
}
