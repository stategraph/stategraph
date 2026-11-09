---
title: Migrating from Spacelift
description: "Move Spacelift stacks to Stategraph with a script: settings, environment, and hooks to .stategraph/config.yml, managed state to Infrastructure as a Database."
order: 4
---

To move from Spacelift to Stategraph, run a script that reads your stacks through the Spacelift API. It writes `.stategraph/config.yml` and the environment of each stack, downloads the Spacelift-managed state, and imports it into Infrastructure as a Database or pushes it to a bucket backend. Resolve the items that the script reports, and roll out on a pull request.

Plans and applies move from Spacelift workers to your GitHub Actions or GitLab CI runners. Your Terraform and OpenTofu code stays as it is.

To keep Spacelift and only send its plans and applies through the `stategraph` CLI, see [Spacelift](/docs/infrastructure-as-a-database/ci/spacelift) instead.

## How Spacelift maps to Stategraph

| Spacelift | Stategraph |
| --- | --- |
| A stack | A `dirs` entry and its workspace, tagged with the stack ID and its labels |
| Project root | The `dirs` key |
| Several stacks with one project root | Workspaces of one directory, named after the stacks |
| Project root and project globs | `when_modified.file_patterns` |
| `autodeploy` | `autoapply` |
| Tracked runs after a push to the branch | `apply_requirements` with `apply_after_merge` |
| Terraform or OpenTofu version | `engine` |
| Environment variables, mounted files, contexts | An `env` step that sources a file per stack in `.stategraph/spacelift/env` |
| Write-only values | GitHub secrets |
| Hooks of the stack and its contexts | `run` steps, in the same order |
| `.spacelift/config.yml` | Applied to the converted settings |
| Stack dependencies | `depends_on`, as [layered runs](/docs/orchestration/workflows/advanced/layered-runs) |
| AWS and Azure integrations | `oidc` steps |
| Plan policies | `conftest` steps with [gates](/docs/orchestration/governance/gatekeeper) |
| Drift detection | `drift.schedules` |
| Private worker pool | [Private runners](/docs/orchestration/security/private-runners) |
| Tracked branch | `destination_branches` |
| Spacelift-managed state | A state in [Infrastructure as a Database](/docs/infrastructure-as-a-database), or a bucket backend |

## Before you begin

- Connect the repository to Orchestration. See [Stategraph Cloud](/docs/get-started/quickstart/cloud) or [Self-hosted](/docs/get-started/quickstart/self-hosted).
- Install Python 3.8 or later and PyYAML, and the [Stategraph CLI](/docs/cli).
- Create an API key in Spacelift under **Organization settings → API keys**, with admin access to the space of the stacks. It reads stacks, contexts, and state.
- For Infrastructure as a Database, export `STATEGRAPH_API_BASE`, `STATEGRAPH_API_KEY`, and `STATEGRAPH_TENANT_ID`. See [Use with Orchestration](/docs/infrastructure-as-a-database/orchestration).

## Convert the stacks

Run the script from the root of your repository. `--repo` selects the stacks of the repository. Add a stack of another repository with `--stack`:

```bash
curl -sSLO https://stategraph.com/assets/migrate/spacelift-to-stategraph.py
pip install pyyaml
export SPACELIFT_API_KEY_ID=<key id>
export SPACELIFT_API_KEY_SECRET=<key secret>
python3 spacelift-to-stategraph.py --endpoint https://acme.app.spacelift.io \
  --repo acme/infra --state-dir ../spacelift-state \
  --report spacelift-migration-report.md
```

The script writes:

- `.stategraph/config.yml`
- `.stategraph/spacelift/env/<dir>/<workspace>.plan.env` and `.apply.env`: the environment of the stack, after the precedence of `.spacelift/config.yml`, the stack, attached contexts by priority, and auto-attached contexts. Variables with the `ro_` prefix go to the plan file only, and `wo_` to the apply file only. Paths under `/mnt/workspace` point to a directory of the run.
- `.stategraph/spacelift/files/<stack>/`: mounted files whose content Spacelift shows. A write-only mounted file comes from a GitHub secret at run time.
- `.stategraph/scripts/`: hook commands that use shell variables.
- `../spacelift-state/<stack>.tfstate` and `../spacelift-state/migrate-state.sh`: the current state of each stack with managed state, and the commands that import it. `--state-dir` must be outside the repository, because state files hold secrets.

