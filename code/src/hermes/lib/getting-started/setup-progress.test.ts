/**
 * Run with: npx tsx lib/getting-started/setup-progress.test.ts
 */

import assert from "node:assert";
import {
  ORCHESTRATION_SETUP_HREF,
  engineStatus,
  featureNavLock,
  featureNavLockTarget,
  homeLayout,
  orchestrationEmptyKind,
  orchestrationStatus,
  sameSetupShape,
  setupShape,
  stateAreaGate,
  stateStatus,
} from "./setup-progress";

let failures = 0;
function test(name: string, fn: () => void) {
  try {
    fn();
    console.log(`ok - ${name}`);
  } catch (e) {
    failures++;
    console.error(`not ok - ${name}`);
    console.error(e);
  }
}

test("a work manifest means orchestration is done, whatever the installation list says", () => {
  assert.equal(orchestrationStatus({ hasWorkManifest: true, linkedInstallation: null }), "done");
  assert.equal(orchestrationStatus({ hasWorkManifest: true, linkedInstallation: false }), "done");
});

test("a linked installation without a run is started", () => {
  assert.equal(orchestrationStatus({ hasWorkManifest: false, linkedInstallation: true }), "started");
  assert.equal(orchestrationStatus({ hasWorkManifest: null, linkedInstallation: true }), "started");
});

test("no run and no known installation is todo", () => {
  assert.equal(orchestrationStatus({ hasWorkManifest: false, linkedInstallation: false }), "todo");
  assert.equal(orchestrationStatus({ hasWorkManifest: null, linkedInstallation: null }), "todo");
});

test("state is done once a state exists", () => {
  assert.equal(stateStatus({ stateCount: 0 }), "todo");
  assert.equal(stateStatus({ stateCount: 3 }), "done");
});

test("the engine is done only on a proven stategraph plan step", () => {
  assert.equal(engineStatus({ engineRun: true }), "done");
  assert.equal(engineStatus({ engineRun: false }), "todo");
  assert.equal(engineStatus({ engineRun: null }), "todo");
});

test("an admin with no linked installation is sent to connect one, whatever the runs say", () => {
  for (const hasWorkManifest of [true, false, null]) {
    assert.equal(
      orchestrationEmptyKind({ tenantAdmin: true, linkedInstallation: false, hasWorkManifest }),
      "connect",
    );
  }
});

test("an admin with a linked or unknown installation keeps the screen's copy", () => {
  assert.equal(
    orchestrationEmptyKind({ tenantAdmin: true, linkedInstallation: true, hasWorkManifest: false }),
    "plain",
  );
  assert.equal(
    orchestrationEmptyKind({ tenantAdmin: true, linkedInstallation: null, hasWorkManifest: false }),
    "plain",
  );
});

test("a member is pointed at an admin only when the tenant has no run", () => {
  assert.equal(
    orchestrationEmptyKind({ tenantAdmin: false, linkedInstallation: null, hasWorkManifest: false }),
    "ask-admin",
  );
  assert.equal(
    orchestrationEmptyKind({ tenantAdmin: false, linkedInstallation: null, hasWorkManifest: true }),
    "plain",
  );
  assert.equal(
    orchestrationEmptyKind({ tenantAdmin: false, linkedInstallation: null, hasWorkManifest: null }),
    "plain",
  );
});

const settledNewTenant = {
  loading: false,
  statesFailed: false,
  stateCount: 0,
  hasWorkManifest: false,
} as const;

const NEITHER = { hasFirstRun: false, hasState: false };
const RUN_ONLY = { hasFirstRun: true, hasState: false };
const STATE_ONLY = { hasFirstRun: false, hasState: true };
const BOTH = { hasFirstRun: true, hasState: true };

test("settled facts give the shape: a run is a work manifest, a state is a listed state", () => {
  assert.deepEqual(setupShape(settledNewTenant), NEITHER);
  assert.deepEqual(setupShape({ ...settledNewTenant, hasWorkManifest: true }), RUN_ONLY);
  assert.deepEqual(setupShape({ ...settledNewTenant, stateCount: 3 }), STATE_ONLY);
  assert.deepEqual(setupShape({ ...settledNewTenant, stateCount: 1, hasWorkManifest: true }), BOTH);
});

