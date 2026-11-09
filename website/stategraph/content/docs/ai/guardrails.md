---
title: Guardrails
description: "Scope what an agent can do with Stategraph access tokens, keep applies behind a person, and read every agent action in the transaction log."
order: 3
---


The token decides what an agent can do, not the prompt. Stategraph checks every request on the server, so a confused or manipulated agent can only do what its token allows.

## The model

<figure class="docs-figure">
<div class="docs-mock docs-flow">
<div class="docs-flow-node">You<small>prompt and approval</small></div><div class="docs-flow-node">Your agent<small>skills and allowed commands</small></div><div class="docs-flow-node accent">Stategraph<small>token capabilities</small></div><div class="docs-flow-msg c12 right"><span>1. Question or change</span></div><div class="docs-flow-msg c23 right"><span>2. stategraph commands</span></div><div class="docs-flow-msg c23 left"><span>3. Rows, plans, or Forbidden</span></div><div class="docs-flow-msg c12 left"><span>4. Answer, with the commands it ran</span></div>
</div>
<figcaption>Three checks stand between an agent and your infrastructure.<br> The skills ask before a change, the agent runs only the commands that you allow, and the server enforces the token.</figcaption>
</figure>

| Layer | Set by | Stops |
| --- | --- | --- |
| Token capabilities | You, with `stategraph user access-tokens create` | Plans and applies outside the scope, and new tokens |
| Agent permissions | You, in your agent's settings | Any command that you did not allow |
| Skills | The `SKILL.md` files | Applies, deletions, and token changes without your approval |

## Give each agent its own token

Create the token yourself, in your own shell. A token that the agent creates passes through its context.

Read-only, for questions about inventory, blast radius, cost, and security:

```bash
stategraph user access-tokens create --name agent-read-only \
  --capabilities-json '{"access-token-create":false,"access-token-refresh":false,"admin":[],"commit":{"modified":[],"pulled-in":[]},"preview":{"modified":[],"pulled-in":[]},"sudo":[],"users-manage":[]}'
```

Plan-only, limited to one state, and unable to pull in resources from other states:

```bash
stategraph user access-tokens create --name agent-data-stores-plan \
  --plan \
  --plan-modified '<state-id>=*' \
  --plan-pulled-in '<state-id>=*'
```

Narrow `--plan-modified` to an address prefix, such as `'<state-id>=module.queues.*'`, to limit the agent to one module. See [Access tokens and capabilities](/docs/admin/access-control/access-tokens) for every flag.

What the server answers when the agent goes past its token:

```text
$ stategraph tf plan                      # read-only token
Forbidden: you are not authorized for this request:
  - your access token does not include the plan capability

$ stategraph tf apply plan.json           # plan-only token
Forbidden: you are not authorized for this request:
  - your access token does not include the apply capability

$ stategraph user access-tokens create --name escalate --plan
Forbidden: you are not authorized for this request:
  - requires the access-token-create capability
```

A token never exceeds the user who created it, and an agent without `access-token-create` cannot make itself a broader one.

## Limit the commands the agent can run

Allow the `stategraph` CLI and nothing else that reaches your infrastructure. Ask before an apply. Most coding agents have an allow list for shell commands. Set it to:

- Allow commands that start with `stategraph`.
- Ask before `stategraph tf apply`, `stategraph apply`, and `stategraph states delete`.
- Deny `terraform`, `tofu`, and cloud command-line tools such as `aws` and `gcloud`, so the agent cannot go around Stategraph.

Example, Claude Code. Save this as `.claude/settings.json` in the repository:

```json
{
  "permissions": {
    "allow": ["Bash(stategraph:*)", "Skill", "Read", "Grep", "Glob"],
    "ask": ["Bash(stategraph tf apply:*)", "Bash(stategraph apply:*)", "Bash(stategraph states delete:*)"]
  }
}
```

Allow lists usually match the start of a command, so a compound command such as `env | grep STATEGRAPH; stategraph states list` is not allowed. In an unattended run it is denied. Add this to the agent's instructions to keep each call simple:

```text
Run each stategraph command as its own shell call, with no pipes, redirects, env, cd, or ';'.
```

## Keep applies behind a person

- An agent with a plan-only token writes a plan file and stops. You review the plan and run `stategraph tf apply plan.json` with your own key.
- When an agent tries the apply anyway, the server refuses it and aborts the plan's transaction. Plan again before you apply.
- In a pull request flow, the agent pushes a branch, and [Stategraph Orchestration](/docs/orchestration) plans it. Applies wait for your apply requirements: approvals, passing checks, or both.

## Read what the agent did

Every plan, apply, import, and refactor is a transaction, with its user, time, and state. A token acts as the user who created it, so tag the agent's transactions to tell them apart:

```bash
export STATEGRAPH_TX_TAGS='{"agent":"nightly-agent"}'
```

Output of `stategraph tx list` (excerpt):

```json
{
  "created_by_name": "Jane Doe",
  "id": "af5bbb29-b102-4f65-8b00-4b6a2060e9ea",
  "plan_summary": { "add": 0, "change": 1, "destroy": 0 },
  "state": "previewed",
  "state_names": [ "acme-feature-flags" ],
  "tags": { "agent": "nightly-agent" }
}
```

`stategraph tx logs list --tx <tx-id>` shows each write in a transaction. An open plan that nobody will apply can be aborted with `stategraph tx abort --tx <tx-id>`. See [Transactions](/docs/infrastructure-as-a-database/transactions).

## What reaches the model provider

The agent sends targeted commands and reads their output: the rows that a query selects, a plan, or a finding. It does not need the state file. Ask for names and flags instead of values, and secret values stay out of the conversation:

```sql
SELECT i.address, i.attributes->>'password' IS NOT NULL AS has_password FROM instances AS i WHERE i.resource_address = 'aws_db_instance.primary'
```

Run Stategraph [self-hosted](/docs/admin/self-hosting) to keep state inside your network. Only the command output that the agent reads goes to the model provider.

## Reversible and irreversible actions

| Action | Undo |
| --- | --- |
| SQL query, blast radius, cost, findings | Nothing to undo |
| `stategraph tf plan` | `stategraph tx abort`, or let it go stale |
| Refactor session before apply | `stategraph refactor abort` |
| Refactor apply (address moves only) | Another refactor session |
| `stategraph tf apply` | A new plan and apply. Destroyed resources do not come back |
| `stategraph states delete` | None |

## Next steps

- [Set up your agent](/docs/ai/quickstart): set this up from scratch
- [Run an agent on a schedule](/docs/ai/guides/unattended): overnight and CI runs with a plan-only token
- [Make a change with a plan-only agent](/docs/ai/guides/plan-a-change): refused at apply, applied by you
