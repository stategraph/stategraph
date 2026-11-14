import type { VcsProvider } from "@/lib/vcs/links";
import type { OrchestrationStep } from "./orchestration-state";

/** Source: docs/src/content/docs/quickstart/cloud/first-plan-apply.mdx, code/src/iris/src/lib/GettingStarted.svelte */
export const ORCHESTRATION_STEP_LABELS: Record<OrchestrationStep, string> = {
  connect: "Install",
  repo: "Repository",
  runnable: "Workflow file",
  credentials: "Credentials",
  wait: "Pull request",
  fork: "Fork",
  actions: "Enable Actions",
  change: "First change",
  done: "Done",
};

/** Source: docs/src/content/docs/quickstart/cloud/first-plan-apply.mdx, code/src/iris/src/lib/GettingStarted.svelte */
export function orchestrationStepLabels(
  provider: VcsProvider | null,
): Record<OrchestrationStep, string> {
  if (provider !== "gitlab") return ORCHESTRATION_STEP_LABELS;
  return {
    ...ORCHESTRATION_STEP_LABELS,
    connect: "Connect",
    runnable: "Pipeline",
    wait: "Merge request",
  };
}

/** Source: docs/src/content/docs/overview/how-it-works.mdx, docs/src/content/docs/configuration/index.mdx, docs/src/content/docs/quickstart/cloud/first-plan-apply.mdx, docs/src/content/docs/workflows/advanced/github-reusable-workflows.mdx, docs/src/content/docs/integrations/cloud-providers/aws/getting-started.mdx, docs/src/content/docs/integrations/cloud-providers/gcp/getting-started.mdx, docs/src/content/docs/integrations/cloud-providers/azure/getting-started.mdx, docs/src/content/docs/integrations/cloud-providers/other.mdx, docs/src/content/docs/troubleshooting/index.mdx, docs/src/content/docs/reference/commands/repo-config.mdx, docs/src/content/docs/reference/api/github-installations.mdx, docs/src/content/docs/reference/api/gitlab-installations.mdx, code/src/iris/src/lib/GettingStarted.svelte */
export const ORCHESTRATION_COPY = {
  loading: "Loading repository setup.",
  tenantError: "Tenant data could not load.",
  noTenant: "No tenant is available for repository setup.",
  reload: "Reload",
  availability: {
    checking: "Checking orchestration availability.",
    unavailable: "Orchestration is not available on this server.",
    errorTitle: "Orchestration availability could not be checked.",
    errorBody: "Try again. Repository setup remains available.",
    retry: "Check again",
  },
  common: {
    back: "Back",
    continue: "Continue",
    errorDetailFallback: "No error details were returned.",
  },
  connect: {
    title: "Set up Stategraph",
    lead: "Plan and apply Terraform from pull requests. Works with Terraform and OpenTofu. Your state stays where it is. Start by installing the Stategraph app where your repositories live.",
    githubTitle: "GitHub",
    githubDescription:
      "Install the Stategraph GitHub App on the organization that owns your repositories. Choose the repositories it may read. Then link the installation to this tenant.",
    githubContinue: "Continue with GitHub",
    gitlabTitle: "GitLab",
    gitlabDescription:
      "Connect a GitLab.com group. Stategraph adds the webhook, the CI/CD role and the pipeline file for you.",
    gitlabContinue: "Continue with GitLab",
    adminHelp:
      "App already installed on your organization? Use the same button. The next screen links that installation to this tenant.",
    ciTitle: "Already run Terraform in CI?",
    ciBody:
      "Keep your pipeline. Set up Infrastructure as a Database against your existing Terraform CI: your state in Stategraph for faster, concurrent plans, cost and blast radius.",
    ciAction: "Set up Infrastructure as a Database",
  },
  repo: {
    title: "Which repository?",
    lead: {
      github: "Nothing to type. Stategraph sees a repository the moment it gets its first pull request.",
      gitlab: "Nothing to type. Stategraph sees a project the moment it gets its first merge request.",
    },
    providerLabel: "Version control provider",
    providerRequirement: "Required. Choose the provider for this repository.",
    githubOption: "GitHub",
    gitlabOption: "GitLab",
    own: {
      title: "Your repository",
      body: {
        github:
          "A repository with Terraform in it, that the app has access to. Two more steps: add one workflow file, open one pull request.",
        gitlab:
          "A project with Terraform in it, in the group you connected. Two more steps: add the pipeline file, open one merge request.",
      },
      action: "Continue with my repository",
    },
    demo: {
      title: {
        github: "The example repository",
        gitlab: "The example project",
      },
      body: {
        github:
          "A fork of stategraph/kick-the-tires. A small repository with null resources. No cloud credentials. Nothing real is created.",
        gitlab:
          "A fork of terrateam-demo/kick-the-tires in your group. A simple Terraform configuration you can experiment with safely. No cloud credentials.",
      },
      action: {
        github: "Use the example repository",
        gitlab: "Use the example project",
      },
      gitlabExistingGroup:
        "The GitLab group is already connected. This console cannot read its existing webhook secret, so it cannot add the example fork safely.",
      gitlabChooseGroup: "Choose a GitLab.com group that is not connected yet.",
      gitlabChooseGroupAction: "Choose another group",
    },
  },
  fork: {
    title: {
      github: "Fork the example repository",
      gitlab: "Fork the example project",
    },
    lead: {
      github:
        "Fork stategraph/kick-the-tires into an account or organization where the Stategraph app is installed. This gives you your own copy to experiment with.",
      gitlab:
        "Fork terrateam-demo/kick-the-tires into the GitLab group you connected. It contains a simple Terraform configuration you can experiment with safely.",
    },
    action: {
      github: "Fork on GitHub",
      gitlab: "Fork project",
    },
    opens: {
      github: "Opens github.com in a new tab.",
      gitlab: "Opens gitlab.com in a new tab.",
    },
    pathLabel: "After forking, enter your project path",
    pathInvalid: "Enter the path of your fork, for example group/kick-the-tires.",
    confirm: "I forked it",
  },
  actions: {
    title: "Enable GitHub Actions on your fork",
    lead: "GitHub turns workflows off on every fork. Turn them on so Stategraph can run.",
    steps: [
      "Open your fork on GitHub.",
      "Open the Actions tab.",
      "Click I understand my workflows, go ahead and enable them.",
    ],
    confirm: "Actions are enabled",
  },
  change: {
    title: "Make your first change",
    lead: {
      github: "Edit one file in your fork and open a pull request.",
      gitlab: "Edit one file in your fork and open a merge request.",
    },
    editPath: "dev/main.tf",
    open: {
      github: "Open dev/main.tf in your fork.",
      gitlab: "Edit dev/main.tf.",
    },
    editInstruction: "Change null_resource_count = 0 to null_resource_count = 1.",
    gitlabPush: "Create a new branch and push your changes.",
    openRequest: {
      github: "Open a pull request in your fork.",
      gitlab: "Open a merge request in your fork.",
    },
    confirm: {
      github: "I opened a pull request",
      gitlab: "I opened a merge request",
    },
  },
  whatHappens: {
    title: "What happens",
    planComment: {
      github: "Stategraph comments a plan on the pull request within a minute.",
      gitlab: "Stategraph comments a plan on the merge request within a minute.",
    },
    approval:
      "If GitHub marks the run Action required, open the Actions tab, select the run, and select Approve and run.",
    apply: {
      github: "To apply, comment stategraph apply on the pull request.",
      gitlab: "To apply, comment stategraph apply on the merge request.",
    },
    runs: "The run shows up under Orchestration in this console.",
  },
  runnable: {
    title: {
      github: "Add the workflow file",
      gitlab: "Add the .gitlab-ci.yml file",
    },
    lead: {
      github:
        "Put this file on your default branch. Push it directly, or merge a pull request that contains only this file.",
      gitlab: "Put this file on your default branch. Skip this if the GitLab setup already added it.",
    },
    pathLabel: "File path",
    whatHappensTitle: "What happens next",
    roots: "Every directory with .tf or .tfvars files becomes a root.",
    plans: "Plan runs on every pull request that changes files in a root.",
    applies: "Nothing is applied until someone comments stategraph apply.",
    missingProvider: "Required. Choose GitHub or GitLab before continuing.",
  },
  credentials: {
    title: "Add cloud credentials",
    requirement: "Required if your Terraform talks to a cloud.",
    githubBody: "Add credentials as GitHub secrets or use OIDC; the action reads them.",
    gitlabBody: "Add credentials as GitLab CI/CD variables or use OIDC; the action reads them.",
    genericBody: "Add credentials in your CI or use OIDC; the action reads them.",
    done: "Done",
    skip: "Skip",
  },
  wait: {
    title: {
      github: "Open a pull request",
      gitlab: "Open a merge request",
    },
    lead: {
      github: "Open a pull request that changes a .tf file in your repository.",
      gitlab: "Open a merge request that changes a .tf file in your project.",
    },
    confirm: {
      github: "I opened a pull request",
      gitlab: "I opened a merge request",
    },
  },
  firstPlan: {
    checking: "Checking for a plan.",
    waiting: {
      github: "Waiting for the plan comment on your pull request.",
      gitlab: "Waiting for the plan comment on your merge request.",
    },
    running: {
      github:
        "Stategraph started the plan. The comment appears on the pull request when the run finishes.",
      gitlab:
        "Stategraph started the plan. The comment appears on the merge request when the run finishes.",
    },
    stopped: {
      github:
        "The plan run stopped before it finished. Its run under Orchestration shows why. Push a commit to the pull request to plan again.",
      gitlab:
        "The plan run stopped before it finished. Its run under Orchestration shows why. Push a commit to the merge request to plan again.",
    },
    arrived: {
      github: "The plan is on your pull request.",
      gitlab: "The plan is on your merge request.",
    },
    existing: {
      github:
        "A plan already ran in this tenant. Continue when the plan comment is on your pull request.",
      gitlab:
        "A plan already ran in this tenant. Continue when the plan comment is on your merge request.",
    },
    error: {
      github:
        "This page cannot check for the plan. Continue when the plan comment is on your pull request.",
      gitlab:
        "This page cannot check for the plan. Continue when the plan comment is on your merge request.",
    },
    skip: "Continue without waiting",
  },
  done: {
    pill: "Orchestration is set up",
    title: {
      github: "Your pull request gets a plan",
      gitlab: "Your merge request gets a plan",
    },
    lead: {
      github:
        "The plan comment appears on the pull request within a minute. From now on, every pull request that changes Terraform gets one. Comment stategraph apply to apply.",
      gitlab:
        "The plan comment appears on the merge request within a minute. From now on, every merge request that changes Terraform gets one. Comment stategraph apply to apply.",
    },
    leadDetected: {
      github:
        "The plan comment is on your pull request. From now on, every pull request that changes Terraform gets one. Comment stategraph apply to apply.",
      gitlab:
        "The plan comment is on your merge request. From now on, every merge request that changes Terraform gets one. Comment stategraph apply to apply.",
    },
    nextEyebrow: "Next",
    iaadTitle: "Run your plans through Stategraph Infrastructure as a Database",
    iaadBody: {
      github:
        "Move your state into Stategraph's database, then switch the engine in .stategraph/config.yml. Your pull requests get plans scoped to what changed, concurrent applies, cost and blast radius. The pull request flow stays the same.",
      gitlab:
        "Move your state into Stategraph's database, then switch the engine in .stategraph/config.yml. Your merge requests get plans scoped to what changed, concurrent applies, cost and blast radius. The merge request flow stays the same.",
    },
    iaadAction: "Set up state",
    console: "Go to the console",
    tuneTitle: "Tune the config",
    tuneDescription: "Optional. Change discovery rules and guardrails after the first plan.",
    usersTitle: "Manage users",
    usersDescription: "Add or remove tenant access in this console.",
    usersAction: "Open user settings",
    referenceTitle: "Read the config reference",
    referenceDescription: "Read the configuration overview and supported options.",
    referenceAction: "Open config reference",
  },
  handoff: "Continue to repository",
} as const;

