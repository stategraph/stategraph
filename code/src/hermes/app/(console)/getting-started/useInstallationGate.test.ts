import assert from "node:assert/strict";
import {
  installationGateForProvider,
  type InstallationListState,
} from "./useInstallationGate";

const row = (provider: "github" | "gitlab") =>
  ({ provider, installation_core_id: `${provider}-1` }) as InstallationListState["rows"][number];

const tests: Array<{ name: string; run: () => void }> = [
  {
    name: "a ready list is linked only for a provider it holds",
    run: () => {
      const state: InstallationListState = { status: "ready", rows: [row("gitlab")] };
      assert.equal(installationGateForProvider(state, "github"), "empty");
      assert.equal(installationGateForProvider(state, "gitlab"), "linked");
      assert.equal(installationGateForProvider(state, null), "linked");
      assert.equal(
        installationGateForProvider({ status: "ready", rows: [] }, null),
        "empty",
      );
    },
  },
  {
    name: "a list that is not ready reports its own status",
    run: () => {
      assert.equal(
        installationGateForProvider({ status: "loading", rows: [] }, "github"),
        "loading",
      );
      assert.equal(
        installationGateForProvider({ status: "forbidden", rows: [] }, "github"),
        "forbidden",
      );
      assert.equal(
        installationGateForProvider(
          { status: "error", rows: [], message: "boom" },
          "github",
        ),
        "error",
      );
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
