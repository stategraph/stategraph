---
title: Users and sign-in
description: API endpoints for the current user, their tenants, and their GitHub and GitLab users, and for login options, login, logout, and first-time setup.
order: 2
---


These endpoints return the current user, their tenants, and their GitHub and GitLab users, sign users in and out, and create the first admin user. For the credentials that each endpoint takes, see [Authentication](/docs/reference/api#authentication).

## Current user

### Get current user

```text
GET /api/v1/whoami
```

Returns the authenticated user.

Response (schema `user`):

```json
{
  "id": "f30ed1f9-be44-46a3-9050-03e9561e94f0",
  "name": "User Name",
  "email": "user@example.com",
  "type": "user",
  "capabilities": { "admin": {} }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Unique user ID (UUID) |
| `name` | string | Display name |
| `email` | string | User email address |
| `type` | enum | `user`, `api`, or `system` |
| `capabilities` | object | The session's capability grants (admin, commit, preview, sudo, users-manage, access-token-create, access-token-refresh). See [Access tokens and capabilities](/docs/admin/access-control/access-tokens). |
| `auth_origin` | string | How the user authenticates (optional) |
| `avatar_url` | string | Avatar image URL (optional) |

Admin status is in `capabilities.admin`. There is no boolean `is_admin` field. This object describes what the identity can do. For the server-wide feature flags, see [Get server capabilities](/docs/reference/api/server#get-server-capabilities).

Example request:

```bash
curl -X GET \
  https://app.stategraph.cloud/api/v1/whoami \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

### Get GitHub user

```text
GET /api/v1/github/whoami
```

Returns the GitHub user of the authenticated user (schema `github-user`). Status codes: `200`, `403`.

```bash
curl -X GET \
  https://app.stategraph.cloud/api/v1/github/whoami \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

### Get GitLab user

```text
GET /api/v1/gitlab/whoami
```

Returns the GitLab user of the authenticated user. Status codes: `200`, and `403` when access is forbidden or no GitLab account is linked to the user.

Response (schema `gitlab-user`):

```json
{
  "username": "string",
  "avatar_url": "string"
}
```

Example request:

```bash
curl -X GET \
  https://app.stategraph.cloud/api/v1/gitlab/whoami \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

### List user tenants

```text
GET /api/v1/user/tenants
```

Returns the tenants that the user can access.

Response:

```json
{
  "results": [
    {
      "id": "tenant-123",
      "name": "Acme"
    }
  ]
}
```

## Sign-in

### Get login options

```text
GET /api/v1/login/options
```

Returns the available authentication methods.

With local authentication only:

```json
{
  "options": []
}
```

When OAuth is configured:

```json
{
  "options": [
    {
      "name": "google",
      "display_name": "Google",
      "url": "/api/v1/login/google"
    }
  ]
}
```

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Provider name (`google` or `oidc`) |
| `display_name` | string | Label for the login button (`STATEGRAPH_OAUTH_DISPLAY_NAME`) |
| `url` | string | Path that starts the login flow for this provider |

### Login with password

```text
POST /api/v1/login/password
```

Authenticates a user with email and password. Local authentication only.

Request body:

```json
{
  "email": "user@example.com",
  "password": "your-password"
}
```

Response:

```json
{
  "session_token": "eyJhbGciOiJIUzI1NiIs...",
  "success": true
}
```

Use the `session_token` for bearer authentication. The response also sets a session cookie for browsers.

### Login with OAuth

```text
GET /api/v1/login/{provider}
```

Starts the OAuth login flow for the provider, named as in `GET /api/v1/login/options`.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `provider` | path | Yes | OAuth provider name |
| `rd` | query | No | Redirect destination after login |

Response: `302` redirect to the OAuth provider, `404` when OAuth is not configured or `provider` is not the configured one, or `503` when OAuth is configured but its sign-in provider is not running.

### Complete OAuth login

```text
GET /api/v1/oauth2/{provider}/complete
```

The provider returns the browser here after authorization. The endpoint sets the session cookie and redirects.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `provider` | path | Yes | OAuth provider name |
| `rd` | query | No | Redirect destination after OAuth completion |

Response: `302` redirect after it sets the session cookie, or `401` when authentication failed.

### Logout

```text
GET /api/v1/logout
```

Clears the session cookie and logs the user out.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `rd` | query | No | Redirect destination after logout |

Response: `302` redirect after it clears the session.

## First-time setup

### Check setup status

```text
GET /api/v1/setup/status
```

Returns whether the deployment still needs its initial setup: it holds no valid license, or it has no human users and authenticates locally. OAuth users arrive through the identity provider, so licensing alone decides it there.

Response:

```json
{
  "needs_setup": false
}
```

### Create first admin user

```text
POST /api/v1/setup/admin
```

Creates the first admin user during initial setup. It works only when no users exist.

Request body:

```json
{
  "email": "admin@example.com",
  "password": "secure-password",
  "name": "Admin User",
  "organization": "Acme"
}
```

Response:

```json
{
  "session_token": "eyJhbGciOiJIUzI1NiIs...",
  "user_id": "f30ed1f9-be44-46a3-9050-03e9561e94f0"
}
```

Use the `session_token` for bearer authentication.
