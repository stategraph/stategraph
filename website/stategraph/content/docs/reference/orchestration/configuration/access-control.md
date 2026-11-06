---
title: access_control
description: Reference for the access_control key in .stategraph/config.yml. Define who can plan, apply, unlock, and override apply requirements.
order: 1
---


`access_control` sets who can plan, apply, unlock, and override apply requirements in Stategraph Orchestration. Rules match users, teams (GitHub teams or GitLab groups), and repository roles.

!!! note "Enterprise"
    Access control is an Enterprise feature, in [Stategraph Cloud](https://app.stategraph.cloud) and self-hosted Enterprise. On the Open Source edition, access control is always off, and Orchestration rejects a configuration with `enabled: true`. See [Editions](/docs/get-started/editions).

## Default Configuration

```yaml
access_control:
  apply_require_all_dirspace_access: true
  ci_config_update: ['*']
  enabled: true
  files: {}
  plan_require_all_dirspace_access: false
  policies:
    - apply: ['*']
      apply_autoapprove: []
      apply_force: []
      apply_with_superapproval: []
      plan: ['*']
      superapproval: []
      tag_query: ""
  terrateam_config_update: ['*']
  unlock: ['*']
```

## Keys

| Key | Type | Description |
| --- | --- | --- |
| `apply_require_all_dirspace_access` | boolean | `true`: to apply, the user must have access to every dirspace in the apply. Default is `true`. |
| `ci_config_update` | array | Who can run an operation on a pull request that changes the CI configuration file: `.github/workflows/stategraph.yml` on GitHub, `.gitlab-ci.yml` on GitLab. Default is `['*']`. |
| `enabled` | boolean | Turns on access control. Default is `true` in Enterprise and `false` in Open Source. |
| `files` | object | A file path as the key, and as the value, who can run an operation on a pull request that changes that file. |
| `plan_require_all_dirspace_access` | boolean | `true`: to plan, the user must have access to every dirspace in the plan. Default is `false`. |
| `policies` | array | The access rules for each operation. See [Policies](#policies). |
| `terrateam_config_update` | array | Who can run an operation on a pull request that changes `.stategraph/config.yml`. Default is `['*']`. |
| `unlock` | array | Who can unlock on a pull request. Default is `['*']`. |

### Policies

| Key | Type | Description |
| --- | --- | --- |
| `apply` | array | Who can apply, including autoapply. |
| `apply_autoapprove` | array | Reserved for `stategraph apply-autoapprove`. Orchestration does not run that command, so this key has no effect. |
| `apply_force` | array | Who can run `stategraph apply-force`. |
| `apply_with_superapproval` | array | Who can apply after a user in `superapproval` approves the pull request. |
| `plan` | array | Who can plan, including autoplan. |
| `superapproval` | array | The users whose approvals are super approvals. |
| `tag_query` | string | The directories and workspaces of the policy. See [tag queries](/docs/reference/orchestration/configuration/tag-queries). Required. |

### Rule Syntax

| Syntax | Matches |
| --- | --- |
| `*` | Anyone. |
| `user:username` | One user. |
| `team:teamname` | A member of the GitHub team. On GitLab, a direct member of the group. |
| `role:rolename` | A user with this repository role or a higher one. The roles, from lowest to highest, are `read`, `triage`, `write`, `maintain`, and `admin`. |

On GitHub, write a team by its slug. To list the slugs, run `gh api orgs/<ORG>/teams`.

### GitLab Users, Groups, and Roles

On GitLab, `user:` takes a GitLab username and `team:` takes a GitLab group.

- `team:` matches direct members of the group. A user who is a member only through a parent group does not match.
- Write a top-level group by its path, such as `team:acme`. Write a subgroup by its numeric group ID, such as `team:1234`. GitLab shows the ID on the group's overview page.
- `role:` reads the user's role in the project, including a role from a group.

GitLab project roles map to rule roles:

| GitLab role | Rule role |
| --- | --- |
| Minimal Access, Guest, Planner, Reporter | `read` |
| Developer | `write` |
| Maintainer, Owner | `maintain` |

No standard GitLab project role maps to `triage` or `admin`. To match maintainers and owners, use `role:maintain`.

## Examples

### Allow Only the SRE Team to Apply Changes

```yaml
access_control:
  policies:
    - tag_query: ''
      plan: ['*']
      apply: ['team:sre']
```

### Require Super Approval for Production Changes

```yaml
access_control:
  policies:
    - tag_query: 'dir:production'
      apply: []
      apply_with_superapproval: ['*']
      superapproval: ['team:sre']
    - tag_query: ''
      plan: ['*']
      apply: ['*']
```

### Allow Developers to Force Apply in the Development Environment

```yaml
access_control:
  policies:
    - tag_query: 'dir:development'
      apply_force: ['team:developers']
```

### Allow Only the SRE Team When the CI Configuration Has Changed

```yaml
access_control:
  ci_config_update: ['team:sre']
```

### Allow Only Repository Admins When a File Is Changed

```yaml
access_control:
  files:
    bin/script-that-handles-sensitive-things: ['role:admin']
```

## Related

- [Apply requirements](/docs/reference/orchestration/configuration/apply-requirements)
- [Tag queries](/docs/reference/orchestration/configuration/tag-queries)
- [Role-based access control](/docs/orchestration/governance/rbac)
- [stategraph apply-force](/docs/reference/orchestration/commands/apply-force)
