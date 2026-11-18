---
title: SQL Syntax Reference
description: Read the grammar of Stategraph SQL, the subset of SQL that queries your infrastructure: clauses, operators, functions, and row limits.
order: 3
---


Stategraph SQL is the subset of SQL that queries your infrastructure in Stategraph. This page gives its grammar, operators, functions, row limits, and errors. For a guided introduction, see [Query](/docs/infrastructure-as-a-database/query/query). For the command, see [SQL commands](/docs/cli/sql).

## Grammar Overview

```text
query     := [WITH cte [, cte ...]] select [UNION [ALL] select ...] [ORDER BY order_exprs] [LIMIT n]
cte       := name AS [MATERIALIZED] (query)
select    := SELECT select_list FROM from_item [, from_item ...] [join ...] [WHERE expr] [GROUP BY exprs [HAVING expr]]
from_item := table [AS alias] | unnest(expr) AS alias
join      := {INNER | LEFT | RIGHT} JOIN table [AS alias] ON expr
```

Each query needs a `FROM` clause: `SELECT 1` with no table is a parse error. Select scalar values from one of the [available tables](#available-tables) too.

`ORDER BY` and `LIMIT` come after the last `UNION` term and apply to the whole result. To sort or limit one term, put that term in parentheses. `HAVING` needs `GROUP BY`. `LIMIT` takes an integer, not an expression.

## SELECT Statement

### Basic Syntax

```sql
SELECT columns FROM table
```

### Select All Columns

```sql
SELECT * FROM instances
```

### Select Specific Columns

```sql
SELECT address, type, provider FROM resources
```

### Column Aliases

```sql
SELECT address AS resource_address, type AS resource_type FROM resources
```

`AS` is required: `SELECT address a` is a parse error.

## FROM Clause

### Single Table

```sql
SELECT * FROM instances
```

### Table Aliases

Alias a table with `AS`, then qualify columns with the alias. `AS` is required here too:

```sql
SELECT r.type, r.provider FROM resources AS r
```

### JOINs

Combine tables with `INNER JOIN`, `LEFT JOIN`, or `RIGHT JOIN`, and match rows with `ON`:

```sql
SELECT i.address, r.type
FROM instances AS i
INNER JOIN resources AS r
  ON i.resource_address = r.address
  AND i.state_id = r.state_id
WHERE r.type = 'aws_instance'
```

A query can have more than one join. Write the join type: `JOIN` alone, `LEFT OUTER JOIN`, `FULL JOIN`, and `CROSS JOIN` are parse errors.

### Available Tables

| Table | Description |
|-------|-------------|
| `instances` | Resource instances: attributes, dependencies, state |
| `resources` | Resource definitions: type, provider, module |
| `states` | Terraform states |
| `providers` | Providers |
| `outputs` | State outputs |
| `transactions` | Transaction history |
| `transaction_logs` | Transaction log entries |
| `tenants` | Tenants |
| `users` | Users |
| `check_results` | Check results |
| `check_entries` | Check entries |
| `cost_snapshots` | Cost snapshot summaries. See [Cost](/docs/infrastructure-as-a-database/cost) |
| `cost_snapshot_resources` | Per-resource cost breakdown |
| `focus_billing_sources` | FOCUS billing sources for cost |
| `security_scans`, `security_scan_findings` | Security scans and their findings |
| `hcl`, `hcl_refs` | Stored HCL blocks and the references between them |
| `files`, `tfvars` | Data files and variable definitions of a state, with ephemeral tfvar values masked |
| `transaction_plan_operations`, `transaction_output_chunks` | Per-resource plan operations and apply output of transactions |
| `transaction_subgraphs`, `revision_hashes`, `revision_tx_hashes` | Transaction and revision bookkeeping |
| `github_pull_requests`, `gitlab_pull_requests`, `pull_request_stacks`, `plans`, `gates`, `gate_approvals`, `drift_schedules`, `github_work_manifests`, `gitlab_work_manifests`, `work_manifest_results`, `github_pull_request_latest_unlocks`, `gitlab_pull_request_latest_unlocks`, … | Orchestration data for GitHub and GitLab of your tenant: runs, pull requests, stacks, gates, and drift schedules. Present when [Orchestration is on](/docs/admin/self-hosting/orchestration) |

For the full list of tables and columns, run `stategraph sql schema`, or see [Query](/docs/infrastructure-as-a-database/query/query).

## WHERE Clause

### Basic Filtering

```sql
SELECT * FROM resources WHERE type = 'aws_instance'
```

### Multiple Conditions

```sql
SELECT * FROM resources
WHERE type = 'aws_instance'
  AND provider LIKE '%hashicorp/aws%'
```

## Expressions

### Literals

| Type | Examples |
|------|----------|
| String | `'hello'`, `'aws_instance'`, `'it''s'` |
| Integer | `42`, `-1`, `0` |
| Float | `3.14`, `-0.5`, `1e3` |
| Boolean | `true`, `false` |
| Null | `null` |

### Identifiers

Table and column names are lowercase and case-sensitive: `ADDRESS` is an unknown column. Quoted names, such as `"address"`, are not supported. Qualify a column with its table name or alias:

```sql
SELECT instances.address, status FROM instances
```

### Operators

| Operator | Description | Example |
|----------|-------------|---------|
| `=` | Equal | `type = 'aws_instance'` |
| `<>` | Not equal | `type <> 'null_resource'` |
| `<` | Less than | `cardinality(dependencies) < 10` |
| `>` | Greater than | `cardinality(dependencies) > 100` |
| `<=` | Less or equal | `cardinality(dependencies) <= 50` |
| `>=` | Greater or equal | `cardinality(dependencies) >= 5` |
| `AND` | Logical AND | `type = 'aws_instance' AND module IS NULL` |
| `OR` | Logical OR | `type = 'aws_instance' OR type = 'aws_eip'` |
| `NOT` | Logical NOT | `NOT (type = 'null_resource')` |
| `+` | Addition | `(attributes->>'volume_size')::integer + 10` |
| `-` | Subtraction | `cardinality(dependencies) - 1` |
| `*` | Multiplication | `(attributes->>'volume_size')::integer * 2` |
| `/` | Division | `monthly_cost::real / 30` |
| `-` (unary) | Negation | `-cardinality(dependencies)` |
| `\|\|` | String concatenation | `'hello' \|\| ' world'` |

`!=` and `%` are not supported. Use `<>` for not equal.

### NULL Handling

| Expression | Description |
|------------|-------------|
| `IS NULL` | Value is null |
| `IS NOT NULL` | Value is not null |
| `IS DISTINCT FROM` | NULL-safe not equal |
| `IS NOT DISTINCT FROM` | NULL-safe equal |

Resources in the root module:

```sql
SELECT * FROM resources WHERE module IS NULL
```

Resources in modules:

```sql
SELECT * FROM resources WHERE module IS NOT NULL
```

### Pattern Matching

#### IN

```sql
SELECT * FROM resources
WHERE type IN ('aws_instance', 'aws_ebs_volume', 'aws_eip')
```

#### LIKE / ILIKE

`LIKE` is case-sensitive, and `ILIKE` is not. `%` matches any sequence of characters, and `_` matches one character. `NOT LIKE` and `NOT ILIKE` negate the match.

Types that start with `aws_`:

```sql
SELECT * FROM resources WHERE type LIKE 'aws_%'
```

Case-insensitive substring:

```sql
SELECT * FROM resources WHERE name ILIKE '%prod%'
```

Negated match:

```sql
SELECT * FROM resources WHERE type NOT LIKE 'null_%'
```

### Type Casting

A column to text:

```sql
SELECT state_id::text FROM instances
```

A JSON value to a number:

```sql
SELECT (attributes->>'volume_size')::integer FROM instances
```

The syntax is `expression::type`. The target types are `text`, `integer`, `bigint`, `smallint`, `real`, `boolean`/`bool`, `jsonb`, `timestamptz`, and `uuid`, in lowercase. A cast to another type, such as `numeric` or `interval`, returns `CAST_ERR`. `CAST(expression AS type)` is not supported.

## JSON Operators

These operators read JSON columns, such as `attributes`.

### Arrow Operators

| Operator | Description | Returns |
|----------|-------------|---------|
| `->` | Get JSON value | JSON |
| `->>` | Get JSON as text | Text |
| `#>>` | Get nested path as text | Text |

The path of `#>>` is a string literal, such as `'{tags,Name}'`. `#>` is not supported.

### Examples

`->`:

```sql
SELECT attributes->'tags' FROM instances
```

`->>`:

```sql
SELECT attributes->>'instance_type' FROM instances
```

`#>>`:

```sql
SELECT attributes#>>'{tags,Name}' FROM instances
```

### JSON Contains

`@>` checks that a JSON value contains another. Cast the JSON literal on the right to `::jsonb`:

```sql
SELECT * FROM instances
WHERE attributes->'tags' @> '{"Environment": "production"}'::jsonb
```

## Aggregation

### COUNT

All instances:

```sql
SELECT COUNT(*) FROM instances
```

All resources:

```sql
SELECT COUNT(*) FROM resources
```

### GROUP BY

The alias cannot be `count`, a reserved keyword. Use another alias, such as `total`:

```sql
SELECT type, COUNT(*) AS total
FROM resources
GROUP BY type
```

### HAVING

```sql
SELECT type, COUNT(*) AS total
FROM resources
GROUP BY type
HAVING COUNT(*) > 10
```

## Ordering

### ORDER BY

Ascending, the default:

```sql
SELECT * FROM resources ORDER BY type
```

Ascending, explicit:

```sql
SELECT * FROM resources ORDER BY type ASC
```

Descending:

```sql
SELECT * FROM resources ORDER BY type DESC
```

### Multiple Columns

```sql
SELECT * FROM resources ORDER BY type ASC, address DESC
```

## Limiting Results

### LIMIT

```sql
SELECT * FROM instances LIMIT 100
```

- Without a `LIMIT`, a query returns at most 20 rows: the default limit.
- An explicit `LIMIT` is capped at 1000 rows: the maximum.
- Over the API, the `mql-default-limit-applied` response header marks a result that the default limit truncated. See [API reference](/docs/reference/api).
- `stategraph sql schema --format json` and `GET /api/v1/mql/schema` report the two values as `default_limit` and `max_limit`.

For a predictable result size, always add a `LIMIT`.

## Common Table Expressions (CTEs)

### WITH Clause

```sql
WITH aws_resources AS (
  SELECT * FROM resources WHERE provider LIKE '%hashicorp/aws%'
)
SELECT type, COUNT(*) FROM aws_resources GROUP BY type
```

### Multiple CTEs

```sql
WITH
  aws AS (SELECT * FROM resources WHERE provider LIKE '%hashicorp/aws%'),
  gcp AS (SELECT * FROM resources WHERE provider LIKE '%hashicorp/google%')
SELECT 'aws' AS cloud, COUNT(*) FROM aws
UNION
SELECT 'gcp' AS cloud, COUNT(*) FROM gcp
```

## Functions

### Built-in Functions

!!! note "Function names are lowercase"
    Function names are case-sensitive and must be lowercase.

| Function | Description | Example |
|----------|-------------|---------|
| `count(*)` | Count rows | `count(*)` |
| `sum(expr)` | Sum values | `sum((attributes->>'volume_size')::integer)` |
| `avg(expr)` | Average values | `avg((attributes->>'volume_size')::integer)` |
| `nullif(a, b)` | Return null if a = b | `nullif(module, '')` |
| `to_char(expr, fmt)` | Format as string | `to_char(created_at, 'YYYY-MM-DD')` |
| `json_build_object(...)` | Build JSON object | `json_build_object('key', value)` |

The allowed functions are below. Any other function returns `FUNC_ACCESS_ERR`.

| Kind | Functions |
|------|-----------|
| Conditional | `coalesce`, `nullif`, `greatest`, `least` |
| Aggregate | `count(*)`, `sum`, `avg`, `min`, `max`, `bool_and`, `bool_or`, `string_agg`, `array_agg`, `json_agg`, `jsonb_agg` |
| String | `lower`, `upper`, `length`, `trim`, `ltrim`, `rtrim`, `substr`, `replace`, `split_part`, `strpos`, `starts_with`, `concat`, `concat_ws`, `regexp_replace`, `to_char` |
| Numeric | `abs`, `ceil`, `floor`, `round`, `trunc` |
| JSON | `to_jsonb`, `json_build_object`, `jsonb_build_object`, `json_build_array`, `jsonb_build_array`, `json_array_length`, `jsonb_array_length`, `json_typeof`, `jsonb_typeof`, `jsonb_extract_path_text`, `jsonb_pretty` |
| Array | `array_length`, `cardinality`, `array_to_string` |
| Date and time | `now`, `date_trunc`, `date_part`, `age` |

## Operator Precedence

From highest (binds tightest) to lowest:

1. `.` (field access), `[]` (index)
2. `::` (type cast)
3. `-` (unary negation), `NOT`
4. `->`, `->>`, `#>>` (JSON)
5. `\|\|` (concatenation)
6. `*`, `/`
7. `+`, `-`
8. `=`, `<>`, `<`, `>`, `<=`, `>=`, `@>`, `IS`, `IS NOT`, `IS DISTINCT FROM`, `IS NOT DISTINCT FROM`, `IN`, `LIKE`, `ILIKE`, `NOT LIKE`, `NOT ILIKE`
9. `AND`
10. `OR`

`NOT` binds tighter than a comparison, so put the condition after `NOT` in parentheses: `NOT (type = 'null_resource')`.

Use parentheses to change the order, or when you are not sure:

```sql
SELECT * FROM resources WHERE (type = 'aws_instance' OR type = 'aws_eip') AND module IS NULL
```

## Unsupported Constructs

These constructs return an error:

- `CASE ... WHEN ... THEN ... END` expressions
- `DISTINCT`, including `COUNT(DISTINCT ...)`
- `OFFSET`
- `NOT IN`
- `BETWEEN`
- `INTERSECT` and `EXCEPT`
- `WITH RECURSIVE`
- Window functions (`OVER (...)`)
- Derived tables (subqueries in the `FROM` clause)
- Qualified star (`t.*`): list the columns explicitly

Subqueries work only in `EXISTS (...)` and `IN (...)`. `UNION ALL` and `MATERIALIZED` CTEs also work.

## Differences from PostgreSQL

Stategraph SQL checks and rewrites each query before PostgreSQL runs it. These rules differ from PostgreSQL:

- A query cannot contain comments, `--` or `/* */`.
- A query is one statement. Do not put two statements in one query, and do not end a query with `;`.
- `count` works only as `count(*)`. `count(address)` and `count(DISTINCT type)` are parse errors.
- In `ORDER BY`, use an alias only when it names a column or `count(*)`. For another expression, such as `sum(...)` or a function call, repeat the expression: `ORDER BY sum(monthly_cost::real) DESC`.
- `ORDER BY 1` and `GROUP BY 1` do not refer to a column position. The number is a value. Write the column name.
- `ANY(...)` is not allowed. To find a value in an array column, convert the array to JSON: `to_jsonb(dependencies) @> '["aws_vpc.main"]'::jsonb`. Or use `unnest` in `FROM`.
- A string literal is `text`. Compared with a `uuid` or `timestamptz` column, it takes the type of the column. Cast it where a function or operator needs another type: `attributes->'tags' @> '{"Environment": "production"}'::jsonb`.
- An integer literal is `bigint`. Cast it where a function or operator needs `integer`: `substr(name, 1::integer, 3::integer)`, `array_length(dependencies, 1::integer)`, `attributes->'ingress'->0::integer`.
- When one side of a comparison or arithmetic operator is a column, the other side must be a column or a literal that fits the column type. A function call, a cast, arithmetic, `||`, or a negative number there returns `TYPE_MISMATCH_ERR`.
- To compare a column with an expression, cast the column: `created_at::timestamptz > date_trunc('week', now())`.
- In `GROUP BY`, an expression with a literal does not match the same expression in the select list. PostgreSQL rejects the query. For a JSON value, use `#>>` in both places: `GROUP BY attributes#>>'{instance_type}'`.
- For another such expression, compute it in a CTE, then group by the CTE column.

## Reserved Keywords

```text
ALL, AND, AS, ASC, BY, COUNT, DESC, EXISTS, FALSE, FROM, GROUP,
HAVING, ILIKE, IN, INNER, IS, JOIN, LEFT, LIKE, LIMIT, MATERIALIZED, NOT,
NULL, ON, OR, ORDER, RIGHT, SELECT, TRUE, UNION, UNNEST, WHERE, WITH
```

Write a keyword in all lowercase or all uppercase: `select` and `SELECT` work, but `Select` does not.

## Query Examples

### Basic Queries

All instances:

```sql
SELECT * FROM instances
```

All resources:

```sql
SELECT * FROM resources
```

One type, from the `resources` table:

```sql
SELECT * FROM resources WHERE type = 'aws_instance'
```

Multiple conditions:

```sql
SELECT * FROM resources
WHERE type = 'aws_instance'
  AND module IS NOT NULL
```

### Aggregations

Count by type. Order by the aggregate expression, not by the alias:

```sql
SELECT type, COUNT(*) AS total
FROM resources
GROUP BY type
ORDER BY COUNT(*) DESC
```

With a minimum count:

```sql
SELECT type, COUNT(*) AS total
FROM resources
GROUP BY type
HAVING COUNT(*) > 5
ORDER BY COUNT(*) DESC
```

### JSON Queries

One attribute:

```sql
SELECT
  address,
  attributes->>'instance_type' AS instance_type
FROM instances
```

Filter by attribute:

```sql
SELECT address
FROM instances
WHERE attributes->>'instance_type' = 't3.micro'
```

Check tags:

```sql
SELECT address
FROM instances
WHERE attributes->'tags'->>'Environment' = 'production'
```

### Complex Queries

Resources by type with counts:

```sql
SELECT type, COUNT(*) AS total
FROM resources
WHERE provider LIKE '%hashicorp/aws%'
GROUP BY type
ORDER BY COUNT(*) DESC
```

## Error Handling

The API returns these errors with HTTP 400, in a JSON body with the error `id` and `data`. The CLI prints `Error: <id> (<data>)`, except for an unknown or ambiguous column, where it prints a plain message.

| Error | Cause |
|-------|-------|
| `QUERY_ERR` | The query does not parse, or PostgreSQL rejects it. A parse error does not name the wrong token or its column. |
| `UNKNOWN_COLUMN_ERR` | A column that is not in the tables of the query. The CLI prints `Error: Unknown column 'foo'.` |
| `AMBIGUOUS_COLUMN_ERR` | A column name that is in more than one table of the query. Qualify it with the table name or alias. |
| `TABLE_ACCESS_ERR` | A table that is not in the [available tables](#available-tables) |
| `FUNC_ACCESS_ERR` | A function that is not in the [allowed functions](#built-in-functions) |
| `CAST_ERR` | A cast to a type that is not allowed |
| `TYPE_MISMATCH_ERR` | A column compared with a value that does not fit its type. See [Differences from PostgreSQL](#differences-from-postgresql). |
| `TIMEOUT_ERR` | The query ran longer than `STATEGRAPH_DB_STATEMENT_TIMEOUT`, `30s` by default |

## Next Steps

- [Query](/docs/infrastructure-as-a-database/query/query): queries in the console and the CLI
- [SQL commands](/docs/cli/sql): `stategraph sql query` and `stategraph sql schema`
- [Cost queries](/docs/infrastructure-as-a-database/cost/queries): cost tables and example queries
