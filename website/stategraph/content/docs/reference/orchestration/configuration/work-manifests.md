---
title: work_manifests
description: Reference for work_manifests in .stategraph/config.yml. Bound how many runs one job runs at the same time and how long a run may take to start and run.
order: 27
---


`work_manifests` sets how long a run has to call home before Stategraph Orchestration treats it as stale and aborts it. A run that never starts holds the directories and workspaces of its operation, and the work behind it waits with no end.

`work_manifests` also sets how long a running run may run before the hourly sweep aborts it. A run that stops in the middle holds its directories and workspaces with no end as well.

`work_manifests` also sets how many runs of one job run at the same time. A job that fans out past the limit holds the rest of its runs in the queue until a run of the same job completes.

## Default Configuration

```yaml
work_manifests:
  concurrent_runs: 10
  start_timeout_sec: 180
  stale_timeout_sec: 86400
```

## Keys

| Key | Type | Description |
| --- | --- | --- |
| `concurrent_runs` | integer | How many work manifests one job may run at the same time. Default is `10`. The value must be at least `1` and at most `2147483647`, a value outside that range is a configuration error. |
| `start_timeout_sec` | integer | Seconds that a dispatched run has to call home before Orchestration aborts it as stale. Default is `180`. The value must be at least `1` and at most `2147483647`, a value outside that range is a configuration error. |
| `stale_timeout_sec` | integer | Seconds that a run may stay in the `running` state before the hourly sweep aborts it. Default is `86400`, one day. The value must be at least `1` and at most `2147483647`, a value outside that range is a configuration error. |

## How many runs one job runs at once

A job makes one work manifest for each batch of directories and workspaces that it plans or applies. With [batch_runs](/docs/reference/orchestration/configuration/batch-runs) disabled, one job can still make several work manifests: the batches separate the run parameters of the dirspaces and keep one directory out of two batches, so a job with several environments or several workspaces in one directory makes one work manifest for each. The three setup runs, the config builder, the tree builder, and the index, each add a work manifest of the same job, one per branch target.

The limit counts the work manifests of the job whose state is `running`. A work manifest that waits in the queue does not count, so a job that makes all of its work manifests at once still starts one. The limit is for each job: a job at its limit holds back no other job of the repository, and a repository at its limit holds back no other repository.

The setup runs count toward the same limit as the plan and apply runs, because they are work manifests of the same job. A low limit therefore runs them one at a time with the rest of the job: with `concurrent_runs: 1`, a cold job runs its setup, then its plans, then its applies, one run at a time, and this is by design. The serialization ends once the setup caches are warm, because a warm setup run adds no work manifest. A repository that wants the setup runs to overlap the plan runs sets a limit of at least the number of enabled setup runs of one branch target, three at most: the config builder, the tree builder, and the index.

The dispatcher starts the next work manifest of the job as soon as a run of the job completes. The hourly sweep and the abort of a failed run free a slot too, and they wake the dispatcher, so a queued work manifest starts without waiting for the next event of the pull request.

A run that waits in the queue for a slot produces no comment. The run is in the queue like any other run.

!!! note "The value is read from the derived configuration"
    The dispatcher reads `concurrent_runs` from the derived configuration of each run, which is the configuration of the repository at the (branch, sha) of the run. A run whose stored configuration is gone falls back to the default of ten.

## When a run counts as stale

A run calls home the first time its runner polls the server. The count starts when Orchestration dispatches the run, not when the run enters the queue, so a run that waits in the queue a long time is not stale.

Orchestration runs the check when an operation requests directories and workspaces that a running run already holds. It aborts the run when all of these hold:

- The run state is `running`.
- The runner never polled, so the run has no run id.
- The run has been dispatched for longer than `start_timeout_sec` seconds.
- The run belongs to no run of the operation that you requested.

The abort is silent: Orchestration posts no comment for it. The run becomes `aborted`, its directories and workspaces are free, and the work that waited behind it starts.

A run that has no dispatch time, one from before Orchestration recorded it, is never stale.

!!! note "A run that started is not aborted by the start check"
    A run that called home passes the start check, however long it runs. A run that has been in flight for over an hour instead blocks the operation and posts a **Potentially Stale Operations Detected** comment with the [`stategraph unlock`](/docs/reference/orchestration/commands/unlock) command to clear it. The sweep of the next section still aborts such a run when it runs longer than `stale_timeout_sec`.

## When a running run is swept

Orchestration sweeps for stale runs once an hour. The sweep is one statement for every repository of the installation, and it aborts a run when all of these hold:

- The run state is `running`.
- The run started more than `stale_timeout_sec` seconds ago.

The age of a run starts when Orchestration dispatches it, as it does for `start_timeout_sec`, so a run that waited in the queue a long time is not swept the moment it starts. A run that has no dispatch time, one from before Orchestration recorded it, counts from the time it entered the queue. The sweep reads no run id and no poll: a run that called home once and then stopped is read the same as a run that never polled. One day is longer than any run a healthy repository produces, thus the default holds for every repository that sets no value.

The sweep reads `stale_timeout_sec` from the derived configuration of the run, which is the configuration of the repository at the (branch, sha) of the run. A run whose stored configuration is gone falls back to the default of one day. The sweep keeps at most 100 runs per hour, and a sweep that cannot keep up leaves the rest to the next hour.

The abort is silent: Orchestration posts no comment for it. The run becomes `aborted`, its directories and workspaces are free, and the work that waited behind it starts.

## Configuration file only

Orchestration reads `start_timeout_sec` from `.stategraph/config.yml` in the repository. A configuration that a config builder or tree builder run produced cannot set it, because such a run is a work manifest itself: a run must never decide when Orchestration aborts runs.

The dispatcher and the sweep read `concurrent_runs` and `stale_timeout_sec` from the derived configuration of the run instead, as the notes above describe. A configuration that a config builder run produced can thus set both.

## Example Configuration

```yaml
work_manifests:
  concurrent_runs: 4
  start_timeout_sec: 600
  stale_timeout_sec: 172800
```

A repository whose runners start slowly can raise `start_timeout_sec` to 600 seconds, so that a slow start is not read as a failure to start. A repository whose apply step runs for more than a day can raise `stale_timeout_sec` to 172800 seconds, two days, so that the sweep does not abort a run that still works. A repository whose CI bill grows with the number of concurrent runs can lower `concurrent_runs`, so that a job with many dirspaces runs a few at a time instead of all of them at once.

## Related

- [Stale runs](/docs/orchestration/workflows/stale-runs): a run that is valid but used files that are no longer at the head. It is a different meaning of stale.
- [batch_runs](/docs/reference/orchestration/configuration/batch-runs): which steps of one job share a CI run
- [stategraph unlock](/docs/reference/orchestration/commands/unlock): clear a run that blocks an operation
- [Troubleshooting](/docs/reference/troubleshooting#apply-is-waiting-on-work-already-running)