/** Source: docs/src/content/docs/quickstart/cloud/first-plan-apply.mdx, docs/src/content/docs/overview/how-it-works.mdx. Legacy demo contract: code/src/iris/src/lib/GettingStarted.svelte */
export const DEMO_REPOSITORIES = {
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
} as const;

/** Source: docs/src/content/docs/overview/how-it-works.mdx */
export function githubConnectedDescription(login: string): string {
  return `Installation ${login} is linked to this tenant. Its repositories appear in this console after their first pull request event.`;
}

/** Source: website/stategraph/content/docs/orchestration/configuration/index.md, website/stategraph/content/docs/orchestration/cloud-providers/aws/index.md, website/stategraph/content/docs/orchestration/cloud-providers/gcp/index.md, website/stategraph/content/docs/orchestration/cloud-providers/azure/index.md, website/stategraph/content/docs/orchestration/cloud-providers/other.md, website/stategraph/content/docs/reference/troubleshooting.md, website/stategraph/content/docs/get-started/quickstart/cloud.md */
export const DOC_LINKS = {
  configuration: "https://stategraph.com/docs/orchestration/configuration",
  aws: "https://stategraph.com/docs/orchestration/cloud-providers/aws",
  gcp: "https://stategraph.com/docs/orchestration/cloud-providers/gcp",
  azure: "https://stategraph.com/docs/orchestration/cloud-providers/azure",
  other: "https://stategraph.com/docs/orchestration/cloud-providers/other",
  troubleshooting: "https://stategraph.com/docs/reference/troubleshooting#orchestration-issues",
  firstPlan: "https://stategraph.com/docs/get-started/quickstart/cloud#open-a-pull-request",
} as const;

