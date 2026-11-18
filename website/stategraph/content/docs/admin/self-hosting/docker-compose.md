---
title: Docker Compose
description: Deploy Stategraph Orchestration with Docker Compose and PostgreSQL, create the first account, and connect GitHub or GitLab.
order: 2
---


Run Stategraph Orchestration and PostgreSQL on one host with Docker Compose, then connect GitHub or GitLab. This is the quickest path, and the reference setup for [self-hosting](/docs/admin/self-hosting), for evaluation, development, and small teams.

This page uses `docker/stategraph/docker-compose.yml` of the [stategraph/stategraph](https://github.com/stategraph/stategraph) repository. It runs the Open Source image, `ghcr.io/stategraph/stategraph-server-oss`. For [Enterprise](/docs/get-started/editions), set `STATEGRAPH_IMAGE=ghcr.io/stategraph/stategraph-server:latest` in `.env`: its setup screen asks for the license key first, and it adds state cost and security scanning.

## Before you begin

- Git
- Docker Engine 20.10 or later
- Docker Compose 2.24 or later
- Port 8080 free on the host

## Quick start

### 1. Get the Compose file

```bash
git clone --depth 1 https://github.com/stategraph/stategraph.git
cd stategraph/docker/stategraph
```

- `docker-compose.yml` runs PostgreSQL and the Stategraph server. Settings go in `.env`, in this directory. The Compose file reads it, and its values win over the defaults.
- `STATEGRAPH_UI_BASE`, the URL that users open, defaults to `http://localhost:8080`. For any other host, set the public HTTPS URL in `.env`.
- Stategraph Orchestration is on. At the first start, the Compose file sets up its database.
- `stop_grace_period: 60s` lets Stategraph finish the requests in progress when it stops.

For Enterprise, create `.env` with the Enterprise image and your license key. Without `STATEGRAPH_LICENSE_KEY`, the setup screen asks for it.

```bash
STATEGRAPH_IMAGE=ghcr.io/stategraph/stategraph-server:latest
STATEGRAPH_LICENSE_KEY=<key>
```

### 2. Start Stategraph

```bash
docker compose up -d
```

### 3. Verify the deployment

```bash
docker compose ps
curl http://localhost:8080/health/live
curl http://localhost:8080/health/ready
```

`/health/live` answers `200` when the web server is up, and `/health/ready` when the migrations are done and the server serves requests. See [Health checks](/docs/admin/operations/health-checks).

### 4. Complete the setup

Open <http://localhost:8080> and create the first admin account on the setup screen. The password needs at least 8 characters. You are then signed in.

To add users, go to **Settings > Admin** in the console, or change to [Google or OIDC sign-in](#authentication).

### 5. Set the public URL

GitHub and GitLab send webhooks to the server, and your runners call it, so the server needs a public HTTPS URL. Put the URL in `.env`:

```bash
STATEGRAPH_PUBLIC_URL=https://stategraph.example.com
STATEGRAPH_UI_BASE=${STATEGRAPH_PUBLIC_URL}
STATEGRAPH_OAUTH_REDIRECT_BASE=${STATEGRAPH_PUBLIC_URL}
```

Your own URL comes from a reverse proxy or a load balancer that terminates TLS in front of port 8080. If the host has no public URL, for example a laptop or a server behind a firewall, use Terratunnel:

1. Open [tunnel.terrateam.dev](https://tunnel.terrateam.dev), and sign in with GitHub or GitLab.
2. Copy your tunnel URL, `https://<name>.tunnel.terrateam.dev`. It is your public URL.
3. Click **Generate API Key**, and copy the key. The page shows it one time.
4. Put the tunnel URL, the key, and the `tunnel` profile in `.env`:

```bash
STATEGRAPH_PUBLIC_URL=https://<name>.tunnel.terrateam.dev
STATEGRAPH_UI_BASE=${STATEGRAPH_PUBLIC_URL}
STATEGRAPH_OAUTH_REDIRECT_BASE=${STATEGRAPH_PUBLIC_URL}
TERRATUNNEL_API_KEY=<key>
COMPOSE_PROFILES=tunnel
```

`COMPOSE_PROFILES=tunnel` makes Docker Compose start `terratunnel`, which forwards each request on your tunnel URL to the server. The tunnel URL stays the same for your account. A new key replaces the old one, so run one stack per key. Terratunnel makes the whole server public at the tunnel URL, and all requests pass through the tunnel service: for production, use your own URL.

Apply the change:

```bash
docker compose up -d
```

Then open the console at your public URL, not `localhost`: the console shows webhook URLs from the address in your browser.

### 6. Connect GitHub or GitLab

For GitHub, open **Get Started > Set up your first repository > Connect GitHub** as the instance admin, and create the App on the **Create** step. GitHub opens with the App filled in, and returns you to the console. Nothing goes into `.env`.

For GitLab, add the credentials of the GitLab application to `.env`, recreate the container, and open **Get Started > Set up your first repository > Connect GitLab**:

```bash
# .env
GITLAB_APP_ID=<application id>
GITLAB_APP_SECRET=<application secret>
GITLAB_ACCESS_TOKEN=<access token>
```

Then follow [Connect GitHub or GitLab](/docs/admin/self-hosting/orchestration) to create the GitLab application, install the GitHub App, and open your first pull request.

## Authentication

Local email and password sign-in is on by default. For single sign-on, set the OAuth variables. Both providers call back on your public URL, so `STATEGRAPH_OAUTH_REDIRECT_BASE` must equal `STATEGRAPH_UI_BASE`.

### Google

In the Google Cloud console, create OAuth credentials with the authorized redirect URI `https://stategraph.example.com/oauth2/google/callback`. Then add to `.env`:

```bash
STATEGRAPH_OAUTH_TYPE=google
STATEGRAPH_OAUTH_CLIENT_ID=your-client-id.apps.googleusercontent.com
STATEGRAPH_OAUTH_CLIENT_SECRET=<client secret>
STATEGRAPH_OAUTH_REDIRECT_BASE=${STATEGRAPH_PUBLIC_URL}
STATEGRAPH_OAUTH_EMAIL_DOMAIN=example.com
```

### OIDC

In your provider, create an application with the redirect URI `https://stategraph.example.com/oauth2/oidc/callback`. Then add to `.env`:

```bash
STATEGRAPH_OAUTH_TYPE=oidc
STATEGRAPH_OAUTH_CLIENT_ID=your-client-id
STATEGRAPH_OAUTH_CLIENT_SECRET=<client secret>
STATEGRAPH_OAUTH_OIDC_ISSUER_URL=https://your-provider.example.com
STATEGRAPH_OAUTH_REDIRECT_BASE=${STATEGRAPH_PUBLIC_URL}
STATEGRAPH_OAUTH_EMAIL_DOMAIN=example.com
```

!!! warning "Restrict the email domain"
    `STATEGRAPH_OAUTH_EMAIL_DOMAIN` defaults to `*`: any identity that your provider authenticates can sign in. While no instance admin exists, the first user to sign in becomes one. Set it to your domain on any public deployment.

Apply the change with `docker compose up -d`. See [Access control](/docs/admin/access-control) for group rules, tenants, and access tokens.

## Environment file

Keep secrets and per-host values out of the Compose file. Put them in `.env`, next to `docker-compose.yml`. Git ignores `.env`, so a `git pull` keeps it.

```bash
# .env
STATEGRAPH_PUBLIC_URL=https://stategraph.example.com
STATEGRAPH_UI_BASE=${STATEGRAPH_PUBLIC_URL}
STATEGRAPH_OAUTH_REDIRECT_BASE=${STATEGRAPH_PUBLIC_URL}

# Single sign-on
# STATEGRAPH_OAUTH_TYPE=google
# STATEGRAPH_OAUTH_CLIENT_ID=...
# STATEGRAPH_OAUTH_CLIENT_SECRET=...
# STATEGRAPH_OAUTH_EMAIL_DOMAIN=example.com
```

!!! note "environment outranks env_file"
    A key under `environment:` in `docker-compose.yml` wins over the same key from `.env`, even with an empty value. Set each variable in one place only. Leave optional variables unset, not empty: several Orchestration variables treat an empty string differently.

## Enable cost estimation

Enterprise only. Cost estimation is off by default. To turn it on, set it in `.env`, and recreate the container:

```bash
# .env
STATEGRAPH_COST_ENABLED=true
```

```bash
docker compose up -d
```

Stategraph then loads the price book into `cloud_pricing` on the `db` volume, in the background, and refreshes it weekly. For verification and air-gapped installs, see [Enable cost estimation](/docs/admin/self-hosting/cost).

## Enable security scanning

Enterprise only. Set `STATEGRAPH_SECURITY=1` in `.env`, and recreate the container. Nothing else is needed. See [Enable security scanning](/docs/admin/self-hosting/security-scanning).

## Production considerations

- HTTPS: terminate TLS in a reverse proxy or load balancer in front of port 8080. Set `STATEGRAPH_UI_BASE` to the `https://` URL, so that cookies get the `Secure` flag.
- Access log: off by default. To see each request in `docker compose logs server`, set `STATEGRAPH_ACCESS_LOG=/dev/stdout`. See [Observability](/docs/admin/operations/observability).

### Use external PostgreSQL

For durability and backups, run the server against a managed PostgreSQL service, with a Compose file of your own for the server only:

```yaml
services:
  server:
    image: ghcr.io/stategraph/stategraph-server-oss:latest
    environment:
      DB_HOST: "postgres.internal.example.com"
      DB_PORT: "5432"
      DB_USER: "stategraph"
      DB_PASS: "${DB_PASSWORD}"
      DB_NAME: "stategraph"
      STATEGRAPH_UI_BASE: "https://stategraph.example.com"
      STATEGRAPH_FDW_USER: "stategraph"
      STATEGRAPH_FDW_PASSWORD: "${DB_PASSWORD}"
      STATEGRAPH_FDW_PROVISIONER_USER: "stategraph"
      STATEGRAPH_FDW_PROVISIONER_PASSWORD: "${DB_PASSWORD}"
```

The `STATEGRAPH_FDW_*` lines turn on Orchestration with the same database user. Create the `stategraph` database before the first start. For the rights of the database user, see [Databases](/docs/admin/self-hosting#databases).

## Updating

```bash
git pull
docker compose pull
docker compose up -d
```

For production, pin a version, not `latest`, in `.env`:

```bash
STATEGRAPH_IMAGE=ghcr.io/stategraph/stategraph-server-oss:<version>
```

Use the latest release on the [releases page](https://github.com/stategraph/releases/releases). For the start sequence and image signatures, see [Upgrades](/docs/admin/operations/upgrades).

## Troubleshooting

### Container does not start

```bash
docker compose logs server
docker compose logs db
```

A sign-in provider with a bad configuration or a missing `STATEGRAPH_UI_BASE` stops the start. The log gives the reason.

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
- An error for the role `stategraph_mql`, on a `db` volume from a setup without Orchestration. Give the roles their passwords one time, then recreate the container:

```bash
docker compose exec db psql -U stategraph -d stategraph \
  -c "ALTER ROLE stategraph_mql LOGIN PASSWORD 'stategraph_mql';" \
  -c "ALTER ROLE stategraph_provisioner LOGIN PASSWORD 'stategraph_provisioner';"
```

## Next steps

- [Import your Terraform state](/docs/infrastructure-as-a-database/import-state)
- [Connect GitHub or GitLab](/docs/admin/self-hosting/orchestration)
- [Environment variables](/docs/admin/operations/environment-variables)
