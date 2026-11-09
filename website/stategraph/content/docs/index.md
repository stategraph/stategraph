---
title: Documentation
description: Stategraph is infrastructure as code with a database underneath. Orchestration runs plans and applies in pull requests, and Infrastructure as a Database replaces the state file.
order: 0
---


Stategraph is infrastructure as code with a database underneath, and works with the Terraform and OpenTofu code that you have. Stategraph Orchestration runs plans and applies in your pull requests, with policy checks and approvals. Infrastructure as a Database replaces the state file, so plans read only what your change reaches, changes that do not overlap apply at the same time, and you can query every state with SQL.

## Start here

<div class="docs-products">
  <a href="/docs/get-started/quickstart/cloud" class="docs-product-card">
    <h3>Stategraph Cloud</h3>
    <p>Sign up, connect GitHub or GitLab, and run your first plan and apply from a pull request.</p>
  </a>
  <a href="/docs/get-started/quickstart" class="docs-product-card">
    <h3>Self-hosted</h3>
    <p>Run Open Source with Docker Compose, or the Enterprise build with a license key.</p>
  </a>
</div>

## Stategraph Orchestration

Orchestration works with GitHub and GitLab, as Open Source or Enterprise.

- Each pull request gets a plan comment, policy checks, and the required approvals.
- An apply runs on a `stategraph apply` comment or on merge.
- Drift detection runs on a schedule.
- Plans and applies run on your own GitHub Actions or GitLab CI runners, with Terraform, OpenTofu, the `stategraph` CLI, Terragrunt, Pulumi, CDKTF, or any command-line tool.
- Your state stays where it is, or you can keep it in [Infrastructure as a Database](/docs/infrastructure-as-a-database/orchestration).

## Infrastructure as a Database

Infrastructure as a Database keeps your state in PostgreSQL as a graph of resources and dependencies, not as a state file:

- A plan reads only the resources that the change reaches.
- Locks hold single resources, not the full state.
- Each plan and apply is a recorded transaction.
- You can query all of your infrastructure with SQL.

Infrastructure as a Database also works without Orchestration, with your current CI system: see [CI and orchestrators](/docs/infrastructure-as-a-database/ci).

## Why Stategraph

<figure class="docs-figure">
<div class="yt-lite" data-id="bjN6e8Znag0">
<button type="button" aria-label="Play the video: What is Stategraph?" onclick="var b=this.closest('.yt-lite'),f=document.createElement('iframe');f.src='https://www.youtube-nocookie.com/embed/'+b.dataset.id+'?autoplay=1&amp;rel=0&amp;iv_load_policy=3&amp;cc_load_policy=0&amp;playsinline=1&amp;color=white';f.title=this.getAttribute('aria-label');f.allow='accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture';f.allowFullscreen=true;b.replaceChildren(f);"><span class="yt-poster"><span class="yt-poster-kicker">Video &middot; 2 min</span><span class="yt-poster-title">What is Stategraph?</span></span><span class="yt-play" aria-hidden="true"></span></button>
</div>
<figcaption>What is Stategraph, in 2 minutes. <a href="https://youtu.be/bjN6e8Znag0">Watch on YouTube</a>.</figcaption>
</figure>

A Terraform state file is one JSON file per workspace, and each run locks all of it. Teams split the state so that they can work at the same time, and then connect the states by hand or with Terragrunt. Stategraph removes these limits.

<figure class="docs-figure docs-why">
<div class="docs-why-pair">
<div class="docs-why-panel bad">
<p class="docs-why-label">State file</p>
<div class="docs-why-lane"><span class="docs-why-name">vpc + subnet</span><span class="docs-why-track"><span class="docs-why-bar first">plan and apply</span></span></div>
<div class="docs-why-lane"><span class="docs-why-name">bucket + policy</span><span class="docs-why-track"><span class="docs-why-wait first">waiting</span><span class="docs-why-bar second">plan and apply</span></span></div>
<p class="docs-why-foot">One run at a time.</p>
</div>
<div class="docs-why-panel good">
<p class="docs-why-label">Stategraph</p>
<div class="docs-why-lane"><span class="docs-why-name">vpc + subnet</span><span class="docs-why-track"><span class="docs-why-bar first">plan and apply</span></span></div>
<div class="docs-why-lane"><span class="docs-why-name">bucket + policy</span><span class="docs-why-track"><span class="docs-why-bar first">plan and apply</span></span></div>
<p class="docs-why-foot">Both at the same time.</p>
</div>
</div>
<figcaption>Two changes to one state.<br> With a state file, the second change waits for the lock.<br> With Stategraph, changes that do not overlap run at the same time.</figcaption>
</figure>

