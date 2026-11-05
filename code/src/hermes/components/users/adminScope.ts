import type { AdminRights } from '@/lib/api/client';

/**
 * How far a user's admin grant reaches.
 *
 * The backend stores one `admin` capability whose optional `tenants` allow-list is the scope: with
 * no allow-list it is installation-wide, with one it covers only the tenants it names. The users
 * list reports the two apart, in `admin_rights` — `is_instance_admin` for the unrestricted grant,
 * `is_tenant_admin` for a scoped one — and every label on this screen has to say which of the two it
 * means:
 * `/api/v1/users/set-instance-admin` grants and revokes the installation-wide one only: a tenant-scoped
 * grant is managed from that tenant's members screen, and revoking through this endpoint leaves it
 * untouched. The two are never both true; both are false for a user with no grant, and also for an
 * `admin` grant whose allow-list permits nothing — one that authorizes no tenant is not a role.
 */
export type AdminScope = 'none' | 'tenants' | 'instance';

export function adminScopeOf(user: { admin_rights: AdminRights }): AdminScope {
  if (user.admin_rights.is_instance_admin) {
    return 'instance';
  }
  return user.admin_rights.is_tenant_admin ? 'tenants' : 'none';
}

/** The Role column. */
export function roleLabel(scope: AdminScope): string {
  switch (scope) {
    case 'instance':
      return 'Admin (installation-wide)';
    case 'tenants':
      return 'Admin (some tenants)';
    case 'none':
      return 'User';
  }
}

/**
 * The label for the `/api/v1/users/set-instance-admin` action offered on a user. The write sets the
 * grant to a value rather than inverting one, but which value is worth offering depends on what the
 * user already holds, which is why the label reads off the current scope: revoking on `instance`,
 * granting on the other two. Granting on `tenants` replaces the tenant-scoped grant, which is why the
 * dialog warns before it.
 */
export function setInstanceAdminLabel(scope: AdminScope): string {
  switch (scope) {
    case 'instance':
      return 'Remove installation-wide Admin';
    case 'tenants':
    case 'none':
      return 'Make installation-wide Admin';
  }
}
