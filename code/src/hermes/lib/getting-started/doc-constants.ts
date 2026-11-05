/**
 * Doc-derived constants for the Getting Started wizard.
 *
 * ALL copy that references CLI commands, flags, environment variables, or
 * workflows is defined here as a single source of truth. When docs change,
 * update this file and the wizard updates automatically.
 *
 * Source documentation lives at: ../website/content/docs/
 * Each constant includes a comment pointing to the specific doc file used.
 */

// ---------------------------------------------------------------------------
// Terminology (from ../website/content/docs/reference/glossary.md)
// ---------------------------------------------------------------------------

export const GLOSSARY = {
  tenant: "Organizational boundary; all states, transactions, and users belong to one.",
  state: "A Terraform state file tracked by Stategraph.",
  groupId: "UUID that identifies a state in the HTTP backend URL.",
  workspace: "Maps to Terraform workspaces. Defaults to \"default\".",
  transaction: "A recorded change to state. Each terraform apply creates a transaction.",
  apiKey: "Bearer token for CLI, Terraform, and programmatic API requests.",
} as const;

// ---------------------------------------------------------------------------
// Environment variables (from ../website/content/docs/quickstart/state-backend.md)
// ---------------------------------------------------------------------------

export const ENV_VARS = {
  /** Source: docs/quickstart/state-backend.md - Step 1 */
  TF_HTTP_USERNAME: {
    name: "TF_HTTP_USERNAME",
    value: "session",
    description: "Username for Terraform HTTP backend authentication",
  },
  /** Source: docs/quickstart/state-backend.md - Step 1 */
  TF_HTTP_PASSWORD: {
    name: "TF_HTTP_PASSWORD",
    value: "<your-api-key>",
    description: "API key for Terraform HTTP backend authentication",
  },
  /** Source: docs/quickstart/state-backend.md - Step 2 */
  STATEGRAPH_API_BASE: {
    name: "STATEGRAPH_API_BASE",
    value: "http://localhost:8080",
    description: "Base URL of the Stategraph server",
  },
  /** Source: docs/quickstart/state-backend.md - Step 2 */
  STATEGRAPH_API_KEY: {
    name: "STATEGRAPH_API_KEY",
    value: "$TF_HTTP_PASSWORD",
    description: "API key for CLI authentication (same as TF_HTTP_PASSWORD)",
  },
} as const;

// ---------------------------------------------------------------------------
// CLI commands (from ../website/content/docs/cli/states.md and
//               ../website/content/docs/backend/state-migration.md)
// ---------------------------------------------------------------------------

export const CLI_COMMANDS = {
  /** Source: docs/velocity/setup.md - Step 1 */
  exportApiKey: `export STATEGRAPH_API_KEY="<your-api-key>"`,

  /** Source: docs/velocity/setup.md - Step 2 */
  exportApiBase: `export STATEGRAPH_API_BASE="http://localhost:8080"`,

  /** Source: docs/velocity/setup.md - Step 2 */
  listTenants: `stategraph user tenants list`,

  /** Source: docs/velocity/setup.md - Step 2 */
  exportTenantId: `export STATEGRAPH_TENANT_ID="<tenant-id>"`,

  /** Source: docs/velocity/setup.md - Step 4 (pull existing state) */
  pullState: `terraform state pull > terraform.tfstate`,

  /** Source: docs/velocity/setup.md - Step 4 (import to velocity) */
  importToVelocity: `stategraph import tf \\
  --name <state-name> \\
  terraform.tfstate`,

  /** Source: docs/velocity/setup.md - Step 4 (create new state) */
  createState: `stategraph states create --name <state-name>`,

  /** Source: docs/velocity/setup.md - Step 5 (plan) */
  velocityPlan: `stategraph plan --out plan.json`,

  /** Source: docs/velocity/setup.md - Step 5 (apply) */
  velocityApply: `stategraph apply plan.json`,

  /** Source: docs/velocity/setup.md - Version Control */
  commitConfig: `git add stategraph.json
git commit -m "Add Stategraph configuration"`,

  /** Source: docs/velocity/setup.md - Cleanup */
  cleanupTfstate: `rm -f terraform.tfstate`,
} as const;

// ---------------------------------------------------------------------------
// Dynamic CLI commands (use browser origin when available)
// ---------------------------------------------------------------------------

export function consoleOrigin(): string {
  return typeof window !== "undefined" ? window.location.origin : "http://localhost:8080";
}

export function getApiBaseCommand(): string {
  return `export STATEGRAPH_API_BASE="${consoleOrigin()}"`;
}

export const API_KEY_PLACEHOLDER = "<your-api-key>";

export function apiKeyCommand(apiKey: string | null): string {
  return `export STATEGRAPH_API_KEY="${apiKey ?? API_KEY_PLACEHOLDER}"`;
}

/** Source: docs/velocity/setup.md - Step 2, with the current tenant's name in place of the example. */
export function tenantListExample(tenantName: string): string {
  return `id                                    name
------------------------------------  -------
a568ae7e-5d38-44b4-a6e6-25cf04fa22ab  ${tenantName}`;
}

// ---------------------------------------------------------------------------
// Orchestration engine switch
// (from website/stategraph/content/docs/infrastructure-as-a-database/orchestration.md)
// ---------------------------------------------------------------------------

export interface EngineSecrets {
  apiBase: string;
  apiKey: string | null;
  tenantId: string;
}

