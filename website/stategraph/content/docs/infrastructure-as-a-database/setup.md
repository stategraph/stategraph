---
title: Setup
description: Set up Infrastructure as a Database for a Terraform module. Create an API key, configure the CLI, add a state, and run your first plan and apply.
order: 2
---


Set up Infrastructure as a Database for one Terraform or OpenTofu root module, from the API key to the first apply. For the fastest path from a state file to a first plan, see [Import your Terraform state](/docs/get-started/quickstart/import-state).

## Before you begin

- A Stategraph server: [Stategraph Cloud](/docs/get-started/quickstart/cloud) or a [self-hosted server](/docs/admin/self-hosting).
- The `stategraph` CLI. See [CLI reference](/docs/cli).
- Terraform or OpenTofu.
- A Terraform root module.

## 1. Create an API key

Create an API key in the console, under **Settings > API Keys**. On a self-hosted server, the default URL is <http://localhost:8080>. Export the key:

```bash
export STATEGRAPH_API_KEY="<your-api-key>"
```

The CLI can also make tokens with limited capabilities from an existing key. See [Access tokens](/docs/admin/access-control/access-tokens).

## 2. Configure the CLI

1. Set your server URL, for Stategraph Cloud or self-hosted:

```bash
export STATEGRAPH_API_BASE="http://localhost:8080"
```

2. List your tenants to get the tenant ID:

```bash
stategraph user tenants list
```

Output:

```
550e8400-e29b-41d4-a716-446655440000    acme
```

3. Set the tenant ID, so that commands do not need `--tenant`:

```bash
export STATEGRAPH_TENANT_ID="550e8400-e29b-41d4-a716-446655440000"
```

4. To check the three variables, run `stategraph info`. It shows the current user, your tenants, and the server version.

## 3. Go to your root module

Run all commands from the root of the Terraform module:

```bash
cd /path/to/your/terraform/module
```

## 4. Add your state

Import a state from S3, GCS, Terraform Cloud, or another backend, or create an empty state.

### Import an existing state

You import a state one time. After that, Stategraph keeps it, and you change it through the CLI.

1. Get a local copy of the state:

```bash
terraform state pull > terraform.tfstate
```

2. Import it:

```bash
stategraph import tf \
  --tenant <tenant-id> \
  --name <state-name> \
  --var-file <path-to-var-file> \
  --var key=value \
  terraform.tfstate
```

The state name must be new. Give the same `--var-file` and `--var` flags that you give to `terraform plan`, so that Stategraph evaluates your HCL as Terraform does. All flags are in [Import commands](/docs/cli/import).

### Replace a state that exists

`stategraph import tf` does not overwrite a state. To import again, for example after a failed first import, add `--overwrite`:

```bash
stategraph import tf --overwrite \
  --tenant <tenant-id> \
  --name <state-name> \
  terraform.tfstate
```

- `--overwrite` replaces the state that `stategraph.json` points to for the workspace.
- If you also give `--name` and there is no `stategraph.json`, the command makes a new state.
- The import replaces the contents of the state. It deletes anything that the import does not contain.
- The transaction history, cost data, and security data stay.

### Create an empty state

```bash
stategraph states create --tenant <tenant-id> --name <state-name>
```

### Add workspaces

