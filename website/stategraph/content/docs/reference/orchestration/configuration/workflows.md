---
title: workflows
description: The workflows key in .stategraph/config.yml sets the plan and apply steps, engine, environment, OIDC, gates, and scanners per directory.
order: 29
---


`workflows` sets the steps that Stategraph Orchestration runs to plan and apply a directory and workspace, in place of the default workflow. An entry can also set the engine, the GitHub environment, the runner, the lock policy, and the plan storage.

## Default Configuration

```yaml
workflows:
  - tag_query: ""
    plan:
      - type: init
      - type: plan
    apply:
      - type: init
      - type: apply
```

## Keys

`workflows` is a list. Orchestration uses the first entry whose `tag_query` matches the directory and workspace. Each entry has these keys:

| Key | Type | Description |
| --- | --- | --- |
| `tag_query` | string | A [tag query](/docs/reference/orchestration/configuration/tag-queries) that must match the tag set of a directory and workspace. Required. An empty string matches everything. |
| `plan` | list | The `plan` steps. Default is `init`, then `plan`. |
| `apply` | list | The `apply` steps. Default is `init`, then `apply`. |
| `engine` | [engine](/docs/reference/orchestration/configuration/engine) | The engine for this workflow, in place of the top-level one. |
| `environment` | string | The GitHub environment for the operation. Not set by default. |
| `runs_on` | object | The [runs-on](/docs/orchestration/workflows/advanced/runs-on) configuration. Default is `ubuntu-latest` on GitHub. On GitLab, set it to a list of runner tags. Orchestration passes it to the pipeline as the `RUNS_ON` input, which is empty by default. |
| `lock_policy` | string | When Orchestration locks the directory: `strict` (when it is merged or applied), `apply` (only when it is applied), `merge` (only when it is merged), or `none` (never). A value other than `strict` is less safe, but can be useful in the right situation. Default is the top-level [`lock_policy`](/docs/reference/orchestration/configuration/lock-policy), which defaults to `strict`. |
| `storage` | [storage](/docs/reference/orchestration/configuration/storage) | Plan storage for this workflow. Default is the top-level `storage`. |
| `terragrunt` | boolean | Legacy. `true` is equivalent to `engine: { name: terragrunt }`. Default is `false`. Use `engine`. |
| `cdktf` | boolean | Legacy. `true` is equivalent to `engine: { name: cdktf }`. Default is `false`. Use `engine`. |
| `terraform_version` | string | Legacy. Equivalent to `engine: { name: terraform, version: <value> }`. Use `engine`. |

## Workflow Steps

Steps run in order. Both the `plan` and the `apply` list accept each step type:

- `init`, `plan`, `apply`: run that command of the [engine](/docs/reference/orchestration/configuration/engine), for example `terraform plan`.
- `env`: sets environment variables.
- `run`: runs a custom command.
- `oidc`: gets cloud credentials through OIDC.
- `checkov`: scans the plan with Checkov.
- `conftest`: checks the plan against Conftest policies.
- `opa`: evaluates an OPA policy against the plan.
- `gates`: runs a command that creates [Gatekeeper](/docs/orchestration/governance/gatekeeper) gates.

!!! warning "Every step list needs its own step"
    If a workflow sets `plan` steps, at least one of them must be a `plan` step. If it sets `apply` steps, at least one must be an `apply` step. Orchestration rejects any other configuration with a repository configuration error.

    A `run` step that calls `terraform plan` or `terraform apply` does not count: the `plan` step reports the plan result that Orchestration tracks, and the `apply` step takes part in the apply handling of Orchestration.

    Without a `plan` or `apply` key, the workflow uses the default steps, which meet this rule. If you remove a default step, such as `init`, errors or unexpected behavior can occur.

### Init, plan, and apply steps

| Key | Type | Description |
| --- | --- | --- |
| `type` | string | `init`, `plan`, or `apply`. |
| `extra_args` | list | Extra command line arguments for the command. |
| `visible_on` | string | When the output shows in a pull request comment or the console: `always`, `failure`, or `success`. Default is `failure` for `init`, and `always` for `plan` and `apply`. |
| `log_output` | boolean | `false` keeps the output of the command out of the CI job log. The output still shows in a pull request comment or the console, as `visible_on` sets. Default is `true`. |

