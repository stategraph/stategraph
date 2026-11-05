import { TrendingUp, TrendingDown, Minus } from 'lucide-react';

interface DeltaIndicatorProps {
  value: number;
  showIcon?: boolean;
  size?: 'sm' | 'md';
}

/**
 * DeltaIndicator - Shows change in value with color and icon
 *
 * @param value - Change value (positive/negative/zero)
 * @param showIcon - Display trend icon (default true)
 * @param size - Size variant (default 'sm')
 */
export function DeltaIndicator({ value, showIcon = true, size = 'sm' }: DeltaIndicatorProps) {
  const isPositive = value > 0;
  const isNegative = value < 0;
  const isZero = value === 0;

  const color = isPositive
    ? 'text-[var(--sg-success)]'
    : isNegative
    ? 'text-[var(--sg-error)]'
    : 'text-[var(--sg-text-dim)]';

  const Icon = isPositive ? TrendingUp : isNegative ? TrendingDown : Minus;
  const iconSize = size === 'sm' ? 'h-3 w-3' : 'h-4 w-4';
  const textSize = size === 'sm' ? 'text-xs' : 'text-sm';

  const displayValue = isZero ? '0' : `${isPositive ? '+' : ''}${value}`;

  return (
    <span className={`inline-flex items-center gap-1 sg-numeric-value ${color} ${textSize}`}>
      {showIcon && <Icon className={iconSize} />}
      {displayValue}
    </span>
  );
}
