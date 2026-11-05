---
title: notifications
description: Reference for the notifications key in .stategraph/config.yml. Control comment strategies, the run summary, and per-dirspace status checks.
order: 18
---


`notifications` controls what Stategraph Orchestration posts to a pull request: how new comments replace old ones for each directory and workspace, the summary of a run, the plan and apply comments, and the per-dirspace status checks.

## Default Configuration

```yaml
notifications:
  policies:
    - tag_query: ''
      comment_strategy: 'minimize'
  summary:
    # enabled has no default of its own. Unset means on in the
    # Enterprise edition and off in the Open Source edition.
    mode: pull_request
    output_details:
      enabled: false
  plan:
    visible_on: always
    status_checks:
      enabled: true
  apply:
    visible_on: always
    status_checks:
      enabled: true
```

## Keys

| Key | Type | Description |
| --- | --- | --- |
| `policies` | array | Notification policies: the comment strategy for the dirspaces that a tag query matches. |
| `summary` | object | The summary of a run. Enterprise only. |
| `plan` | object | The plan comment of each run, and the per-dirspace plan status check. |
| `apply` | object | The apply comment of each run, and the per-dirspace apply status check. |

### Policies

| Key | Type | Description |
| --- | --- | --- |
| `comment_strategy` | string | What happens to old comments when Orchestration posts a new one: `append` keeps them, `minimize` minimizes them, and `delete` removes them. Default is `minimize`. |
| `tag_query` | string | See [tag queries](/docs/reference/orchestration/configuration/tag-queries). Required. |

GitLab cannot minimize a comment. On GitLab, `minimize` replaces the body of an earlier comment with a collapsed note that says the output was superseded. The full output stays on the run page that the comment links to.

### Summary

!!! note "Enterprise"
    The summary is an [Enterprise](/docs/get-started/editions) feature. The Open Source edition does not support it. If you enable it there, Orchestration posts a message that this is a commercial feature, and does not run the operation.

| Key | Type | Description |
| --- | --- | --- |
| `enabled` | boolean | Turns on the summary. The key has no default of its own: when you leave it out, the summary is on in the Enterprise edition and off in the Open Source edition. |
| `mode` | string | `header`: a summary header in each plan and apply comment. `pull_request`: one summary comment for the whole pull request. Default is `pull_request`. Both modes need `enabled: true`. |
| `output_details.enabled` | boolean | `true` adds an output details section with the plan output to the summary comment. Default is `false`. The plan output is also in the console, through the links in the table. |

On the Enterprise edition, the summary is on unless you turn it off:

```yaml
notifications:
  summary:
    enabled: false
```

### Header Mode

With `mode: header`, each plan and apply comment starts with a summary header, above the collapsed plan and apply output. Reviewers see what a comment covers without expanding the full output.

The header has a one-line rollup and a table of the dirspaces (directory and workspace combinations) of that comment. For each dirspace, the table shows:

- The result.
- For plans, the imported, created, updated, replaced, and deleted resource counts that the runner reports. The imported count includes every resource that the plan imports, whatever its action. A runner or engine that reports no counts shows `-`.

In `header` mode, the per-dirspace changes tables of the plan and apply comments are never collapsed.

### Plan and Apply

`plan` and `apply` set what a run of that kind posts: its comment and its per-dirspace status check. They are separate from `summary`, so they work with or without the summary, in either mode. They are not an Enterprise feature.

| Key | Type | Description |
| --- | --- | --- |
| `plan.visible_on` | string | When the plan comment of each run posts: `always`, `change_or_failure`, `failure`, `success`, or `never`. Default is `always`. |
| `plan.status_checks.enabled` | boolean | `true` gives each dirspace of a plan its own status check, `stategraph plan: <directory> <workspace>`. Default is `true`. |
| `apply.visible_on` | string | When the apply comment of each run posts: `always`, `failure`, `success`, or `never`. Default is `always`. |
| `apply.status_checks.enabled` | boolean | `true` gives each dirspace of an apply its own status check, `stategraph apply: <directory> <workspace>`. Default is `true`. |

