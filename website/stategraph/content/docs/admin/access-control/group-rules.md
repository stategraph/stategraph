---
title: Group Rules
description: Grant Stategraph plan, apply, and admin rights from identity provider groups at sign-in, with tenant-scoped group rules.
order: 7
---


Group rules grant capabilities to users from the groups that their identity provider reports at sign-in. A rule pairs a condition on group membership with a capability grant. Each rule belongs to one tenant, and grants capabilities only in that tenant.

With a minimal [default capability](/docs/admin/access-control/access-tokens#default-capabilities-for-new-users) for new users, your identity provider controls access: a user's groups set what the user can plan, apply, or administer.

## How rules apply

At each sign-in through an OAuth or OIDC provider that reports the user's groups, Stategraph recomputes the user's capabilities, and the login session gets the result. The result is the union of:

- The user's baseline: the system-wide default, plus any rights granted to the user directly.
- The grants of every rule whose condition matches the user's groups.

The admins of a tenant manage its rules, and an installation admin can manage the rules of any tenant. So every `stategraph capabilities group` command takes `--tenant` (or `STATEGRAPH_TENANT_ID`). `stategraph caps` is an alias for `stategraph capabilities`.

## Conditions

A condition is a JSON object:

| Condition | Meaning |
|-----------|---------|
| `{"group": "<glob>"}` | The user is in a group matching the glob. |
| `{"any": [<cond>, ...]}` | At least one of the conditions holds. |
| `{"all": [<cond>, ...]}` | Every condition holds. |

A group matches by exact name, or by a prefix glob that ends in `*`:

- `{"group": "platform-eng"}` matches one group.
- `{"group": "eng-*"}` matches `eng-web`, `eng-db`, and so on.
- `{"any": [{"group": "developers"}, {"group": "devops"}]}` matches either of two groups.
- `{"group": "github:Acme/platform"}` matches the members of the team `platform` of the GitHub organization `Acme`, and `{"group": "github:Acme"}` the members of the organization, with [GitHub sign-in](/docs/admin/access-control/github#what-stategraph-reads-from-github).

## stategraph capabilities group create

Create a rule that grants capabilities to the members of the matching groups when they sign in.

```bash
stategraph capabilities group create --tenant <tenant-id> [capability flags] '<condition-json>'
```

| Flag | Description |
|------|-------------|
| `--tenant <uuid>` | ID of the tenant. Required, or set `STATEGRAPH_TENANT_ID`. The rule's capabilities are scoped to this tenant. |
| `--admin` | Grant admin, scoped to `--tenant`. |
| `--plan` | Grant plan (preview), scoped to `--tenant`. Narrow it further with `--plan-modified` or `--plan-pulled-in`. |
| `--plan-modified <STATE_ID=PATTERN>` | Restrict plan to the directly modified resources in a state that match PATTERN (repeatable). |
| `--plan-pulled-in <STATE_ID=PATTERN>` | Restrict what plan can pull in: the resources pulled in as cone or blast dependencies in that state must match PATTERN (repeatable). |
| `--apply` | Grant apply (commit), scoped to `--tenant`. Narrow it further with `--apply-modified` or `--apply-pulled-in`. |
| `--apply-modified <STATE_ID=PATTERN>` | Restrict apply to the directly modified resources in a state that match PATTERN (repeatable). |
| `--apply-pulled-in <STATE_ID=PATTERN>` | Restrict what apply can pull in: the resources pulled in as cone or blast dependencies in that state must match PATTERN (repeatable). |
| `--users-manage` | Grant users-manage, scoped to `--tenant`. |
| `--capabilities-json <json>` | Raw grant capabilities JSON object. Mutually exclusive with the individual capability flags. The request is refused if this grant reaches beyond the scope of `--tenant`. |
| `--description <text>` | Optional description of the rule. |

State patterns have the same `STATE_ID=PATTERN` form as for [access tokens](/docs/admin/access-control/access-tokens): `*` for the whole state, a prefix such as `sid=module.foo.*`, and a leading `!` to deny.

A rule cannot grant installation-level capabilities: unscoped `admin`, `sudo`, and access-token create and refresh. Stategraph refuses a grant that names another tenant, or a state that another tenant owns.

## stategraph capabilities group list

List the tenant's rules.

```bash
stategraph capabilities group list --tenant <tenant-id>
```

With `--format json`, each rule has `id`, `condition`, `grant`, `description`, `created_at`, and `created_by`.

## stategraph capabilities group delete

Delete a rule by id.

```bash
stategraph capabilities group delete --tenant <tenant-id> <rule-id>
```

The rule stops applying at each affected user's next sign-in. An unknown id, a rule of another tenant, or a rule already deleted returns `404`.

## Example: two teams, two states

Rights for two teams and two states in one tenant:

```bash
# The tenant these rules apply within (also settable via STATEGRAPH_TENANT_ID).
TENANT=<tenant-id>

# Baseline for everyone: can plan, nothing else.
stategraph caps default set --plan

# Anyone in an "eng-*" group may also apply within this tenant.
stategraph caps group create '{"group":"eng-*"}' --tenant "$TENANT" \
  --apply --description "Engineers may apply"

# Anyone in "platform-admins" is an admin of this tenant.
stategraph caps group create '{"group":"platform-admins"}' --tenant "$TENANT" \
  --admin --description "Platform admins"

# team-a owns the prod-network state: full plan + apply on it, nothing elsewhere.
stategraph caps group create '{"group":"team-a"}' --tenant "$TENANT" \
  --plan-modified '<prod-network-state-id>=*' --apply-modified '<prod-network-state-id>=*' \
  --description "team-a owns prod-network"

# team-b owns the prod-db state.
stategraph caps group create '{"group":"team-b"}' --tenant "$TENANT" \
  --plan-modified '<prod-db-state-id>=*' --apply-modified '<prod-db-state-id>=*' \
  --description "team-b owns prod-db"
```

For a signed-in user, the `capabilities` object of [`stategraph user whoami`](/docs/cli/user) shows the result.

## API

| Method | Endpoint | Purpose |
|--------|----------|---------|
| `GET` | `/api/v1/tenants/{tenant_id}/caps/group-rules` | List the tenant's active rules. |
| `POST` | `/api/v1/tenants/{tenant_id}/caps/group-rules` | Create a rule. The body has `condition`, `grant` (a capabilities object), and an optional `description`. The response is the new `id`. |
| `DELETE` | `/api/v1/tenants/{tenant_id}/caps/group-rules/{id}` | Delete a rule. |

All three need admin of the tenant (`403` otherwise). Create returns `400` when the condition is malformed or the grant is invalid, and `422` when the grant reaches beyond the tenant.

## Next steps

- [Access Tokens and Capabilities](/docs/admin/access-control/access-tokens): the capability model and new-user defaults
- [Tenants and Administration](/docs/admin/access-control/tenants): instance admin versus tenant admin
- [OIDC Setup](/docs/admin/access-control/oidc), [Google OAuth Setup](/docs/admin/access-control/google-oauth), and [GitHub OAuth Setup](/docs/admin/access-control/github): the providers that report groups
