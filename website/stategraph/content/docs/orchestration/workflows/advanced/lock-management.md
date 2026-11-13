---
title: Locks and Concurrency
description: How Orchestration locks directories on apply and merge, when locks are released, how to unlock, and how to tune lock_policy per workflow.
order: 10
---


Stategraph Orchestration locks the directories and workspaces of a pull request, so that only one pull request at a time applies a change to them. Locks keep the real infrastructure consistent with the code on your default branch.

## Why locks matter

Suppose Jane and John both open pull requests that change the same Terraform resource. Without locks, both can apply, and the infrastructure no longer matches the code on `main`. With locks:

1. Jane's pull request applies and takes the lock.
2. John's apply is blocked while Jane holds the lock.
3. Jane's pull request merges, and the lock is released.
4. John plans again against the new `main`, applies, takes the lock, and merges.

## How locks work

A lock belongs to a pull request and covers a [dirspace](/docs/get-started/core-concepts): a directory and a workspace. While a pull request holds a lock, no other pull request can apply to that dirspace. By default:

- A pull request takes a lock when it applies, or when it merges without an apply. The lock covers the dirspaces that the pull request targets.
- A pull request takes the lock whether the apply succeeds or fails.
- After one dirspace of a pull request applies, the pull request holds locks on every dirspace that it targets.
- A pull request that has not applied or merged holds no lock.
- A lock is released only after a successful apply and a merge.

### Example

A pull request changes `dir1` and `dir2`, both in the `default` workspace:

1. The pull request opens.
2. `stategraph plan` runs.
3. Someone comments `stategraph apply dir:dir1`.
4. The pull request now holds locks on `(dir1, default)` and `(dir2, default)`.

## Unlocking

To remove a lock by force, comment [`stategraph unlock`](/docs/reference/orchestration/commands/unlock) on the pull request that holds it. The `unlock` rule of [access control](/docs/reference/orchestration/configuration/access-control) sets who can unlock.

!!! note "Unlock scope"
    `stategraph unlock` removes only the locks taken before the comment. A merge or an apply after the unlock takes locks again.

!!! warning "Use with care"
    `stategraph unlock` removes every lock that the pull request holds. When several pull requests comment `stategraph apply`, Orchestration runs only one apply at a time. If you unlock while an apply runs, the locks are released, and a second pull request can apply against the same resources. If both pull requests change the same resources, the second apply can have unintended results.

## Lock policies

The [`lock_policy`](/docs/reference/orchestration/configuration/lock-policy) key sets when Orchestration takes a lock. Set it at the top level for the whole repository, and on a workflow entry to override it for the directories that the workflow matches.

| Policy | Description | Recommended use |
|--------|-------------|-----------------|
| `strict` | Takes a lock on a `stategraph apply` comment or on merge. Releases it when the other action happens. | Production environments (default) |
| `apply` | Takes a lock only when the directory applies. Releases it when the change merges. | Standard apply-then-merge workflows |
| `merge` | Takes a lock only when the directory merges. Releases it when the change applies. | Development and playground branches |
| `none` | Never takes a lock. | Special cases only. Not recommended. |

To use `apply` for the whole repository and keep `strict` for production:

```yaml
lock_policy: apply

workflows:
  - tag_query: dir:production
    lock_policy: strict
```

Any value other than `strict` is less safe. Use it only where a stale infrastructure state is acceptable.

## Locks in Infrastructure as a Database

Orchestration locks are per pull request and per dirspace. Infrastructure as a Database also locks single resources in a state, so two transactions that change different resources in the same state do not conflict. See [Resource-level locking](/docs/infrastructure-as-a-database/resource-locking).

In the Enterprise edition, a dirspace that runs `engine: stategraph`, set for the whole repository or in its workflow, is not locked for other pull requests, whatever its `lock_policy`. Pull requests plan and apply it in parallel, and the rules below apply per resource rather than per directory.

- A plan never waits for another pull request.
- An apply is refused, before it starts, when its plan changes a resource that another open pull request is applying or has applied. The refusal is the comment **Overlapping applies**, which names that pull request and the conflicting resources. This holds whether your plan was made before or after the other apply: a plan made after it, from a branch that does not contain the other pull request's change, would undo that change. Your own pull request's earlier applies never refuse your later plans: fix, plan and apply again.
- The refusal lifts when the other pull request merges, when it is closed without merging, or when it is unlocked with `stategraph unlock`. Bring the base branch into yours, plan again and apply. When none of these can happen, for instance for a repository Orchestration no longer sees, an operator lists the held applies with `stategraph tx holds list` and releases one with `stategraph tx holds release` (see [Transactions](/docs/cli/transactions)).
- If the other pull request's apply fails, your plan stands: apply again. A failed apply blocks no one.
- An apply made outside Orchestration with the `stategraph` CLI (e.g., on a developer's laptop) follows the same rule: against the same state, it is rejected with a transaction conflict instead of a comment.

For example:

1. Jane's and John's pull requests both plan `(dir1, default)`.
2. Jane's pull request applies. John's pull request can still apply, during or after Jane's apply, if his plan changes none of the resources hers did. If they change the same resource, his apply is refused before it starts, and he plans again.
3. If John plans after Jane's apply, from a branch without her change, his plan undoes her resources, and his apply is refused until Jane's pull request merges. He then brings the base branch into his and plans again.
4. A pull request stacked on Jane's branch carries her change, so its plan does not undo her resources, and it applies while hers is still open as long as it changes other resources.

## Best practices

- Tell your team when you work on shared directories, so that applies do not wait for each other.
- Check long-held locks regularly. An apply that never merges blocks everyone else on that directory.
- Use `stategraph unlock` rarely, and make sure that the whole team knows what it does.
- Agree on a process to take, release, and force locks before the first conflict.

## Next steps

- [unlock command](/docs/reference/orchestration/commands/unlock)
- [lock_policy reference](/docs/reference/orchestration/configuration/lock-policy)
- [Apply after merge](/docs/orchestration/workflows/apply-after-merge)