- A result with gate approvals or access control denials always posts its comment, whatever the value of `visible_on`, because no other comment carries them.
- In `header` mode, the summary header is in the plan or apply comment. A comment that `visible_on` hides also hides its header.
- With `change_or_failure`, the plan comment posts when a plan in the run has changes or the run fails. A successful run with no changes posts no plan comment.
- A pull request that impacts more than 50 dirspaces gets no per-dirspace checks of either kind, whatever the settings say. Orchestration then behaves as `plan.status_checks.enabled: false` and `apply.status_checks.enabled: false`: one large pull request does not fill the check list of the forge. Do not require a per-dirspace check in branch protection for a repository whose pull requests can exceed 50 dirspaces. The `stategraph apply` check is not affected. To find the cause, see [Per-dirspace status checks are missing](/docs/reference/troubleshooting#per-dirspace-status-checks-are-missing).

`status_checks` controls only the per-dirspace checks. It does not change these checks:

- `stategraph apply`, which stays pending until every changed dirspace is applied. Require this check in branch protection. Orchestration always creates it.
- `stategraph index`, `stategraph build-config`, and `stategraph build-tree`, which belong to other operations.

On GitLab, checks are commit statuses on the merge request pipeline, and each status counts toward the pipeline result. Orchestration thus publishes only `stategraph apply` on GitLab, so that the plan of one directory cannot hold the full pipeline pending or failed.

The check names start with the brand of the repository, `stategraph` or `terrateam`. For how Orchestration selects the brand, see `TERRAT_BRAND` in [Environment variables](/docs/admin/operations/environment-variables).

A pull request opened before the `pre-hooks` and `post-hooks` checks were retired can still have one of them. Orchestration completes it when every changed dirspace of that pull request is applied.

A repository with many dirspaces gets one check per dirspace per run. Turn the checks off to prevent this. The setting applies to every run of that kind, drift included.

```yaml
notifications:
  plan:
    visible_on: never
    status_checks:
      enabled: false
  apply:
    visible_on: failure
    status_checks:
      enabled: false
```

### Pull Request Mode

With `mode: pull_request`, Orchestration keeps one summary comment per pull request. Reviewers always have one current view of the pull request.

- Orchestration posts the comment when a run starts, before the run can post a result. It is always the first Orchestration comment on the pull request.
- While a run is in progress, its dirspaces show as `Plan Running` or `Apply Running`.
- When each run finishes, Orchestration updates the comment in place.

The comment has a table with one row per dirspace:

- Status: one of the values below.
- Change counts: `Created`, `Updated`, `Replaced`, and `Deleted`, from the resource summary of the plan step on the runner. A runner or engine that reports no counts shows `-`.
- Link: a link to the dirspace in the console.

The status of a dirspace is one of:

- `Pending`: the dirspace is in the pull request and nothing has run for it.
- `Plan Running`: a plan is in progress and has produced nothing for the dirspace.
- `Apply Running`: the apply of a plan that is already in the table is in progress.
- `Planned`: a plan succeeded and waits for an apply.
- `Applied`: the apply succeeded.
- `Failed`: the plan or the apply failed, or the run stopped before it produced a result.

A totals row adds up the change counts of all dirspaces. Failures sort first, then dirspaces with changes. If the table is too large for one comment, Orchestration truncates it to the top rows and links to the console for the full list.

The plan and apply comments of each run still post next to the summary comment:

- Their per-dirspace changes table is collapsed into a details block that shows the totals of the table. The summary comment has the full rollup.
- To post fewer of these comments, use `plan.visible_on` and `apply.visible_on`.
- With `never`, the summary comment is the only comment. The full output is in the console, through the links in the table.

To turn on this mode:

```yaml
notifications:
  summary:
    enabled: true
    mode: pull_request
```

## Examples

### Multiple Comment Strategies for Different Dirspaces

```yaml
notifications:
  policies:
    - tag_query: 'dir:tf1'
      comment_strategy: 'minimize'

    - tag_query: 'dir:tf2'
      comment_strategy: 'delete'
```

The `tf1` directory minimizes old comments, and the `tf2` directory deletes them.

## Related

- [Pull request workflow](/docs/orchestration/workflows)
- [apply_requirements](/docs/reference/orchestration/configuration/apply-requirements)
- [Tag queries](/docs/reference/orchestration/configuration/tag-queries)
