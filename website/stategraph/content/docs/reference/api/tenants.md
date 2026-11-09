---
title: Tenants and members
description: API endpoints that create and rename tenants, manage members and their roles, and create, reissue, revoke, preview, and accept invitations.
order: 4
---


These endpoints create and rename tenants, and manage membership, roles, and invitations. Unless an entry says otherwise, they require tenant administrator rights or tenant-scoped `users-manage`. See [Tenants](/docs/admin/access-control/tenants) for the admin model.

## Tenants

### Create tenant

```text
POST /api/v1/tenants
```

Creates a tenant and adds the caller as a member. Installation admin only. The server trims the name. The answer is `400` when the name is blank, and `409` when another tenant has it.

Request body:

```json
{ "name": "Acme" }
```

Response: `201 Created` with `{ "id": "...", "name": "Acme" }`.

### Rename tenant

```text
PUT /api/v1/tenants/{tenant_id}
```

Changes the display name of the tenant. Requires tenant administrator rights: tenant-scoped `users-manage` is not enough. The name rules of Create tenant apply.

Request body:

```json
{ "name": "Acme Platform" }
```

Response: `200 OK` with `{ "id": "...", "name": "..." }`.

## Members

### List members

```text
GET /api/v1/tenants/{tenant_id}/members
```

Returns a page of the active members of the tenant, oldest membership first.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `cursor` | query | No | Pagination cursor from a previous response's `next_cursor` |
| `limit` | query | No | Max results (default: 25) |

Response:

```json
{
  "members": [
    {
      "user_id": "f30ed1f9-be44-46a3-9050-03e9561e94f0",
      "name": "Jane Doe",
      "email": "jane@example.com",
      "type": "user",
      "joined_at": "2026-06-04T10:30:00Z",
      "admin_scope": "tenant",
      "users_manage_scope": "none"
    }
  ],
  "total_count": 1,
  "limit": 25,
  "has_more": false,
  "next_cursor": null
}
```

`admin_scope` and `users_manage_scope` are each `none`, `tenant`, `wider` (the grant also reaches other tenants, but not all of them), or `instance` (the grant covers every tenant, for example for an instance admin).

### Add member

```text
POST /api/v1/tenants/{tenant_id}/members
```

Adds an existing user as a plain member. Idempotent: an existing member returns unchanged with `200`, and a new membership returns `201`. The answer is `404` when no such active user exists. Invite a person who has no account.

Request body:

```json
{ "user_id": "f30ed1f9-be44-46a3-9050-03e9561e94f0" }
```

Response: `200 OK` or `201 Created` with the member object.

### Set member role

```text
POST /api/v1/tenants/{tenant_id}/members/set-role?user_id={user_id}
```

Grants or revokes the tenant administrator and membership management rights of a member. The two are independent: omit a field to leave that right unchanged. `tenant_admin: true` requires tenant administrator rights. The answer is `409` when you demote yourself or the last administrator, or edit a member whose grant is wider than this tenant.

Request body:

```json
{ "tenant_admin": true, "can_manage_users": true }
```

Response: `200 OK` with the member object and the scopes actually stored.

### Remove member

```text
DELETE /api/v1/tenants/{tenant_id}/members?user_id={user_id}
```

Removes the membership and revokes the tenant-scoped grants of the user in one transaction. You cannot remove yourself or the last administrator of the tenant. The answer is `404` when the user is not a member, and `409` when the grant of the member is wider than this tenant.

Response: `200 OK` with `{ "user_id": "...", "removed": true }`.

## Invitations

### List invitations

```text
GET /api/v1/tenants/{tenant_id}/invitations
```

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `cursor` | query | No | Pagination cursor from a previous response's `next_cursor` |
| `limit` | query | No | Max results (default: 25) |

Response: `invitations`, plus `total_count`, `limit`, `has_more`, and `next_cursor`. Each invitation has `id`, `email`, `role` (`member` or `admin`), `status` (`pending`, `accepted`, `revoked`, or `expired`), `invited_by_name`, `created_at`, `expires_at`, `send_count`, and `delivered`.

### Create invitation

```text
POST /api/v1/tenants/{tenant_id}/invitations
```

Creates an invitation and sends the email. Delivery is best-effort, so the response always has a copyable `invite_url`. `tenant_admin: true` requires tenant administrator rights. The answer is `409` when the address already has a live invitation (reissue it instead), and `429` when a rate limit is hit.

Request body:

```json
{ "email": "john@example.com", "tenant_admin": false }
```

Response: `201 Created`

```json
{
  "invitation": { "id": "...", "email": "john@example.com", "role": "member", "status": "pending", "...": "..." },
  "invite_url": "https://stategraph.example.com/invitations/accept?token=...",
  "delivery": "emailed"
}
```

`delivery` is one of `emailed`, `not_configured`, `no_provider_key`, `inviter_has_no_email`, or `transport_failed`.

### Reissue invitation

```text
POST /api/v1/tenants/{tenant_id}/invitations/reissue?id={invitation_id}
```

Makes a new token for a pending invitation, resets its lifetime and send budget, and sends the email again. The previous link stops working. The answer is `404` when the invitation is not this tenant's, `409` when it is no longer pending, and `429` during the send cooldown.

Response: `200 OK` with the same shape as Create invitation.

### Revoke invitation

```text
POST /api/v1/tenants/{tenant_id}/invitations/revoke?id={invitation_id}
```

Invalidates a pending invitation, so that its link can no longer be accepted.

Response: `204 No Content`

### Preview invitation

```text
GET /api/v1/invitations/preview?token={token}
```

Needs no authentication. Returns the public details of an invitation for its accept page: `tenant_name`, `inviter_name`, `role`, `status`, `expires_at`, and the masked recipient address `invited_email_masked`. The answer is `404` for an unknown token, `410` when it expired, and `409` when it was revoked or already accepted.

### Accept invitation

```text
POST /api/v1/invitations/accept
```

Joins the signed-in user to the tenant that the token names. Requires only a valid session. Idempotent for an existing member.

Request body:

```json
{ "token": "..." }
```

Response:

```json
{
  "tenant_id": "550e8400-e29b-41d4-a716-446655440000",
  "tenant_name": "Acme",
  "already_member": false,
  "email_mismatch": false
}
```
