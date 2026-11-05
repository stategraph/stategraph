---
title: automerge
description: Reference for the automerge key in .stategraph/config.yml. Merge the pull request automatically after every directory applies successfully.
order: 3
---


`automerge` makes Stategraph Orchestration merge the pull request after every directory in it applies successfully. If a directory fails to apply, there is no merge.

## Default Configuration

```yaml
automerge:
  enabled: false
  delete_branch: false
  merge_strategy: auto
  require_explicit_apply: false
  retain_pr_title: false
```

## Keys

| Key | Type | Description |
| --- | --- | --- |
| `enabled` | boolean | Turns on automerge. Default is `false`. |
| `delete_branch` | boolean | Deletes the source branch after a successful merge. Default is `false`. |
| `merge_strategy` | string | The merge method: `auto`, `merge`, `rebase`, or `squash`. Default is `auto`. See [Merge Strategy](#merge-strategy). |
| `require_explicit_apply` | boolean or string | `true`: automerge runs only after an apply from a comment, such as `stategraph apply` or `stategraph apply-force`, not after an autoplan. `include_layers`: also merges when a later layer of a run that an apply comment started completes the pull request. Default is `false`. See [Explicit Apply](#explicit-apply). |
| `retain_pr_title` | boolean | Uses the pull request title as the commit title. Default is `false`. See [Commit Title](#commit-title). |

Automerge does not force a merge. It respects the branch protection rules of the repository, and on GitLab the merge checks of the project. If the merge fails, Orchestration comments the reason on the pull request.

## Merge Strategy

| Value | Description |
| --- | --- |
| `auto` | On GitHub, tries a merge commit first. If the repository does not allow merge commits, it squashes. On GitLab, does a standard (non-squash) merge. This is the default. |
| `merge` | Creates a merge commit. On GitLab, does a non-squash merge. |
| `rebase` | Rebases the commits of the pull request onto the base branch. On GitLab, does a non-squash merge, the same as `merge`. |
| `squash` | Squashes all commits of the pull request into one commit. |

The repository's merge settings must allow the strategy. If they do not, the merge fails. The exception is `auto` on GitHub, which falls back to squash.

On GitLab, Orchestration only chooses whether to squash. The merge method in the project's merge request settings decides how GitLab merges.

## Explicit Apply

In a [layered run](/docs/orchestration/workflows/advanced/layered-runs), an apply comment applies the first layer, and Orchestration then plans the next layer. That plan can complete the pull request: it has no changes, or a [stack](/docs/reference/orchestration/configuration/stacks) rule with `auto_apply: true` applies it.

| Value | Pull request after the last layer |
| --- | --- |
| `true` | Stays open. Comment `stategraph apply` again to merge it. |
| `include_layers` | Merges, because an apply comment started the run. |

Use `true` to review the plans of each layer before the merge.

## Commit Title

On GitHub, a merge commit or a squash commit gets the title `Terrateam Automerge #PR_NUMBER` by default. Every automerged commit then looks almost the same in the history of the main branch.

With `retain_pr_title: true`, the title is the pull request title, followed by the number in parentheses, for example `My pull request title (#123)`. If the pull request title is not available, Orchestration uses the default title.

On GitLab, `retain_pr_title` affects only squash merges (`merge_strategy: squash`). Orchestration sets no squash commit message by default, so GitLab uses its own default message. With `retain_pr_title: true`, the squash commit message is the merge request title, with no number.

## Examples

### Enable Automerge

```yaml
automerge:
  enabled: true
```

### Enable Automerge and Delete Branch

```yaml
automerge:
  enabled: true
  delete_branch: true
```

### Enable Automerge with Squash

```yaml
automerge:
  enabled: true
  merge_strategy: squash
```

### Merge After an Apply Comment and Its Layers

```yaml
automerge:
  enabled: true
  require_explicit_apply: include_layers
```

### Retain Pull Request Title in Squash Commit

```yaml
automerge:
  enabled: true
  merge_strategy: squash
  retain_pr_title: true
```

## Stacked Pull Requests

On GitHub, Orchestration merges through the [asynchronous merge API](https://docs.github.com/en/rest/pulls/pulls), which supports [stacked pull requests](https://docs.github.com/en/pull-requests/get-started/about-stacked-prs). A merge of a stacked pull request also merges every unmerged pull request below it, as one operation. GitHub then changes the base of the pull requests above it to the stack base.

Automerge thus works on a stack. Apply the bottom pull request, and Orchestration merges it. GitHub changes the base of the next pull request, and you can then plan and apply that one.

On a GitHub Enterprise Server version without the asynchronous merge API, Orchestration uses the synchronous merge API. That API cannot merge a stacked pull request.

## Related

- [Apply after merge](/docs/orchestration/workflows/apply-after-merge)
- [apply_requirements](/docs/reference/orchestration/configuration/apply-requirements)
