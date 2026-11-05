import { capitalize } from "@/lib/utils";

/**
 * Small pill rendering an effective severity. Severities come from the
 * enrichment pass (security-finding.severity_effective): one of "critical",
 * "high", "medium", "low", "info", or "unknown". Anything unrecognised
 * (including an absent severity) renders as "unknown". Stored lowercase; shown
 * capitalized. Keep this vocabulary in sync with the backend severity buckets
 * (Sgs_security_store.Severity_breakdown / select_security_findings_summary.sql).
 */

const SEVERITY_STYLES: Record<string, { bg: string; fg: string; border: string }> = {
  critical: { bg: "rgba(220,38,38,0.12)", fg: "#dc2626", border: "rgba(220,38,38,0.35)" },
  high: { bg: "rgba(234,88,12,0.12)", fg: "#ea580c", border: "rgba(234,88,12,0.35)" },
  medium: { bg: "rgba(202,138,4,0.14)", fg: "#ca8a04", border: "rgba(202,138,4,0.35)" },
  low: { bg: "rgba(37,99,235,0.12)", fg: "#2563eb", border: "rgba(37,99,235,0.35)" },
  info: { bg: "rgba(100,116,139,0.12)", fg: "#64748b", border: "rgba(100,116,139,0.35)" },
  unknown: {
    bg: "var(--sg-bg-2)",
    fg: "var(--sg-text-muted)",
    border: "var(--sg-border-light)",
  },
};

/** Highest-to-lowest severity, for sorting and for the filter control. */
export const SEVERITY_ORDER = ["critical", "high", "medium", "low", "info", "unknown"] as const;

export type Severity = (typeof SEVERITY_ORDER)[number];

function normalize(severity?: string): Severity {
  const s = (severity ?? "").toLowerCase();
  return (SEVERITY_ORDER as readonly string[]).includes(s) ? (s as Severity) : "unknown";
}

/** Rank for sorting: 0 = critical (most severe), higher = less severe. */
export function severityRank(severity?: string): number {
  return SEVERITY_ORDER.indexOf(normalize(severity));
}

export function SeverityBadge({ severity }: { severity?: string }) {
  const key = normalize(severity);
  const style = SEVERITY_STYLES[key];
  return (
    <span
      className="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium tracking-wide"
      style={{ backgroundColor: style.bg, color: style.fg, border: `1px solid ${style.border}` }}
    >
      {capitalize(key)}
    </span>
  );
}
