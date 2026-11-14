import { stateAreaForRoute, type ProductId, type StateAreaId } from "@/config/products";
import type { AttentionKind } from "@/app/(console)/home/dashboard";
import type { NextStepId } from "./next-steps";

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
export const STATE_DOCS_HREF = "https://stategraph.com/docs/infrastructure-as-a-database";

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

/** What the tenant has set up. */
export interface SetupShape {
  hasFirstRun: boolean;
  hasState: boolean;
}

/** `null` while not known. While facts reload, `previous` holds until they land, except that a
 *  state already in the list counts. */
export function setupShape(
  facts: Pick<SetupFacts, "stateCount" | "hasWorkManifest"> & {
    /** The setup facts or the state list are loading. */
    loading: boolean;
    /** The state list failed to load, so `stateCount` is not known. */
    statesFailed: boolean;
  },
  previous: SetupShape | null = null,
): SetupShape | null {
  if (facts.loading) {
    return previous && facts.stateCount > 0 ? { ...previous, hasState: true } : previous;
  }
  if (facts.statesFailed || facts.hasWorkManifest === null) return null;
  return { hasFirstRun: facts.hasWorkManifest, hasState: facts.stateCount > 0 };
}

export function sameSetupShape(a: SetupShape | null, b: SetupShape | null): boolean {
  if (a === null || b === null) return a === b;
  return a.hasFirstRun === b.hasFirstRun && a.hasState === b.hasState;
}

/** How the sidebar presents the areas that read a tenant's states: `unlocked` is the normal
 *  sidebar, `first-run` greys them out and points at the Orchestration setup, `needs-state` greys
 *  them out and points at the Infrastructure as a Database setup. */
export type FeatureNavLock = "unlocked" | "first-run" | "needs-state";

/** Locks only when first-run setup applies and the shape is known to have no state. */
export function featureNavLock(
  firstRunSetup: boolean | null,
  shape: SetupShape | null,
): FeatureNavLock {
  if (firstRunSetup !== true || shape === null || shape.hasState) return "unlocked";
  return shape.hasFirstRun ? "needs-state" : "first-run";
}

/** The parts of Home to render, top to bottom: the welcome panel, Needs attention, the
 *  Orchestration activity and the state sections, Next steps, the setup card, the help footer.
 *  With `columns` the Orchestration activity and the state overview sit side by side on wide
 *  screens. An Orchestration setup card goes above the state sections. */
export interface HomeLayout {
  welcome: boolean;
  attention: boolean;
  orchestration: boolean;
  stateSections: boolean;
  columns: boolean;
  nextSteps: boolean;
  card: "orchestration" | "state" | null;
  helpFooter: boolean;
}

const HOME_NOTHING: HomeLayout = {
  welcome: false,
  attention: false,
  orchestration: false,
  stateSections: false,
  columns: false,
  nextSteps: false,
  card: null,
  helpFooter: true,
};

/** Home shows what the tenant has set up, and the full page while that is not known. The help
 *  footer shows on every Home except the welcome panel, which carries the same links. */
export function homeLayout(firstRunSetup: boolean | null, shape: SetupShape | null): HomeLayout {
  const full: HomeLayout = {
    ...HOME_NOTHING,
    welcome: firstRunSetup === true,
    orchestration: true,
    stateSections: true,
    helpFooter: firstRunSetup !== true,
  };
  if (firstRunSetup === null || shape === null) return full;
  if (firstRunSetup === false) {
    return shape.hasState ? full : { ...HOME_NOTHING, card: "state" };
  }
  if (shape.hasFirstRun && shape.hasState) {
    return {
      ...HOME_NOTHING,
      attention: true,
      orchestration: true,
      stateSections: true,
      columns: true,
      nextSteps: true,
    };
  }
  if (shape.hasFirstRun) {
    return { ...HOME_NOTHING, attention: true, orchestration: true, nextSteps: true, card: "state" };
  }
  if (shape.hasState) return { ...HOME_NOTHING, stateSections: true, card: "orchestration" };
  return { ...HOME_NOTHING, welcome: true, helpFooter: false };
}

/** Where a locked area's sidebar row leads: the Orchestration setup before the first run, the area
 *  itself after it. An area the server has turned off leads to its own page, which says so. */
export function featureNavLockTarget(
  lock: Exclude<FeatureNavLock, "unlocked">,
  areaHref: string,
  featureOff = false,
): { href: string; hint: string } {
  if (featureOff) return { href: areaHref, hint: SETUP_COPY.featureNav.offHint };
  return lock === "first-run"
    ? { href: ORCHESTRATION_SETUP_HREF, hint: SETUP_COPY.featureNav.firstRunHint }
    : { href: areaHref, hint: SETUP_COPY.featureNav.stateHint };
}

/** Screens that show a self-hosted-only notice in COMMUNISM mode. */
const SELF_HOSTED_ONLY_SCREENS: ReadonlySet<ProductId> = new Set<ProductId>([
  "gap-analysis",
  "billing-connections",
]);

