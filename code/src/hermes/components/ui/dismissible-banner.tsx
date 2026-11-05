'use client';

import type { ReactNode } from 'react';
import { AlertCircle, AlertTriangle, CheckCircle2, Info, X, type LucideIcon } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';

export type BannerTone = 'error' | 'success' | 'warning' | 'info';

/**
 * What each tone contributes: its design-system colour token, for the frame and the icon alike,
 * and the live-region role -- an error interrupts the screen reader, the others wait their turn.
 * Information has no token of its own and borrows the accent blue. The classes are spelled out in
 * full so Tailwind finds them.
 */
export const BANNER_TONES: Record<
  BannerTone,
  { role: 'alert' | 'status'; Icon: LucideIcon; className: string; iconClassName: string }
> = {
  error: {
    role: 'alert',
    Icon: AlertCircle,
    className: 'border-[var(--sg-error)]/30 bg-[var(--sg-error)]/10',
    iconClassName: 'text-[var(--sg-error)]',
  },
  success: {
    role: 'status',
    Icon: CheckCircle2,
    className: 'border-[var(--sg-success)]/30 bg-[var(--sg-success)]/10',
    iconClassName: 'text-[var(--sg-success)]',
  },
  warning: {
    role: 'status',
    Icon: AlertTriangle,
    className: 'border-[var(--sg-warning)]/30 bg-[var(--sg-warning)]/10',
    iconClassName: 'text-[var(--sg-warning)]',
  },
  info: {
    role: 'status',
    Icon: Info,
    className: 'border-[var(--sg-accent)]/30 bg-[var(--sg-accent)]/10',
    iconClassName: 'text-[var(--sg-accent)]',
  },
};

/** A toned message box about the outcome of an action, shown until the user closes it. */
export function DismissibleBanner({
  tone,
  children,
  onDismiss,
  dismissLabel = 'Dismiss',
}: {
  tone: BannerTone;
  children: ReactNode;
  onDismiss: () => void;
  /** The close button's accessible name; make it specific where several banners can stack. */
  dismissLabel?: string;
}) {
  const { role, Icon, className, iconClassName } = BANNER_TONES[tone];

  return (
    <div
      role={role}
      className={cn('flex items-start gap-3 rounded-lg border px-4 py-3 text-sm', className)}
    >
      <Icon className={cn('mt-0.5 h-4 w-4 shrink-0', iconClassName)} aria-hidden="true" />
      <div className="flex-1 text-[var(--sg-text)]">{children}</div>
      <Button
        type="button"
        variant="ghost"
        size="icon-sm"
        className="-mr-1 -mt-1"
        onClick={onDismiss}
        aria-label={dismissLabel}
      >
        <X className="h-4 w-4" />
      </Button>
    </div>
  );
}
