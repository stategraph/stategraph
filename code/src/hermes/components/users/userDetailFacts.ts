import type { UserDetailResponse } from '@/lib/api/client';
import { adminScopeOf, roleLabel } from './adminScope';

/** One label/value line of the user-details box. */
export interface UserDetailFact {
  label: string;
  value: string;
  /** Render the value in the monospace face (identifiers). */
  mono?: boolean;
}

/**
 * The identity lines of the user-details box that opens below the Members and
 * Admin lists (#2665), in display order. `auth_origin` is absent for a password
 * account, and an absent email is shown as an em dash rather than dropped, so
 * the box keeps the same shape for every user.
 */
export function userDetailFacts(detail: UserDetailResponse): UserDetailFact[] {
  return [
    { label: 'Email', value: detail.email || '—' },
    { label: 'User ID', value: detail.id, mono: true },
    { label: 'Type', value: detail.type },
    { label: 'Auth', value: detail.auth_origin || 'password' },
    { label: 'Role', value: roleLabel(adminScopeOf(detail)) },
  ];
}

/**
 * The note under the tenant memberships, or null when the list is whole.
 * `/api/v1/users/detail` answers with the memberships the caller's grant
 * reaches and says in `tenants_complete` whether that is all of them (it is,
 * for the caller's own record and for an installation admin), so a partial list
 * has to be labelled as such instead of being read as "belongs to exactly these
 * tenants".
 */
export function membershipsScopeNote(detail: UserDetailResponse): string | null {
  return detail.tenants_complete
    ? null
    : 'Only the memberships within your scope are listed; this user may belong to other tenants.';
}

/**
 * The note shown in place of the capabilities, or null when they are shown.
 */
export function capabilitiesNote(detail: UserDetailResponse): string | null {
  return detail.capabilities
    ? null
    : 'Shown only to this user and to those who can edit this user.';
}
