---
title: Audit compliance and secrets
description: "Use an AI agent with Stategraph SQL and security findings to check every state against your rules, and find secrets in state without printing them."
order: 3
---


Check every state against your rules in one pass: buckets without versioning, security groups open to the internet, scanner findings, and secrets that Terraform wrote into state. The agent shows the query behind each finding, so the report is evidence you can rerun.

## How Stategraph does it

- Resource attributes are JSON in the `instances` table. A rule is a `WHERE` clause over every state, not a script per repository.
- With security scanning on, Stategraph runs Checkov on each state and stores the findings as rows. The agent cross-checks its own SQL against them.
- A query returns only the columns it selects. Select a flag such as `password IS NOT NULL`, and the secret value never reaches the agent.

## Before you begin

- [Set up your agent](/docs/ai/quickstart) with a read-only token.
- For scanner findings, [security scanning](/docs/infrastructure-as-a-database/security) on the server.

## Audit your rules

### 1. Ask for the audit

```text
Run a compliance check over all our states with Stategraph: S3 buckets without versioning
or encryption, security groups that allow 0.0.0.0/0, and the most common security scanner
findings. Show the query or command behind each claim.
```

The agent queries resource attributes, then the scanner:

```bash
stategraph sql query "SELECT s.name AS state, i.address, i.attributes->>'bucket' AS bucket, i.attributes#>>'{versioning_configuration,0,status}' AS versioning FROM instances AS i INNER JOIN resources AS r ON i.resource_address = r.address AND i.state_id = r.state_id INNER JOIN states AS s ON i.state_id = s.id WHERE r.type = 'aws_s3_bucket_versioning' ORDER BY s.name, i.address LIMIT 1000" --format=json
stategraph sql query "SELECT s.name AS state, i.address, r.type, i.attributes->>'cidr_ipv4' AS cidr, i.attributes->>'from_port' AS from_port FROM instances AS i INNER JOIN resources AS r ON i.resource_address = r.address AND i.state_id = r.state_id INNER JOIN states AS s ON i.state_id = s.id WHERE i.attributes::text LIKE '%0.0.0.0/0%' ORDER BY s.name, i.address LIMIT 1000" --format=json
stategraph security findings summary --state <state-id> --format=json
```

Output (excerpt from the agent):

```text
| Bucket                   | Versioning | Encryption |
|--------------------------|------------|------------|
| acme-assets-production   | Enabled    | aws:kms    |
| acme-exports-production  | Suspended  | aws:kms    |
| acme-logs-production     | Suspended  | aws:kms    |
| acme-terraform-state     | Enabled    | aws:kms    |

Checkov agrees: CKV_AWS_21 fails on exactly these two buckets.

| Rule                                             | Port    | Assessment               |
|--------------------------------------------------|---------|--------------------------|
| aws_vpc_security_group_ingress_rule.bastion_ssh  | 22/tcp  | SSH open to the internet |
| aws_vpc_security_group_ingress_rule.alb_http     | 80/tcp  | Normal for a public ALB  |
| aws_vpc_security_group_ingress_rule.alb_https    | 443/tcp | Normal for a public ALB  |
```

### 2. Fix the findings with a plan

Hand each fix to a [plan-only agent](/docs/ai/guides/plan-a-change). The plan shows the security impact of the change, so you can confirm a finding is resolved before you apply.

## Find secrets in state

### 1. Ask without the values

```text
Which resources in our states hold passwords, secret strings, or private keys in their state
attributes? Do not print any secret values, only addresses and attribute names.
```

### 2. Check it yourself

Select flags, not values:

```bash
stategraph sql query "SELECT s.name AS state, i.address, i.attributes->>'password' IS NOT NULL AS has_password, i.attributes->>'secret_string' IS NOT NULL AS has_secret_string FROM instances AS i INNER JOIN states AS s ON i.state_id = s.id WHERE i.attributes->>'password' IS NOT NULL OR i.attributes->>'secret_string' IS NOT NULL ORDER BY s.name, i.address LIMIT 1000"
```

Output:

```text
state             address                                            has_password  has_secret_string
----------------  -------------------------------------------------  ------------  -----------------
acme-data-stores  aws_db_instance.primary                            true          false
acme-data-stores  aws_db_instance.replica_1                          true          false
acme-data-stores  aws_db_instance.replica_2                          true          false
acme-platform     aws_secretsmanager_secret_version.api_keys         false         true
acme-platform     aws_secretsmanager_secret_version.db_password      false         true
acme-platform     aws_secretsmanager_secret_version.jwt_signing_key  false         true
```

The agent's advice for the RDS rows: set `manage_master_user_password`, so that RDS keeps the password in Secrets Manager and it leaves state.

## Next steps

- [Security scanning](/docs/infrastructure-as-a-database/security): how findings are produced
- [Guardrails](/docs/ai/guardrails): what reaches the model provider
- [SQL syntax](/docs/reference/sql-syntax): JSON operators and filters
