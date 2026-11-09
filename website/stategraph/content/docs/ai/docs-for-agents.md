---
title: Docs for agents
description: "Give an agent the Stategraph docs as Markdown: llms.txt as an index, llms-full.txt as one file, and any page as Markdown with a .md suffix."
order: 6
---


The Stategraph docs are published in formats that agents read directly. Point an agent at them when it needs a command, a flag, or a configuration key that the skills do not cover.

| URL | Content |
| --- | --- |
| [stategraph.com/llms.txt](https://stategraph.com/llms.txt) | An index of every docs page, with a one-line summary, in the [llms.txt](https://llmstxt.org) format |
| [stategraph.com/llms-full.txt](https://stategraph.com/llms-full.txt) | Every docs page as Markdown, in one file |
| `https://stategraph.com/docs/<page>.md` | One page as Markdown. Add `.md` to any docs URL |

For example, the SQL reference as Markdown:

```bash
curl -s https://stategraph.com/docs/reference/sql-syntax.md
```

## Use them in your agent

Ask the agent to read a page when a task needs it:

```text
Read https://stategraph.com/docs/admin/access-control/access-tokens.md, then create a
token that can plan acme-compute only.
```

Add the index to your repository's `CLAUDE.md`, so that every session knows where to look:

```markdown
Stategraph docs: https://stategraph.com/llms.txt (append .md to any docs URL for Markdown).
```

## Next steps

- [Skills](/docs/ai/skills): workflows that already know the commands
- [CLI reference](/docs/cli): the commands an agent runs
- [SQL syntax](/docs/reference/sql-syntax): the query language
