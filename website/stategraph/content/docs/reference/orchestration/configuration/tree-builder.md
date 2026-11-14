---
title: tree_builder
description: Reference for the tree_builder key in .stategraph/config.yml. Replace Git change detection with a script that lists files and their content IDs.
order: 25
---


`tree_builder` makes Stategraph Orchestration use your own script, not only the Git file tree and diff, to find the files of the repository and the changed files. The script lists the files to track with an optional ID for each file, and Orchestration compares the IDs between branches.

Use it for dynamic infrastructure, complex monorepo dependencies, or any case where the Git diff does not capture what "changed" means for your workflow.

## Default Configuration

```yaml
tree_builder:
  enabled: false
```

## Keys

| Key | Type | Description |
| --- | --- | --- |
| `enabled` | boolean | Turns on the tree builder. Default is `false`. |
| `script` | string | The script that builds the file tree. It must write JSON to stdout. Required when `enabled` is `true`. |

## Script Output

The script must write a JSON array of file objects to stdout:

```json
[
  {
    "path": "path/to/file1.tf",
    "id": "abc123def456"
  },
  {
    "path": "path/to/file2.tf",
    "id": "789ghi012jkl"
  }
]
```

- The output is a bare array, not an object with a `files` key. A script that writes `{"files": [...]}` fails with `TypeError: string indices must be integers`.
- An empty array is valid. It means that the repository has no files to track.

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `[].path` | string | Yes | Relative path from the repository root. |
| `[].id` | string | No | Unique identifier for the file, typically a hash. Orchestration compares IDs between branches to detect changes. |

## How It Works

The tree builder runs as separate work manifests on your CI runner, not inline with the plan or apply. When Orchestration evaluates a pull request, it checks for a file inventory of each commit:

1. If the database already has a tree for the commit, Orchestration uses it, and no new runs are needed.
2. If not, Orchestration queues a `build-tree` run. The runner executes your script and returns the file list with the IDs.
3. Orchestration then queues a `build-config` run, which loads `.stategraph/config.yml` for that commit.
4. Orchestration stores the tree (commit SHA, paths, and IDs) in the database. Later events on that commit skip both runs.

A file is changed when its `id` differs between the feature branch tree and the destination branch tree.

### The Pull Request Run Sequence

Both branches of a pull request need a file inventory. With the tree builder and build config enabled, a new pull request where Orchestration has seen neither branch produces up to 5 runs (up to 7 with the indexer):

1. Destination branch: `build-tree` (runs your script).
2. Destination branch: `build-config` (loads `.stategraph/config.yml`).
3. Feature branch: `build-tree` (runs your script).
4. Feature branch: `build-config` (loads `.stategraph/config.yml`).
5. Feature branch: plan or apply (waits for both trees).

- The two branches build in parallel, so you see runs for both at the same time.
- In each branch, the runs are sequential: `build-tree` must finish before `build-config`.
- The plan run waits for both trees, then compares them to find the changed files.
- The destination branch builds only once. Later pull requests from other feature branches use its stored inventory, as long as the destination commit does not change.

### What You See on Your Pull Request

With the tree builder, GitHub shows more check runs on your pull request than the normal `stategraph plan`. For a pull request to `main` where Orchestration has processed neither branch, you see all of these:

| Check name | Branch | What it does |
| --- | --- | --- |
| `stategraph build-tree main` | destination | Runs your script against `main` and stores the inventory. |
| `stategraph build-config main` | destination | Loads `.stategraph/config.yml` from `main`. |
| `stategraph build-tree` | feature | Runs your script against your branch and stores the inventory. |
| `stategraph build-config` | feature | Loads `.stategraph/config.yml` from your branch. |
| `stategraph plan` | feature | Compares inventories and runs the plan. |

These checks are normal. The destination branch checks (`... main`) are there because Orchestration needs both sides of the diff. Later pull requests to the same `main` commit do not show them.

Each check run uses one runner while it runs. For runner capacity, plan up to 4 concurrent runners for the build phase of a new pull request, because destination and feature branch checks can overlap. Add your normal plan and apply runners.

On GitLab, checks are commit statuses that count toward the merge request pipeline result, so Orchestration publishes only `stategraph apply` there. The build runs show as pipelines in the project and use runners in the same way.

## Related

- [Tree builder setup](/docs/orchestration/workflows/advanced/tree-builder-setup)
- [config_builder](/docs/reference/orchestration/configuration/config-builder)
- [indexer](/docs/reference/orchestration/configuration/indexer)
- [batch_runs](/docs/reference/orchestration/configuration/batch-runs)
