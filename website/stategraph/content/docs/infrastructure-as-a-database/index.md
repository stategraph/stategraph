---
title: Infrastructure as a Database
description: Infrastructure as a Database keeps your Terraform and OpenTofu state as a graph in PostgreSQL, with scoped plans, resource locks, and SQL.
order: 1
---


Infrastructure as a Database keeps your Terraform and OpenTofu state in PostgreSQL as a graph, not as a flat file. You can use it with or without Stategraph Orchestration. See [Editions](/docs/get-started/editions).

## What changes

### State as a graph

Resources, instances, modules, variables, outputs, and their dependencies are rows in PostgreSQL. You query them with SQL from the CLI or the console. See [Query](/docs/infrastructure-as-a-database/query/query).

### Scoped plans

`stategraph tf plan` compares your local HCL with the current state, and plans only the subgraph that your change reaches, not the full root module. Plan time follows the size of the change, not of your infrastructure.

Stategraph uses the Terraform or OpenTofu binary that you have. You change no providers and no HCL. Replace `terraform plan` and `terraform apply` with `stategraph tf plan` and `stategraph tf apply`:

```bash
stategraph tf plan --tenant <tenant-id> --out plan.json
stategraph tf apply plan.json
```

### Resource-level locks

A usual backend locks the full state file for each operation. Stategraph finds conflicts per resource at commit time, so two engineers can change different parts of the same state at once. See [Resource-level locking](/docs/infrastructure-as-a-database/resource-locking).

### Transactions

Each plan and apply is a transaction, with a log of what changed, in which state, and by whom. You see transactions in the CLI, the console timeline, and SQL. See [Transactions](/docs/infrastructure-as-a-database/transactions).

### Multi-state transactions

Several states plan and apply in one atomic transaction, with the references between them resolved. The plan adds the states that your change reaches through `terraform_remote_state`. `stategraph tf mtx` plans the directories that you choose, for example the networking, compute, and application layers. See [Multi-state transactions](/docs/infrastructure-as-a-database/multi-state).

```bash
stategraph tf mtx --tenant <tenant-id> --out plan.json ./networking ./compute ./application
```

## How it works

<figure class="docs-figure">
<div class="docs-diagram-stages two">
<div class="docs-why-panel"><p class="docs-why-label">Your machine or CI runner</p><div class="docs-why-states"><span class="docs-why-state">Terraform / OpenTofu</span><div class="docs-diagram-row"><span class="docs-why-arrow">&harr;</span><span class="docs-why-state accent">Stategraph CLI</span></div></div><p class="docs-why-foot">Plans and applies run here.</p></div>
<span class="docs-why-arrow">&rarr;</span>
<div class="docs-why-panel"><p class="docs-why-label">Stategraph Cloud or <span class="docs-diagram-keep">self-hosted</span></p><div class="docs-why-states"><span class="docs-why-state accent">Stategraph server</span><span class="docs-why-arrow">&rarr;</span><span class="docs-why-state">PostgreSQL</span></div><p class="docs-why-foot">Stores state and coordinates transactions.</p></div>
</div>
<figcaption>The Stategraph CLI runs Terraform or OpenTofu on your machine or CI runner.<br> The Stategraph server stores the state in PostgreSQL and coordinates transactions.</figcaption>
</figure>

- The CLI runs on your machine or CI runner. It reads the Terraform configuration, builds the resource dependency graph, and runs Terraform or OpenTofu, which applies independent changes in parallel, in dependency order.
- The server stores state and coordinates transactions. It does not run your plans and applies.

## Get started

1. Get a server: [Stategraph Cloud](/docs/get-started/quickstart/cloud) or [host Stategraph yourself](/docs/admin/self-hosting).
2. Import a state and run your first plan: see [Import your Terraform state](/docs/infrastructure-as-a-database/import-state) for a short walkthrough, or [Setup](/docs/infrastructure-as-a-database/setup) for the full guide.

## In this section

| Page | What it covers |
|------|----------------|
| [Setup](/docs/infrastructure-as-a-database/setup) | API key, CLI setup, import or create a state, workspaces, plan and apply |
| [Transactions](/docs/infrastructure-as-a-database/transactions) | Transaction lifecycle: create, preview, commit, abort |
| [Resource-level locking](/docs/infrastructure-as-a-database/resource-locking) | Conflict detection and concurrent transactions |
| [Multi-state transactions](/docs/infrastructure-as-a-database/multi-state) | Plan and apply several states in one transaction |
| [Refactoring](/docs/infrastructure-as-a-database/refactoring) | Rename and move resources without losing state |
| [Use with Orchestration](/docs/infrastructure-as-a-database/orchestration) | Run pull request plans and applies with Infrastructure as a Database |
