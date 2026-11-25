---
title: User Commands
description: Use the stategraph user commands to see who you are, list your tenants, manage your access tokens, list users, and set installation admins.
order: 1
---


The `stategraph user` commands show who you are and which tenants you belong to, and create, list, and delete your access tokens. For an installation admin, they also list the installation's users and grant or revoke installation admin.

## Commands

| Command | Description |
|---------|-------------|
| `stategraph user whoami` | Show the current user |
| `stategraph user tenants list` | List the tenants that you belong to |
| `stategraph user access-tokens create` | Create a capability-scoped access token |
| `stategraph user access-tokens list` | List your access tokens |
| `stategraph user access-tokens delete` | Delete (revoke) an access token |
| `stategraph user list` | List the users you manage, with their IDs and admin rights |
| `stategraph user set-instance-admin` | Grant or revoke installation admin |

## stategraph user whoami

Use it to check that authentication works, to see which account you use, and to get your user ID for API calls. `stategraph whoami` is a top-level alias.

```bash
stategraph user whoami
```

### Example

```bash
stategraph user whoami
```

The default output is a `field | value` table:

```text
field                 value
--------------------  ------------------------------------
id                    550e8400-e29b-41d4-a716-446655440000
name                  Jane Smith
email                 jane@example.com
type                  `User
avatar_url
auth_origin           local
capabilities
  admin                 no
  access-token-create   no
  access-token-refresh  no
  plan                  yes
    tenants             all
    states              all
    subgraph            all
  apply                 yes
    tenants             all
    states              all
    subgraph            all
  sudo                  no
  users-manage          no
```

For scripts, use `--format json`:

```bash
stategraph user whoami --format json
```

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "name": "Jane Smith",
  "email": "jane@example.com",
  "type": "user",
  "capabilities": {
    "preview": {},
    "commit": {}
  }
}
```

The `capabilities` object shows what the identity can do: `admin`, `preview`, `commit`, `sudo`, `users-manage`, `access-token-create`, and `access-token-refresh`. `preview` and `commit` are the plan and apply capabilities, which the CLI flags and the table call `plan` and `apply`. `capabilities.admin` gives the admin and role status. There is no boolean `is_admin` flag.

## stategraph user tenants list

```bash
stategraph user tenants list
```

### Example

```bash
stategraph user tenants list
```

The default output is an `id | name` table:

```text
id                                    name
------------------------------------  -----------
550e8400-e29b-41d4-a716-446655440000  production
660e8400-e29b-41d4-a716-446655440001  staging
770e8400-e29b-41d4-a716-446655440002  development
```

For scripts, use `--format simple` (tab-separated, no header) or `--format json`:

```bash
stategraph user tenants list --format simple
```

```text
550e8400-e29b-41d4-a716-446655440000    production
660e8400-e29b-41d4-a716-446655440001    staging
770e8400-e29b-41d4-a716-446655440002    development
```

## stategraph user access-tokens

An access token is a Bearer token for the CLI, Terraform, and the API, limited to a set of capabilities. For the capability model, see [Access tokens and capabilities](/docs/admin/access-control/access-tokens).

### stategraph user access-tokens create

The capability flags limit the token. With no flags, the token gets the capabilities of the session that creates it.

```bash
stategraph user access-tokens create --name ci-prod-apply --apply --apply-modified 'sid=*'
```

| Flag | Description |
|------|-------------|
| `--name <name>` | Name of the token. Required. |
| `--admin` | Grant admin (full access). Restrict with `--admin-tenant <TENANT>`. |
| `--plan` | Grant plan. Restrict with `--plan-tenant <TENANT>`, `--plan-modified <STATE_ID=PATTERN>`, or `--plan-pulled-in <STATE_ID=PATTERN>`. |
| `--apply` | Grant apply. Restrict with `--apply-tenant <TENANT>`, `--apply-modified <STATE_ID=PATTERN>`, or `--apply-pulled-in <STATE_ID=PATTERN>`. |
| `--users-manage` | Grant users-manage. Restrict with `--users-manage-tenant <TENANT>`. |
| `--sudo-user <USER>` | Grant sudo over these users. Repeatable. |
| `--access-token-create` | Grant access-token-create. |
| `--access-token-refresh` | Grant access-token-refresh. |
| `--capabilities-json <json>` | Raw capabilities JSON. Not with the flags above. |

