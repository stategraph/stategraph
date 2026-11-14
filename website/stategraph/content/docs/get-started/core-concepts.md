---
title: Core concepts
description: Learn the terms that Stategraph uses: tenants, runs, dirspaces, stacks, locks, tag queries, states, instances, and transactions.
order: 3
---


Stategraph Orchestration and Infrastructure as a Database use these terms in the console, the configuration file, the CLI, and the docs.

The Orchestration defaults suit most teams, so configure only what you need, such as module handling, custom workflows, or apply rules.

## Tenant

A tenant is the top-level isolation boundary, usually an organization or a team. Each state, transaction, and connected GitHub or GitLab installation belongs to exactly one tenant. A user can be a member of several tenants. A new account administers its own tenant. Most CLI commands take `--tenant` or read `STATEGRAPH_TENANT_ID`. See [Tenants](/docs/admin/access-control/tenants).

## Repository, directory, and workspace

A repository holds one or more directories of Terraform code. Each directory has one or more Terraform workspaces, or the `default` workspace when it has none. A directory and workspace pair is a dirspace: the unit that Orchestration plans, applies, and locks.

Orchestration finds dirspaces from your Terraform files. The `dirs` section of `.stategraph/config.yml` attaches tags, workspaces, and settings to directories. See [dirs](/docs/reference/orchestration/configuration/dirs).

## Installation

An installation connects Orchestration to a VCS account. On GitHub, it is the GitHub App on an organization or user account. On GitLab, it is a group, connected with an access token and a webhook secret. The installation ID is the numeric group ID, and a GitLab project is a repository.

## Run

A run is one plan or apply that Orchestration executes, for a pull request or a drift schedule. A run is queued, running, succeeded, failed, or aborted, and the console lists runs under **Runs**. For run limits, see [Editions and pricing](/docs/get-started/editions).

## Changes and file patterns

When a pull request opens or updates, Orchestration maps the changed files to dirspaces with `when_modified.file_patterns` in [`.stategraph/config.yml`](/docs/orchestration/configuration). These dirspaces are the changes of the pull request, and Orchestration plans nothing else. The default:

```yaml
when_modified:
  file_patterns:
    - '${DIR}/*.tf'
    - '${DIR}/*.tfvars'
```

You can also set `when_modified` per directory or per workspace, and the most specific setting wins. See [when_modified](/docs/reference/orchestration/configuration/when-modified).

## Auto-plan and auto-apply

Orchestration plans a pull request when it opens or updates, and applies on a `stategraph apply` comment. Apply after merge is off by default:

```yaml
when_modified:
  autoplan: true
  autoapply: false
```

Set `autoapply: true` to apply when the pull request merges. See [Apply after merge](/docs/orchestration/workflows/apply-after-merge).

## Engine

The engine is the tool that runs `init`, `plan`, and `apply` for a dirspace: Terraform (the default), OpenTofu (`tofu`), Terragrunt, Pulumi, CDKTF, the `stategraph` CLI, or `custom`, with your own command for each step. Set it for the repository or per workflow:

```yaml
workflows:
  - tag_query: "development"
    engine:
      name: tofu
  - tag_query: "production"
    engine:
      name: terraform
```

See [engine](/docs/reference/orchestration/configuration/engine) and [Use with Orchestration](/docs/infrastructure-as-a-database/orchestration).

## Tags and tag queries

Tags label dirspaces. Each dirspace has `dir:<path>` and `workspace:<name>` tags. Add your own under `dirs`, or derive them from branch names with the top-level `tags` key. A tag query is a boolean expression over tags, such as `prod in dir and not deprecated`. It selects the dirspaces for a workflow, an access control rule, an apply requirement, a drift schedule, or a pull request command. See [Tag queries](/docs/reference/orchestration/configuration/tag-queries) and [The tag system](/docs/orchestration/workflows/advanced/tag-system).

## Stacks

A stack names a group of dirspaces, selected by a tag query, or a group of other stacks. Its rules set when one group can plan or apply relative to another. A dirspace belongs to at most one stack. Stack rules are transitive. See [Stacks](/docs/orchestration/workflows/advanced/stacks).

## Locks

When a pull request applies a dirspace, or merges without an apply, Orchestration locks each dirspace that the pull request targets. No other pull request can apply those dirspaces until the change is both applied and merged. To release a lock by hand, comment `stategraph unlock`. `lock_policy` sets when Orchestration takes locks:

```yaml
lock_policy: strict
```

