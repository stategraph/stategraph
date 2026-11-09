import assert from 'node:assert';
import type { TenantMember } from '@/lib/api/client';
import { lockedReason, removeLockedReason, scopeReach } from './grant-scope';

type GrantScope = TenantMember['admin_scope'];

// Every value of the API's `admin_scope` / `users_manage_scope` enum. The record makes adding a value
// to api.json a compile error here, so the exhaustive checks below cannot fall behind the backend.
const SCOPE_SET: Record<GrantScope, true> = { none: true, tenant: true, wider: true, instance: true };
const SCOPES = Object.keys(SCOPE_SET) as GrantScope[];

// Only no grant, or one scoped exactly to this tenant, is this screen's to change.
const EDITABLE: ReadonlySet<GrantScope> = new Set<GrantScope>(['none', 'tenant']);

// The three reaches a role badge spells out are told apart: a grant naming several tenants is not
// an installation-wide one.
assert.strictEqual(scopeReach('tenant'), 'tenant');
assert.strictEqual(scopeReach('wider'), 'multiple tenants');
assert.strictEqual(scopeReach('instance'), 'installation-wide');

for (const scope of SCOPES) {
  const reason = lockedReason(scope);
  assert.strictEqual(reason === null, EDITABLE.has(scope), `lockedReason('${scope}') = ${reason}`);
}
assert.ok(lockedReason('wider')?.includes('other tenants'), 'a wider grant should say it reaches other tenants');
assert.ok(lockedReason('instance')?.includes('installation-wide'), 'an instance grant should say it is installation-wide');

// Removal is locked exactly when the server refuses it: when either grant reaches beyond this tenant
// (`Sgs_service_tenants_members_common.wider_grant` is `Some`).
for (const admin_scope of SCOPES) {
  for (const users_manage_scope of SCOPES) {
    const reason = removeLockedReason({ admin_scope, users_manage_scope });
    const refused = !EDITABLE.has(admin_scope) || !EDITABLE.has(users_manage_scope);
    assert.strictEqual(reason !== null, refused, `remove for admin=${admin_scope}, users-manage=${users_manage_scope}: ${reason}`);
  }
}

// The case the screen used to get wrong: a tenant admin whose users-manage grant reaches wider was
// offered removal, and the server answered 409. The reason names the grant that blocks it.
assert.ok(
  removeLockedReason({ admin_scope: 'tenant', users_manage_scope: 'wider' })?.includes('member-management grant'),
  'a wider users-manage grant should block removal and be named'
);

// When both grants reach wider, the admin one is named, as the server checks it first.
assert.ok(
  removeLockedReason({ admin_scope: 'wider', users_manage_scope: 'instance' })?.includes('admin grant'),
  'the admin grant should be named first'
);

console.log('ok - grant-scope: badges tell the three reaches apart, and edit/remove lock exactly where the server refuses');
