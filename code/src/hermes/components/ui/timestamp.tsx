import { Clock } from 'lucide-react';

interface TimestampProps {
  date: string | Date;
  relative?: boolean;
  showIcon?: boolean;
  className?: string;
}

/**
 * Timestamp - Displays formatted date/time
 *
 * @param date - Date string or Date object
 * @param relative - Show relative time (e.g., "2 hours ago")
 * @param showIcon - Display clock icon (default false)
 */
export function Timestamp({ date, relative = false, showIcon = false, className = '' }: TimestampProps) {
  const dateObj = typeof date === 'string' ? new Date(date) : date;

  const formatted = relative
    ? getRelativeTime(dateObj)
    : dateObj.toLocaleString('en-US', {
        month: 'short',
        day: 'numeric',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
      });

  return (
    <span className={`inline-flex items-center gap-1.5 sg-data-meta ${className}`}>
      {showIcon && <Clock className="h-3 w-3" />}
      <time dateTime={dateObj.toISOString()} title={dateObj.toLocaleString()}>
        {formatted}
      </time>
    </span>
  );
}

function getRelativeTime(date: Date): string {
  const now = new Date();
  const diffMs = now.getTime() - date.getTime();
  const diffSec = Math.floor(diffMs / 1000);
  const diffMin = Math.floor(diffSec / 60);
  const diffHour = Math.floor(diffMin / 60);
  const diffDay = Math.floor(diffHour / 24);

  if (diffSec < 60) return 'just now';
  if (diffMin < 60) return `${diffMin}m ago`;
  if (diffHour < 24) return `${diffHour}h ago`;
  if (diffDay < 7) return `${diffDay}d ago`;
  if (diffDay < 30) return `${Math.floor(diffDay / 7)}w ago`;
  if (diffDay < 365) return `${Math.floor(diffDay / 30)}mo ago`;
  return `${Math.floor(diffDay / 365)}y ago`;
}
