"use client";

interface BadgeProps {
  children: React.ReactNode;
  variant?: 'default' | 'secondary' | 'outline';
  className?: string;
}

/**
 * Badge - Small label/tag component for resource groups
 *
 * @param children - Badge content (usually text)
 * @param variant - Visual style (default, secondary, outline)
 * @param className - Additional CSS classes
 */
export function Badge({
  children,
  variant = 'default',
  className = ''
}: BadgeProps) {
  const baseClasses = 'inline-flex items-center rounded px-2 py-0.5 text-xs font-medium transition-colors';

  const variantClasses = {
    default: 'bg-[var(--sg-accent-bg)] text-[var(--sg-accent)] border border-[var(--sg-accent)]/20',
    secondary: 'bg-[var(--sg-bg-2)] text-[var(--sg-text-muted)] border border-[var(--sg-border)]',
    outline: 'bg-transparent text-[var(--sg-text-muted)] border border-[var(--sg-border)]'
  };

  return (
    <span className={`${baseClasses} ${variantClasses[variant]} ${className}`}>
      {children}
    </span>
  );
}

/**
 * BadgeGroup - Container for multiple badges with spacing
 */
export function BadgeGroup({
  children,
  className = ''
}: {
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <div className={`flex flex-wrap items-center gap-1.5 ${className}`}>
      {children}
    </div>
  );
}