test("unknown run history or a failed state list leaves the shape unknown", () => {
  assert.equal(setupShape({ ...settledNewTenant, hasWorkManifest: null }), null);
  assert.equal(setupShape({ ...settledNewTenant, hasWorkManifest: null, stateCount: 2 }), null);
  assert.equal(setupShape({ ...settledNewTenant, statesFailed: true }, RUN_ONLY), null);
});

test("a first load is unknown, and a reload keeps the shape it had", () => {
  const loading = { ...settledNewTenant, loading: true, hasWorkManifest: null };
  assert.equal(setupShape(loading), null);
  assert.deepEqual(setupShape(loading, NEITHER), NEITHER);
  assert.deepEqual(setupShape(loading, RUN_ONLY), RUN_ONLY);
});

test("a state that is already listed counts during a reload", () => {
  const loading = { ...settledNewTenant, loading: true, stateCount: 2 };
  assert.deepEqual(setupShape(loading, NEITHER), STATE_ONLY);
  assert.deepEqual(setupShape(loading, RUN_ONLY), BOTH);
  assert.equal(setupShape(loading), null);
});

test("shapes compare by value", () => {
  assert.equal(sameSetupShape({ ...RUN_ONLY }, { ...RUN_ONLY }), true);
  assert.equal(sameSetupShape(RUN_ONLY, BOTH), false);
  assert.equal(sameSetupShape(null, null), true);
  assert.equal(sameSetupShape(null, NEITHER), false);
});

test("no run and no state locks the state areas behind the first run", () => {
  assert.equal(featureNavLock(true, NEITHER), "first-run");
});

test("a run without state locks them behind Infrastructure as a Database setup", () => {
  assert.equal(featureNavLock(true, RUN_ONLY), "needs-state");
});

test("a state unlocks them, whatever the runs say", () => {
  assert.equal(featureNavLock(true, STATE_ONLY), "unlocked");
  assert.equal(featureNavLock(true, BOTH), "unlocked");
});

test("nothing is locked unless first-run setup applies and the shape is known", () => {
  for (const firstRunSetup of [false, null]) {
    for (const shape of [NEITHER, RUN_ONLY, null]) {
      assert.equal(featureNavLock(firstRunSetup, shape), "unlocked");
    }
  }
  assert.equal(featureNavLock(true, null), "unlocked");
});

const NOTHING = {
  welcome: false,
  attention: false,
  orchestration: false,
  stateSections: false,
  columns: false,
  nextSteps: false,
  card: null,
  helpFooter: true,
};
const FULL = { ...NOTHING, welcome: true, orchestration: true, stateSections: true, helpFooter: false };
const FULL_NO_WELCOME = { ...FULL, welcome: false, helpFooter: true };

test("before anything is set up Home is the welcome panel alone", () => {
  assert.deepEqual(homeLayout(true, NEITHER), { ...NOTHING, welcome: true, helpFooter: false });
});

test("runs without a state lead with Needs attention and end with the state card", () => {
  assert.deepEqual(homeLayout(true, RUN_ONLY), {
    ...NOTHING,
    attention: true,
    orchestration: true,
    nextSteps: true,
    card: "state",
  });
});

test("runs and a state put Orchestration and the state overview side by side, with no setup card", () => {
  assert.deepEqual(homeLayout(true, BOTH), {
    ...NOTHING,
    attention: true,
    orchestration: true,
    stateSections: true,
    columns: true,
    nextSteps: true,
  });
});

test("a state without runs shows the state sections under the Orchestration card", () => {
  assert.deepEqual(homeLayout(true, STATE_ONLY), {
    ...NOTHING,
    stateSections: true,
    card: "orchestration",
  });
});

test("Needs attention and Next steps show exactly when the tenant has runs", () => {
  for (const shape of [NEITHER, RUN_ONLY, STATE_ONLY, BOTH]) {
    const layout = homeLayout(true, shape);
    assert.equal(layout.attention, shape.hasFirstRun);
    assert.equal(layout.nextSteps, shape.hasFirstRun);
  }
});

test("the help footer shows on every Home but the welcome panel", () => {
  for (const firstRunSetup of [true, false, null]) {
    for (const shape of [NEITHER, RUN_ONLY, STATE_ONLY, BOTH, null]) {
      const layout = homeLayout(firstRunSetup, shape);
      assert.equal(layout.helpFooter, !layout.welcome);
    }
  }
});

