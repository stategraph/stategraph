---
title: Commits That Move During a Run
description: How Stategraph Orchestration handles a push or a merge while a plan or an apply runs, and what a stale result means for your pull request.
order: 5
---

A plan or an apply uses the commits of a branch. Somebody can push to the pull request (merge request in GitLab), or merge another pull request into the destination branch, while the run operates. The commits of the run are then older than the head of the branch.

Stategraph Orchestration does not treat every move as a problem. A move matters only when it changes the files of a directory and workspace (a [dirspace](/docs/get-started/core-concepts#repository-directory-and-workspace)) of the run. When it does, the result of that dirspace is **stale**: it was computed from files that are no longer at the head.

## How Orchestration decides

For each dirspace of the run, Orchestration compares the files of the commits that the run used with the files of the current commits. It uses the same comparison that decides whether a pull request keeps its plans after a push. A dirspace changes when a file that it uses changes: a file in its directory, a file that its [file patterns](/docs/reference/orchestration/configuration/when-modified) match, or a dirspace that it depends on.

The commits that Orchestration compares depend on the run:

- **Open pull request:** the commit of the run with the head of the pull request, and the head of the destination branch at the start of the run with the head of the destination branch now. The runner merges the destination branch when it starts, thus a move of either branch can make the run stale.
- **Merged pull request:** the head of the destination branch at the start of the run with the head of the destination branch now.
- **Drift:** the head of the branch at the start of the run with the head of the branch now.

A push that changes only other files, for example documentation, does not make the run stale. The run completes as usual, and its checks and comments show no warning.

### When Orchestration cannot compare

Orchestration compares the stored trees of two commits. With the [tree builder](/docs/orchestration/workflows/advanced/tree-builder-setup) or a config builder turned on, the tree or the built config of a commit can be missing when the result arrives. Orchestration does not wait for a build. It treats every dirspace of the run as stale, and the warning says that it cannot compare the files yet.

This fails safe. A later `stategraph plan` or `stategraph apply` builds the tree of the head and compares again. When the comparison then proves that the files did not change, the earlier result is valid again: Orchestration does not run the dirspace again, and it sets its checks from the earlier result.

## Before the run starts

When the runner asks for its work, nothing has run yet. Orchestration compares:

1. The commit of the run with the commit that the runner checked out.
2. The commit that the runner checked out with the head of the branch now.

If the files of a dirspace changed in either range, Orchestration aborts the run and evaluates the pull request again at the new head. You see a new plan for the new head, and the old commit is never applied.

A job that aborts or restarts more than 10 runs stops with an error, so that a branch that keeps moving does not restart work without end.

## When the result arrives

### Plan

Orchestration always posts the plan output. For a stale dirspace, the output starts with a **Commits moved during this plan** warning that names the commits that moved and the stale dirspaces. The plan check of a stale dirspace fails with the description `Stale: commits moved during the run`.

A stale plan is not valid. Comment `stategraph plan` to plan the head again before you apply.

When you push again while a plan runs, the newer plan replaces the older one. Orchestration aborts or hides the older plan, and posts only the plan of the newest head.

### Apply

Orchestration always posts the apply output, because the apply changed your infrastructure with the files of the commit that it used. For a stale dirspace, the output starts with a **Commits moved during this apply** warning.

A stale dirspace is **not applied**: the files at the head are different from the files that the apply used. Its apply check fails with the description `Stale: commits moved during the run`, and the `stategraph apply` check does not pass while a dirspace is stale. Orchestration does not start the apply again by itself. Plan and apply the stale dirspaces again.

A dirspace whose apply failed is failed, whether it is stale or not.

### Layered runs

A dirspace of a [layered run](/docs/orchestration/workflows/advanced/layered-runs) runs only when every dirspace that it depends on is applied. A stale dirspace is not applied, thus the layers that depend on it wait. The warning lists the commands to plan the stale layer again, for example:

```text
stategraph plan dir:network
```

### Drift

When the files of a drift reconcile change while it runs, Orchestration stores the result and reconciles again at the new head. A drift reconciles again at most 10 times. To turn this off for a schedule, set [`restart_on_change: false`](/docs/reference/orchestration/configuration/drift#schedule).

## Status checks after a push

GitHub removes the checks of the old head when you push to a pull request. When Orchestration evaluates the new head, it creates the checks again for each dirspace that keeps its run. A dirspace whose last plan or apply failed does not keep its run: the next plan of the pull request, for example the autoplan of the push, plans it again, and its apply check waits for a new apply. The summary comment shows the state of each dirspace at the head, including the `stale` state.

## Limitations

- The runner merges the head of the destination branch when it starts. Orchestration does not know that exact commit, thus a merge in the first seconds of a run can cause a stale warning that is not necessary. Orchestration never hides a real change.
- A push directly to the destination branch, not through a pull request, is not compared. The required `stategraph apply` check makes sure that each pull request runs on its dirspaces before it merges.
