---
title: Run an agent on a schedule
description: "Run an AI agent headless on a schedule or in CI with a plan-only Stategraph token, a list of allowed commands, and a transcript of every call."
order: 8
---


A headless agent can audit compliance, answer inventory questions, or prepare a plan overnight. Give it a plan-only token and a short list of allowed commands, and the worst result of a mistake is a plan that you discard.

## What the run needs

Any coding agent with a non-interactive mode works. Set up the run so that:

- The agent uses its own Stategraph token, read-only or plan-only, from the secret store of your scheduler.
- The agent can run `stategraph` commands and nothing else that reaches your infrastructure.
- A command that is not allowed is denied at once. Nobody is there to answer a prompt.
- The run writes a transcript of every command and its output, for review afterwards.
- The agent's transactions carry a tag, so they stand out in `stategraph tx list`.

## 1. Create the token

Create it with your own key, scoped to the states the job may plan:

```bash
stategraph user access-tokens create --name nightly-agent \
  --plan \
  --plan-modified '<state-id>=*' \
  --plan-pulled-in '<state-id>=*' \
  --format json
```

Store the token in the secret store of your scheduler or CI system as `STATEGRAPH_API_KEY`. For a read-only job, create a token with no capabilities. See [Guardrails](/docs/ai/guardrails).

## 2. Set the environment

```bash
export STATEGRAPH_API_BASE="https://stategraph.example.com"
export STATEGRAPH_TENANT_ID="<tenant-id>"
export STATEGRAPH_NON_INTERACTIVE=1
export STATEGRAPH_TX_TAGS='{"agent":"nightly-agent"}'
```

## 3. Run the agent headless

Give the agent the task, the allowed commands, and this instruction, so that each command matches the allow list:

```text
Run each stategraph command as its own shell call, with no pipes, redirects, env, cd, or ';'.
The environment is already configured.
```

Example, Claude Code:

```bash
claude -p "Run a compliance check over all our states with Stategraph. Report S3 buckets without versioning, security groups open to 0.0.0.0/0, and the most common scanner findings." \
  --permission-mode dontAsk \
  --allowedTools "Bash(stategraph:*)" "Skill" "Read" "Grep" "Glob" \
  --append-system-prompt "Run each stategraph command as its own shell call, with no pipes, redirects, env, cd, or ';'. The environment is already configured." \
  --output-format stream-json --verbose > transcript.jsonl
```

- `--permission-mode dontAsk` denies every tool that is not in `--allowedTools`, with no prompt to wait on.
- `--allowedTools "Bash(stategraph:*)"` allows the `stategraph` CLI and no other shell command.
- `--output-format stream-json` records every command and its output.

To let the job edit HCL and plan, allow file edits too. The token still stops it at apply:

```text
Forbidden: you are not authorized for this request:
  - your access token does not include the apply capability
```

## 4. Review what it did

The transcript holds each command. Stategraph holds each transaction, with the job's tag:

```bash
stategraph tx list
stategraph tx logs list --tx <tx-id>
```

An open plan from the job stays in the `previewed` state until a person applies it with their own key, or aborts it:

```bash
stategraph tf apply plan.json
stategraph tx abort --tx <tx-id>
```

## In pull requests

For an agent that reviews plans in pull requests, run it as an Orchestration hook. See [AI integrations](/docs/orchestration/external-tools/ai-integrations).

## Next steps

- [Guardrails](/docs/ai/guardrails): token scopes and what the server refuses
- [Make a change with a plan-only agent](/docs/ai/guides/plan-a-change): the same flow with a person at the keyboard
- [Access tokens and capabilities](/docs/admin/access-control/access-tokens): every capability flag
