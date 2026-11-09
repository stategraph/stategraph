---
title: Tenants and Administration
description: Learn how tenants, members, invitations, and instance and tenant admins work in a self-hosted Stategraph install.
order: 5
---


A tenant is an isolated workspace with its own states, transactions, members, and settings, and admins control who can act in it. Each state belongs to exactly one tenant.

A self-hosted install starts with one tenant that all users share. It is named `Default` unless you set `STATEGRAPH_DEFAULT_TENANT_NAME`. You need more tenants only for hard isolation between groups of infrastructure.

## Instance admin vs tenant admin

The `admin` capability has two scopes:

- Instance admin (`{"admin": {}}`, no tenants named) administers the whole installation: all tenants, the global user list, and installation settings. The first user to complete setup is an instance admin.
- Tenant admin (`{"admin": {"tenants": ["<tenant-id>"]}}`) administers only those tenants: their membership, invitations, [group rules](/docs/admin/access-control/group-rules), and settings, including deleting states in them. A tenant admin cannot see the installation-wide user list or other tenants.

`users-manage` is a separate, narrower right:

- Scoped to a tenant, it manages that tenant's membership (add, remove, and change the roles of members) without tenant admin.
- Unscoped, it reaches the users of the whole installation.
- It cannot grant tenant admin: no one can grant a right that they do not hold.

The `is_instance_admin` boolean of the [users API](/docs/admin/access-control/local-authentication) grants or revokes instance admin, and user responses show both scopes in `admin_rights`. A revoke leaves a tenant-scoped admin grant untouched. That grant is managed per tenant through the members API.

## Who can act on whom

To edit or delete a user, or to reset a user's password, both conditions must be true:

- The user holds strictly less authority than you.
- The user belongs only to tenants that your grant reaches.

To read a user's details, only the second condition applies.

`admin` outranks `users-manage`, and a wider scope outranks a narrower one. An instance admin can act on a tenant admin, and an unscoped `users-manage` holder on one confined to a single tenant. Equals cannot act on each other, and admins of different tenants cannot either, because neither scope contains the other. If a user belongs to two tenants and you manage only one, you cannot act on that user.

Three cases are outside the rule:

- Creating a user does not act on an existing one. The new user joins those of your tenants that your grant reaches, with the installation's default capabilities. If your grant reaches none of your tenants, the request is refused.
- Granting `admin` needs an unrestricted `admin` grant of your own, whatever else you hold. An unscoped `users-manage` holder can create and delete users, but cannot make any user an admin, itself included.
- Instance admins can delete, demote, and reset each other.

## Membership

A user sees and acts on a tenant only as a member. An admin capability that covers a tenant does not make you a member: add yourself first, or ask to be added. An instance admin who is not a member gets `403 TENANT_MEMBERSHIP_REQUIRED` when managing the tenant. With no session, the error is `401`. New users join the `Default` tenant automatically at sign-in.

## Adding an existing user to a tenant

A tenant administrator, or a `users-manage` holder for the tenant, adds a user who has an account, by user id, on **Settings > Members**. The user becomes a plain member, without tenant-scoped capabilities.

The API call is `POST /api/v1/tenants/{tenant_id}/members` with `{"user_id": "..."}`. It is idempotent, and returns `404` if no such active user exists.

## Changing roles and removing members

On **Settings > Members**, a tenant administrator removes a member, or grants or revokes two independent rights:

- Tenant admin.
- Membership management, which is `users-manage` scoped to the tenant.

The API call is `POST /api/v1/tenants/{tenant_id}/members/set-role?user_id=<user-id>` with `{"tenant_admin": true, "can_manage_users": true}`:

- Send `false` to revoke a right. Omit a field to leave that right unchanged.
- To grant tenant admin, you must be a tenant admin.
- Revoking your own admin, or demoting the tenant's last administrator, returns `409`.

Removing a member (`DELETE /api/v1/tenants/{tenant_id}/members?user_id=<user-id>`) also revokes their tenant-scoped grants, in the same transaction. You cannot remove yourself or the tenant's last administrator.

A member whose admin or `users-manage` grant reaches wider than this tenant, such as an instance admin, cannot be demoted or removed here (`409`).

`GET /api/v1/tenants/{tenant_id}/members` lists the members. Each member has an `admin_scope` and a `users_manage_scope`: `none`, `tenant`, `wider` (the grant also reaches other tenants, but not all of them), or `instance` (the grant covers every tenant).

## Creating a tenant

An instance admin creates a tenant on **Settings > Preferences**, or with `POST /api/v1/tenants` and `{"name": "..."}`:

