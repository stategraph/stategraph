"use client";

import {
  BarChart,
  Bar,
  PieChart,
  Pie,
  Treemap,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  Cell,
  ResponsiveContainer,
} from 'recharts';
import type { ChartDataPoint, ChartType } from './analyticsUtils';

interface AnalyticsChartProps {
  chartType: ChartType;
  data: ChartDataPoint[];
  dimensionField: string;
  metricField: string;
}

// Color palette for charts
const COLORS = [
  '#60a5fa', // Accent blue
  '#34d399', // Green
  '#fbbf24', // Yellow
  '#f87171', // Red
  '#a78bfa', // Purple
  '#fb923c', // Orange
  '#4ade80', // Light green
  '#38bdf8', // Sky blue
  '#c084fc', // Light purple
  '#fb7185', // Pink
];

/**
 * Custom label for pie chart
 * Recharts provides these props to the label render function
 */
interface PieLabelProps {
  cx?: number;
  cy?: number;
  midAngle?: number;
  innerRadius?: number;
  outerRadius?: number;
  percent?: number;
  index?: number;
  name?: string;
  value?: number;
}

const renderPieLabel = (props: PieLabelProps) => {
  const percent = ((props.percent || 0) * 100).toFixed(0);
  return `${props.name || ''}: ${percent}%`;
};

/**
 * Custom content for treemap
 * Recharts provides these props when rendering
 */
interface TreemapContentProps {
  x?: number;
  y?: number;
  width?: number;
  height?: number;
  index?: number;
  dimension?: string;
  count?: number;
}

const TreemapContent = (props: TreemapContentProps) => {
  const { x = 0, y = 0, width = 0, height = 0, index = 0, dimension = '', count = 0 } = props;

  if (width < 50 || height < 30) {
    // Too small to render text
    return (
      <g>
        <rect
          x={x}
          y={y}
          width={width}
          height={height}
          fill={COLORS[index % COLORS.length]}
          stroke="var(--sg-border)"
          strokeWidth={2}
        />
      </g>
    );
  }

  return (
    <g>
      <rect
        x={x}
        y={y}
        width={width}
        height={height}
        fill={COLORS[index % COLORS.length]}
        stroke="var(--sg-border)"
        strokeWidth={2}
      />
      <text
        x={x + width / 2}
        y={y + height / 2 - 7}
        textAnchor="middle"
        fill="white"
        fontSize={12}
        fontWeight="bold"
      >
        {dimension}
      </text>
      <text
        x={x + width / 2}
        y={y + height / 2 + 9}
        textAnchor="middle"
        fill="white"
        fontSize={11}
      >
        {count}
      </text>
    </g>
  );
};

/**
 * AnalyticsChart Component
 * Renders different chart types using Recharts
 */
export function AnalyticsChart({
  chartType,
  data,
  dimensionField: _dimensionField,
  metricField: _metricField,
}: AnalyticsChartProps) {
  // Empty state
  if (!data || data.length === 0) {
    return (
      <div className="flex items-center justify-center h-[400px] bg-[var(--sg-bg-1)] border border-[var(--sg-border)] rounded-lg">
        <div className="text-center">
          <div className="text-lg font-semibold text-[var(--sg-text)] mb-2">No Data</div>
          <div className="text-sm text-[var(--sg-text-muted)]">
            No results available to visualize
          </div>
        </div>
      </div>
    );
  }

  // Render based on chart type
  switch (chartType) {
    case 'bar':
      return (
        <div className="h-[400px] w-full">
          <ResponsiveContainer width="100%" height="100%">
            <BarChart
              data={data}
              margin={{ top: 20, right: 30, left: 20, bottom: 60 }}
            >
              <CartesianGrid strokeDasharray="3 3" stroke="var(--sg-border)" />
              <XAxis
                dataKey="dimension"
                angle={-45}
                textAnchor="end"
                height={80}
                tick={{ fill: 'var(--sg-text-muted)', fontSize: 11 }}
              />
              <YAxis tick={{ fill: 'var(--sg-text-muted)', fontSize: 11 }} />
              <Tooltip
                contentStyle={{
                  backgroundColor: 'var(--sg-bg-2)',
                  border: '1px solid var(--sg-border)',
                  borderRadius: '8px',
                  color: 'var(--sg-text)',
                }}
                labelStyle={{ color: 'var(--sg-text)' }}
              />
              <Legend wrapperStyle={{ color: 'var(--sg-text-muted)' }} />
              <Bar dataKey="count" fill="#60a5fa" name="Count">
                {data.map((entry, index) => (
                  <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                ))}
              </Bar>
            </BarChart>
          </ResponsiveContainer>
        </div>
      );

    case 'pie':
      return (
        <div className="h-[400px] w-full">
          <ResponsiveContainer width="100%" height="100%">
            <PieChart>
              <Pie
                data={data}
                dataKey="count"
                nameKey="dimension"
                cx="50%"
                cy="50%"
                outerRadius={120}
                label={renderPieLabel}
                labelLine={{ stroke: 'var(--sg-text-muted)' }}
              >
                {data.map((entry, index) => (
                  <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                ))}
              </Pie>
              <Tooltip
                contentStyle={{
                  backgroundColor: 'var(--sg-bg-2)',
                  border: '1px solid var(--sg-border)',
                  borderRadius: '8px',
                  color: 'var(--sg-text)',
                }}
              />
              <Legend
                wrapperStyle={{ color: 'var(--sg-text-muted)' }}
                iconType="circle"
              />
            </PieChart>
          </ResponsiveContainer>
        </div>
      );

    case 'treemap':
      return (
        <div className="h-[400px] w-full">
          <ResponsiveContainer width="100%" height="100%">
            <Treemap
              data={data}
              dataKey="count"
              aspectRatio={4 / 3}
              stroke="var(--sg-border)"
              content={<TreemapContent />}
            >
              <Tooltip
                contentStyle={{
                  backgroundColor: 'var(--sg-bg-2)',
                  border: '1px solid var(--sg-border)',
                  borderRadius: '8px',
                  color: 'var(--sg-text)',
                }}
              />
            </Treemap>
          </ResponsiveContainer>
        </div>
      );

    default:
      return (
        <div className="flex items-center justify-center h-[400px] bg-[var(--sg-bg-1)] border border-[var(--sg-border)] rounded-lg">
          <div className="text-center">
            <div className="text-lg font-semibold text-[var(--sg-text)] mb-2">
              Unsupported Chart Type
            </div>
            <div className="text-sm text-[var(--sg-text-muted)]">
              Chart type &ldquo;{chartType}&rdquo; is not supported
            </div>
          </div>
        </div>
      );
  }
}