For [Terraform workspaces](https://developer.hashicorp.com/terraform/language/state/workspaces), such as staging and production, make one state for each workspace in the same group. When `stategraph.json` exists, the command reads the group ID from it.

```bash
# The first state creates the group and writes stategraph.json
stategraph states create --tenant <tenant-id> --name my-state

# Additional workspaces join the same group
stategraph states create --tenant <tenant-id> --name my-state-staging --workspace staging
stategraph states create --tenant <tenant-id> --name my-state-prod --workspace production
```

Then give `--workspace` when you plan and apply:

```bash
stategraph tf plan --tenant <tenant-id> --workspace staging --out plan.json
stategraph tf apply plan.json
```

Stategraph sets `terraform.workspace` in your HCL to the selected workspace, so workspace logic continues to work.

## 5. Plan and apply

1. Plan the change, and save the plan:

```bash
stategraph tf plan --tenant <tenant-id> --out plan.json
```

2. Apply the saved plan:

```bash
stategraph tf apply plan.json
```

To plan and apply in one step, as with `terraform apply`, give no plan file. The command makes a plan, shows the changes, and asks for your approval before it commits:

```bash
stategraph tf apply --tenant <tenant-id>
```

`--auto-approve` skips the approval. Without it, the apply fails when stdin is not a terminal, or with `--silent` (`STATEGRAPH_SILENT`). In CI, use both flags:

```bash
stategraph tf apply --tenant <tenant-id> --silent --auto-approve
```

## 6. Commit stategraph.json

`stategraph import tf` and `stategraph states create` write `stategraph.json` in your module directory. The file holds the group ID of the module. The CLI finds the state from the group ID and `--workspace`. Commit the file, so that your team uses the same state:

```bash
git add stategraph.json
git commit -m "Add Stategraph configuration"
```

## Other commands

The `stategraph tf` commands replace `terraform plan` and `terraform apply`. `stategraph plan` and `stategraph apply` are aliases for `stategraph tf plan` and `stategraph tf apply`.

```bash
# Plan and apply in one step (--auto-approve skips the prompt)
stategraph tf apply --tenant <tenant-id> --auto-approve

# Plan across several states in one transaction
stategraph tf mtx --tenant <tenant-id> --out plan.json ./networking ./compute ./application
```

### Ephemeral tfvars

Mark a tfvar as ephemeral in `stategraph.json` when its value changes at each run but changes no infrastructure, for example a token for one run. Stategraph gives the value to the run, but:

- It does not use the tfvar to find the subgraph.
- It does not store the tfvar in the database.
- It masks the value in SQL results.

```bash
# Mark tfvars matching a glob as ephemeral ('*' is the only metacharacter)
stategraph config tfvar ephemeral add '*_token'

# List the configured globs
stategraph config tfvar ephemeral list

# Stop treating a glob as ephemeral (spell it exactly as list prints it)
stategraph config tfvar ephemeral remove '*_token'
```

### Plan options

| Option | Description |
|--------|-------------|
| `--tenant` | Tenant ID. Required, or set `STATEGRAPH_TENANT_ID`. |
| `--out` | File for the plan. Optional for `tf plan`: without it, you get a read-only preview and no file. Required for `tf mtx`. |
| `--state` | State ID. Default: read from `stategraph.json`. |
| `--workspace` | Workspace name. Default `default`. |
| `--var` | A variable as `key=value`. You can give it more than one time. |
| `--var-file` | Path to a variable file. |
| `--force` | Put a resource address into the plan. Accepts globs, for example `data.*`. |

| Environment variable | Description |
|----------------------|-------------|
| `STATEGRAPH_API_BASE` | Server URL, or use `--api-base`. |
| `STATEGRAPH_API_KEY` | The API key that the CLI uses. |
| `STATEGRAPH_TENANT_ID` | Tenant ID, or use `--tenant`. |
| `STATEGRAPH_WORKSPACE` | Workspace name, or use `--workspace`. |
| `TF_CMD` | Path to the Terraform or OpenTofu binary. Default: `tofu`, then `terraform`, whichever the CLI finds first. |
| `STATEGRAPH_TELEMETRY_ENDPOINT` | `0` turns [telemetry](/docs/cli#telemetry) off. |

All flags are in [Terraform commands](/docs/cli/tf), including `--skip-refresh`, `--tx-tags`, `--detailed-exitcode`, and the cost and security preview options.

### Transaction commands

`stategraph tx` manages transactions directly:

```bash
# Create a transaction manually
stategraph tx create --tenant <tenant-id>

# List transactions
stategraph tx list --tenant <tenant-id>

# Abort a transaction
stategraph tx abort --tx <tx-id>

# View transaction logs
stategraph tx logs list --tx <tx-id>
```

See [Transaction commands](/docs/cli/transactions) for the CLI, and the [API reference](/docs/reference/api/transactions) for the REST endpoints.

## Next steps

- [Transactions](/docs/infrastructure-as-a-database/transactions): what happens in each plan and apply.
- [Resource-level locking](/docs/infrastructure-as-a-database/resource-locking): how concurrent changes stay safe.
- [Multi-state transactions](/docs/infrastructure-as-a-database/multi-state): one transaction across several states.
- [Use with Orchestration](/docs/infrastructure-as-a-database/orchestration): run pull request plans and applies with Infrastructure as a Database.
