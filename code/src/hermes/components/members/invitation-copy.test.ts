import assert from 'node:assert';
import { invitationLinkMessage } from './invitation-copy';

// The five values are the arms of Sgs_service_tenants_invitation_common.Delivery, enumerated in
// api.json as `invitation-create-response.delivery`. Adding one there is a compile error in the
// helper, so this list cannot silently fall behind the backend.
const FAILURE = /could not|couldn't|failed|not be sent|not be delivered/i;

// Nobody was emailed, and nothing went wrong: no transport at all, a transport with no provider key,
// or an inviter with no address to send from. All three are supported link-only modes on a
// self-hosted install, so none of them may be framed as a delivery failure.
for (const delivery of ['not_configured', 'no_provider_key', 'inviter_has_no_email'] as const) {
  const message = invitationLinkMessage(delivery);
  assert.ok(!FAILURE.test(message), `${delivery} copy must not imply a delivery failure`);
  assert.ok(/copy this link/i.test(message), `${delivery} copy should present the link`);
}

// The one genuine fault: say so, and offer the link as the fallback.
const failed = invitationLinkMessage('transport_failed');
assert.ok(/could not be delivered/i.test(failed), 'a real delivery failure should say so');
assert.ok(/copy this link/i.test(failed), 'a real delivery failure should still offer the link');

// Emailed: the link is an optional extra, no failure language.
const sent = invitationLinkMessage('emailed');
assert.ok(/on its way/i.test(sent), 'a sent invitation should say the email is coming');
assert.ok(!FAILURE.test(sent), 'a sent invitation should not imply failure');

console.log('ok - invitation-copy: only transport_failed reads as a failure, the other three are link-only, emailed is clean');
