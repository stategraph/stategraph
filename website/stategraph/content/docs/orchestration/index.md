---
title: Stategraph Orchestration
description: Stategraph Orchestration runs Terraform and OpenTofu from pull requests: automatic plans, policy checks, approvals, applies, and drift detection.
order: 1
---


Stategraph Orchestration runs your infrastructure changes through pull requests on GitHub and GitLab. The Open Source edition is [free to self-host](/docs/get-started/quickstart/self-hosted). Enterprise adds governance, and Stategraph Cloud runs Orchestration for you. See [Editions and pricing](/docs/get-started/editions).

## What it does

- Plans each pull request, for each changed directory and workspace. The plan uses your branch merged with the destination branch, so it shows the result of the merge. Comment `stategraph plan` to plan again. See [Pull request workflow](/docs/orchestration/workflows).
- Applies on a `stategraph apply` comment, or after the merge with `when_modified.autoapply`. See [Apply after merge](/docs/orchestration/workflows/apply-after-merge).
- Locks the directories and workspaces that an apply changes, so no other pull request applies over them. The merge after a successful apply releases the lock. See [Locks and concurrency](/docs/orchestration/workflows/advanced/lock-management).
- Runs your checks on each plan: OPA and Conftest policies, Checkov scans, and Infracost estimates. A failed check fails the plan, or adds a gate that someone must approve. See [OPA](/docs/orchestration/external-tools/opa), [Security scanning](/docs/infrastructure-as-a-database/security), and [Infracost](/docs/orchestration/external-tools/infracost).
- Enforces apply requirements: approvals, passing checks, and no merge conflicts. Enterprise adds RBAC, CODEOWNERS enforcement, approval gates, and centralized configuration. See [Governance](/docs/orchestration/governance/rbac).
- Detects drift with scheduled plans, and can open an issue when your infrastructure and your code differ. See [Drift detection](/docs/orchestration/governance/drift-detection).
- Runs Terraform, OpenTofu, the `stategraph` CLI, Terragrunt, Pulumi, CDKTF, or a custom command. See [IaC tools](/docs/orchestration/iac-tools/terraform) and [Use with Orchestration](/docs/infrastructure-as-a-database/orchestration).

## How it works

<figure class="docs-figure">
<div class="docs-mock docs-flow">
<div class="docs-flow-node">Pull request<small>GitHub or GitLab</small></div><div class="docs-flow-node accent">Stategraph Orchestration<small>Cloud or self-hosted</small></div><div class="docs-flow-node">CI runner<small>GitHub Actions or GitLab CI</small></div><div class="docs-flow-msg c12 right"><span>1. Event</span></div><div class="docs-flow-msg c23 right"><span>2. Start a CI run</span></div><div class="docs-flow-msg c23 left"><span>3. Results</span></div><div class="docs-flow-msg c12 left"><span>4. Comments and checks</span></div>
</div>
<figcaption>An event on a pull request reaches Orchestration.<br> Orchestration starts a workflow on your CI runner.<br> Orchestration posts the results back as comments and checks.</figcaption>
</figure>

Plans and applies run on your GitHub Actions or GitLab CI runners, so your cloud credentials stay there. Orchestration starts the runs and records the results. For the full event sequence, see [How it works](/docs/get-started/how-it-works).

## Get started

1. Choose where Orchestration runs: [Stategraph Cloud](/docs/get-started/quickstart/cloud), or [self-hosted](/docs/get-started/quickstart/self-hosted), Open Source or Enterprise.
2. Connect GitHub or GitLab, and add the workflow file to your repository. The quickstarts show both steps.
3. Open a pull request that changes a `.tf` file, and read the plan comment.

Without a configuration file, Orchestration uses defaults. To change workflows, policies, or other settings, add `.stategraph/config.yml`. See [Configuration](/docs/orchestration/configuration).

## In this section

| Group | What it covers |
|-------|----------------|
| [Pull requests](/docs/orchestration/workflows) | The pull request flow, apply after merge, rollbacks, and performance |
| [Configuration](/docs/orchestration/configuration) | The `.stategraph/config.yml` file, modules, secrets and variables, and CODEOWNERS |
| [Advanced patterns](/docs/orchestration/workflows/advanced/multi-environment) | Environments, stacks, layered runs, tags, locks, engines, and custom steps |
| [Governance](/docs/orchestration/governance/rbac) | Access control, approval gates, drift detection, and centralized configuration |
| [Security](/docs/orchestration/security) | Cloud credentials, OIDC, private runners, plan storage, and the audit trail |
| [Cloud providers](/docs/orchestration/cloud-providers/aws) | AWS, GCP, Azure, and other providers |
| [IaC tools](/docs/orchestration/iac-tools/terraform) | Terraform, OpenTofu, Terragrunt, Pulumi, and CDKTF |
| [External tools](/docs/orchestration/external-tools/opa) | OPA, Infracost, webhooks, AI integrations, and packages on the runner |
