---
title: Migrating from Terraform Cloud
description: "Move HCP Terraform workspaces to Stategraph with a script: settings and variables to .stategraph/config.yml, state to a bucket backend or to Infrastructure as a Database."
order: 1
---

To move from HCP Terraform (Terraform Cloud) or Terraform Enterprise to Stategraph, run a script that reads your workspaces through the API. It writes `.stategraph/config.yml` and the workspace variables, downloads the state of each workspace, and imports it into Infrastructure as a Database or pushes it to a bucket backend. Resolve the items that the script reports, and roll out on a pull request.

Plans and applies move from Terraform Cloud to your GitHub Actions or GitLab CI runners. Your Terraform code stays, without its `cloud` block.

## How Terraform Cloud maps to Stategraph

| Terraform Cloud | Stategraph |
| --- | --- |
| A workspace | A `dirs` entry and its workspace, tagged with the workspace name |
| Working directory, or the directory of the `cloud` block | The `dirs` key |
| Several workspaces in one directory | Workspaces of one directory, one state each |
| Trigger prefixes, trigger patterns | `when_modified.file_patterns` |
| Automatic speculative plans off | `autoplan: false` |
| Auto-apply | `autoapply` |
| Apply after merge (VCS workflow) | `apply_requirements` with `apply_after_merge` |
| Terraform version | `engine` |
| Terraform variables, variable sets | A var file per workspace in `.stategraph/tfc/vars` |
| Environment variables | An `env` step that sources a file per workspace |
| Sensitive variables | GitHub secrets |
| Run triggers | `depends_on`, as [layered runs](/docs/orchestration/workflows/advanced/layered-runs) |
| Dynamic provider credentials | `oidc` steps |
| VCS branch | `destination_branches` |
| Health assessments | `drift.schedules` |
| Workspace state | A state in [Infrastructure as a Database](/docs/infrastructure-as-a-database), or a bucket backend |

## Before you begin

- Connect the repository to Orchestration. See [Stategraph Cloud](/docs/get-started/quickstart/cloud) or [Self-hosted](/docs/get-started/quickstart/self-hosted).
- Install Python 3.8 or later and PyYAML, and the [Stategraph CLI](/docs/cli).
- Create an organization API token in HCP Terraform under **Settings → API tokens**. It reads workspaces, variables, and state.
- For Infrastructure as a Database, export `STATEGRAPH_API_BASE`, `STATEGRAPH_API_KEY`, and `STATEGRAPH_TENANT_ID`. See [Use with Orchestration](/docs/infrastructure-as-a-database/orchestration).

## Convert the workspaces

Run the script from the root of your repository. `--repo` selects the VCS workspaces of the repository. Add CLI-driven workspaces with `--workspace`:

```bash
curl -sSLO https://stategraph.com/assets/migrate/tfc-to-stategraph.py
pip install pyyaml
export TFC_TOKEN=<organization token>
python3 tfc-to-stategraph.py --org acme --repo acme/infra \
  --workspace network --state-dir ../tfc-state \
  --rewrite-code --report tfc-migration-report.md
```

The script writes:

- `.stategraph/config.yml`
- `.stategraph/tfc/vars/<dir>/<workspace>.tfvars`: the Terraform variables, after the precedence of workspace variables and variable sets. The plan reads it as a var file, so these values still win over `*.tfvars` in the repository, as in Terraform Cloud.
- `.stategraph/tfc/vars/<dir>/<workspace>.env`: the environment variables. At run time it also writes the sensitive Terraform variables from GitHub secrets to a temporary var file.
- `../tfc-state/<workspace>.tfstate` and `../tfc-state/migrate-state.sh`: the current state of each workspace, and the commands that import it. `--state-dir` must be outside the repository, because state files hold secrets.
- With `--rewrite-code`, the Terraform code without its `cloud` and `backend "remote"` blocks.

A CLI-driven workspace has no working directory in the API. The script finds its directory from the `cloud` or `backend "remote"` block that names it, by name, tags, or prefix. Pass `--workspace-dir <workspace>=<dir>` when no block names it.

A directory with one workspace gets the workspace `default`, unless the code reads `terraform.workspace`. Then, and for several workspaces in a directory, each workspace keeps its Terraform Cloud name, or the part after the prefix of a `backend "remote"` block.

Output:

```text
# Terraform Cloud to Stategraph Orchestration conversion report

Converter: tfc-to-stategraph.py 1.0.0
Source: Terraform Cloud organization acme
Output: .stategraph/config.yml
...

## Manual steps (3)

- `secrets`: Terraform Cloud does not reveal sensitive values. Create these GitHub secrets with the values: `TFC_NETWORK__DB_PASSWORD`. For example: `gh secret set TFC_NETWORK__DB_PASSWORD`.
- `runner secrets`: Set the GitHub secrets `STATEGRAPH_API_BASE`, `STATEGRAPH_API_KEY`, and `STATEGRAPH_TENANT_ID`, so that the runner can reach Infrastructure as a Database.
- `state`: Run `sh ../tfc-state/migrate-state.sh` to move the state, then delete the state files.
...
```

Manual steps need your action: resolve each one before you roll out. Notes describe a difference in behavior.

