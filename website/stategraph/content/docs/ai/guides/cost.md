---
title: Answer cost questions
description: "Use an AI agent with Stategraph cost data to rank spend by state, resource, and tag, check coverage, and price a change before you apply it."
order: 4
---


Find where your cloud spend goes and what a change will cost, from the cost data that Stategraph keeps for every state. The agent ranks and explains. The figures come from Stategraph.

## How Stategraph does it

- With cost estimation on, Stategraph prices every resource in every state from its price book. It recalculates after applies and on a schedule.
- Every total carries a coverage figure: the share of resources that have a price. The agent reports it with the total, so an estimate is never read as the full bill.
- A plan carries a cost block, with the change in monthly cost of each resource that the plan touches.
- With a billing source connected, actual spend from your cloud bill sits beside the estimates, in separate commands.

## Before you begin

- [Set up your agent](/docs/ai/quickstart) with a read-only token.
- [Cost estimation](/docs/admin/self-hosting/cost) on the server.

## Steps

### 1. Ask where the spend goes

```text
Where does our monthly AWS spend go? Use Stategraph to break it down by state, list the five
most expensive resources, and tell me how much of the estate is not priced.
```

The agent reads the tenant total, then each expensive state:

```bash
stategraph cost tenant --format=json
stategraph cost state --state <state-id> --format=json
stategraph cost billing-source list --format=json
```

<figure class="docs-figure">
<div class="docs-diagram-bars">
<div class="docs-why-lane"><span class="docs-why-name">aws_db_instance.primary</span><span class="docs-why-track"><span class="docs-why-bar docs-diagram-bar" style="--w: 100%">$656.27</span></span></div>
<div class="docs-why-lane"><span class="docs-why-name">aws_db_instance.replica_1</span><span class="docs-why-track"><span class="docs-why-bar docs-diagram-bar" style="--w: 50%">$328.50</span></span></div>
<div class="docs-why-lane"><span class="docs-why-name">aws_db_instance.replica_2</span><span class="docs-why-track"><span class="docs-why-bar docs-diagram-bar" style="--w: 25%">$164.25</span></span></div>
<div class="docs-why-lane"><span class="docs-why-name">aws_instance.bastion</span><span class="docs-why-track"><span class="docs-why-bar docs-diagram-bar" style="--w: 2%">$7.59</span></span></div>
</div>
<figcaption>Monthly estimate per resource, from <code>stategraph cost state</code>.</figcaption>
</figure>

### 2. Break it down by owner

```bash
stategraph cost tenant --tag-key Team
```

Output:

```text
tag:Team        monthly      hourly    resources
--------------  -----------  --------  ---------
(total)         1156.612000  1.584400  204
data            1149.020000  1.574000  13
engineering     7.592000     0.010400  20
```

Other breakdowns: `stategraph cost history --group-by provider` for the trend, and `stategraph cost unmanaged` for spend that no state manages. Both need a [billing source](/docs/infrastructure-as-a-database/cost/billing-sources) for actual spend.

### 3. Price a change before you apply it

When an agent plans a change, ask for its cost. The plan's cost block shows the change per resource:

```text
Costs:
  Per state:
    acme-data-stores:
      ~ aws_db_instance.replica_1                           -164.25
```

See [Make a change with a plan-only agent](/docs/ai/guides/plan-a-change).

## Next steps

- [Cost overview](/docs/infrastructure-as-a-database/cost): estimates, actual spend, and attribution
- [Plan-time cost](/docs/infrastructure-as-a-database/cost/plan-time): the cost block of a plan
- [Cost attribution](/docs/infrastructure-as-a-database/cost/attribution): spend by tag and owner
