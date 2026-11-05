---
title: Open Source
description: Self-host the open-source edition of Stategraph Orchestration with Docker Compose, Kubernetes, or Amazon ECS, and find its variables and metrics.
order: 1
---


The open-source edition of Stategraph Orchestration is the `ghcr.io/terrateamio/terrat-oss` image, built from the [stategraph/stategraph](https://github.com/stategraph/stategraph) repository under the MPL-2.0 license. It runs Orchestration only: pull request plans and applies, policy checks, cost estimates, and drift detection, for up to 3 active users per month per GitHub or GitLab installation, with unlimited runs. It does not include Infrastructure as a Database. See [Editions](/docs/get-started/editions).

The Enterprise edition is a different image, `ghcr.io/stategraph/stategraph-server`, with a license key: see [Self-hosting](/docs/admin/self-hosting). An open-source build of the Stategraph server, with Orchestration and no license key, is in development.

## What runs

- The server container, `ghcr.io/terrateamio/terrat-oss`. It listens on port 8080, and serves the console, the API, the GitHub and GitLab webhooks, and the endpoints that the runner calls.
- A PostgreSQL database.
- A public HTTPS URL that GitHub or GitLab can reach, for webhooks. The Docker Compose setup gets one from a tunnel. On Kubernetes and ECS, your ingress or load balancer provides it.
- Your GitHub Actions or GitLab CI runners, which run the plans and applies. The server only dispatches them.

## Choose a deployment

| Deployment | Use it for | Guide |
|---|---|---|
| Docker Compose | One host, with PostgreSQL and a tunnel included. The quickest start. | [Self-hosted Open Source quickstart](/docs/get-started/quickstart/self-hosted-open-source) |
| Kubernetes | The Helm chart, with an ingress and an external PostgreSQL. | [Kubernetes](/docs/admin/self-hosting/open-source/kubernetes) |
| Amazon ECS | Fargate behind an Application Load Balancer, with RDS, from a Terraform module. | [Amazon ECS](/docs/admin/self-hosting/open-source/ecs) |

Each path starts with the setup wizard, `ghcr.io/stategraph/orchestration-setup`. It creates the GitHub App or collects the GitLab credentials, and prints the environment variables that the server needs.

For the variables that the container reads, see [Environment variables](/docs/admin/self-hosting/open-source/environment-variables). For the health endpoint, logs, and Prometheus metrics, see [Observability and metrics](/docs/admin/self-hosting/open-source/observability).

## Move to Enterprise

Enterprise has no user limit, and adds RBAC, CODEOWNERS enforcement, approval gates, centralized configuration, and more drift schedules. It is a different server image. For a new deployment, see [Self-hosted Enterprise](/docs/get-started/quickstart/self-hosted). To move an existing Orchestration server, see [Migrate from Terrateam](/docs/admin/self-hosting/migrate-from-terrateam). The migration keeps the database, the GitHub App, and the run history. Your repositories and `.stategraph/config.yml` stay as they are. [Contact sales](https://stategraph.com/contact) for a license key.

## Next steps

- [Self-hosted Open Source quickstart](/docs/get-started/quickstart/self-hosted-open-source): Docker Compose, from the wizard to the first pull request.
- [Kubernetes](/docs/admin/self-hosting/open-source/kubernetes): the Helm chart.
- [Amazon ECS](/docs/admin/self-hosting/open-source/ecs): the Terraform module.
- [Editions](/docs/get-started/editions): what Open Source includes, and how to get Enterprise.
