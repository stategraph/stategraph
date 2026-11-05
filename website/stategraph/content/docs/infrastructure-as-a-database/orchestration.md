---
title: Use with Orchestration
description: Run Stategraph Orchestration plans and applies with Infrastructure as a Database: onboard directories, set the engine, and add runner secrets.
order: 7
---


With `engine: stategraph` in `.stategraph/config.yml`, Stategraph Orchestration runs each pull request plan and apply through the `stategraph` CLI, against your state in the database, not a state file. Orchestration also works without Infrastructure as a Database, with plain Terraform or OpenTofu state.

## What changes

- Plans are scoped. `stategraph tf plan` compares the pull request HCL with the current state, and plans only the resources that the change reaches. Plan time follows the size of the change.
- A plan adds the other states that the change reaches through `terraform_remote_state`. See [Multi-state transactions](/docs/infrastructure-as-a-database/multi-state).
- Conflicts are checked per resource at commit time. If two pull requests change different resources in the same state, both applies commit.
- If they overlap, Stategraph rejects the second, so that it cannot overwrite the first. You must plan it again. See [Resource-level locking](/docs/infrastructure-as-a-database/resource-locking).
- In the Enterprise edition, pull requests apply the same directory in parallel instead of waiting for its lock, whatever the lock policy. When Orchestration runs inside the Stategraph server, it refuses an apply that Stategraph would reject before it starts, and names the pull request and the resources. A pull request whose plan opened its transaction after another one's apply committed must plan again, and then wait for that one to merge. See [Locks in Infrastructure as a Database](/docs/orchestration/workflows/advanced/lock-management#locks-in-infrastructure-as-a-database). With other engines, directory locks follow your [lock policy](/docs/reference/orchestration/configuration/lock-policy).
- Each run is a transaction that records what changed, in which state, and by whom. See it with `stategraph tx list`, the **State Changes** page in the console, or SQL.

## Before you begin

- A Stategraph server that your runners can reach: [Stategraph Cloud](/docs/get-started/editions) or a [self-hosted server](/docs/admin/self-hosting).
- An API key that can plan and apply the states that Orchestration manages. See [Access tokens](/docs/admin/access-control/access-tokens).
- The Stategraph CLI on the machine for the one-time onboarding. The runner installs the CLI itself.

```bash
curl -fsSL https://get.stategraph.com/install.sh | sh
```

## Onboard each directory

Onboard each dirspace (a directory plus an optional workspace) once before its first run. Use a machine with the CLI, and with `STATEGRAPH_API_BASE`, `STATEGRAPH_API_KEY`, and `STATEGRAPH_TENANT_ID` exported.

1. Go to the directory that contains your `*.tf` files.
2. If the directory has no state, create one:

```bash
stategraph states create --name my-app
```

If you have a `terraform.tfstate`, import it instead:

```bash
stategraph import tf --name my-app terraform.tfstate
```

3. Commit the `stategraph.json` that the command writes, with your Terraform code.
4. Repeat for each directory that uses Infrastructure as a Database.

The runner passes the dirspace workspace to the plan. For several workspaces in one directory, create one state per workspace in the same group with `--workspace`. See [Adding workspaces](/docs/infrastructure-as-a-database/setup).

## Enable the engine

Set the engine in `.stategraph/config.yml`:

```yaml
engine:
  name: stategraph
```

To pin the CLI version that the runner installs, set `version` to a release from the [releases page](https://github.com/stategraph/releases/releases):

```yaml
engine:
  name: stategraph
  version: '<version>'
```

Stategraph wraps `terraform` by default. To wrap OpenTofu, set `tf_cmd` and `tf_version`:

```yaml
engine:
  name: stategraph
  tf_cmd: tofu
  tf_version: '1.7.0'
```

Set the engine globally or per workflow. For some directories only:

```yaml
workflows:
  - tag_query: dir:services/**
    engine:
      name: stategraph
```

All keys, including `override_tf_cmd`, are in the [engine reference](/docs/reference/orchestration/configuration/engine). For the other engines, see [Choosing an engine](/docs/orchestration/workflows/advanced/engine-setup).

## Runner secrets

Set these three required variables as secrets in your runner environment or self-hosted runner configuration. See [Environment variables](/docs/orchestration/configuration/environment-variables) for how they reach a run.

| Variable | Purpose |
|----------|---------|
| `STATEGRAPH_API_BASE` | URL of your Stategraph server, for example `https://stategraph.example.com` |
| `STATEGRAPH_API_KEY` | API key that can plan and apply the states |
| `STATEGRAPH_TENANT_ID` | The tenant UUID. To find it, run `stategraph info`. |

- GitHub: add each one as a repository secret, for example with `gh secret set STATEGRAPH_API_KEY`. The workflow file passes repository secrets to the runner.
- GitLab: in the project, open **Settings > CI/CD > Variables** and add each one. Select **Mask variable** for `STATEGRAPH_API_KEY`.

Full procedures: [Secrets and variables](/docs/orchestration/configuration/variables).

## Run plan and apply

Use Orchestration as usual. The runner calls `stategraph tf plan` and `stategraph tf apply` instead of `terraform`.

1. Open a pull request that changes a directory with `engine: stategraph`.
2. Orchestration plans on your GitHub Actions or GitLab CI runner, and comments the diff on the pull request.
3. Review the plan, and get the required approvals.
4. Comment `stategraph apply`. Orchestration runs the apply, and Stategraph commits the state changes to the database as a transaction.

## Limits

- Each dirspace runs as its own transaction. Orchestration does not run `stategraph tf mtx`.
- A plan or apply fails at preflight when a runner variable is missing, or when the directory has no committed `stategraph.json`. Onboard each directory first.
- The runner runs Terraform or OpenTofu on your CI infrastructure, with your cloud credentials. The server does not run your plans and applies.

## Next steps

- [Setup](/docs/infrastructure-as-a-database/setup): the `stategraph` CLI in detail.
- [Enable Orchestration](/docs/admin/self-hosting/orchestration): on a self-hosted server.
- [Pull request workflow](/docs/orchestration/workflows): plan, review, and apply.
