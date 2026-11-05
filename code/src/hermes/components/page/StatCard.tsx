import React from "react";
import { ArrowUpRight } from "lucide-react";
// Direct import: the navigation barrel's HubRedirect imports this barrel.
import { DeepLink } from "@/components/navigation/DeepLink";

/**
 * One card of an overview strip. Overview cards are navigation: with `href`
 * the card is a link (so ctrl/middle-click open a new tab) to the list it
 * counts, filtered through that list's own URL params; with `onClick` it is a
 * button for in-page actions such as scrolling to a section.
 */
export function StatCard({
  label,
  value,
  sub,
  icon: Icon,
  tone,
  href,
  onClick,
}: {
  label: string;
  value: string;
  /** One line under the value: a relative time, a split, a caveat. */
  sub?: string;
  icon?: React.ComponentType<{ className?: string }>;
  /** Text colour class for the value; defaults to accent when clickable. */
  tone?: string;
  href?: string;
  onClick?: () => void;
}) {
  const clickable = href !== undefined || onClick !== undefined;
  const valueTone = tone ?? (clickable ? "text-[var(--sg-accent)]" : "text-[var(--sg-text)]");
  const body = (
    <>
      <div className="flex items-center gap-1.5 text-xs uppercase tracking-wide text-[var(--sg-text-muted)]">
        {Icon && <Icon className="w-3.5 h-3.5" />}
        <span>{label}</span>
        {clickable && <ArrowUpRight className="w-3 h-3 ml-auto text-[var(--sg-accent)]" />}
      </div>
      <div className={`mt-1 text-xl font-semibold tabular-nums break-words ${valueTone}`}>{value}</div>
      {sub && <div className="text-xs text-[var(--sg-text-dim)]">{sub}</div>}
    </>
  );
  const className = "rounded-lg border border-[var(--sg-border)] bg-[var(--sg-bg-1)] px-4 py-3";
  if (href !== undefined) {
    return (
      <DeepLink href={href} className={`${className} block w-full text-left hover:bg-[var(--sg-bg-2)]`}>
        {body}
      </DeepLink>
    );
  }
  return onClick ? (
    <button type="button" onClick={onClick} className={`${className} w-full text-left hover:bg-[var(--sg-bg-2)] cursor-pointer`}>
      {body}
    </button>
  ) : (
    <div className={className}>{body}</div>
  );
}
