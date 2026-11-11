---
title: Migrate from Terrateam
description: Replace a self-hosted Terrateam server, Open Source or Enterprise, with the Stategraph server image and keep its database.
order: 9
---

A self-hosted Terrateam server becomes a Stategraph server when you replace the container. Each Terrateam image has a Stategraph image of the same edition:

| Terrateam | Stategraph |
|---|---|
| `ghcr.io/terrateamio/terrat-oss` | `ghcr.io/stategraph/stategraph-server-oss` |
| `ghcr.io/terrateamio/terrat-ee` | `ghcr.io/stategraph/stategraph-server`, with a license key |

The PostgreSQL server, the Terrateam database, the GitHub App, the webhook URL, the runner workflow, and the run history stay. On Enterprise, the API tokens stay too. The Stategraph console replaces the Terrateam console on the same URL. The steps are the same for both editions, except for the license key.

## What changes

| | Terrateam server | Stategraph server |
|---|---|---|
| Image | `terrat-oss` or `terrat-ee` | `stategraph-server-oss:<version>` or `stategraph-server:<version>` |
| Databases | `terrateam` | `terrateam` and a new database, `stategraph`, on the same server |
| Console | Terrateam console, GitHub sign-in | Stategraph console, local or OIDC sign-in |
| Webhook and runner URLs | `https://<host>/api/github/v1/...` | the same |
| License | none | Open Source: none. Enterprise: `STATEGRAPH_LICENSE_KEY` |
| PostgreSQL | 14 or later | 15 or later |

## Before you start

1. Use PostgreSQL 15 or later.
2. Start the current Terrateam image one time and wait until its migrations are complete.
3. Set a webhook secret on the GitHub App and in `GITHUB_WEBHOOK_SECRET`.
4. Set `GITHUB_APP_URL` to the page of the App, for example `https://github.com/apps/<slug>`.
5. For Enterprise, get a license key.
6. Make a backup of the Terrateam database.
7. Change API clients that call `GET /api/v1/whoami` to `GET /api/v1/terrateam/whoami`. All other API paths stay the same.

## Environment

| Terrateam | Stategraph |
|---|---|
| `DB_NAME=terrateam` | `DB_NAME=stategraph` and `TERRAT_DB_NAME=terrateam`. `TERRAT_DB_HOST`, `_PORT`, `_USER`, and `_PASS` use the `DB_*` values by default. |
| `TERRAT_UI_BASE`, `TERRAT_API_BASE` | Remove. Set `STATEGRAPH_UI_BASE` and `STATEGRAPH_OAUTH_REDIRECT_BASE` to the old URL. |
| `TERRAT_WEB_BASE_URL` | Keep. |
| `GITHUB_*`, `GITLAB_*`, `TERRAT_TELEMETRY_LEVEL` | Keep. |
| | Add `STATEGRAPH_ORCHESTRATION_ENABLED=true`. |
| | Add `STATEGRAPH_FDW_USER` and `STATEGRAPH_FDW_PROVISIONER_USER` with the value of `DB_USER`, and `STATEGRAPH_FDW_PASSWORD` and `STATEGRAPH_FDW_PROVISIONER_PASSWORD` with the value of `DB_PASS`. |
| | Enterprise: add `STATEGRAPH_LICENSE_KEY`. |
| | If the name of the Terrateam database is not `terrateam`, add `STATEGRAPH_FDW_DBNAME` with the same value as `TERRAT_DB_NAME`. |
| `TERRATEAM_CLIENT_MAX_BODY_SIZE`, `TERRAT_ACCESS_LOG` | `STATEGRAPH_CLIENT_MAX_BODY_SIZE`, `STATEGRAPH_ACCESS_LOG` |
| `CUSTOM_CA_CERT` | Not available. Build a derived image that includes the certificate. |

## Database

Run this statement one time on the PostgreSQL server that has the Terrateam database:

```sql
CREATE DATABASE stategraph OWNER <application role>;
```

The `stategraph` database reads and writes the Terrateam database through `postgres_fdw`, as the application role. At each start, the server creates the roles `stategraph_mql` and `stategraph_provisioner` without `LOGIN`; this configuration does not use them. If the application role does not have `CREATEROLE`, create them one time:

```sql
CREATE ROLE stategraph_mql NOLOGIN;
CREATE ROLE stategraph_provisioner NOLOGIN;
```

