---
title: Editions and pricing
description: Compare Stategraph Orchestration Open Source and Enterprise, Infrastructure as a Database, and the Stategraph Cloud plans, prices, and limits.
order: 4
---


Stategraph Orchestration has an Open Source edition and an Enterprise edition. Infrastructure as a Database includes Orchestration Pro, with every Enterprise feature. You self-host them, or use a Stategraph Cloud plan.

## Feature matrix

Infrastructure as a Database includes Orchestration Pro, so its column has every Enterprise row.

| Capability | Open Source | Enterprise | Infrastructure as a Database |
|---|---|---|---|
| Automation on pull requests: `stategraph plan`, `stategraph apply` | Yes | Yes | Yes |
| Pre-merge and post-merge applies | Yes | Yes | Yes |
| Multi-environment and multi-workspace coordination | Yes | Yes | Yes |
| Tag queries and the tag system | Yes | Yes | Yes |
| Locking and parallel execution | Yes | Yes | Yes |
| [Config builder](/docs/orchestration/workflows/advanced/dynamic-configuration) (dynamic config, Terragrunt, tree builder) | Yes | Yes | Yes |
| [Custom workflows](/docs/orchestration/workflows/advanced/custom-commands) and [custom runners](/docs/orchestration/workflows/advanced/runs-on) | Yes | Yes | Yes |
| [Cost estimation in pull requests](/docs/orchestration/external-tools/infracost) | Yes | Yes | Yes |
| Policy enforcement: [OPA](/docs/orchestration/external-tools/opa), [Checkov](/docs/infrastructure-as-a-database/security), built-in | Yes | Yes | Yes |
| [Stacks](/docs/orchestration/workflows/advanced/stacks) and dependency coordination | Yes | Yes | Yes |
| [Audit trail](/docs/orchestration/security/audit-trail) | Yes | Yes | Yes |
| Console for runs, logs, and debugging | Yes | Yes | Yes |
| [Private runners](/docs/orchestration/security/private-runners) | Yes | Yes | Yes |
| [Drift detection](/docs/orchestration/governance/drift-detection), one schedule per repository | Yes | Yes | Yes |
| Drift detection, multiple schedules per repository | No | Yes | Yes |
| [Access control / RBAC](/docs/orchestration/governance/rbac) (`access_control.enabled: true`) | No | Yes | Yes |
| [CODEOWNERS enforcement](/docs/orchestration/configuration/codeowners) (`require_completed_reviews`) | No | Yes | Yes |
| [Gatekeeper](/docs/orchestration/governance/gatekeeper) (approval gates with tokens) | No | Yes | Yes |
| [Centralized configuration](/docs/orchestration/governance/centralized-config) (defaults and overrides across repositories) | No | Yes | Yes |
| [API access tokens](/docs/reference/api/access-tokens#refresh-tokens-and-access-tokens) | No | Yes | Yes |
| [Unified pull request summary comment](/docs/reference/orchestration/configuration/notifications) (`notifications.summary`) | No | Yes | Yes |
| Active users per installation per month | Up to 3 | No limit self-hosted; per plan on Stategraph Cloud | Custom |
| [Plans scoped to the resources a change reaches](/docs/infrastructure-as-a-database) | No | No | Yes |
| [Resource-level locking](/docs/infrastructure-as-a-database/resource-locking) | No | No | Yes |
| [Transactions](/docs/infrastructure-as-a-database/transactions) and [multi-state transactions](/docs/infrastructure-as-a-database/multi-state) | No | No | Yes |
| [SQL across every state](/docs/infrastructure-as-a-database/query), [blast radius](/docs/infrastructure-as-a-database/query/blast-radius), [gap analysis](/docs/infrastructure-as-a-database/query/gap-analysis) | No | No | Yes |
| [State cost and attribution](/docs/infrastructure-as-a-database/cost) | No | No | Yes |
| Self-hostable | Yes | Yes, with a license | Yes, including air-gapped and BYOC |
| License | MPL-2.0 | Commercial | Commercial |

## Stategraph Orchestration Open Source

Open Source is the full core of Orchestration, with unlimited runs. Enterprise and Stategraph Cloud add the Enterprise features below. The source is on [GitHub](https://github.com/stategraph/stategraph). You self-host it with Docker Compose, Kubernetes, Amazon ECS, or Google Cloud Run: see [Self-hosted](/docs/get-started/quickstart/self-hosted) and [Self-hosting](/docs/admin/self-hosting).

Besides its Yes rows in the matrix, Open Source includes:

- Automerge and rollbacks.
- Hooks, and parallel, batch, and layered runs.
- All [IaC tool integrations](/docs/orchestration/iac-tools/terraform) (Terraform, OpenTofu, Terragrunt, Pulumi, CDKTF), and all cloud provider integrations.
- [Plan file storage](/docs/orchestration/security/plan-file-storage).

### What happens past 3 active users

Each GitHub or GitLab installation allows up to 3 active users per month.

- The first 3 users who run a plan or apply in a calendar month keep working all month.
- For other users, the plan or apply does not run. Orchestration posts an **Open Source Tier Limit Reached** comment on the pull request that lists the active users of the month.
- Drift detection is not affected.
- The count resets at the start of each calendar month.

### What happens if you enable an Enterprise feature

If `.stategraph/config.yml` turns on an Enterprise-only setting on an Open Source server, Orchestration rejects the configuration when it loads it, and a pull request comment names the feature. Open Source rejects:

- `access_control.enabled: true`
- More than one entry under `drift.schedules`
- Any `apply_requirements.checks[].approved.require_completed_reviews: true`
- `notifications.summary.enabled: true`
- A `stategraph gate approve <token>` comment, or any workflow gate with a token

Open Source reads only the `.stategraph/config.yml` in each repository, so it has no centralized configuration. It does not register the API access token routes.

## Stategraph Orchestration Enterprise

Enterprise is Open Source with no user limit, plus these governance features, marked Enterprise in the docs:

- Access control / RBAC: control who can `plan`, `apply`, `apply-force`, `apply-autoapprove`, `unlock`, and update CI or Stategraph configuration. Rules match users, teams, or repository roles, per tag query, and can use super-approval. See [RBAC](/docs/orchestration/governance/rbac) and the [access_control reference](/docs/reference/orchestration/configuration/access-control).
- CODEOWNERS enforcement: with the `require_completed_reviews` apply requirement, each reviewer that CODEOWNERS requires must approve before an apply can run. See [CODEOWNERS](/docs/orchestration/configuration/codeowners).
- Gatekeeper: when a gated workflow step fails, such as a security scan, a policy check, or a custom validation, the workflow records a gate and blocks the apply. Authorized users approve with a `stategraph gate approve <token>` comment. See [Gatekeeper](/docs/orchestration/governance/gatekeeper).
- Centralized configuration: global and per-repository defaults, overrides, and forced configuration, kept in one repository and layered onto the `.stategraph/config.yml` of each repository. See [Centralized configuration](/docs/orchestration/governance/centralized-config).
- Multiple drift schedules: for example, hourly and tag-scoped for production, daily for staging. See [Drift detection](/docs/orchestration/governance/drift-detection).
- API access tokens: create, list, refresh, and delete scoped tokens for KV store reads and writes and other operations. See [Access tokens](/docs/reference/api/access-tokens#refresh-tokens-and-access-tokens).

### How to get Enterprise

- Stategraph Cloud: every plan includes all Enterprise features, on from the start. Sign up at [app.stategraph.cloud](https://app.stategraph.cloud).
- Self-hosted: the Pro plan includes a licensed Enterprise build that you run yourself, for $12,000 per year, the same price as Pro on Stategraph Cloud. [Contact sales](https://stategraph.com/contact) for a license, then deploy it: see [Self-hosted](/docs/get-started/quickstart/self-hosted), or change the image of your Open Source server: see [Move to Enterprise](/docs/admin/self-hosting#move-to-enterprise). Your repositories and `.stategraph/config.yml` carry over.

## Infrastructure as a Database

Orchestration decides when and how changes run. Infrastructure as a Database scopes each operation to the resources that changed, not to a locked and replayed state file. Operations run at the same time without a global lock, and leave a complete record of your infrastructure that you can query.

- With Orchestration: set the engine to `stategraph` to run each pull request through it. See [Use with Orchestration](/docs/infrastructure-as-a-database/orchestration).
- With other CI/CD: use the `stategraph` CLI under your existing CI/CD or orchestration workflows. See [Infrastructure as a Database](/docs/infrastructure-as-a-database) and [CI and orchestrators](/docs/infrastructure-as-a-database/ci).
- Deployment: Stategraph Cloud, self-hosted, air-gapped, or BYOC (Stategraph engineers operate it in your AWS, GCP, or Azure account).
- Pricing: from $25,000 per year, on an annual contract, with dedicated support and a custom SLA. It includes Orchestration Pro. [Contact sales](https://stategraph.com/contact) for a quote, then follow [Setup](/docs/infrastructure-as-a-database/setup).

## Stategraph Cloud plans

| Plan | Price | Users | Runs per month | Concurrent workers | Support |
|---|---|---|---|---|---|
| Free | $0, forever | 3 | 50 | 1 | Community |
| Pro | $12,000 per year, billed annually | Unlimited | Unlimited | Unlimited | Priority support by email and Slack, and an onboarding session with Stategraph engineers |

Free and Pro include every Orchestration feature and differ only by these limits. A run is one plan or apply that Stategraph executes. New accounts start on Pro for 30 days, with no credit card, then move to Free with every feature at the Free limits. To stay on Pro, add a card at any time.

### Managing a subscription

Manage your subscription, payment method, and invoices in the [Stripe customer portal](https://billing.stripe.com/p/login/00geXngL2cQR0YofYY).

## Choosing an edition

You can move from Open Source to Enterprise, then to Infrastructure as a Database, which includes Orchestration Pro. Each step keeps your repositories and your `.stategraph/config.yml`. To move a self-hosted server from Open Source to Enterprise, see [Move to Enterprise](/docs/admin/self-hosting#move-to-enterprise).

Choose Open Source when:

- One team or a few repositories need none of the Enterprise features.
- GitHub branch protection or GitLab protected branches are enough, without CODEOWNERS or fine-grained RBAC in the apply flow.
- You are comfortable with self-hosting and upgrades.

Choose Enterprise when:

- You need any of its governance features, such as RBAC for teams that share infrastructure.
- More than 3 users run plans or applies on one installation in a month.
- You want Stategraph Cloud. All Stategraph Cloud plans include the Enterprise features.

Choose Infrastructure as a Database when:

- Plans and applies are slow because each run replays the full state.
- Teams wait behind one lock per state, although their changes touch different resources.
- You want SQL over your infrastructure, or blast radius and cost before apply.
- You want a complete, queryable record of each change, from CI, laptops, and AI agents.

## Next steps

- [Stategraph Cloud quickstart](/docs/get-started/quickstart/cloud): sign up and run your first plan.
- [Self-hosted quickstart](/docs/get-started/quickstart/self-hosted): run Open Source or Enterprise with Docker Compose.
- [Governance](/docs/orchestration/governance/rbac): the Enterprise governance features.
- [Infrastructure as a Database](/docs/infrastructure-as-a-database): scoped plans, locks, transactions, and SQL.
