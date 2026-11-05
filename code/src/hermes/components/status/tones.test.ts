import assert from "node:assert";
import {
  OUTCOME_TONE,
  PR_STATE_TONE,
  RUN_STATE_TONE,
  STACK_STATE_TONE,
  STEP_STATUS_TONE,
  TONE_CLASS,
  TX_STATE_TONE,
  toneOf,
} from "./tones";

let failures = 0;
function test(name: string, fn: () => void) {
  try {
    fn();
    console.log(`ok - ${name}`);
  } catch (e) {
    failures++;
    console.error(`FAIL - ${name}\n  ${e instanceof Error ? e.message : e}`);
  }
}

test("every tone has a class and every class carries bg/text/border", () => {
  for (const tone of ["success", "error", "warning", "accent", "neutral"] as const) {
    const cls = TONE_CLASS[tone];
    assert.ok(cls, `missing class for ${tone}`);
    assert.match(cls, /bg-\[var\(--sg-/);
    assert.match(cls, /text-\[var\(--sg-/);
    assert.match(cls, /border-\[var\(--sg-/);
  }
});

test("stack states: the anchor mapping covers all 7 states", () => {
  assert.equal(toneOf(STACK_STATE_TONE, "plan_failed"), "error");
  assert.equal(toneOf(STACK_STATE_TONE, "apply_failed"), "error");
  assert.equal(toneOf(STACK_STATE_TONE, "plan_pending"), "warning");
  assert.equal(toneOf(STACK_STATE_TONE, "apply_pending"), "warning");
  assert.equal(toneOf(STACK_STATE_TONE, "apply_ready"), "accent");
  assert.equal(toneOf(STACK_STATE_TONE, "apply_success"), "success");
  assert.equal(toneOf(STACK_STATE_TONE, "no_changes"), "neutral");
});

test("run outcomes: success green, failure red, pending amber", () => {
  assert.equal(toneOf(OUTCOME_TONE, "succeeded"), "success");
  assert.equal(toneOf(OUTCOME_TONE, "failed"), "error");
  assert.equal(toneOf(OUTCOME_TONE, "queued"), "warning");
  assert.equal(toneOf(OUTCOME_TONE, "running"), "accent");
  assert.equal(toneOf(OUTCOME_TONE, "aborted"), "neutral");
  // Never green: an unrecognised lifecycle state is not a success.
  assert.equal(toneOf(OUTCOME_TONE, "unknown"), "neutral");
});

test("transaction states keep their existing colors", () => {
  assert.equal(toneOf(TX_STATE_TONE, "committed"), "success");
  assert.equal(toneOf(TX_STATE_TONE, "failed"), "error");
  assert.equal(toneOf(TX_STATE_TONE, "committing"), "warning");
  assert.equal(toneOf(TX_STATE_TONE, "open"), "accent");
  assert.equal(toneOf(TX_STATE_TONE, "previewing"), "accent");
  assert.equal(toneOf(TX_STATE_TONE, "aborted"), "neutral");
});

test("run lifecycle states keep their existing colors", () => {
  assert.equal(toneOf(RUN_STATE_TONE, "queued"), "neutral");
  assert.equal(toneOf(RUN_STATE_TONE, "running"), "accent");
  assert.equal(toneOf(RUN_STATE_TONE, "completed"), "neutral");
  assert.equal(toneOf(RUN_STATE_TONE, "aborted"), "neutral");
});

test("PR states: open accent, merged success, closed neutral", () => {
  assert.equal(toneOf(PR_STATE_TONE, "open"), "accent");
  assert.equal(toneOf(PR_STATE_TONE, "merged"), "success");
  assert.equal(toneOf(PR_STATE_TONE, "closed"), "neutral");
});

test("step statuses: success green, failure red, ignored failure amber", () => {
  assert.equal(STEP_STATUS_TONE.success, "success");
  assert.equal(STEP_STATUS_TONE.failure, "error");
  assert.equal(STEP_STATUS_TONE.ignored, "warning");
});

test("unknown states fall back to a visible neutral, never undefined", () => {
  for (const map of [STACK_STATE_TONE, OUTCOME_TONE, TX_STATE_TONE, RUN_STATE_TONE, PR_STATE_TONE]) {
    assert.equal(toneOf(map, "some_future_state"), "neutral");
    assert.ok(TONE_CLASS[toneOf(map, "some_future_state")]);
  }
  assert.equal(toneOf(OUTCOME_TONE, ""), "neutral");
});

if (failures > 0) {
  console.error(`\n${failures} test(s) failed`);
  process.exit(1);
}
console.log("\nall tone tests passed");
