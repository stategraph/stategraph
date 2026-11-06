---
title: Apply After Merge
description: Apply infrastructure changes automatically when a pull request merges, with when_modified.autoapply, selective directories, and apply requirements.
order: 2
---


Apply after merge makes Stategraph Orchestration apply a pull request when it merges. Nobody comments `stategraph apply` before the merge, so each deployment has one manual step less.

## Enabling apply after merge

Set `when_modified.autoapply: true` in `.stategraph/config.yml`. To turn it off, set it to `false`. The [when_modified reference](/docs/reference/orchestration/configuration/when-modified) lists every option.

```yaml
when_modified:
  autoapply: true
  file_patterns: ["**/*.tf", "**/*.tfvars"]
  autoplan: true
  autoplan_draft_pr: true
```

## How it works

1. Open a pull request with changes to your Terraform code.
2. Orchestration runs a plan and comments on the pull request with the output.
3. Review the plan with your team. The merge starts the apply, so review and test the change before you merge.
4. When the pull request is approved and every required check has passed, merge it.
5. Orchestration detects the merge and starts an apply.
6. Orchestration comments on the merged pull request with the apply output, or with the error details if the apply fails.

The apply uses the plan that you reviewed. If another pull request superseded that plan before the merge, the apply aborts with a **Missing Plans** comment. See [Apply runs the plan you reviewed](/docs/orchestration/workflows).

On GitLab, the **Merge request events** trigger of the project webhook tells Orchestration about the merge. Orchestration starts the apply pipeline on the destination branch, so the `.gitlab-ci.yml` on that branch must contain the Orchestration pipeline that the **Get Started** page of the console shows.

## Customizing apply after merge

### Selective auto-apply

To use apply after merge only for some directories, set `autoapply` under [dirs](/docs/reference/orchestration/configuration/dirs):

```yaml
dirs:
  prod:
    tags: [prod]
    when_modified:
      autoapply: true
      file_patterns: ["${DIR}/*.tf"]
  staging:
    tags: [staging]
    when_modified:
      autoapply: false
      file_patterns: ["${DIR}/*.tf"]
```

Production applies on merge. Staging still waits for a `stategraph apply` comment.

### Apply requirements

[Apply requirements](/docs/reference/orchestration/configuration/apply-requirements) stop a `stategraph apply` comment when they fail. They do not stop the apply that a merge starts. To gate a merge, use the branch protection of GitHub or GitLab, for example required reviews and status checks.

```yaml
apply_requirements:
  create_pending_apply_check: true
  checks:
    - tag_query: ""
      approved:
        enabled: true
        any_of: ["team:infrastructure"]
        any_of_count: 2
      merge_conflicts:
        enabled: true
      status_checks:
        enabled: true
        ignore_matching: []
```

This configuration requires:

- Two approvals from the infrastructure team.
- No merge conflicts.
- A pass on every status check.

### Notifications

For notifications other than the apply comment, add a post-apply [hook](/docs/reference/orchestration/configuration/hooks):

```yaml
hooks:
  apply:
    post:
      - type: run
        cmd: ['curl', '-X', 'POST', '--data', '{"text":"Apply completed after merge"}', '${SLACK_WEBHOOK_URL}']
```

`SLACK_WEBHOOK_URL` comes from a [CI secret](/docs/orchestration/configuration/variables). To send a different message on `failure`, use the `run_on` key of the `run` hook.

## Next Steps

- [Pull request workflow](/docs/orchestration/workflows): the default apply-before-merge flow.
- [when_modified](/docs/reference/orchestration/configuration/when-modified): file patterns, autoplan, and autoapply.
- [Multi-environment](/docs/orchestration/workflows/advanced/multi-environment): different rules for staging and production.
