import assert from "node:assert";
import {
  applyOutputs,
  countsFor,
  decodeCost,
  dirspaceAnchor,
  groupByDirspace,
  groupSteps,
  hasChanges,
  hookSteps,
  isActualFailure,
  isApplyStep,
  isDirspaceScope,
  isInitStep,
  isPlanStep,
  isRunScope,
  isStepVisible,
  parseCounts,
  planBody,
  planDiff,
  resourceSummaryFor,
  runHooks,
  runKindLabel,
  runListOutcome,
  runOutcome,
  runOutcomeFromSuccess,
  runSummary,
  summaryCountsLine,
  summaryResult,
  stepCmd,
  stepLabel,
  stepStatus,
  totalCounts,
  type RawStep,
} from "./decode";

let failures = 0;
function test(name: string, fn: () => void) {
  try { fn(); console.log(`ok - ${name}`); }
  catch (e) { failures++; console.error(`FAIL - ${name}\n  ${e instanceof Error ? e.message : e}`); }
}

// --- scope classification ---
test("scope: canonical dirspace vs run hook", () => {
  assert.equal(isDirspaceScope({ type: "dirspace", dir: "a", workspace: "default" }), true);
  assert.equal(isRunScope({ type: "run", flow: "hooks", subflow: "pre" }), true);
  assert.equal(isDirspaceScope({ type: "run", flow: "hooks", subflow: "pre" }), false);
});
test("scope: legacy pr/drift still group as dirspace", () => {
  assert.equal(isDirspaceScope({ type: "pr", dir: "a", workspace: "default" }), true);
  assert.equal(isDirspaceScope({ type: "drift", dir: "a", workspace: "default" }), true);
});

// --- plan counts (canonical text + legacy summary) ---
const PLAN_TEXT = "Terraform will perform the following actions:\n\n  # module.a.aws_instance.web will be created\n  + resource \"aws_instance\" \"web\" {}\n\nPlan: 2 to add, 1 to change, 0 to destroy.\n";
test("parseCounts: reads the Plan: summary line", () => {
  assert.deepEqual(parseCounts(PLAN_TEXT), { add: 2, change: 1, destroy: 0 });
});
test("parseCounts: no summary line -> null", () => {
  assert.equal(parseCounts("No changes. Your infrastructure matches the configuration."), null);
});
test("countsFor: canonical plan prefers parsed text", () => {
  assert.deepEqual(countsFor({ plan: PLAN_TEXT, has_changes: true }), { add: 2, change: 1, destroy: 0 });
});
test("countsFor: legacy summary fallback", () => {
  assert.deepEqual(countsFor({ text: "x", summary: { add: 3, change: 0, destroy: 2 } }), { add: 3, change: 0, destroy: 2 });
});

// --- plan resource summary (imported/created/updated/replaced/deleted) ---
test("resourceSummaryFor: counts present, partial keeps all five slots", () => {
  assert.deepEqual(
    resourceSummaryFor({ resource_summary: { imported: 1, created: 2, updated: 1, replaced: 0, deleted: 0 } }),
    { imported: 1, created: 2, updated: 1, replaced: 0, deleted: 0 },
  );
  // A partial payload keeps every slot, unreported ones null, so the renderer
  // shows `-` for them (the backend count_str convention).
  assert.deepEqual(
    resourceSummaryFor({ resource_summary: { replaced: 2 } }),
    { imported: null, created: null, updated: null, replaced: 2, deleted: null },
  );
  assert.deepEqual(
    resourceSummaryFor({ resource_summary: { imported: 3 } }),
    { imported: 3, created: null, updated: null, replaced: null, deleted: null },
  );
});
test("resourceSummaryFor: resource_summary absent -> null", () => {
  assert.equal(resourceSummaryFor(null), null);
  assert.equal(resourceSummaryFor({}), null);
  assert.equal(resourceSummaryFor({ plan: PLAN_TEXT, has_changes: true }), null);
});
test("resourceSummaryFor: all slots null -> null (hide, never zero)", () => {
  assert.equal(
    resourceSummaryFor({
      resource_summary: { imported: null, created: null, updated: null, replaced: null, deleted: null },
    }),
    null,
  );
});
test("resourceSummaryFor: legacy payload shape degrades without throwing", () => {
  // Legacy plan payload: the made-up summary carries add/change/destroy and
  // no resource counts; a non-object resource_summary reads as absent.
  assert.equal(resourceSummaryFor({ summary: { add: 3, change: 0, destroy: 2 } }), null);
  assert.equal(resourceSummaryFor({ resource_summary: "none" }), null);
  assert.equal(resourceSummaryFor({ resource_summary: [1, 2] }), null);
});

