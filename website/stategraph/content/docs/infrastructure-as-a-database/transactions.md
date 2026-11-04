---
title: Transactions
description: Each Stategraph plan and apply runs in a transaction that goes through create, preview, a conflict check, and commit.
order: 3
---


Each `stategraph tf plan` and `stategraph tf apply` runs in a transaction. Its log records what changed, in which state, and by whom.

## Lifecycle

```text
Create -> Preview (plan) -> Commit (apply)
```

### Transaction states

| State | Description |
|-------|-------------|
| `open` | Created, changes recorded |
| `previewing` | Plan in progress |
| `previewed` | Plan ready, waits for the commit |
| `reserved` | Plan ready, held for an apply that Orchestration is about to run; overlapping transactions are rejected meanwhile |
| `committing` | Apply in progress |
| `committed` | Apply succeeded, state updated |
| `failed` | Error during the preview, or the apply did not run |
| `failed-committed` | The apply ran and failed after it wrote the state back. The state shows what the apply completed. |
| `aborted` | Cancelled by a user |

## Create

`stategraph tf plan` creates a transaction automatically. To create one by hand:

```bash
stategraph tx create --tenant <tenant-id>
```

## Preview (plan)

```bash
stategraph tf plan --out plan.json
```

Without `--out`, the preview is read-only and writes no plan file. Under the diff, the plan also shows:

- With [cost estimation](/docs/admin/self-hosting/cost), a [cost delta](/docs/infrastructure-as-a-database/cost/plan-time): current versus planned monthly cost.
- With [security scanning](/docs/infrastructure-as-a-database/security), the findings that the change adds and resolves.

Each waits up to three seconds by default. Skip them with `--skip-costs` and `--skip-security`.

The plan output masks sensitive values. Several previews can run at the same time on one state, each on an independent set of resources.

To plan several state directories in one transaction:

```bash
stategraph tf mtx --out plan.json ./networking ./compute
```

## Commit (apply)

```bash
stategraph tf apply plan.json
```

The plan file records a hash of your HCL and tfvars files. If they changed after the plan, the apply refuses to run. Plan again.

Without a plan file, `stategraph tf apply` plans, shows the diff, and asks for approval, like `terraform apply`. `--auto-approve` skips the prompt. Without it, the apply fails when stdin is not a terminal or with `--silent` (`STATEGRAPH_SILENT`):

```bash
stategraph tf apply --tenant <tenant-id> --silent --auto-approve
```

Before the apply, the server runs a [conflict check](/docs/infrastructure-as-a-database/resource-locking). If another transaction committed changes to overlapping resources after this one was created, the server rejects the commit with the conflicting transaction IDs. Run `stategraph tf plan` again and retry.

A failed apply reports the actual Terraform error, with resource addresses as in your configuration.

## Abort

Cancel a transaction before the commit completes:

```bash
stategraph tx abort --tx <tx-id>
```

## Inspect

```bash
# List transactions for a tenant
stategraph tx list --tenant <tenant-id>

# View the log of a transaction
stategraph tx logs list --tx <tx-id>

# Cost delta of a pending transaction
stategraph tx costs --tx <tx-id>
```

Commands that take `--tx` also read the transaction ID from `STATEGRAPH_TX_ID`. The console shows this history on the [Timeline](/docs/infrastructure-as-a-database/query/timeline). [Transaction commands](/docs/cli/transactions) has the full CLI reference and output formats.

## API

The CLI calls these endpoints. You can call them from your own tools. See the [API reference](/docs/reference/api/transactions).

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/v1/tenants/{tenant_id}/tx` | GET | List transactions in a tenant |
| `/api/v1/tenants/{tenant_id}/tx/create` | POST | Create a transaction |
| `/api/v1/tx/{tx_id}/preview` | POST | Start a preview (plan) |
| `/api/v1/tx/{tx_id}/commit` | POST | Commit (apply) the transaction. Returns 409 on a conflict. |
| `/api/v1/tx/{tx_id}/abort` | POST | Abort the transaction |
| `/api/v1/tx/{tx_id}/logs` | GET | Read the transaction log |
| `/api/v1/tx/{tx_id}/costs` | GET | Cost delta for the transaction |

## Next steps

- [Resource-level locking](/docs/infrastructure-as-a-database/resource-locking): how the conflict check works.
- [Multi-state transactions](/docs/infrastructure-as-a-database/multi-state): one transaction across several states.
- [Audit trail](/docs/orchestration/security/audit-trail): transactions as the record of change.
