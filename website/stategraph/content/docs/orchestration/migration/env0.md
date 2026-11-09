---
title: Migrating from env0
description: "Move env0 environments to Stategraph with a script: templates, variables, and custom flows to .stategraph/config.yml, env0-hosted state to Infrastructure as a Database."
order: 5
---

To move from env0 to Stategraph, run a script that reads your environments through the env0 API. It writes `.stategraph/config.yml` and the variables of each environment, downloads the env0-hosted state, and imports it into Infrastructure as a Database or pushes it to a bucket backend. Resolve the items that the script reports, and roll out on a pull request.

Plans and applies move from env0 runners to your GitHub Actions or GitLab CI runners. Your Terraform and OpenTofu code stays as it is.

## How env0 maps to Stategraph

| env0 | Stategraph |
| --- | --- |
| An environment | A `dirs` entry and its workspace, tagged with the environment name and its tags |
| Template path, and the Terragrunt working directory | The `dirs` key |
| Several environments of one template path | Workspaces of one directory, named after their workspace names |
| Trigger: any change, template directory, or file filter pattern | `when_modified.file_patterns` |
| Plan on pull request off | `autoplan: false` |
| Continuous deployment without approval | `autoapply` |
| Deploy after a push to the branch | `apply_requirements` with `apply_after_merge` |
| Terraform, OpenTofu, or Terragrunt version | `engine` |
| Terraform variables of every scope | A var file per environment in `.stategraph/env0` |
| Environment variables of every scope | An `env` step that sources a file per environment |
| Sensitive variables | GitHub secrets |
| `env0.yml` custom flows, and project custom flows | `run` steps, in the same order |
| Workflow triggers, workflow `needs`, environment outputs as inputs | `depends_on`, as [layered runs](/docs/orchestration/workflows/advanced/layered-runs) |
| AWS, Azure, and Google Cloud OIDC credentials | `oidc` steps |
| Approval policies | `conftest` steps with [gates](/docs/orchestration/governance/gatekeeper) |
| Drift detection | `drift.schedules` |
| Revision | `destination_branches` |
| env0 remote backend, or the state that env0 saves | A state in [Infrastructure as a Database](/docs/infrastructure-as-a-database), or a bucket backend |

## Before you begin

- Connect the repository to Orchestration. See [Stategraph Cloud](/docs/get-started/quickstart/cloud) or [Self-hosted](/docs/get-started/quickstart/self-hosted).
- Install Python 3.8 or later and PyYAML, and the [Stategraph CLI](/docs/cli).
- Create an API key in env0 under **Organization settings → API keys**, of type **Admin**, not read-only. It reads the environments and the state, and `--state-via-task` runs a task.
- For Infrastructure as a Database, export `STATEGRAPH_API_BASE`, `STATEGRAPH_API_KEY`, and `STATEGRAPH_TENANT_ID`. See [Use with Orchestration](/docs/infrastructure-as-a-database/orchestration).

## Convert the environments

Run the script from the root of your repository. `--repo` selects the environments whose template uses the repository. Add other environments with `--environment`:

```bash
curl -sSLO https://stategraph.com/assets/migrate/env0-to-stategraph.py
pip install pyyaml
export ENV0_API_KEY=<key id>
export ENV0_API_SECRET=<key secret>
python3 env0-to-stategraph.py --repo acme/infra \
  --state-dir ../env0-state --state-via-task \
  --report env0-migration-report.md
```

The script writes:

- `.stategraph/config.yml`
- `.stategraph/env0/<dir>/<workspace>.tfvars`: the Terraform variables of the environment, after the precedence of env0: organization, template, project and its parent projects, then the environment. The plan reads it as a var file.
- `.stategraph/env0/<dir>/<workspace>.env`: the environment variables. At run time it also writes the sensitive Terraform variables from GitHub secrets to a temporary var file.
- `.stategraph/scripts/`: the steps of the `env0.yml` custom flows. Each step runs in the directory of its `env0.yml`, as in env0.
- `../env0-state/<environment>.tfstate` and `../env0-state/migrate-state.sh`: the current state of each environment with env0-hosted state, and the commands that import it. `--state-dir` must be outside the repository, because state files hold secrets.

