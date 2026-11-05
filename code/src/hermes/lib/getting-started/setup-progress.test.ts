/**
 * Run with: npx tsx lib/getting-started/setup-progress.test.ts
 */

import assert from "node:assert";
import {
  engineStatus,
  orchestrationEmptyKind,
  orchestrationStatus,
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

if (failures > 0) process.exit(1);
