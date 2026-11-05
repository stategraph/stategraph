import { provenanceMeta } from "@/lib/cost/provenance";

const PILL: Record<string, { bg: string; fg: string }> = {
  tx_apply: { bg: "var(--sg-accent-bg)", fg: "var(--sg-accent)" },
  actuator_commit: { bg: "var(--sg-accent-bg)", fg: "var(--sg-accent)" },
  preview: { bg: "var(--sg-warning-bg)", fg: "var(--sg-warning)" },
  scheduled: { bg: "var(--sg-bg-2)", fg: "var(--sg-text-muted)" },
  manual: { bg: "var(--sg-bg-2)", fg: "var(--sg-text-muted)" },
  state_import: { bg: "var(--sg-bg-2)", fg: "var(--sg-text-muted)" },
};

const NEUTRAL = { bg: "var(--sg-bg-2)", fg: "var(--sg-text-muted)" };

export interface ProvenanceBadgeProps {
  triggeredBy: string | null | undefined;
  className?: string;
}

/**
 * A small pill labelling what produced a cost snapshot (apply, scheduled,
 * import, ...). Apply/actuator events use the accent colour since they map to a
 * real infrastructure change; everything else is neutral.
 */
export function ProvenanceBadge({ triggeredBy, className }: ProvenanceBadgeProps) {
  const meta = provenanceMeta(triggeredBy);
  const pill = (triggeredBy && PILL[triggeredBy]) || NEUTRAL;
  return (
    <span
      title={meta.description}
      className={`inline-flex items-center px-1.5 py-0.5 rounded text-[10px] font-medium uppercase tracking-wide ${className ?? ""}`}
      style={{ backgroundColor: pill.bg, color: pill.fg }}
    >
      {meta.label}
    </span>
  );
}