- Stategraph trims the name.
- A blank name, or one longer than 255 characters, returns `400 INVALID_TENANT_NAME`.
- A name that another tenant uses returns `409 TENANT_NAME_CONFLICT`.

The creator becomes a member, and can appoint a tenant admin. You cannot delete a tenant from the console.

## Renaming and switching tenants

A tenant administrator renames the tenant with the pencil button next to its name on **Settings > Tenant**, or with `PUT /api/v1/tenants/{tenant_id}` and `{"name": "..."}`. The name rules of tenant creation apply. A tenant-scoped `users-manage` holder cannot rename the tenant.

Switch tenants on **Settings > Preferences**. `stategraph user tenants list` (`GET /api/v1/user/tenants`) lists your tenants.

## Invitations

Invite someone who has no account yet on **Settings > Members**. An invitation can also make the invitee a tenant admin.

An invitation is a single-use link that expires after 7 days by default (`STATEGRAPH_INVITATION_TTL_HOURS`). The invitee opens the link and signs in, which creates their account, and joins the tenant. On a password-only install (no OAuth), a new invitee cannot register from the login page: an instance admin creates the user first, on **Settings > Admin**, and then you add the user to the tenant.

Email delivery is optional. Stategraph sends invitation emails through Aegis, the hosted control plane. Without Aegis, a self-hosted install sends no email. This is a supported mode, not an error: Stategraph still creates the invitation, and the console always shows the accept link for you to hand over, and reports no failed send.

## Sessions and capability changes

A session holds a snapshot of the capabilities that it was created with.

- A change to a user's capabilities (promote, demote, or admin on or off) revokes that user's active browser sessions. Their next request needs a new sign-in, which gets the new rights.
- A change to your own membership does not sign you out: only your other sessions end.
- API tokens keep the access they were created with until they expire or are revoked.

## Linking a GitHub installation

A tenant admin who is a member of the tenant can link their own GitHub App installation to it, with no instance admin, by verifying with GitHub.

1. The flow starts from the **Get Started** screen, at `GET /api/v1/tenants/{tenant_id}/vcs-installations/github/claim/start`.
2. GitHub returns to `/api/v1/vcs-installations/github/claim/callback`.
3. The console links one of the installations that you proved control of, with `POST /api/v1/tenants/{tenant_id}/vcs-installations/github/claim`.

To turn this on in a self-hosted deployment:

- Set the OAuth client of the GitHub App for the server: `GITHUB_APP_CLIENT_ID` and `GITHUB_APP_CLIENT_SECRET`.
- Register `{STATEGRAPH_OAUTH_REDIRECT_BASE}/api/v1/vcs-installations/github/claim/callback` as a callback URL on the GitHub App.
- Grant the GitHub App the organization **Members: read** permission.

For the GitHub App setup, see [Enable orchestration](/docs/admin/self-hosting/orchestration).

## Linking a GitLab installation

A tenant admin who is a member of the tenant connects a GitLab group to it, with no instance admin.

- The GitLab connection on the **Get Started** screen calls `POST /api/v1/tenants/{tenant_id}/vcs-installations/gitlab` with the group id, the group name, and a GitLab access token.
- The response gives the webhook secret exactly once.
- The installation stays `pending` until GitLab delivers the first webhook signed with that secret.

On **Settings > Integrations**, a tenant admin can also:

- Rotate the access token, the webhook secret, or both (`PUT /api/v1/tenants/{tenant_id}/vcs-installations/gitlab/{group_id}`).
- Unlink a GitHub or GitLab installation from the tenant (`DELETE /api/v1/tenants/{tenant_id}/vcs-installations/{provider}/{installation_core_id}`).

In a self-hosted deployment, GitLab provisioning needs Orchestration turned on and `STATEGRAPH_FDW_PROVISIONER_PASSWORD` set. Without that password, the provisioning endpoint returns `503`. For the GitLab connection steps, see [Enable orchestration](/docs/admin/self-hosting/orchestration).

## Next steps

- [Access Tokens and Capabilities](/docs/admin/access-control/access-tokens): the capability model behind admin and `users-manage`
- [Group Rules](/docs/admin/access-control/group-rules): grant tenant capabilities from identity provider groups
- [Local Authentication](/docs/admin/access-control/local-authentication): creating and managing users
- [Environment variables](/docs/admin/operations/environment-variables): `STATEGRAPH_DEFAULT_TENANT_NAME`, `STATEGRAPH_INVITATION_TTL_HOURS`, and the Aegis settings
