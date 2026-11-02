---
title: OIDC Configuration
description: Set up Stategraph sign-in through any OIDC provider, such as Okta, Auth0, Azure AD, Keycloak, AWS Cognito, or GitLab.
order: 4
---


Stategraph signs users in through any OpenID Connect (OIDC) identity provider, such as Okta, Auth0, Azure Active Directory (Entra ID), Keycloak, OneLogin, PingIdentity, AWS Cognito, or GitLab.

## Basic configuration

### Required environment variables

```bash
# Enable OIDC
STATEGRAPH_OAUTH_TYPE=oidc

# Your OIDC provider's issuer URL
STATEGRAPH_OAUTH_OIDC_ISSUER_URL=https://your-provider.com

# OAuth client credentials
STATEGRAPH_OAUTH_CLIENT_ID=your-client-id
STATEGRAPH_OAUTH_CLIENT_SECRET=your-client-secret

# Your Stategraph URL
STATEGRAPH_UI_BASE=https://stategraph.example.com
```

### Optional environment variables

```bash
# Restrict to an email domain
STATEGRAPH_OAUTH_EMAIL_DOMAIN=example.com

# Callback URL base (if different from the UI base)
STATEGRAPH_OAUTH_REDIRECT_BASE=https://stategraph.example.com
```

!!! note "Callback URL"
    Register the callback URL `{STATEGRAPH_OAUTH_REDIRECT_BASE}/oauth2/oidc/callback` with your OIDC provider. Without `STATEGRAPH_OAUTH_REDIRECT_BASE`, the base is `http://localhost:<port>`, for local development only. Stategraph logs the callback URL at startup.

With OIDC, the sign-in page forwards to your identity provider without a click.

## Provider-specific setup

### Okta

#### Create the application

1. In the Okta Admin Console, go to **Applications** > **Create App Integration**.
2. Select **OIDC - OpenID Connect**, then **Web Application**.
3. Set **App integration name** to Stategraph, **Grant type** to Authorization Code, **Sign-in redirect URIs** to `https://stategraph.example.com/oauth2/oidc/callback`, and **Sign-out redirect URIs** to `https://stategraph.example.com`.
4. Save, and copy the Client ID and Client Secret.

#### Configuration

```bash
STATEGRAPH_OAUTH_TYPE=oidc
STATEGRAPH_OAUTH_OIDC_ISSUER_URL=https://your-org.okta.com
STATEGRAPH_OAUTH_CLIENT_ID=0oaxxxxxxxxxxxxxx
STATEGRAPH_OAUTH_CLIENT_SECRET=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

### Auth0

#### Create the application

1. In the Auth0 Dashboard, go to **Applications** > **Create Application**.
2. Select **Regular Web Applications**.
3. In Settings, set **Allowed Callback URLs** to `https://stategraph.example.com/oauth2/oidc/callback` and **Allowed Logout URLs** to `https://stategraph.example.com`.
4. Copy the Domain, Client ID, and Client Secret.

#### Configuration

```bash
STATEGRAPH_OAUTH_TYPE=oidc
STATEGRAPH_OAUTH_OIDC_ISSUER_URL=https://your-tenant.auth0.com
STATEGRAPH_OAUTH_CLIENT_ID=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
STATEGRAPH_OAUTH_CLIENT_SECRET=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

### Azure AD (Entra ID)

#### Register the application

1. In Azure Portal > Azure Active Directory, go to **App registrations** > **New registration**.
2. Set **Name** to Stategraph, **Supported account types** to accounts in this organizational directory only, and **Redirect URI** to Web with `https://stategraph.example.com/oauth2/oidc/callback`.
3. After creation, copy the **Application (client) ID**.
4. Go to **Certificates & secrets** > **New client secret**, and copy the secret value.

#### Configuration

```bash
STATEGRAPH_OAUTH_TYPE=oidc
STATEGRAPH_OAUTH_OIDC_ISSUER_URL=https://login.microsoftonline.com/{tenant-id}/v2.0
STATEGRAPH_OAUTH_CLIENT_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
STATEGRAPH_OAUTH_CLIENT_SECRET=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

Replace `{tenant-id}` with your Azure AD tenant ID.

### Keycloak

#### Create the client

1. In the Keycloak Admin Console, select your realm and go to **Clients** > **Create client**.
2. Set **Client ID** to stategraph, **Client Protocol** to openid-connect, and **Root URL** to `https://stategraph.example.com`.
3. After creation, set **Valid Redirect URIs** to `https://stategraph.example.com/oauth2/oidc/callback`, and enable **Client authentication**.
4. Copy the client secret from the **Credentials** tab.

#### Configuration

```bash
STATEGRAPH_OAUTH_TYPE=oidc
STATEGRAPH_OAUTH_OIDC_ISSUER_URL=https://keycloak.example.com/realms/your-realm
STATEGRAPH_OAUTH_CLIENT_ID=stategraph
STATEGRAPH_OAUTH_CLIENT_SECRET=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

### AWS Cognito

#### Create the user pool and app client

1. In the AWS Cognito Console, create or select a User Pool, and go to **App clients** > **Create app client**.
2. Set **App client name** to stategraph, and enable **Generate client secret**.
3. Under **App integration** > **Domain**, set up a Cognito domain or a custom domain.
4. Set the callback URL to `https://stategraph.example.com/oauth2/oidc/callback`.