### Env

The `env` step sets environment variables for the steps after it, so put it before the steps that use them. It has two methods: a command, or a script with `method: source`.

#### Command

Sets the variable `name` to the output of `cmd`.

| Key | Type | Description |
| --- | --- | --- |
| `name` | string | The environment variable name. |
| `cmd` | list | The command that prints the value of the environment variable. |
| `trim_trailing_newlines` | boolean | Trim trailing newlines. Default is `true`. |
| `sensitive` | boolean | `true` masks the value in the output that Orchestration posts, and on GitHub Actions also in the job log. GitLab CI does not mask it in the job log. Default is `false`. |

#### Source Method

Runs `cmd` and keeps the environment variables that it exports. The script must export them, so test it on its own first.

| Key | Type | Description |
| --- | --- | --- |
| `method` | string | Must be `source`. |
| `cmd` | list | The command or script that exports environment variables. |
| `sensitive` | boolean | `true` masks the variables that the script changes in the output that Orchestration posts, and on GitHub Actions also in the job log. GitLab CI does not mask them in the job log. Default is `false`. |

### Run

The `run` step runs a custom command from the directory that Orchestration works on. The command must be available and executable on the runner: use absolute paths, or install what it needs. It can read the [runner environment variables](/docs/orchestration/configuration/environment-variables), such as `TERRATEAM_DIR` and `TERRATEAM_WORKSPACE`, so one workflow can serve many directories and workspaces.

Orchestration records the output of the command and masks secrets with `***`. When the command fails, the output shows in the pull request comment by default, so remove or mask sensitive data in it.

