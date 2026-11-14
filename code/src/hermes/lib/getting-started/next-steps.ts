import { ORCHESTRATION_SETUP_HREF } from "./setup-progress";

export type NextStepId = "invite" | "drift" | "repository";

export const MEMBERS_SETTINGS_HREF = "/settings?tab=members";
export const DRIFT_DOCS_HREF = "https://stategraph.com/docs/orchestration/governance/drift-detection";

/** `null` where the fact is not known to this session. */
export interface NextStepFacts {
  memberCount: number | null;
  hasDriftRun: boolean | null;
  repositoriesWithRuns: number | null;
}

export interface NextStep {
  id: NextStepId;
  done: boolean;
  href: string;
  external: boolean;
}

/** The next steps whose fact is known, in display order. */
export function nextSteps(facts: NextStepFacts): NextStep[] {
  const steps: NextStep[] = [];
  if (facts.memberCount !== null) {
    steps.push({
      id: "invite",
      done: facts.memberCount > 1,
      href: MEMBERS_SETTINGS_HREF,
      external: false,
    });
  }
  if (facts.hasDriftRun !== null) {
    steps.push({ id: "drift", done: facts.hasDriftRun, href: DRIFT_DOCS_HREF, external: true });
  }
  if (facts.repositoriesWithRuns !== null) {
    steps.push({
      id: "repository",
      done: facts.repositoriesWithRuns > 1,
      href: ORCHESTRATION_SETUP_HREF,
      external: false,
    });
  }
  return steps;
}

/** The card shows while it is not dismissed and a known step is not done. */
export function showNextSteps(steps: readonly NextStep[], dismissed: boolean): boolean {
  return !dismissed && steps.some((s) => !s.done);
}

const KEY_PREFIX = "stategraph-home-next-steps-dismissed:";

interface StoreLike {
  getItem(key: string): string | null;
  setItem(key: string, value: string): void;
}

function localStore(): StoreLike | null {
  if (typeof window === "undefined") return null;
  try {
    return window.localStorage;
  } catch {
    return null;
  }
}

/** Whether this browser dismissed the Next steps card for the tenant. */
export function nextStepsDismissed(tenantId: string, store: StoreLike | null = localStore()): boolean {
  if (!store) return false;
  try {
    return store.getItem(KEY_PREFIX + tenantId) === "1";
  } catch {
    return false;
  }
}

export function dismissNextSteps(tenantId: string, store: StoreLike | null = localStore()): void {
  if (!store) return;
  try {
    store.setItem(KEY_PREFIX + tenantId, "1");
  } catch {
    // Unavailable or full: the card comes back on the next load.
  }
}
