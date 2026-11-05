import { LucideIcon } from 'lucide-react';

export interface MetricCardProps {
  /** Label displayed above the value */
  label: string;

  /** The metric value - can be number, string, or undefined */
  value: string | number | undefined | null;

  /** Optional subtitle/description below the value */
  subtitle?: string;

  /** Optional icon to display */
  icon?: LucideIcon;

  /** Loading state */
  isLoading?: boolean;

  /** Error state */
  isError?: boolean;

  /** Dimmed state for "coming soon" features */
  dimmed?: boolean;

  /** Optional click handler for navigation */
  onClick?: () => void;
}

export function MetricCard({
  label,
  value,
  subtitle,
  icon: Icon,
  isLoading,
  isError,
  dimmed,
  onClick,
}: MetricCardProps) {
  // Determine what to display
  const displayValue = getDisplayValue(value, isError);
  const isEmpty = value === 0 || value === '0';
  const isClickable = !!onClick && !isLoading && !isError;

  return (
    <div
      className={`bg-[var(--sg-bg-1)] border border-[var(--sg-border)] rounded-lg overflow-hidden transition-colors duration-150 ${
        dimmed ? 'opacity-60' : ''
      } ${
        isClickable ? 'cursor-pointer hover:border-[var(--sg-accent)]' : ''
      }`}
      style={{
        boxShadow: 'var(--sg-shadow-sm)'
      }}
      onClick={isClickable ? onClick : undefined}
    >
      {/* Header with deeper contrast */}
      <div className="flex items-center justify-between px-3 py-2 bg-[var(--sg-bg-0)] border-b border-[var(--sg-border)]">
        <div className="flex items-center gap-1.5">
          {Icon && <Icon className="w-3.5 h-3.5 text-[var(--sg-text-muted)]" />}
          <div className="sg-metadata font-medium text-[var(--sg-text-muted)]">{label}</div>
        </div>
      </div>

      {/* Content */}
      <div className="p-3">
        {/* Value */}
        {isLoading ? (
          <div className="h-7 w-20 sg-skeleton-shimmer"></div>
        ) : (
          <div
            className={`text-2xl sg-numeric-value ${
              isError
                ? 'text-[var(--sg-error)]'
                : isEmpty
                ? 'text-[var(--sg-text-dim)]'
                : 'text-[var(--sg-text)]'
            }`}
          >
            {displayValue}
          </div>
        )}

        {/* Subtitle or empty state message */}
        {!isLoading && (
          <div className="sg-metadata mt-1.5">
            {isError ? (
              <span className="text-[var(--sg-error)]">Failed to load</span>
            ) : isEmpty && !subtitle ? (
              <span>No data yet</span>
            ) : subtitle ? (
              subtitle
            ) : isClickable ? (
              <span className="text-[var(--sg-accent)]">Click to explore →</span>
            ) : null}
          </div>
        )}
      </div>
    </div>
  );
}

/**
 * Determines what value to display based on state
 */
function getDisplayValue(
  value: string | number | undefined | null,
  isError?: boolean
): string {
  if (isError) {
    return '--';
  }

  if (value === undefined || value === null) {
    return 'Not available';
  }

  if (typeof value === 'number') {
    return value.toLocaleString();
  }

  return value;
}
