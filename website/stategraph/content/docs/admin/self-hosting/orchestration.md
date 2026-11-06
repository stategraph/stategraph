---
title: Enable Orchestration
description: Set up Stategraph Orchestration on a self-hosted server with database passwords, your public URL, and a GitHub App or GitLab credentials.
order: 6
---


Stategraph Orchestration is on in the [Docker Compose](/docs/admin/self-hosting/docker-compose) setup. `STATEGRAPH_ORCHESTRATION_ENABLED=true` turns it on, `false` turns it off, and when the variable is unset, Orchestration is on exactly when `STATEGRAPH_FDW_PASSWORD` is set. To use it, give it two database passwords and your public URL, and connect a GitHub App or GitLab.

## Turn it on

Add these variables to the container environment, and recreate the container:

```bash
STATEGRAPH_UI_BASE=https://stategraph.example.com
STATEGRAPH_OAUTH_REDIRECT_BASE=https://stategraph.example.com
STATEGRAPH_FDW_PASSWORD=<fdw-password>
STATEGRAPH_FDW_PROVISIONER_PASSWORD=<provisioner-password>
```

| Variable | Notes |
|----------|-------|
| `STATEGRAPH_UI_BASE` | Your public URL. The webhook and runner URLs derive from it |
| `STATEGRAPH_OAUTH_REDIRECT_BASE` | Your public URL. The callback URLs of the GitHub App are under it |
| `STATEGRAPH_FDW_PASSWORD` | Password of the `stategraph_mql` database role. Setting it turns on Orchestration. See [Database](#database) |
| `STATEGRAPH_FDW_PROVISIONER_PASSWORD` | Password of the `stategraph_provisioner` database role. The console creates the GitHub App and connects GitLab groups through it |

`TERRAT_API_BASE` and `TERRAT_UI_BASE` default to `STATEGRAPH_UI_BASE` plus `/api`, and to `STATEGRAPH_UI_BASE`. Set them only when Orchestration has another public URL. `STATEGRAPH_ORCHESTRATION_ENABLED=false` turns Orchestration off with the passwords in place.

Then connect your provider: [Connect GitHub](#connect-github) or [Connect GitLab](#connect-gitlab).

The switch takes effect only with the default container command. Anonymous telemetry is on by default: `TERRAT_TELEMETRY_LEVEL=disabled` turns it off.

## Database

Orchestration stores its data in a second database, `terrateam`, on the same PostgreSQL server as `stategraph`. The console reads it through `postgres_fdw`, as the `stategraph_mql` role, and writes the GitHub App and the GitLab group connections as the `stategraph_provisioner` role. Stategraph creates the database and the roles, and keeps the grants of the roles current. You give the roles their passwords, one time.

With the [Docker Compose](/docs/admin/self-hosting/docker-compose) setup, there is nothing to do: its `initdb/` scripts create the database and the roles at the first start of a new `db` volume, with the passwords that `orchestration.env` sets in `STATEGRAPH_FDW_PASSWORD` and `STATEGRAPH_FDW_PROVISIONER_PASSWORD`. For an existing volume, see [Connect GitHub or GitLab](/docs/admin/self-hosting/docker-compose#connect-github-or-gitlab).

On any other PostgreSQL, create the roles before the first start with Orchestration on. If Stategraph already created them, use `ALTER ROLE` instead.

```sql
CREATE ROLE stategraph_mql LOGIN PASSWORD '<fdw-password>';
CREATE ROLE stategraph_provisioner LOGIN PASSWORD '<provisioner-password>';
```

### Managed PostgreSQL

On Amazon RDS, Cloud SQL, and other managed PostgreSQL, the role that Stategraph connects as is usually not a superuser. Then:

- `postgres_fdw` needs superuser rights. On Amazon RDS, grant the role `rds_superuser`. Otherwise, create the foreign server and the user mapping in the `stategraph` database in advance. Without one of these, the Stategraph server does not start, and the error is in the server log.
- When the role cannot create databases, create `terrateam` yourself, owned by that role. Stategraph logs the statement at each start. With `STATEGRAPH_ORCHESTRATION_ENABLED=true`, the start fails, and the server restarts a few seconds later. When only `STATEGRAPH_FDW_PASSWORD` turns on Orchestration, the server runs without Orchestration until its next start:

```sql
CREATE DATABASE terrateam OWNER stategraph;
```

## Connect GitHub

Orchestration runs as a GitHub App that you own. An instance admin creates it from the console, or you create it by hand and pass it through the environment.

### From the console

This path needs `STATEGRAPH_FDW_PROVISIONER_PASSWORD`. Sign in as an instance admin, and open **Get Started > Set up your first repository > Connect GitHub**. The first step is **Create**:

1. Keep the App name the console suggests, or type your own. GitHub requires a name no other App uses. To create the App under an organization, enter the organization name.
2. Click **Create on GitHub**. GitHub opens with the App filled in: the webhook URL, the callback URLs, the setup URL, the permissions and events listed below, and OAuth on install.
3. Create the App on GitHub. GitHub returns you to the console.

Stategraph stores the App in the Orchestration database and starts Orchestration with it. The console shows "The App is created. Starting the orchestration engine." for a few seconds, then moves to the **Install** step. Nothing changes in the environment, and no restart is needed. For GitHub Enterprise Server, set the two URL variables first: see [GitHub Enterprise Server](#github-enterprise-server).

### Manage the App

An App created from the console is managed in **Settings > Integrations > GitHub App**, as an instance admin. The panel shows which App the server holds, when it was created, and whether Orchestration is running it.

**Replace** creates a new App on GitHub and stores it in place of the current one. You install the new App yourself. The installations of the old App stop being orchestrated.

**Rotate credentials** takes the private key, the OAuth client secret and the webhook secret that you rotate on the App's GitHub page. Fill in the ones you rotated and leave the rest empty. GitHub shows each of them one time only and has no API that reads one back, so keep what you download until the panel reports it in use. A stale webhook secret stops every run, because the events then fail their signature check. A stale client secret breaks console sign-in and leaves webhooks alone.

**Remove** deletes the App from Stategraph. Orchestration then answers no GitHub events. The App, its installations and their tenant links stay on GitHub. The stored copy of the private key is destroyed, and no copy remains in Stategraph.

Each of the three restarts Orchestration on the new state, which takes a few seconds. A webhook that arrives during the restart is lost, and GitHub does not redeliver it, so make these changes when no run is in flight.

An App that comes from the environment is not managed here. The panel names it and says so.

### With the environment

For a deployment that keeps its secrets outside Stategraph, such as Kubernetes secrets, create the App by hand and set the six `GITHUB_*` variables. When `GITHUB_APP_ID` is set, the environment wins over an App created from the console, and the console neither stores nor manages an App.

Create a GitHub App in your organization with these permissions:

| Permission | Access |
|------------|--------|
| Actions | Read and write |
| Checks | Read |
| Contents | Read and write |
| Issues | Read and write |
| Metadata | Read |
| Pull requests | Read and write |
| Commit statuses | Read and write |
| Secrets | Read and write |
| Workflows | Read and write |
| Members (organization) | Read |
| Email addresses (account) | Read |

Subscribe it to the events `issue_comment`, `issues`, `pull_request`, `pull_request_review`, `pull_request_review_comment`, `push`, `workflow_job`, and `workflow_run`. Then:

1. Set the webhook URL to `https://stategraph.example.com/api/github/v1/events`, and a webhook secret. Put the secret in `GITHUB_WEBHOOK_SECRET`.
2. Add `https://stategraph.example.com/api/v1/vcs-installations/github/claim/callback` as a callback URL.
3. Generate a private key, and put its contents in `GITHUB_APP_PEM`. Literal `\n` sequences become line breaks.
4. Put the App ID in `GITHUB_APP_ID`, the client ID and secret in `GITHUB_APP_CLIENT_ID` and `GITHUB_APP_CLIENT_SECRET`, and the install URL, `https://github.com/apps/<your-app>`, in `GITHUB_APP_URL`.

`GITHUB_WEBHOOK_SECRET` is required when `GITHUB_APP_ID` is set: without it, Orchestration does not start, and the container log says so. With the OAuth client, the callback URL, and the Members permission in place, tenant admins link their own installation from the console, without an instance admin. See [Tenants](/docs/admin/access-control/tenants).

### GitHub Enterprise Server

Set `GITHUB_API_BASE_URL` and `GITHUB_WEB_BASE_URL` to your instance, for example `https://github.example.com/api/v3` and `https://github.example.com`.

## Connect GitLab

Orchestration connects to GitLab as a bot user that you create, with an access token and an OAuth application. Set the variables, then a tenant admin connects each group from the console.

| Variable | Notes |
|----------|-------|
| `GITLAB_APP_ID` | Application ID of the OAuth application. A value that is not empty turns on GitLab in Orchestration |
| `GITLAB_APP_SECRET` | Secret of the application. Required with `GITLAB_APP_ID` |
| `GITLAB_ACCESS_TOKEN` | Access token of the bot user, with the `api` scope. Required with `GITLAB_APP_ID` |
| `GITLAB_API_BASE_URL`, `GITLAB_WEB_BASE_URL` | Self-managed GitLab only: the root URL of the instance, for example `https://gitlab.example.com`. Both default to `https://gitlab.com` |
| `STATEGRAPH_FDW_PROVISIONER_PASSWORD` | Password of the `stategraph_provisioner` database role. See [Database](#database). Without it, the console cannot connect a group |

When `GITLAB_APP_ID` is set and `GITLAB_APP_SECRET` or `GITLAB_ACCESS_TOKEN` is missing, Orchestration does not start. The container log has a `CONFIG : ERROR` line that names the variable.

### GitLab version

Stategraph Orchestration requires GitLab 18.1 or later, Community or Enterprise Edition. gitlab.com always meets this. On self-managed GitLab, check the version with the metadata API:

```bash
curl --header "PRIVATE-TOKEN: <access-token>" "https://gitlab.example.com/api/v4/metadata"
```

Earlier versions start the pipeline without the inputs that carry the work token, and the job fails when it calls back.

### Create the GitLab application

1. Create a dedicated GitLab user for Stategraph. As that user, create a personal access token with the `api` scope, and put it in `GITLAB_ACCESS_TOKEN`.
2. As the same user, create an OAuth application with the `api` scope and the redirect URI `https://stategraph.example.com/api/v1/gitlab/callback`. Put its application ID in `GITLAB_APP_ID` and its secret in `GITLAB_APP_SECRET`.
3. For self-managed GitLab, set `GITLAB_API_BASE_URL` and `GITLAB_WEB_BASE_URL` to the root URL of the instance.

### Connect a group

After the restart, a tenant admin opens **Get Started → Set up your first repository → Connect GitLab** in the console.

1. Enter the GitLab URL, the group path as it shows in URLs, and the numeric group ID (under the group name, or **Copy group ID** in the group menu).
2. Check the group ID yourself. The wizard does not check it, and a wrong ID gives an installation that never receives webhooks.
3. Enter the project path under the group.
4. Create an access token with the `api` scope, and enter it. Group and project tokens need at least the Developer role.

- Group access token: the narrowest choice, not tied to a person. GitLab Premium or Ultimate on gitlab.com, any tier on self-managed GitLab.
- Project access token: one project.
- Personal access token: any plan, but it stops working if you lose access to the group. Use the classic form, so that you can grant `api`.

Stategraph stores the token write-only. Merge request comments and pipelines for the group run as the user of the token.

5. Add a project webhook in GitLab with the URL and secret token that the wizard shows, and with **Push events**, **Comments**, **Merge request events**, and **Job events** on. Copy the secret before you continue: it shows one time only.
6. Save the webhook, and run **Test → Push events** on it to activate it.
7. In GitLab, set **Settings → CI/CD → Variables → Minimum role to use pipeline variables** to **Developer**, so that Orchestration can use pipeline variables.
8. Push the `.gitlab-ci.yml` that the wizard shows to the repository root on the default branch.

To replace a lost secret, rotate the credentials in **Settings > Integrations**.

### Self-managed GitLab

The instance must run GitLab 18.1 or later. Set `GITLAB_API_BASE_URL` and `GITLAB_WEB_BASE_URL` to its root URL, and enter the same URL in the connect wizard: Orchestration reads the variables, the console does not. Also mirror `gitlab.com/terrateam-io/terrateam-template` to `terrateam-io/terrateam-template` on the instance, because the `.gitlab-ci.yml` includes it from the instance that runs the pipeline. Without the mirror, pipeline creation fails.

## Verify

After the container restarts with Orchestration on, search its log:

```bash
docker compose logs server | grep -E 'terrat|GITHUB_APP|GitLab|CONFIG : ERROR|GITHUB_WEBHOOK_SECRET|CREATE DATABASE'
```

A correct start logs that Orchestration starts and that the roles are reconciled, and with GitLab, `Starting GitLab Service`. With no GitHub App yet, it logs `GITHUB_APP : WAITING` until an instance admin creates one from the console, then `GITHUB_APP : LOADED` after the restart. A failed start logs the missing GitHub webhook secret, a `CONFIG : ERROR` line for a missing GitLab variable, or the `CREATE DATABASE` statement to run. Then open the console, and set up your first repository from the **Get Started** page. For anything else, see [Orchestration issues](/docs/reference/troubleshooting#orchestration-issues).

## Next steps

- [Pull request workflows](/docs/orchestration/workflows): what Orchestration does on a pull request.
- [Private runners](/docs/orchestration/security/private-runners): plans and applies on GitHub Actions or GitLab runners that you host.
- [Environment variables](/docs/admin/operations/environment-variables): every Orchestration variable.