<figure class="docs-figure docs-why">
<div class="docs-why-pair">
<div class="docs-why-panel bad">
<p class="docs-why-label">State file</p>
<svg class="docs-why-graph" viewBox="0 0 250 118" role="img" aria-label="All five resources of the state are locked."><line x1="64" y1="32" x2="64" y2="46"/><line x1="64" y1="72" x2="64" y2="86"/><line x1="186" y1="32" x2="186" y2="46"/><g class="lock"><rect x="8" y="6" width="112" height="26" rx="4"/><text x="64" y="19">aws_sg</text></g><g class="lock"><rect x="8" y="46" width="112" height="26" rx="4"/><text x="64" y="59">aws_db</text></g><g class="lock"><rect x="8" y="86" width="112" height="26" rx="4"/><text x="64" y="99">aws_db_replica</text></g><g class="lock"><rect x="130" y="6" width="112" height="26" rx="4"/><text x="186" y="19">aws_bucket</text></g><g class="lock"><rect x="130" y="46" width="112" height="26" rx="4"/><text x="186" y="59">bucket_policy</text></g></svg>
<p class="docs-why-foot">The full state locks.</p>
</div>
<div class="docs-why-panel good">
<p class="docs-why-label">Stategraph</p>
<svg class="docs-why-graph" viewBox="0 0 250 118" role="img" aria-label="Only aws_db and aws_db_replica are locked."><line x1="64" y1="32" x2="64" y2="46"/><line x1="64" y1="72" x2="64" y2="86"/><line x1="186" y1="32" x2="186" y2="46"/><g><rect x="8" y="6" width="112" height="26" rx="4"/><text x="64" y="19">aws_sg</text></g><g class="lock"><rect x="8" y="46" width="112" height="26" rx="4"/><text x="64" y="59">aws_db</text></g><g class="lock"><rect x="8" y="86" width="112" height="26" rx="4"/><text x="64" y="99">aws_db_replica</text></g><g><rect x="130" y="6" width="112" height="26" rx="4"/><text x="186" y="19">aws_bucket</text></g><g><rect x="130" y="46" width="112" height="26" rx="4"/><text x="186" y="59">bucket_policy</text></g></svg>
<p class="docs-why-foot">Only the changed resources lock.</p>
</div>
</div>
<figcaption>A change to <code>aws_db</code> and <code>aws_db_replica</code>. With Stategraph, the rest of the state stays free for other changes.</figcaption>
</figure>

<figure class="docs-figure docs-why">
<div class="docs-why-pair">
<div class="docs-why-panel bad">
<p class="docs-why-label">State files</p>
<div class="docs-why-states"><span class="docs-why-state ok">networking</span><span class="docs-why-arrow">&rarr;</span><span class="docs-why-state ok">compute</span><span class="docs-why-arrow">&rarr;</span><span class="docs-why-state fail">application</span></div>
<p class="docs-why-foot">One apply per state. A failure leaves a partial change.</p>
</div>
<div class="docs-why-panel good">
<p class="docs-why-label">Stategraph</p>
<div class="docs-why-states tx"><span class="docs-why-state">networking</span><span class="docs-why-state">compute</span><span class="docs-why-state">application</span></div>
<p class="docs-why-foot">One transaction. All states apply, or none do.</p>
</div>
</div>
<figcaption>A change that reaches three states.</figcaption>
</figure>

