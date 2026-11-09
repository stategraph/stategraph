---
title: Review what changed
description: "Use an AI agent with the Stategraph transaction log to report what was applied, planned, refused, and aborted, with who, when, and tags."
order: 7
---


Turn the transaction log into a change report: what was applied, what was planned and left open, and what was refused or aborted. Use it after an incident, for a change review, or each morning after agents ran overnight.

## How Stategraph does it

- Every plan, apply, import, and refactor is a transaction. Nothing changes state without one.
- `stategraph tx list` returns each transaction with its status, user, times, states, plan summary, and tags.
- `stategraph tx logs list --tx <tx-id>` returns each write in one transaction.
- Tags set with `STATEGRAPH_TX_TAGS` travel with the transaction, so the work of an agent stands out from the work of the person who owns its token.

## Before you begin

- [Set up your agent](/docs/ai/quickstart) with a read-only token.
- To tell agents apart, set `STATEGRAPH_TX_TAGS` in each agent's environment, for example `{"agent":"nightly-agent"}`.

## Steps

### 1. Ask for the report

```text
What changed in our Stategraph-managed infrastructure today? Show what was applied, what was
planned and never applied, and anything that was refused or aborted, with who, when, the
state, and the transaction id. Point out which transactions carry tags.
```

The agent runs:

```bash
stategraph tx list
stategraph tx logs list --tx <tx-id>
```

Output (excerpt from the agent):

```text
Committed (written to state)
| Time                | State              | Tx id     | What changed                          |
|---------------------|--------------------|-----------|---------------------------------------|
| 15:31:15 → 15:31:21 | acme-feature-flags | 43de525c… | Plan then apply: +2.                  |
| 15:39:41 → 15:42:08 | acme-compute       | d6710a7f… | Code and state for the ECR resources, |
|                     |                    |           | including modules/ecr_repository.     |

Planned but never applied (still open)
| Created  | State              | Tx id     | Status    | Plan         |
|----------|--------------------|-----------|-----------|--------------|
| 15:30:26 | acme-feature-flags | 5477eabb… | previewed | +2 / ~0 / −0 |
The plan at 15:30 was overtaken by the apply at 15:31, so it is out of date.

Failed or aborted
| Time                | State              | Tx id     | Status  | Tags                |
|---------------------|--------------------|-----------|---------|---------------------|
| 15:28:59 → 15:30:33 | acme-data-stores   | 37f2f87f… | aborted | none                |
| 15:31:35 → 15:31:39 | acme-feature-flags | af5bbb29… | aborted | agent=nightly-agent |
```

### 2. Check one transaction yourself

```bash
stategraph tx list
```

Output (excerpt):

```json
{
  "created_by_name": "Jane Doe",
  "id": "af5bbb29-b102-4f65-8b00-4b6a2060e9ea",
  "plan_summary": { "add": 0, "change": 1, "destroy": 0 },
  "state": "aborted",
  "state_names": [ "acme-feature-flags" ],
  "tags": { "agent": "nightly-agent" }
}
```

### 3. Clean up open plans

Plans that nobody will apply stay open until they are aborted. Ask the agent to list them, then approve each abort. The agent asks before it runs `stategraph tx abort`.

## Next steps

- [Transactions](/docs/infrastructure-as-a-database/transactions): the transaction lifecycle
- [Transaction commands](/docs/cli/transactions): `tx list`, `tx logs list`, and `tx abort`
- [Guardrails](/docs/ai/guardrails): tag the agent's transactions
