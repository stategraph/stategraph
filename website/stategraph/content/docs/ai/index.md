---
title: AI agents
description: "What Stategraph gives an AI agent working on Terraform and OpenTofu, and how to use it from any coding agent safely and reliably."
order: 1
---


Stategraph stores every Terraform and OpenTofu state in one database, and exposes it through the `stategraph` CLI. A coding agent, such as Claude Code, Codex, or Gemini CLI, uses the same CLI that you do. It reads facts from Stategraph instead of guessing, proves changes with a plan, and works inside the limits of the token you give it.

<figure class="docs-figure">
<video class="docs-video" src="/assets/docs/ai/blast-radius.mp4" poster="/assets/docs/ai/blast-radius.jpg" controls muted playsinline preload="none"></video>
<figcaption>Claude Code checks what depends on a NAT gateway across every state, with the Stategraph commands behind each answer.</figcaption>
</figure>

## What Stategraph gives an agent

| Capability | What the agent does with it | Command |
| --- | --- | --- |
| SQL over every state | Answers inventory, ownership, and policy questions across all states at once | `stategraph sql query` |
| References between states | Finds which states read an output, without a search across repositories | `stategraph sql query` on `hcl_refs` |
| Blast radius | Lists everything a change to one resource can affect, before anyone edits code | `stategraph states instances blast-radius` |
| Plans in transactions | Proves a change before it happens. The plan carries its cost and security impact | `stategraph tf plan --out` |
| Refactor sessions | Moves resources into modules and keeps every state address | `stategraph refactor` |
| Cost | Ranks spend by state, resource, and tag, and prices a plan | `stategraph cost` |
| Security findings | Reads Checkov findings per state, and the security impact of a plan | `stategraph security` |
| Scoped access tokens | Limits what the agent can plan and apply. The server enforces it | `stategraph user access-tokens create` |
| Transaction log | Records each plan and apply, its user, and its tags | `stategraph tx list` |

## How the work divides

<figure class="docs-figure">
<div class="docs-mock docs-flow">
<div class="docs-flow-node">You<small>goal and approval</small></div><div class="docs-flow-node">Your agent<small>Stategraph skills</small></div><div class="docs-flow-node accent">Stategraph<small>every state, one graph</small></div><div class="docs-flow-msg c12 right"><span>1. Task</span></div><div class="docs-flow-msg c23 right"><span>2. stategraph commands</span></div><div class="docs-flow-msg c23 left"><span>3. Rows, plans, findings</span></div><div class="docs-flow-msg c12 left"><span>4. Answer or plan, with its sources</span></div>
</div>
<figcaption>Stategraph supplies the facts and enforces the token.<br> The agent turns them into an answer or a plan. You approve the apply.</figcaption>
</figure>

- Stategraph answers. Inventory, dependencies, cost, and findings come from the database, so the agent does not invent resources or miss a dependency because its context is full.
- The agent explains and edits. It writes the query, reads the result, edits HCL, and explains what the result means.
- You decide. Plans are cheap and safe to hand to an agent. Applies stay with a person, or with a token that you scoped for them.

## Work safely and reliably

- Give the agent its own token. Start read-only, and add plan rights for one state when it needs them. See [Guardrails](/docs/ai/guardrails).
- Ask for the commands. Every answer can cite the `stategraph` command behind it, and you can run it again to check.
- Let the plan be the test. A change that the agent wrote is correct when the plan says so, not when the agent says so.
- Tag the agent's transactions with `STATEGRAPH_TX_TAGS`, so its plans stand out in `stategraph tx list`.

## How-to guides

| Task | Guide |
| --- | --- |
| Find out what you run, and how the states depend on each other | [Inventory your infrastructure](/docs/ai/guides/inventory) |
| Find what a change to one resource can break | [Check the impact of a change](/docs/ai/guides/impact-of-a-change) |
| Check every state against your rules, and find secrets in state | [Audit compliance and secrets](/docs/ai/guides/compliance-audit) |
| Find where spend goes, and what a change costs | [Answer cost questions](/docs/ai/guides/cost) |
| Let an agent edit HCL and plan, and keep the apply | [Make a change with a plan-only agent](/docs/ai/guides/plan-a-change) |
| Move resources into modules without recreating them | [Refactor into modules](/docs/ai/guides/refactor) |
| Report what was applied, planned, and aborted | [Review what changed](/docs/ai/guides/what-changed) |
| Run an agent overnight or in CI | [Run an agent on a schedule](/docs/ai/guides/unattended) |

## Next steps

- [Set up your agent](/docs/ai/quickstart): the CLI, the skills, and a read-only token
- [Guardrails](/docs/ai/guardrails): read-only and plan-only tokens
- [Skills](/docs/ai/skills): what each skill does