/** Source: website/stategraph/content/docs/orchestration/cloud-providers/aws/index.md, website/stategraph/content/docs/orchestration/cloud-providers/gcp/index.md, website/stategraph/content/docs/orchestration/cloud-providers/azure/index.md, website/stategraph/content/docs/orchestration/cloud-providers/other.md */
export const CREDENTIAL_CARDS = [
  { id: "aws", label: "AWS", href: DOC_LINKS.aws },
  { id: "gcp", label: "GCP", href: DOC_LINKS.gcp },
  { id: "azure", label: "Azure", href: DOC_LINKS.azure },
  { id: "other", label: "Other", href: DOC_LINKS.other },
] as const;

/** Source: docs/src/content/docs/workflows/advanced/github-reusable-workflows.mdx. Engine contract: code/src/terrat_github/terrat_github.ml */
export const GITHUB_WORKFLOW_PATH = ".github/workflows/stategraph.yml";

/** Source: docs/src/content/docs/workflows/advanced/github-reusable-workflows.mdx */
export const GITHUB_WORKFLOW_LANGUAGE = "yaml";

/** Source: github.com/terrateamio/terrateam-example github/actions/workflows/default/terrateam.yml (linked from docs/src/content/docs/workflows/advanced/github-reusable-workflows.mdx). Engine contract: code/src/terrat_github/terrat_github.ml, code/src/terrat_vcs_service_github/terrat_vcs_service_github_provider.ml */
export const GITHUB_WORKFLOW_YAML = [
  "name: 'Stategraph'",
  "on:",
  "  workflow_dispatch:",
  "    inputs:",
  "      # The work-token and api-base-url are passed in by the backend",
  "      work-token:",
  "        description: 'Work Token'",
  "        required: true",
  "      api-base-url:",
  "        description: 'API Base URL'",
  "      environment:",
  "        description: 'Environment in which to run the action'",
  "        type: environment",
  "      runs_on:",
  "        description: 'runs-on configuration'",
  "        type: string",
  "        default: '\"ubuntu-latest\"'",
  "jobs:",
  "  stategraph:",
  "    permissions: # Required to pass credentials to the action",
  "      id-token: write",
  "      contents: read",
  "    runs-on: ${{ fromJSON(github.event.inputs.runs_on) }}",
  "    timeout-minutes: 1440",
  "    name: Stategraph",
  "    environment: '${{ github.event.inputs.environment }}'",
  "    steps:",
  "      - uses: actions/checkout@v4",
  "      - name: Run Stategraph",
  "        id: stategraph",
  "        uses: terrateamio/action@v1",
  "        with:",
  "          work-token: '${{ github.event.inputs.work-token }}'",
  "          api-base-url: '${{ github.event.inputs.api-base-url }}'",
  "        env:",
  "          SECRETS_CONTEXT: ${{ toJson(secrets) }}",
  "          VARIABLES_CONTEXT: ${{ toJson(vars) }}",
].join("\n");