/** The state area whose page body gives way to the Infrastructure as a Database empty state, or
 *  `null` to render the page. A feature that is off on this server keeps its own notice. */
export function stateAreaGate(args: {
  lock: FeatureNavLock;
  pathname: string;
  mode: string | undefined;
  costsEnabled: boolean;
  securityEnabled: boolean;
}): StateAreaId | null {
  if (args.lock !== "needs-state") return null;
  const route = stateAreaForRoute(args.pathname);
  if (!route) return null;
  if (route.area === "costs" && !args.costsEnabled) return null;
  if (route.area === "security" && !args.securityEnabled) return null;
  if (args.mode === "COMMUNISM" && SELF_HOSTED_ONLY_SCREENS.has(route.screen)) return null;
  return route.area;
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
  featureNav: {
    firstRunHint: "After your first run",
    stateHint: "Needs a state",
    offHint: "Not enabled on this server",
  },
  stateArea: {
    title: (area: string) => `${area} needs Infrastructure as a Database`,
    areaBody: {
      inventory: "Inventory lists the states, resources, and modules that Stategraph stores.",
      insights: "Insights shows the timeline, search, and dependency graph of your states.",
      analyze: "Analyze runs SQL queries and dashboards over your states.",
      security: "Security scans your states for findings.",
      costs: "Costs estimates the spend of the resources in your states.",
    } satisfies Record<StateAreaId, string>,
    body: "With Orchestration, your state stays in your own backend, such as S3 or GCS, and this page has nothing to show. Infrastructure as a Database imports that state into PostgreSQL.",
    setupAction: "Set up Infrastructure as a Database",
    docsAction: "Learn more",
  },
  homeCards: {
    orchestration: {
      title: "Run plans from pull requests",
      body: "Orchestration plans and applies Terraform from pull requests, with approvals and policy checks. It can run on the states you already keep here.",
      action: "Set up Orchestration",
    },
    state: {
      title: "Infrastructure as a Database",
      body: "With Orchestration, your state stays in your own backend, such as S3 or GCS. Infrastructure as a Database imports it into PostgreSQL and adds inventory, search, queries, security scans, and cost estimates for every resource.",
      action: "Set up Infrastructure as a Database",
      docsAction: "Learn more",
    },
  },
  attention: {
    title: "Needs attention",
    empty: "Nothing needs attention.",
    partial: (providers: string) => `Could not load the ${providers} items. The list shows the rest.`,
    transactionsPartial: "Could not load the transactions.",
    count: {
      "failed-run": (n: number) => `${n} failed ${n === 1 ? "run" : "runs"}`,
      "failed-transaction": (n: number) => `${n} failed ${n === 1 ? "transaction" : "transactions"}`,
      "open-transaction": (n: number) => `${n} open ${n === 1 ? "transaction" : "transactions"}`,
      drift: (n: number) => `${n} drifted ${n === 1 ? "workspace" : "workspaces"}`,
      "waiting-for-apply": (n: number) => `${n} waiting for apply`,
    } satisfies Record<AttentionKind, (n: number) => string>,
    chip: {
      failed: "Failed",
      applyFailed: "Apply failed",
      openOverHour: "Open over 1 hour",
      drifted: "Drifted",
      waiting: "Waiting for apply",
    },
    transaction: (shortId: string) => `Transaction ${shortId}`,
    workspaces: (n: number) => `${n} ${n === 1 ? "workspace" : "workspaces"} with changes`,
  },
  activity: {
    chartTitle: "Plans and applies",
    chartRange: "Last 14 days",
    series: { plans: "Plans", applies: "Applies", failed: "Failed" },
    chartEmpty: "No plans or applies in the last 14 days.",
    partial: (providers: string) => `Could not load the ${providers} activity. The chart shows the rest.`,
    summary: (total: number, failed: number) =>
      `${total} plans and applies in the last 14 days. ${failed} failed.`,
  },
  nextSteps: {
    title: "Next steps",
    dismiss: "Dismiss",
    done: "Done",
    steps: {
      invite: {
        title: "Invite teammates",
        body: "Give your team access to runs, plans, and drift.",
        action: "Invite",
      },
      drift: {
        title: "Turn on drift detection",
        body: "Find changes made outside Terraform with scheduled plans.",
        action: "Read the guide",
      },
      repository: {
        title: "Connect another repository",
        body: "Plan and apply Terraform from more of your repositories.",
        action: "Add a repository",
      },
    } satisfies Record<NextStepId, { title: string; body: string; action: string }>,
  },
  help: {
    label: "Help",
    docs: "Getting started guide",
    slack: "Join our Slack",
    support: "Support",
  },
} as const;

export const HELP_DOCS_HREF = "https://stategraph.com/docs";
export const HELP_SLACK_HREF = "https://stategraph.com/slack";
export const HELP_SUPPORT_HREF = "/support";
