---
title: VCS installations
description: API endpoints for GitHub and GitLab installations: tenant links, repositories, pull requests, dirspaces, work manifests, groups, and webhooks.
order: 11
---


These endpoints link GitHub App and GitLab installations to a tenant for Stategraph Orchestration. They also read and manage the repositories, pull requests, dirspaces, and work manifests of each installation. See [Connect GitHub or GitLab](/docs/admin/self-hosting/orchestration) for the server-side setup.

## Tenant installations

These endpoints link installations to a tenant.

- GitHub identity claims require `GITHUB_APP_CLIENT_ID` and `GITHUB_APP_CLIENT_SECRET` on the server (`503` otherwise).
- GitLab provisioning requires Stategraph Orchestration (`503` when unavailable).

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/v1/tenants/{tenant_id}/vcs-installations` | Installations linked to the tenant (`provider`, `installation_core_id`, timestamps) |
| `GET` | `/api/v1/tenants/{tenant_id}/vcs-installations/github/claim/start` | Redirect the browser to GitHub to prove the caller administers an installation. `?rd` is where to return afterwards; a claim that cannot start redirects back with a `github_claim` result of `unavailable`, `not_member`, or `error` |
| `GET` | `/api/v1/vcs-installations/github/claim/callback` | GitHub returns the user here. Sets a short-lived proof cookie and redirects back to the console; never links an installation itself |
| `GET` | `/api/v1/tenants/{tenant_id}/vcs-installations/github/claimable` | Installations the caller proved control of that are still unlinked. Requires the proof cookie (`412` without it) |
| `POST` | `/api/v1/tenants/{tenant_id}/vcs-installations/github/claim` | Link a proven installation to this tenant. Body `{ "installation_core_id" }`; `409` when linked to another tenant |
| `GET` | `/api/v1/vcs-installations/github/unclaimed` | Installations not linked to any tenant (`?cursor`, `?limit`, default 100). Installation admin |
| `POST` | `/api/v1/tenants/{tenant_id}/vcs-installations/gitlab` | Provision a GitLab group installation. Body `{ "name", "group_id", "access_token" }`; the response carries the `webhook_secret` once |
| `PUT` | `/api/v1/tenants/{tenant_id}/vcs-installations/gitlab/{group_id}` | Rotate the access token (`access_token`) or regenerate the webhook secret (`regenerate_webhook_secret: true`) |
| `PUT` | `/api/v1/tenants/{tenant_id}/vcs-installations/{provider}/{installation_core_id}` | Link an installation to the tenant. Installation admin |
| `DELETE` | `/api/v1/tenants/{tenant_id}/vcs-installations/{provider}/{installation_core_id}` | Unlink an installation from the tenant |

## Installations

Most of the endpoints below exist for both GitHub and GitLab, with the same parameters and responses. Each entry lists its paths. These path parameters are strings:

- `installation_id`: the installation. A GitLab installation is a GitLab group, and its installation ID is the numeric group ID.
- `repo_id`: the repository. A GitLab repository is a GitLab project, and its repository ID is the numeric project ID.
- `work_manifest_id`: the work manifest.

Four GitLab endpoints call GitLab with the GitLab account that is linked to the caller. They list installations and groups, return the webhook, and set the access token. To link a GitLab group to a tenant, use the [tenant installation](#tenant-installations) endpoints.

### List installations

```text
GET /api/v1/user/github/installations
GET /api/v1/gitlab/installations
```

Returns the GitHub or GitLab installations that the current user can access. Status codes: `200`, `403`.

```json
{
  "installations": [...]
}
```

```bash
curl -X GET \
  https://app.stategraph.cloud/api/v1/user/github/installations \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

```bash
curl -X GET \
  https://app.stategraph.cloud/api/v1/gitlab/installations \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

### List GitLab groups

```text
GET /api/v1/gitlab/groups
```

Returns the GitLab groups that the GitLab account of the current user can see, sorted by name. Each entry has the numeric group ID and the full group name. Status codes: `200`.

```json
[
  {
    "id": 1043,
    "name": "Acme"
  }
]
```

### Get GitLab webhook

```text
GET /api/v1/gitlab/installations/{id}/webhook
```

Registers a GitLab group as an installation if it is not one yet, and returns the webhook settings to configure in GitLab. The caller must have the Maintainer or Owner role in the group. `id` (integer) is the GitLab group ID.

Status codes: `200`, and `403` when the caller does not have the Maintainer or Owner role in the group.

Response (schema `gitlab-webhook`):

```json
{
  "state": "pending",
  "webhook_secret": "string",
  "webhook_url": "https://app.stategraph.cloud/api/v1/gitlab/events"
}
```

| Field | Description |
|-------|-------------|
| `webhook_url` | The URL to enter as the GitLab webhook URL |
| `webhook_secret` | The value to enter as the GitLab webhook secret token |
| `state` | `pending` until Orchestration receives the first webhook delivery for the group, then `installed` |

### Set GitLab access token

```text
PUT /api/v1/gitlab/installations/{installation_id}/access-token
```

Creates or updates the GitLab access token that Orchestration uses to call GitLab for a group. The caller must have the Maintainer or Owner role in the group. Status codes: `200`, `403`.

Request body (schema `gitlab-access-token`):

```json
{
  "access_token": "string"
}
```

```bash
curl -X PUT \
  https://app.stategraph.cloud/api/v1/gitlab/installations/{installation_id}/access-token \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"access_token": "YOUR_GITLAB_TOKEN"}'
