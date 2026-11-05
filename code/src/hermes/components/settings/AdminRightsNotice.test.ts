/** Run with: npx tsx components/settings/AdminRightsNotice.test.ts */

import assert from 'node:assert/strict';
import {
  getAdminRightsNoticeCopy,
  getAdminRightsNoticeTone,
  type AdminRightsChange,
} from './AdminRightsNotice';

// Which change yields which notice, and when it links to the keys list: only a revocation (of a
// role, or of the membership) shown to a viewer who may revoke keys. A grant, in either form, is
// about the key the user creates next, so the viewer's own rights do not change its advice, and
// it is information rather than a warning: nothing is at risk.
const changes: AdminRightsChange[] = ['granted', 'invited', 'revoked', 'removed'];
for (const change of changes) {
  const adds = change === 'granted' || change === 'invited';
  assert.equal(getAdminRightsNoticeTone(change), adds ? 'info' : 'warning', change);
  for (const canRevokeAnyKeys of [true, false]) {
    const copy = getAdminRightsNoticeCopy(change, canRevokeAnyKeys);
    const label = `${change}, canRevokeAnyKeys=${canRevokeAnyKeys}`;
    const linked = canRevokeAnyKeys && (change === 'revoked' || change === 'removed');
    assert.equal(copy.link !== undefined, linked, label);
    // The renderer closes the sentence after the link; without one, the text is complete.
    assert.equal(/\.$/.test(copy.text), !linked, label);
    if (copy.link) assert.equal(copy.link.href, '/settings?tab=api-keys', label);
  }
}
assert.deepEqual(getAdminRightsNoticeCopy('granted', true), getAdminRightsNoticeCopy('granted', false));
assert.deepEqual(getAdminRightsNoticeCopy('invited', true), getAdminRightsNoticeCopy('invited', false));
// Every change reads differently.
assert.equal(
  new Set(changes.map((change) => getAdminRightsNoticeCopy(change, true).text)).size,
  changes.length
);

// Wording.
const grantCopy = getAdminRightsNoticeCopy('granted', false);
assert.match(grantCopy.text, /affected user must create a new API key\./);
assert.match(grantCopy.text, /new rights to take effect in the CLI/);

const invitationGrantCopy = getAdminRightsNoticeCopy('invited', false);
assert.match(invitationGrantCopy.text, /Once the invitation is accepted/);
assert.match(invitationGrantCopy.text, /sign out and back in, then create a new API key for/);
assert.match(invitationGrantCopy.text, /tenant-admin rights to take effect in the CLI/);

const revocationCopy = getAdminRightsNoticeCopy('revoked', true);
assert.match(revocationCopy.text, /API keys retain the rights they were minted with/);
assert.match(revocationCopy.text, /after access is removed/);
assert.match(revocationCopy.text, /You can revoke this user's API keys/);
assert.equal(revocationCopy.link?.label, 'API Keys tab');

const tenantAdminRevocationCopy = getAdminRightsNoticeCopy('revoked', false);
assert.match(tenantAdminRevocationCopy.text, /API keys retain the rights they were minted with/);
assert.match(tenantAdminRevocationCopy.text, /Ask an installation admin to revoke this user's API keys/);

const removalCopy = getAdminRightsNoticeCopy('removed', true);
assert.match(removalCopy.text, /lost access to this tenant with their membership/);
assert.match(removalCopy.text, /adding the user back, even as a plain member, restores those rights/);
assert.match(removalCopy.text, /You can revoke this user's API keys/);
assert.equal(removalCopy.link?.label, 'API Keys tab');

const tenantAdminRemovalCopy = getAdminRightsNoticeCopy('removed', false);
assert.match(tenantAdminRemovalCopy.text, /restores those rights to the keys/);
assert.match(tenantAdminRemovalCopy.text, /Ask an installation admin to revoke this user's API keys/);
