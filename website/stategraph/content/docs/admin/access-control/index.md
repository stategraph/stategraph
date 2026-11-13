---
title: Authentication
description: Set up sign-in to Stategraph with local accounts, Google, GitHub, or OIDC, and API keys for the CLI, scripts, and CI pipelines.
order: 1
---


Stategraph signs people in with a local account, Google OAuth, GitHub OAuth, or an OIDC provider, and accepts API keys from the CLI, Terraform, scripts, and CI pipelines.

## Overview

Without authentication, anyone with network access can use Stategraph. Configure it for every production deployment, and use HTTPS.

| Mode | Use case |
|------|----------|
| Local authentication | Email and password accounts that you manage in Stategraph |
| Google OAuth | Organizations that use Google Workspace |
| GitHub OAuth | Members of your GitHub organizations, on GitHub or GitHub Enterprise Server |
| Generic OIDC | Any OIDC provider, such as Okta, Auth0, or Azure AD |

## Authentication flow

1. The user opens Stategraph.
2. If the user is not signed in, the browser goes to the sign-in page, then to the OAuth provider.
3. The user signs in with the identity provider, which returns a token to Stategraph.
4. At the first sign-in, Stategraph creates the user, links it to the OAuth identity, and adds it to the shared Default tenant.
5. Stategraph sets a session cookie, and the browser sends it with each request.

A new user can access states and create API keys immediately.

The sign-in button reads "Sign in with" and the value of `STATEGRAPH_OAUTH_DISPLAY_NAME`. With OIDC, the sign-in page forwards to the provider without a click.

## Quick configuration

### Google OAuth

```bash
# Required
STATEGRAPH_OAUTH_TYPE=google
STATEGRAPH_OAUTH_CLIENT_ID=your-client-id.apps.googleusercontent.com
STATEGRAPH_OAUTH_CLIENT_SECRET=your-client-secret

# Optional
STATEGRAPH_OAUTH_EMAIL_DOMAIN=example.com  # Restrict to domain
STATEGRAPH_OAUTH_DISPLAY_NAME="Google Workspace"  # Button reads "Sign in with Google Workspace"
```

See [Google OAuth setup](/docs/admin/access-control/google-oauth) for more details.

### GitHub OAuth

```bash
# Required
STATEGRAPH_OAUTH_TYPE=github
STATEGRAPH_OAUTH_CLIENT_ID=your-client-id
STATEGRAPH_OAUTH_CLIENT_SECRET=your-client-secret
STATEGRAPH_OAUTH_GITHUB_ORG=acme  # Organizations whose members can sign in

# Optional
STATEGRAPH_OAUTH_EMAIL_DOMAIN=example.com
```

See [GitHub OAuth setup](/docs/admin/access-control/github) for more details.

### Generic OIDC

```bash
# Required
STATEGRAPH_OAUTH_TYPE=oidc
STATEGRAPH_OAUTH_CLIENT_ID=your-client-id
STATEGRAPH_OAUTH_CLIENT_SECRET=your-client-secret
STATEGRAPH_OAUTH_OIDC_ISSUER_URL=https://your-provider.com

# Optional
STATEGRAPH_OAUTH_EMAIL_DOMAIN=example.com
STATEGRAPH_OAUTH_DISPLAY_NAME="Acme SSO"  # Button reads "Sign in with Acme SSO"
```

See [OIDC setup](/docs/admin/access-control/oidc).

## API keys

The API accepts an API key as a Bearer token. It also accepts the session cookie that the browser sends.

```bash
curl -H "Authorization: Bearer $STATEGRAPH_API_KEY" http://localhost:8080/api/v1/...
```

| Type | Use case | Created by |
|------|----------|------------|
| Personal API key | CLI access, personal scripts | Individual user |
| Service account | CI/CD pipelines, automation | Team setup |

API keys of both types:

- Need no prefix.
- Do not expire. Treat them as long-lived secrets, and do not commit them to version control.
- Create audit trail entries. Audit their use through the transaction logs.

### Personal API keys

A personal API key is tied to your user account. The recommended way to create one is in the console, under **Settings > API Keys**. The key is shown only once.

Through the API, with an active browser session:

```bash
curl -X POST http://localhost:8080/api/v1/user/access-tokens \
  -H "Content-Type: application/json" \
  -H "Cookie: session=<your-session-cookie>" \
  -d '{"name": "my-api-key"}'
```

Response:

```json
{"token": "<your-api-key>"}
```

Through the CLI, with an existing API key (`STATEGRAPH_API_KEY` plus `--api-base`) and no browser session:

```bash
stategraph user access-tokens create --name my-api-key
```

Capability flags limit what the new token can do. Without them, the token inherits the capabilities of your current session. An apply-only token for one state:

