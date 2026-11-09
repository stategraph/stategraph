---
title: Inventory your infrastructure
description: "Use an AI agent and Stategraph SQL to list what every state manages and how the states depend on each other, from live data."
order: 1
---


Get a map of everything you run: each state, what it manages, and which states read from which. Use it to onboard to an estate you did not build, or before you plan work that crosses states.

## How Stategraph does it

Every state is in one database, so one SQL query reads all of them. Three tables answer most inventory questions:

| Table | Holds |
| --- | --- |
| `resources` | Each resource address, its type, module, and state |
| `instances` | Each instance of a resource, with its attributes as JSON |
| `hcl_refs` | Each reference in the HCL, including reads of other states' outputs |

The agent writes the queries and explains the result. The numbers come from the database, not from the agent.

## Before you begin

- [Set up your agent](/docs/ai/quickstart) with a read-only token.

## Steps

### 1. Ask for the map

```text
Using Stategraph, give me a one-screen map of our infrastructure: every state, what it
manages, how many resources, and how the states depend on each other.
```

The agent runs `stategraph states list`, then SQL over `resources`, `instances`, and `hcl_refs`:

```bash
stategraph sql query "SELECT s.name AS state, r.type, count(*) AS total FROM resources AS r INNER JOIN states AS s ON r.state_id = s.id WHERE r.mode = 'managed' GROUP BY s.name, r.type ORDER BY s.name, r.type LIMIT 1000" --format=json
stategraph sql query "SELECT s.name AS state, h.ref, count(*) AS total FROM hcl_refs AS h INNER JOIN states AS s ON h.state_id = s.id WHERE h.ref LIKE 'data.terraform_remote_state.%' GROUP BY s.name, h.ref ORDER BY s.name, h.ref LIMIT 1000" --format=json
```

Output (excerpt from the agent):

```text
acme-networking
   │
   ▼
acme-platform ───────────────┐
   │            ▲ networking │
   ▼            │            ▼
acme-data-stores ─────► acme-compute
   │                         │
   └────────► acme-monitoring ◄┘

- acme-networking is the root. A change there can reach all four other states.
- acme-monitoring is a leaf. Nothing reads it, so changes there are the lowest risk.
```

### 2. Check the counts yourself

Run the query behind the answer:

```bash
stategraph sql query "SELECT s.name AS state, count(*) AS resources FROM resources AS r INNER JOIN states AS s ON r.state_id = s.id GROUP BY s.name ORDER BY s.name LIMIT 100"
```

Output:

```text
state             resources
----------------  ---------
acme-compute      40
acme-data-stores  36
acme-monitoring   42
acme-networking   16
acme-platform     80
```

### 3. Ask the next question

The same tables answer narrower questions:

```text
Which states contain production resources, and who owns them by the Team tag?
Which outputs does acme-networking expose, and which states read each one?
Which module versions do we use for S3 buckets, across every state?
```

## Next steps

- [Check the impact of a change](/docs/ai/guides/impact-of-a-change): from the map to one resource
- [SQL queries](/docs/infrastructure-as-a-database/query/query): every table and column
- [SQL syntax](/docs/reference/sql-syntax): JSON operators and filters