#### Configuration

```bash
STATEGRAPH_OAUTH_TYPE=oidc
STATEGRAPH_OAUTH_OIDC_ISSUER_URL=https://cognito-idp.{region}.amazonaws.com/{user-pool-id}
STATEGRAPH_OAUTH_CLIENT_ID=xxxxxxxxxxxxxxxxxxxxxxxxxx
STATEGRAPH_OAUTH_CLIENT_SECRET=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

### GitLab

#### Create the application

1. Go to GitLab > User Settings > Applications, or to Admin Area > Applications for an instance-wide application.
2. Set **Name** to Stategraph, **Redirect URI** to `https://stategraph.example.com/oauth2/oidc/callback`, and **Scopes** to `openid`, `email`, and `profile`.
3. Save, and copy the Application ID and Secret.

#### Configuration

```bash
STATEGRAPH_OAUTH_TYPE=oidc
STATEGRAPH_OAUTH_OIDC_ISSUER_URL=https://gitlab.com
# Or your self-hosted GitLab URL
STATEGRAPH_OAUTH_CLIENT_ID=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
STATEGRAPH_OAUTH_CLIENT_SECRET=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

## Finding the issuer URL

The issuer URL is the base URL of your OIDC provider. Most providers publish their discovery document at:

```text
{issuer_url}/.well-known/openid-configuration
```

For example:

- Okta: `https://your-org.okta.com/.well-known/openid-configuration`
- Auth0: `https://your-tenant.auth0.com/.well-known/openid-configuration`
- Azure AD: `https://login.microsoftonline.com/{tenant}/v2.0/.well-known/openid-configuration`

## Docker Compose example

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

      STATEGRAPH_OAUTH_TYPE: "oidc"
      STATEGRAPH_OAUTH_OIDC_ISSUER_URL: "https://your-provider.com"
      STATEGRAPH_OAUTH_CLIENT_ID: "your-client-id"
      STATEGRAPH_OAUTH_CLIENT_SECRET: "${OIDC_CLIENT_SECRET}"
      STATEGRAPH_OAUTH_EMAIL_DOMAIN: "example.com"
      STATEGRAPH_OAUTH_REDIRECT_BASE: "https://stategraph.example.com"
    ports:
      - "8080:8080"
```

## Troubleshooting

### "Invalid issuer"

The issuer URL is incorrect or unreachable. Check:

- The issuer URL is correct.
- `curl {issuer_url}/.well-known/openid-configuration` answers.
- Stategraph can reach the provider over the network.

### "Invalid client"

The client ID or secret is incorrect. Check:

- The credentials match your provider's dashboard.
- The values have no whitespace or newlines.
- The client is not deleted or disabled.

### "Redirect URI mismatch"

The callback URL does not match the one in the provider. It must be exactly `https://stategraph.example.com/oauth2/oidc/callback`. Check the protocol (http or https), the hostname and port, and that there is no trailing slash.

### "Access denied" after authentication

Check:

- The user's email is in the domain that `STATEGRAPH_OAUTH_EMAIL_DOMAIN` allows.
- The group or role assignments in the provider, if any.

### Session not persisting

Cookies are not set correctly. Check:

- `STATEGRAPH_UI_BASE` matches the access URL exactly.
- HTTPS is used in production.
- No proxy interferes.

## Verifying the configuration

### Test OIDC discovery

```bash
curl https://your-provider.com/.well-known/openid-configuration | jq
```

Response:

```json
{
  "issuer": "https://your-provider.com",
  "authorization_endpoint": "https://your-provider.com/authorize",
  "token_endpoint": "https://your-provider.com/oauth/token",
  "userinfo_endpoint": "https://your-provider.com/userinfo",
  "jwks_uri": "https://your-provider.com/.well-known/jwks.json",
  "id_token_signing_alg_values_supported": ["RS256"]
}
```

Stategraph verifies ID tokens signed with RS256, RS384, RS512, PS256, PS384, PS512, ES256, ES384, ES512, or EdDSA. When the provider lists none of these, the sign-in provider cannot be set up. The client authenticates at the token endpoint with HTTP Basic, and with its credentials in the request body when the provider refuses Basic.

### Check the Stategraph logs

```bash
docker compose logs server | grep -i oauth
```

Look for errors or successful authentication messages. If the sign-in provider cannot be set up, Stategraph logs the reason, tries again every second, and accepts no requests until the setup succeeds.

## Security best practices

- Use HTTPS for Stategraph and the callback URLs.
- Restrict email domains to your organization.
- Keep client secrets in a secrets manager, and rotate them periodically.
- Enable MFA at the identity provider.
- Audit authorized users regularly.

## Next steps

- [Google OAuth Setup](/docs/admin/access-control/google-oauth) for Google-specific features
- [Group Rules](/docs/admin/access-control/group-rules) to grant capabilities from identity provider groups
- [Environment Variables](/docs/admin/operations/environment-variables)
- [API Reference](/docs/reference/api)
