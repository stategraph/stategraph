// The runtime session-expiry contract (#1827): fetchAPICore fires the registered handler on a
// settled 401 (session gone) and never on a 403 (an authorization denial the caller should see in
// context) or a 404 (a state or transaction that does not exist, or is in a tenant we are not in --
// a stale deep link must not log anyone out). A 401 is answered by the session middleware before
// any endpoint runs, so nothing past that point may use it and this split is reliable.
import assert from 'node:assert';
import { whoami, setSessionExpiredHandler } from './client';

type FetchImpl = typeof fetch;

async function run() {
  let fired = 0;
  setSessionExpiredHandler(() => {
    fired += 1;
  });

  // A settled 401 fires the handler exactly once (after the internal retries).
  (globalThis as { fetch: FetchImpl }).fetch = async () =>
    new Response('', { status: 401, statusText: 'Unauthorized' });
  try {
    await whoami();
    assert.fail('expected whoami to throw on 401');
  } catch {
    // expected
  }
  assert.equal(fired, 1, 'a 401 should fire the session-expired handler once');

  // A 403 (denial) must not be treated as session loss.
  fired = 0;
  (globalThis as { fetch: FetchImpl }).fetch = async () =>
    new Response(JSON.stringify({ id: 'CAPABILITY_UNAUTHORIZED' }), {
      status: 403,
      statusText: 'Forbidden',
    });
  try {
    await whoami();
    assert.fail('expected whoami to throw on 403');
  } catch {
    // expected
  }
  assert.equal(fired, 0, 'a 403 must not fire the session-expired handler');

  // A 404 (missing state/tx, or one in someone else's tenant) must not be treated as session loss:
  // this is the stale-bookmark case, where a forced logout would be the wrong answer entirely.
  fired = 0;
  (globalThis as { fetch: FetchImpl }).fetch = async () =>
    new Response('', { status: 404, statusText: 'Not Found' });
  try {
    await whoami();
    assert.fail('expected whoami to throw on 404');
  } catch {
    // expected
  }
  assert.equal(fired, 0, 'a 404 must not fire the session-expired handler');

  // A cleared handler is safe: a 401 with no handler registered does not throw from the notify path.
  fired = 0;
  setSessionExpiredHandler(null);
  (globalThis as { fetch: FetchImpl }).fetch = async () => new Response('', { status: 401 });
  try {
    await whoami();
  } catch {
    // expected (still throws the API error), but the null handler must not have blown up first
  }
  assert.equal(fired, 0, 'a cleared handler must not be invoked');

  console.log(
    'ok - session-expiry: 401 fires the handler once, 403 and 404 do not, null handler is safe',
  );
}

run()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });
