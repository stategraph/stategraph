'use client';

import { DismissibleBanner, type BannerTone } from '@/components/ui/dismissible-banner';
import { DeepLink } from '@/components/navigation';

/**
 * The access-rights mutation that just succeeded. 'invited' is a tenant-admin invitation, whose
 * grant lands only once it is accepted. 'removed' is a membership removal, which takes the tenant
 * away from the user's API keys at once, unlike the role revocation 'revoked'.
 */
export type AdminRightsChange = 'granted' | 'invited' | 'revoked' | 'removed';

export interface AdminRightsNoticeCopy {
  text: string;
  /** Where the keys can be revoked, closing the sentence `text` leaves open. Only for a viewer who may revoke them. */
  link?: { label: string; href: string };
}

/** `lead`, then where the keys can be revoked: a link for an installation admin, a pointer otherwise. */
function withRevokeHint(lead: string, canRevokeAnyKeys: boolean): AdminRightsNoticeCopy {
  return canRevokeAnyKeys
    ? {
        text: `${lead} You can revoke this user's API keys in the`,
        link: { label: 'API Keys tab', href: '/settings?tab=api-keys' },
      }
    : { text: `${lead} Ask an installation admin to revoke this user's API keys in the API Keys tab.` };
}

export function getAdminRightsNoticeCopy(
  change: AdminRightsChange,
  canRevokeAnyKeys: boolean
): AdminRightsNoticeCopy {
  switch (change) {
    case 'granted':
      return {
        text: 'For the new rights to take effect in the CLI, the affected user must create a new API key.',
      };
    case 'invited':
      // Accepting an invitation leaves the invitee's current session with its old rights, and a
      // key is minted with the rights of the session that creates it.
      return {
        text: 'Once the invitation is accepted, the invitee must sign out and back in, then create a new API key for the tenant-admin rights to take effect in the CLI.',
      };
    case 'revoked':
      return withRevokeHint(
        'API keys retain the rights they were minted with after access is removed.',
        canRevokeAnyKeys
      );
    case 'removed':
      // Membership is checked on every request, so the keys lose the tenant at once; the rights
      // stored on them still name it, and come back with the membership.
      return withRevokeHint(
        "This user's API keys lost access to this tenant with their membership, but still carry the rights they were minted with: adding the user back, even as a plain member, restores those rights to the keys.",
        canRevokeAnyKeys
      );
  }
}

/** Information when rights are added: nothing is at risk. A warning when they are taken away. */
export function getAdminRightsNoticeTone(change: AdminRightsChange): BannerTone {
  switch (change) {
    case 'granted':
    case 'invited':
      return 'info';
    case 'revoked':
    case 'removed':
      return 'warning';
  }
}

export function AdminRightsNotice({
  change,
  canRevokeAnyKeys,
  onDismiss,
}: {
  change: AdminRightsChange;
  canRevokeAnyKeys: boolean;
  onDismiss: () => void;
}) {
  const copy = getAdminRightsNoticeCopy(change, canRevokeAnyKeys);

  return (
    <DismissibleBanner
      tone={getAdminRightsNoticeTone(change)}
      onDismiss={onDismiss}
      dismissLabel="Dismiss admin rights notice"
    >
      {copy.text}
      {copy.link && (
        <>
          {' '}
          <DeepLink href={copy.link.href} className="font-medium underline underline-offset-2">
            {copy.link.label}
          </DeepLink>
          .
        </>
      )}
    </DismissibleBanner>
  );
}