```bash
stategraph user access-tokens create \
  --name ci-prod-apply \
  --apply \
  --apply-modified '<state-id>=*'
```

`stategraph user access-tokens list` lists your tokens, and `stategraph user access-tokens delete --token-id <id>` revokes one at any time. For all flags, the API endpoints, and the capability model, see [Access Tokens and Capabilities](/docs/admin/access-control/access-tokens).

### Service accounts

A service account is a separate user identity (type `api`) for CI/CD pipelines and automation. Compared with a personal API key, a service account:

- Stays valid when an employee leaves.
- Shows in the audit trail with its own name, such as "ci-production", not a person.
- Can be managed apart from human users.

Create one in the console on **Settings > API Keys**, under **Service Accounts**. The service account joins your current tenant. Its token is shown only once.

Through the API:

```bash
curl -X POST http://localhost:8080/api/v1/api-users \
  -H "Content-Type: application/json" \
  -H "Cookie: session=<your-session-cookie>" \
  -d '{"name": "ci-production", "tenant_id": "<tenant-uuid>"}'
```

Response:

```json
{"user_id": "<uuid>", "token": "<your-api-key>"}
```

### Using API keys

The CLI reads the key from `STATEGRAPH_API_KEY`:

```bash
export STATEGRAPH_API_KEY="<your-api-key>"
stategraph user tenants list
```

With the API:

```bash
curl -H "Authorization: Bearer $STATEGRAPH_API_KEY" http://localhost:8080/api/v1/...
```

[`stategraph user whoami`](/docs/cli/user) shows which identity a key authenticates as, and its capabilities.

### CI/CD setup

1. Create a service account, for example "github-actions".
2. Store its token as a secret in your CI/CD platform, for example `STATEGRAPH_API_KEY`.
3. Set the environment variables in the pipeline:

```yaml
# GitHub Actions example
env:
  STATEGRAPH_API_BASE: https://stategraph.example.com
  STATEGRAPH_API_KEY: ${{ secrets.STATEGRAPH_API_KEY }}
```

On GitLab, add `STATEGRAPH_API_KEY` as a masked CI/CD variable. GitLab gives CI/CD variables to jobs as environment variables, so `.gitlab-ci.yml` sets only the server URL:

```yaml
# GitLab CI example
variables:
  STATEGRAPH_API_BASE: https://stategraph.example.com
```

You can create a separate service account for each pipeline, such as staging and production.

## Email domain restriction

`STATEGRAPH_OAUTH_EMAIL_DOMAIN` limits access to an email domain. Users outside it are denied access. The default is `*`, which allows all domains. On a deployment that the public internet can reach, set it to your domain.

```bash
# Single domain
STATEGRAPH_OAUTH_EMAIL_DOMAIN=example.com

# Allow all domains
STATEGRAPH_OAUTH_EMAIL_DOMAIN=*
```

## Redirect URLs

In your OAuth provider, register the redirect URL for your provider type.

For Google OAuth:

```text
https://stategraph.example.com/oauth2/google/callback
```

For GitHub OAuth:

```text
https://stategraph.example.com/oauth2/github/callback
```

For OIDC providers:

```text
https://stategraph.example.com/oauth2/oidc/callback
```

`STATEGRAPH_OAUTH_REDIRECT_BASE` sets the base of the redirect URL:

```bash
STATEGRAPH_OAUTH_REDIRECT_BASE=https://stategraph.example.com
```

Without it, the base is `http://localhost:<port>`, which works only for local development. Always set it for a non-local deployment.

The `/oauth2/{provider}/callback` routes exist only when OAuth is configured. With local authentication, a request to one, such as `GET /oauth2/google/callback`, returns `404`. Only the `google` and `oidc` providers are supported.

## Troubleshooting

### "Invalid redirect URI"

The callback URL in your OAuth provider does not match. Check:

- The protocol (http or https).
- The hostname matches `STATEGRAPH_UI_BASE`.
- The path is `/oauth2/google/callback` (Google) or `/oauth2/oidc/callback` (OIDC).

### "Access denied"

Check:

- The email domain restriction.
- The user is in the allowed group (Google Groups).
- The OAuth app is approved in the organization.

### Session not persisting

Check:

- Cookies are enabled in the browser.
- `STATEGRAPH_UI_BASE` matches the URL that you open.
- No proxy strips cookies.

## Next steps

- [Local Authentication](/docs/admin/access-control/local-authentication): email and password accounts
- [Google OAuth Setup](/docs/admin/access-control/google-oauth): for Google Workspace organizations
- [OIDC Setup](/docs/admin/access-control/oidc): for other identity providers
- [Environment Variables](/docs/admin/operations/environment-variables)
