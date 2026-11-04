---
title: batch_runs
description: Reference for the batch_runs key in .stategraph/config.yml. Limit how many workspaces a single CI run executes in large repositories.
order: 4
---


`batch_runs` sets how Stategraph Orchestration puts work into CI runs: how many workspaces one work manifest holds, how many work manifests one run performs, and which steps can join a run that is already running. A CI run is a GitHub Actions workflow run or a GitLab pipeline. In a large repository, one run cannot always hold all workspaces because of CPU and disk space limits.

## Default Configuration

```yaml
batch_runs:
  enabled: false
  max_work_manifests_per_node: 9
  max_workspaces_per_batch: 1
  merge_steps: setup
```

## Keys

| Key | Type | Description |
| --- | --- | --- |
| `enabled` | boolean | Turns on `max_workspaces_per_batch`. It does not control `merge_steps` or `max_work_manifests_per_node`. Default is `false`. |
| `max_work_manifests_per_node` | integer | The maximum number of work manifests one CI run is given. The count is charged when the work manifest joins the run, and it never goes down, so it is an upper bound on how many the run performs. Orchestration spreads the work of one operation evenly over the runs it starts, and gives a work manifest a run of its own when it cannot start in the run it joined. Minimum is `1`, maximum is `9`, default is `9`. |
| `max_workspaces_per_batch` | integer | The maximum number of workspaces in one work manifest. Orchestration creates more work manifests for the other workspaces. Default is `1`. |
| `merge_steps` | string | Which steps can join a run that is already running: `none`, `setup`, `setup_and_plan`, `all`, or `by_phase`. Default is `setup`. See [Merging steps](#merging-steps). |

Orchestration limits the runs of one operation with `work_manifests.concurrent_runs`, which is `10` by default. For example, a change with 100 workspaces and `max_workspaces_per_batch: 1` makes 100 work manifests, and with the default `max_work_manifests_per_node: 9` that is 12 runs — so the `concurrent_runs` default of `10` binds first, and the operation runs `10` at a time until they are done. Raise `work_manifests.concurrent_runs` if you want all `12` at once.

A run once held a workspace budget of its own, and it no longer does. A run performs up to `max_work_manifests_per_node` work manifests, and each of them holds up to `max_workspaces_per_batch` workspaces. With `enabled: false` a work manifest holds no workspace bound, so one run can receive the work of many workspaces at once, and the memory and the disk of its runner must hold all of them. A repository whose runners have little room for it sets `enabled: true` and a `max_workspaces_per_batch` that fits its runners.

## Merging steps

Orchestration puts the steps of a job into as few runs as it can, because many runs are slower than one run. `merge_steps` sets which steps can join a run that is already running. A step that the value does not permit always starts a run of its own.

Four of the values make a ladder of the highest step that can join:

| Value | The steps that can join a run |
| --- | --- |
| `none` | None. Each step gets a run of its own. |
| `setup` | The tree builder, the config builder and the indexer. |
| `setup_and_plan` | The steps above, and a plan. |
| `all` | The steps above, and an apply, so a stack of layers can share one run while the job's work manifests fit `max_work_manifests_per_node`. |

The fifth value, `by_phase`, is not on that ladder. See [Phases](#phases).

A step joins a run only if the run can take it:

- The run is still queued or starting.
- The run has the same environment, the same `runs_on`, and the same head commit.
- The run has been given fewer work manifests than `max_work_manifests_per_node`.

A step that cannot join gets a run of its own.

Orchestration reads `merge_steps` from the configuration file in the repository. A configuration from the config builder cannot set it, because the tree builder, the config builder and the indexer run before that configuration exists.

`merge_steps` changes only how many runs hold the work of a job. It cannot start an operation that the rest of the configuration does not permit, and it cannot stop an operation that the rest of the configuration permits. Automatic plans and applies happen in the same order with any value of this key.

## Phases

The steps of a job fall into two phases.

| Phase | The steps of the phase |
| --- | --- |
| Setup | The tree builder, the config builder and the indexer. |
| Layer | A plan and an apply. |

`merge_steps: by_phase` permits every step, as `all` does, but only into a run of the same phase. A run thus holds one phase, never both.

```yaml
batch_runs:
  merge_steps: by_phase
```

Use `by_phase` when the setup steps of a job must keep a run of their own, and the layers of that job must still share one run.

### Example

A pull request has the three setup steps and three layers. The first two layers have no changes, so Orchestration plans the next layer without a comment from a user. The third layer has a change and stops the job at the plan comment.

| Value | The runs |
| --- | --- |
| `none` | Six. One for each step. |
| `setup` | Four. One for the three setup steps, and one for each layer. |
| `setup_and_plan` | One. A plan joins the run of the setup steps. |
| `all` | One. The same as above, and an apply would join as well. |
| `by_phase` | Two. One for the three setup steps, and one for the three layers. |

These counts do not include one more run. The tree builder of a pull request also builds the tree of the destination branch. That build has the ref of the destination branch, so it always takes a run of its own, whatever the value of `merge_steps`.

## Related

- [parallel_runs](/docs/reference/orchestration/configuration/parallel-runs)
- [Performance](/docs/orchestration/workflows/performance)
