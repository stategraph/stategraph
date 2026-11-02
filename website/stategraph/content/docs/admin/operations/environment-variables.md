---
title: Environment variables
description: Look up every environment variable that self-hosted Stategraph reads, with its default value and what it does.
order: 9
---


You configure self-hosted Stategraph only with environment variables on the [Stategraph container](/docs/admin/self-hosting):

- The database connection and `STATEGRAPH_UI_BASE` are always required.
- Some variables are required only with a feature, such as OAuth or Orchestration.
- All others have a default.

Leave optional variables unset, not empty: several Orchestration variables treat an empty string differently from an unset one.

## Core

| Variable | Default | Description |
|----------|---------|-------------|
| `STATEGRAPH_UI_BASE` | required | Public URL that users open, for example `https://stategraph.example.com`, for links, cookie security, and sign-in callbacks. `migrate` needs it too: it loads the configuration first |
| `STATEGRAPH_LICENSE_KEY` | unset | License key of the Enterprise build. You can also enter it on the setup screen, or later under **Settings > License**. Needed to complete the first-time setup. Afterwards, the server checks it at each start and exits with `LICENSE_REQUIRED` when neither this variable nor an entered key is valid |
| `STATEGRAPH_DEFAULT_TENANT_NAME` | `Default` | Tenant that new users join at sign-in. With an empty string, new users have no tenant until someone adds them to one |
| `STATEGRAPH_INVITATION_TTL_HOURS` | `168` | Tenant invitation link validity, in hours (7 days) |
| `STATEGRAPH_AEGIS_API_BASE` / `STATEGRAPH_AEGIS_SERVICE_TOKEN` | unset | Aegis control plane, used only for invitation emails. Both unset: invitations are links only |
| `STATEGRAPH_ENABLE_CORS` | `false` | Send CORS headers. Development only, with the console on another origin |
| `STATEGRAPH_CORS_DEFAULT_ORIGIN` | `http://localhost:3000` | Origin that CORS allows |

## HTTP

| Variable | Default | Description |
|----------|---------|-------------|
| `STATEGRAPH_ACCESS_LOG` | `off` | Access log, used as it is: a path or `off`, no `on`. `/dev/stdout` writes each request to the container log |
| `STATEGRAPH_CLIENT_MAX_BODY_SIZE` | `512m` | Maximum request body, which limits the state file size |
| `DISABLE_IPV6` | `0` | `1` turns off IPv6 on port 8080 |

## Database

| Variable | Default | Description |
|----------|---------|-------------|
| `DB_HOST` | required | PostgreSQL host |
| `DB_PORT` | `5432` | PostgreSQL port |
| `DB_USER` | required | Database user |
| `DB_PASS` | required | Database password |
| `DB_NAME` | required | Stategraph database name, `stategraph` in every guide |
| `DB_CONNECT_TIMEOUT` | `120` | Connection timeout in seconds. Orchestration reads it too, same default |
| `DB_MAX_POOL_SIZE` | `100` | Maximum connections in the pool. Orchestration reads it too |
| `DB_IDLE_TX_TIMEOUT` | `180s` | Idle-in-transaction timeout. Orchestration reads it too |
| `DB_LOCK_TIMEOUT` | `120s` | Lock timeout. Only Orchestration reads it |
| `STATEGRAPH_DB_STATEMENT_TIMEOUT` | `30s` | Statement timeout for the Stategraph server |
| `DWF_IDLE_TX_TIMEOUT` | `600s` | Idle-in-transaction timeout for workflow connections. No `STATEGRAPH_` prefix |

