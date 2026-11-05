/** Run with: npx tsx components/ui/dismissible-banner.test.ts */

import assert from 'node:assert/strict';
import { BANNER_TONES, type BannerTone } from './dismissible-banner';

// The design-system token each tone draws on: information borrows the accent blue.
const tokens: Record<BannerTone, string> = {
  error: 'error',
  success: 'success',
  warning: 'warning',
  info: 'accent',
};
const tones = Object.keys(tokens) as BannerTone[];
for (const tone of tones) {
  const { role, className, iconClassName } = BANNER_TONES[tone];
  // Frame and icon draw on the tone's own token, and on no other tone's.
  for (const classes of [className, iconClassName]) {
    assert.match(classes, new RegExp(`var\\(--sg-${tokens[tone]}\\)`), tone);
    for (const other of tones) {
      if (other !== tone) assert.doesNotMatch(classes, new RegExp(`--sg-${tokens[other]}\\b`), tone);
    }
  }
  // Only an error interrupts the screen reader; the others wait their turn.
  assert.equal(role, tone === 'error' ? 'alert' : 'status', tone);
}