A directory with one stack gets the workspace `default`. Several stacks with one project root become workspaces of that directory, named after the stacks.

Output:

```text
# Spacelift to Stategraph Orchestration conversion report

Converter: spacelift-to-stategraph.py 1.0.0
Source: Spacelift account acme
Output: .stategraph/config.yml
...

## Manual steps (3)

- `secrets`: Spacelift does not reveal write-only values. Create these GitHub secrets with the values: `SPACELIFT_NETWORK__TF_VAR_DB_PASSWORD`. For example: `gh secret set SPACELIFT_NETWORK__TF_VAR_DB_PASSWORD`.
- `runner secrets`: Set the GitHub secrets `STATEGRAPH_API_BASE`, `STATEGRAPH_API_KEY`, and `STATEGRAPH_TENANT_ID`, so that the runner can reach Infrastructure as a Database.
- `state`: Lock or disable each stack in Spacelift, run `sh ../spacelift-state/migrate-state.sh` to move the state, then delete the state files.
...
```

Manual steps need your action: resolve each one before you roll out. Notes describe a difference in behavior.

| Flag | Description |
| --- | --- |
| `--endpoint` | The URL of the Spacelift account, such as `https://acme.app.spacelift.io`. |
| `--repo` | Convert the stacks whose repository is `OWNER/NAME`. |
| `--stack` | Also convert this stack. Repeatable. |
| `--key-id-env`, `--key-secret-env` | The environment variables with the API key. Default is `SPACELIFT_API_KEY_ID` and `SPACELIFT_API_KEY_SECRET`. |
| `--state-dir` | Download the managed state of each stack into this directory, and write `migrate-state.sh`. |
| `--state-via-task` | When Spacelift refuses the state download, read the state with a Spacelift task. |
| `--backend` | Move the state to an `s3`, `gcs`, or `azurerm` backend, not to Infrastructure as a Database. |
| `--backend-config` | A setting of the backend block, as `KEY=VALUE`. Repeatable. |
| `--rewrite-code` | With `--backend`, write a `backend.tf` in the directory of each stack with managed state. |
| `--save-snapshot` | Write the API data that the conversion reads to a file. |
| `--snapshot` | Convert from that file, with no API access. |
| `--output` | The configuration to write. Default is `.stategraph/config.yml`. |
| `--report` | Also write the report to a file. |
| `--dry-run` | Print the files, and write nothing. |
| `--force` | Overwrite existing files. |

Exit status `0` means no manual steps, `2` means that the report lists manual steps, and `1` is an error.

## Move the state

A stack that keeps its own backend keeps its state there, and the converted configuration runs it with its engine. The steps below move Spacelift-managed state.

### Download the state

The script downloads the state of a stack when **External state access** is on in the backend settings of the stack. Spacelift refuses the download for some stacks even with the setting on, for example native OpenTofu stacks. For those, add `--state-via-task`. The script then runs a task on the stack that prints the state, compressed and base64-encoded, to the run log, and reads it from there. The state stays in that run log in Spacelift.

### Into Infrastructure as a Database

This is the default. Each stack becomes a state in [Infrastructure as a Database](/docs/infrastructure-as-a-database), and the converted configuration runs it with the `stategraph` engine.

1. Lock each stack in Spacelift, so that nobody applies there.

2. Export the connection to your Stategraph server, and the values of the write-only variables that the report lists. The import evaluates the configuration, so it needs every variable:

```bash
export STATEGRAPH_API_BASE=https://stategraph.example.com
export STATEGRAPH_API_KEY=<api key>
export STATEGRAPH_TENANT_ID=<tenant id>
export SPACELIFT_NETWORK__TF_VAR_DB_PASSWORD=<value>
```

