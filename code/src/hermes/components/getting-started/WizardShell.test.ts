import assert from "node:assert/strict";
import { wizardProgress } from "./WizardShell";

const tests: Array<{ name: string; run: () => void }> = [
  {
    name: "computes progress for arbitrary string step ids",
    run: () => {
      assert.deepEqual(wizardProgress(["first", "second", "third"], "second"), [
        "completed",
        "current",
        "upcoming",
      ]);
    },
  },
  {
    name: "a step outside the list marks every step upcoming",
    run: () => {
      assert.deepEqual(wizardProgress(["first", "second"], "other"), [
        "upcoming",
        "upcoming",
      ]);
    },
  },
];

let failed = 0;
for (const test of tests) {
  try {
    test.run();
    console.log(`PASS: ${test.name}`);
  } catch (error) {
    failed += 1;
    console.error(`FAIL: ${test.name}`);
    console.error(error);
  }
}

process.exit(failed === 0 ? 0 : 1);