To use these two roles for the connection instead of the application role, give them `LOGIN` and passwords, do not set `STATEGRAPH_FDW_USER` and `STATEGRAPH_FDW_PROVISIONER_USER`, and set the two password variables to their passwords.

If the application role is not a superuser, for example on Amazon RDS or Cloud SQL, run these statements one time in the `stategraph` database as a superuser:

```sql
CREATE EXTENSION IF NOT EXISTS postgres_fdw;
GRANT USAGE ON FOREIGN DATA WRAPPER postgres_fdw TO <application role>;
```

## Docker Compose

1. `docker compose pull server`
2. `docker compose stop server`
3. `docker compose exec db psql -U terrateam -d postgres -c 'create database stategraph owner terrateam'`
4. In the `server` service, set the Stategraph image of your edition and the environment from the table.
5. `docker compose up -d server`

`/health/ready` returns 200 when the migrations are complete.

## Kubernetes

The Stategraph chart uses the database of the Terrateam release. Keep the Terrateam release installed, with zero replicas, until the migration is final.

1. `kubectl scale deploy/terrateam-server --replicas=0 -n <namespace>`
2. `kubectl exec deploy/terrateam-db -n <namespace> -- psql -U terrateam -d postgres -c 'create database stategraph owner terrateam'`
3. Install the Stategraph chart with these values:

```yaml
stategraph:
  ui:
    base: https://<your Terrateam URL>
  # From terrat-ee only.
  edition: enterprise
  license:
    key: <license key>
  orchestration:
    enabled: true
    databaseName: terrateam
    provisionDatabase: false
    fdw:
      user: terrateam
      provisionerUser: terrateam
      existingSecret: terrateam-db-password
      existingSecretKeys:
        password: password
        provisionerPassword: password
    github:
      existingSecret: <Secret with the five GitHub credentials>
      appUrl: https://github.com/apps/<slug>
postgresql:
  enabled: false
  host: terrateam-db
  port: 5432
  auth:
    username: terrateam
    database: stategraph
    existingSecret: terrateam-db-password
    existingSecretKey: password
```

`terrateam-db` and `terrateam-db-password` are the Service and the Secret of the Terrateam chart. With an external PostgreSQL, set `postgresql.host` and `existingSecret` to that server and its Secret. The GitHub Secret uses the keys `github-app-id`, `github-app-client-id`, `github-app-client-secret`, `github-app-pem`, and `github-webhook-secret`; the Terrateam chart has the same values in five Secrets.

