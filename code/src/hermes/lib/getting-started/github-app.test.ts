import assert from "node:assert/strict";
import {
  GITHUB_APP_NAME_MAX,
  GITHUB_APP_RESULT_MESSAGE,
  githubAppNameSuggestion,
  githubAppResult,
  githubConnectStep,
  githubConnectSteps,
  githubInstallUrl,
} from "./github-app";

const tests: Array<{ name: string; run: () => void }> = [
  {
    name: "a server that creates Apps offers the create step first",
    run: () => {
      assert.deepEqual(githubConnectSteps(true), ["create", "install", "link", "done"]);
    },
  },
  {
    name: "a server that does not create Apps offers no create step",
    run: () => {
      assert.deepEqual(githubConnectSteps(false), ["install", "link", "done"]);
    },
  },
  {
    name: "the claim return shows the link step",
    run: () => {
      assert.equal(githubConnectStep({ claimResult: "ready", creatable: true, ready: false }), "link");
      assert.equal(
        githubConnectStep({ claimResult: "installed", creatable: true, ready: true }),
        "link",
      );
    },
  },
  {
    name: "the install link opens the install form with the console's state",
    run: () => {
      assert.equal(
        githubInstallUrl("https://github.com/apps/terrateam-action"),
        "https://github.com/apps/terrateam-action/installations/new?state=stategraph",
      );
      assert.equal(
        githubInstallUrl("https://github.com/apps/stategraph-1a2b3c4d/"),
        "https://github.com/apps/stategraph-1a2b3c4d/installations/new?state=stategraph",
      );
    },
  },
  {
    name: "an engine that holds an App shows install",
    run: () => {
      assert.equal(githubConnectStep({ claimResult: null, creatable: true, ready: true }), "install");
    },
  },
  {
    name: "no App, or one the engine has not loaded yet, shows create",
    run: () => {
      assert.equal(githubConnectStep({ claimResult: null, creatable: true, ready: false }), "create");
    },
  },
  {
    name: "a server that cannot create an App shows install",
    run: () => {
      assert.equal(
        githubConnectStep({ claimResult: null, creatable: false, ready: false }),
        "install",
      );
    },
  },
  {
    name: "only the callback's results are results",
    run: () => {
      assert.equal(githubAppResult("created"), "created");
      assert.equal(githubAppResult("expired"), "expired");
      assert.equal(githubAppResult("conflict"), "conflict");
      assert.equal(githubAppResult("error"), "error");
      assert.equal(githubAppResult("ready"), null);
      assert.equal(githubAppResult(null), null);
    },
  },
  {
    name: "every result the operator must act on has a sentence",
    run: () => {
      for (const result of ["expired", "conflict", "error"] as const) {
        assert.ok(GITHUB_APP_RESULT_MESSAGE[result].length > 0, result);
      }
    },
  },
  {
    name: "a suggested name fits GitHub's limit and slug charset",
    run: () => {
      const name = githubAppNameSuggestion();
      assert.ok(name.length <= GITHUB_APP_NAME_MAX, name);
      assert.match(name, /^stategraph-[0-9a-f]{8}$/);
    },
  },
  {
    name: "two suggested names differ",
    run: () => {
      const names = new Set(Array.from({ length: 50 }, () => githubAppNameSuggestion()));
      assert.equal(names.size, 50);
    },
  },
];

let failed = 0;
for (const t of tests) {
  try {
    t.run();
    console.log(`ok - ${t.name}`);
  } catch (e) {
    failed += 1;
    console.error(`not ok - ${t.name}`);
    console.error(e);
  }
}
if (failed > 0) process.exit(1);
