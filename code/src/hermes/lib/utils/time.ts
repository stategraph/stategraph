/**
 * Time formatting utilities for Activity timeline
 */

/**
 * Format a timestamp as relative time (e.g., "12 minutes ago")
 * Never displays raw seconds - shows "Just now" for recent events
 * Handles edge cases like future timestamps and invalid dates
 */
export function formatRelativeTime(timestamp: string): string {
  const date = new Date(timestamp);
  const now = new Date();

  // Handle invalid dates
  if (isNaN(date.getTime())) {
    return 'Unknown time';
  }

  let seconds = Math.floor((now.getTime() - date.getTime()) / 1000);

  // Handle clock skew: if timestamp is in "future" by reasonable amount,
  // treat it as clock desync and use absolute value
  if (seconds < 0) {
    const secondsInFuture = Math.abs(seconds);

    if (secondsInFuture > 3600) {
      // More than 1 hour in future - likely bad data
      return 'Clock sync issue';
    }

    // Clock skew within 1 hour - use absolute value
    // This handles dev environments where client clock is behind server
    seconds = secondsInFuture;
  }

  // Under 1 minute
  if (seconds < 60) {
    return 'Just now';
  }

  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) {
    return `${minutes} minute${minutes !== 1 ? 's' : ''} ago`;
  }

  const hours = Math.floor(minutes / 60);
  if (hours < 24) {
    return `${hours} hour${hours !== 1 ? 's' : ''} ago`;
  }

  const days = Math.floor(hours / 24);
  if (days < 30) {
    return `${days} day${days !== 1 ? 's' : ''} ago`;
  }

  const months = Math.floor(days / 30);
  if (months < 12) {
    return `${months} month${months !== 1 ? 's' : ''} ago`;
  }

  const years = Math.floor(months / 12);
  return `${years} year${years !== 1 ? 's' : ''} ago`;
}

/**
 * Format a timestamp as absolute date/time
 * Example: "Dec 15, 2025 at 2:30 PM"
 */
export function formatAbsoluteTime(timestamp: string): string {
  const date = new Date(timestamp);

  const dateStr = date.toLocaleDateString('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  });

  const timeStr = date.toLocaleTimeString('en-US', {
    hour: 'numeric',
    minute: '2-digit',
    hour12: true,
  });

  return `${dateStr} at ${timeStr}`;
}

/**
 * Calculate duration between two timestamps in human-readable format
 * Example: "2 minutes 30 seconds"
 */
export function formatDuration(startTime: string, endTime?: string): string {
  const start = new Date(startTime);
  const end = endTime ? new Date(endTime) : new Date();
  const seconds = Math.floor((end.getTime() - start.getTime()) / 1000);

  if (seconds < 60) {
    return `${seconds}s`;
  }

  const minutes = Math.floor(seconds / 60);
  const remainingSeconds = seconds % 60;

  if (minutes < 60) {
    return remainingSeconds > 0
      ? `${minutes}m ${remainingSeconds}s`
      : `${minutes}m`;
  }

  const hours = Math.floor(minutes / 60);
  const remainingMinutes = minutes % 60;

  return remainingMinutes > 0
    ? `${hours}h ${remainingMinutes}m`
    : `${hours}h`;
}
