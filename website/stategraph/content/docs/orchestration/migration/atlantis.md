---
title: Migrating from Atlantis
description: "Convert atlantis.yaml and the server repos.yaml to .stategraph/config.yml with a script, resolve the items it reports, and roll out on a pull request."
order: 3
---

To move from Atlantis to Stategraph Orchestration, run a script that converts `atlantis.yaml` and the server-side `repos.yaml` to `.stategraph/config.yml`, resolve the items that the script reports, and roll out on a pull request. Your Terraform code and state do not change. Plans and applies move from the Atlantis server to your GitHub Actions or GitLab CI runners.

To keep Atlantis and only send its plans and applies through the `stategraph` CLI, see [Atlantis](/docs/infrastructure-as-a-database/ci/atlantis) instead.

## How Atlantis maps to Orchestration

| Atlantis | Orchestration |
| --- | --- |
| A project (`name`, `dir`, `workspace`) | A `dirs` entry and its workspace, tagged with the project name |
| `dir` glob | One `dirs` entry for each directory that it matches |
| `autoplan.when_modified` | `when_modified.file_patterns`, relative to the repository root |
| `autoplan.enabled: false` | `autoplan: false` |
| `autodiscover` | The global `when_modified.file_patterns` |
| `workflows` in `atlantis.yaml` or `repos.yaml` | `workflows` entries, selected by a `workflow-<name>` tag |
| `env`, `multienv` | `env` steps |
| `run` | `run` steps, and `terraform`, `tofu`, or `terragrunt` commands become `init`, `plan`, and `apply` steps |
| `terraform_version`, `terraform_distribution` | `engine` |
| `execution_order_group`, `depends_on` | `depends_on`, as [layered runs](/docs/orchestration/workflows/advanced/layered-runs) |
| `apply_requirements` | `apply_requirements` |
| Policy sets in `repos.yaml` | `conftest` steps with [gates](/docs/orchestration/governance/gatekeeper) for the policy owners |
| `pre_workflow_hooks`, `post_workflow_hooks` | `hooks` |
| terragrunt-atlantis-config in a pre-workflow hook | The [Terragrunt config builder](/docs/orchestration/workflows/advanced/terragrunt-config-builder) |
| `automerge`, `--automerge-method`, `delete_source_branch_on_merge` | `automerge` |
| `repo_locks` | `lock_policy` |
| `--gh-team-allowlist` | `access_control` |

Pull request comments:

| Atlantis | Orchestration |
| --- | --- |
| `atlantis plan` | `stategraph plan` |
| `atlantis plan -p app` | `stategraph plan app` |
| `atlantis plan -d infra/app -w staging` | `stategraph plan dir:infra/app workspace:staging` |
| `atlantis apply` | `stategraph apply` |
| `atlantis approve_policies` | `stategraph gate approve <token>` |
| `atlantis unlock` | `stategraph unlock` |

As with `-p`, a tag in a comment selects only directories that the pull request changes. A project without a `name` has no name tag: select it with `dir:`.

## Before you begin

- Connect the repository to Orchestration. See [Stategraph Cloud](/docs/get-started/quickstart/cloud) or [Self-hosted](/docs/get-started/quickstart/self-hosted).
- Install Python 3.8 or later and PyYAML.
- Get the `repos.yaml` of your Atlantis server, and its server configuration file if it has one. The script converts the repository settings without them, but requirements, workflows, hooks, and policies often live there.

## Convert the configuration

Run the script from the root of your repository:

```bash
curl -sSLO https://stategraph.com/assets/migrate/atlantis-to-stategraph.py
pip install pyyaml
python3 atlantis-to-stategraph.py \
  --server-config repos.yaml --repo-id github.com/acme/infra \
  --server-flags atlantis-server.yaml \
  --report atlantis-migration-report.md
```

The script reads `atlantis.yaml`, the `repos[]` entries of `repos.yaml` that match `--repo-id`, and the server flags. It writes `.stategraph/config.yml`. A command that uses `$` moves to a script in `.stategraph/scripts/`, because the runner expands `$` before the shell does. The script sets the Atlantis variables that the command reads, such as `$WORKSPACE`, `$PLANFILE`, `$SHOWFILE`, and `$PROJECT_NAME`. The same input gives the same output.

Output:

