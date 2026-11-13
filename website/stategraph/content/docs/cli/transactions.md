---
title: Transactions Commands
description: Use the stategraph tx commands to create, list, and abort Stategraph transactions, to see their cost previews and their logs, and to release their holds.
order: 3
---


The `stategraph tx` commands create, list, and abort transactions, show their cost previews and logs, and release their holds. A transaction records a change to your infrastructure and gives an audit trail. See [Transactions](/docs/infrastructure-as-a-database/transactions) for the model.

## Commands

| Command | Description |
|---------|-------------|
| `stategraph tx create` | Create a transaction |
| `stategraph tx create-with-session` | Create a transaction and a session token for it |
| `stategraph tx list` | List the transactions of a tenant |
| `stategraph tx costs` | Show the cost delta (current and planned) of a pending transaction |
| `stategraph tx abort` | Abort an active transaction |
| `stategraph tx logs list` | List the logs of a transaction |
| `stategraph tx holds list` | List the held applies: applied transactions whose hold is not released |
| `stategraph tx holds release` | Release the hold of an applied transaction |

Common options:

- `--tenant` takes a tenant ID and `--tx` takes a transaction ID. Both are UUIDs.
- `create`, `create-with-session`, and `list` require `--tenant`. The other commands require `--tx`.
- You can set `STATEGRAPH_TX_ID` in place of `--tx`.
- `create` and `create-with-session` take `--tag` (`key=value`, repeatable) and `--tags` (a JSON object).

## stategraph tx create

```bash
stategraph tx create --tenant <tenant-id> [options]
```

### Example

```bash
stategraph tx create \
  --tenant 550e8400-e29b-41d4-a716-446655440000 \
  --tag pipeline=github-actions \
  --tag commit=abc123
```

Output (JSON):

```json
{
  "id": "...",
  "created_at": "2024-01-15T10:30:00Z",
  "created_by": "7cc3cdab-c634-4b7b-9523-ef7fd7013d87",
  "state": "open",
  "params": {},
  "tags": {
    "pipeline": "github-actions",
    "commit": "abc123"
  }
}
```

`completed_at` and `completed_by` appear only after a commit or an abort.

## stategraph tx create-with-session

Use it in pipelines to scope operations to one transaction.

```bash
stategraph tx create-with-session --tenant <tenant-id> [options]
```

### Example

```bash
stategraph tx create-with-session \
  --tenant 550e8400-e29b-41d4-a716-446655440000 \
  --tag pipeline=terraform-ci
```

Output (session token):

```text
eyJhbGciOiJIUzI1NiIs...
```

Use the token as a Bearer token in direct API calls, or as `STATEGRAPH_API_KEY` for the CLI.

## stategraph tx list

```bash
stategraph tx list --tenant <tenant-id>
```

### Example

```bash
stategraph tx list --tenant 550e8400-e29b-41d4-a716-446655440000
```

Output (JSON):

```json
{
  "results": [
    {
      "id": "...",
      "created_at": "2024-01-15T10:30:00Z",
      "created_by": "7cc3cdab-c634-4b7b-9523-ef7fd7013d87",
      "completed_at": "2024-01-15T10:30:05Z",
      "completed_by": "7cc3cdab-c634-4b7b-9523-ef7fd7013d87",
      "state": "committed",
      "params": {},
      "tags": {
        "pipeline": "github-actions"
      }
    }
  ]
}
```

## stategraph tx costs

Only transactions from `stategraph tf plan` or `stategraph tf mtx` have a cost preview.

```bash
stategraph tx costs --tx <transaction-id>
```

### Example

```bash
stategraph tx costs --tx 550e8400-e29b-41d4-a716-446655440000
```

Output:

```text
Costs:
  Totals:
    Monthly:  130.82 USD → 140.16 USD   (+9.34 USD)
    Hourly:   0.18 USD → 0.19 USD   (+0.01 USD)
    Resources: 12 → 13 (+1)
    Coverage: 100.0% (unchanged)
  Per state:
    networking: +9.34/mo  (resources +1)
      + aws_nat_gateway.main                                +9.34
```

`stategraph tf plan` prints the same `Costs:` block. Use `tx costs` when that preview was not ready, or later. To read the delta, see [Plan-time cost](/docs/infrastructure-as-a-database/cost/plan-time).

## stategraph tx abort

```bash
stategraph tx abort --tx <transaction-id>
```

### Example

```bash
stategraph tx abort --tx 550e8400-e29b-41d4-a716-446655440000
```

## stategraph tx logs list

```bash
stategraph tx logs list --tx <transaction-id>
```

### Example

```bash
stategraph tx logs list --tx 550e8400-e29b-41d4-a716-446655440000
```

## stategraph tx holds list

```bash
stategraph tx holds list [--format json|table|simple]
```

An applied transaction may be held: an apply run by Orchestration leaves a hold on the transaction it applied until its pull request merges, is closed or is unlocked, so that no other pull request reverts the change meanwhile. An apply that overlaps a held one is refused until the hold is released. See [Lock management](/docs/orchestration/workflows/advanced/lock-management). This command lists the held applies of your tenants, with the key of each hold.

### Example

```bash
stategraph tx holds list
```

## stategraph tx holds release

```bash
stategraph tx holds release --tx <transaction-id>
```

Releases the hold of an applied transaction. Orchestration releases the holds of a pull request itself when it merges, is closed or is unlocked; this command is the way out when it cannot, for a repository it no longer sees, or when a release failed. A no-op on a transaction without a hold.

### Example

```bash
stategraph tx holds release --tx 550e8400-e29b-41d4-a716-446655440000
```

Output (JSON):

```json
{
  "results": [
    {
      "id": "...",
      "action": "state_set",
      "object_type": "instance",
      "created_at": "2024-01-15T10:30:00Z",
      "state_id": "...",
      "user_id": "...",
      "data": { ... }
    }
  ]
}
```

## Transaction States

| State | Description |
|-------|-------------|
| `open` | Created. Changes are recorded. |
| `previewing` | Plan in progress |
| `previewed` | Plan ready for review |
| `committing` | Apply in progress |
| `committed` | The apply succeeded and the state is updated |
| `failed` | The preview failed |
| `failed-committed` | The apply failed after committing started |
| `aborted` | Cancelled by a user |

## Next Steps

- [Transactions](/docs/infrastructure-as-a-database/transactions): the transaction model
- [States](/docs/cli/states): state management
- [Timeline](/docs/infrastructure-as-a-database/query/timeline): see transactions in the console
