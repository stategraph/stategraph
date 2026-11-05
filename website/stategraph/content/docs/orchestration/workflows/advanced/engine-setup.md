---
title: Choosing an Engine
description: Choose the engine that runs plan and apply: Terraform, OpenTofu, the stategraph CLI, Terragrunt, Pulumi, CDKTF, or a custom command.
order: 7
---


The engine is the tool that Stategraph Orchestration runs for each plan and apply: Terraform, OpenTofu, the `stategraph` CLI, Terragrunt, Pulumi, CDKTF, or a custom command. The default is the Terraform CLI. Set the [`engine`](/docs/reference/orchestration/configuration/engine) key at the top level of `.stategraph/config.yml`, or override it per workflow.

## Built-in engines

### Terraform (default)

```yaml
engine:
  name: terraform
  version: '1.5.7'
```

### OpenTofu

```yaml
engine:
  name: tofu
  version: '1.9.0'
```

See [OpenTofu](/docs/orchestration/iac-tools/opentofu).

### Terragrunt

```yaml
engine:
  name: terragrunt
  tf_version: '1.5.7'
```

`tf_cmd` selects the tool under Terragrunt (`terraform` by default, or `tofu`), and `tf_version` pins its version. See [Terragrunt](/docs/orchestration/iac-tools/terragrunt).

### CDKTF

```yaml
engine:
  name: cdktf
  tf_cmd: tofu
```

See [CDKTF](/docs/orchestration/iac-tools/cdktf).

### Pulumi

```yaml
engine:
  name: pulumi
```

The `pulumi` engine takes no other keys. See [Pulumi](/docs/orchestration/iac-tools/pulumi).

### Stategraph

```yaml
engine:
  name: stategraph
  tf_cmd: tofu
```

The `stategraph` engine runs the `stategraph` CLI and keeps your state in Infrastructure as a Database, in place of a Terraform backend. The runner calls `stategraph tf plan` and `stategraph tf apply`. These commands run Terraform or OpenTofu and store the state in your Stategraph server. The engine does not collect outputs. For scoped plans, resource locks, and transactions, see [Use with Orchestration](/docs/infrastructure-as-a-database/orchestration).

## Setting up the Stategraph engine

### Prerequisites

