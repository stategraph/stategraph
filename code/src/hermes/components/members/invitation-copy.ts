import type { InvitationCreateResponse } from '@/lib/api/client';

type Delivery = InvitationCreateResponse['delivery'];

/**
 * Copy for the one-time invitation-link dialog, chosen by the backend's `delivery`.
 *
 * The split is failure vs. no failure, and it is not the same as emailed vs. not emailed: three of
 * the four non-delivery outcomes mean nobody was emailed because nobody was ever going to be, which
 * is a supported mode on a self-hosted install and must not be reported as something going wrong.
 * Only `transport_failed` is a fault. See `Sgs_cloud.S.send_tenant_invite` and
 * `Sgs_service_tenants_invitation_common.Delivery` for the contract.
 *
 * Keyed on `delivery` rather than the invitation's `delivered` flag because the two endpoints that
 * open this dialog are the ones that report `delivery`, and `delivered` conflates "no provider key"
 * with "never attempted".
 */
export function invitationLinkMessage(delivery: Delivery): string {
  switch (delivery) {
    case 'emailed':
      return 'The invitation email is on its way. You can also copy this link to share it directly; it is shown only once.';
    case 'not_configured':
    case 'no_provider_key':
    case 'inviter_has_no_email':
      return "Copy this link and send it to the person you're inviting. It is shown only once.";
    case 'transport_failed':
      return 'The invitation email could not be delivered. Copy this link and pass it on instead. It is shown only once.';
  }
}