test("without Orchestration Home is the Infrastructure as a Database card until there is a state", () => {
  for (const shape of [NEITHER, RUN_ONLY]) {
    assert.deepEqual(homeLayout(false, shape), { ...NOTHING, card: "state" });
  }
  for (const shape of [STATE_ONLY, BOTH]) {
    assert.deepEqual(homeLayout(false, shape), FULL_NO_WELCOME);
  }
});

test("Home is the full page while the shape or first-run setup is not known", () => {
  assert.deepEqual(homeLayout(true, null), FULL);
  assert.deepEqual(homeLayout(false, null), FULL_NO_WELCOME);
  for (const shape of [NEITHER, RUN_ONLY, STATE_ONLY, BOTH, null]) {
    assert.deepEqual(homeLayout(null, shape), FULL_NO_WELCOME);
  }
});

test("Home and the sidebar agree: state sections show exactly when the state areas are unlocked", () => {
  for (const shape of [NEITHER, RUN_ONLY, STATE_ONLY, BOTH, null]) {
    assert.equal(homeLayout(true, shape).stateSections, featureNavLock(true, shape) === "unlocked");
  }
});

test("before the first run a locked row leads to the Orchestration setup, after it to its own area", () => {
  assert.deepEqual(featureNavLockTarget("first-run", "/inventory"), {
    href: ORCHESTRATION_SETUP_HREF,
    hint: "After your first run",
  });
  assert.deepEqual(featureNavLockTarget("needs-state", "/inventory"), {
    href: "/inventory",
    hint: "Needs a state",
  });
  assert.equal(featureNavLockTarget("needs-state", "/costs").href, "/costs");
});

test("an area the server has turned off leads to its own page in either lock", () => {
  for (const lock of ["first-run", "needs-state"] as const) {
    assert.deepEqual(featureNavLockTarget(lock, "/security", true), {
      href: "/security",
      hint: "Not enabled on this server",
    });
  }
});

const gateAll = {
  lock: "needs-state",
  mode: undefined,
  costsEnabled: true,
  securityEnabled: true,
} as const;

test("a run without state replaces every state area page with the empty state", () => {
  const cases: Array<[string, string]> = [
    ["/inventory", "inventory"],
    ["/instances", "inventory"],
    ["/states/detail", "inventory"],
    ["/gap-analysis", "inventory"],
    ["/timeline", "insights"],
    ["/state-changes", "insights"],
    ["/graph-explorer", "insights"],
    ["/query", "analyze"],
    ["/dashboards", "analyze"],
    ["/security", "security"],
    ["/security/findings/detail", "security"],
    ["/cost-overview", "costs"],
    ["/billing-connections", "costs"],
  ];
  for (const [pathname, area] of cases) {
    assert.equal(stateAreaGate({ ...gateAll, pathname }), area, pathname);
  }
});

test("the empty state shows only in the needs-state lock and only on state area pages", () => {
  for (const lock of ["unlocked", "first-run"] as const) {
    assert.equal(stateAreaGate({ ...gateAll, lock, pathname: "/instances" }), null);
  }
  for (const pathname of ["/", "/orchestration", "/runs", "/getting-started", "/migrate-stategraph", "/settings"]) {
    assert.equal(stateAreaGate({ ...gateAll, pathname }), null, pathname);
  }
});

test("a feature that is off keeps its own notice", () => {
  assert.equal(stateAreaGate({ ...gateAll, costsEnabled: false, pathname: "/cost-overview" }), null);
  assert.equal(stateAreaGate({ ...gateAll, costsEnabled: false, pathname: "/costs" }), null);
  assert.equal(stateAreaGate({ ...gateAll, securityEnabled: false, pathname: "/security/overview" }), null);
  assert.equal(stateAreaGate({ ...gateAll, mode: "COMMUNISM", pathname: "/gap-analysis" }), null);
  assert.equal(stateAreaGate({ ...gateAll, mode: "COMMUNISM", pathname: "/billing-connections" }), null);
  assert.equal(stateAreaGate({ ...gateAll, mode: "COMMUNISM", pathname: "/instances" }), "inventory");
  assert.equal(stateAreaGate({ ...gateAll, costsEnabled: false, pathname: "/instances" }), "inventory");
});

if (failures > 0) process.exit(1);