/** Source: code/src/iris/src/lib/GettingStarted.svelte (add-pipeline step) */
export const GITLAB_PIPELINE_PATH = ".gitlab-ci.yml";

/** Source: code/src/iris/src/lib/GettingStarted.svelte (add-pipeline step). The include project, template file, job name, stage and input names are the engine's interface: do not rebrand them. */
export const GITLAB_PIPELINE_YAML = `# .gitlab-ci.yml - Stategraph pipeline
spec:
  inputs:
    TERRATEAM_TRIGGER:
      description: "Is this being triggered by Stategraph?"
      type: string
      default: "$TERRATEAM_TRIGGER"
    WORK_TOKEN:
      description: "The work token from Stategraph"
      type: string
      default: "$WORK_TOKEN"
    API_BASE_URL:
      description: "The base url for the Stategraph API"
      type: string
      default: "$API_BASE_URL"
    RUNS_ON:
      description: "The tags to use for the runner"
      type: array
      default: []
---
include:
  - project: 'terrateam-io/terrateam-template'
    file: 'terrateam-template.yml'
    inputs:
      TERRATEAM_TRIGGER: $[[ inputs.TERRATEAM_TRIGGER ]]
      WORK_TOKEN: $[[ inputs.WORK_TOKEN ]]
      API_BASE_URL: $[[ inputs.API_BASE_URL ]]
      RUNS_ON: $[[ inputs.RUNS_ON ]]

stages:
  - terrateam

terrateam_job:
  extends: .terrateam_template
`;
