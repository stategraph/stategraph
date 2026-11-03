---
title: Docker Compose
description: Deploy Stategraph with Docker Compose and PostgreSQL, then set up the first account, sign-in, and optional features.
order: 2
---


Run Stategraph and PostgreSQL on one host with Docker Compose, and set up sign-in and the optional features. This is the quickest path, and the reference setup for [self-hosting](/docs/admin/self-hosting), for evaluation, development, and small teams.

## Before you begin

- Docker Engine 20.10 or later
- Docker Compose 2.23.1 or later
- Port 8080 free on the host

## Quick start

### 1. Create a project directory

```bash
mkdir stategraph && cd stategraph
```

### 2. Create docker-compose.yml

```yaml
services:
  db:
    image: postgres:17-alpine
    user: postgres
    environment:
      POSTGRES_PASSWORD: "stategraph"
      POSTGRES_USER: "stategraph"
      POSTGRES_DB: "stategraph"
    healthcheck:
      test: ["CMD", "pg_isready", "-h", "localhost", "-p", "5432", "-d", "stategraph", "-U", "stategraph"]
      interval: 3s
      timeout: 3s
      retries: 5
    volumes:
      - db:/var/lib/postgresql/data/
    configs:
      - source: orchestration-db
        target: /docker-entrypoint-initdb.d/orchestration.sql
    networks:
      - stategraph

  server:
    image: ghcr.io/stategraph/stategraph-server:latest
    env_file:
      - path: .env
        required: false
    environment:
      DB_HOST: "db"
      DB_PORT: "5432"
      DB_USER: "stategraph"
      DB_PASS: "stategraph"
      DB_NAME: "stategraph"
      STATEGRAPH_UI_BASE: "http://localhost:8080"
      STATEGRAPH_ORCHESTRATION_ENABLED: "true"
      STATEGRAPH_FDW_PASSWORD: "stategraph_mql"
      STATEGRAPH_FDW_PROVISIONER_PASSWORD: "stategraph_provisioner"
    ports:
      - "8080:8080"
    stop_grace_period: 60s
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health/ready"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 120s
    depends_on:
      db:
        condition: service_healthy
    networks:
      - stategraph

configs:
  orchestration-db:
    content: |
      CREATE DATABASE terrateam;
      CREATE ROLE stategraph_mql LOGIN PASSWORD 'stategraph_mql';
      CREATE ROLE stategraph_provisioner LOGIN PASSWORD 'stategraph_provisioner';

networks:
  stategraph:

volumes:
  db:
```

- `STATEGRAPH_UI_BASE` is the URL that users open. Keep `http://localhost:8080` for a local trial. Otherwise, set the public HTTPS URL.
- `STATEGRAPH_ORCHESTRATION_ENABLED` turns on Stategraph Orchestration. At the first start of a new `db` volume, the `orchestration-db` script creates the `terrateam` database of Orchestration and its two database roles. The two `STATEGRAPH_FDW_*` passwords are the passwords of these roles: change both places together.
- `stop_grace_period: 60s` lets Stategraph finish the requests in progress when it stops.

### 3. Start Stategraph

```bash
docker compose up -d
```

### 4. Verify the deployment

```bash
docker compose ps
curl http://localhost:8080/health/live
curl http://localhost:8080/health/ready
```

`/health/live` answers `200` when the web server is up, and `/health/ready` when the migrations are done and the server serves requests. See [Health checks](/docs/admin/operations/health-checks).

### 5. Complete the setup

Open <http://localhost:8080> and create the first admin account on the setup screen. The password needs at least 8 characters. You are then signed in.

