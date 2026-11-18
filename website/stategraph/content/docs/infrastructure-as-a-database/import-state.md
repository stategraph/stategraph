---
title: Import your state
description: Import a Terraform or OpenTofu state into Stategraph with the CLI, then run your first scoped plan and apply.
order: 3
---


Import a Terraform or OpenTofu state into Infrastructure as a Database, which stores it as a graph in PostgreSQL. Then run a first scoped plan, which plans only what your change touches. You need a server: [Stategraph Cloud](https://app.stategraph.cloud) or a [self-hosted](/docs/admin/self-hosting) one.

## 1. Install the CLI

1. Install the CLI. On macOS or Linux:

```bash
curl -sSL https://get.stategraph.com/install.sh | sh
```

With Homebrew:

```bash
brew tap stategraph/stategraph
brew install stategraph
```

For APT, a binary download, or the Docker image, see [CLI reference](/docs/cli).

2. Check the install:

```bash
stategraph --version
```

The CLI runs `tofu` if it is on your `PATH`, otherwise `terraform`. To use another binary, set `TF_CMD`.

## 2. Connect to your server

1. In the console, create an API key under **Settings → API Keys**.
2. Set three variables, with the console URL as `STATEGRAPH_API_BASE`:

```bash
export STATEGRAPH_API_BASE="https://app.stategraph.cloud"   # or your self-hosted URL
export STATEGRAPH_API_KEY="<your-api-key>"
export STATEGRAPH_TENANT_ID="<your-tenant-id>"
```

3. Check the connection, and find your tenant ID:

```bash
stategraph info
```

Output:

```
key       value
--------  --------------------------------------------
User      Jane Doe (jane@example.com) [admin: 7e45a833-24db-4847-b3da-bbb6f699f201]
Server    2.5.7
Client    2.5.7
Tenants   1
  Tenant  Production (7e45a833-24db-4847-b3da-bbb6f699f201)
```

The `[admin: …]` tag lists the tenants that you administer: for a new account, its own tenant. `stategraph user tenants list` prints the same IDs as a table.

## 3. Import the state

1. Go to the root module directory, where you run `terraform plan`, so that the CLI finds the HCL.
2. If the state is in a remote backend, pull it to a file:

```bash
terraform state pull > terraform.tfstate
```

3. Import the state and the configuration. Give the same `--var-file` and `--var` flags as to `terraform plan`, so that the HCL evaluates as in Terraform:

```bash
stategraph import tf \
  --name my-app \
  --var-file prod.tfvars \
  terraform.tfstate
```

4. The CLI warns that Stategraph manages state apart from your existing backend. Answer `y`, or give `-y` to skip the prompt.

The CLI creates the state `my-app` in your tenant, and writes `stategraph.json`. This file binds the directory to the state, so later commands need no `--state`.

5. Check the import. `stategraph states list` shows the new state and its ID, and the summary counts what landed:

```bash
stategraph states list
stategraph states summary --state <state-id>
```

- The state name must be new. To import again over a state that you created, for example after a failed first import, give `--overwrite`. It replaces the contents of the state, and keeps its transaction history.
- If your HCL reads files with `file()` or `templatefile()`, attach them with `--attach-files`, so that they take part in change detection.

## 4. Point the configuration at Stategraph

Commit `stategraph.json`, so that everyone in this directory uses the same state:

```bash
git add stategraph.json
git commit -m "Add Stategraph configuration"
```

Stategraph now keeps the state, so the configuration needs no `backend` block, and Stategraph transactions, not backend locks, control concurrency. See [Terraform compatibility](/docs/reference/terraform-compatibility).

For Terraform workspaces, create one more state per workspace in the same group, which the CLI reads from `stategraph.json`:

```bash
stategraph states create --name my-app-staging --workspace staging
```

Then plan and apply with `--workspace staging` or `STATEGRAPH_WORKSPACE`.

## 5. Run the first scoped plan

1. Edit a `.tf` file.
2. Plan:

```bash
stategraph tf plan
```

Without `--out`, this is a read-only preview that writes no file. Right after an import, with no edits, expect no changes.

3. Save the plan and apply it, or plan and apply in one step:

```bash
# Review a saved plan, then apply exactly that plan
stategraph tf plan --out plan.json
stategraph tf apply plan.json

# Or plan, show the diff, and prompt before applying
stategraph tf apply
```

`stategraph plan` and `stategraph apply` are aliases of the `tf` forms. CI has no terminal, so give `--auto-approve`, and `--silent` to suppress prompt output. Each apply is a transaction that locks only the resources it changes, so unrelated transactions run at the same time. See [Transactions](/docs/infrastructure-as-a-database/transactions) and [Resource locking](/docs/infrastructure-as-a-database/resource-locking).

## 6. Query what you imported

The import also feeds SQL over all your infrastructure, and the dependency graph:

```bash
stategraph sql schema
stategraph query "SELECT type, count(*) AS n FROM resources GROUP BY type ORDER BY n DESC LIMIT 5"
stategraph blast-radius aws_subnet.public --state <state-id>
```

The blast radius lists the resource that you name, and each dependent that a change to it would affect, across linked states. See [Query and insights](/docs/infrastructure-as-a-database/query).

## Next steps

- [Setup](/docs/infrastructure-as-a-database/setup): workspaces, ephemeral tfvars, and CI.
- [Multi-state transactions](/docs/infrastructure-as-a-database/multi-state): one transaction for the states that a change reaches, or for the directories that you choose with `stategraph tf mtx`.
- [Use with Orchestration](/docs/infrastructure-as-a-database/orchestration): scoped plans from pull requests with `engine: stategraph`.
- [Cost](/docs/infrastructure-as-a-database/cost): what a state costs, and what a plan changes.
- [Import reference](/docs/cli/import): all flags of `stategraph import tf`.
