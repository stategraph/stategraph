---
title: Self-hosted Enterprise
description: Run the Stategraph Enterprise build with Docker Compose and a license key, connect GitHub or GitLab, and get your first plan on a pull request.
order: 4
---


!!! note "Enterprise build"
    This page needs a license key. The free edition, which is what Terrateam self-hosted ran, is [Self-hosted Open Source](/docs/get-started/quickstart/self-hosted-open-source). [Editions](/docs/get-started/editions) compares the two.

Run the Enterprise build of Stategraph, `ghcr.io/stategraph/stategraph-server`, with Docker Compose, connect GitHub or GitLab, and get your first plan and apply on a pull request. For Kubernetes, ECS, and Cloud Run, see [Self-hosting](/docs/admin/self-hosting). For the free open-source edition, see [Self-hosted Open Source](/docs/get-started/quickstart/self-hosted-open-source).

The Enterprise build needs a license key to complete the first-time setup, and checks it at each start after that. Put it in `.env` as `STATEGRAPH_LICENSE_KEY=<key>` before the first start, or enter it on the License step of the setup screen. [Contact sales](https://stategraph.com/contact) for a key. See [Editions](/docs/get-started/editions).

## Before you begin

- Docker Engine 20.10 or later, and Docker Compose 2.23.1 or later.
- Port 8080 free on the host.
- For Orchestration, a URL that GitHub or GitLab can reach over HTTPS.
- For GitHub, admin rights in the GitHub organization, to create and install a GitHub App.
- For GitLab, gitlab.com or self-managed GitLab 18.1 or later (see [GitLab version](/docs/admin/self-hosting/orchestration#gitlab-version)), a group (personal namespaces are not supported), and the rights to create an access token, add a project webhook, and change the project's CI/CD settings.

## Create the Compose project

1. Create a directory.
2. In it, create `docker-compose.yml`:

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
      - .env
    environment:
      DB_HOST: "db"
      DB_PORT: "5432"
      DB_USER: "stategraph"
      DB_PASS: "stategraph"
      DB_NAME: "stategraph"
      STATEGRAPH_ORCHESTRATION_ENABLED: "true"
      STATEGRAPH_FDW_PASSWORD: "stategraph_mql"
      STATEGRAPH_FDW_PROVISIONER_PASSWORD: "stategraph_provisioner"
    ports:
      - "8080:8080"
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

`STATEGRAPH_ORCHESTRATION_ENABLED` turns on Stategraph Orchestration. At the first start of the `db` volume, the `orchestration-db` script creates the `terrateam` database of Orchestration and its two database roles: `stategraph_mql`, through which Stategraph reads Orchestration's data, and `stategraph_provisioner`, through which the console writes the GitHub App and the GitLab group connections. The two `STATEGRAPH_FDW_*` passwords are the passwords of these roles: change both places together.

3. Create `.env`:

```bash
STATEGRAPH_UI_BASE=http://localhost:8080
```

`STATEGRAPH_UI_BASE`, the public URL of the console, is required. All other settings go into `.env`. Leave optional variables unset, not empty: for some, an empty value differs from an absent one.

## Start and verify

1. Start the services:

```bash
docker compose up -d
```

2. Check the containers:

```bash
docker compose ps
```

3. Check that Stategraph is ready:

```bash
curl -f http://localhost:8080/health/ready
```

At start, Stategraph migrates the `stategraph` database, then serves requests. `/health/ready` returns a non-200 status until the migrations finish. `/health/live` answers as soon as the web server is up. See [Health checks](/docs/admin/operations/health-checks).

## First login

Open [http://localhost:8080](http://localhost:8080). The first visit shows the setup screen. It asks for the license key first, unless `STATEGRAPH_LICENSE_KEY` is set in `.env`. With local authentication, the default, it then creates the first account, with a password of at least 8 characters, and signs you in as the instance admin.

As on Stategraph Cloud, you can connect GitHub or GitLab, or import your state. To connect, follow the next section. For Google or OIDC sign-in, see [Access control](/docs/admin/access-control).

## Connect GitHub or GitLab

### 1. Set the public URL

`STATEGRAPH_UI_BASE` becomes the public URL. Replace `.env` with:

```bash
STATEGRAPH_UI_BASE=https://stategraph.example.com
STATEGRAPH_OAUTH_REDIRECT_BASE=https://stategraph.example.com
```

| Variable | Purpose |
|----------|---------|
| `STATEGRAPH_OAUTH_REDIRECT_BASE` | Base of the OAuth callback URLs, including those of the GitHub App. Default `http://localhost:<port>`, which GitHub cannot reach |

The webhook and runner URLs derive from `STATEGRAPH_UI_BASE`, and `TERRAT_DB_*` need no setting: Orchestration uses the `DB_*` values with the database name `terrateam`. Telemetry is on by default. To turn it off, set `TERRAT_TELEMETRY_LEVEL=disabled`. All variables are in [Environment variables](/docs/admin/operations/environment-variables).

For GitHub, nothing else goes into `.env`: you create the App from the console in step 3. For GitLab, add the application and the bot user now.

#### GitLab

The setup wizard tells you what to create in GitLab, and collects the values. Run it one time, on any computer with a browser:

```bash
docker run --rm -p 3000:3000 ghcr.io/stategraph/orchestration-setup:latest
```

1. Open [http://localhost:3000](http://localhost:3000). When asked how GitLab reaches your server, enter the host name of your public URL.
2. Create a dedicated GitLab user for Stategraph.
3. As that user, create a personal access token with the `api` scope, and enter it with your GitLab instance URL.
4. As the same user, in **Preferences > Applications**, add an application with the `api` scope and the redirect URI that the wizard shows, `<public-url>/api/v1/gitlab/callback`. Enter its application ID and secret.

The wizard then shows the settings for `.env`:

```bash
GITLAB_APP_ID=<application id>
GITLAB_APP_SECRET=<application secret>
GITLAB_ACCESS_TOKEN=<access token>
```

When `GITLAB_APP_ID` is set, the other two are required. Each GitLab group gets its own access token and webhook secret later, when you connect it in the console. On self-managed GitLab, see [Self-managed GitLab](/docs/admin/self-hosting/orchestration#self-managed-gitlab) for the two URL variables that the wizard does not write, and the CI template to mirror.

### 2. Restart

Restart, and follow the server log:

```bash
docker compose up -d
docker compose logs -f server
```

Orchestration migrates the `terrateam` database at start. If Orchestration does not start, the log gives the cause. A missing GitLab variable logs a `CONFIG : ERROR` line that names it.

### 3. Create the GitHub App

Sign in to the console as the instance admin, and open **Get Started > Set up your first repository > Connect GitHub**. The first step is **Create**:

1. Keep the App name the console suggests, or type your own. GitHub requires a name no other App uses. To create the App under an organization, enter its name.
2. Click **Create on GitHub**. GitHub opens with the App filled in: webhook URL, callback URLs, permissions, and events.
3. Create the App on GitHub. GitHub returns you to the console.

The console shows "The App is created. Starting the orchestration engine." for a few seconds, then moves to the **Install** step. To bring an App that you manage outside the console instead, set the `GITHUB_*` variables: see [Enable Orchestration](/docs/admin/self-hosting/orchestration#connect-github).

## Your first pull request

From here, the flow is the same as on [Stategraph Cloud](/docs/get-started/quickstart/cloud), which has the GitHub and GitLab steps, the workflow and pipeline files, the example repository, and what to check when no plan starts. Runs execute on your GitHub Actions or GitLab CI runners. The server only dispatches them.

### GitHub

1. In the console, open **Get Started > Set up your first repository > Connect GitHub**. On the **Install** step, click **Install on GitHub**, and install the App on the organization that holds your repositories.
2. Claim the installation:
    - An instance admin sees every unclaimed installation.
    - A tenant admin who is not an instance admin verifies with GitHub first, and sees only installations on organizations that they administer.
3. Pick a repository that the App can access, or fork the example repository.
4. Add `.github/workflows/terrateam.yml` to the default branch.
5. Open a pull request that changes a `.tf` file. Your GitHub App posts the plan comment.
6. Comment `stategraph apply`, then merge.

### GitLab

1. In the console, open **Get Started > Set up your first repository > Connect GitLab**. This needs admin rights on the tenant.
2. Enter the GitLab URL and group, the repository, and an access token with the `api` scope. In GitLab, add the project webhook to `<public-url>/api/v1/gitlab/events` with the secret that the wizard shows one time, and set the minimum role to use pipeline variables to Developer.
3. Add the `.gitlab-ci.yml` that the wizard shows to the default branch.
4. Create a branch from the default branch, change a `.tf` file, and open a merge request. The owner of the group's access token posts the plan comment.
5. Comment `stategraph apply`, then merge.

## Next steps

- [Self-hosting](/docs/admin/self-hosting): other deployments and upgrades.
- [Enable Orchestration](/docs/admin/self-hosting/orchestration): the `GITHUB_*` variables, GitLab credential rotation, self-managed GitLab, and managed PostgreSQL.
- [Environment variables](/docs/admin/operations/environment-variables): all settings that Stategraph reads.
- [Access control](/docs/admin/access-control): Google, OIDC, tenants, and API access tokens.
- [Import your state](/docs/get-started/quickstart/import-state): use Infrastructure as a Database on this server.
