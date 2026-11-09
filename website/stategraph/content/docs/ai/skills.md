---
title: Skills
description: "The Stategraph skills teach coding agents to query, plan, import, refactor, price, and secure infrastructure with the stategraph CLI."
order: 4
---


The Stategraph skills in [github.com/stategraph/skills](https://github.com/stategraph/skills) teach an agent to drive the `stategraph` CLI: the workflow for each task, the exact command form, and when to stop and ask. They work in Claude Code, in agents that use [skills.sh](https://skills.sh), and in any tool that loads `SKILL.md` files.

## Available skills

| Skill | Purpose |
| --- | --- |
| `stategraph` | Router. Detects a Stategraph task and hands it to one of the skills below. |
| `stategraph-query` | Read-only SQL queries, state summaries, inventory, blast radius, and gap analysis. |
| `stategraph-change` | `stategraph tf plan`, `stategraph tf apply`, `stategraph tf mtx`, state deletion, and the transaction lifecycle. |
| `stategraph-import` | Import `.tfstate` or HCL, and wire a Terraform repository to Stategraph. |
| `stategraph-refactor` | Refactor sessions: restructure a root module and keep every state address. |
| `stategraph-cost` | State and tenant cost, attribution, history, coverage gaps, plan-time cost, and billing sources. |
| `stategraph-security` | Security findings by severity, scan history, posture over time, and the security impact of a plan. |
| `stategraph-capabilities` | Access tokens, default capabilities, group rules, and what the current session can do. |

Most users need only the router. It loads the other skills through the agent's Skill tool.

## Install

Install them all with the [skills CLI](https://skills.sh):

```bash
npx skills add stategraph/skills
```

Or install one skill:

```bash
npx skills add stategraph/skills -s stategraph-query
```

### Manual install

Copy each skill folder to the directory that your agent loads skills from. Example, Claude Code, which loads them from `~/.claude/skills/<name>/SKILL.md`:

```bash
git clone https://github.com/stategraph/skills /tmp/stategraph-skills
cp -r /tmp/stategraph-skills/skills/* ~/.claude/skills/
rm -rf /tmp/stategraph-skills
```

For one repository only, Claude Code also loads `.claude/skills/` in that repository.

An agent without skill support can read the same files as instructions. Point it at `skills/<name>/SKILL.md` in [github.com/stategraph/skills](https://github.com/stategraph/skills).

## Requirements

- The `stategraph` CLI on your `PATH`. See [CLI reference](/docs/cli).
- `STATEGRAPH_API_BASE`, `STATEGRAPH_API_KEY`, and `STATEGRAPH_TENANT_ID` exported, so that `stategraph info` succeeds. See [Setup](/docs/infrastructure-as-a-database/setup).

## Usage

Ask a question, and the router picks the skill:

| You ask | Skill |
| --- | --- |
| "What S3 buckets do we have, across every state?" | `stategraph-query` |
| "What depends on the NAT gateway?" | `stategraph-query` |
| "Plan this change, and tell me what it costs." | `stategraph-change` |
| "Import this terraform.tfstate." | `stategraph-import` |
| "Move these resources into a module without recreating them." | `stategraph-refactor` |
| "Where does our monthly spend go?" | `stategraph-cost` |
| "Any open findings on public network access?" | `stategraph-security` |
| "Create a plan-only token for the overnight agent." | `stategraph-capabilities` |

You can also start a skill directly: `/stategraph-query`, `/stategraph-change`, `/stategraph-import`, `/stategraph-refactor`, `/stategraph-cost`, `/stategraph-security`, or `/stategraph-capabilities`.

## What the skills do on their own

- Reads run without asking: SQL queries, state summaries, blast radius, cost, and security findings.
- `stategraph tf plan` runs without asking, and the agent says that it opened a transaction.
- An apply, a state deletion, a transaction abort, an import with `--overwrite`, a scan or cost recalculation, and every token or capability change need your explicit approval in the conversation.
- The skills never run a command that waits for input. A plan is written with `--out`, and the apply reads that file.

The server still decides what the agent can do. See [Guardrails](/docs/ai/guardrails).

## Next steps

- [Set up your agent](/docs/ai/quickstart): install the skills and ask a first question
- [Guardrails](/docs/ai/guardrails): scope the agent's token
- [Check the impact of a change](/docs/ai/guides/impact-of-a-change): a how-to guide that uses the skills
