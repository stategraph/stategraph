---
title: Configuration
description: Configure Stategraph Orchestration with the .stategraph/config.yml file: its main sections, and a link to each configuration reference page.
order: 1
---


The `.stategraph/config.yml` file at the root of your repository configures Stategraph Orchestration: who can plan and apply, what an apply requires, which directories run, and which steps they run.

!!! note "Do you need a config file?"
    Without a config file, Orchestration uses defaults. Add one only when you need custom workflows, OIDC, policies, or other advanced settings.

## Basic structure

The file is YAML. The `version` key names the file format. Its only value is `"1"`, which is also the default, so you can omit it. Quote the value: an unquoted `1` is a YAML integer, and the key requires a string.

```yaml
version: "1"
access_control:
  policies: []
apply_requirements:
  checks: []
dirs: {}
hooks:
  all:
    pre: []
    post: []
workflows: []
```

## Access control

`access_control` policies set who can do each operation, such as plan and apply. You can give access to users, teams, or repository collaborator roles.

```yaml
access_control:
  policies:
    - tag_query: ''
      plan: ['*']
      apply: ['team:sre']
```

The empty tag query matches all directories and workspaces. Anyone can plan. Only members of the `sre` team can apply.

On GitLab:

- A `team:` entry names a GitLab group by its full path, and matches the direct members of the group.
- A `role:` entry matches the access level of the user in the GitLab project.

!!! note "Enterprise"
    Access control is on by default in Enterprise. In the Open Source edition it is always off, and Orchestration rejects `access_control.enabled: true`. See [Editions](/docs/get-started/editions).

For all options, see [access_control](/docs/reference/orchestration/configuration/access-control).

## Apply requirements

`apply_requirements` sets the conditions that must be true before an apply can run on an unmerged pull request. Changes then get review and checks before they reach your infrastructure.

```yaml
apply_requirements:
  create_pending_apply_check: true
  checks:
    - tag_query: ""
      approved:
        enabled: true
        any_of: []
        any_of_count: 2
        all_of: []
      merge_conflicts:
        enabled: true
      status_checks:
        enabled: true
        ignore_matching:
          - "ci/.*"
```

Before an apply can run, this configuration requires at least two approvals, no merge conflicts, and passing status checks. It ignores each check whose name matches `ci/.*`.

With `create_pending_apply_check` enabled, Orchestration creates a `stategraph apply` commit check:

- On GitHub, with branch protection rules, the pull request cannot merge until all applies are complete.
- On GitLab, the check is a commit status on the merge request pipeline for the commit, when the project runs merge request pipelines. A project that requires a successful pipeline before merge then holds the merge request until all applies are complete.

For details, see [apply_requirements](/docs/reference/orchestration/configuration/apply-requirements).

## Dirs

`dirs` assigns [tags](/docs/orchestration/workflows/advanced/tag-system), workspaces, and [when_modified](/docs/reference/orchestration/configuration/when-modified) rules to directories in your repository.

```yaml
dirs:
  ec2:
    tags: [aws, ec2]
    workspaces:
      production:
        tags: [production]
    when_modified:
      file_patterns: ["${DIR}/*.tf", "${DIR}/*.tfvars", "iam/*.tf", "iam/*.tfvars"]
  iam:
    tags: [aws, iam]
```

This configuration:

1. Assigns the directory-level tags `aws` and `ec2` to the `ec2` directory.
2. Assigns the directory-level tags `aws` and `iam` to the `iam` directory.
3. Creates a `production` workspace for the `ec2` directory with the tag `production`.
4. Lists the files that trigger operations for the `ec2` directory when they change.

!!! note "Directory tags and workspace tags"
    Directory tags (`tags` at the directory level) apply to all operations in that directory, in all workspaces. Workspace tags (`tags` under a workspace) apply only to operations on that workspace. Tag queries such as `tag_query: "aws"` match both kinds.

The `dirs` keys accept glob patterns, so one entry can configure many directories with the same shape. `${DIR}` expands to the current directory, relative to the repository root.

For details, see [dirs](/docs/reference/orchestration/configuration/dirs).

## Hooks

`hooks` run custom commands or set environment variables before (pre-hooks) or after (post-hooks) an operation, in three groups:

- `all` runs for plan and apply operations.
- `plan` runs only for plan operations.
- `apply` runs only for apply operations.

```yaml
hooks:
  all:
    pre:
      - type: run
        cmd: ['echo', 'Running pre-hook for all operations']
  plan:
    post:
      - type: run
        cmd: ['echo', 'Running post-hook for plan operations']
```

For details, see [hooks](/docs/reference/orchestration/configuration/hooks).

## Workflows

`workflows` set the steps of plan and apply operations, to replace or extend the default behavior. This workflow shows the default steps:

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

1. `init` runs `terraform init` to prepare the directory.
2. `plan` runs `terraform plan` to make the execution plan.
3. `apply` applies the changes to your infrastructure.

A workflow can also add arguments and error handling:

```yaml
workflows:
  - tag_query: "production"
    plan:
      - type: init
      - type: plan
        extra_args: ["-var-file=production.tfvars"]
    apply:
      - type: init
      - type: apply
      - type: run
        cmd: ['echo', 'Error running apply']
        run_on: failure
```