```text
# Atlantis to Stategraph Orchestration conversion report

Converter: atlantis-to-stategraph.py 1.0.0
Source: atlantis.yaml
Output: .stategraph/config.yml
Script: .stategraph/scripts/atlantis-custom-plan-1.sh
...

## Manual steps (1)

- `policies.policy_sets[0]`: Atlantis read the policies from `/home/atlantis/policy` on the Atlantis server. Commit them to the repository, and set that path in the `CONFTEST_POLICY` env step.
...
```

Manual steps need your action: resolve each one before you roll out. Notes describe a difference in behavior.

| Flag | Description |
| --- | --- |
| `--repo-root` | The repository checkout. Default is the current directory. |
| `--atlantis-file` | The repository configuration. Default is `atlantis.yaml`, or the `repo_config_file` of `repos.yaml`. |
| `--server-config` | The server-side `repos.yaml`. Needs `--repo-id`. |
| `--repo-id` | The repository as Atlantis names it, for example `github.com/acme/infra`. |
| `--server-flags` | The Atlantis server configuration file, with flag names as keys, for example `automerge: true`. |
| `--base-branch` | Keep only the projects whose `branch` regex matches this branch, as Atlantis does. |
| `--output` | The configuration to write. Default is `.stategraph/config.yml`. |
| `--report` | Also write the report to a file. |
| `--dry-run` | Print the files, and write nothing. |
| `--force` | Overwrite existing files. |

Exit status `0` means no manual steps, `2` means that the report lists manual steps, and `1` is an error. The script rejects a configuration that Atlantis rejects, such as an unknown key or a restricted key without `allowed_overrides`.

## State

Your state stays in its backend, and the converted configuration runs Terraform on it as Atlantis did. To move each state into [Infrastructure as a Database](/docs/infrastructure-as-a-database) instead:

1. Import the state of each directory and workspace with `stategraph import tf`, and commit the `stategraph.json` that it writes. See [Import your Terraform state](/docs/get-started/quickstart/import-state).
2. Set `engine: {name: stategraph}` in `.stategraph/config.yml`, and in each workflow that sets `engine`. `extra_args` of a `plan` step take the flags of `stategraph tf plan`, such as `--var-file`. Add the runner secrets. See [Use with Orchestration](/docs/infrastructure-as-a-database/orchestration).
3. Remove the `backend` block from the configuration.

## Differences in behavior

- Each run starts from a fresh checkout, so every apply runs `init` first.
- Orchestration merges the destination branch into the pull request before each run, as `--checkout-strategy=merge` does.
- For `mergeable`, Orchestration requires every status check to pass. GitHub requires only the required checks.
- Atlantis applied with no requirements by default. The converted configuration turns off the merge conflict and status check requirements to match. Remove those lines to require them.
- Orchestration plans a later `execution_order_group` after the earlier groups apply, not in the same run.
- Orchestration locks a directory when it applies or merges, not when it plans. A pull request that applied and closes without a merge keeps its locks until you comment `stategraph unlock <number>`.
- When another pull request applies a directory, plan your pull request again before you apply it.
- An approval from the author of the pull request does not count for a gate.
- Orchestration runs up to three directories at the same time. Set `parallel_runs: 1` to run one at a time.
- Orchestration reads `apply_requirements`, `access_control`, and `destination_branches` from the default branch.

## Roll out

1. Open a pull request that adds `.stategraph/config.yml`, `.stategraph/scripts/`, any policies that the report asks for, and the [Orchestration workflow file](/docs/get-started/quickstart/cloud#add-the-workflow-file). Comment `stategraph repo-config` to see the configuration that Orchestration derives.
2. Merge it. Orchestration reads the workflow file and the apply requirements from the default branch.
3. Remove the repository from the Atlantis `--repo-allowlist`, or remove the Atlantis webhook, so that one tool plans and applies. Then remove `atlantis.yaml`.
4. Open a pull request that changes one directory. Compare the plan with the last Atlantis plan, and apply it.
5. When every repository has moved, shut down the Atlantis server.

## Next steps

- [Configuration](/docs/orchestration/configuration): the `.stategraph/config.yml` reference
- [Gatekeeper](/docs/orchestration/governance/gatekeeper): approvals for failed policy checks
- [Layered runs](/docs/orchestration/workflows/advanced/layered-runs): how `depends_on` orders directories
- [Migrating from Digger](/docs/orchestration/migration/digger): move from Digger