Keep `provisionDatabase` off; its init container changes the password of the bridge users, which are now the application role. If the application role does not have `CREATEROLE`, create the two roles as shown in [Database](#database).

Move the Ingress host to the Service of the Stategraph release.

To go back to Terrateam, scale the Stategraph deployment to zero and the Terrateam server to one. Do not run `helm uninstall terrateam` while the Stategraph release uses its database.

## Amazon ECS

The Stategraph module (`terraform-aws-stategraph-ecs`) is a second stack that uses the RDS instance of the Terrateam module (`terraform-aws-terrateam`).

1. Make a snapshot of the RDS instance.
2. Create the `stategraph` database on the RDS instance, with `terrateam` as the owner. Run `psql` from inside the VPC, for example as a one-off Fargate task.
3. `aws ecs update-service --cluster <name> --service <name> --desired-count 0`
4. Apply the Stategraph module:

```hcl
module "stategraph" {
  source = "stategraph/stategraph-ecs/aws"

  vpc_id             = var.vpc_id
  public_subnet_ids  = var.public_subnet_ids
  private_subnet_ids = var.private_subnet_ids
  domain_name        = "stategraph.example.com"   # the Terrateam domain
  certificate_arn    = var.certificate_arn

  # From terrat-ee only.
  # edition     = "enterprise"
  # license_key = var.license_key

  create_database            = false
  external_database_host     = "<terrateam RDS host>"
  external_database_port     = 5432
  external_database_name     = "stategraph"
  external_database_username = "terrateam"
  external_database_password = var.terrateam_db_password

  extra_environment = [
    { name = "STATEGRAPH_ORCHESTRATION_ENABLED", value = "true" },
    { name = "TERRAT_DB_NAME", value = "terrateam" },
    { name = "STATEGRAPH_FDW_USER", value = "terrateam" },
    { name = "STATEGRAPH_FDW_PROVISIONER_USER", value = "terrateam" },
    { name = "GITHUB_APP_URL", value = "https://github.com/apps/<slug>" },
  ]

  extra_secrets = [
    { name = "STATEGRAPH_FDW_PASSWORD", value_from = module.terrateam.secret_arns["db_password"] },
    { name = "STATEGRAPH_FDW_PROVISIONER_PASSWORD", value_from = module.terrateam.secret_arns["db_password"] },
    { name = "GITHUB_APP_ID", value_from = module.terrateam.secret_arns["github_app_id"] },
    { name = "GITHUB_APP_CLIENT_ID", value_from = module.terrateam.secret_arns["github_app_client_id"] },
    { name = "GITHUB_APP_CLIENT_SECRET", value_from = module.terrateam.secret_arns["github_app_client_secret"] },
    { name = "GITHUB_APP_PEM", value_from = module.terrateam.secret_arns["github_app_pem"] },
    { name = "GITHUB_WEBHOOK_SECRET", value_from = module.terrateam.secret_arns["github_webhook_secret"] },
  ]
}

resource "aws_vpc_security_group_ingress_rule" "stategraph_to_terrateam_rds" {
  security_group_id            = module.terrateam.rds_security_group_id
  referenced_security_group_id = module.stategraph.security_group_ecs_id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}
```


5. Move the DNS record of the Terrateam domain to the Stategraph load balancer (output `alb_dns_name`).
6. When the migration is final, remove `aws_db_instance.this` from the Terrateam state with `terraform state rm`, then destroy the Terrateam stack.

To go back to Terrateam before step 6, move the DNS record back and scale the Terrateam service up.

## After the start

1. Open the old URL and create the first instance admin in the setup screen. On Enterprise, the setup screen asks for the license key first, unless `STATEGRAPH_LICENSE_KEY` is set. With Google or OIDC sign-in, the first person who signs in becomes the instance admin.
2. Open **Getting started**, then **Connect GitHub**, and link each installation to a tenant. With the API: `PUT /api/v1/tenants/{tenant_id}/vcs-installations/github/{installation_core_id}`, with the ids from `GET /api/v1/vcs-installations/github/unclaimed`. For a GitLab group, use `gitlab` as the provider and the `core_id` from the `gitlab_installations_map` table.
3. Open **Orchestration**. It shows the runs from before the migration.
4. Open a pull request. The plan runs with the same workflow. Pull requests that were planned before the migration keep their plans.

Users of the Terrateam console must sign in again.

## Repository files

You do not have to rename files in your repositories.

- Orchestration reads `.stategraph/config.yml`. If a repository does not have it, Orchestration reads `.terrateam/config.yml`.
- On GitHub, Orchestration runs `.github/workflows/stategraph.yml`. If a repository does not have it, Orchestration runs `.github/workflows/terrateam.yml`.

To use the new names, rename both files in one pull request, and merge it. In the workflow file, also change `name: 'Terrateam Workflow'` to `name: 'Stategraph'`.

## Central configuration repository

With [centralized configuration](/docs/orchestration/governance/centralized-config), Orchestration looks for a central repository named `stategraph` first, then for one named `terrateam`. It uses the first repository whose default branch has at least one configuration file. It does not merge the two.

Orchestration starts to use the `stategraph` repository at the first commit that adds a configuration file to it. After that commit, files that are only in the `terrateam` repository have no effect. To move without a gap, do one of these:

- Copy all files to a branch of the `stategraph` repository, and merge them in one pull request.
- Rename the `terrateam` repository to `stategraph`.

## Comment and check names

Pull request comments and commit check names use a brand, for example `stategraph plan` or `terrateam plan`. A repository with `.terrateam/config.yml` uses the `terrateam` brand. A repository with no configuration file of its own uses the name of the central repository. A repository with a forced configuration in the central repository also uses that name. To set the brand on a server, use `TERRAT_BRAND`. See [Environment variables](/docs/admin/operations/environment-variables).

When the brand changes, the check names change too. Update branch protection rules that require a check by its name.

## Go back to Terrateam

The Terrateam image starts on the migrated database while the `migrations` table of the Terrateam database has no name that the image does not know. A Stategraph release that adds a Terrateam migration closes this window. Then restore the backup, and start the Terrateam image.

On Docker Compose, create the Terrateam container again with `docker compose up -d --force-recreate server`.