| Problem | With Stategraph |
|---------|-----------------|
| Runs wait for the lock on the full state. | Stategraph detects conflicts per resource. Changes that do not overlap plan and apply at the same time, in the same state. See [Resource-level locking](/docs/infrastructure-as-a-database/resource-locking). |
| A large state makes each plan slow. | A plan reads only the resources that the change reaches. See [Infrastructure as a Database](/docs/infrastructure-as-a-database). |
| Split states need dependencies that you connect by hand. | A plan follows the dependencies between states. The states that a change reaches plan and apply as one transaction: all of them apply, or none do. See [Multi-state transactions](/docs/infrastructure-as-a-database/multi-state). |
| A rename or a move can lose state. | A refactor session follows your HCL changes and writes the `moved` blocks for you. See [Refactoring](/docs/infrastructure-as-a-database/refactoring). |
| Changes reach the cloud without review. | Each change goes through a pull request: a plan, policy checks, approvals, and an apply on a comment or on merge. An apply locks the directories and workspaces that it changes, so no other pull request applies over them. Layered runs and stacks put dependent changes in order. See [Pull request workflow](/docs/orchestration/workflows). |
| Anyone with access can apply to production. | With Enterprise, RBAC, CODEOWNERS enforcement, approval gates, and centralized configuration control who can plan and apply. Runs can get cloud credentials through OIDC. See [Security best practices](/docs/orchestration/security). |
| Changes made outside Terraform stay hidden. | Scheduled drift detection compares your infrastructure with your code, and can open an issue. See [Drift detection](/docs/orchestration/governance/drift-detection). |
| You cannot see what you run or how it changed. | Query every state with SQL, and keep your queries in dashboards. See the blast radius, the dependency graph, the history of each change, and the cloud resources that no state manages. See [Query](/docs/infrastructure-as-a-database/query). |
| You see what a change costs only on the bill. | Stategraph estimates the cost of each plan and shows it in the pull request. It totals the cost per state and per tenant, and attributes it by tag. See [Cost](/docs/infrastructure-as-a-database/cost). |
| AI agents need wide access to your infrastructure. | Skills for Claude Code and other agents, tokens with limited capabilities, and a timeline of each action. See [AI agents](/docs/ai). |

Adopt Stategraph in two steps:

1. Start with Orchestration and the tool that you use now: Terraform, OpenTofu, Terragrunt, Pulumi, or CDKTF. Your state stays where it is.
2. Change to the [`stategraph` engine](/docs/infrastructure-as-a-database/orchestration), and [import your state](/docs/get-started/quickstart/import-state) into Infrastructure as a Database. You can export it back to a Terraform state file.

## Browse the docs

<div class="docs-map">
<div class="docs-map-group">
<h3>Get started</h3>
<ul>
<li><a href="/docs/get-started/how-it-works">How it works</a></li>
<li><a href="/docs/get-started/core-concepts">Core concepts</a></li>
<li><a href="/docs/get-started/editions">Editions and pricing</a></li>
<li><a href="/docs/get-started/integrations">Integrations</a></li>
</ul>
</div>
<div class="docs-map-group">
<h3>Orchestration</h3>
<ul>
<li><a href="/docs/orchestration">Overview</a></li>
<li><a href="/docs/orchestration/workflows">Pull request workflow</a></li>
<li><a href="/docs/orchestration/configuration">Configuration file</a></li>
<li><a href="/docs/orchestration/security">Security best practices</a></li>
</ul>
</div>
<div class="docs-map-group">
<h3>Infrastructure as a Database</h3>
<ul>
<li><a href="/docs/infrastructure-as-a-database">Overview</a></li>
<li><a href="/docs/infrastructure-as-a-database/setup">Setup</a></li>
<li><a href="/docs/get-started/quickstart/import-state">Import your state</a></li>
<li><a href="/docs/infrastructure-as-a-database/orchestration">Use with Orchestration</a></li>
</ul>
</div>
<div class="docs-map-group">
<h3>Administration</h3>
<ul>
<li><a href="/docs/admin/self-hosting">Self-hosting</a></li>
<li><a href="/docs/admin/access-control">Authentication</a></li>
<li><a href="/docs/admin/operations/environment-variables">Environment variables</a></li>
<li><a href="/docs/admin/operations/upgrades">Upgrades</a></li>
</ul>
</div>
<div class="docs-map-group">
<h3>CLI</h3>
<ul>
<li><a href="/docs/cli">Install and configure</a></li>
<li><a href="/docs/cli/config">Client configuration</a></li>
<li><a href="/docs/cli/tf">Plan and apply</a></li>
<li><a href="/docs/cli/sql">SQL queries</a></li>
</ul>
</div>
<div class="docs-map-group">
<h3>Reference</h3>
<ul>
<li><a href="/docs/reference/orchestration/configuration">Configuration keys</a></li>
<li><a href="/docs/reference/api">Stategraph API</a></li>
<li><a href="/docs/reference/troubleshooting">Troubleshooting</a></li>
<li><a href="/docs/reference/sql-syntax">SQL syntax</a></li>
</ul>
</div>
</div>

For help, see [Support](/docs/support).
