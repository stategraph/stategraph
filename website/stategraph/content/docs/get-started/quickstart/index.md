---
title: Quickstart
description: Choose how to start with Stategraph: Stategraph Cloud, self-hosting Open Source or Enterprise with Docker Compose, or a Terraform state import.
order: 1
---


Start with Stategraph on Stategraph Cloud, on your own server, or with an import of your Terraform state. Stategraph Orchestration runs plan and apply from pull requests. Infrastructure as a Database stores state as a graph and runs scoped plans with resource locks.

## Choose a path

- [Stategraph Cloud](/docs/get-started/quickstart/cloud): the fastest start, with nothing to run. Sign up, connect GitHub or GitLab, and get a plan comment and an apply on a pull request.
- [Self-hosted](/docs/get-started/quickstart/self-hosted): run Open Source, or Enterprise with a license key, with Docker Compose. Connect GitHub or GitLab, and open your first pull request on your own server.
- [Import your state](/docs/get-started/quickstart/import-state): install the CLI, import a Terraform or OpenTofu state into Infrastructure as a Database, and run a scoped plan and apply.

## What each path needs

| Path | You need |
|------|----------|
| Stategraph Cloud | On GitHub, ownership of the organization that holds the repository, or an owner who installs the app. On GitLab, a group (not a personal namespace) and the rights to create an access token, add a project webhook, and change CI/CD settings. A Terraform or OpenTofu repository, or a fork of the example, which needs no cloud credentials. |
| Self-hosted | Docker Engine and Docker Compose v2, and a license key for Enterprise. A URL that GitHub or GitLab can reach over HTTPS, or Terratunnel, which gives the server one. On GitHub, organization admin rights to create and install the GitHub App. On GitLab, a GitLab user for Stategraph with a personal access token and an OAuth application, and the GitLab rights above. |
| Import your state | A Stategraph server, on Stategraph Cloud or self-hosted. A Terraform or OpenTofu project with a state file that you can pull. Terraform or OpenTofu where you run the CLI. |

## Editions

On Stategraph Cloud, the Free and Pro plans include every Orchestration feature and differ by usage limits. Self-hosted Stategraph Open Source, the `stategraph-server-oss` image, allows up to 3 active users per month per GitHub or GitLab installation, with no run limit. Self-hosted Enterprise needs a license key and has no user limit. Infrastructure as a Database starts at $25,000 per year, on an annual contract. See [Editions](/docs/get-started/editions).

## Next steps

- [How it works](/docs/get-started/how-it-works): the server, the runner, and where Terraform runs.
- [Core concepts](/docs/get-started/core-concepts): the terms that the docs use.
- [Configuration](/docs/orchestration/configuration): the `.stategraph/config.yml` file that tunes Orchestration.
