---
title: drift
description: Reference for the drift key in .stategraph/config.yml. Schedule drift detection and reconciliation, set run windows, and create issues.
order: 11
---


`drift` schedules drift detection and reconciliation in a repository that Stategraph Orchestration manages. It also sets run windows.

A drift run is a plan operation. Your [workflows](/docs/reference/orchestration/configuration/workflows) and [hooks](/docs/reference/orchestration/configuration/hooks) run for it, and plans and applies that drift starts get `TERRATEAM_RUN_KIND=drift`. A new or changed schedule runs immediately, inside its window if it has one.

Drift runs on the default branch. It also runs on a branch that an entry of [`destination_branches`](/docs/reference/orchestration/configuration/destination-branches) matches: a push to that branch registers the `drift` configuration of the branch, and its schedules plan the branch. A push to a branch that no entry matches registers no schedule and starts no run. When the branch is deleted, its schedules are removed.

## Default Configuration

```yaml
drift:
  enabled: false
  schedules: {}
```

## Keys

| Key | Type | Description |
| --- | --- | --- |
| `enabled` | boolean | Turns on drift detection. If `false`, drift detection and reconciliation do not run. Default is `false`. |
| `schedules` | object | The schedules. Each key is a unique schedule name, and each value is the schedule configuration. Required in this form, also when `enabled` is `false` (use `schedules: {}`). |

!!! note "Enterprise"
    More than one schedule is available on Stategraph Cloud (all plans) and self-hosted Enterprise deployments.

### Schedule

| Key | Type | Description |
| --- | --- | --- |
| `schedule` | string | How often drift runs: `hourly`, `daily`, `weekly`, or `monthly`. Required, with no default. |
| `reconcile` | boolean | `true`: when drift detection finds changes, an apply of the generated plan runs automatically. Default is `false`. |
| `tag_query` | string | The directories and workspaces of the schedule. See [tag queries](/docs/reference/orchestration/configuration/tag-queries). Required. Use `''` to match everything. |
| `window` | object | The window in which the schedule can run. Optional. When set, both `start` and `end` are required. |

`schedule` is the most frequent interval, not a guarantee of when or how often drift runs. In practice, this matters only for `hourly`, because a drift run can take longer than an hour.

!!! warning "Reconciliation"
    With `reconcile: true`, changes apply with no manual review or approval. Put safeguards and tests in place before you turn it on.

### Window

| Key | Type | Description |
| --- | --- | --- |
| `start` | string | The start of the window, inclusive, as `HH:MM TZ`, in 24-hour notation. |
| `end` | string | The end of the window, exclusive, as `HH:MM TZ`, in 24-hour notation. |

