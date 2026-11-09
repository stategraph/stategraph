import type { TenantMember } from '@/lib/api/client';

/** How one of a member's grants covers this tenant; `admin_scope` and `users_manage_scope` share it. */
type GrantScope = TenantMember['admin_scope'];

/** The reach a role badge spells out, as in "Admin (tenant)". */
export function scopeReach(scope: Exclude<GrantScope, 'none'>): string {
  switch (scope) {
    case 'tenant':
      return 'tenant';
    case 'wider':
      return 'multiple tenants';
    case 'instance':
      return 'installation-wide';
  }
}

/** What puts a grant beyond this tenant's members screen, or `null` when the screen can change it. */
function grantReach(scope: GrantScope): string | null {
  switch (scope) {
    case 'none':
    case 'tenant':
      return null;
    case 'wider':
      return 'also covers other tenants';
    case 'instance':
      return 'is installation-wide';
  }
}

/** Why a grant cannot be changed from this tenant's members screen, or `null` when it can. */
export function lockedReason(scope: GrantScope): string | null {
  const reach = grantReach(scope);
  return reach === null ? null : `This grant ${reach} and cannot be changed from here`;
}

/**
 * Why a member cannot be removed from this tenant, or `null` when they can. Removal also takes this
 * tenant out of the member's grants, so the server refuses it when one of them reaches beyond this
 * tenant -- checking admin, then users-manage, as `Sgs_service_tenants_members_common.wider_grant`.
 */
export function removeLockedReason(
  member: Pick<TenantMember, 'admin_scope' | 'users_manage_scope'>
): string | null {
  const adminReach = grantReach(member.admin_scope);
  if (adminReach !== null) {
    return `Removing this member would take this tenant out of their admin grant, which ${adminReach} and cannot be changed from here`;
  }
  const manageReach = grantReach(member.users_manage_scope);
  if (manageReach !== null) {
    return `Removing this member would take this tenant out of their member-management grant, which ${manageReach} and cannot be changed from here`;
  }
  return null;
}
