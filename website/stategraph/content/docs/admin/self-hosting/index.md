---
title: Self-hosting
description: "Run Stategraph on your own infrastructure: the Open Source and Enterprise images, the deployment paths, and the setup that both share."
order: 1
---


You can run Stategraph on your own infrastructure in two editions. They are the same server, in two images:

| | Open Source | Enterprise |
|---|---|---|
| Image | `ghcr.io/stategraph/stategraph-server-oss` | `ghcr.io/stategraph/stategraph-server` |
| Includes | Orchestration: plans and applies from pull requests, policy checks, cost estimates in pull requests, and drift detection | Orchestration with the Enterprise features, and Infrastructure as a Database with state cost and security scanning |
| Users | Up to 3 active users per month per GitHub or GitLab installation | No limit |
| License | MPL-2.0, no key | Commercial. A license key completes the first-time setup, and the server checks it at each start afterwards: set `STATEGRAPH_LICENSE_KEY`, or enter the key on the setup screen |

Both images deploy the same way, with [Docker Compose](/docs/admin/self-hosting/docker-compose), [Kubernetes](/docs/admin/self-hosting/kubernetes), [Amazon ECS](/docs/admin/self-hosting/ecs), or [Google Cloud Run](/docs/admin/self-hosting/cloud-run). The pages of this section use the Open Source image. For Enterprise, use `ghcr.io/stategraph/stategraph-server` instead, and add the license key. See [Editions](/docs/get-started/editions) for the features of each edition.

## What you need

- The Stategraph container: `ghcr.io/stategraph/stategraph-server-oss` or `ghcr.io/stategraph/stategraph-server`.
- A PostgreSQL server, version 15 or later. The Docker Compose setup runs PostgreSQL 17.
- A public URL for Stategraph, for example `https://stategraph.example.com`.
- A reverse proxy, an ingress, or a load balancer that terminates TLS in front of the container.

The Stategraph server does not run your plans and applies. The Enterprise container includes the `stategraph` CLI at `/usr/local/bin/stategraph`, to run by hand or from a runner.

## Choose a deployment

- [Docker Compose](/docs/admin/self-hosting/docker-compose): one host, with PostgreSQL included. The quickest path and the reference setup.
- [Kubernetes](/docs/admin/self-hosting/kubernetes): the Helm chart, with an ingress and an external PostgreSQL.
- [Amazon ECS](/docs/admin/self-hosting/ecs): Fargate behind an Application Load Balancer, with RDS, from a Terraform module.
- [Google Cloud Run](/docs/admin/self-hosting/cloud-run): a serverless service, with Cloud SQL through the Auth Proxy sidecar.

## Ports

Publish only port `8080`. It serves the console, the API, the OAuth callbacks, the health endpoints, and the Orchestration webhook and runner paths.

Keep all other ports closed. Port `8090`, for state cost, answers requests without authentication.

## Databases

Stategraph uses one PostgreSQL server with up to three databases:

| Database | Variable | Needed for | Created by |
|----------|----------|------------|------------------|
| `stategraph` | `DB_NAME` | Always | You, before the first start. The Docker Compose file creates it as `POSTGRES_DB`. |
| `terrateam` | `TERRAT_DB_NAME` | Orchestration | Orchestration, at start, when its role has `CREATEDB`. Otherwise, see [Enable Orchestration](/docs/admin/self-hosting/orchestration#database). |
| `cloud_pricing` | `PRICING_DB_NAME` | State cost, Enterprise | The `load-pricing-data` loader, at the first start. |

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
| [State cost](/docs/admin/self-hosting/cost), Enterprise | `STATEGRAPH_COST_ENABLED=true` |
| [Security scanning](/docs/admin/self-hosting/security-scanning), Enterprise | `STATEGRAPH_SECURITY=1` |
| [Google or OIDC sign-in](/docs/admin/access-control) | `STATEGRAPH_OAUTH_TYPE=google` or `oidc` |

Cost estimates in pull requests run Infracost on your runner, in both editions: see [Cost estimation in pull requests](/docs/orchestration/external-tools/infracost) for the Infracost API key.

Stategraph reads the Orchestration and state cost settings only at a start with its default command. With an overridden `command:` or `entrypoint:`, they have no effect.

## Move to Enterprise

Open Source and Enterprise use the same databases. To move a server to Enterprise, change the image to `ghcr.io/stategraph/stategraph-server` and set `STATEGRAPH_LICENSE_KEY`. Your repositories, `.stategraph/config.yml`, GitHub App, and run history stay. [Contact sales](https://stategraph.com/contact) for a license key.

## Next steps

- [Self-hosted quickstart](/docs/get-started/quickstart/self-hosted): from nothing to a running console, with Orchestration, on Open Source or Enterprise.
- [Environment variables](/docs/admin/operations/environment-variables): all settings that Stategraph reads.
- [Upgrades](/docs/admin/operations/upgrades): install a new version safely and verify the image signature.
- [Migrate from Terrateam](/docs/admin/self-hosting/migrate-from-terrateam): replace a self-hosted Terrateam server with the Stategraph server image and keep its database.