| Key | Type | Description |
| --- | --- | --- |
| `cmd` | list | The command to run. |
| `run_on` | string | When the step runs, from the state of the workflow: `success`, `failure`, or `always`. Default is `success`. |
| `env` | object | Environment variables for this command. Each key is a variable name, and each value is a string. |
| `ignore_errors` | boolean | `true` ignores a failure. Default is `false`, or `true` when `on_error` contains a gate. |
| `visible_on` | string | When the output shows in a pull request comment or the console: `always`, `failure`, or `success`. Default is `failure`. |
| `log_output` | boolean | `false` keeps the output of the command out of the CI job log. Orchestration still records it. Default is `true`. |
| `format` | string or object | How the output shows in pull request comments: `code` (the default, a fenced code block), `raw` (as it is), or `markdown` (as Markdown). The object form `{ type: code, lang: <language> }` gives a fenced code block with syntax highlighting for `<language>`. |
| `on_error` | list | Actions when the command fails. Each entry is an object with a `type`. The only type is `gate`, which creates a [Gatekeeper](/docs/orchestration/governance/gatekeeper) gate with the keys in [Gate](#gate). |

### Checkov

The `checkov` step runs Checkov on the JSON form of the plan, to find misconfigurations and security issues. The output goes into the results. The step fails when Checkov exits with an error.

| Key | Type | Description |
| --- | --- | --- |
| `type` | string | Must be `checkov`. |
| `extra_args` | list | Extra command line arguments for `checkov`. They replace the default `--quiet --compact`. |
| `gate` | object | A [gate](#gate) that asks for approval when Checkov fails. |
| `ignore_errors` | boolean | `true` ignores a failure. Default is `false`, or `true` when `gate` is set. |
| `run_on` | string | When the step runs, from the state of the workflow: `success`, `failure`, or `always`. Default is `success`. |

Checkov reads its configuration from environment variables. Set them with an `env` step before the `checkov` step. Common variables:

- `CKV_SKIP_CHECK`: comma-separated list of check IDs to skip.
- `CKV_CHECK`: comma-separated list of specific check IDs to run.
- `CKV_FRAMEWORK`: framework to scan (default: `terraform_plan`).

For all options, see the [Checkov documentation](https://www.checkov.io/2.Basics/CLI%20Command%20Reference.html).

### Conftest

The `conftest` step runs Conftest with Rego policies on the JSON form of the plan. The output goes into the results. The step fails when a policy is violated.

| Key | Type | Description |
| --- | --- | --- |
| `type` | string | Must be `conftest`. |
| `extra_args` | list | Extra command line arguments for `conftest`. |
| `gate` | object | A [gate](#gate) that asks for approval when Conftest fails. |
| `ignore_errors` | boolean | `true` ignores a failure. Default is `false`, or `true` when `gate` is set. |
| `run_on` | string | When the step runs, from the state of the workflow: `success`, `failure`, or `always`. Default is `success`. |

By default, Conftest reads policies from the `policy/` directory, relative to the Terraform configuration. To change Conftest, set these environment variables with an `env` step:

- `CONFTEST_POLICY`: path to the directory containing Rego policy files.
- `CONFTEST_NAMESPACE`: namespace to use for policy evaluation (default: `main`).
- `CONFTEST_OUTPUT`: output format (`json`, `table`, `tap`, `junit`, `github`).

For policies and other options, see the [Conftest documentation](https://www.conftest.dev/).

### OPA

The `opa` step runs `opa eval` on the JSON form of the plan. Pass the policy and the query in `extra_args`, for example `['-d', 'policy.rego', 'data.terraform.deny']`.

| Key | Type | Description |
| --- | --- | --- |
| `type` | string | Must be `opa`. |
| `extra_args` | list | Extra command line arguments for `opa eval`, usually the policy file (`-d`) and the query. |
| `fail_on` | string | `undefined` fails the step when the query result is undefined. `defined` fails the step when the query result is defined. Default is `undefined`. |
| `gate` | object | A [gate](#gate) that asks for approval when the step fails. |
| `ignore_errors` | boolean | `true` ignores a failure. Default is `false`, or `true` when `gate` is set. |
| `run_on` | string | When the step runs, from the state of the workflow: `success`, `failure`, or `always`. Default is `success`. |

### Gate

A `gate` asks for manual approval when a step fails, for example a security scan, a policy check, or a custom validation script. When a gated step fails, Orchestration records a gate instead of failing the plan, and blocks the apply until authorized users approve the gate. See [Gatekeeper](/docs/orchestration/governance/gatekeeper).

The `checkov`, `conftest`, and `opa` steps accept `gate`. The `run` step does not: use `on_error` with an entry of `type: gate` and the same keys.

| Key | Type | Description |
| --- | --- | --- |
| `token` | string | A unique identifier for this gate request. Gates without a token are approved by approving the pull request. |
| `name` | string | A name for the gate. |
| `all_of` | list | Users, teams, or roles that must all approve the gate. |
| `any_of` | list | Users, teams, or roles from which `any_of_count` approvals are required. |
| `any_of_count` | integer | The number of approvals required from the `any_of` list. Default is `0`, which requires no approval from `any_of`. Set it to `1` or more when you use `any_of`. |

To approve a gate with a token, an authorized user comments:

```text
stategraph gate approve <token>
```

### Gates

The `gates` step runs a command, and creates a [Gatekeeper](/docs/orchestration/governance/gatekeeper) gate for each entry of the `gates` list in the JSON that the command prints to standard output. The step never fails the workflow.

| Key | Type | Description |
| --- | --- | --- |
| `type` | string | Must be `gates`. |
| `cmd` | list | The command to run. Its standard output must be a JSON object of the form `{"gates": [ ... ]}`. Each gate accepts `token`, `name`, `all_of`, `any_of`, `any_of_count`, and `add_reviewers` (boolean, default `true`: request a review from the `user:` and `team:` entries). |
| `run_on` | string | When the step runs, from the state of the workflow: `success`, `failure`, or `always`. Default is `success`. |

### OIDC

The `oidc` step gets short-lived credentials from AWS, Azure, or GCP through OpenID Connect. For AWS, it sets `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`, and `AWS_REGION`. Each string value except `type` and `provider` can come from a GitHub secret or an environment variable, as `${ENV_VAR}`.

| Key | Type | Provider | Description |
| --- | --- | --- | --- |
| `type` | string | | Must be `oidc`. |
| `provider` | string | | `aws`, `azure`, or `gcp`. Required for `azure` and `gcp`. Default is `aws`. |
| `role_arn` | string | aws | The ARN of the IAM role to use. Required. |
| `assume_role_arn` | string | aws | The ARN of an IAM role to assume into, after `role_arn`. Default is the value of `role_arn`. |
| `assume_role_enabled` | boolean | aws | `false` skips the assume into `assume_role_arn`. Default is `true`. |
| `audience` | string | aws | The AWS audience name. Default is `sts.amazonaws.com`. |
| `region` | string | aws | The AWS region, set as `AWS_REGION`. Default is `us-east-1`. |
| `session_name` | string | aws | The AWS session name. Default is `terrateam`. |
| `duration` | integer | aws | The AWS session duration in seconds. Default is `3600`. |
| `service_account` | string | gcp | The email address or unique identifier of the Google Cloud service account to generate credentials for. Required. |
| `workload_identity_provider` | string | gcp | The full identifier of the Workload Identity Provider, with the project number, pool name, and provider name. Required. |
| `access_token_lifetime` | integer | gcp | The lifetime of the access token, in seconds. Default is `3600`. |
| `audience` | string | gcp | The GCP audience name. Default is `https://iam.googleapis.com/` followed by `workload_identity_provider`. |
| `access_token_subject` | string | gcp | The email address of a user to impersonate for [Domain-Wide Delegation](https://developers.google.com/workspace/guides/create-credentials). |
| `client_id` | string | azure | The App Registration client ID. Required. |
| `tenant_id` | string | azure | The Azure AD (Entra ID) tenant ID. Required. |
| `subscription_id` | string | azure | The default Azure subscription ID. |
| `audience` | string | azure | The Azure audience name. Default is `api://AzureADTokenExchange`. |

## Examples

### Setting an environment variable with a command

```yaml
workflows:
  - tag_query: "dir:prod"
    plan:
      - type: env
        name: MY_CUSTOM_VAR
        cmd: ['echo', 'Hello, World!']
      - type: run
        cmd: ['echo', 'The value of MY_CUSTOM_VAR is: $MY_CUSTOM_VAR']
      - type: init
      - type: plan
```

### Setting environment variables with the source method

```yaml
workflows:
  - tag_query: "dir:prod"
    plan:
      - type: env
        method: source
        cmd: ['$TERRATEAM_ROOT/scripts/environment']
      - type: init
      - type: plan
    apply:
      - type: env
        method: source
        cmd: ['$TERRATEAM_ROOT/scripts/environment']
      - type: init
      - type: apply
```

For directories that match `dir:prod`, the `environment` script exports environment variables before the plan, and again before the apply. Then `terraform init` runs, and `terraform plan` or `terraform apply` runs with these variables.

### Custom plan and apply steps

```yaml
workflows:
  - tag_query: "dir:production"
    plan:
      - type: init
      - type: run
        cmd: ['echo', 'Running custom plan step']
      - type: plan
        extra_args: ['-input=false']
    apply:
      - type: init
      - type: apply
        extra_args: ['-auto-approve']
      - type: run
        cmd: ['./post_apply_script.sh']
```

For directories that match `dir:production`, this workflow runs `terraform init` for both plan and apply. It prints a message before `terraform plan`, plans with `-input=false`, applies with `-auto-approve`, and runs a custom script after the apply.

### Blocking the apply path

Some teams plan with Orchestration but apply somewhere else. To enforce this, add a `run` step to `apply` that exits non-zero, so that the apply fails before Terraform runs. The `apply` steps must still contain an `apply` step.

```yaml
workflows:
  - tag_query: ""
    plan:
      - type: init
      - type: plan
    apply:
      - type: run
        cmd: ['sh', '-c', 'echo "Applies for this repository are performed outside of Stategraph."; exit 1']
      # Required: the apply list must contain an apply step. The run step
      # above always fails first, so this step never runs.
      - type: apply
```

This workflow plans normally. On apply, the `run` step prints a message and exits non-zero. A failed step [aborts the workflow](/docs/orchestration/workflows/advanced/custom-commands), so the `apply` step never starts and `terraform apply` never runs. The pull request shows the message, because the output of a `run` step is visible on failure by default.

!!! warning "Order matters"
    The `apply` step must come after the `run` step that fails. If it comes first, `terraform apply` runs before the `run` step can block it.

### AWS OIDC authentication

```yaml
workflows:
  - tag_query: "dir:aws"
    plan:
      - type: oidc
        provider: aws
        role_arn: ${AWS_ROLE_ARN}
      - type: init
      - type: plan
    apply:
      - type: oidc
        provider: aws
        role_arn: ${AWS_ROLE_ARN}
      - type: init
      - type: apply
```

For directories that match `dir:aws`, the plan and the apply first get AWS credentials through OIDC, with the role ARN from the `AWS_ROLE_ARN` environment variable. Then `terraform init` runs, followed by `terraform plan` or `terraform apply`.

### GCP OIDC authentication

```yaml
workflows:
  - tag_query: "dir:gcp"
    plan:
      - type: oidc
        provider: gcp
        service_account: ${GCP_SERVICE_ACCOUNT}
        workload_identity_provider: ${GCP_WORKLOAD_IDENTITY_PROVIDER}
      - type: init
      - type: plan
    apply:
      - type: oidc
        provider: gcp
        service_account: ${GCP_SERVICE_ACCOUNT}
        workload_identity_provider: ${GCP_WORKLOAD_IDENTITY_PROVIDER}
      - type: init
      - type: apply
```

For directories that match `dir:gcp`, the plan and the apply first get GCP credentials through OIDC, with the service account and the workload identity provider from the `GCP_SERVICE_ACCOUNT` and `GCP_WORKLOAD_IDENTITY_PROVIDER` environment variables. Then `terraform init` runs, followed by `terraform plan` or `terraform apply`.

### Security scanning with Checkov

```yaml
workflows:
  - tag_query: ""
    plan:
      - type: init
      - type: plan
      - type: checkov
```

Checkov scans the plan for misconfigurations and security issues.

### Policy validation with Conftest

```yaml
workflows:
  - tag_query: ""
    plan:
      - type: init
      - type: plan
      - type: conftest
```

Conftest checks the plan against the policies of your organization.

### Combined security and policy checks

```yaml
workflows:
  - tag_query: "env:production"
    plan:
      - type: env
        name: CKV_SKIP_CHECK
        cmd: ['echo', 'CKV_AWS_20,CKV_AWS_23']
      - type: env
        name: CONFTEST_POLICY
        cmd: ['echo', '$TERRATEAM_ROOT/policies/production/']
      - type: init
      - type: plan
      - type: checkov
      - type: conftest
```

For production, this workflow makes Checkov skip two checks, points Conftest at the production policies, and runs both after the plan.

### Using gates for manual approval

```yaml
workflows:
  - tag_query: "env:production"
    plan:
      - type: init
      - type: plan
      - type: checkov
        gate:
          token: "checkov-override"
          any_of: ["team:security", "team:platform"]
          any_of_count: 1
      - type: conftest
        gate:
          token: "policy-override"
          all_of: ["team:compliance"]
          any_of: ["user:cto", "user:security-lead"]
          any_of_count: 1
```

A member of the security or platform team can approve a Checkov failure. A Conftest policy violation needs the approval of the compliance team, and of the CTO or the security lead.

### Gating custom validation scripts

```yaml
workflows:
  - tag_query: ""
    plan:
      - type: init
      - type: plan
      - type: run
        cmd: ['./scripts/cost-check.sh']
        on_error:
          - type: gate
            token: "cost-approval"
            any_of: ["team:finance", "user:budget-owner"]
            any_of_count: 1
```

A custom script checks the cost. When the cost exceeds the thresholds, a member of the finance team or the budget owner can approve.

### Specifying a GitHub environment

```yaml
workflows:
  - tag_query: production
    environment: production
```

The run uses the `production` GitHub environment, so it can read the secrets and variables of that environment.

## Related

- [hooks](/docs/reference/orchestration/configuration/hooks)
- [engine](/docs/reference/orchestration/configuration/engine)
- [Custom commands](/docs/orchestration/workflows/advanced/custom-commands)
- [Runs-on](/docs/orchestration/workflows/advanced/runs-on)
- [GitHub environments](/docs/orchestration/security/github-environments)
- [Gatekeeper](/docs/orchestration/governance/gatekeeper)
- [Security scanning](/docs/infrastructure-as-a-database/security)
- [OPA](/docs/orchestration/external-tools/opa)
- [Runner environment variables](/docs/orchestration/configuration/environment-variables)
