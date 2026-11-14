import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import path from "node:path";
import * as constants from "./orchestration-constants";

function collectStrings(value: unknown, location: string, output: Array<[string, string]>): void {
  if (typeof value === "string") {
    output.push([location, value]);
    return;
  }
  if (Array.isArray(value)) {
    value.forEach((item, index) => collectStrings(item, `${location}[${index}]`, output));
    return;
  }
  if (typeof value === "object" && value !== null) {
    Object.entries(value).forEach(([key, item]) =>
      collectStrings(item, `${location}.${key}`, output),
    );
  }
}

const tests: Array<{ name: string; run: () => void }> = [
  {
    name: "all exported copy strings follow the onboarding copy rules",
    run: () => {
      const strings: Array<[string, string]> = [];
      collectStrings(constants, "constants", strings);
      strings.push([
        "constants.githubConnectedDescription",
        constants.githubConnectedDescription("example-installation"),
      ]);
      assert.ok(strings.length > 0);
      for (const [location, value] of strings) {
        assert.ok(value.trim().length > 0, `${location} must not be empty`);
        assert.equal(value.includes("—"), false, `${location} must not contain an em dash`);
        assert.equal(value.includes("!"), false, `${location} must not contain an exclamation mark`);
        assert.equal(
          /\b(?:simply|just|easily)\b/i.test(value),
          false,
          `${location} must not contain filler copy`,
        );
      }
    },
  },
  {
    name: "step labels follow the provider's vocabulary",
    run: () => {
      const github = constants.orchestrationStepLabels("github");
      assert.equal(github, constants.ORCHESTRATION_STEP_LABELS);
      assert.equal(constants.orchestrationStepLabels(null), constants.ORCHESTRATION_STEP_LABELS);
      assert.equal(github.connect, "Install");
      assert.equal(github.runnable, "Workflow file");
      assert.equal(github.wait, "Pull request");
      const gitlab = constants.orchestrationStepLabels("gitlab");
      assert.equal(gitlab.connect, "Connect");
      assert.equal(gitlab.runnable, "Pipeline");
      assert.equal(gitlab.wait, "Merge request");
      assert.equal(gitlab.fork, github.fork);
      assert.equal(gitlab.change, github.change);
    },
  },
  {
    name: "every provider-keyed sentence names its own request noun",
    run: () => {
      const copy = constants.ORCHESTRATION_COPY;
      const pairs: Array<Readonly<Record<"github" | "gitlab", string>>> = [
        copy.repo.lead,
        copy.change.lead,
        copy.change.openRequest,
        copy.change.confirm,
        copy.whatHappens.planComment,
        copy.whatHappens.apply,
        copy.wait.title,
        copy.wait.lead,
        copy.wait.confirm,
        copy.firstPlan.waiting,
        copy.firstPlan.running,
        copy.firstPlan.stopped,
        copy.firstPlan.arrived,
        copy.firstPlan.existing,
        copy.firstPlan.error,
        copy.done.title,
        copy.done.lead,
        copy.done.leadDetected,
        copy.done.iaadBody,
      ];
      for (const pair of pairs) {
        assert.match(pair.github, /pull request/);
        assert.match(pair.gitlab, /merge request/);
        assert.doesNotMatch(pair.gitlab, /pull request/);
      }
      assert.match(copy.change.editInstruction, /null_resource_count = 0/);
      assert.match(copy.change.editInstruction, /null_resource_count = 1/);
      assert.equal(copy.change.editPath, "dev/main.tf");
      assert.equal(copy.actions.steps.length, 3);
      assert.match(copy.connect.ciAction, /Infrastructure as a Database/);
      assert.match(copy.done.iaadTitle, /Infrastructure as a Database/);
    },
  },
  {
    name: "the detected Done lead changes only the first sentence of the manual lead",
    run: () => {
      const { lead, leadDetected } = constants.ORCHESTRATION_COPY.done;
      assert.ok(leadDetected.github.startsWith("The plan comment is on your pull request. "));
      assert.ok(leadDetected.gitlab.startsWith("The plan comment is on your merge request. "));
      assert.ok(lead.github.startsWith("The plan comment appears on the pull request within a minute. "));
      assert.ok(lead.gitlab.startsWith("The plan comment appears on the merge request within a minute. "));
      for (const provider of ["github", "gitlab"] as const) {
        const rest = (text: string): string => text.slice(text.indexOf(". ") + 2);
        assert.equal(rest(leadDetected[provider]), rest(lead[provider]));
      }
    },
  },
  {
    name: "every top-level export names its copy source",
    run: () => {
      const source = readFileSync(
        path.join(__dirname, "orchestration-constants.ts"),
        "utf8",
      );
      const exports = [...source.matchAll(/^export (?:const|function) (\w+)/gm)];
      assert.ok(exports.length > 0);

      for (const match of exports) {
        const prefix = source.slice(0, match.index).trimEnd();
        const sourceComment = prefix.split("\n").at(-1) ?? "";
        assert.match(
          sourceComment,
          /^\/\*\* Source: .+ \*\/$/,
          `${match[1]} must have a Source comment`,
        );
      }
    },
  },
  {
    name: "documentation links use the working documentation base",
    run: () => {
      for (const url of Object.values(constants.DOC_LINKS)) {
        assert.match(url, /^https:\/\/stategraph\.com\/docs\//);
      }
    },
  },
  {
    name: "demo repositories expose provider-specific fork paths and copy",
    run: () => {
      assert.deepEqual(constants.DEMO_REPOSITORIES, {
        github: {
          slug: "stategraph/kick-the-tires",
          repositoryUrl: "https://github.com/stategraph/kick-the-tires",
          forkUrl: "https://github.com/stategraph/kick-the-tires/fork",
        },
        gitlab: {
          slug: "terrateam-demo/kick-the-tires",
          repositoryUrl: "https://gitlab.com/terrateam-demo/kick-the-tires",
          forkUrl: "https://gitlab.com/terrateam-demo/kick-the-tires/-/forks/new",
        },
      });
      const copy = constants.ORCHESTRATION_COPY;
      for (const provider of ["github", "gitlab"] as const) {
        const slug = constants.DEMO_REPOSITORIES[provider].slug;
        assert.ok(copy.repo.demo.body[provider].includes(slug));
        assert.ok(copy.fork.lead[provider].includes(slug));
        assert.match(copy.repo.demo.body[provider], /No cloud credentials/);
      }
      assert.match(copy.repo.demo.gitlabExistingGroup, /webhook secret/);
      assert.match(copy.repo.demo.gitlabChooseGroup, /not connected yet/);
      assert.match(copy.fork.pathLabel, /project path/);
    },
  },
  {
    name: "workflow body declares the path and dispatch inputs the GitHub engine uses",
    run: () => {
      const engineFiles = [
        "../../../terrat_github/terrat_github.ml",
        "../../../terrat_vcs_service_github/terrat_vcs_service_github_installation.ml",
        "../../../terrat_vcs_service_github/terrat_vcs_service_github_ep_installation.ml",
      ].map((file) => readFileSync(path.join(__dirname, file), "utf8"));
      assert.ok(
        engineFiles.some((source) => source.includes(`"${constants.GITHUB_WORKFLOW_PATH}"`)),
        "the engine looks for the workflow at GITHUB_WORKFLOW_PATH",
      );
      const provider = readFileSync(
        path.join(__dirname, "../../../terrat_vcs_service_github/terrat_vcs_service_github_provider.ml"),
        "utf8",
      );
      const yaml = constants.GITHUB_WORKFLOW_YAML;
      for (const name of ["work-token", "api-base-url", "environment", "runs_on"]) {
        assert.match(provider, new RegExp(`\\(\\s*"${name}",`), `terrat sends the ${name} input`);
        assert.match(yaml, new RegExp(`^      ${name}:$`, "m"), `the workflow declares the ${name} input`);
      }
      assert.match(yaml, /^name: 'Stategraph'$/m);
      assert.match(yaml, /^on:\n  workflow_dispatch:$/m);
      assert.match(yaml, /^jobs:$/m);
      assert.match(yaml, /^  stategraph:$/m);
      assert.ok(yaml.includes("id-token: write"));
      assert.ok(yaml.includes("uses: terrateamio/action@v1"));
      assert.ok(yaml.includes("runs-on: ${{ fromJSON(github.event.inputs.runs_on) }}"));
      assert.equal(yaml.endsWith("\n"), false);
      assert.equal(constants.GITHUB_WORKFLOW_PATH, ".github/workflows/stategraph.yml");
    },
  },
  {
    name: "pipeline body keeps the engine contract and names Stategraph in free text",
    run: () => {
      const yaml = constants.GITLAB_PIPELINE_YAML;
      assert.match(yaml, /^# \.gitlab-ci\.yml - Stategraph pipeline$/m);
      assert.match(yaml, /project: 'terrateam-io\/terrateam-template'/);
      assert.match(yaml, /file: 'terrateam-template\.yml'/);
      assert.match(yaml, /^    TERRATEAM_TRIGGER:$/m);
      assert.match(yaml, /^  - terrateam$/m);
      assert.match(yaml, /^terrateam_job:\n  extends: \.terrateam_template$/m);
      assert.doesNotMatch(yaml, /description: "[^"]*terrateam/i);
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