```

## Repositories and pull requests

### List repositories

```text
GET /api/v1/github/installations/{installation_id}/repos
GET /api/v1/gitlab/installations/{installation_id}/repos
```

Returns the repositories of an installation. Status codes: `200`, `403`.

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `page` | array[string] | No | Pagination token |

```json
{
  "repositories": [...]
}
```

### Refresh repositories

```text
POST /api/v1/github/installations/{installation_id}/repos/refresh
```

Starts a refresh of the repositories of a GitHub installation. Returns a task ID to poll with [`GET /api/v1/tasks/{task_id}`](/docs/reference/api/transactions#tasks). Status codes: `200`, `403`.

```json
{
  "id": "string"
}
```

### Delete repository

```text
DELETE /api/v1/github/installations/{installation_id}/repos/{repo_id}
DELETE /api/v1/gitlab/installations/{installation_id}/repos/{repo_id}
```

Removes a repository from an installation:

- GitHub: the repository must be archived on GitHub, and the caller must be an admin of the organization that owns it.
- GitLab: the project must be archived in GitLab, and the caller must have the Maintainer or Owner role in the group that owns it.

Status codes: `200` with an empty object, `400` with the error `id` `INVALID_REPO_ID`, `REPO_NOT_FOUND`, or `REPO_NOT_ARCHIVED`, and `403`.

```bash
curl -X DELETE \
  https://app.stategraph.cloud/api/v1/github/installations/{installation_id}/repos/{repo_id} \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

```bash
curl -X DELETE \
  https://app.stategraph.cloud/api/v1/gitlab/installations/{installation_id}/repos/{repo_id} \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

### List pull requests

```text
GET /api/v1/github/installations/{installation_id}/pull-requests
```

Returns the pull requests of a GitHub installation. Status codes: `200`, `403`.

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `page` | array[string] | No | Pagination token |
| `pr` | integer | No | Filter by pull request number |

```json
{
  "pull_requests": [...]
}
```

## Dirspaces and work manifests

### List dirspaces

```text
GET /api/v1/github/installations/{installation_id}/dirspaces
GET /api/v1/gitlab/installations/{installation_id}/dirspaces
```

Returns the directory and workspace pairs (dirspaces) of an installation. Status codes: `200`, `400`, `403`.

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `page` | array[string] | No | Pagination token |
| `q` | string | No | Search query |
| `d` | string | No | Sort direction: `asc` or `desc` |
| `tz` | string | No | Timezone for date filtering |
| `limit` | integer | No | Maximum number of results |

```json
{
  "dirspaces": [...]
}
```

### List work manifests

```text
GET /api/v1/github/installations/{installation_id}/work-manifests
GET /api/v1/gitlab/installations/{installation_id}/work-manifests
```

Returns the work manifests of an installation. Status codes: `200`, `400`, `403`.

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `page` | array[string] | No | Pagination token |
| `q` | string | No | Search query |
| `d` | string | No | Sort direction: `asc` or `desc` |
| `tz` | string | No | Timezone for date filtering |
| `limit` | integer | No | Maximum number of results |

```json
{
  "work_manifests": [...]
}
```

### Get work manifest

```text
GET /api/v1/github/installations/{installation_id}/work-manifests/{work_manifest_id}
GET /api/v1/gitlab/installations/{installation_id}/work-manifests/{work_manifest_id}
```

Returns the details of a work manifest. Status codes: `200`, `403`, `404`.

### Get work manifest outputs

```text
GET /api/v1/github/installations/{installation_id}/work-manifests/{work_manifest_id}/outputs
GET /api/v1/gitlab/installations/{installation_id}/work-manifests/{work_manifest_id}/outputs
```

Returns the outputs and steps of a work manifest. Status codes: `200`, `400`, `403`, `404`.

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `q` | string | No | Search query |
| `page` | array[string] | No | Pagination token |
| `tz` | string | No | Timezone for date filtering |
| `limit` | integer | No | Maximum number of results |
| `lite` | boolean | No | Return a lightweight response (default: false) |

```json
{
  "steps": [...]
}
```

### List workspaces

```text
POST /api/github/v1/work-manifests/{work_manifest_id}/workspaces
```

Returns the workspaces of a GitHub work manifest (schema `work-manifest-workspaces`). Status codes: `200`, `403`.

```bash
curl -X POST \
  https://app.stategraph.cloud/api/github/v1/work-manifests/{work_manifest_id}/workspaces \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```