The CLI prints the token one time. You cannot get it again. The default table has one `token` row. With `--format json`:

```json
{ "token": "eyJhbGciOiJIUzI1NiIs..." }
```

### stategraph user access-tokens list

```bash
stategraph user access-tokens list
```

The default table shows `id`, `name`, `created_at`, `expiration`, `owner_name`, and `owner_type`. `--format json` gives the full objects, with `owner_id`.

### stategraph user access-tokens delete

`--token-id` is required.

```bash
stategraph user access-tokens delete --token-id f02791c8-aa63-4cdf-acae-a7c968d8a831
```

## stategraph user list

Lists the users you manage, with their IDs and admin rights. It requires the admin or users-manage capability. When the capability covers every tenant, the list holds every user of the installation. When it is restricted to tenants, as for a tenant admin, the list holds the members of those tenants. See [Tenants](/docs/admin/access-control/tenants) for installation and tenant admins.

```bash
stategraph user list [--search <text>] [--type user|api|system]
```

| Flag | Description |
|------|-------------|
| `--search <text>` | Case-insensitive substring match against a user's name or email. |
| `--type <type>` | Only users of this type: `user`, `api`, or `system`. |

The command reads every page of results, so the output holds every matching user. When no user matches, the table prints nothing and the JSON is `[]`.

### Example

```bash
stategraph user list --search jane
```

The default output is a table:

```text
id                                    name      email             type  is_instance_admin  is_tenant_admin
------------------------------------  --------  ----------------  ----  -----------------  ---------------
550e8400-e29b-41d4-a716-446655440000  Jane Doe  jane@example.com  user  false              false
```

For scripts, use `--format json`. It prints an array of users:

```json
[
  {
    "admin_rights": { "is_instance_admin": false, "is_tenant_admin": false },
    "auth_origin": "local",
    "created_at": "2026-01-15T10:30:00Z",
    "email": "jane@example.com",
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "name": "Jane Doe",
    "type": "user"
  }
]
```

## stategraph user set-instance-admin

Grants a user the installation-wide admin capability, or removes it with `--revoke`. It requires installation admin. Get the user ID from `stategraph user list`.

```bash
stategraph user set-instance-admin [--revoke] <user-id>
```

The grant is set, not toggled, so repeating a call changes nothing. `--revoke` removes only the installation-wide grant: an admin grant scoped to named tenants is kept. You cannot remove your own grant (`CANNOT_ACT_ON_SELF`), nor the grant of the last installation admin (`CANNOT_REMOVE_LAST_ADMIN`).

When the grant changes, the user's browser sessions end and the user must sign in again. Access tokens the user already holds keep the capabilities they were created with, so `--revoke` does not remove admin from them. To finish a demotion, list the user's tokens with `stategraph user access-tokens list` and delete each one with `stategraph user access-tokens delete --token-id`.

### Example

```bash
stategraph user set-instance-admin 550e8400-e29b-41d4-a716-446655440000
```

The default output is an `id | is_instance_admin` table. With `--format json`:

```json
{ "id": "550e8400-e29b-41d4-a716-446655440000", "is_instance_admin": true }
```

## Scripting Examples

### Get tenant ID by name

```bash
TENANT_ID=$(stategraph user tenants list --format simple | grep "production" | awk '{print $1}')
echo "Production tenant: $TENANT_ID"
```

### Promote a user by email

```bash
USER_ID=$(stategraph user list --search jane@example.com --format json \
  | jq -r '.[] | select(.email == "jane@example.com") | .id')
stategraph user set-instance-admin "$USER_ID"
```

### Verify authentication in CI

```bash
#!/bin/bash
if ! stategraph user whoami > /dev/null 2>&1; then
  echo "Authentication failed. Check STATEGRAPH_API_KEY."
  exit 1
fi
echo "Authenticated successfully"
```

### List all states across all tenants

```bash
stategraph user tenants list --format simple | while read id name; do
  echo "=== $name ==="
  stategraph states list --tenant "$id" --format json | jq -r '.results[].name'
done
```

## Next steps

- [States](/docs/cli/states): manage Terraform states
- [Access control](/docs/admin/access-control): sign-in methods and access tokens
- [Capabilities Commands](/docs/cli/capabilities): default capabilities for new users, and group rules
- [CLI Overview](/docs/cli): all CLI commands