This workflow applies to all directories with the `production` tag. It passes a production variable file to the plan, and runs a custom command only when the apply fails.

For details, see [workflows](/docs/reference/orchestration/configuration/workflows).

## Reference pages

Each key has its own page in the [configuration reference](/docs/reference/orchestration/configuration):

- [access_control](/docs/reference/orchestration/configuration/access-control): who can plan, apply, and unlock.
- [apply_requirements](/docs/reference/orchestration/configuration/apply-requirements): approvals, merge conflicts, and status checks required before apply.
- [automerge](/docs/reference/orchestration/configuration/automerge): merge the pull request after a successful apply.
- [batch_runs](/docs/reference/orchestration/configuration/batch-runs): split a large operation across several CI jobs.
- [config_builder](/docs/reference/orchestration/configuration/config-builder): generate configuration with a script at run time.
- [cost_estimation](/docs/reference/orchestration/configuration/cost-estimation): turn on cost estimates in pull request comments.
- [default_branch_overrides](/docs/reference/orchestration/configuration/default-branch-overrides): which settings are always read from the default branch.
- [definitions](/docs/reference/orchestration/configuration/definitions): reusable templates with YAML anchors.
- [destination_branches](/docs/reference/orchestration/configuration/destination-branches): which branches a pull request may target to trigger operations.
- [dirs](/docs/reference/orchestration/configuration/dirs): per-directory tags, workspaces, and trigger rules.
- [drift](/docs/reference/orchestration/configuration/drift): drift detection schedules and reconciliation.
- [enabled](/docs/reference/orchestration/configuration/enabled): turn Orchestration on or off for a repository.
- [engine](/docs/reference/orchestration/configuration/engine): the IaC tool and its version. Orchestration runs Terraform, OpenTofu, the `stategraph` CLI with Infrastructure as a Database, Terragrunt, Pulumi, CDKTF, or a custom command.
- [hooks](/docs/reference/orchestration/configuration/hooks): commands before and after operations.
- [ignore_patterns](/docs/reference/orchestration/configuration/ignore-patterns): directories that never run on their own.
- [indexer](/docs/reference/orchestration/configuration/indexer): automatic module dependency discovery.
- [lock_policy](/docs/reference/orchestration/configuration/lock-policy): when a directory acquires a lock.
- [notifications](/docs/reference/orchestration/configuration/notifications): which comments and checks Orchestration posts.
- [parallel_runs](/docs/reference/orchestration/configuration/parallel-runs): how many directories run at once.
- [stacks](/docs/reference/orchestration/configuration/stacks): group workspaces with dependencies and shared variables.
- [storage](/docs/reference/orchestration/configuration/storage): where plan files are stored.
- [tag_queries](/docs/reference/orchestration/configuration/tag-queries): the query language that selects directories and workspaces.
- [tags](/docs/reference/orchestration/configuration/tags): custom tags based on dynamic criteria such as the destination branch.
- [tree_builder](/docs/reference/orchestration/configuration/tree-builder): a script that defines which files exist and which have changed.
- [version](/docs/reference/orchestration/configuration/version): the configuration file format version.
- [when_modified](/docs/reference/orchestration/configuration/when-modified): file patterns and autoplan (which changes trigger a plan), and autoapply (apply after merge).
- [work_manifests](/docs/reference/orchestration/configuration/work-manifests): how long a dispatched run has to call home before Orchestration aborts it as stale.
- [workflows](/docs/reference/orchestration/configuration/workflows): custom plan and apply steps.

## Basic example

A complete file with the sections above:

```yaml
access_control:
  policies:
    - tag_query: ''
      plan: ['*']
      apply: ['team:infra', 'team:platform']

apply_requirements:
  create_pending_apply_check: true
  checks:
    - tag_query: ""
      approved:
        enabled: true
        any_of_count: 1

dirs:
  staging:
    tags: [aws, staging]
  production:
    tags: [aws, production, critical]
    workspaces:
      default:
        tags: [default]

hooks:
  all:
    pre:
      - type: run
        cmd: ['echo', 'Starting Terraform operation']

workflows:
  - tag_query: "staging"
    plan:
      - type: init
      - type: plan
        extra_args: ["-var-file=staging.tfvars"]

  - tag_query: "production"
    plan:
      - type: init
      - type: plan
        extra_args: ["-var-file=production.tfvars"]
```

This configuration:

1. Lets anyone plan, but only members of the `infra` or `platform` teams apply.
2. Requires at least one approval before an apply.
3. Tags the staging and production directories.
4. Runs a pre-hook before every operation.
5. Passes the matching variable file to the staging and production plans.

Start with a file like this, and add sections when you need them.

## Next Steps

- [Modules](/docs/orchestration/configuration/modules): trigger dependent directories when a module changes.
- [Secrets and variables](/docs/orchestration/configuration/variables): pass secrets and `.tfvars` files to Terraform.
- [Pull request workflow](/docs/orchestration/workflows): what happens from open to merge.
- [Configuration reference](/docs/reference/orchestration/configuration): every key, type, and default.
