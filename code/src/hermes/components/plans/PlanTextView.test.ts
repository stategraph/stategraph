import { trimPlanStdout } from "./PlanTextView";

const fullStdout = `module.state_57c7b.module.network.null_resource.vpc: Refreshing state... [id=12345]
module.state_57c7b.module.platform.null_resource.cluster: Refreshing state... [id=67890]

Note: Objects have changed outside of Terraform

OpenTofu detected the following changes made outside of OpenTofu since the
last "tofu apply" which may have affected this plan:

OpenTofu used the selected providers to generate the following execution
plan. Resource actions are indicated with the following symbols:
  ~ update in-place
-/+ destroy and then create replacement

OpenTofu will perform the following actions:

  # module.state_57c7b.module.platform.null_resource.cluster must be replaced
-/+ resource "null_resource" "cluster" {
      ~ id       = "6396..." -> (known after apply)
      ~ triggers = { # forces replacement
          ~ "version" = "1" -> "2"
        }
    }

Plan: 1 to add, 0 to change, 1 to destroy.

─────────────────────────────────────────────────────────────────────────────

Saved the plan to: /tmp/sg_actuator_01b0b6/plan.out

To perform exactly these actions, run the following command to apply:
    tofu apply "/tmp/sg_actuator_01b0b6/plan.out"
`;

interface TestCase {
  name: string;
  fn: () => boolean;
}

const tests: TestCase[] = [
  {
    name: "slices from 'will perform the following actions' through 'Plan:'",
    fn: () => {
      const out = trimPlanStdout(fullStdout);
      return (
        out.startsWith("OpenTofu will perform the following actions:") &&
        out.endsWith("Plan: 1 to add, 0 to change, 1 to destroy.")
      );
    },
  },
  {
    name: "drops the refreshing-state preamble",
    fn: () => !trimPlanStdout(fullStdout).includes("Refreshing state"),
  },
  {
    name: "drops the 'Saved the plan to' footer",
    fn: () => !trimPlanStdout(fullStdout).includes("Saved the plan to"),
  },
  {
    name: "drops the 'tofu apply' command footer",
    fn: () => !trimPlanStdout(fullStdout).includes("tofu apply "),
  },
  {
    name: "matches Terraform banner too (not just OpenTofu)",
    fn: () => {
      const tf = fullStdout.replace(/OpenTofu/g, "Terraform");
      const out = trimPlanStdout(tf);
      return out.startsWith("Terraform will perform the following actions:");
    },
  },
  {
    name: "falls back to full text when no banner is present",
    fn: () => {
      const odd = "some custom output\nPlan: 1 to add, 0 to change, 0 to destroy.\nfooter";
      return trimPlanStdout(odd) === odd;
    },
  },
  {
    name: "falls back to full text when no Plan: summary is present",
    fn: () => {
      const odd =
        "OpenTofu will perform the following actions:\n  # something\nNo changes.";
      return trimPlanStdout(odd) === odd;
    },
  },
];

let passed = 0;
let failed = 0;
for (const t of tests) {
  let ok = false;
  try {
    ok = t.fn();
  } catch (e) {
    console.error(`THREW: ${t.name}`, e);
  }
  if (ok) {
    passed++;
    console.log(`  ✓ ${t.name}`);
  } else {
    failed++;
    console.error(`  ✗ ${t.name}`);
  }
}
console.log(`\n${passed}/${tests.length} passed`);
process.exit(failed === 0 ? 0 : 1);