To add users, go to **Settings > Admin** in the console, or change to [Google or OIDC sign-in](#authentication).

## Authentication

Local email and password sign-in is on by default. For single sign-on, set the OAuth variables. Both providers call back on your public URL, so `STATEGRAPH_OAUTH_REDIRECT_BASE` must equal `STATEGRAPH_UI_BASE`.

### Google

In the Google Cloud console, create OAuth credentials with the authorized redirect URI `https://stategraph.example.com/oauth2/google/callback`. Then add:

```yaml
services:
  server:
    environment:
      STATEGRAPH_OAUTH_TYPE: "google"
      STATEGRAPH_OAUTH_CLIENT_ID: "your-client-id.apps.googleusercontent.com"
      STATEGRAPH_OAUTH_CLIENT_SECRET: "${GOOGLE_CLIENT_SECRET}"
      STATEGRAPH_OAUTH_REDIRECT_BASE: "https://stategraph.example.com"
      STATEGRAPH_OAUTH_EMAIL_DOMAIN: "example.com"
```

### OIDC

In your provider, create an application with the redirect URI `https://stategraph.example.com/oauth2/oidc/callback`. Then add:

```yaml
services:
  server:
    environment:
      STATEGRAPH_OAUTH_TYPE: "oidc"
      STATEGRAPH_OAUTH_CLIENT_ID: "your-client-id"
      STATEGRAPH_OAUTH_CLIENT_SECRET: "${OIDC_CLIENT_SECRET}"
      STATEGRAPH_OAUTH_OIDC_ISSUER_URL: "https://your-provider.example.com"
      STATEGRAPH_OAUTH_REDIRECT_BASE: "https://stategraph.example.com"
      STATEGRAPH_OAUTH_EMAIL_DOMAIN: "example.com"
```

!!! warning "Restrict the email domain"
    `STATEGRAPH_OAUTH_EMAIL_DOMAIN` defaults to `*`: any identity that your provider authenticates can sign in. While no instance admin exists, the first user to sign in becomes one. Set it to your domain on any public deployment.

Apply the change with `docker compose up -d`. See [Access control](/docs/admin/access-control) for group rules, tenants, and access tokens.

## Environment file

Keep secrets and per-host values out of the Compose file. Put them in `.env`, next to `docker-compose.yml`, and keep `.env` out of version control. The Compose file loads `.env` through `env_file`. To reference a secret from `.env` or your secrets manager, use `${VAR}` interpolation.

```bash
# .env
STATEGRAPH_UI_BASE=https://stategraph.example.com
STATEGRAPH_OAUTH_REDIRECT_BASE=https://stategraph.example.com

# Single sign-on
# STATEGRAPH_OAUTH_TYPE=google
# STATEGRAPH_OAUTH_CLIENT_ID=...
# STATEGRAPH_OAUTH_CLIENT_SECRET=...
# STATEGRAPH_OAUTH_EMAIL_DOMAIN=example.com

# External PostgreSQL
# DB_HOST=postgres.internal.example.com
# DB_PORT=5432
# DB_USER=stategraph
# DB_PASS=...
# DB_NAME=stategraph
```

!!! note "environment outranks env_file"
    A key under `environment:` in `docker-compose.yml` wins over the same key from `.env`, even with an empty value. Set each variable in one place only. Leave optional variables unset, not empty: several Orchestration variables treat an empty string differently.

## Enable cost estimation

Cost estimation is off by default. To turn it on, set it in `.env`, and recreate the container:

```bash
# .env
STATEGRAPH_COST_ENABLED=true
```

```bash
docker compose up -d
```

Stategraph then loads the price book into `cloud_pricing` on the `db` volume, in the background, and refreshes it weekly. For verification and air-gapped installs, see [Enable cost estimation](/docs/admin/self-hosting/cost).

## Connect GitHub or GitLab

Stategraph Orchestration is on from the first start. To connect your provider:

1. Set `STATEGRAPH_UI_BASE` and `STATEGRAPH_OAUTH_REDIRECT_BASE` to your public URL. The webhook and callback URLs derive from them, so GitHub or GitLab must reach that URL over HTTPS.
2. For GitLab, add the credentials to `.env`, and recreate the container with `docker compose up -d`:

```bash
# .env
GITLAB_APP_ID=...
GITLAB_APP_SECRET=...
GITLAB_ACCESS_TOKEN=...
```

3. For GitHub, sign in as the instance admin, open **Get Started > Set up your first repository > Connect GitHub**, and create the App on the **Create** step. GitHub opens with the App filled in, and returns you to the console.

To bring a GitHub App that you manage outside the console, set the six `GITHUB_*` variables in `.env` instead. They win over an App created from the console. For self-managed GitLab, also set `GITLAB_API_BASE_URL` and `GITLAB_WEB_BASE_URL`. For the GitHub App by hand, the GitLab credentials, GitLab groups, and the two roles, see [Enable Orchestration](/docs/admin/self-hosting/orchestration).

To turn Orchestration off, set `STATEGRAPH_ORCHESTRATION_ENABLED` to `"false"` in `docker-compose.yml`, and recreate the container.

PostgreSQL runs the `orchestration-db` script only at the first start of a new `db` volume. On an existing volume, create what is missing one time, with the passwords of `docker-compose.yml`, or put the passwords of the existing roles in `docker-compose.yml`. Then recreate the container:

```bash
docker compose exec db psql -U stategraph -d stategraph \
  -c "CREATE DATABASE terrateam OWNER stategraph;" \
  -c "CREATE ROLE stategraph_mql LOGIN PASSWORD 'stategraph_mql';" \
  -c "CREATE ROLE stategraph_provisioner LOGIN PASSWORD 'stategraph_provisioner';"
```

## Enable security scanning

Set `STATEGRAPH_SECURITY=1` in `.env`, and recreate the container. Nothing else is needed. See [Enable security scanning](/docs/admin/self-hosting/security-scanning).

## Production considerations

- HTTPS: terminate TLS in a reverse proxy or load balancer in front of port 8080. Set `STATEGRAPH_UI_BASE` to the `https://` URL, so that cookies get the `Secure` flag.
- Access log: off by default. To see each request in `docker compose logs server`, set `STATEGRAPH_ACCESS_LOG=/dev/stdout`. See [Observability](/docs/admin/operations/observability).

### Use external PostgreSQL

For durability and backups, point the server at a managed PostgreSQL service, and remove the `db` service and the `configs` block:

```yaml
services:
  server:
    image: ghcr.io/stategraph/stategraph-server:latest
    environment:
      DB_HOST: "postgres.internal.example.com"
      DB_PORT: "5432"
      DB_USER: "stategraph"
      DB_PASS: "${DB_PASSWORD}"
      DB_NAME: "stategraph"
      STATEGRAPH_UI_BASE: "https://stategraph.example.com"
      STATEGRAPH_ORCHESTRATION_ENABLED: "true"
      STATEGRAPH_FDW_PASSWORD: "${FDW_PASSWORD}"
      STATEGRAPH_FDW_PROVISIONER_PASSWORD: "${FDW_PROVISIONER_PASSWORD}"
```

Create the `stategraph` database and the two Orchestration roles before the first start. The FDW bridge needs superuser rights on managed PostgreSQL: see [Database](/docs/admin/self-hosting/orchestration#database).

## Updating

```bash
docker compose pull
docker compose up -d
```

For production, pin a version, not `latest`:

```yaml
services:
  server:
    image: ghcr.io/stategraph/stategraph-server:2.5.7
```

For versions, see the [releases page](https://github.com/stategraph/releases/releases). For the start sequence and image signatures, see [Upgrades](/docs/admin/operations/upgrades).

## Troubleshooting

### Container does not start

```bash
docker compose logs server
docker compose logs db
```

A misconfigured sign-in provider, a missing `STATEGRAPH_UI_BASE`, or `STATEGRAPH_ORCHESTRATION_ENABLED=true` without `STATEGRAPH_FDW_PASSWORD` stops the start. The log gives the reason.

### Database connection errors

```bash
docker compose ps
```

The `db` service must show `healthy`. The `server` service waits for it through `depends_on`. Also check that `DB_USER`, `DB_PASS`, and `DB_NAME` match the PostgreSQL configuration.

### Port already in use

Stop the service that uses port 8080, or map another host port:

```yaml
ports:
  - "8081:8080"
```

### Orchestration does not start

Only the container log shows the cause. With `STATEGRAPH_ORCHESTRATION_ENABLED=true`, as in this setup, a failed start of Orchestration stops the server, which restarts a few seconds later. In the log, look for:

- `GITHUB_APP : WAITING`: there is no GitHub App yet. Create it from the console, or set the `GITHUB_*` variables.
- `GITHUB_WEBHOOK_SECRET must be set`: `GITHUB_APP_ID` is set without `GITHUB_WEBHOOK_SECRET`.
- A `CONFIG : ERROR` line that names a GitLab variable: `GITLAB_APP_ID` is set without `GITLAB_APP_SECRET` or `GITLAB_ACCESS_TOKEN`.
- A `CREATE DATABASE` statement: run it.

## Next steps

- [Import your Terraform state](/docs/get-started/quickstart/import-state)
- [Enable Orchestration](/docs/admin/self-hosting/orchestration)
- [Environment variables](/docs/admin/operations/environment-variables)