// --- plan body / has_changes ---
test("planBody: prefers plan, falls back to text", () => {
  assert.equal(planBody({ plan: "P", text: "T" }), "P");
  assert.equal(planBody({ text: "T" }), "T");
  assert.equal(planBody({ plan_text: "L" }), "L");
});
test("hasChanges: only a real boolean", () => {
  assert.equal(hasChanges({ has_changes: false }), false);
  assert.equal(hasChanges({}), undefined);
});

// --- cmd + apply outputs ---
test("stepCmd: array of strings", () => {
  assert.deepEqual(stepCmd({ cmd: ["terraform", "plan"] }), ["terraform", "plan"]);
  assert.deepEqual(stepCmd({}), []);
});
test("applyOutputs: value/sensitive object shape", () => {
  const outs = applyOutputs({ outputs: {
    vpc_id: { value: "vpc-1", sensitive: false },
    secret: { value: "shh", sensitive: true },
  }});
  assert.deepEqual(outs.find((o) => o.name === "vpc_id"), { name: "vpc_id", value: "vpc-1", sensitive: false });
  assert.deepEqual(outs.find((o) => o.name === "secret"), { name: "secret", value: "(sensitive)", sensitive: true });
});

// --- cost estimation ---
test("decodeCost: canonical summary + dirspaces", () => {
  const c = decodeCost({
    currency: "USD",
    summary: { prev_monthly_cost: 100, total_monthly_cost: 150, diff_monthly_cost: 50 },
    dirspaces: [{ dir: "a", workspace: "default", prev_monthly_cost: 100, total_monthly_cost: 150, diff_monthly_cost: 50 }],
  });
  assert.ok(c);
  assert.equal(c!.diff, 50);
  assert.equal(c!.dirspaces.length, 1);
  assert.equal(c!.dirspaces[0].dir, "a");
});
test("decodeCost: failure payload {text}", () => {
  const c = decodeCost({ text: "infracost failed" });
  assert.ok(c);
  assert.equal(c!.failed, "infracost failed");
});
test("decodeCost: empty -> null", () => {
  assert.equal(decodeCost(null), null);
  assert.equal(decodeCost({}), null);
});

// --- grouping + hooks ---
const STEPS: RawStep[] = [
  { idx: 0, step: "checkout", success: true, scope: { type: "run", flow: "hooks", subflow: "pre" }, payload: { text: "HEAD" } },
  { idx: 1, step: "env", success: true, scope: { type: "run", flow: "hooks", subflow: "pre" }, payload: { text: "TF" } },
  { idx: 2, step: "tf/init", success: true, scope: { type: "dirspace", dir: "a", workspace: "default" }, payload: { text: "init" } },
  { idx: 3, step: "tf/plan", success: true, scope: { type: "dirspace", dir: "a", workspace: "default" }, payload: { plan: PLAN_TEXT, has_changes: true } },
  { idx: 4, step: "tf/cost-estimation", success: true, scope: { type: "run", flow: "hooks", subflow: "pre" }, payload: { summary: { diff_monthly_cost: 5 }, currency: "USD" } },
];
test("groupByDirspace: pulls init/plan out per dirspace", () => {
  const g = groupByDirspace(STEPS);
  assert.equal(g.length, 1);
  assert.equal(g[0].dir, "a");
  assert.ok(g[0].init);
  assert.ok(g[0].plan);
  assert.equal(g[0].apply, undefined);
});
test("groupByDirspace: every engine's init/plan/apply structure like tf's", () => {
  const scope = { type: "dirspace", dir: "a", workspace: "default" };
  for (const engine of ["tf", "pulumi", "custom", "fly", "stategraph"]) {
    const [g] = groupByDirspace(
      ["init", "plan", "apply"].map((op, idx) => ({ idx, step: `${engine}/${op}`, success: true, scope, payload: {} })),
    );
    assert.equal(g.init?.step, `${engine}/init`);
    assert.equal(g.plan?.step, `${engine}/plan`);
    assert.equal(g.apply?.step, `${engine}/apply`);
    assert.equal(g.others.length, 0);
  }
});
test("isPlanStep/isApplyStep/isInitStep: only known engines' steps", () => {
  assert.equal(isPlanStep("pulumi/plan"), true);
  assert.equal(isPlanStep("run/plan"), false);
  assert.equal(isPlanStep("tf/plan-json"), false);
  assert.equal(isApplyStep("fly/apply"), true);
  assert.equal(isInitStep("stategraph/init"), true);
});
test("runHooks: checkout/env/cost recognised", () => {
  const h = runHooks(STEPS);
  assert.ok(h.checkout);
  assert.ok(h.env);
  assert.ok(h.cost);
});
test("totalCounts: sums plan counts across dirspaces", () => {
  assert.deepEqual(totalCounts(groupByDirspace(STEPS)), { add: 2, change: 1, destroy: 0 });
});

// --- run summary ---
const dsStep = (idx: number, step: string, dir: string, success: boolean, payload: RawStep["payload"]): RawStep => ({
  idx, step, success, scope: { type: "dirspace", dir, workspace: "default" }, payload,
});
test("runSummary: failed first, then changes, then dirspace; totals over reported rows", () => {
  const { rows, totals } = runSummary(groupByDirspace([
    dsStep(0, "tf/plan", "c", true, { has_changes: false }),
    dsStep(1, "tf/plan", "b", true, { has_changes: true, resource_summary: { created: 2, updated: null, replaced: 1, deleted: 0 } }),
    dsStep(2, "tf/plan", "a", true, { has_changes: true, resource_summary: { imported: 2, created: 1, updated: 3, replaced: 0, deleted: 4 } }),
    dsStep(3, "tf/init", "d", false, {}),
  ]));
  assert.deepEqual(rows.map((r) => [r.dir, r.success, r.hasChanges]), [
    ["d", false, false], ["a", true, true], ["b", true, true], ["c", true, false],
  ]);
  assert.deepEqual(rows[2].resources, { imported: null, created: 2, updated: null, replaced: 1, deleted: 0 });
  assert.equal(rows[3].resources, null);
  assert.deepEqual(totals, { imported: 2, created: 3, updated: 3, replaced: 1, deleted: 4 });
});
test("runSummary: ignored failures succeed; apply wins over plan", () => {
  const { rows } = runSummary(groupByDirspace([
    { ...dsStep(0, "run", "a", false, {}), ignoreErrors: true },
    dsStep(1, "tf/plan", "a", true, {}),
    dsStep(2, "tf/apply", "a", true, {}),
    dsStep(3, "tf/apply", "b", false, {}),
    dsStep(4, "tf/plan", "c", true, {}),
    dsStep(5, "tf/init", "d", true, {}),
  ]), [{ dir: "0", workspace: "default" }]);
  assert.deepEqual(rows.map((r) => [r.dir, r.success, r.op]), [
    ["b", false, "apply"], ["a", true, "apply"], ["c", true, "plan"], ["d", true, "other"], ["0", null, "other"],
  ]);
});
test("runSummary: totals are null when no dirspace reported a summary", () => {
  assert.equal(runSummary(groupByDirspace(STEPS)).totals, null);
  assert.deepEqual(runSummary([]), { rows: [], totals: null });
});

test("runSummary: listed dirspaces without output have no result and sort last", () => {
  const { rows } = runSummary(
    groupByDirspace([dsStep(0, "tf/plan", "b", false, {})]),
    [{ dir: "a", workspace: "default" }, { dir: "b", workspace: "default" }, { dir: "c", workspace: "default" }],
  );
  assert.deepEqual(rows.map((r) => [r.dir, r.success, r.op]), [["b", false, "plan"], ["a", null, "other"], ["c", null, "other"]]);
});
test("summaryResult: labels per row and liveness", () => {
  const row = { dir: "a", workspace: "default", success: true, op: "plan", hasChanges: false, resources: null } as const;
  assert.equal(summaryResult({ ...row, success: false }, false), "failed");
  assert.equal(summaryResult({ ...row, success: null }, true), "pending");
  assert.equal(summaryResult({ ...row, success: null }, false), "not run");
  assert.equal(summaryResult({ ...row, op: "apply" }, false), "applied");
  assert.equal(summaryResult({ ...row, hasChanges: true }, false), "changes");
  assert.equal(summaryResult(row, false), "no changes");
  assert.equal(summaryResult({ ...row, op: "other" }, false), "success");
});
test("summaryCountsLine: PR comment wording, waiting dirspaces appended", () => {
  const plan = runSummary(
    groupByDirspace([
      dsStep(0, "tf/plan", "a", true, { has_changes: true }),
      dsStep(1, "tf/plan", "b", true, { has_changes: false }),
      dsStep(2, "tf/plan", "c", false, {}),
    ]),
    [{ dir: "d", workspace: "default" }],
  );
  assert.equal(summaryCountsLine(plan, false, true), "4 dirspaces · 1 with changes · 1 no changes · 1 failed · 1 pending");
  assert.equal(summaryCountsLine(plan, false, false), "4 dirspaces · 1 with changes · 1 no changes · 1 failed · 1 not run");
  const apply = runSummary(groupByDirspace([dsStep(0, "tf/apply", "a", true, {})]));
  assert.equal(summaryCountsLine(apply, true, false), "1 dirspace · 1 applied · 0 failed");
});
test("dirspaceAnchor: distinct ids for distinct dirspaces", () => {
  assert.notEqual(dirspaceAnchor("a--b", "c"), dirspaceAnchor("a", "b--c"));
  assert.equal(dirspaceAnchor("x/y", "default"), "dirspace-x%2Fy:default");
});

// --- plan diff vs body ---
test("planDiff: only the dedicated plan field, no fallback", () => {
  assert.equal(planDiff({ plan: "P", text: "T" }), "P");
  assert.equal(planDiff({ text: "T" }), "");
});

// --- step status / visibility ---
const okStep: RawStep = { idx: 0, step: "run", success: true, scope: null, payload: {} };
const failStep: RawStep = { idx: 1, step: "run", success: false, scope: null, payload: {} };
const ignoredStep: RawStep = { ...failStep, ignoreErrors: true };
test("stepStatus: success / failure / ignored", () => {
  assert.equal(stepStatus(okStep), "success");
  assert.equal(stepStatus(failStep), "failure");
  assert.equal(stepStatus(ignoredStep), "ignored");
  // legacy payload-borne flag
  assert.equal(stepStatus({ ...failStep, payload: { ignore_errors: true } }), "ignored");
});
test("isActualFailure: ignored failures do not count", () => {
  assert.equal(isActualFailure(failStep), true);
  assert.equal(isActualFailure(ignoredStep), false);
  assert.equal(isActualFailure(okStep), false);
});
test("isStepVisible: absent visible_on shows only on real failure", () => {
  assert.equal(isStepVisible(okStep), false);
  assert.equal(isStepVisible(failStep), true);
  assert.equal(isStepVisible(ignoredStep), false);
});
test("isStepVisible: explicit settings", () => {
  const vis = (st: RawStep, visible_on: string) =>
    isStepVisible({ ...st, payload: { ...st.payload, visible_on } });
  assert.equal(vis(okStep, "always"), true);
  assert.equal(vis(failStep, "always"), true);
  assert.equal(vis(okStep, "failure"), false);
  assert.equal(vis(failStep, "failure"), true);
  assert.equal(vis(failStep, "error"), true); // legacy alias
  assert.equal(vis(okStep, "success"), true);
  assert.equal(vis(failStep, "success"), false);
  // An ignored failure is effectively successful, so "success" shows it —
  // whether the flag lives on the row or in the payload.
  assert.equal(vis({ ...ignoredStep, payload: {} }, "success"), true);
  assert.equal(isStepVisible({ ...ignoredStep, payload: { visible_on: "success" } }), true);
  assert.equal(vis(okStep, "sometimes"), true); // unknown fails open
});

// --- ordered step lists ---
test("groupSteps: init/plan/apply plus others, ordered by idx", () => {
  const g = groupByDirspace(STEPS)[0];
  g.others.push({ idx: 9, step: "run", success: true, scope: g.plan!.scope, payload: {} });
  assert.deepEqual(groupSteps(g).map((s) => s.step), ["tf/init", "tf/plan", "run"]);
});
test("hookSteps: checkout/env plus others, cost excluded", () => {
  const h = runHooks(STEPS);
  assert.deepEqual(hookSteps(h).map((s) => s.step), ["checkout", "env"]);
});

// --- step labels ---
test("stepLabel: known names and engine generalization", () => {
  assert.equal(stepLabel("tf/plan"), "Plan");
  assert.equal(stepLabel("tf/cost-estimation"), "Cost estimation");
  assert.equal(stepLabel("custom/plan"), "Custom Plan");
  assert.equal(stepLabel("pulumi/apply"), "Pulumi Apply");
  assert.equal(stepLabel("run"), "Run");
  assert.equal(stepLabel("something/else"), "something/else");
});

// --- run outcome ---
test("runOutcome: completed + all success -> succeeded", () => {
  assert.equal(runOutcome("completed", STEPS), "succeeded");
});
test("runOutcome: a failed step -> failed", () => {
  assert.equal(runOutcome("completed", [{ ...STEPS[3], success: false }]), "failed");
});
test("runOutcome: unrecognized state -> unknown (never a green chip), unless a step failed", () => {
  assert.equal(runOutcome("", STEPS), "unknown");
  assert.equal(runOutcome("something-new", STEPS), "unknown");
  assert.equal(runOutcome("something-new", [{ ...STEPS[3], success: false }]), "failed");
});
test("runOutcome: an ignored failure stays succeeded", () => {
  assert.equal(runOutcome("completed", [{ ...STEPS[3], success: false, ignoreErrors: true }]), "succeeded");
  // ...and does not force "failed" onto an unrecognized state either.
  assert.equal(runOutcome("something-new", [{ ...STEPS[3], success: false, ignoreErrors: true }]), "unknown");
});
test("runOutcome: lifecycle states pass through", () => {
  assert.equal(runOutcome("running", STEPS), "running");
  assert.equal(runOutcome("queued", []), "queued");
  assert.equal(runOutcome("aborted", []), "aborted");
});
test("runOutcomeFromSuccess: mirrors runOutcome on the aggregated result", () => {
  assert.equal(runOutcomeFromSuccess("completed", true), "succeeded");
  assert.equal(runOutcomeFromSuccess("completed", null), "succeeded");
  assert.equal(runOutcomeFromSuccess("completed", false), "failed");
  assert.equal(runOutcomeFromSuccess("something-new", false), "failed");
  assert.equal(runOutcomeFromSuccess("running", false), "running");
  assert.equal(runOutcomeFromSuccess("queued", null), "queued");
  assert.equal(runOutcomeFromSuccess("aborted", true), "aborted");
});
test("runOutcomeFromSuccess: a null or unrecognised state never reads as success", () => {
  assert.equal(runOutcomeFromSuccess("", null), "unknown");
  assert.equal(runOutcomeFromSuccess("", true), "unknown");
  assert.equal(runOutcomeFromSuccess("something-new", true), "unknown");
});
test("runListOutcome: mirrors runOutcome from an aggregate failure count", () => {
  assert.equal(runListOutcome("queued", 0), "queued");
  assert.equal(runListOutcome("running", 0), "running");
  assert.equal(runListOutcome("aborted", 3), "aborted");
  assert.equal(runListOutcome("completed", 0), "succeeded");
  assert.equal(runListOutcome("completed", 1), "failed");
  // Unknown lifecycle states: a failure still decides, but no failure is not
  // a success (same rule as runOutcomeFromSuccess).
  assert.equal(runListOutcome("someday_new", 0), "unknown");
  assert.equal(runListOutcome("", 0), "unknown");
  assert.equal(runListOutcome("someday_new", 2), "failed");
});

test("runKindLabel: pr reads as PR, other kinds as stored", () => {
  assert.equal(runKindLabel("pr"), "PR");
  assert.equal(runKindLabel("drift"), "drift");
  assert.equal(runKindLabel(""), "");
});

if (failures > 0) { console.error(`\n${failures} test(s) failed`); process.exit(1); }
else console.log("\nall decode tests passed");
