---
title: GitHub OAuth Setup
description: Set up GitHub sign-in for Stategraph with a GitHub OAuth App, and restrict access to the members of your GitHub organizations.
order: 4
---


GitHub OAuth signs the members of your GitHub organizations in to Stategraph with their GitHub accounts. It works with GitHub and GitHub Enterprise Server and needs no OIDC broker.

## Before you begin

- A GitHub organization whose members sign in to Stategraph, and owner access to it if the organization restricts OAuth App access.

## Step 1: Create a GitHub OAuth App

1. In GitHub, open the organization's **Settings** > **Developer settings** (at the very bottom of the list) > **OAuth Apps**, and click **New OAuth App**.
2. Set **Application name** to Stategraph, and **Homepage URL** to your public URL.
3. Set **Authorization callback URL** to your callback URL. For a deployment:

```text
https://stategraph.example.com/oauth2/github/callback
```

For local development:

```text
http://localhost:8080/oauth2/github/callback
```

4. Click **Register application**.
5. Copy the **Client ID**, then click **Generate a new client secret** and copy the secret.

## Step 2: Configure Stategraph

### Required environment variables

```bash
STATEGRAPH_OAUTH_TYPE=github

# From the GitHub OAuth App
STATEGRAPH_OAUTH_CLIENT_ID=Ov23liAbCdEf123456
STATEGRAPH_OAUTH_CLIENT_SECRET=your-client-secret

# GitHub organizations whose members can sign in, comma-separated
STATEGRAPH_OAUTH_GITHUB_ORG=acme,acme-other-entity

# Your public URL
STATEGRAPH_UI_BASE=https://stategraph.example.com
```

### Optional environment variables

```bash
# Restrict to an email domain. Skip this if some of your developers have a personal primary email on GitHub: they could not sign in
STATEGRAPH_OAUTH_EMAIL_DOMAIN=example.com

# Callback URL base (set this for any non-local deployment)
STATEGRAPH_OAUTH_REDIRECT_BASE=https://stategraph.example.com
```

Anyone can create a GitHub account, so Stategraph requires `STATEGRAPH_OAUTH_GITHUB_ORG`: without at least one organization, Stategraph does not start.

!!! note "Callback URL"
    The callback URL is `{STATEGRAPH_OAUTH_REDIRECT_BASE}/oauth2/github/callback`. Without `STATEGRAPH_OAUTH_REDIRECT_BASE`, the base is `http://localhost:<port>`, which works only for local development. Stategraph logs the callback URL at startup.

### What Stategraph reads from GitHub

A sign-in asks for the scopes `read:user`, `user:email`, and `read:org`. With the user's token, Stategraph reads:

- The numeric GitHub user id. A user who renames their GitHub login keeps the same Stategraph user.
- The avatar of the account, which the console shows for the user.
- The primary email of the account, which must be verified.
- The logins of the organizations the user is an active member of. A pending invitation is not a membership.

Stategraph compares the organization logins with `STATEGRAPH_OAUTH_GITHUB_ORG` without case. The logins are also the user's groups for [group rules](/docs/admin/access-control/group-rules), as GitHub spells them, for example `Acme`.

### GitHub Enterprise Server

Set the web and API URLs of your GitHub Enterprise Server. These are the same variables that Orchestration uses:

```bash
GITHUB_WEB_BASE_URL=https://github.example.com
GITHUB_API_BASE_URL=https://github.example.com/api/v3
```

With the Helm chart, set the same URLs in the values:

```yaml
stategraph:
  oauth:
    github:
      webBaseUrl: https://github.example.com
      apiBaseUrl: https://github.example.com/api/v3
```

When the chart also sets `stategraph.orchestration.github.webBaseUrl` and `apiBaseUrl`, they must be equal to these.

### Docker Compose example

```yaml
services:
  server:
    image: ghcr.io/stategraph/stategraph-server-oss:latest
    environment:
      DB_HOST: "db"
      DB_PORT: "5432"
      DB_USER: "stategraph"
      DB_PASS: "stategraph"
      DB_NAME: "stategraph"

      STATEGRAPH_UI_BASE: "https://stategraph.example.com"

      STATEGRAPH_OAUTH_TYPE: "github"
      STATEGRAPH_OAUTH_CLIENT_ID: "Ov23liAbCdEf123456"
      STATEGRAPH_OAUTH_CLIENT_SECRET: "${GITHUB_CLIENT_SECRET}"
      STATEGRAPH_OAUTH_GITHUB_ORG: "acme"
      STATEGRAPH_OAUTH_REDIRECT_BASE: "https://stategraph.example.com"
```

## Step 3: Verify the configuration

1. Open Stategraph in your browser.
2. Sign in with GitHub, and authorize the OAuth App. The console opens.

If sign-in fails, check the server logs:

```bash
docker compose logs server
```

## Troubleshooting

### Stategraph does not start

The server log names `STATEGRAPH_OAUTH_GITHUB_ORG`: it is unset, or holds no organization.

**Solution**:

- Set `STATEGRAPH_OAUTH_GITHUB_ORG` to at least one organization.

### "This account is not allowed to sign in"

**Causes**:

- The user is not an active member of an organization in `STATEGRAPH_OAUTH_GITHUB_ORG`.
- The organization restricts OAuth App access, and no owner has approved the OAuth App. GitHub then hides the membership, and the server log says that the user is not an active member.
- The primary email of the GitHub account is not verified.
- The primary email is not in `STATEGRAPH_OAUTH_EMAIL_DOMAIN`.

**Solutions**:

1. Check the user's membership in the organization.
2. As an owner of the organization, approve the OAuth App in the organization's **Settings** > **Third-party Access** > **OAuth application policy**. A member can also request the approval on the GitHub authorization page.
3. Verify the primary email in the GitHub account's **Settings** > **Emails**.

### "The redirect_uri is not associated with this application"

The callback URL of the OAuth App does not match.

**Solution**:

- Set the **Authorization callback URL** of the OAuth App to the callback URL that Stategraph logs at startup.

### "Sign-in failed"

The server log shows `GitHub refused the code`, for example with `incorrect_client_credentials`.

**Solution**:

- Compare the client ID and secret with the OAuth App, and look for whitespace or newlines.

## Next steps

- [Group Rules](/docs/admin/access-control/group-rules) to grant capabilities from GitHub organizations
- [OIDC Configuration](/docs/admin/access-control/oidc) for other providers
- [Environment Variables](/docs/admin/operations/environment-variables)
