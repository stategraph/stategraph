import assert from "node:assert/strict";
import {
  DEMO_REPOSITORY_SEARCH_VALUE,
  INITIAL_ORCHESTRATION_STATE,
  resumeOrchestrationState,
  ORCHESTRATION_STEPS,
  clearOrchestrationState,
  decodeOrchestrationState,
  fillOrchestrationSearchParams,
  isOrchestrationStep,
  isLiveOrchestrationTenantChange,
  isRepositorySlug,
  isRepositorySource,
  isVcsProvider,
  loadOrchestrationState,
  nextOrchestrationStepAfterRepository,
  orchestrationRailSteps,
  orchestrationStorageKey,
  orchestrationOverridesFromSearchParams,
  orchestrationStepSearchParams,
  resetOrchestrationSearchParams,
  previousOrchestrationStep,
  resolveOrchestrationState,
  saveOrchestrationState,
  searchParamsMatchTenant,
  stripTenantOrchestrationSearchParams,
  type OrchestrationState,
} from "./orchestration-state";

class MemoryStorage {
  private values = new Map<string, string>();

  getItem(key: string): string | null {
    return this.values.get(key) ?? null;
  }

  setItem(key: string, value: string): void {
    this.values.set(key, value);
  }

  removeItem(key: string): void {
    this.values.delete(key);
  }
}

