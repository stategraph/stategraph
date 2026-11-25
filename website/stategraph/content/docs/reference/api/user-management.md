---
title: User management
description: API endpoints that list, create, update, and delete users, change passwords, set the installation admin, and create service accounts.
order: 3
---


These endpoints list, create, update, and delete users, change their passwords, set installation admin status, and create service accounts.

## Permissions

- Each endpoint requires an `admin` or `users-manage` grant of any scope.
- Update, delete, and change password also require strictly more authority than the target user, who must belong only to tenants that your grant reaches. Otherwise the answer is `403 CAPABILITY_UNAUTHORIZED`.
- Get user details requires only that the user belongs to tenants that your grant reaches.

See [Tenants](/docs/admin/access-control/tenants) for who can act on whom.

## Users

### List users

```text
GET /api/v1/users
```

Returns the users that your grant reaches, newest first, with cursor-based pagination and filters. When your `admin` or `users-manage` grant covers every tenant, the list holds every user of the installation, including users who belong to no tenant. When your grant is scoped to tenants, the list holds the members of those tenants.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `type` | query | No | Filter by user type: `user`, `api`, or `system` |
| `limit` | query | No | Max results (default: 25) |
| `cursor` | query | No | Pagination cursor from the previous response |
| `search` | query | No | Search by name or email |

Response:

```json
{
  "users": [
    {
      "id": "f30ed1f9-be44-46a3-9050-03e9561e94f0",
      "name": "John Doe",
      "email": "john@example.com",
      "admin_rights": { "is_instance_admin": false, "is_tenant_admin": false },
      "type": "user",
      "auth_origin": "local",
      "created_at": "2024-01-15T10:30:00Z"
    }
  ],
  "total_count": 10,
  "limit": 25,
  "has_more": false,
  "next_cursor": null
}
```

| Field | Type | Description |
|-------|------|-------------|
| `users` | array | List of user objects |
| `total_count` | integer | Total number of matching users |
| `limit` | integer | Limit used for this request |
| `has_more` | boolean | Whether more results are available |
| `next_cursor` | string | Cursor for the next page (null if no more) |
| `auth_origin` | string | Authentication origin (for example `local`, `google`, `oidc`) |
| `admin_rights.is_instance_admin` | boolean | Whether the user administers the whole installation |
| `admin_rights.is_tenant_admin` | boolean | Whether the user administers named tenants rather than the installation. Never true at the same time as `is_instance_admin` |

While more users follow, the response carries a `Link` header with `rel="next"`. Its URL asks for the next page, with your `type`, `search`, and `limit`. The last page has no `Link` header.

```text
Link: <https://stategraph.example.com/api/v1/users?limit=25&cursor=...>; rel="next"
```

### Get user details

```text
GET /api/v1/users/detail?user_id={user_id}
```

Returns the details of one user.

Response:

```json
{
  "id": "f30ed1f9-be44-46a3-9050-03e9561e94f0",
  "name": "John Doe",
  "email": "john@example.com",
  "admin_rights": { "is_instance_admin": false, "is_tenant_admin": false },
  "type": "user",
  "created_at": "2024-01-15T10:30:00Z"
}
```

The response also includes `auth_origin` (how the user authenticates) and `avatar_url` when they are set.

### Create user

```text
POST /api/v1/users
```

Creates a user account.

Request body:

