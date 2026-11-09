---
title: Make a change with a plan-only agent
description: "Let an AI agent edit HCL and plan with Stategraph, read the cost and security impact, and keep the apply with a person through a plan-only token."
order: 5
---


Let an agent do the work of a change, from the edit to the plan and its impact, while the apply stays with you. A plan-only token makes that a rule the server enforces, not a request in the prompt.

<figure class="docs-figure">
<video class="docs-video" src="/assets/docs/ai/plan-a-change.mp4" poster="/assets/docs/ai/plan-a-change.jpg" controls muted playsinline preload="none"></video>
<figcaption>Claude Code resizes a database replica, plans it, reads cost and security impact, and is refused at apply.</figcaption>
</figure>

## How Stategraph does it

- `stategraph tf plan --out plan.json` runs the plan in a transaction. Stategraph detects conflicts per resource, not per state, so the agent's plan does not block other work on the same state.
- Cost and security impact attach to the plan's transaction. The agent reads them with `stategraph tx costs` and `stategraph security impact`.
- The token's capabilities are checked on the server. A plan-only token can plan the states it names, and every apply is refused.
- The plan file is the handoff. You review it and apply it with your own key.

## Before you begin

- [Set up your agent](/docs/ai/quickstart).
- The ID of the state to change: `stategraph states resolve --name <state-name>`.
- Allow the agent to edit files, so it can change HCL.

## Steps

### 1. Create a plan-only token for the state

```bash
stategraph user access-tokens create --name agent-data-stores-plan \
  --plan \
  --plan-modified '<state-id>=*' \
  --plan-pulled-in '<state-id>=*'
```

`--plan-pulled-in` keeps the plan from reaching into other states. Start the agent with this token as `STATEGRAPH_API_KEY`.

### 2. Ask for the change

```text
aws_db_instance.replica_1 in acme-data-stores is oversized. Change it to db.r6g.large, plan it
with Stategraph, and tell me exactly what the plan changes and what it does to cost and security.
```

The agent edits `instance_class` in `rds.tf`, then:

```bash
stategraph tf plan --out plan.json --detailed-exitcode
stategraph tx costs --tx <tx-id>
stategraph security impact summary --tx <tx-id>
```

Output (excerpt from the agent):

```text
~ aws_db_instance.replica_1  (id db-5492CA6B)
    instance_class = "db.r6g.xlarge" -> "db.r6g.large"
Plan: 0 to add, 1 to change, 0 to destroy.

It's an in-place update, so the instance isn't replaced, and no other resource is touched.

Cost: -$164.25/mo. replica_1 drops from $328.50/mo to $164.25/mo.
Security: no critical, high, medium or low findings are added.

On real AWS: with no apply_immediately set, the resize waits for the next maintenance
window, and it briefly takes replica_1 offline.
```

### 3. Review and apply the plan yourself

Read the plan, then apply the same file with your own key:

```bash
stategraph tf apply plan.json
```

If the agent tries the apply, the server refuses it:

```text
Forbidden: you are not authorized for this request:
  - your access token does not include the apply capability
```

A refused apply aborts the plan's transaction. Plan again, then apply.

## Next steps

- [Guardrails](/docs/ai/guardrails): token scopes and the apply handoff
- [Check the impact of a change](/docs/ai/guides/impact-of-a-change): before the edit
- [Run an agent on a schedule](/docs/ai/guides/unattended): the same flow overnight
