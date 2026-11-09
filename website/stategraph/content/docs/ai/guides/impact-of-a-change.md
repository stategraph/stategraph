---
title: Check the impact of a change
description: "Use an AI agent with Stategraph blast radius and cross-state references to find what a change to one resource can break, before you edit code."
order: 2
---


Find everything that depends on a resource, in its own state and in the states that read it, before you change it. The agent turns the dependency graph into the risks of the change.

## How Stategraph does it

- `stategraph states instances blast-radius` walks the dependency graph on the server and returns every node that a change to one instance can reach. The result says when the graph was cut, so a partial answer never looks complete.
- `hcl_refs` records which block in which state reads which output of another state, so cross-state impact is a query.
- `outputs` and `instances` give the IDs and attributes that connect the two, such as the subnets that workloads in other states run in.

The graph runs in the database. The agent's context only holds the result.

## Before you begin

- [Set up your agent](/docs/ai/quickstart) with a read-only token.
- The instance address of the resource. Blast radius takes an instance address, such as `aws_nat_gateway.main[0]`, not the resource address `aws_nat_gateway.main`.

## Steps

### 1. Ask what depends on the resource

```text
We want to replace the NAT gateway in acme-networking. Using Stategraph, tell me everything
that depends on it, including in other states, and what would be at risk. Do not change anything.
```

The agent runs blast radius on each instance, then reads outputs and cross-state references:

```bash
stategraph states instances blast-radius 'aws_nat_gateway.main[0]' --state <state-id> --format=json
stategraph sql query "SELECT o.name, o.value FROM outputs AS o WHERE o.state_id = '<state-id>' ORDER BY o.name" --format=json
stategraph sql query "SELECT s.name AS state, h.ref, h.id AS block, h.attr_path FROM hcl_refs AS h INNER JOIN states AS s ON h.state_id = s.id WHERE h.ref LIKE 'data.terraform_remote_state%' GROUP BY s.name, h.ref, h.id, h.attr_path ORDER BY s.name LIMIT 1000" --format=json
```

Output (excerpt from the agent):

```text
Replacing the NAT gateway breaks no Terraform reference outside acme-networking. Its real
reach is network egress: every workload in the three private subnets sends internet-bound
traffic through it, and those workloads live in acme-compute and acme-data-stores.

Other states
- acme-compute: aws_autoscaling_group.api and .web, plus four Lambdas.
- acme-data-stores: the RDS primary and both replicas, and both ElastiCache clusters.
- acme-platform reads only vpc_id, so it isn't affected.

What's at risk
1. Outbound internet is down during the swap. S3 and DynamoDB keep working through
   the VPC endpoints.
2. NAT [0] serves two of the three private subnets. Replace one instance at a time.
3. Public egress IPs can change. Allowlists that trust the current EIPs would break.
```

### 2. Check the graph yourself

```bash
stategraph blast-radius aws_vpc.main --state <state-id>
```

Output (excerpt):

```text
address                                   kind      state            instances  depends_on
----------------------------------------  --------  ---------------  ---------  ----------
* aws_vpc.main                            resource  acme-networking  1          0
aws_internet_gateway.main                 resource  acme-networking  1          1
aws_network_acl.private                   resource  acme-networking  1          2
aws_route_table.private                   resource  acme-networking  2          2
aws_vpc_endpoint.s3                       resource  acme-networking  1          3
module.private_subnets.aws_subnet.this    resource  acme-networking  3          1
aws_nat_gateway.main                      resource  acme-networking  2          1
```

### 3. Plan the change

When you decide to go ahead, hand the agent a plan-only token and the change. See [Make a change with a plan-only agent](/docs/ai/guides/plan-a-change).

## Next steps

- [Blast radius](/docs/infrastructure-as-a-database/query/blast-radius): how the graph is built
- [Inventory your infrastructure](/docs/ai/guides/inventory): the map of every state
- [Make a change with a plan-only agent](/docs/ai/guides/plan-a-change): plan it next
