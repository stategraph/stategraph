---
title: Self-hosted
description: Run Stategraph Open Source or Enterprise with Docker Compose, connect GitHub or GitLab, and get your first plan on a pull request.
order: 3
---


Run Stategraph with Docker Compose, connect GitHub or GitLab, and get your first plan and apply on a pull request. For Kubernetes, ECS, and Cloud Run, see [Self-hosting](/docs/admin/self-hosting).

The Compose file runs Open Source, `ghcr.io/stategraph/stategraph-server-oss`, by default. Open Source is MPL-2.0 licensed and needs no license key. It runs Orchestration: pull request plans and applies, policy checks, cost estimates in pull requests, and drift detection. It does not include Infrastructure as a Database.

Enterprise, `ghcr.io/stategraph/stategraph-server`, adds the Enterprise features. It needs a license key: [contact sales](https://stategraph.com/contact) for one. See [Editions](/docs/get-started/editions).

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
```

Your settings go in `.env`, in this directory. For Enterprise, create `.env` with the Enterprise image and your license key:

```bash
STATEGRAPH_IMAGE=ghcr.io/stategraph/stategraph-server:latest
STATEGRAPH_LICENSE_KEY=<key>
```

Enterprise checks the key at each start. Without `STATEGRAPH_LICENSE_KEY`, the setup screen asks for it. Then start:

```bash
docker compose up -d
```

The Compose file runs PostgreSQL and the Stategraph server with Orchestration on, at <http://localhost:8080>.

Check that Stategraph is ready:

```bash
curl -f http://localhost:8080/health/ready
```

`/health/ready` returns a non-200 status until Stategraph is ready. See [Health checks](/docs/admin/operations/health-checks). If Stategraph does not start, `docker compose logs -f server` gives the cause.

## First login

Open [http://localhost:8080](http://localhost:8080). The first visit shows the setup screen. On Enterprise, it asks for the license key first, unless `STATEGRAPH_LICENSE_KEY` is set in `.env`. With local authentication, the default, it creates the first account, with a password of at least 8 characters, and signs you in as the instance admin. For Google or OIDC sign-in, see [Access control](/docs/admin/access-control).

## Connect GitHub or GitLab

### 1. Set the public URL

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

| Variable | Purpose |
|----------|---------|
| `STATEGRAPH_UI_BASE` | The public URL of the console. The webhook, callback, and runner URLs derive from it |
| `STATEGRAPH_OAUTH_REDIRECT_BASE` | Base of the OAuth callback URLs, including those of the GitHub App |

Telemetry is on by default. To turn it off, set `TERRAT_TELEMETRY_LEVEL=disabled`. Leave optional variables unset, not empty: for some, an empty value differs from an absent one. All variables are in [Environment variables](/docs/admin/operations/environment-variables).

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

The console then moves to the **Install** step. Nothing goes into `.env`. To bring an App that you manage outside the console instead, set the `GITHUB_*` variables: see [Enable Orchestration](/docs/admin/self-hosting/orchestration#connect-github).

### 2. Add the GitLab application

Skip this step for GitHub.

1. Create a dedicated GitLab user for Stategraph.
2. As that user, create a personal access token with the `api` scope.
3. As the same user, in **Preferences > Applications**, add an application with the `api` scope and the redirect URI `<public-url>/api/v1/gitlab/callback`. Copy its application ID and secret.

Add the three values to `.env`:

```bash
GITLAB_APP_ID=<application id>
GITLAB_APP_SECRET=<application secret>
GITLAB_ACCESS_TOKEN=<access token>
```

When `GITLAB_APP_ID` is set, the other two are required. On self-managed GitLab, also set the two URL variables and mirror the CI template: see [Self-managed GitLab](/docs/admin/self-hosting/orchestration#self-managed-gitlab).

Restart, and follow the server log:

```bash
docker compose up -d
docker compose logs -f server
```

A missing GitLab variable logs a `CONFIG : ERROR` line that names it. Each GitLab group gets its own access token and webhook secret later, when you connect it in the console.

## Your first pull request

Runs execute on your GitHub Actions or GitLab CI runners. The server only dispatches them.

### GitHub

1. In the console, open **Get Started > Set up your first repository > Connect GitHub**. On the **Install** step, click **Install on GitHub**, and install the App on the organization that holds your repositories.
2. Claim the installation:
    - An instance admin sees every unclaimed installation.
    - A tenant admin who is not an instance admin verifies with GitHub first, and sees only installations on organizations that they administer.
3. Pick a repository that the App can access. To try Orchestration without cloud credentials, fork the [example repository](https://github.com/stategraph/kick-the-tires/fork), and enable workflows in the **Actions** tab of the fork.
4. Add the [workflow file](#workflow-file) to the default branch.
5. Open a pull request that changes a `.tf` file. Your GitHub App posts the plan comment.
6. Comment `stategraph apply`, then merge.

### GitLab

1. In the console, open **Get Started > Set up your first repository > Connect GitLab**. This needs admin rights on the tenant.
2. Enter the GitLab URL and group, the repository, and an access token with the `api` scope. In GitLab, add the project webhook to `<public-url>/api/v1/gitlab/events` with the secret that the wizard shows one time, and set the minimum role to use pipeline variables to Developer.
3. Add the `.gitlab-ci.yml` that the wizard shows to the default branch.
4. Create a branch from the default branch, change a `.tf` file, and open a merge request. The owner of the group's access token posts the plan comment.
5. Comment `stategraph apply`, then merge.

### Workflow file

Create `.github/workflows/stategraph.yml` on the default branch. Keep the file name and the action as shown:

```yaml
name: 'Stategraph'
on:
  workflow_dispatch:
    inputs:
      # The work-token and api-base-url are passed in by the backend
      work-token:
        description: 'Work Token'
        required: true
      api-base-url:
        description: 'API Base URL'
      environment:
        description: 'Environment in which to run the action'
        type: environment
      runs_on:
        description: 'runs-on configuration'
        type: string
        default: '"ubuntu-latest"'
jobs:
  stategraph:
    permissions: # Required to pass credentials to the action
      id-token: write
      contents: read
    runs-on: ${{ fromJSON(github.event.inputs.runs_on) }}
    timeout-minutes: 1440
    name: Stategraph
    environment: '${{ github.event.inputs.environment }}'
    steps:
      - uses: actions/checkout@v4
      - name: Run Stategraph
        id: stategraph
        uses: terrateamio/action@v1
        with:
          work-token: '${{ github.event.inputs.work-token }}'
          api-base-url: '${{ github.event.inputs.api-base-url }}'
        env:
          SECRETS_CONTEXT: ${{ toJson(secrets) }}
          VARIABLES_CONTEXT: ${{ toJson(vars) }}
```

The example repository already has this file.

### If no plan starts

- On GitHub, check that GitHub Actions is enabled and that the workflow file is on the default branch.
- On GitHub, check the **Actions** tab for a run marked **Action required**. Select the run and select **Approve and run**.
- On GitLab, check that the source branch contains `.gitlab-ci.yml` and that the minimum role to use pipeline variables is Developer.
- Comment `stategraph repo-config` to see the configuration that Orchestration derived for the repository.
- When a run fails, the pull request comment names the cause. Fix it and comment `stategraph plan`.

## Next steps

- [Docker Compose](/docs/admin/self-hosting/docker-compose): sign-in, cost estimation, updates, and the other settings of this Compose file.
- [Self-hosting](/docs/admin/self-hosting): Kubernetes, Amazon ECS, and Google Cloud Run, and the move to Enterprise.
- [Enable Orchestration](/docs/admin/self-hosting/orchestration): the `GITHUB_*` variables, GitLab credential rotation, self-managed GitLab, and managed PostgreSQL.
- [Environment variables](/docs/admin/operations/environment-variables): all settings that Stategraph reads.
- [Access control](/docs/admin/access-control): Google, OIDC, tenants, and API access tokens.
- [Import your state](/docs/get-started/quickstart/import-state): use Infrastructure as a Database on an Enterprise server.
- [Editions](/docs/get-started/editions): what each edition includes, and how to get Enterprise.
