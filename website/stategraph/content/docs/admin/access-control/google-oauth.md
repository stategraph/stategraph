---
title: Google OAuth Setup
description: Set up Google Workspace sign-in for Stategraph with Google OAuth, and restrict access by email domain or Google Group.
order: 3
---


Google OAuth signs users in to Stategraph with their Google Workspace accounts, optionally limited to your email domain or to a Google Group.

## Before you begin

- A Google Cloud account and a Google Cloud project.
- Admin access to configure the OAuth consent screen.

## Step 1: Create an OAuth client

### Configure the OAuth consent screen

1. In the [Google Cloud Console](https://console.cloud.google.com), select your project, or create a new one.
2. Go to **APIs & Services** > **OAuth consent screen**.
3. Select the user type: **Internal** (only users in your Google Workspace organization) or **External** (any Google user; production needs app verification).
4. Set **App name** to Stategraph, and **User support email** and **Developer contact** to your email.
5. Click **Save and Continue**.
6. Optionally, add scopes. Email and profile are included by default.
7. Complete the setup.

### Create the OAuth client ID

1. Go to **APIs & Services** > **Credentials**.
2. Click **Create Credentials** > **OAuth client ID**.
3. Select **Web application**.
4. Set **Name** to Stategraph.
5. Under **Authorized redirect URIs**, add your callback URL. For a deployment:

```text
https://stategraph.example.com/oauth2/google/callback
```

For local development:

```text
http://localhost:8080/oauth2/google/callback
```

6. Click **Create**.
7. Copy the **Client ID** and the **Client Secret**.

## Step 2: Configure Stategraph

### Required environment variables

```bash
# Enable Google OAuth
STATEGRAPH_OAUTH_TYPE=google

# From the Google Cloud Console
STATEGRAPH_OAUTH_CLIENT_ID=123456789-abc123.apps.googleusercontent.com
STATEGRAPH_OAUTH_CLIENT_SECRET=GOCSPX-xxxxxxxxxxxxx

# Your public URL
STATEGRAPH_UI_BASE=https://stategraph.example.com
```

### Optional environment variables

```bash
# Restrict to a specific domain
STATEGRAPH_OAUTH_EMAIL_DOMAIN=example.com

# Callback URL base (set this for any non-local deployment)
STATEGRAPH_OAUTH_REDIRECT_BASE=https://stategraph.example.com
```

!!! note "Callback URL"
    The callback URL is `{STATEGRAPH_OAUTH_REDIRECT_BASE}/oauth2/google/callback`. Without `STATEGRAPH_OAUTH_REDIRECT_BASE`, the base is `http://localhost:<port>`, which works only for local development. Stategraph logs the callback URL at startup.

### Docker Compose example

```yaml
services:
  server:
    image: ghcr.io/stategraph/stategraph-server:latest
    environment:
      DB_HOST: "db"
      DB_PORT: "5432"
      DB_USER: "stategraph"
      DB_PASS: "stategraph"
      DB_NAME: "stategraph"

      STATEGRAPH_UI_BASE: "https://stategraph.example.com"

      STATEGRAPH_OAUTH_TYPE: "google"
      STATEGRAPH_OAUTH_CLIENT_ID: "123456789-abc123.apps.googleusercontent.com"
      STATEGRAPH_OAUTH_CLIENT_SECRET: "${GOOGLE_CLIENT_SECRET}"
      STATEGRAPH_OAUTH_EMAIL_DOMAIN: "example.com"
      STATEGRAPH_OAUTH_REDIRECT_BASE: "https://stategraph.example.com"
```

## Step 3: Verify the configuration

1. Open Stategraph in your browser.
2. Sign in with Google. The console opens.

If sign-in fails, check the server logs:

```bash
docker compose logs server
```

Look for OAuth messages. A missing or invalid OAuth variable stops Stategraph at startup, with the reason in the log. If the sign-in provider cannot be set up, Stategraph logs the reason, tries again every second, and accepts no requests until the setup succeeds. The service account key is not logged at startup.

## Advanced configuration

### Google Groups

With an admin email and a service account, Stategraph reads each user's Google Groups at sign-in, and [group rules](/docs/admin/access-control/group-rules) grant capabilities from them. To also limit access to the members of some groups, set `STATEGRAPH_OAUTH_GOOGLE_GROUP` to one group or a comma-separated list:

```bash
# Google Groups whose members can sign in (optional)
STATEGRAPH_OAUTH_GOOGLE_GROUP=stategraph-users@example.com

# Admin email for the group lookup
STATEGRAPH_OAUTH_GOOGLE_ADMIN_EMAIL=admin@example.com

# Service account JSON for the Google Admin API (the JSON itself, or a path to a file containing it)
STATEGRAPH_OAUTH_GOOGLE_SERVICE_ACCOUNT_JSON='{...}'
```

#### Set up the service account

1. Create a service account in the Google Cloud Console.
2. Enable domain-wide delegation.
3. Grant the service account the Admin SDK scope `https://www.googleapis.com/auth/admin.directory.group.readonly`.
4. Download the JSON key file.
5. Set `STATEGRAPH_OAUTH_GOOGLE_SERVICE_ACCOUNT_JSON` to the JSON content, or to the path of the downloaded key file.

Stategraph checks the key and the delegation at startup. If the check fails, Stategraph logs the reason and tries again every second, and accepts no requests until the check passes.

#### Configure domain-wide delegation

1. Go to the [Google Admin Console](https://admin.google.com).
2. Go to **Security** > **API Controls** > **Domain-wide Delegation**.
3. Add the client ID of the service account.
4. Add the scope `https://www.googleapis.com/auth/admin.directory.group.readonly`.

### Multiple domains

Set `STATEGRAPH_OAUTH_EMAIL_DOMAIN` to a comma-separated list of domains:

```bash
STATEGRAPH_OAUTH_EMAIL_DOMAIN=example.com,example.org
```

For users from many organizations, allow all domains with `*`, and limit access with a Google Group.

## Troubleshooting

### "redirect_uri_mismatch"

The redirect URI in your Google OAuth client does not match. To fix it:

1. Go to Google Cloud Console > APIs & Services > Credentials.
2. Edit your OAuth client.
3. Add the exact redirect URI: `https://stategraph.example.com/oauth2/google/callback`.

### "access_denied"

Causes and fixes:

- The user's email domain is not allowed: check `STATEGRAPH_OAUTH_EMAIL_DOMAIN`.
- The user is not in the required Google Group: check the membership.
- The OAuth consent screen is not approved for external users: complete app verification.

### "invalid_client"

The client ID or secret is incorrect. Compare both with the Google Cloud Console, and look for whitespace or newlines.

### Login redirects but nothing happens

The session cookie may not be set. Causes and fixes:

- `STATEGRAPH_UI_BASE` does not match the URL that you open: make it match exactly.
- HTTPS and HTTP are mixed: use HTTPS everywhere.
- A proxy strips cookies: check the proxy configuration.

### Google Groups not working

Check:

- The service account exists.
- Domain-wide delegation is enabled.
- The admin email is a super admin.
- The JSON key is valid.
- The scopes are delegated in the Admin Console.

## Complete example

### Environment file (.env)

```bash
# Database
DB_HOST=db
DB_PORT=5432
DB_USER=stategraph
DB_PASS=your-secure-password
DB_NAME=stategraph

# Stategraph
STATEGRAPH_UI_BASE=https://stategraph.example.com

# Google OAuth
STATEGRAPH_OAUTH_TYPE=google
STATEGRAPH_OAUTH_CLIENT_ID=123456789-abc123.apps.googleusercontent.com
STATEGRAPH_OAUTH_CLIENT_SECRET=GOCSPX-xxxxxxxxxxxxx
STATEGRAPH_OAUTH_EMAIL_DOMAIN=example.com
STATEGRAPH_OAUTH_REDIRECT_BASE=https://stategraph.example.com

# Optional: Google Groups
# STATEGRAPH_OAUTH_GOOGLE_GROUP=stategraph-users@example.com
# STATEGRAPH_OAUTH_GOOGLE_ADMIN_EMAIL=admin@example.com
# STATEGRAPH_OAUTH_GOOGLE_SERVICE_ACCOUNT_JSON='{...}'
```

### Docker Compose

```yaml
services:
  db:
    image: postgres:17-alpine
    environment:
      POSTGRES_PASSWORD: "your-secure-password"
      POSTGRES_USER: "stategraph"
      POSTGRES_DB: "stategraph"
    volumes:
      - db:/var/lib/postgresql/data/
    networks:
      - stategraph

  server:
    image: ghcr.io/stategraph/stategraph-server:latest
    env_file:
      - .env
    ports:
      - "8080:8080"
    depends_on:
      db:
        condition: service_healthy
    networks:
      - stategraph

networks:
  stategraph:

volumes:
  db:
```

## Next steps

- [OIDC Configuration](/docs/admin/access-control/oidc) for other providers
- [Group Rules](/docs/admin/access-control/group-rules) to grant capabilities from identity provider groups
- [Environment Variables](/docs/admin/operations/environment-variables)
- [API Reference](/docs/reference/api)
