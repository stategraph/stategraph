---
title: Self-hosted Open Source
description: Run Stategraph Orchestration Open Source with Docker Compose, connect GitHub or GitLab, and get your first plan on a pull request.
order: 3
---


Run the open-source edition of Stategraph, `ghcr.io/stategraph/stategraph-server-oss`, with Docker Compose, connect GitHub or GitLab, and get your first plan and apply on a pull request. For Kubernetes, ECS, and Cloud Run, see [Self-hosting](/docs/admin/self-hosting).

The image is built from the [stategraph/stategraph](https://github.com/stategraph/stategraph) repository under the MPL-2.0 license, and needs no license key. It runs Orchestration: pull request plans and applies, policy checks, cost estimates in pull requests, and drift detection. It allows up to 3 active users per month per GitHub or GitLab installation, with unlimited runs. It does not include Infrastructure as a Database. See [Editions](/docs/get-started/editions).

## Before you begin

- Git, Docker Engine 20.10 or later, and Docker Compose 2.24 or later.
- Port 8080 free on the host.
- For GitHub, admin rights in the GitHub organization, to create and install a GitHub App.
- For GitLab, gitlab.com or self-managed GitLab 18.1 or later (see [GitLab version](/docs/admin/self-hosting/orchestration#gitlab-version)), a group (personal namespaces are not supported), and the rights to create an access token, add a project webhook, and change the project's CI/CD settings.
- To connect GitHub or GitLab, a URL that they can reach over HTTPS. Without one, a GitHub or gitlab.com account for Terratunnel.

## Start Stategraph

```bash
git clone --depth 1 https://github.com/stategraph/stategraph.git
cd stategraph/docker/stategraph
docker compose up -d
```

The Compose file runs PostgreSQL and the Stategraph server with Orchestration on, at <http://localhost:8080>. Your settings go in `.env`, in this directory.

Check that Stategraph is ready:

```bash
curl -f http://localhost:8080/health/ready
```

At start, Stategraph migrates the `stategraph` and `terrateam` databases, then serves requests. `/health/ready` returns a non-200 status until the migrations finish. See [Health checks](/docs/admin/operations/health-checks). If Orchestration does not start, `docker compose logs -f server` gives the cause.

## First login

Open [http://localhost:8080](http://localhost:8080). The first visit shows the setup screen. With local authentication, the default, it creates the first account, with a password of at least 8 characters, and signs you in as the instance admin. For Google or OIDC sign-in, see [Access control](/docs/admin/access-control).

## Connect GitHub or GitLab

### 1. Set the public URL

GitHub and GitLab send webhooks to the server, and your runners call it, so the server needs a public HTTPS URL. Put the URL in `.env`:

```bash
STATEGRAPH_UI_BASE=https://stategraph.example.com
STATEGRAPH_OAUTH_REDIRECT_BASE=https://stategraph.example.com
```

Your own URL comes from a reverse proxy or a load balancer that terminates TLS in front of port 8080. If the host has no public URL, for example a laptop or a server behind a firewall, use Terratunnel:

1. Open [tunnel.terrateam.dev](https://tunnel.terrateam.dev), and sign in with GitHub or GitLab.
2. Copy your tunnel URL, `https://<name>.tunnel.terrateam.dev`. It is your public URL.
3. Click **Generate API Key**, and copy the key. The page shows it one time.
4. Put the tunnel URL, the key, and the `tunnel` profile in `.env`:

```bash
STATEGRAPH_UI_BASE=https://<name>.tunnel.terrateam.dev
STATEGRAPH_OAUTH_REDIRECT_BASE=https://<name>.tunnel.terrateam.dev
TERRATUNNEL_API_KEY=<key>
COMPOSE_PROFILES=tunnel
```

`COMPOSE_PROFILES=tunnel` makes Docker Compose start `terratunnel`, which forwards each request on your tunnel URL to the server. The tunnel URL stays the same for your account. A new key replaces the old one, so run one stack per key. Terratunnel makes the whole server public at the tunnel URL, and all requests pass through the tunnel service: for production, use your own URL.

| Variable | Purpose |
|----------|---------|
| `STATEGRAPH_UI_BASE` | The public URL of the console. The webhook, callback, and runner URLs derive from it |
| `STATEGRAPH_OAUTH_REDIRECT_BASE` | Base of the OAuth callback URLs, including those of the GitHub App |

`TERRAT_DB_*` need no setting: Orchestration uses the `DB_*` values with the database name `terrateam`. Telemetry is on by default. To turn it off, set `TERRAT_TELEMETRY_LEVEL=disabled`. Leave optional variables unset, not empty: for some, an empty value differs from an absent one. All variables are in [Environment variables](/docs/admin/operations/environment-variables).

Apply the change:

```bash
docker compose up -d
```

Then open the console at your public URL, not `localhost`: the console shows webhook URLs from the address in your browser.

### 2. Create the GitHub App

Skip this step for GitLab.

Open **Get Started > Set up your first repository > Connect GitHub**. The first step is **Create**:

1. Keep the App name the console suggests, or type your own. GitHub requires a name no other App uses. To create the App under an organization, enter its name.
2. Click **Create on GitHub**. GitHub opens with the App filled in: webhook URL, callback URLs, permissions, and events.
3. Create the App on GitHub. GitHub returns you to the console.

The console shows "The App is created. Starting the orchestration engine." for a few seconds, then moves to the **Install** step. Nothing goes into `.env`. To bring an App that you manage outside the console instead, set the `GITHUB_*` variables: see [Enable Orchestration](/docs/admin/self-hosting/orchestration#connect-github).

### 2. Add the GitLab application

Skip this step for GitHub.

The setup wizard tells you what to create in GitLab, and collects the values. Run it one time, on any computer with a browser:

```bash
docker run --rm -p 3000:3000 ghcr.io/stategraph/orchestration-setup:latest
```

1. Open [http://localhost:3000](http://localhost:3000). On the webhook access step, choose the public server option, and enter the host name of your public URL. With Terratunnel, enter the host name of your tunnel URL, and do not choose the Terratunnel option of the wizard: it generates a new key, which replaces the key in your `.env`.
2. Create a dedicated GitLab user for Stategraph.
3. As that user, create a personal access token with the `api` scope, and enter it with your GitLab instance URL.
4. As the same user, in **Preferences > Applications**, add an application with the `api` scope and the redirect URI that the wizard shows, `<public-url>/api/v1/gitlab/callback`. Enter its application ID and secret.

Add the three settings that the wizard shows to `.env`:

```bash
GITLAB_APP_ID=<application id>
GITLAB_APP_SECRET=<application secret>
GITLAB_ACCESS_TOKEN=<access token>
```

When `GITLAB_APP_ID` is set, the other two are required. Leave out the wizard's other settings: your public URL is already in `.env`. On self-managed GitLab, see [Self-managed GitLab](/docs/admin/self-hosting/orchestration#self-managed-gitlab) for the two URL variables that the wizard does not write, and the CI template to mirror.

Restart, and follow the server log:

```bash
docker compose up -d
docker compose logs -f server
```

A missing GitLab variable logs a `CONFIG : ERROR` line that names it. Each GitLab group gets its own access token and webhook secret later, when you connect it in the console.

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

- [Docker Compose](/docs/admin/self-hosting/docker-compose): sign-in, updates, and the other settings of this Compose file.
- [Self-hosting](/docs/admin/self-hosting): Kubernetes, Amazon ECS, and Google Cloud Run, and the move to Enterprise.
- [Enable Orchestration](/docs/admin/self-hosting/orchestration): the `GITHUB_*` variables, GitLab credential rotation, self-managed GitLab, and managed PostgreSQL.
- [Environment variables](/docs/admin/operations/environment-variables): all settings that Stategraph reads.
- [Editions](/docs/get-started/editions): the Open Source limits, and how to get Enterprise.