For a write-only mounted file, export its content base64-encoded.

3. Run the script that the conversion wrote:

```bash
sh ../spacelift-state/migrate-state.sh
```

For each stack, it sources the environment file of the stack in the stack directory, and runs the equivalent of this command:

```bash
stategraph import tf --tenant "$STATEGRAPH_TENANT_ID" --name network --workspace default \
  ../../spacelift-state/network.tfstate
```

4. Commit the `stategraph.json` that each import writes. Several stacks in one directory share the group in that file.

5. Check the states:

```bash
stategraph states list --tenant "$STATEGRAPH_TENANT_ID"
stategraph states summary --state <state-id>
```

6. Delete the state files.

For the import on its own, see [Import your Terraform state](/docs/get-started/quickstart/import-state). For the engine and the runner secrets, see [Use with Orchestration](/docs/infrastructure-as-a-database/orchestration).

### Into a bucket backend

To keep Terraform state files, pass `--backend` and the settings of the backend:

```bash
python3 spacelift-to-stategraph.py --endpoint https://acme.app.spacelift.io \
  --repo acme/infra --state-dir ../spacelift-state \
  --backend s3 --backend-config bucket=acme-terraform-state \
  --backend-config region=us-west-2 --rewrite-code
```

`--rewrite-code` writes a `backend.tf` for each stack with managed state, with the key `spacelift/<stack>/terraform.tfstate`, or the prefix `spacelift/<stack>` for `gcs`. Pass `--backend-config key=...` to set it yourself. The configuration uses the `terraform` or `tofu` engine. For each stack, `migrate-state.sh` runs `init`, selects the workspace, and runs `state push` with `terraform` or `tofu`. Give the runner access to the bucket, for example with an [OIDC role](/docs/orchestration/security/cloud-credentials). Delete the state files after the push.

## Differences in behavior

- Each pull request plans the directories that it changes, and each plan comments on the pull request. Spacelift ran a proposed run, and posted a commit status.
- Changes apply after the merge, as tracked runs did. Comment `stategraph apply` on the merged pull request, or set `autoapply`, which the script sets for stacks with `autodeploy`. Remove `apply_after_merge` to apply before the merge.
- Spacelift matched the project root as a prefix, so `stacks/app2` also triggered `stacks/app`. Orchestration matches the directory.
- Each hook is a step in its own process. A variable that a hook exports does not reach the next steps: set it in the environment file of the stack.
- A stack dependency makes the dependent plan and apply in the same pull request, after its dependency applies. Spacelift started a tracked run of the dependent after the apply. Values from dependency references have no equivalent: read them with a `terraform_remote_state` data source.
- Spacelift run variables such as `TF_VAR_spacelift_run_id` are not set. The script sets the ones that do not change between runs, such as `TF_VAR_spacelift_stack_id`, when the code or a hook reads them.
- AWS and Azure integrations become `oidc` steps. The role or the app registration must now trust the GitHub OIDC issuer, not Spacelift.
- Orchestration reads `apply_requirements` and `destination_branches` from the default branch.

## Roll out

1. Open a pull request that adds `.stategraph/config.yml`, `.stategraph/spacelift/`, `.stategraph/scripts/`, each `stategraph.json`, and the [Orchestration workflow file](/docs/get-started/quickstart/cloud#add-the-workflow-file).
2. Check that each directory plans with no changes. A change means that a variable, a file, or the state differs from Spacelift.
3. Merge it.
4. Disable each stack in Spacelift, and delete `.spacelift/config.yml`.
5. When every stack has moved, delete the stacks and the contexts in Spacelift.

## Next steps

- [Use with Orchestration](/docs/infrastructure-as-a-database/orchestration): the `stategraph` engine
- [Configuration](/docs/orchestration/configuration): the `.stategraph/config.yml` reference
- [Cloud credentials](/docs/orchestration/security/cloud-credentials): OIDC for AWS, Google Cloud, and Azure
- [Migrating from Terraform Cloud](/docs/orchestration/migration/terraform-cloud): move from Terraform Cloud
