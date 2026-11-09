---
title: Set up your agent
description: "Set up an AI agent to work with Stategraph: install the CLI and skills, give the agent a read-only token, and allow only the stategraph CLI."
order: 2
---


Set up a coding agent so that it works on your infrastructure through Stategraph, with a read-only token and only the `stategraph` CLI allowed. Any agent that can run shell commands works. The how-to guides start from this setup.

## Before you begin

- A Stategraph server with your state in it: [Stategraph Cloud](/docs/get-started/quickstart/cloud) or [self-hosted](/docs/get-started/quickstart/self-hosted). To load state, see [Import your state](/docs/get-started/quickstart/import-state).
- A coding agent that can run shell commands, such as Claude Code, Codex, or Gemini CLI.

## 1. Install the CLI

Install it on the machine where the agent runs:

```bash
curl -sSL https://get.stategraph.com/install.sh | sh
```

Homebrew, APT, and downloads are on [CLI reference](/docs/cli).

## 2. Give the agent a token

Create a read-only token with your own API key. The agent can query everything and change nothing:

```bash
stategraph user access-tokens create --name agent-read-only \
  --capabilities-json '{"access-token-create":false,"access-token-refresh":false,"admin":[],"commit":{"modified":[],"pulled-in":[]},"preview":{"modified":[],"pulled-in":[]},"sudo":[],"users-manage":[]}'
```

Export it in the environment that starts the agent:

```bash
export STATEGRAPH_API_BASE="https://stategraph.example.com"
export STATEGRAPH_API_KEY="<read-only-token>"
export STATEGRAPH_TENANT_ID="<tenant-id>"
stategraph info
```

To let the agent plan changes too, see [Guardrails](/docs/ai/guardrails).

## 3. Install the skills

```bash
npx skills add stategraph/skills
```

The skills are `SKILL.md` files. Agents that load skills pick them up from their skills directory. For an agent that does not, point it at the files, or at the [docs for agents](/docs/ai/docs-for-agents). See [Skills](/docs/ai/skills).

## 4. Allow only the CLI

In your agent's permission settings:

- Allow commands that start with `stategraph`.
- Ask before `stategraph tf apply`, `stategraph apply`, and `stategraph states delete`.
- Allow file reads. Allow file edits only for the guides that change HCL.
- Deny other shell commands that reach your cloud, such as `terraform`, `tofu`, `aws`, and `gcloud`.

Example, Claude Code. Save `.claude/settings.json` in your Terraform repository:

```json
{
  "permissions": {
    "allow": ["Bash(stategraph:*)", "Skill", "Read", "Grep", "Glob"],
    "ask": ["Bash(stategraph tf apply:*)", "Bash(stategraph apply:*)", "Bash(stategraph states delete:*)"]
  }
}
```

## 5. Check the setup

Start the agent in the repository and ask:

```text
Using Stategraph, which states do we have, and how many resources does each one manage?
```

The agent loads the `stategraph-query` skill and runs read-only commands, such as:

```bash
stategraph states list --format=json
stategraph sql query "SELECT s.name AS state, count(*) AS resources FROM resources AS r INNER JOIN states AS s ON r.state_id = s.id GROUP BY s.name ORDER BY s.name LIMIT 100" --format=json
```

The answer lists your states and their resource counts, with the commands behind it. Run any of them yourself to check.

To check the token, ask for a plan. A read-only token is refused:

```text
Forbidden: you are not authorized for this request:
  - your access token does not include the plan capability
```

## Next steps

- [Inventory your infrastructure](/docs/ai/guides/inventory): map every state and how they depend on each other
- [Guardrails](/docs/ai/guardrails): plan-only tokens and applies that stay with a person
- [Skills](/docs/ai/skills): every skill and what it does
