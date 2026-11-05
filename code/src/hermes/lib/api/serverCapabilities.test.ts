// The server capability envelope's caching rule (#1752): concurrent loads share one request, a
// failure resolves to everything-disabled without being cached, the next load after a failure
// sends a new request, and a success is served from the cache. A 500 is used rather than a 401 so
// the client's retries and the session-expired handler stay out of the picture.
import assert from 'node:assert';
import { cachedServerCapabilities, loadServerCapabilities } from './serverCapabilities';

type FetchImpl = typeof fetch;

const enabled = {
  costs: { enabled: true },
  dedicated: { enabled: false },
  github_app: { configured: false, creatable: false, ready: false },
  security: { enabled: true },
};

async function run() {
  let calls = 0;
  let release: (r: Response) => void = () => {};
  (globalThis as { fetch: FetchImpl }).fetch = () => {
    calls += 1;
    return new Promise<Response>((res) => {
      release = res;
    });
  };
  const a = loadServerCapabilities();
  const b = loadServerCapabilities();
  assert.equal(calls, 1, 'concurrent loads share one request');
  release(new Response('', { status: 500, statusText: 'Internal Server Error' }));
  const [ra, rb] = await Promise.all([a, b]);
  assert.equal(ra.security.enabled, false);
  assert.equal(rb.costs.enabled, false);
  assert.equal(cachedServerCapabilities(), null, 'a failure is not cached');

  (globalThis as { fetch: FetchImpl }).fetch = async () => {
    calls += 1;
    return new Response(JSON.stringify(enabled), { status: 200 });
  };
  const c = await loadServerCapabilities();
  assert.equal(calls, 2, 'the next load after a failure sends a new request');
  assert.deepEqual(cachedServerCapabilities(), c);
  await loadServerCapabilities();
  assert.equal(calls, 2, 'a success is served without another request');

  console.log('ok - server capabilities: failures are shared and retried, successes cached');
}

run()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });
