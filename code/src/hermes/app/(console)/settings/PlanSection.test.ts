/**
 * Run with: npx tsx 'app/(console)/settings/PlanSection.test.ts'
 */

import assert from "node:assert";
import { humanize, mapPlanRow, planQuery, stripePricingTable, trialText } from "./PlanSection";

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

test("the query reads each provider's installation table under one column set", () => {
  assert.equal(
    planQuery("github"),
    "select login as name, tier, account_status, trial_ends_at from github_installations limit 50",
  );
  assert.equal(
    planQuery("gitlab"),
    "select name, tier, account_status, trial_ends_at from gitlab_installations limit 50",
  );
});

test("rows keep the provider and turn an empty trial date into null", () => {
  const row = mapPlanRow("github", { name: "acme", tier: "free-2026-07-10", account_status: "active", trial_ends_at: "" });
  assert.deepEqual(row, { provider: "github", name: "acme", tier: "free-2026-07-10", status: "active", trialEndsAt: null });
});

test("tier and status names read as words", () => {
  assert.equal(humanize("free-2026-07-10"), "Free");
  assert.equal(humanize("trial_ending"), "Trial ending");
  assert.equal(humanize(""), "");
});

test("trial text counts days from now", () => {
  const now = Date.parse("2026-09-27T12:00:00Z");
  assert.match(trialText("2026-10-07T00:00:00Z", now) ?? "", /^Trial ends in 10 days, on /);
  assert.match(trialText("2026-09-28T13:00:00Z", now) ?? "", /^Trial ends in 2 days|^Trial ends tomorrow/);
  assert.match(trialText("2026-09-01T00:00:00Z", now) ?? "", /^Trial ended on /);
  assert.equal(trialText(null, now), null);
  assert.equal(trialText("not a date", now), null);
});

function headWith(metas: Record<string, string>): Pick<Document, "querySelector"> {
  return {
    querySelector: ((selector: string) => {
      const name = /^meta\[name="([^"]+)"\]$/.exec(selector)?.[1];
      return name !== undefined && name in metas ? { content: metas[name] } : null;
    }) as Document["querySelector"],
  };
}

test("the pricing table needs both the publishable key and the table id", () => {
  assert.deepEqual(
    stripePricingTable(
      headWith({
        "stategraph-stripe-publishable-key": "pk_test_1",
        "stategraph-stripe-pricing-table-id": "prctbl_1",
      }),
    ),
    { publishableKey: "pk_test_1", pricingTableId: "prctbl_1" },
  );
  assert.equal(stripePricingTable(headWith({ "stategraph-stripe-publishable-key": "pk_test_1" })), null);
  assert.equal(
    stripePricingTable(
      headWith({ "stategraph-stripe-publishable-key": " ", "stategraph-stripe-pricing-table-id": "prctbl_1" }),
    ),
    null,
  );
  assert.equal(stripePricingTable(headWith({})), null);
});

if (failures > 0) process.exit(1);