A directory with one environment gets the workspace `default`, unless the code reads `terraform.workspace`. Several environments of one template path become workspaces of that directory, named after their env0 workspace names. An environment with its own backend keeps its env0 workspace name, because env0 selected that workspace before each plan.

Output:

```text
# env0 to Stategraph Orchestration conversion report

Converter: env0-to-stategraph.py 1.0.0
Source: env0 organization acme
Output: .stategraph/config.yml
...

## Manual steps (3)

- `secrets`: env0 does not reveal sensitive values. Create these GitHub secrets with the values: `ENV0_NETWORK__DB_PASSWORD`. For example: `gh secret set ENV0_NETWORK__DB_PASSWORD`.
- `runner secrets`: Set the GitHub secrets `STATEGRAPH_API_BASE`, `STATEGRAPH_API_KEY`, and `STATEGRAPH_TENANT_ID`, so that the runner can reach Infrastructure as a Database.
- `state`: Lock each environment in env0, run `sh ../env0-state/migrate-state.sh` to move the state, then delete the state files.
...
```

Manual steps need your action: resolve each one before you roll out. Notes describe a difference in behavior.

| Flag | Description |
| --- | --- |
| `--repo` | Convert the environments whose template repository is `OWNER/NAME`. |
| `--environment` | Also convert this environment, by ID or name. Repeatable. |
| `--organization` | The organization ID. Default is the only organization of the API key. |
| `--key-id-env`, `--key-secret-env` | The environment variables with the API key. Default is `ENV0_API_KEY` and `ENV0_API_SECRET`. |
| `--endpoint`, `--backend-host` | The env0 API and remote backend hosts, for a self-hosted env0. |
| `--state-dir` | Download the env0-hosted state of each environment into this directory, and write `migrate-state.sh`. |
| `--state-via-task` | Read the state that env0 saves for environments without the env0 remote backend with an env0 task. |
| `--backend` | Move the state to an `s3`, `gcs`, or `azurerm` backend, not to Infrastructure as a Database. |
| `--backend-config` | A setting of the backend block, as `KEY=VALUE`. Repeatable. |
| `--rewrite-code` | With `--backend`, write a `backend.tf` in the directory of each environment with env0-hosted state. |
| `--save-snapshot` | Write the API data that the conversion reads to a file. |
| `--snapshot` | Convert from that file, with no API access. |
| `--output` | The configuration to write. Default is `.stategraph/config.yml`. |
| `--report` | Also write the report to a file. |
| `--dry-run` | Print the files, and write nothing. |
| `--force` | Overwrite existing files. |

Exit status `0` means no manual steps, `2` means that the report lists manual steps, and `1` is an error.

## Move the state

An environment with a backend in its code, a Terragrunt environment, and a Pulumi environment keep their state where it is, and the converted configuration runs them with their engine. The steps below move the state that env0 holds.

### Download the state

For an environment on the env0 remote backend, the script reads the current state from `backend.api.env0.com`, as `terraform state pull` does.

For an environment without the env0 remote backend, env0 keeps the state in the working directory that it saves between deployments, and the API does not serve it. Add `--state-via-task`. The script then runs a task on the environment that prints the state, compressed and base64-encoded, to the deployment log, and reads it from there. The state stays in that deployment log in env0.

### Into Infrastructure as a Database

This is the default. Each environment becomes a state in [Infrastructure as a Database](/docs/infrastructure-as-a-database), and the converted configuration runs it with the `stategraph` engine.

1. Lock each environment in env0, so that nobody deploys there.

2. Export the connection to your Stategraph server, and the values of the sensitive variables that the report lists. The import evaluates the configuration, so it needs every variable:

