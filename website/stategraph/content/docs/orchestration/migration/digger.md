---
title: Migrating from Digger
description: "Convert digger.yml to .stategraph/config.yml with a script, resolve the items it reports, and roll out Stategraph Orchestration on a pull request."
order: 2
---

To move from Digger (renamed OpenTaco in November 2025) to Stategraph Orchestration, run a script that converts `digger.yml` to `.stategraph/config.yml`, resolve the items that the script reports, and roll out on a pull request. Your Terraform code and state do not change.

## How Digger maps to Orchestration

| Digger | Orchestration |
| --- | --- |
| A project (`name`, `dir`, `workspace`) | A `dirs` entry and its workspace, tagged with the project name |
| `include_patterns`, `exclude_patterns` | `when_modified.file_patterns`, with `!` for an exclude |
| `generate_projects` for Terraform or OpenTofu | One `dirs` entry for each directory that it matches |
| `generate_projects` for Terragrunt | The [Terragrunt config builder](/docs/orchestration/workflows/advanced/terragrunt-config-builder) |
| `workflows` | `workflows` entries, selected by a `workflow-<name>` tag |
| `env_vars` | `env` steps |
| `aws_role_to_assume` | `oidc` steps |
| `on_pull_request_pushed: [digger plan]` | `autoplan` |
| `on_commit_to_default: [digger apply]` | `autoapply` |
| `depends_on` | `depends_on`, as [layered runs](/docs/orchestration/workflows/advanced/layered-runs) |
| `apply_requirements: [approved]` | `apply_requirements` with `approved` |
| `auto_merge`, `auto_merge_strategy` | `automerge` |
| `pr_locks: false` | `lock_policy: none` |
| Action inputs: tool versions, cloud credentials | `engine`, `hooks` |
| A scheduled drift workflow | `drift.schedules` |

Pull request comments:

| Digger | Orchestration |
| --- | --- |
| `digger plan` | `stategraph plan` |
| `digger plan -p app` | `stategraph plan app` |
| `digger plan -d infra/app` | `stategraph plan dir:infra/app` |
| `digger apply` | `stategraph apply` |
| `digger unlock` | `stategraph unlock` |

As with `-p`, a tag in a comment selects only directories that the pull request changes.

## Before you begin

- Connect the repository to Orchestration. See [Stategraph Cloud](/docs/get-started/quickstart/cloud) or [Self-hosted](/docs/get-started/quickstart/self-hosted).
- Install Python 3.8 or later and PyYAML.

## Convert the configuration

Run the script from the root of your repository:

```bash
curl -sSLO https://stategraph.com/assets/migrate/digger-to-stategraph.py
pip install pyyaml
python3 digger-to-stategraph.py --report digger-migration-report.md
```

The script reads `digger.yml`, and each workflow in `.github/workflows` that runs `diggerhq/digger`. It writes `.stategraph/config.yml`. A `run` command that uses `$` moves to a script in `.stategraph/scripts/`, because the runner expands `$` before the shell does. The same input gives the same output.

Output:

```text
# Digger to Stategraph Orchestration conversion report

Converter: digger-to-stategraph.py 1.0.0
Source: digger.yml
Output: .stategraph/config.yml
Script: .stategraph/scripts/digger-db-plan-1.sh

## Manual steps (0)

None.

## Notes (5)

- `workflows.db.plan.steps[1]`: The command uses `$`, which the runner would expand before the shell. It moved to `.stategraph/scripts/digger-db-plan-1.sh`.
...
```

Manual steps need your action: resolve each one before you roll out. Notes describe a difference in behavior.

| Flag | Description |
| --- | --- |
| `--repo-root` | The repository checkout. Default is the current directory. |
| `--digger-file` | The Digger configuration. Default is `digger.yml` or `digger.yaml` in the repository. |
| `--workflows-dir` | The GitHub Actions workflows. Default is `.github/workflows`. |
| `--output` | The configuration to write. Default is `.stategraph/config.yml`. |
| `--report` | Also write the report to a file. |
| `--dry-run` | Print the files, and write nothing. |
| `--force` | Overwrite existing files. |

Exit status `0` means no manual steps, `2` means that the report lists manual steps, and `1` is an error.

## State

Your state stays in its backend, and the converted configuration runs Terraform on it as Digger did. To move each state into [Infrastructure as a Database](/docs/infrastructure-as-a-database) instead:

1. Import the state of each directory and workspace with `stategraph import tf`, and commit the `stategraph.json` that it writes. See [Import your Terraform state](/docs/get-started/quickstart/import-state).
2. Set `engine: {name: stategraph}` in `.stategraph/config.yml`, and in each workflow that sets `engine`. `extra_args` of a `plan` step take the flags of `stategraph tf plan`, such as `--var-file`. Add the runner secrets. See [Use with Orchestration](/docs/infrastructure-as-a-database/orchestration).
3. Remove the `backend` block from the configuration.

## Differences in behavior

- A directory that no Digger project names never runs. The converted configuration sets the global `file_patterns` to `[]`.
- Orchestration plans a dependent directory after its dependency applies. Digger planned them together.
- Orchestration locks a directory when it applies or merges, not when it plans. A pull request that applied and closes without a merge keeps its locks until you comment `stategraph unlock <number>`.
- When another pull request applies a directory, plan your pull request again before you apply it.
- Orchestration does not plan a pull request that has merge conflicts.
- `env_vars` also reach `run` steps.
- Orchestration reads `apply_requirements`, `access_control`, and `destination_branches` from the default branch.

## Roll out

1. Open a pull request that adds `.stategraph/config.yml`, `.stategraph/scripts/`, and the [Orchestration workflow file](/docs/get-started/quickstart/cloud#add-the-workflow-file). Comment `stategraph repo-config` to see the configuration that Orchestration derives.
2. Merge it. Orchestration reads the workflow file and the apply requirements from the default branch.
3. Remove `digger.yml` and the Digger workflows in the next pull request, so that one tool plans and applies. Then uninstall the Digger GitHub App.
4. Open a pull request that changes one directory. Compare the plan with the last Digger plan, and apply it.
5. If Digger ran without its backend, delete its lock table in DynamoDB, Google Cloud Storage, or Azure Storage.

## Next steps

- [Configuration](/docs/orchestration/configuration): the `.stategraph/config.yml` reference
- [Layered runs](/docs/orchestration/workflows/advanced/layered-runs): how `depends_on` orders directories
- [Tags and tag queries](/docs/orchestration/workflows/advanced/tag-system): select directories in workflows and comments
- [Migrating from Terraform Cloud](/docs/orchestration/migration/terraform-cloud): move workspaces from Terraform Cloud
- [Migrating from Atlantis](/docs/orchestration/migration/atlantis): move from Atlantis