export function githubSecretsCommands({ apiBase, apiKey, tenantId }: EngineSecrets): string {
  return [
    `gh secret set STATEGRAPH_API_BASE --body "${apiBase}"`,
    `gh secret set STATEGRAPH_API_KEY --body "${apiKey ?? API_KEY_PLACEHOLDER}"`,
    `gh secret set STATEGRAPH_TENANT_ID --body "${tenantId}"`,
  ].join("\n");
}

export function gitlabVariablesTable({ apiBase, apiKey, tenantId }: EngineSecrets): string {
  return [
    `STATEGRAPH_API_BASE   ${apiBase}`,
    `STATEGRAPH_API_KEY    ${apiKey ?? API_KEY_PLACEHOLDER}`,
    `STATEGRAPH_TENANT_ID  ${tenantId}`,
  ].join("\n");
}

/** Source: api_schemas/terrat/config-schema.json (engine-stategraph). */
export const ENGINE_CONFIG = {
  path: ".stategraph/config.yml",
  global: `engine:
  name: stategraph`,
  perDirectory: `workflows:
  - tag_query: dir:services/api
    engine:
      name: stategraph`,
  tofu: "tf_cmd: tofu",
} as const;

// ---------------------------------------------------------------------------
// Example CLI outputs
// (from ../website/content/docs/quickstart/state-backend.md and
//  ../website/content/docs/backend/state-migration.md)
// ---------------------------------------------------------------------------

export const CLI_EXAMPLE_OUTPUTS = {
  /** Source: docs/velocity/setup.md - Step 5 (plan output) */
  velocityPlan: `No changes. Your infrastructure matches the configuration.`,
} as const;

// ---------------------------------------------------------------------------
// Source backend examples — show what users need to replace
// (from ../website/content/docs/backend/state-migration.md)
// ---------------------------------------------------------------------------


// ---------------------------------------------------------------------------
// Terraform backend configuration templates
// (from ../website/content/docs/quickstart/state-backend.md - Step 3,
//  and ../website/content/docs/backend/state-migration.md)
// ---------------------------------------------------------------------------


// ---------------------------------------------------------------------------
// Migration steps overview
// (from ../website/content/docs/backend/state-migration.md - Overview)
// ---------------------------------------------------------------------------

export const MIGRATION_STEPS_OVERVIEW = [
  "Create an API key in Settings",
  "Configure CLI credentials",
  "Pull and import your existing state",
  "Verify with `stategraph plan`",
  "Commit `stategraph.json` to version control",
] as const;

// ---------------------------------------------------------------------------
// Verification checklist
// (from ../website/content/docs/backend/state-migration.md - Verification Checklist)
// ---------------------------------------------------------------------------

export const VERIFICATION_CHECKLIST = [
  "`stategraph plan` shows no changes",
  "State appears in Stategraph UI",
  "Resource count matches expectations",
  "Dependencies are visible in graph view",
  "`stategraph.json` committed to version control",
] as const;

// ---------------------------------------------------------------------------
// Prerequisites
// (from ../website/content/docs/backend/state-migration.md - Prerequisites)
// ---------------------------------------------------------------------------

export const MIGRATION_PREREQUISITES = [
  "Stategraph CLI installed",
  "Terraform or OpenTofu installed",
  "Access to your existing state (to pull it)",
  "An API key created in Settings > API Keys",
] as const;

// ---------------------------------------------------------------------------
// State import: supported file format
// (from ../website/content/docs/cli/states.md - stategraph states import)
// ---------------------------------------------------------------------------

export const IMPORT_FILE_FORMAT = {
  extension: ".tfstate",
  mimeType: "application/json",
  description: "Terraform state file (JSON format)",
} as const;

// ---------------------------------------------------------------------------
// Doc page links (relative to docs site root)
// ---------------------------------------------------------------------------

export const DOC_LINKS = {
  /** Source: docs/quickstart/state-backend.md */
  stateBackend: "/docs/quickstart/state-backend",
  /** Source: docs/backend/state-migration.md */
  stateMigration: "/docs/backend/state-migration",
  /** Source: docs/cli/states.md */
  cliStates: "/docs/cli/states",
  /** Source: docs/cli/index.md */
  cliInstallation: "/docs/cli",
  /** Source: docs/inventory/query.md */
  inventoryQuery: "/docs/inventory/query",
  /** Source: docs/inventory/index.md */
  inventory: "/docs/inventory",
  /** Source: docs/reference/glossary.md */
  glossary: "/docs/reference/glossary",
  /** Source: website/stategraph/content/docs/velocity/setup.md - Usage */
  ciGuides: "https://stategraph.com/docs/velocity/setup#usage",
} as const;

// ---------------------------------------------------------------------------
// Troubleshooting entries
// (from ../website/content/docs/backend/state-migration.md - Troubleshooting)
// ---------------------------------------------------------------------------

export const TROUBLESHOOTING = {
  unauthorized: {
    symptom: "401 Unauthorized",
    fix: "Your API key is missing or invalid. Make sure the environment variables are set before running terraform init.",
  },
  backendChanged: {
    symptom: "Backend configuration changed",
    fix: 'This is expected - confirm the change by entering "yes".',
  },
  largeState: {
    symptom: "Timeout or error with large state files",
    fix: "For very large states (>100MB): ensure STATEGRAPH_CLIENT_MAX_BODY_SIZE is set appropriately and check proxy/load balancer timeouts.",
  },
} as const;