- A Stategraph server that your runners can reach: [Stategraph Cloud](https://app.stategraph.cloud) or a [self-hosted deployment](/docs/admin/self-hosting).
- An [API key](/docs/admin/access-control/access-tokens) with permission to plan and apply the states of the repository.
- The tenant ID. `stategraph info` lists your tenants.
- The `stategraph` CLI on a developer machine, for the one-time onboarding:

```bash
curl -sSL https://get.stategraph.com/install.sh | sh
```

### Onboard each directory once

Each directory (with its workspace) needs a Stategraph state before its first run. On a developer machine, export `STATEGRAPH_API_BASE`, `STATEGRAPH_API_KEY`, and `STATEGRAPH_TENANT_ID`. Then:

1. Go to the directory that holds the `*.tf` files.
2. If the directory has no `terraform.tfstate`, create a new state:

```bash
stategraph states create --name my-app
```

3. If a `terraform.tfstate` exists, import it:

```bash
stategraph import tf --name my-app terraform.tfstate
```

4. Both commands write `stategraph.json` in the directory. Commit it next to the Terraform code.
5. Do these steps for each directory that uses this engine.

For all options, see [states](/docs/cli/states) and [import](/docs/cli/import).

### Enable the engine

After you commit `stategraph.json` in each directory, set the engine:

```yaml
engine:
  name: stategraph
```

To pin the CLI version that the runner uses, set `version` to a release from the [releases page](https://github.com/stategraph/releases/releases):

```yaml
engine:
  name: stategraph
  version: '<version>'
```

To run OpenTofu in place of Terraform, set `tf_cmd` and `tf_version`:

```yaml
engine:
  name: stategraph
  tf_cmd: tofu
  tf_version: '1.9.0'
```

`override_tf_cmd` sets the Terraform or OpenTofu program that the CLI calls (`TF_CMD`), in place of `terraform` or `tofu`.

### Runner secrets

The runner needs three environment variables. Set them as GitHub Actions secrets on GitHub, as masked CI/CD variables on the GitLab project, or in your self-hosted runner configuration. See [Variables](/docs/orchestration/configuration/variables).

| Variable | Purpose |
|----------|---------|
| `STATEGRAPH_API_BASE` | URL of your Stategraph server, for example `https://stategraph.example.com` |
| `STATEGRAPH_API_KEY` | API key with permission to plan and apply the relevant states |
| `STATEGRAPH_TENANT_ID` | The tenant UUID |

All three are required. The engine's preflight fails the run if one is missing, or if the directory has no `stategraph.json`.

### Plan and apply

1. Open a pull request that changes a directory with `engine: stategraph`.
2. Orchestration runs a plan and posts the diff on the pull request.
3. Review the plan, get the required approvals, and comment `stategraph apply`.
4. Orchestration applies against your Stategraph server. The Stategraph database records the state changes.

## Custom engine

Use a custom engine for tools outside the Terraform family, for wrappers, or for legacy systems. Each key is one step, and every step is optional. Set only the steps that your workflow needs.

```yaml
engine:
  name: custom
  # The command to run during the init step (optional)
  init: ['echo', 'init']
  # The command to run during the plan step (optional)
  plan: ['my-custom-plan']
  # The command to produce a human-readable diff of the plan output (optional)
  diff: ['printf', '+ added foo\n- removed bar\n~ updated bar\n']
  # The command to print the plan's resource counts as JSON (optional)
  resource_summary: ['echo', '{"created": 1, "updated": 0, "replaced": 0, "deleted": 0, "imported": 0}']
  # The command to run during the apply step (optional)
  apply: ['my-custom-apply']
  # The command to run for stategraph apply-autoapprove, which has no stored plan (optional)
  unsafe_apply: ['my-custom-apply', '--no-plan']
  # The command to return output values as a JSON string (optional)
  outputs: ['echo', '{"foo": "bar"}']
```

- `resource_summary` prints a JSON object with the integer keys `created`, `updated`, `replaced`, `deleted`, and `imported`. It runs after a plan that reports changes, and the counts appear in the summary comment. `imported` counts the resources that the plan imports, whatever their action. A key that the program leaves out shows as `-`.
- `unsafe_apply` runs for [`stategraph apply-autoapprove`](/docs/reference/orchestration/commands/apply-autoapprove).
- To pass data from the plan step to the apply step, write it to the path in `TERRATEAM_PLAN_FILE`. The apply step can read it there.

!!! note "Plan exit codes"
    The exit code of the `plan` command sets the result. `0` means that the plan succeeded and there are changes. `2` means that the plan succeeded and there are no changes. Any other exit code is a failure. Terraform and OpenTofu use the reverse with `-detailed-exitcode`, where `2` means changes. Wrap those tools if you pass their exit code through.

## Per-workflow engines

Different workflows can use different engines, for example when environments need different tools. Put the `engine` block in the workflow entry:

```yaml
workflows:
  - tag_query: "development"
    engine:
      name: tofu
  - tag_query: "production"
    engine:
      name: terraform
```

## Best practices

- Pin versions. Use `version` on the `terraform` and `tofu` engines. Use `tf_cmd` and `tf_version` on the `terragrunt`, `cdktf`, and `stategraph` engines to control which Terraform-compatible CLI runs.
- Test custom engines locally with the environment variables that the runner sets, especially `TERRATEAM_PLAN_FILE`.

## Next steps

- [engine reference](/docs/reference/orchestration/configuration/engine)
- [Use with Orchestration](/docs/infrastructure-as-a-database/orchestration)
- [Runner environment variables](/docs/orchestration/configuration/environment-variables)