| Flag | Description |
| --- | --- |
| `--org` | The organization. |
| `--repo` | Convert the workspaces whose VCS repository is `OWNER/NAME`. |
| `--workspace` | Also convert this workspace. Repeatable. |
| `--workspace-dir` | The directory of a CLI-driven workspace, as `NAME=DIR`. Repeatable. |
| `--hostname` | The host of Terraform Enterprise. Default is `app.terraform.io`. |
| `--token-env` | The environment variable with the API token. Default is `TFC_TOKEN`. |
| `--state-dir` | Download the state of each workspace into this directory, and write `migrate-state.sh`. |
| `--backend` | Move the state to an `s3`, `gcs`, or `azurerm` backend, not to Infrastructure as a Database. |
| `--backend-config` | A setting of the backend block, as `KEY=VALUE`. Repeatable. |
| `--rewrite-code` | Remove the `cloud` and `backend "remote"` blocks, or replace them with the `--backend` block. |
| `--save-snapshot` | Write the API data that the conversion reads to a file. |
| `--snapshot` | Convert from that file, with no API access. |
| `--output` | The configuration to write. Default is `.stategraph/config.yml`. |
| `--report` | Also write the report to a file. |
| `--dry-run` | Print the files, and write nothing. |
| `--force` | Overwrite existing files. |

Exit status `0` means no manual steps, `2` means that the report lists manual steps, and `1` is an error.

## Move the state

### Into Infrastructure as a Database

This is the default. Each Terraform Cloud workspace becomes a state in [Infrastructure as a Database](/docs/infrastructure-as-a-database), and the converted configuration runs it with the `stategraph` engine.

1. Export the connection to your Stategraph server, and the values of the sensitive variables that the report lists. The import evaluates the configuration, so it needs every variable:

```bash
export STATEGRAPH_API_BASE=https://stategraph.example.com
export STATEGRAPH_API_KEY=<api key>
export STATEGRAPH_TENANT_ID=<tenant id>
export TFC_NETWORK__DB_PASSWORD=<value>
```

2. Run the script that the conversion wrote:

```bash
sh ../tfc-state/migrate-state.sh
```

For each workspace, it runs the equivalent of this command in the workspace directory, with the var files of the workspace:

```bash
stategraph import tf --tenant "$STATEGRAPH_TENANT_ID" --name network --workspace default \
  --var-file=../.stategraph/tfc/vars/network/default.tfvars ../../tfc-state/network.tfstate
```

3. Commit the `stategraph.json` that each import writes. Several workspaces in one directory share the group in that file.

4. Check the states:

```bash
stategraph states list --tenant "$STATEGRAPH_TENANT_ID"
stategraph states summary --state <state-id>
```

5. Delete the state files.

For the import on its own, see [Import your Terraform state](/docs/get-started/quickstart/import-state). For the engine and the runner secrets, see [Use with Orchestration](/docs/infrastructure-as-a-database/orchestration).

### Into a bucket backend

To keep Terraform state files, pass `--backend` and the settings of the backend:

```bash
python3 tfc-to-stategraph.py --org acme --repo acme/infra --state-dir ../tfc-state \
  --backend s3 --backend-config bucket=acme-terraform-state \
  --backend-config key=terraform.tfstate --backend-config region=us-west-2 \
  --rewrite-code
```

`--rewrite-code` replaces each `cloud` block with the backend block, and the configuration uses the `terraform` engine. For each workspace, `migrate-state.sh` runs `terraform init`, selects the workspace, and runs `terraform state push`. Give the runner access to the bucket, for example with an [OIDC role](/docs/orchestration/security/cloud-credentials). Delete the state files after the push.

## Differences in behavior

- Each pull request plans the directories that it changes, and each plan comments on the pull request. Terraform Cloud ran speculative plans, and posted a commit status.
- A VCS workspace applies after the merge, as in Terraform Cloud. Comment `stategraph apply` on the merged pull request, or set `autoapply`. Remove `apply_after_merge` to apply before the merge.
- A CLI-driven workspace now plans on each pull request that changes its directory.
- A run trigger makes the dependent plan and apply in the same pull request, after its dependency applies. Terraform Cloud queued a new run after the apply.
- Dynamic provider credentials become `oidc` steps. The role or identity must now trust the GitHub OIDC issuer, not `app.terraform.io`.
- Orchestration reads `apply_requirements` and `destination_branches` from the default branch.

## Roll out

1. Open a pull request that adds `.stategraph/config.yml`, `.stategraph/tfc/`, each `stategraph.json`, the code without `cloud` blocks, and the [Orchestration workflow file](/docs/get-started/quickstart/cloud#add-the-workflow-file).
2. Check that each directory plans with no changes. A change means that a variable or the state differs from Terraform Cloud.
3. Merge it.
4. In Terraform Cloud, lock each workspace, so that nobody applies there, and disconnect its VCS repository.
5. When every directory has moved, delete the workspaces and the variable sets in Terraform Cloud.

## Next steps

- [Use with Orchestration](/docs/infrastructure-as-a-database/orchestration): the `stategraph` engine
- [Configuration](/docs/orchestration/configuration): the `.stategraph/config.yml` reference
- [Cloud credentials](/docs/orchestration/security/cloud-credentials): OIDC for AWS, Google Cloud, and Azure
- [Migrating from Atlantis](/docs/orchestration/migration/atlantis): move from Atlantis