const tests: Array<{ name: string; run: () => void }> = [
  {
    name: "registers the URL step ids and the three rails",
    run: () => {
      assert.deepEqual(ORCHESTRATION_STEPS, [
        "connect",
        "repo",
        "runnable",
        "credentials",
        "wait",
        "fork",
        "actions",
        "change",
        "done",
      ]);
      assert.equal(isOrchestrationStep("wait"), true);
      assert.equal(isOrchestrationStep("fork"), true);
      assert.equal(isOrchestrationStep("unknown"), false);
      assert.deepEqual(orchestrationRailSteps("github", "own"), [
        "connect",
        "repo",
        "runnable",
        "credentials",
        "wait",
        "done",
      ]);
      assert.deepEqual(orchestrationRailSteps("gitlab", "own"), orchestrationRailSteps(null, "own"));
      assert.deepEqual(orchestrationRailSteps("github", "demo"), [
        "connect",
        "repo",
        "fork",
        "actions",
        "change",
        "done",
      ]);
      assert.deepEqual(orchestrationRailSteps("gitlab", "demo"), [
        "connect",
        "repo",
        "fork",
        "change",
        "done",
      ]);
      assert.deepEqual(orchestrationRailSteps(null, "demo"), orchestrationRailSteps("github", "demo"));
    },
  },
  {
    name: "uses a tenant-specific storage key",
    run: () => {
      assert.equal(
        orchestrationStorageKey("tenant-a"),
        "stategraph-orchestration-onboarding:tenant-a",
      );
      assert.notEqual(orchestrationStorageKey("tenant-a"), orchestrationStorageKey("tenant-b"));
    },
  },
  {
    name: "round trips a valid state",
    run: () => {
      const storage = new MemoryStorage();
      const state: OrchestrationState = {
        currentStep: "credentials",
        provider: "github",
        repo: "platform/infrastructure",
        repositorySource: "demo",
        credentials: "done",
      };
      saveOrchestrationState("tenant-a", state, storage);
      assert.deepEqual(loadOrchestrationState("tenant-a", storage), state);
    },
  },
  {
    name: "falls back safely for malformed and unknown stored values",
    run: () => {
      const storage = new MemoryStorage();
      storage.setItem(orchestrationStorageKey("tenant-a"), "not-json");
      assert.deepEqual(loadOrchestrationState("tenant-a", storage), INITIAL_ORCHESTRATION_STATE);
      assert.deepEqual(
        decodeOrchestrationState({
          currentStep: "old-step",
          provider: "other",
          repo: 42,
          repositorySource: "unknown",
          credentials: true,
        }),
        INITIAL_ORCHESTRATION_STATE,
      );
    },
  },
  {
    name: "fills missing fields in older records with defaults",
    run: () => {
      assert.deepEqual(decodeOrchestrationState({ currentStep: "repo", repo: "" }), {
        currentStep: "repo",
        provider: null,
        repo: "",
        repositorySource: "own",
        credentials: null,
      });
    },
  },
  {
    name: "lets URL overrides win while retaining absent stored values",
    run: () => {
      const stored: OrchestrationState = {
        currentStep: "runnable",
        provider: "github",
        repo: "platform/infrastructure",
        repositorySource: "own",
        credentials: null,
      };
      assert.deepEqual(
        resolveOrchestrationState(stored, {
          currentStep: "wait",
          provider: "gitlab",
          repo: "group/live",
        }),
        {
          currentStep: "wait",
          provider: "gitlab",
          repo: "group/live",
          repositorySource: "own",
          credentials: null,
        },
      );
      assert.deepEqual(resolveOrchestrationState(stored, { currentStep: "repo" }), {
        ...stored,
        currentStep: "repo",
      });
      const demo = resolveOrchestrationState(stored, { repositorySource: "demo" });
      assert.deepEqual(demo, { ...stored, repositorySource: "demo" });
      assert.deepEqual(
        resolveOrchestrationState(demo, { repositorySource: "own" }),
        stored,
      );
      assert.deepEqual(
        resolveOrchestrationState(
          {
            ...stored,
            repo: "example/fork",
            repositorySource: "demo",
          },
          orchestrationOverridesFromSearchParams(
            new URLSearchParams(
              "step=repo&provider=github&repo=platform%2Freal",
            ),
          ),
        ),
        {
          ...stored,
          currentStep: "repo",
          repo: "platform/real",
          repositorySource: "own",
        },
      );
    },
  },
  {
    name: "reads explicit URL values and preserves an explicit empty repository",
    run: () => {
      assert.deepEqual(
        orchestrationOverridesFromSearchParams(
          new URLSearchParams("step=wait&provider=gitlab&repo="),
        ),
        {
          currentStep: "wait",
          provider: "gitlab",
          repo: "",
          repositorySource: "own",
        },
      );
      assert.deepEqual(
        orchestrationOverridesFromSearchParams(
          new URLSearchParams(
            `step=wait&provider=gitlab&repo=group%2Ffork&demo=${DEMO_REPOSITORY_SEARCH_VALUE}`,
          ),
        ),
        {
          currentStep: "wait",
          provider: "gitlab",
          repo: "group/fork",
          repositorySource: "demo",
        },
      );
      assert.deepEqual(orchestrationOverridesFromSearchParams(new URLSearchParams()), {});
    },
  },
  {
    name: "fills a bare URL from storage without replacing explicit URL values",
    run: () => {
      const stored: OrchestrationState = {
        currentStep: "credentials",
        provider: "github",
        repo: "platform/infrastructure",
        repositorySource: "own",
        credentials: null,
      };
      assert.equal(
        fillOrchestrationSearchParams(new URLSearchParams("path=orchestrate"), stored).toString(),
        "path=orchestrate&step=credentials&provider=github&repo=platform%2Finfrastructure",
      );
      assert.equal(
        fillOrchestrationSearchParams(
          new URLSearchParams("path=orchestrate&step=repo&provider=gitlab&repo=group%2Flive"),
          stored,
        ).toString(),
        "path=orchestrate&step=repo&provider=gitlab&repo=group%2Flive",
      );
      assert.equal(
        fillOrchestrationSearchParams(new URLSearchParams("path=orchestrate"), {
          ...stored,
          repositorySource: "demo",
        }).toString(),
        `path=orchestrate&step=credentials&provider=github&repo=platform%2Finfrastructure&demo=${DEMO_REPOSITORY_SEARCH_VALUE}`,
      );
    },
  },
  {
    name: "reset replaces populated onboarding parameters with the connect step",
    run: () => {
      assert.equal(
        resetOrchestrationSearchParams(
          new URLSearchParams(
            `tenant=tenant-a&path=orchestrate&step=done&provider=github&repo=platform%2Finfrastructure&demo=${DEMO_REPOSITORY_SEARCH_VALUE}`,
          ),
        ).toString(),
        "tenant=tenant-a&path=orchestrate&step=connect",
      );
    },
  },
  {
    name: "builds an atomic provider and step transition from Connect to Repository",
    run: () => {
      assert.equal(
        orchestrationStepSearchParams(
          new URLSearchParams("tenant=tenant-a&path=orchestrate&step=connect"),
          "repo",
          "github",
          "",
        ).toString(),
        "tenant=tenant-a&path=orchestrate&step=repo&provider=github&repo=",
      );
      assert.equal(
        orchestrationStepSearchParams(
          new URLSearchParams("tenant=tenant-a&path=orchestrate&step=repo"),
          "wait",
          "github",
          "group/fork",
          "demo",
        ).toString(),
        `tenant=tenant-a&path=orchestrate&step=wait&provider=github&repo=group%2Ffork&demo=${DEMO_REPOSITORY_SEARCH_VALUE}`,
      );
    },
  },
  {
    name: "walks each rail forward and back",
    run: () => {
      assert.equal(nextOrchestrationStepAfterRepository("own"), "runnable");
      assert.equal(nextOrchestrationStepAfterRepository("demo"), "fork");
      assert.equal(previousOrchestrationStep("wait"), "credentials");
      assert.equal(previousOrchestrationStep("repo"), "connect");
      assert.equal(previousOrchestrationStep("connect"), null);
      assert.equal(previousOrchestrationStep("fork", "demo", "github"), "repo");
      assert.equal(previousOrchestrationStep("change", "demo", "github"), "actions");
      assert.equal(previousOrchestrationStep("change", "demo", "gitlab"), "fork");
      assert.equal(previousOrchestrationStep("done", "demo", "gitlab"), "change");
    },
  },
  {
    name: "a finished walkthrough starts fresh unless the URL names a step",
    run: () => {
      const done = {
        ...INITIAL_ORCHESTRATION_STATE,
        currentStep: "done" as const,
        provider: "github" as const,
        repositorySource: "demo" as const,
      };
      assert.equal(resumeOrchestrationState(done, {}).currentStep, "connect");
      assert.equal(resumeOrchestrationState(done, {}).provider, null);
      assert.equal(resumeOrchestrationState(done, { currentStep: "done" }).currentStep, "done");
      const midway = { ...done, currentStep: "fork" as const };
      assert.equal(resumeOrchestrationState(midway, {}).currentStep, "fork");
    },
  },
  {
    name: "strips tenant-scoped answers during a live tenant switch",
    run: () => {
      assert.equal(
        stripTenantOrchestrationSearchParams(
          new URLSearchParams(
            `tenant=tenant-b&state=state-a&path=orchestrate&step=wait&provider=github&repo=platform%2Finfrastructure&demo=${DEMO_REPOSITORY_SEARCH_VALUE}`,
          ),
        ).toString(),
        "tenant=tenant-b&state=state-a&path=orchestrate",
      );
    },
  },
  {
    name: "distinguishes live onboarding tenant switches from initial deep links",
    run: () => {
      assert.equal(
        isLiveOrchestrationTenantChange(
          "/getting-started/",
          new URLSearchParams("tenant=tenant-a&path=orchestrate"),
          "tenant-b",
        ),
        true,
      );
      assert.equal(
        isLiveOrchestrationTenantChange(
          "/getting-started",
          new URLSearchParams("path=orchestrate&step=wait"),
          "tenant-b",
        ),
        false,
      );
      assert.equal(
        isLiveOrchestrationTenantChange(
          "/getting-started",
          new URLSearchParams("tenant=tenant-a&path=import"),
          "tenant-b",
        ),
        false,
      );
    },
  },
  {
    name: "a URL belongs to the current tenant only when it names that tenant or none",
    run: () => {
      assert.equal(searchParamsMatchTenant(new URLSearchParams("path=orchestrate"), "tenant-b"), true);
      assert.equal(
        searchParamsMatchTenant(new URLSearchParams("tenant=tenant-b&path=orchestrate"), "tenant-b"),
        true,
      );
      assert.equal(
        searchParamsMatchTenant(
          new URLSearchParams("tenant=tenant-a&path=orchestrate&step=wait&provider=github&repo=a%2Finfra"),
          "tenant-b",
        ),
        false,
      );
    },
  },
  {
    name: "clears only the selected tenant storage record",
    run: () => {
      const storage = new MemoryStorage();
      storage.setItem("stategraph-getting-started", "import-state");
      saveOrchestrationState(
        "tenant-a",
        {
          ...INITIAL_ORCHESTRATION_STATE,
          provider: "github",
          repo: "group/demo",
          repositorySource: "demo",
        },
        storage,
      );
      const tenantBState: OrchestrationState = {
        ...INITIAL_ORCHESTRATION_STATE,
        provider: "gitlab",
        repo: "group/project",
      };
      saveOrchestrationState("tenant-b", tenantBState, storage);
      clearOrchestrationState("tenant-a", storage);
      assert.deepEqual(
        loadOrchestrationState("tenant-a", storage),
        INITIAL_ORCHESTRATION_STATE,
      );
      assert.deepEqual(loadOrchestrationState("tenant-b", storage), tenantBState);
      assert.equal(storage.getItem("stategraph-getting-started"), "import-state");
    },
  },
  {
    name: "accepts skippable empty repositories and validates project paths",
    run: () => {
      assert.equal(decodeOrchestrationState({ repo: "" }).repo, "");
      assert.equal(isRepositorySlug("platform/infrastructure"), true);
      assert.equal(isRepositorySlug("group/subgroup/infrastructure"), true);
      assert.equal(isRepositorySlug("infrastructure"), false);
      assert.equal(isRepositorySlug("group//infrastructure"), false);
    },
  },
  {
    name: "defaults old and invalid repository sources to own",
    run: () => {
      assert.equal(decodeOrchestrationState({ repo: "group/project" }).repositorySource, "own");
      assert.equal(
        decodeOrchestrationState({ repositorySource: "unknown" }).repositorySource,
        "own",
      );
      assert.equal(isRepositorySource("own"), true);
      assert.equal(isRepositorySource("demo"), true);
      assert.equal(isRepositorySource(null), false);
    },
  },
  {
    name: "accepts only supported providers",
    run: () => {
      assert.equal(isVcsProvider("github"), true);
      assert.equal(isVcsProvider("gitlab"), true);
      assert.equal(isVcsProvider("other"), false);
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
