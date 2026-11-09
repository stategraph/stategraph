---
title: Utility Commands
description: Use stategraph info to see your user, your tenants, and the versions, and use stategraph version to print the client and server versions.
order: 12
---


`stategraph info` and `stategraph version` show your user, your tenants, and the client and server versions.

## Commands

| Command | Description |
|---------|-------------|
| `stategraph info` | Show the current user, tenants, versions, and suggested next steps |
| `stategraph version client` | Print the client version |
| `stategraph version server` | Print the server version |

## stategraph info

`--format` sets the output format: `table` (default), `json`, or `simple`. The `table` and `simple` formats also print suggested next steps, for new users and AI agents.

```bash
stategraph info
```

### Example

```bash
stategraph info
```

```text
key       value
--------  ----------------------------------------------
User      Jane Smith (jane@example.com) [admin]
Server    2.5.7
Client    2.5.7
Tenants   1
  Tenant  production (550e8400-e29b-41d4-a716-446655440000)

--- What you can do next ---
  stategraph sql schema                  # Discover queryable tables
  stategraph query "SELECT * FROM resources"  # Browse your infrastructure
  stategraph states list --tenant ID     # List Terraform states
  stategraph gaps --tenant ID --provider aws  # Find unmanaged resources
  stategraph blast-radius ADDR --state ID     # Check impact before changes
```

`--format json` gives the user, the server version, and the tenants as one JSON object. Its `state_schema_version` is the Stategraph state schema version that the server understands. The CLI refuses to plan when it differs from its own.

## stategraph version

`version client` works offline. `version server` asks the configured server.

```bash
stategraph version client
stategraph version server
```

### Example

```bash
stategraph version client
# 2.5.7

stategraph version server
# 2.5.7
```

`stategraph --version` is the same as `version client`. In CI, run them first to check that the client and server are compatible.

## Next Steps

- [CLI Overview](/docs/cli): all commands and global options
- [User Commands](/docs/cli/user): identity and tenant membership
- [AI agents](/docs/ai): give an agent the CLI