```json
{
  "name": "Jane Doe",
  "email": "jane@example.com",
  "password": "secure-password",
  "is_instance_admin": false
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes | Display name |
| `email` | string | No | Email address (used for login) |
| `password` | string | Yes | Password (8 to 128 characters) |
| `is_instance_admin` | boolean | No | Grant the installation-wide admin capability (default: false). You cannot create a tenant-scoped admin here. Grant one afterwards with [Set member role](/docs/reference/api/tenants#set-member-role). |

Response: `201 Created`

```json
{
  "id": "a1b2c3d4-5678-90ab-cdef-1234567890ab",
  "name": "Jane Doe",
  "email": "jane@example.com",
  "is_instance_admin": false
}
```

The new user joins each of your tenants that your grant reaches. If it reaches none, the answer is `403`. Setting `is_instance_admin` requires an installation-wide `admin` grant.

### Update user

```text
PUT /api/v1/users/update?user_id={user_id}
```

Updates a user.

Request body:

```json
{
  "name": "Jane Smith",
  "email": "jane.smith@example.com"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | No | Display name |
| `email` | string | No | Email address (admin sessions only) |
| `avatar_url` | string | No | Avatar URL |
| `is_instance_admin` | boolean | No | Grant or revoke the installation-wide admin capability (admin sessions only), the same write and the same refusals as `POST /api/v1/users/set-instance-admin`. Omit it to leave the admin grant of the user unchanged. |

Response: `200 OK` with the updated user object, with the same `admin_rights` object as the users list and the user details.

`is_instance_admin: false` on the last installation admin returns `400 CANNOT_REMOVE_LAST_ADMIN`, and on yourself returns `400 CANNOT_ACT_ON_SELF`. Either refusal discards the whole update: `name`, `email`, and `avatar_url` are written in the same transaction, so none of them is saved.

### Delete user

```text
DELETE /api/v1/users/delete?user_id={user_id}
```

Soft-deletes a user: marks the user as deleted and invalidates their API keys.

Response:

```json
{
  "id": "f30ed1f9-be44-46a3-9050-03e9561e94f0",
  "deleted": true
}
```

Errors:

- `403` when the target holds as much authority as you or more, or belongs to a tenant that your grant does not reach. Instance admins are exempt and can delete each other.
- A `users-manage` holder cannot delete an admin or another `users-manage` holder.
- `400 CANNOT_DELETE_LAST_ADMIN` for the last instance admin.
- `400 CANNOT_DELETE_OWN_ACCOUNT` for your own account.

### Change user password

```text
POST /api/v1/users/change-password?user_id={user_id}
```

Changes the password of a user.

Request body:

```json
{
  "new_password": "new-secure-password",
  "current_password": "old-password"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `new_password` | string | Yes | New password (8 to 128 characters) |
| `current_password` | string | Conditional | Required when you change your own password, whatever capabilities you hold, admins included |

Response:

```json
{
  "id": "f30ed1f9-be44-46a3-9050-03e9561e94f0",
  "password_changed": true
}
```

Another user's password requires no `current_password`. Instance admins are exempt from the authority comparison in [Permissions](#permissions), and can reset each other's passwords.

### Set installation admin status

```text
POST /api/v1/users/set-instance-admin?user_id={user_id}
```

Sets the installation-wide `admin` capability of the user to the requested value:

- `true` writes an unrestricted admin capability, and replaces any tenants allow-list that the user held.
- `false` removes an unrestricted admin capability and leaves a tenant-scoped one untouched. On a user who never held the installation-wide grant, it changes nothing.

Request body:

```json
{
  "is_instance_admin": true
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `is_instance_admin` | boolean | Yes | The installation-wide admin grant to leave the user with |

Response:

```json
{
  "id": "f30ed1f9-be44-46a3-9050-03e9561e94f0",
  "is_instance_admin": true
}
```

The value is set, not toggled: the server never reads the current grant to invert it, so a repeated call changes nothing. Removing the grant from the last installation admin returns `400 CANNOT_REMOVE_LAST_ADMIN`, and removing your own returns `400 CANNOT_ACT_ON_SELF`, whoever else holds one.

## Service accounts

### Create service account

```text
POST /api/v1/api-users
```

Creates a service account (API user) for programmatic access.

Request body:

```json
{
  "name": "ci-production",
  "tenant_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

Response:

```json
{
  "user_id": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
  "token": "eyJhbGciOiJIUzI1NiIs..."
}
```

The response shows the token only one time. Save it immediately.
