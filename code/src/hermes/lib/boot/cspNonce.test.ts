/**
 * Tests for reading the CSP nonce of the console document.
 * Run with: npx tsx lib/boot/cspNonce.test.ts
 */

import { getNonce } from 'get-nonce';
import { adoptDocumentNonce, documentNonce } from './cspNonce';

let passed = 0;
let failed = 0;

interface TestCase {
  name: string;
  fn: () => boolean;
}

/** A document whose only nonce-carrying script has the given IDL and attribute values. */
function docWith(script: { nonce?: string; attr?: string | null } | null): Pick<Document, 'querySelector'> {
  return {
    querySelector: ((selector: string) => {
      if (selector !== 'script[nonce]' || script === null) return null;
      return {
        nonce: script.nonce ?? '',
        getAttribute: (name: string) => (name === 'nonce' ? script.attr ?? null : null),
      };
    }) as Document['querySelector'],
  };
}

const tests: TestCase[] = [
  {
    name: 'reads the IDL nonce, which survives nonce hiding',
    fn: () => documentNonce(docWith({ nonce: 'abc123', attr: '' })) === 'abc123',
  },
  {
    name: 'falls back to the attribute when the IDL value is empty',
    fn: () => documentNonce(docWith({ nonce: '', attr: 'def456' })) === 'def456',
  },
  {
    name: 'no script with a nonce gives no nonce',
    fn: () => documentNonce(docWith(null)) === undefined,
  },
  {
    name: 'an empty nonce gives no nonce',
    fn: () => documentNonce(docWith({ nonce: '', attr: '' })) === undefined,
  },
  {
    name: 'does not call the setter without a nonce',
    fn: () => {
      let called = false;
      adoptDocumentNonce(docWith(null), () => {
        called = true;
      });
      return !called;
    },
  },
  {
    name: 'stores the nonce where react-style-singleton reads it',
    fn: () => {
      adoptDocumentNonce(docWith({ nonce: 'ghi789' }));
      return getNonce() === 'ghi789';
    },
  },
];

for (const test of tests) {
  try {
    if (test.fn()) {
      console.log(`PASS: ${test.name}`);
      passed++;
    } else {
      console.log(`FAIL: ${test.name}`);
      failed++;
    }
  } catch (e) {
    console.log(`FAIL: ${test.name} (threw: ${e})`);
    failed++;
  }
}

console.log(`\n${passed} passed, ${failed} failed`);
process.exit(failed > 0 ? 1 : 0);