Orchestration reads the same `DB_*` names for its database. See [Orchestration](#orchestration) for how they map.

## Authentication

Local email and password sign-in needs no variable. For the sign-in modes, see [Access control](/docs/admin/access-control).

| Variable | Default | Description |
|----------|---------|-------------|
| `STATEGRAPH_OAUTH_TYPE` | unset | `google` or `oidc`. Unset: single sign-on is off |
| `STATEGRAPH_OAUTH_CLIENT_ID` | | OAuth client ID. Required with `STATEGRAPH_OAUTH_TYPE` |
| `STATEGRAPH_OAUTH_CLIENT_SECRET` | | OAuth client secret. Required with `STATEGRAPH_OAUTH_TYPE` |
| `STATEGRAPH_OAUTH_REDIRECT_BASE` | `http://localhost:<port>` | Base URL of the `/oauth2/{provider}/callback` callbacks. Set it to the public URL, as in `STATEGRAPH_UI_BASE` |
| `STATEGRAPH_OAUTH_EMAIL_DOMAIN` | `*` | Email domain that can sign in. With `*`, any identity that the provider authenticates signs in, and the first to sign in while no instance admin exists becomes one. Restrict it to your domain on any public deployment |
| `STATEGRAPH_OAUTH_DISPLAY_NAME` | `Google` or `SSO` | Provider name on the sign-in button |
| `STATEGRAPH_OAUTH_COOKIE_SECRET` | random per process | Signs session and CSRF cookies: 16, 24, or 32 characters. Set it on each replica of a multi-replica deployment, or replicas do not share sessions |
| `STATEGRAPH_OAUTH_OIDC_ISSUER_URL` | | OIDC issuer URL, required with `STATEGRAPH_OAUTH_TYPE=oidc`. The provider must support discovery at `{issuer}/.well-known/openid-configuration` |
| `STATEGRAPH_OAUTH_OIDC_USE_AUTH0_LOGOUT` | `false` | Use the Auth0 logout endpoint for OIDC sign-out |
| `STATEGRAPH_OAUTH_GOOGLE_GROUP` | unset | Google Group whose members can sign in. Needs the two variables below |
| `STATEGRAPH_OAUTH_GOOGLE_ADMIN_EMAIL` | unset | Google Workspace super admin email, for Google Groups API access |
| `STATEGRAPH_OAUTH_GOOGLE_SERVICE_ACCOUNT_JSON` | unset | Google Admin API service account key, as inline JSON or a file path |
| `STATEGRAPH_OAUTH2_PROXY_PATH` | `/usr/local/bin/oauth2-proxy` | Path of the oauth2-proxy binary that Stategraph runs |

A missing or invalid sign-in variable stops the server at start, with the reason in the server log. If the sign-in provider does not start, the server runs without OAuth sign-in, with the reason in `/tmp/oauth2-proxy.log` in the container.

## Server tuning

| Variable | Default | Description |
|----------|---------|-------------|
| `STATEGRAPH_DWF_CONCURRENCY` | `40` | Workflow concurrency |
| `STATEGRAPH_PREVIEW_EXEC_TIMEOUT_MINUTES` | `60` | Wall-clock limit for a plan preview |
| `STATEGRAPH_PREVIEW_IDLE_TIMEOUT_MINUTES` | `60` | Idle limit for a plan preview |
| `STATEGRAPH_COMMIT_EXEC_TIMEOUT_MINUTES` | `60` | Wall-clock limit for a commit |
| `STATEGRAPH_COMMIT_IDLE_TIMEOUT_MINUTES` | `60` | Idle limit for a commit |
| `STATEGRAPH_FOCUS_SYNC_PARALLELISM` | | Parallelism of focus synchronization |
| `STATEGRAPH_INTERP_MEMO` | on | Memoization in the HCL interpreter. `false`, `0`, or `off` turns it off |
| `STATEGRAPH_INTERP_MEMO_VERIFY` | off | `true`, `1`, or `on` compares memoized results with a fresh evaluation |

## Orchestration

[Enable Orchestration](/docs/admin/self-hosting/orchestration) explains the database, the roles, and the GitHub and GitLab setup.

| Variable | Default | Description |
|----------|---------|-------------|
| `STATEGRAPH_ORCHESTRATION_ENABLED` | on when `STATEGRAPH_FDW_PASSWORD` is set | `true` turns on Orchestration, `false` turns it off. Unset: on exactly when `STATEGRAPH_FDW_PASSWORD` is set. With Orchestration on, the FDW bridge is rebuilt at each start |
| `TERRAT_API_BASE` | `STATEGRAPH_UI_BASE` plus `/api` | Public base of the Orchestration API. The runner base URL, the webhook URL, and the callback URLs of a GitHub App created from the console come from it |
| `TERRAT_UI_BASE` | `STATEGRAPH_UI_BASE` | Public URL of the server |
| `TERRAT_WEB_BASE_URL` | `https://app.terrateam.io` | Base of the run links in comments and commit checks when `STATEGRAPH_UI_BASE` and `TERRAT_UI_BASE` are unset |
| `TERRAT_DB_HOST` / `TERRAT_DB_PORT` / `TERRAT_DB_USER` / `TERRAT_DB_PASS` | the `DB_*` values | Orchestration database connection. Each unset one takes the matching `DB_*` value |
| `TERRAT_DB_NAME` | `terrateam` | Orchestration database. It never takes `DB_NAME` |
| `TERRAT_SESSION_COOKIE_NAME` | `terrat_session`, set in the container | Orchestration session cookie. It must differ from the console `session` cookie on the shared origin, or a VCS OAuth callback signs the console user out. Set it container-wide: Stategraph expires it at sign-out |
| `TERRAT_BRAND` | unset | Brand of comments and commit-check names when the repository configuration names none. `.stategraph/config` or a `stategraph` centralized repository gives `stategraph`, and `.terrateam/config` or a `terrateam` one gives `terrateam`. Others get this value, or `stategraph` when unset. Any value except `stategraph` or `terrateam` is a configuration error: Orchestration does not start |
| `TERRAT_TELEMETRY_LEVEL` | `anonymous` | `anonymous` or `disabled`. Other values stop Orchestration at start |
| `TERRAT_TELEMETRY_URI` | `https://telemetry.terrateam.io` | Where anonymous telemetry goes |
| `TERRAT_ADMIN_TOKEN` | unset | Bearer token for the Orchestration admin endpoints |
| `TERRAT_DEFAULT_TIER` | `unlimited` | Default tier of a new installation |
| `TERRAT_EVENT_EVALUATOR_SLOTS` | `20` | Concurrent event evaluations |
| `TERRAT_STATEMENT_TIMEOUT` | `5s` | Statement timeout for the Orchestration database |
| `GITHUB_ACTION_DYNAMIC_TITLE` | unset | Comma-separated fields for the dynamic title of Orchestration GitHub Actions runs: `pr_title`, `pr_number`, `run_kind`, `run_type` |
| `GITHUB_WORKFLOW_PATH_OVERRIDE` | unset | Path of the GitHub Actions workflow file that Orchestration dispatches, in place of the default |
| `TERRATUNNEL_API_ENDPOINT` | unset | Development only: `TERRAT_API_BASE` comes from a tunnel |
| `INFRACOST_PRICING_API_ENDPOINT` / `SELF_HOSTED_INFRACOST_API_KEY` | empty | Infracost pricing API endpoint and key, for cost estimation in pull requests. See [Cost estimation in pull requests](/docs/orchestration/external-tools/infracost) |

### FDW bridge

| Variable | Default | Description |
|----------|---------|-------------|
| `STATEGRAPH_FDW_HOST` | `localhost` | Host of the `terrateam` database, as seen from the PostgreSQL server |
| `STATEGRAPH_FDW_PORT` | `5432` | Port of that connection |
| `STATEGRAPH_FDW_DBNAME` | `terrateam` | Orchestration database |
| `STATEGRAPH_FDW_USER` | `stategraph_mql` | Read role that the bridge authenticates as |
| `STATEGRAPH_FDW_PASSWORD` | unset | Password of the read role. Setting it turns on Orchestration, unless `STATEGRAPH_ORCHESTRATION_ENABLED` is `false`. Required with `STATEGRAPH_ORCHESTRATION_ENABLED=true`: without it, the configuration does not load |
| `STATEGRAPH_FDW_PROVISIONER_USER` | `stategraph_provisioner` | Write role of the console, for GitHub App creation and GitLab provisioning |
| `STATEGRAPH_FDW_PROVISIONER_PASSWORD` | unset | Password of the write role. Unset: provisioning is off, the endpoint answers `503`, and the console can neither create the GitHub App nor connect a GitLab group |

### GitHub

An instance admin creates the GitHub App from the console, and Stategraph stores it in the Orchestration database. The variables below pass an App that you manage outside the console. When `GITHUB_APP_ID` is set, they win over the stored App.

| Variable | Default | Description |
|----------|---------|-------------|
| `GITHUB_APP_ID` | unset | GitHub App ID. Setting it makes the environment the source of the App |
| `GITHUB_APP_PEM` | | Private key of the App. Literal `\n` sequences become newlines |
| `GITHUB_APP_CLIENT_ID` / `GITHUB_APP_CLIENT_SECRET` | | OAuth client of the App, for Orchestration and Stategraph. For tenant self-claim, Stategraph reads both or neither |
| `GITHUB_WEBHOOK_SECRET` | | Webhook secret of the App. Required with `GITHUB_APP_ID`: unset or empty, Orchestration does not start |
| `GITHUB_APP_URL` | unset | App install URL, behind the console **Install on GitHub** button. An App created from the console carries its own. Unset with `GITHUB_APP_ID`, the console says to install the App from the GitHub organization settings. Leave it unset, not empty |
| `GITHUB_API_BASE_URL` | `https://api.github.com` | GitHub Enterprise Server API base |
| `GITHUB_WEB_BASE_URL` | `https://github.com` | GitHub Enterprise Server web base |

### GitLab

| Variable | Default | Description |
|----------|---------|-------------|
| `GITLAB_APP_ID` | unset | Application ID of a GitLab OAuth application. A non-empty value turns on GitLab in Orchestration |
| `GITLAB_APP_SECRET` | unset | Application secret. Required with `GITLAB_APP_ID`, or Orchestration does not start |
| `GITLAB_ACCESS_TOKEN` | unset | Access token with the `api` scope. Required with `GITLAB_APP_ID`, or Orchestration does not start |
| `GITLAB_API_BASE_URL` | `https://gitlab.com` | Root URL of a self-managed instance, for example `https://gitlab.example.com`, without `/api/v4`. Only Orchestration reads it |
| `GITLAB_WEB_BASE_URL` | `https://gitlab.com` | Web URL of a self-managed instance, for example `https://gitlab.example.com`. Only Orchestration reads it |

## Cost estimation

See [Enable cost estimation](/docs/admin/self-hosting/cost).

| Variable | Default | Description |
|----------|---------|-------------|
| `STATEGRAPH_COST_ENABLED` | off | `true` or `1` turns on cost estimation |
| `STATEGRAPH_PRICING_SERVICE_URL` | `http://localhost:8090` | Pricing endpoint. Set it only for an external pricing service |
| `STATEGRAPH_PRICING_DEFAULT_REGION` | `us-east-1` | Region for a resource that does not specify one |
| `STATEGRAPH_COST_SCHEDULE_HOURS` | `24` | Interval of the scheduled per-state cost recompute |
| `STATEGRAPH_COST_EVENT_DEBOUNCE_HOURS` | `6` | Minimum gap before an apply triggers a recompute |
| `STATEGRAPH_COST_PRICING_CALL_TIMEOUT_SECONDS` | `30` | Timeout of one pricing call |
| `PRICING_DB_HOST` / `PRICING_DB_PORT` / `PRICING_DB_USER` / `PRICING_DB_PASSWORD` / `PRICING_DB_NAME` | `db` / `5432` / `stategraph` / `stategraph` / `cloud_pricing` | Price-book database. It does not take `DB_*`, but the `load-pricing-data` loader does, for host, port, user, and password |
| `PRICING_DB_SSLMODE` | `disable` | Set it for a remote pricing database |
| `PRICING_REFRESH_HOURS` | `168` | Price-book refresh interval. `0` turns off the refresh |
| `LISTEN_ADDR` | `:8090` | Pricing endpoint listen address. It has no authentication: do not publish the port |

## Security scanning

See [Enable security scanning](/docs/admin/self-hosting/security-scanning).

| Variable | Default | Description |
|----------|---------|-------------|
| `STATEGRAPH_SECURITY` | off | `true` or `1` turns on security scanning |
| `STATEGRAPH_SECURITY_SCHEDULE_HOURS` | `24` | Scheduled rescan interval per state |
| `STATEGRAPH_SECURITY_EVENT_DEBOUNCE_HOURS` | `1` | Minimum gap before an apply triggers another scan |

## Read by the CLI, not the server

The `stategraph` CLI reads these when it runs, by hand or on a runner. The server ignores them.

| Variable | Description |
|----------|-------------|
| `TF_CMD` | Terraform or tofu binary that the CLI runs. It must exist when set |
| `STATEGRAPH_ACTUATOR_CHUNK_SIZE` | Size of the chunks that the CLI uploads |
| `STATEGRAPH_FETCH_RESULT_PARALLELISM` | Parallelism of the CLI result fetches |
| `STATEGRAPH_REMOTE_MODULE_BATCH_BYTES` | Byte budget of the query of one batch of the CLI's committed reads. The default leaves room under the 8 KiB request line of the server image's nginx. A value that is not a positive integer falls back to the default |
| `STATEGRAPH_REMOTE_MODULE_PARALLELISM` | How many batch requests of the CLI's committed reads are in flight at once. A value that is not a positive integer falls back to the default |

## Not supported

Stategraph ignores `CUSTOM_CA_CERT`: the container installs no certificates at start. To trust a custom CA, build a derived image. See [Self-signed certificates](/docs/orchestration/security/self-signed-certificates).

If a configuration change has no effect, check the server metrics first: see [Observability](/docs/admin/operations/observability). Otherwise, [contact support](/docs/support) with your server logs and deployment version.

## Next steps

- [Docker Compose](/docs/admin/self-hosting/docker-compose): the reference setup
- [Enable Orchestration](/docs/admin/self-hosting/orchestration)
- [Upgrades](/docs/admin/operations/upgrades): variables whose behavior changed between releases