The default, `strict`, locks on apply or merge. See [Locks and concurrency](/docs/orchestration/workflows/advanced/lock-management). For Infrastructure as a Database, see [Resource-level locking](#resource-level-locking).

## Apply requirements and gates

Apply requirements, scoped by tag query, set what must be true before an apply: approvals from named users or teams, passing status checks, and no merge conflicts. See [apply_requirements](/docs/reference/orchestration/configuration/apply-requirements).

A gate is a manual approval that Orchestration records when a gated step fails, such as a policy check. The apply waits until an authorized user approves the gate. Gatekeeper is an Enterprise feature. See [Gatekeeper](/docs/orchestration/governance/gatekeeper).

## State and the state graph

In Infrastructure as a Database, a state is one Terraform state, the resources of one root module, stored on the server with a UUID. It is a graph, not a file: resources are nodes and dependencies are edges. Terraform computes this graph to order its operations, and Stategraph keeps it for locks, queries, and analysis. A state has a name, and belongs to a workspace and a group.

## Group

A group connects a configuration directory to its states, one per workspace, such as `default`, `staging`, or `production`. The import writes the mapping to `stategraph.json` in that directory, so the CLI knows which state a directory drives. See [Import your Terraform state](/docs/get-started/quickstart/import-state). A group ID with a workspace selects one state. Each state also has its own state ID, which the API and the `--state` option of the CLI use.

## Resource and instance

A resource is one `resource` block in your configuration, such as `aws_instance.web`. An instance is a real object that the block produces. A block with `count` or `for_each` has several instances (`aws_instance.web[0]`, `aws_instance.web[1]`). Inventory queries, search, and blast radius work on instances.

## Transaction

Each plan and apply through Infrastructure as a Database is a transaction. A transaction moves from `open` through plan and apply states, and ends as committed, failed, or aborted. The server records who ran each transaction, when, and what changed. Inspect this timeline in the console, with `stategraph tx`, or with SQL. See [Transactions](/docs/infrastructure-as-a-database/transactions) and [Timeline](/docs/infrastructure-as-a-database/query/timeline).

## Resource-level locking

Because the state is a graph, Infrastructure as a Database locks single resources, not full states. Transactions that change different resources plan and apply at the same time. When two applies overlap, Stategraph rejects the later one at commit time with the ID of the conflicting transaction. Plan again and retry. See [Resource-level locking](/docs/infrastructure-as-a-database/resource-locking).

## Blast radius

The blast radius of an instance is its dependency cone: everything that a change to it could affect. Infrastructure as a Database computes it from the graph, across linked states, so you see the impact before you apply. See [Blast radius](/docs/infrastructure-as-a-database/query/blast-radius).

## Gap analysis

Gap analysis finds cloud resources in your account that no state manages. It is drift in the other direction: what runs outside of code. See [Gap analysis](/docs/infrastructure-as-a-database/query/gap-analysis).

## SQL

Infrastructure as a Database shows your infrastructure as SQL tables: `resources`, `instances`, `states`, `transactions`, cost snapshots, and, when Orchestration is on, its runs, pull requests, and drift schedules. Find the tables with `stategraph sql schema`, and run queries with `stategraph query "..."`. See [Query](/docs/infrastructure-as-a-database/query/query).

## Cost

Infrastructure as a Database estimates the cost of the resources in each state, attributes spend by tag, owner, or provider, and shows the cost change at plan time. With a FOCUS billing source, it reconciles the estimates with actual cloud spend. Orchestration also posts a cost estimate on pull requests, through Infracost. See [Cost](/docs/infrastructure-as-a-database/cost).

## Access and capabilities

Users and service accounts authenticate with API keys. A key can have limited capabilities, such as plan only, apply on one state, or admin of one tenant. In Orchestration, access control rules (Enterprise) set who can run `stategraph plan`, `stategraph apply`, and the other pull request commands. See [Access control](/docs/admin/access-control) and [RBAC](/docs/orchestration/governance/rbac).

## Terraform and HCP Terraform terms

| Stategraph | Terraform or HCP Terraform |
|------------|----------------------------|
| Tenant | Organization |
| State | State file |
| Workspace | Workspace |
| Group ID | None |
| Transaction | None |
| API key | API token or team token |

## Next steps

- [How it works](/docs/get-started/how-it-works): the flows behind these terms.
- [Workflows](/docs/orchestration/workflows): pull request triggers and patterns.
- [Configuration](/docs/orchestration/configuration): the `.stategraph/config.yml` file.
- [Infrastructure as a Database](/docs/infrastructure-as-a-database): scoped plans, locks, transactions, and SQL.