For valid time zone abbreviations, see [this list](https://en.wikipedia.org/wiki/List_of_time_zone_abbreviations).

!!! note "Windows that cross midnight"
    If `end` is less than `start`, the window ends on the next day. For example, with `start: 21:00 EST` and `end: 01:00 EST`, the window starts at `21:00 EST` today and ends at `01:00 EST` tomorrow.

### Legacy Single Schedule Form

You can also write one schedule directly under `drift`, with the `schedule`, `reconcile`, and `tag_query` keys. It is the same as a `schedules` entry named `default`, without `window`.

| Key | Type | Description |
| --- | --- | --- |
| `enabled` | boolean | Turns on drift detection. Default is `false`. |
| `schedule` | string | The interval: `hourly`, `daily`, `weekly`, or `monthly`. Required. |
| `reconcile` | boolean | Turns on reconciliation. Default is `false`. |
| `tag_query` | string | The directories and workspaces. Default matches everything. |

```yaml
drift:
  enabled: true
  schedule: daily
  reconcile: false
```

## Examples

### Enabling Drift Detection

```yaml
drift:
  enabled: true
  schedules:
    default:
      tag_query: ''
      schedule: daily
```

### Enabling Drift Detection with Reconciliation

```yaml
drift:
  enabled: true
  schedules:
    default:
      tag_query: ''
      schedule: weekly
      reconcile: true
```

### Using Tag Queries to Limit Scope

This schedule runs hourly, only for `dir:production`:

```yaml
drift:
  enabled: true
  schedules:
    prod:
      tag_query: 'dir:production'
      schedule: hourly
```

### Enable Drift for Production After Work Hours and Development Any Time

Both schedules run daily. The production window is from 6pm to 7am the next day.

```yaml
drift:
  enabled: true
  schedules:
    prod:
      tag_query: 'dir:production'
      schedule: daily
      window:
        start: '18:00 EST'
        end: '07:00 EST'
    dev:
      tag_query: 'dir:dev'
      schedule: daily
```

## Notifications

### Issues

To open an issue when drift detection finds changes, add this hook:

```yaml
hooks:
  plan:
    post:
      - type: drift_create_issue
```

Orchestration does not open a second issue for the same changes. If changes are frequent, drift detection can open many issues. To reduce them, limit the scope with `tag_query`.

- On GitHub, the runner opens the issue with a token from the Stategraph GitHub App.
- On GitLab, the runner opens the issue in the project with an access token that you supply, and adds the `terrateam` and `drift` labels. Orchestration finds an open drift issue by these two labels, so keep both labels on it.

On GitLab, set up the token before you turn on the hook:

1. Create a project or group access token with the `api` scope. A personal access token with the `api` scope also works.
2. Open your GitLab project and go to **Settings**, then **CI/CD**, then **Variables**.
3. Add the token as a masked variable with the **Key** `TERRATEAM_DRIFT_ACCESS_TOKEN`.

<figure class="docs-figure" data-vcs="github">
<div class="docs-mock">
<div class="docs-mock-issue-title">Terrateam: Drift Detected <span>#12</span><span class="docs-vcs-switch" role="group" aria-label="Provider"><button type="button" data-vcs-set="github" aria-pressed="true">GitHub</button><button type="button" data-vcs-set="gitlab" aria-pressed="false">GitLab</button></span></div><div class="docs-mock-issue-meta"><span class="docs-mock-state">Open</span><span class="vcs-github">Opened by the Stategraph GitHub App</span><span class="vcs-gitlab">Opened by the drift access token user</span><span class="vcs-gitlab docs-mock-label">terrateam</span><span class="vcs-gitlab docs-mock-label">drift</span></div><div class="docs-mock-issue-comment"><div class="docs-mock-body"><div class="docs-mock-h">Terrateam Drift Detection Report</div><p><strong>Terrateam detected drift against live infrastructure.</strong></p><p>Create a new pull request to reconcile differences or enable automatic reconciliation using the Terrateam configuration file. See <span class="docs-mock-link">Drift Detection</span> documentation for details.</p><div class="docs-mock-h">Terrateam Plan Output</div><details><summary>Directory: frontend | Workspace: default</summary><pre>Terraform will perform the following actions:

  # aws_security_group_rule.https will be updated in-place
  ~ resource &quot;aws_security_group_rule&quot; &quot;https&quot; {
      ~ cidr_blocks = [
          - &quot;0.0.0.0/0&quot;,
          + &quot;10.0.0.0/8&quot;,
        ]
        id          = &quot;sgrule-2468013579&quot;
    }

Plan: 0 to add, 1 to change, 0 to destroy.</pre></details><details><summary>Directory: backend | Workspace: default</summary><p class="docs-mock-muted">The plan output for this directory.</p></details><hr><p>Report ID: 938b9891b39e674fd252fe9f2cc6268f</p></div></div>
</div>
<figcaption>An issue opened by drift detection.</figcaption>
</figure>

#### Grouping

By default, one issue lists every drifted dirspace. For one issue per drifted dirspace, set `group_by: dirspace`:

```yaml
hooks:
  plan:
    post:
      - type: drift_create_issue
        group_by: dirspace
```

| Value | Behavior |
| --- | --- |
| `all` (default) | One issue for each drift run, with every drifted dirspace. |
| `dirspace` | One issue for each drifted dirspace. |

Use `dirspace` when different teams own the dirspaces, or when each dirspace needs its own triage, assignee, and closure. Each issue has the title `Terrateam: Drift Detected - <dir> (<workspace>)`, and Orchestration deduplicates each issue on its own. A new drift run does not open an issue again when its plan output did not change.

### Slack

On GitHub, send Slack notifications with the official [GitHub Integration for Slack](https://github.com/integrations/slack):

- Install the app in your Slack workspace and channel.
- Use the `/github` command to subscribe to your Terraform repository:

```text
/github subscribe owner/repo issues
```

On GitLab, use the Slack integration of the project to notify a channel of new issues. Drift issues have the `terrateam` and `drift` labels.

### Custom Notifications

For custom notifications or actions when drift detection finds changes, add a hook. Use it to connect drift detection to your monitoring and alerting systems:

```yaml
hooks:
  plan:
    post:
      - type: run
        cmd: ['bash', '-c', '$TERRATEAM_ROOT/drift-notify.sh']
```

`drift-notify.sh`:

```bash
#!/usr/bin/env bash
set -e
if [[ "$TERRATEAM_RUN_KIND" == "drift" ]] && [[ -f "$TERRATEAM_RESULTS_FILE" ]]; then
  echo "This is a drift operation"
fi
```

## Related

- [Drift detection](/docs/orchestration/governance/drift-detection)
- [hooks](/docs/reference/orchestration/configuration/hooks)
- [Tag queries](/docs/reference/orchestration/configuration/tag-queries)
