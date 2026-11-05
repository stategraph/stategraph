"use client";

import { LineChart, Line, ResponsiveContainer } from 'recharts';

interface SparklineProps {
  data: number[];
  color?: string;
  height?: number;
  strokeWidth?: number;
}

/**
 * Sparkline - Tiny inline chart showing trend
 *
 * @param data - Array of numeric values
 * @param color - Line color (defaults to accent)
 * @param height - Height in pixels (default 32)
 * @param strokeWidth - Line thickness (default 1.5)
 */
export function Sparkline({
  data,
  color = 'var(--sg-accent)',
  height = 32,
  strokeWidth = 1.5
}: SparklineProps) {
  // Transform data into format Recharts expects
  const chartData = data.map((value, index) => ({ value, index }));

  return (
    <div className="sg-fade-in">
      <ResponsiveContainer width="100%" height={height}>
        <LineChart data={chartData}>
          <Line
            type="monotone"
            dataKey="value"
            stroke={color}
            strokeWidth={strokeWidth}
            dot={false}
            animationDuration={300}
          />
        </LineChart>
      </ResponsiveContainer>
    </div>
  );
}
