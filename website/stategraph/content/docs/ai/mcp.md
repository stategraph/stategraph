---
title: Connect over MCP
description: "Connect an AI agent to the Stategraph MCP server with a URL and an API token: query infrastructure, follow pull request runs, and search the docs with no local CLI."
order: 5
---


The Stategraph server answers the Model Context Protocol (MCP) at `/api/v1/mcp`. An agent connects with the URL of your server and a Stategraph API token, with no CLI on its machine. It can query your infrastructure, follow the Orchestration runs of a pull request, and search the docs of your server's version.

The MCP server is part of Stategraph Enterprise.

## What the agent can do

Each tool reads through the Stategraph API with the token of the agent, so the agent reads only what the user of that token can read. No tool changes anything.

| Tool | Returns |
| --- | --- |
| `search_docs`, `get_doc` | Docs pages for a question, with the URL to cite, from the docs of your server's version |
| `whoami` | The user of the token and its tenants |
| `sql_schema`, `query` | The SQL tables, and the rows of one read-only [SQL query](/docs/reference/sql-syntax) |
| `list_states` | The states of a tenant |
| `blast_radius` | The instances that depend on an instance |
| `get_transaction` | A transaction and its planned operations |
| `list_pull_request_runs` | The runs of a pull request, and the dirspaces that passed and failed in each |
| `get_run` | The dirspace results and steps of a run, failures first |
| `get_step_output` | The plan or log text of one step |
| `pull_request_locks` | The dirspace locks of a repository, and the pull request that holds each |
| `pull_request_gates` | The gates of a pull request and their approvals |

Sensitive values are masked: the values of sensitive attributes, outputs, and variables come back as `__SENSITIVE__`.

## 1. Give the agent its own identity

Create a service account in the tenant the agent works in, on **Settings > API Keys**, under **Service Accounts**. See [Service accounts](/docs/admin/access-control/local-authentication#service-accounts-api-users). The calls of the agent then carry its own name, and you revoke its token without touching any other token.

To limit what the token can reach, see [Guardrails](/docs/ai/guardrails).

## 2. Connect the agent

Replace `https://stategraph.example.com` with the URL of your server, and export the token as `STATEGRAPH_API_KEY`.

### Claude Code

```bash
claude mcp add --transport http stategraph https://stategraph.example.com/api/v1/mcp \
  --header "Authorization: Bearer $STATEGRAPH_API_KEY"
```

To share the server with your team, save `.mcp.json` in the repository:

```json
{
  "mcpServers": {
    "stategraph": {
      "type": "http",
      "url": "https://stategraph.example.com/api/v1/mcp",
      "headers": { "Authorization": "Bearer ${STATEGRAPH_API_KEY}" }
    }
  }
}
```

### Cursor

Save `.cursor/mcp.json` in the repository, or `~/.cursor/mcp.json` for every project:

```json
{
  "mcpServers": {
    "stategraph": {
      "url": "https://stategraph.example.com/api/v1/mcp",
      "headers": { "Authorization": "Bearer ${env:STATEGRAPH_API_KEY}" }
    }
  }
}
```

### Claude Desktop

Claude Desktop connects through the `mcp-remote` bridge, in `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "stategraph": {
      "command": "npx",
      "args": [
        "-y", "mcp-remote", "https://stategraph.example.com/api/v1/mcp",
        "--header", "Authorization:${STATEGRAPH_AUTH}"
      ],
      "env": { "STATEGRAPH_AUTH": "Bearer <token>" }
    }
  }
}
```

## 3. Check the connection

Ask the agent:

```text
Using the Stategraph MCP server, which states do we have, and what does the pull request I am working on plan?
```

## Configuration

Set these on the Stategraph server:

| Variable | Default | Meaning |
| --- | --- | --- |
| `STATEGRAPH_MCP_ENABLED` | `true` | Any value other than `true` or `1` turns the MCP server off. `/api/v1/mcp` then returns 404. |
| `STATEGRAPH_MCP_DOCS_URL` | The docs of your server's version | The docs that `search_docs` reads, over `https` or `file://`. `https://stategraph.com/llms-full.txt` gives the docs of the newest release. Empty turns the docs tools off. |

The Orchestration tools read the Orchestration tables, so they need Orchestration turned on.

The server accepts requests with no `Origin` header, which is what coding agents send, or with the origin of `STATEGRAPH_UI_BASE`. It refuses a request from any other origin.

## Next steps

- [Guardrails](/docs/ai/guardrails): limit what the token of an agent can do
- [Docs for agents](/docs/ai/docs-for-agents): the docs as Markdown for agents without MCP
