---
title: Query (SQL)
description: Query your Terraform infrastructure with SQL. Filter resources by attribute, aggregate counts, and analyze configurations in all states.
order: 2
---


Stategraph SQL queries the data of every state that you can access. Run queries in the console, with `stategraph sql query`, or with the API at `/api/v1/mql`.

## Basic syntax

Stategraph SQL uses standard `SELECT` syntax:

```sql
SELECT columns
FROM table
WHERE conditions
ORDER BY column [ASC|DESC]
LIMIT n
```

## Tables

### instances

| Column | Type | Description |
|--------|------|-------------|
| `address` | string | Full instance address |
| `resource_address` | string | Resource address (without index) |
| `fq_address` | string | Fully-qualified instance address |
| `fq_resource_address` | string | Fully-qualified resource address |
| `attributes` | jsonb | Resource attributes |
| `dependencies` | text[] | List of dependency addresses |
| `state_id` | uuid | Parent state ID |
| `index_key` | jsonb | Instance index key (for count/for_each) |
| `status` | string | Instance status |
| `schema_version` | integer | Schema version |
| `create_before_destroy` | boolean | Lifecycle setting |
| `deposed` | string | Deposed key, if any |
| `sensitive_attributes` | jsonb | Sensitive attribute paths |
| `identity` | jsonb | Identity information |
| `identity_schema_version` | integer | Identity schema version |
| `private` | string | Private data |

To query by resource type or provider, use the `resources` table.

### states

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | State ID |
| `name` | string | State name |
| `group_id` | uuid | Group identifier |
| `workspace` | string | Workspace name |
| `tenant_id` | uuid | Tenant ID |
| `created_at` | timestamp | Creation time |
| `updated_at` | timestamp | Last update time |
| `deleted_at` | timestamp | Deletion time (if deleted) |
| `deleted_by` | uuid | User who deleted it (if deleted) |

### resources

| Column | Type | Description |
|--------|------|-------------|
| `address` | string | Resource address |
| `fq_address` | string | Fully-qualified resource address |
| `type` | string | Resource type, such as `aws_instance` |
| `name` | string | Resource name |
| `provider` | string | Provider name |
| `module` | string | Module path |
| `mode` | string | Resource mode (managed/data) |
| `state_id` | uuid | Parent state ID |

### providers

| Column | Type | Description |
|--------|------|-------------|
| `name` | string | Provider name |
| `state_id` | uuid | Parent state ID |

### outputs

| Column | Type | Description |
|--------|------|-------------|
| `address` | string | Output address |
| `name` | string | Output name |
| `value` | jsonb | Output value |
| `type` | jsonb | Output type |
| `sensitive` | boolean | Is sensitive |
| `state_id` | uuid | Parent state ID |

### transactions

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | Transaction ID |
| `state` | string | Transaction state |
| `tags` | jsonb | Transaction tags |
| `tenant_id` | uuid | Tenant ID |
| `created_at` | timestamp | Creation time |
| `created_by` | uuid | Creator user ID |
| `completed_at` | timestamp | Completion time |
| `completed_by` | uuid | Completing user ID |
| `params` | jsonb | Transaction parameters |
| `metadata` | jsonb | What the server records about the transaction for the system that drives it: `hold`, the key of its hold while one does, which Orchestration sets to the ID of the pull request whose apply committed it and releases when that pull request merges, is closed or is unlocked |

### tenants

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | Tenant ID |
| `name` | string | Tenant name |
| `created_at` | timestamp | Creation time |

### users

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | User ID |
| `name` | string | User name |
| `type` | string | User type |
| `created_at` | timestamp | Creation time |

### transaction_logs

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | Log entry ID |
| `tx_id` | uuid | Parent transaction ID |
| `action` | string | Action type, such as `state_set` |
| `object_type` | string | Type of the affected object |
| `state_id` | uuid | Related state ID |
| `user_id` | uuid | User who did the action |
| `data` | jsonb | More action data |
| `created_at` | timestamp | Action time |

### check_results

Terraform check results:

| Column | Type | Description |
|--------|------|-------------|
| `config_addr` | string | Check configuration address |
| `object_kind` | string | Kind of object checked |
| `state_id` | uuid | Parent state ID |
| `status` | string | Check status |

### check_entries

| Column | Type | Description |
|--------|------|-------------|
| `config_addr` | string | Check configuration address |
| `object_addr` | string | Checked object address |
| `state_id` | uuid | Parent state ID |
| `status` | string | Entry status |
| `failure_messages` | text[] | Failure messages, if any |

### More tables

- `cost_snapshots` and `cost_snapshot_resources`: see [Querying Cost Data](/docs/infrastructure-as-a-database/cost/queries).
- `hcl`, `hcl_refs`, `files`, `tfvars`, `transaction_subgraphs`, `revision_hashes`, and `revision_tx_hashes`.
- With Stategraph Orchestration on: GitHub and GitLab data for your tenant, such as runs, pull requests, gates, drift schedules, pull request stacks, and unlock timestamps.

`stategraph sql schema` lists all tables and columns.

## Query examples

### List all resources

```sql
SELECT * FROM instances
```

### Filter by resource type

```sql
SELECT * FROM resources
WHERE type = 'aws_instance'
```

### Count resources by type

```sql
SELECT type, COUNT(*) as type_count
FROM resources
GROUP BY type
ORDER BY COUNT(*) DESC
```

### Filter by attribute

```sql
SELECT address, attributes->>'instance_type' as instance_type
FROM instances
WHERE attributes->>'instance_type' = 't3.micro'
```

### Search by address

```sql
SELECT * FROM instances
WHERE address = 'module.database.aws_rds_cluster.main'
```

### Cross-state query

A query covers all your states. For example, list the states, then find a resource type in all of them:

```sql
SELECT id, name FROM states
```

```sql
SELECT * FROM resources
WHERE type = 'aws_rds_cluster'
```

To relate rows of different tables, use a `JOIN` on a shared column such as `state_id` (see [Cross-table queries](#cross-table-queries)).

### Module analysis

```sql
SELECT module, COUNT(*) as resources
FROM resources
WHERE module IS NOT NULL
GROUP BY module
ORDER BY resources DESC
```

## Operators

| Operator | Description | Example |
|----------|-------------|---------|
| `=` | Equal | `type = 'aws_instance'` |
| `<>` | Not equal | `type <> 'null_resource'` |
| `<` | Less than | `count(*) < 10` |
| `>` | Greater than | `count(*) > 100` |
| `<=` | Less or equal | `count(*) <= 50` |
| `>=` | Greater or equal | `count(*) >= 5` |
| `AND` | Both conditions | `type = 'aws_instance' AND module IS NOT NULL` |
| `OR` | Either condition | `type = 'aws_s3_bucket' OR type = 'aws_s3_bucket_policy'` |
| `NOT` | Negate condition | `NOT type = 'null_resource'` |
| `IN` | Value in list | `type IN ('aws_instance', 'aws_ebs_volume')` |
| `LIKE` | Case-sensitive pattern match | `type LIKE 'aws_%'` |
| `ILIKE` | Case-insensitive pattern match | `name ILIKE '%prod%'` |
| `NOT LIKE` | Negated pattern match | `type NOT LIKE 'aws_%'` |
| `IS NULL` | Is null | `module IS NULL` |
| `IS NOT NULL` | Is not null | `module IS NOT NULL` |

In patterns, `%` matches any sequence of characters and `_` matches one character.

## JSON operators

PostgreSQL-style operators read JSON attributes:

| Operator | Description | Example |
|----------|-------------|---------|
| `->` | Get JSON value | `attributes->'tags'` |
| `->>` | Get JSON as text | `attributes->>'instance_type'` |
| `#>>` | Get nested path as text | `attributes#>>'{tags,Name}'` |

### JSON path examples

Get the instance type:

```sql
SELECT address, attributes->>'instance_type' as instance_type
FROM instances
WHERE attributes->>'instance_type' IS NOT NULL
```

Get a nested tag value:

```sql
SELECT address, attributes#>>'{tags,Environment}' as env
FROM instances
```

Filter by tag:

```sql
SELECT * FROM instances
WHERE attributes->'tags'->>'Environment' = 'production'
```

### JSON contains

Find instances with specific tags:

```sql
SELECT * FROM instances
WHERE attributes->'tags' @> '{"Environment": "production"}'::jsonb
```

## Aggregations

### COUNT

Count all instances:

```sql
SELECT count(*) FROM instances
```

Count the resources of each type:

```sql
SELECT type, count(*) FROM resources GROUP BY type ORDER BY type
```

### With HAVING

```sql
SELECT type, count(*) as type_count
FROM resources
GROUP BY type
HAVING count(*) > 10
ORDER BY type
```

## Cross-table queries

Stategraph SQL supports `INNER`, `LEFT`, and `RIGHT` joins with an `ON` clause. Most tables share a `state_id`, and `instances.resource_address` matches `resources.address`.

Join instances to their resource definitions to filter by type:

```sql
SELECT i.address, r.type, r.provider
FROM instances AS i
INNER JOIN resources AS r
  ON i.resource_address = r.address
  AND i.state_id = r.state_id
WHERE r.type = 'aws_instance'
```

Count resources by type within each state:

```sql
SELECT s.name AS state, r.type, COUNT(*) AS type_count
FROM resources AS r
INNER JOIN states AS s ON r.state_id = s.id
GROUP BY s.name, r.type
ORDER BY COUNT(*) DESC
```

## Ordering and limits

### ORDER BY

```sql
SELECT * FROM instances
ORDER BY address ASC, status DESC
```

### LIMIT

```sql
SELECT * FROM instances
LIMIT 100
```

Without a `LIMIT`, a query returns at most 20 rows. The maximum `LIMIT` is 1000 rows. Add a `LIMIT` for a predictable result size, and when you explore large datasets.

## Common patterns

### AWS resources by type

```sql
SELECT type, COUNT(*) as type_count
FROM resources
WHERE type IN ('aws_instance', 'aws_s3_bucket', 'aws_lambda_function', 'aws_rds_cluster')
GROUP BY type
ORDER BY COUNT(*) DESC
```

### Find untagged resources

```sql
SELECT address, resource_address
FROM instances
WHERE attributes->'tags' IS NULL
   OR attributes->>'tags' = '{}'
```

### Resources by state

```sql
SELECT state_id, COUNT(*) as resources
FROM instances
GROUP BY state_id
```

### Security groups

```sql
SELECT address, attributes->>'name' as name
FROM instances
WHERE resource_address = 'aws_security_group.main'
```

## Tips

- Select only the columns that you need, for faster queries.
- Filters on `type` and `address` use an index and are fast.
- Build complex queries step by step.

## Error messages

| Error | Cause | Solution |
|-------|-------|----------|
| `QUERY_ERR` | Invalid SQL syntax | Check the query structure |
| `UNKNOWN_COLUMN_ERR` | The column does not exist | Check the column names |
| `TYPE_MISMATCH_ERR` | Wrong data type in a comparison | Cast the values |

## Next steps

- [Instances](/docs/infrastructure-as-a-database/query/instances): browse resource instances.
- [SQL Syntax Reference](/docs/reference/sql-syntax): complete grammar reference.
- [API Reference](/docs/reference/api/queries): query through the API.