```bash
export STATEGRAPH_API_BASE=https://stategraph.example.com
export STATEGRAPH_API_KEY=<api key>
export STATEGRAPH_TENANT_ID=<tenant id>
export ENV0_NETWORK__DB_PASSWORD=<value>
```

3. Run the script that the conversion wrote:

```bash
sh ../env0-state/migrate-state.sh
```

For each environment, it sources the environment file in the environment directory, and runs the equivalent of this command:

```bash
stategraph import tf --tenant "$STATEGRAPH_TENANT_ID" --name network --workspace default \
  --var-file=../../.stategraph/env0/aws/network/default.tfvars ../../../env0-state/network.tfstate
```

4. Commit the `stategraph.json` that each import writes. Several environments in one directory share the group in that file.

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
python3 env0-to-stategraph.py --repo acme/infra --state-dir ../env0-state \
  --backend s3 --backend-config bucket=acme-terraform-state \
  --backend-config region=us-west-2 --rewrite-code
```

`--rewrite-code` writes a `backend.tf` for each environment with env0-hosted state, with the key `env0/<environment>/terraform.tfstate`, or the prefix `env0/<environment>` for `gcs`. Pass `--backend-config key=...` to set it yourself. The configuration uses the `terraform` or `tofu` engine. For each environment, `migrate-state.sh` runs `init`, selects the workspace, and runs `state push` with `terraform` or `tofu`. Give the runner access to the bucket, for example with an [OIDC role](/docs/orchestration/security/cloud-credentials). Delete the state files after the push.

## Differences in behavior

- Each pull request plans the directories that it changes, and each plan comments on the pull request. env0 ran a PR plan, and posted a commit status.
- Changes apply after the merge, as env0 deployed after a push to the branch. Comment `stategraph apply` on the merged pull request, or set `autoapply`, which the script sets for environments with continuous deployment and no approval. Remove `apply_after_merge` to apply before the merge.
- An environment that waited for an approval of its plan now waits for `stategraph apply`.
- The converted var file is passed with `--var-file`, so its values win over `*.auto.tfvars` files in the repository. In env0, a file that sorts after `env0.auto.tfvars.json` won.
- Each custom flow step runs in its own process. A variable that a step writes to `$ENV0_ENV` does not reach the next steps: set it in the environment file instead. Variables such as `ENV0_REVIEWER_NAME` and `ENV0_PR_NUMBER` are not set. The script sets the ones that do not change between deployments, such as `ENV0_ENVIRONMENT_NAME`, when a step reads them.
- A workflow trigger makes the downstream environment plan and apply in the same pull request, after its upstream applies. An environment output used as a variable has no equivalent: read the value with a data source.
- OIDC credentials become `oidc` steps. env0 does not reveal the role or the identity, so set it as a GitHub variable, and make it trust the GitHub OIDC issuer, not env0.
- Orchestration has no destroy or task deployments, and no TTL. The `destroy` and `task` sections of `env0.yml` are not converted.
- Orchestration reads `apply_requirements` and `destination_branches` from the default branch.

## Roll out

1. Open a pull request that adds `.stategraph/config.yml`, `.stategraph/env0/`, `.stategraph/scripts/`, each `stategraph.json`, and the [Orchestration workflow file](/docs/get-started/quickstart/cloud#add-the-workflow-file).
2. Check that each directory plans with no changes. A change means that a variable or the state differs from env0.
3. Merge it.
4. In env0, turn off continuous deployment and pull request plans of each environment, then mark it inactive. Marking an environment inactive keeps its cloud resources.
5. When every environment has moved, delete the templates, and the `env0.yml` files.

## Next steps

- [Use with Orchestration](/docs/infrastructure-as-a-database/orchestration): the `stategraph` engine
- [Configuration](/docs/orchestration/configuration): the `.stategraph/config.yml` reference
- [Cloud credentials](/docs/orchestration/security/cloud-credentials): OIDC for AWS, Google Cloud, and Azure
- [Migrating from Spacelift](/docs/orchestration/migration/spacelift): move from Spacelift
