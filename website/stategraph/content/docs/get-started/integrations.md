---
title: Integrations
description: Connect Stategraph to your cloud providers, infrastructure as code tools, CI systems, and external tools, with a setup guide for each one.
order: 1
---

Stategraph works with the cloud providers, infrastructure as code tools, CI systems, and external tools that you already use.

Orchestration runs plans and applies for pull requests on your GitHub Actions or GitLab CI runners. The `stategraph` CLI runs where your pipeline runs today. Both authenticate to your cloud like any other job there. The Stategraph server does not run your plans and applies.

## Cloud providers

Give Orchestration credentials for the cloud that your code manages. Each guide covers static credentials for a quick start and OIDC for production.

- [AWS](/docs/orchestration/cloud-providers/aws): IAM access keys or an IAM role assumed through OpenID Connect
- [GCP](/docs/orchestration/cloud-providers/gcp): a service account key or Workload Identity Federation
- [Azure](/docs/orchestration/cloud-providers/azure): a service principal secret or Entra ID federated credentials
- [Other providers](/docs/orchestration/cloud-providers/other): the pattern for any provider that reads a token from an environment variable

## IaC tools

Orchestration runs Terraform by default. To run OpenTofu, the `stategraph` CLI, Terragrunt, Pulumi, CDKTF, or a custom command, set [`engine`](/docs/reference/orchestration/configuration/engine) in `.stategraph/config.yml`.

- [Terraform](/docs/orchestration/iac-tools/terraform): the default engine, and how to pin its version
- [OpenTofu](/docs/orchestration/iac-tools/opentofu): the `tofu` engine
- [Terragrunt](/docs/orchestration/iac-tools/terragrunt): the `terragrunt` engine
- [Pulumi](/docs/orchestration/iac-tools/pulumi): the `pulumi` engine
- [CDKTF](/docs/orchestration/iac-tools/cdktf): the `cdktf` engine

## Migration

- [From Terraform Cloud](/docs/orchestration/migration/terraform-cloud): move workspaces, state, secrets, and workflows
- [From Digger](/docs/orchestration/migration/digger): convert `digger.yml` to `.stategraph/config.yml`
- [From Atlantis](/docs/orchestration/migration/atlantis): convert `atlantis.yaml` and `repos.yaml` to `.stategraph/config.yml`
- [From Spacelift](/docs/orchestration/migration/spacelift): move stacks, contexts, state, and secrets
- [From env0](/docs/orchestration/migration/env0): move environments, variables, custom flows, and state

## CI and orchestrators

Use Infrastructure as a Database under your current CI system or orchestrator. Your triggers and approvals stay, and the `stategraph` CLI plans and applies.

- [GitHub Actions](/docs/infrastructure-as-a-database/ci/github-actions): plan on pull requests and apply on merge, in plain workflow YAML
- [GitLab CI](/docs/infrastructure-as-a-database/ci/gitlab-ci): the same flow on GitLab, with a sticky merge request note
- [Atlantis](/docs/infrastructure-as-a-database/ci/atlantis): keep comment-driven automation, and replace the Terraform commands with two `run` steps
- [Spacelift](/docs/infrastructure-as-a-database/ci/spacelift): run the CLI through the Spacelift custom workflow tool

## External tools

- [OPA](/docs/orchestration/external-tools/opa): enforce policies on plans with Open Policy Agent and Conftest
- [Infracost](/docs/orchestration/external-tools/infracost): cost estimates in pull requests
- [Security scanning](/docs/infrastructure-as-a-database/security): static analysis with Checkov
- [Webhooks](/docs/orchestration/external-tools/webhooks): connect external systems
- [AI integrations](/docs/orchestration/external-tools/ai-integrations): AI feedback on plan and apply results in pull requests
- [Installing packages](/docs/orchestration/external-tools/installing-packages): add packages to the runner
