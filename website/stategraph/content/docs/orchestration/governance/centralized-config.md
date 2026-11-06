---
title: Centralized Configuration
description: Manage Stategraph Orchestration configuration defaults, overrides, and forced configurations for every repository from one central repository.
order: 4
---


!!! note "Enterprise Edition"
    Centralized configuration is an Enterprise feature, in Stategraph Cloud and in self-hosted Enterprise deployments. The Open Source edition reads only the local `.stategraph/config.yml` of each repository. See [Editions](/docs/get-started/editions).

Centralized configuration gives Stategraph Orchestration defaults, overrides, and full repository configurations for all repositories of an organization from one central repository. You write shared configuration one time, not in each repository, and you can enforce organization-wide policy. Each file in the central repository has the same structure as a repository configuration.

The central repository is in the same organization as the repositories that it configures. On GitHub, that is the organization that owns the repository. On GitLab, it is the top-level group of the project, and the access token of the GitLab connection must be able to read that project.

The central repository is named `stategraph`. Orchestration uses it when its default branch has at least one of the files below. An empty file counts.

These files make up the repository configuration. Each path also works with the `.yaml` extension. When both exist, the `.yml` file takes precedence.

| Name | Repository | Branch | Path |
|--- |--- |--- |--- |
| `global_defaults` | `stategraph` | default branch | `config/defaults.yml` |
| `global_overrides` | `stategraph` | default branch | `config/overrides.yml` |
| `repo_defaults` | `stategraph` | default branch | `config/$repository_name/defaults.yml` |
| `repo_overrides` | `stategraph` | default branch | `config/$repository_name/overrides.yml` |
| `repo_forced_config` | `stategraph` | default branch | `config/$repository_name/config.yml` |
| `repo_default_config` | `$repository` | default branch | `.stategraph/config.yml` |
| `repo_config` | `$repository` | feature branch | `.stategraph/config.yml` |

## How it works

Orchestration fetches the files in the table and merges them in order, each file over the files before it. If `repo_forced_config` exists, Orchestration merges it directly with `global_defaults`. If not, it builds two configurations:

- The default branch configuration: `global_defaults`, then `repo_defaults`, then `repo_default_config`, then `global_overrides`, then `repo_overrides`.
- The feature branch configuration: `global_defaults`, then `repo_defaults`, then `repo_config`, then `global_overrides`, then `repo_overrides`.

Then the feature branch configuration takes the keys in `default_branch_overrides` from the default branch configuration: by default, `access_control`, `apply_requirements`, and `destination_branches`.

## Use cases

### Disable Orchestration by default

To let teams migrate at their own pace, you can install the Stategraph GitHub App for the whole organization at one time. Orchestration then acts on changes in every repository. To disable it by default, put this in `global_defaults`:

```yaml
enabled: false
```

When a team moves over, it enables Orchestration with `enabled: true` in its repository configuration.

### Enforce a strict set of workflows

To stop repositories from defining their own `workflows` section, put this in `global_overrides`:

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

If a repository needs its own workflows, define them in the `repo_overrides` of that repository.

### Restrict apply operations to specific teams

To let only the SRE team apply, while everyone can plan, put this in `global_overrides`:

```yaml
access_control:
  enabled: true
  policies:
    - tag_query: ""
      plan: ['*']
      apply: ['team:sre']
```

### Require super approval for production changes

Changes to production need super approval from the SRE team, and developers manage the other environments. Put this in `global_overrides`:

```yaml
access_control:
  enabled: true
  policies:
    - tag_query: "dir:production"
      apply_with_superapproval: ['*']
      superapproval: ['team:sre']
    - tag_query: ""
      plan: ['*']
      apply: ['team:developers']
```

### Require approvals and status checks

Before an apply, each change in your organization must have an approval from at least one SRE team member and pass all status checks. Put this in `global_overrides`:

```yaml
apply_requirements:
  checks:
    - tag_query: ""
      approved:
        enabled: true
        any_of: ["team:sre"]
        any_of_count: 1
      status_checks:
        enabled: true
```

## Inspecting the effective configuration

To see how the configuration was built, and which files it came from, comment [`stategraph repo-config`](/docs/reference/orchestration/commands/repo-config) on a pull request.

## Next steps

- [Feature Branch Configuration Overrides](/docs/orchestration/governance/config-overrides) for which keys always come from the default branch
- [Role-Based Access Control](/docs/orchestration/governance/rbac) for the `access_control` policies used above
- [Configuration](/docs/orchestration/configuration) for the structure of `.stategraph/config.yml`
