export type SetupStatus = "done" | "started" | "todo";

export interface SetupFacts {
  stateCount: number;
  /** `null` when run history could not be read for every provider. */
  hasWorkManifest: boolean | null;
  /** `null` when the installation list was not available to this session. */
  linkedInstallation: boolean | null;
  /** `null` when the step outputs could not be read. */
  engineRun: boolean | null;
}

export const ORCHESTRATION_SETUP_HREF = "/getting-started?path=orchestrate";
export const STATE_SETUP_HREF = "/migrate-stategraph";
export const ENGINE_SETUP_HREF = "/migrate-stategraph?step=orchestration";

export function orchestrationStatus(
  facts: Pick<SetupFacts, "hasWorkManifest" | "linkedInstallation">,
): SetupStatus {
  if (facts.hasWorkManifest === true) return "done";
  if (facts.linkedInstallation === true) return "started";
  return "todo";
}

export function stateStatus(facts: Pick<SetupFacts, "stateCount">): SetupStatus {
  return facts.stateCount > 0 ? "done" : "todo";
}

export function engineStatus(facts: Pick<SetupFacts, "engineRun">): SetupStatus {
  return facts.engineRun === true ? "done" : "todo";
}

/** What an empty orchestration screen shows: `connect` replaces the screen's copy with the way into
 *  setup, `ask-admin` follows it with who connects a provider, `plain` is the screen's copy alone.
 *  A member cannot read the installation list, so a member is only told when the tenant has no run. */
export type OrchestrationEmptyKind = "connect" | "ask-admin" | "plain";

export function orchestrationEmptyKind(
  facts: Pick<SetupFacts, "hasWorkManifest" | "linkedInstallation"> & { tenantAdmin: boolean },
): OrchestrationEmptyKind {
  if (facts.tenantAdmin) return facts.linkedInstallation === false ? "connect" : "plain";
  return facts.hasWorkManifest === false ? "ask-admin" : "plain";
}

export const SETUP_COPY = {
  engine: {
    title: "Run your plans through Stategraph Infrastructure as a Database",
    nextBody:
      "Your state is in Stategraph's database, but your pull requests still plan against your old backend. Switch the engine in .stategraph/config.yml.",
    action: "Switch the engine",
  },
  orchestrationEmpty: {
    connectTitle: "No repositories connected",
    connectBody: "Connect a GitHub organization or GitLab group to run plans from pull requests.",
    connectAction: "Get started",
    askAdmin: "A tenant admin connects GitHub or GitLab from Get Started.",
  },
} as const;
