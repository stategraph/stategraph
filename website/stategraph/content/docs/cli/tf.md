---
title: Terraform Commands
description: Reference for stategraph tf plan, apply, show, and mtx, which plan and apply Terraform changes through Stategraph with plan files and cost previews.
order: 6
---


The `stategraph tf` commands plan, apply, and show Terraform changes through Stategraph, in place of `terraform plan` and `terraform apply`. Stategraph finds what your change reaches, runs Terraform or OpenTofu on your machine or runner, and records the change in a transaction.

When your change reaches other states through `terraform_remote_state`, the plan includes them in the same transaction. To plan several directories that you choose in one transaction, use [`stategraph tf mtx`](#stategraph-tf-mtx).

`stategraph plan` and `stategraph apply` are aliases for `stategraph tf plan` and `stategraph tf apply`. In a pull request comment, the same words start a Stategraph Orchestration run. See [Pull request commands](/docs/reference/orchestration/commands).

## Commands

| Command | Description |
|---------|-------------|
| `stategraph tf plan` | Compare the local HCL with the current state |
| `stategraph tf apply` | Apply a plan file, or plan and apply in one step |
| `stategraph tf show` | Show a plan file again, as text or JSON |
| `stategraph tf mtx` | Plan the directories that you choose in one transaction |

Usually, `plan --out` writes a plan file, you review it, and `apply` commits it.

```bash
# From your root module directory
stategraph tf plan --tenant <tenant-id> --out plan.json
stategraph tf apply plan.json
```

## stategraph tf plan

Run it from your root module directory.

```bash
stategraph tf plan --tenant <tenant-id> [--out <plan-file>] [options]
```

### Options

| Option | Required | Description |
|--------|----------|-------------|
| `--tenant` | Yes | Tenant ID (UUID) |
| `--out` | No | Plan file for a later `stategraph tf apply`. Without it, you get a read-only preview and no file. |
| `--state` | No | State ID. Default: read from `stategraph.json`. |
| `--workspace` | No | Workspace name. Default: `default`. |
| `--var` | No | A variable, as `key=value`. Repeatable. |
| `--var-file` | No | Path to a variable file |
| `--force` | No | Add a node address to the plan. Accepts globs, for example `data.*`. Repeatable. |
| `--skip-refresh` | No | Skip the state refresh (passes `-refresh=false` to `terraform plan`) |
| `--skip-costs` | No | Skip the cost-delta preview after the plan diff |
| `--costs-wait` | No | Maximum seconds to wait for the cost delta. Default: `3`. Not with `--skip-costs`. |
| `--skip-security` | No | Skip the security-impact preview after the plan diff |
| `--security-wait` | No | Maximum seconds to wait for the security impact. Default: `3`. Not with `--skip-security`. |
| `--tx-tags` | No | Tags for the transaction of this plan, as a JSON object |
| `--diagnostics` | No | Evaluate the HCL with low-cost tracing. Optional mode: `rollup`, `on` (default for a bare `--diagnostics`), `detail`, `verbose`, or `perf`. See [Diagnostics](/docs/cli/diagnostics). |
| `--batch-size` | No | Batch size for transaction log appends (performance tuning) |
| `--parallel-batches` | No | Number of parallel batches for transaction log appends (performance tuning) |
| `--detailed-exitcode` | No | Return the exit codes of `tofu plan` and `terraform plan` with `-detailed-exitcode`, for CI scripts |

`--var` and `--var-file` work as in `terraform plan`.

### Example

```bash
stategraph tf plan --tenant 550e8400-e29b-41d4-a716-446655440000 --out plan.json
```

The output ends with the usual summary line. When [cost analysis](/docs/infrastructure-as-a-database/cost) is configured, a cost preview follows:

```text
Plan: 1 to add, 0 to change, 0 to destroy.

Costs:
  Totals:
    Monthly:  130.82 USD → 140.16 USD   (+9.34 USD)
    ...
```

If the cost or security-impact preview is not ready within `--costs-wait` or `--security-wait` seconds, the plan prints a hint to use `stategraph tx costs` or `stategraph security impact`. See [Plan-time cost](/docs/infrastructure-as-a-database/cost/plan-time).

### Subgraph census lines

With `--verbosity=debug` (or `--verbosity=info`), the plan log carries one `PLAN_SUBGRAPH_COUNT` line per node type, plus a summary line:

```text
<tx> : PLAN_SUBGRAPH_COUNT : type=hcl   seed=11 cone=44 blast=21 total=76
<tx> : PLAN_SUBGRAPH_COUNT : type=state seed=0  cone=0  blast=7  total=7
<tx> : PLAN_SUBGRAPH_COUNT :            seed=14 cone=46 blast=28 total=88
```

These count the subgraph the plan handed to Terraform: `seed`, `cone`, and `blast` are the walks that collected the nodes, and the same rows are queryable through MQL as the `transaction_subgraphs` table (see [Query language](/docs/infrastructure-as-a-database/query/query)).

The neighboring `PLAN_STATE_NODE_COUNT` lines count the **whole state's** resources and outputs for the touched states — the size of the state, not the size of the slice. Do not read them as plan numbers.

The census goes to stderr and never affects the plan's exit code.

### Forcing resources into a plan

By default, a plan includes only what your change reaches. `--force` adds more addresses:

```bash
# Re-plan every data source
stategraph tf plan --tenant <tenant-id> --out plan.json --force 'data.*'

# Force one module into the plan
stategraph tf plan --tenant <tenant-id> --out plan.json --force 'module.networking.*'
```

## stategraph tf apply

With a plan file, `apply` commits it. With no plan file, it runs a new plan, shows the diff, and asks for approval before it commits.

```bash
stategraph tf apply [options] [<plan-file>]
```

### Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| `<plan-file>` | No | Plan file from `stategraph tf plan` or `stategraph tf mtx` |

### Options

| Option | Required | Description |
|--------|----------|-------------|
| `--skip-revision-check` | No | Skip the revision hash check between plan and apply |
| `--auto-approve` | No | Skip the approval prompt when you apply without a plan file. No effect with a plan file. |

The plan file records the state revision. If the state changed after the plan, `apply` stops, so you never apply a stale plan. Plan again.

### Applying without a plan file

Without `<plan-file>`, `stategraph tf apply` works like `terraform apply`. To skip the prompt, add `--auto-approve`:

```bash
stategraph tf apply --tenant <tenant-id> --auto-approve
```

The prompt needs an interactive terminal. When stdin is not a tty, or with `--silent` (`STATEGRAPH_SILENT`), the apply fails without `--auto-approve`. In CI, use `--silent` with `--auto-approve`.

When the plan has no changes, `apply` does not prompt.

In this form, `apply` accepts the `stategraph tf plan` options for its new plan, except `--out`, `--diagnostics`, and `--detailed-exitcode`. A saved plan file already has these choices, and several of the options then cause a usage error.

### Example

```bash
stategraph tf apply plan.json
```

## stategraph tf show

The default output is text for people to read.

```bash
stategraph tf show [options] <plan-file>
```

### Options

| Option | Required | Description |
|--------|----------|-------------|
| `--json` | No | Show the plan as JSON with all names unmangled, for policy checks and tools |

### Example

```bash
# Review a plan again before applying
stategraph tf show plan.json

# Feed the plan into tooling
stategraph tf show --json plan.json | jq '.'
```

## stategraph tf mtx

`mtx` plans the directories that you name in one atomic transaction: all states apply, or none do. For each directory, it plans all workspaces in the group of that directory.

```bash
stategraph tf mtx --tenant <tenant-id> --out <plan-file> [options] <dir>...
```

### Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| `<dir>...` | Yes | One or more directories. Each must contain `stategraph.json`. |

### Options

`--tenant` and `--out` are required. `mtx` also takes these [`tf plan` options](#stategraph-tf-plan): `--force`, `--skip-refresh`, `--skip-costs`, `--costs-wait`, `--skip-security`, `--security-wait`, `--batch-size`, `--parallel-batches`, and `--detailed-exitcode`.

### Example

```bash
stategraph tf mtx --tenant <tenant-id> --out plan.json ./networking ./compute ./application
stategraph tf apply plan.json
```

For the dependency rules and guarantees across states, see [Multi-state transactions](/docs/infrastructure-as-a-database/multi-state).

## Configuration

| Environment Variable | Description |
|---------------------|-------------|
| `TF_CMD` | The Terraform or OpenTofu binary. Default: `tofu`, then `terraform`, whichever the CLI finds first. |
| `STATEGRAPH_TENANT_ID` | Tenant ID, in place of `--tenant` |
| `STATEGRAPH_WORKSPACE` | Workspace name, in place of `--workspace` |
| `STATEGRAPH_COSTS_WAIT_SECONDS` | Default for `--costs-wait` |
| `STATEGRAPH_SECURITY_WAIT_SECONDS` | Default for `--security-wait` |
| `STATEGRAPH_TX_TAGS` | Default for `--tx-tags` (a JSON object) |
| `STATEGRAPH_DIAGNOSTICS` | Default for `--diagnostics` (`tf plan` only) |
| `STATEGRAPH_TX_BATCH_SIZE` | Default for `--batch-size` |
| `STATEGRAPH_TX_PARALLEL_BATCHES` | Default for `--parallel-batches` |
| `STATEGRAPH_ACTUATOR_RUN_DIR` | Directory where the CLI keeps the exact Terraform tree it planned, per run, under `preview/<timestamp>/` |

> `STATEGRAPH_ACTUATOR_RUN_DIR` is an **internal debug switch** for support investigations. It is not covered by support agreements, and its layout or behaviour may change between releases.

## Next Steps

- [Setup](/docs/infrastructure-as-a-database/setup): import a state and plan
- [Multi-state transactions](/docs/infrastructure-as-a-database/multi-state): plan and apply several states in one transaction
- [Plan-time cost](/docs/infrastructure-as-a-database/cost/plan-time): read the `Costs:` block
- [Refactor](/docs/cli/refactor): generate `moved` blocks for HCL restructuring
- [Transactions](/docs/cli/transactions): inspect plan transactions
- [Terraform CLI compatibility](/docs/reference/terraform-compatibility): flag-by-flag mapping from `terraform plan` and `apply`
