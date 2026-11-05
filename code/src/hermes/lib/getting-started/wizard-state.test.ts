/**
 * Tests for the state import wizard state machine
 * Run with: npx tsx lib/getting-started/wizard-state.test.ts
 */

import {
  getSteps,
  getStepsForState,
  getStepIndex,
  getStepCount,
  isFirstStep,
  isLastStep,
  stepFromParam,
  STEP_LABELS,
  type WizardStep,
} from "./wizard-state";

import {
  CLI_COMMANDS,
  ENGINE_CONFIG,
  MIGRATION_STEPS_OVERVIEW,
  VERIFICATION_CHECKLIST,
  MIGRATION_PREREQUISITES,
  DOC_LINKS,
  apiKeyCommand,
  githubSecretsCommands,
  gitlabVariablesTable,
  tenantListExample,
} from "./doc-constants";

console.log("Testing state import wizard\n");
console.log("=".repeat(60));

let passed = 0;
let failed = 0;

interface TestCase {
  name: string;
  fn: () => boolean;
}

const tests: TestCase[] = [
  {
    name: "Without orchestration the flow has 5 steps: api-key, credentials, import, verify, done",
    fn: () => {
      const steps = getSteps(false);
      return (
        steps.length === 5 &&
        steps[0] === "velocity-api-key" &&
        steps[1] === "velocity-credentials" &&
        steps[2] === "velocity-import" &&
        steps[3] === "velocity-verify" &&
        steps[4] === "velocity-done"
      );
    },
  },
  {
    name: "With orchestration the engine step sits between verify and done",
    fn: () => {
      const steps = getSteps(true);
      return (
        steps.length === 6 &&
        steps[3] === "velocity-verify" &&
        steps[4] === "velocity-orchestration" &&
        steps[5] === "velocity-done"
      );
    },
  },
  {
    name: "A deep link onto the engine step keeps it in the list before the installation list answers",
    fn: () => {
      const steps = getStepsForState({ orchestration: false, currentStep: "velocity-orchestration" });
      return steps.length === 6 && steps[4] === "velocity-orchestration";
    },
  },
  {
    name: "getStepsForState without orchestration and off the engine step is the 5-step list",
    fn: () => {
      return getStepsForState({ orchestration: false, currentStep: "velocity-verify" }).length === 5;
    },
  },
  {
    name: "getStepIndex follows the list the orchestration flag selects",
    fn: () => {
      return (
        getStepIndex("velocity-api-key", false) === 0 &&
        getStepIndex("velocity-done", false) === 4 &&
        getStepIndex("velocity-orchestration", false) === -1 &&
        getStepIndex("velocity-orchestration", true) === 4 &&
        getStepIndex("velocity-done", true) === 5
      );
    },
  },
  {
    name: "getStepCount returns 5 without and 6 with orchestration",
    fn: () => getStepCount(false) === 5 && getStepCount(true) === 6,
  },
  {
    name: "isFirstStep identifies the API key step as first",
    fn: () => {
      return (
        isFirstStep("velocity-api-key", false) === true &&
        isFirstStep("velocity-api-key", true) === true &&
        isFirstStep("velocity-credentials", false) === false
      );
    },
  },
  {
    name: "isLastStep identifies done as last in both lists",
    fn: () => {
      return (
        isLastStep("velocity-done", false) === true &&
        isLastStep("velocity-done", true) === true &&
        isLastStep("velocity-orchestration", true) === false &&
        isLastStep("velocity-verify", false) === false
      );
    },
  },
  {
    name: "stepFromParam accepts only the engine step",
    fn: () => {
      return (
        stepFromParam("orchestration") === "velocity-orchestration" &&
        stepFromParam("velocity-done") === null &&
        stepFromParam("") === null &&
        stepFromParam(null) === null
      );
    },
  },
  {
    name: "All wizard steps have labels",
    fn: () => {
      const allSteps: WizardStep[] = [
        "velocity-api-key",
        "velocity-credentials",
        "velocity-import",
        "velocity-verify",
        "velocity-orchestration",
        "velocity-done",
      ];
      return allSteps.every(
        (step) => typeof STEP_LABELS[step] === "string" && STEP_LABELS[step].length > 0
      );
    },
  },

  // =========================================================================
  // Doc-derived constants: CLI commands
  // =========================================================================
  {
    name: "CLI_COMMANDS.exportApiKey and exportApiBase contain correct env vars",
    fn: () => {
      return (
        CLI_COMMANDS.exportApiKey.includes("STATEGRAPH_API_KEY") &&
        CLI_COMMANDS.exportApiBase.includes("STATEGRAPH_API_BASE")
      );
    },
  },
  {
    name: "apiKeyCommand uses the key when present and the placeholder otherwise",
    fn: () => {
      return (
        apiKeyCommand("sg_x") === 'export STATEGRAPH_API_KEY="sg_x"' &&
        apiKeyCommand(null) === 'export STATEGRAPH_API_KEY="<your-api-key>"'
      );
    },
  },
  {
    name: "tenantListExample carries the tenant name",
    fn: () => {
      const out = tenantListExample("acme-platform");
      return out.endsWith("acme-platform") && out.split("\n").length === 3;
    },
  },
  {
    name: "CLI_COMMANDS.pullState pulls terraform state",
    fn: () => {
      return CLI_COMMANDS.pullState.includes("terraform state pull");
    },
  },
  {
    name: "CLI_COMMANDS.importToVelocity uses stategraph import tf",
    fn: () => {
      return CLI_COMMANDS.importToVelocity.includes("stategraph import tf");
    },
  },
  {
    name: "CLI_COMMANDS.velocityPlan uses stategraph plan",
    fn: () => {
      return CLI_COMMANDS.velocityPlan.startsWith("stategraph plan ");
    },
  },
  {
    name: "CLI_COMMANDS.velocityApply uses stategraph apply",
    fn: () => {
      return CLI_COMMANDS.velocityApply.startsWith("stategraph apply ");
    },
  },
  {
    name: "CLI_COMMANDS.commitConfig commits stategraph.json",
    fn: () => CLI_COMMANDS.commitConfig.includes("git add stategraph.json"),
  },

  // =========================================================================
  // Engine switch constants
  // =========================================================================
  {
    name: "githubSecretsCommands sets all three secrets with the given values",
    fn: () => {
      const out = githubSecretsCommands({
        apiBase: "https://app.stategraph.cloud",
        apiKey: "sg_x",
        tenantId: "t-1",
      });
      const lines = out.split("\n");
      return (
        lines.length === 3 &&
        lines[0] === 'gh secret set STATEGRAPH_API_BASE --body "https://app.stategraph.cloud"' &&
        lines[1] === 'gh secret set STATEGRAPH_API_KEY --body "sg_x"' &&
        lines[2] === 'gh secret set STATEGRAPH_TENANT_ID --body "t-1"'
      );
    },
  },
  {
    name: "githubSecretsCommands falls back to the key placeholder",
    fn: () => {
      return githubSecretsCommands({ apiBase: "b", apiKey: null, tenantId: "t" }).includes(
        '--body "<your-api-key>"',
      );
    },
  },
  {
    name: "gitlabVariablesTable lists the same three names",
    fn: () => {
      const out = gitlabVariablesTable({ apiBase: "b", apiKey: "k", tenantId: "t" });
      return (
        ["STATEGRAPH_API_BASE", "STATEGRAPH_API_KEY", "STATEGRAPH_TENANT_ID"].every((name) =>
          out.includes(name),
        ) && out.split("\n").length === 3
      );
    },
  },
  {
    name: "ENGINE_CONFIG names the stategraph engine in both forms",
    fn: () => {
      return (
        ENGINE_CONFIG.path === ".stategraph/config.yml" &&
        ENGINE_CONFIG.global === "engine:\n  name: stategraph" &&
        ENGINE_CONFIG.perDirectory.includes("tag_query:") &&
        ENGINE_CONFIG.perDirectory.includes("name: stategraph") &&
        ENGINE_CONFIG.tofu === "tf_cmd: tofu"
      );
    },
  },

  // =========================================================================
  // Migration flow: doc-derived text
  // =========================================================================
  {
    name: "MIGRATION_STEPS_OVERVIEW has 5 items",
    fn: () => {
      return (
        MIGRATION_STEPS_OVERVIEW.length === 5 &&
        MIGRATION_STEPS_OVERVIEW[0].includes("API key") &&
        MIGRATION_STEPS_OVERVIEW[2].includes("import") &&
        MIGRATION_STEPS_OVERVIEW[4].includes("stategraph.json")
      );
    },
  },
  {
    name: "VERIFICATION_CHECKLIST has 5 items",
    fn: () => {
      return (
        VERIFICATION_CHECKLIST.length === 5 &&
        VERIFICATION_CHECKLIST[0].includes("`stategraph plan`") &&
        VERIFICATION_CHECKLIST[1].includes("Stategraph UI")
      );
    },
  },
  {
    name: "MIGRATION_PREREQUISITES has 4 items",
    fn: () => {
      return (
        MIGRATION_PREREQUISITES.length === 4 &&
        MIGRATION_PREREQUISITES[0].includes("CLI") &&
        MIGRATION_PREREQUISITES[3].includes("API key")
      );
    },
  },
  {
    name: "DOC_LINKS.stateBackend and ciGuides exist",
    fn: () => {
      return (
        typeof DOC_LINKS.stateBackend === "string" &&
        DOC_LINKS.stateBackend.length > 0 &&
        DOC_LINKS.ciGuides.startsWith("https://stategraph.com/docs/")
      );
    },
  },
];

tests.forEach((test) => {
  try {
    if (test.fn()) {
      console.log(`  PASS: ${test.name}`);
      passed++;
    } else {
      console.log(`  FAIL: ${test.name}`);
      failed++;
    }
  } catch (error) {
    console.log(`  FAIL: ${test.name} (threw error: ${error})`);
    failed++;
  }
});

console.log("\n" + "=".repeat(60));
console.log(
  `\nResults: ${passed} passed, ${failed} failed out of ${tests.length} tests`
);

process.exit(failed > 0 ? 1 : 0);
