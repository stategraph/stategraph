---
title: Self-hosting
description: Run Stategraph on your own infrastructure: the Open Source and Enterprise editions, their images and deployment paths, and the Enterprise setup.
order: 1
---


You can run Stategraph on your own infrastructure in two editions. They are different server images:

| | Open Source | Enterprise |
|---|---|---|
| Image | `ghcr.io/terrateamio/terrat-oss` | `ghcr.io/stategraph/stategraph-server` |
| Includes | Orchestration: plans and applies from pull requests, policy checks, cost estimates, and drift detection | Orchestration with the Enterprise features, and Infrastructure as a Database |
| Users | Up to 3 active users per month per GitHub or GitLab installation | No limit |
| License | MPL-2.0, no key | Commercial. A license key completes the first-time setup, and the server checks it at each start afterwards: set `STATEGRAPH_LICENSE_KEY`, or enter the key on the setup screen |
| Deployments | [Docker Compose](/docs/get-started/quickstart/self-hosted-open-source), [Kubernetes](/docs/admin/self-hosting/open-source/kubernetes), [Amazon ECS](/docs/admin/self-hosting/open-source/ecs) | [Docker Compose](/docs/admin/self-hosting/docker-compose), [Kubernetes](/docs/admin/self-hosting/kubernetes), [Amazon ECS](/docs/admin/self-hosting/ecs), [Google Cloud Run](/docs/admin/self-hosting/cloud-run) |

For the open-source edition, see [Open Source](/docs/admin/self-hosting/open-source). An open-source build of the Stategraph server, with Orchestration and no license key, is in development. See [Editions](/docs/get-started/editions) for the features of each edition.

The rest of this page, and the other pages of this section, cover the Enterprise server. Each deployment needs the container, port, databases, and settings below.

## What you need

- The Stategraph container, `ghcr.io/stategraph/stategraph-server`.
- A PostgreSQL server. The Docker Compose setup runs PostgreSQL 17.
- A public URL for Stategraph, for example `https://stategraph.example.com`.
- A reverse proxy, an ingress, or a load balancer that terminates TLS in front of the container.

The Stategraph server does not run your plans and applies. The container includes the `stategraph` CLI at `/usr/local/bin/stategraph`, to run by hand or from a runner.

## Choose a deployment

- [Docker Compose](/docs/admin/self-hosting/docker-compose): one host, with PostgreSQL included. The quickest path and the reference setup.
- [Kubernetes](/docs/admin/self-hosting/kubernetes): the Helm chart, with an ingress and an external PostgreSQL.
- [Amazon ECS](/docs/admin/self-hosting/ecs): Fargate behind an Application Load Balancer, with RDS, from a Terraform module.
- [Google Cloud Run](/docs/admin/self-hosting/cloud-run): a serverless service, with Cloud SQL through the Auth Proxy sidecar.

## Ports

Publish only port `8080`. It serves the console, the API, the OAuth callbacks, the health endpoints, and the Orchestration webhook and runner paths.

Keep all other ports closed. Port `8090`, for cost estimation, answers requests without authentication.

## Databases

Stategraph uses one PostgreSQL server with up to three databases:

| Database | Variable | Needed for | Created by |
|----------|----------|------------|------------------|
| `stategraph` | `DB_NAME` | Always | You, before the first start. The Docker Compose file creates it as `POSTGRES_DB`. |
| `terrateam` | `TERRAT_DB_NAME` | Orchestration | Orchestration, at start, when its role has `CREATEDB`. Otherwise, see [Enable Orchestration](/docs/admin/self-hosting/orchestration#database). |
| `cloud_pricing` | `PRICING_DB_NAME` | Cost estimation | The `load-pricing-data` loader, at the first start. |

With Orchestration on:

- On PostgreSQL 15 and later, the role that Orchestration connects as must own the `terrateam` database, because PostgreSQL closes the `public` schema to other roles.
- The `stategraph` database reads `terrateam` through `postgres_fdw`, as two more roles: `stategraph_mql` and `stategraph_provisioner`. See [Enable Orchestration](/docs/admin/self-hosting/orchestration) for these roles and for managed PostgreSQL.

## Start and migrations

At each start, Stategraph migrates its databases, then serves requests.

- `/health/live` answers `200` as soon as the web server is up.
- `/health/ready` answers `200` only after the Stategraph server has migrated its database and serves requests.
- An interrupted start leaves the database consistent, at the last completed migration step.
- Replicas that start at the same time migrate safely.

See [Health checks](/docs/admin/operations/health-checks) and [Upgrades](/docs/admin/operations/upgrades).

## Required settings

Stategraph needs its database connection and its public URL. All other settings have defaults.

| Variable | Value |
|----------|-------|
| `DB_HOST` / `DB_PORT` / `DB_USER` / `DB_PASS` / `DB_NAME` | The `stategraph` database |
| `STATEGRAPH_UI_BASE` | The public URL that users open, for example `https://stategraph.example.com`. The `migrate` command also needs it, because it loads the configuration first. |

## Optional features

Each feature is off by default, except Orchestration in the [Docker Compose](/docs/admin/self-hosting/docker-compose) setup. To turn one on, set its variables in the container environment.

| Feature | Setting |
|---------|---------|
| [Stategraph Orchestration](/docs/admin/self-hosting/orchestration) | `STATEGRAPH_ORCHESTRATION_ENABLED=true`, with `STATEGRAPH_FDW_PASSWORD` |
| [Cost estimation](/docs/admin/self-hosting/cost) | `STATEGRAPH_COST_ENABLED=true` |
| [Security scanning](/docs/admin/self-hosting/security-scanning) | `STATEGRAPH_SECURITY=1` |
| [Google or OIDC sign-in](/docs/admin/access-control) | `STATEGRAPH_OAUTH_TYPE=google` or `oidc` |

Stategraph reads the Orchestration and cost estimation settings only at a start with its default command. With an overridden `command:` or `entrypoint:`, they have no effect.

## Next steps

- [Self-hosted Enterprise quickstart](/docs/get-started/quickstart/self-hosted): from nothing to a running console.
- [Open Source](/docs/admin/self-hosting/open-source): self-host the open-source edition of Orchestration.
- [Environment variables](/docs/admin/operations/environment-variables): all settings that Stategraph reads.
- [Upgrades](/docs/admin/operations/upgrades): install a new version safely and verify the image signature.
