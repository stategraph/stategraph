/**
 * Human labels for a cost snapshot's `triggered_by` provenance.
 *
 * The backend records what caused each snapshot (an import, an apply, the
 * scheduled refresh, ...). The UI surfaces this on KPIs, history tooltips, and
 * event markers so a spike can be traced to the change that caused it.
 */

export interface ProvenanceMeta {
  label: string;
  /** Longer description for tooltips. */
  description: string;
}

const PROVENANCE: Record<string, ProvenanceMeta> = {
  state_import: {
    label: "Import",
    description: "Computed from an imported state snapshot",
  },
  tx_apply: {
    label: "Apply",
    description: "Computed after a Terraform apply transaction",
  },
  actuator_commit: {
    label: "Actuator",
    description: "Computed after an orchestrated actuator commit",
  },
  scheduled: {
    label: "Scheduled",
    description: "Computed by the scheduled cost refresh",
  },
  manual: {
    label: "Manual",
    description: "Computed from a manual recalculation",
  },
  preview: {
    label: "Preview",
    description: "Computed for a plan/preview (not applied)",
  },
};

function humanize(value: string): string {
  return value.replace(/_/g, " ").replace(/\b\w/g, (c) => c.toUpperCase());
}

/** Short label for a `triggered_by` value (falls back to a humanized form). */
export function groupLabel(triggeredBy: string | null | undefined): string {
  if (!triggeredBy) return "Unknown";
  return PROVENANCE[triggeredBy]?.label ?? humanize(triggeredBy);
}

/** Label + description for a `triggered_by` value. */
export function provenanceMeta(triggeredBy: string | null | undefined): ProvenanceMeta {
  if (!triggeredBy) return { label: "Unknown", description: "Provenance not recorded" };
  return PROVENANCE[triggeredBy] ?? { label: humanize(triggeredBy), description: triggeredBy };
}

/** Snapshot causes that represent a change worth annotating on a trend chart. */
export const CHANGE_EVENTS: ReadonlySet<string> = new Set(["tx_apply", "actuator_commit"]);

export function isChangeEvent(triggeredBy: string | null | undefined): boolean {
  return !!triggeredBy && CHANGE_EVENTS.has(triggeredBy);
}
