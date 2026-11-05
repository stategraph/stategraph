---
title: Drift Detection
description: Detect and reconcile infrastructure drift on a schedule with Stategraph Orchestration, open GitHub or GitLab issues, and track it in the console.
order: 3
---


!!! note "Edition differences"
    Both editions include drift detection. The Open Source edition supports one drift schedule per repository. More than one schedule per repository is an Enterprise feature: on the Open Source edition, Orchestration rejects a configuration with more than one entry under `drift.schedules`. See [Editions](/docs/get-started/editions).

Drift detection in Stategraph Orchestration finds where your infrastructure differs from the desired state in your Terraform code, and can reconcile the difference. On a schedule, it runs a plan against all [dirspaces](/docs/get-started/core-concepts#repository-directory-and-workspace) in your repository. It runs on the default branch, and on each branch that [`destination_branches`](/docs/reference/orchestration/configuration/destination-branches) matches. When it finds drift, Orchestration can open an issue in your GitHub repository or GitLab project, or apply the plan. Your infrastructure stays consistent and compliant.

## Enabling drift detection

Configure drift detection in `.stategraph/config.yml`. `schedule` is `hourly`, `daily`, `weekly`, or `monthly`. This example runs daily:

```yaml
drift:
  enabled: true
  schedules:
    default:
      tag_query: ''
      schedule: daily
```

## Drift reconciliation

With `reconcile: true`, Orchestration applies the generated plan each time it detects drift. This brings your infrastructure back in sync with your Terraform configuration.

```yaml
drift:
  enabled: true
  schedules:
    default:
      tag_query: ''
      reconcile: true
      schedule: weekly
```

!!! warning "Reconciliation applies without review"
    Reconciliation applies changes with no manual review or approval. First run drift detection alone, assess the impact, and check that the drift it finds is valid and needs action. Put safeguards and testing in place before you turn on reconciliation.

## Limiting drift detection scope

In a large repository, a [tag query](/docs/orchestration/workflows/advanced/tag-system) limits drift detection to the directories and workspaces that match. This reduces noise, and keeps the focus on the critical parts of your infrastructure. This example limits drift detection to the `production` directory:

```yaml
drift:
  enabled: true
  schedules:
    prod:
      tag_query: "dir:production"
      schedule: hourly
```

## Drift in the console

The console shows drift status, schedules, and check history on the **Drift** page. You can also query drift schedules with [SQL](/docs/infrastructure-as-a-database/query/query), scoped to your tenant.

## Notifications and alerting

Orchestration can notify your team with an issue, a Slack message, or your own script.

### Drift issues

The `drift_create_issue` hook opens an issue in your repository each time Orchestration detects drift. The issue shows the affected resources and the changes that reconcile the drift. Orchestration does not open a duplicate issue for identical drift findings.

```yaml
hooks:
  plan:
    post:
      - type: drift_create_issue
```

- On GitHub, you need no setup. The runner opens the issue with the token that Orchestration provides for the run.
- On GitLab, add a project, group, or personal access token with the `api` scope as a masked CI/CD variable named `TERRATEAM_DRIFT_ACCESS_TOKEN`. The runner opens the issue with it.
- GitLab drift issues have the labels `terrateam` and `drift`. The runner searches the open issues with these labels to avoid duplicates.

By default, one issue lists every drifted dirspace. To open one issue per dirspace, for example when different teams own the dirspaces or triage them separately, set `group_by: dirspace`:

```yaml
hooks:
  plan:
    post:
      - type: drift_create_issue
        group_by: dirspace
```

See the [drift configuration reference](/docs/reference/orchestration/configuration/drift#grouping) for details.

### Slack notifications

To get a Slack notification for detected drift, subscribe to the issues of the repository. On GitHub:

1. Install the official [GitHub integration for Slack](https://github.com/integrations/slack) in your Slack workspace and channel.
2. Use the `/github` command to subscribe to the issues of your Terraform repository.

```text
/github subscribe owner/repo issues
```

Each GitHub issue that Orchestration creates for drift then shows in your Slack channel. On GitLab, turn on issue event notifications for the project in the GitLab Slack integration.

### Custom notifications

To send drift to your monitoring and alerting systems, or for other notification needs, run your own script in a hook. This example runs a script after every plan:

```yaml
hooks:
  plan:
    post:
      - type: run
        cmd: ['bash', '-c', '$TERRATEAM_ROOT/drift-notify.sh']
```

Drift plans set `TERRATEAM_RUN_KIND=drift` in the runner environment, so `drift-notify.sh` can tell a drift run from a pull request plan, and send notifications or trigger actions.

## Next steps

- [drift reference](/docs/reference/orchestration/configuration/drift) for every schedule key, run windows, and issue grouping
- [hooks reference](/docs/reference/orchestration/configuration/hooks) for the `drift_create_issue` and `run` hooks
- [Tag system](/docs/orchestration/workflows/advanced/tag-system) for tag query syntax
