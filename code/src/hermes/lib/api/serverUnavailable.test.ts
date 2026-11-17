// While the server starts, nginx answers 502 for the API and the console waits; any other outcome
// (an answer, a 4xx, a thrown non-server error) settles the wait at once.
import assert from 'node:assert';
import { getLoginOptions, getSetupStatus } from './client';
import { ServerUnavailableError, fetchFromServer, untilServerAnswers } from './serverUnavailable';

type FetchImpl = typeof fetch;

function setFetch(impl: FetchImpl) {
  (globalThis as { fetch: FetchImpl }).fetch = impl;
}

/** A fetch that serves `responses` in order, then repeats the last one. */
function sequence(responses: Array<() => Response>): { calls: () => number } {
  let n = 0;
  setFetch(async () => {
    const next = responses[Math.min(n, responses.length - 1)];
    n += 1;
    return next();
  });
  return { calls: () => n };
}

const noWait = async () => {};

async function rejectsWith(p: Promise<unknown>, cls: new (...args: never[]) => Error) {
  try {
    await p;
  } catch (err) {
    assert.ok(err instanceof cls, `expected ${cls.name}, got ${String(err)}`);
    return err;
  }
  assert.fail(`expected ${cls.name}`);
}

async function run() {
  // fetchFromServer: 5xx and a failed connection are ServerUnavailableError; 4xx is a response.
  for (const status of [500, 502, 503, 504]) {
    setFetch(async () => new Response('', { status }));
    await rejectsWith(fetchFromServer('/x'), ServerUnavailableError);
  }
  setFetch(async () => {
    throw new TypeError('Failed to fetch');
  });
  await rejectsWith(fetchFromServer('/x'), ServerUnavailableError);
  setFetch(async () => new Response('', { status: 404 }));
  assert.equal((await fetchFromServer('/x')).status, 404);

  // getSetupStatus: unavailable on 502, plain Error on 4xx.
  setFetch(async () => new Response('', { status: 502 }));
  await rejectsWith(getSetupStatus(), ServerUnavailableError);
  setFetch(async () => new Response('', { status: 403 }));
  const forbidden = await rejectsWith(getSetupStatus(), Error);
  assert.ok(!(forbidden instanceof ServerUnavailableError), 'a 4xx is not server-unavailable');

  // untilServerAnswers + getSetupStatus: waits through 502s, returns the first answer.
  const json = (body: unknown) => () =>
    new Response(JSON.stringify(body), { status: 200, headers: { 'Content-Type': 'application/json' } });
  const bad = () => new Response('<html>502 Bad Gateway</html>', { status: 502 });
  let setup = sequence([bad, bad, bad, json({ needs_setup: true })]);
  const waits: number[] = [];
  let unavailable = 0;
  const status = await untilServerAnswers(getSetupStatus, {
    onUnavailable: () => {
      unavailable += 1;
    },
    wait: async (ms) => {
      waits.push(ms);
    },
  });
  assert.deepEqual(status, { needs_setup: true });
  assert.equal(setup.calls(), 4);
  assert.deepEqual(waits, [2000, 2000, 2000], 'waits between attempts, not after the answer');
  assert.equal(unavailable, 1, 'onUnavailable fires once, however many attempts fail');

  // An answer on the first attempt never reports the server as unavailable.
  setup = sequence([json({ needs_setup: false })]);
  unavailable = 0;
  await untilServerAnswers(getSetupStatus, {
    onUnavailable: () => {
      unavailable += 1;
    },
    wait: noWait,
  });
  assert.equal(unavailable, 0);

  // A connection failure is waited out the same way.
  let failures = 2;
  setFetch(async () => {
    if (failures-- > 0) throw new TypeError('Failed to fetch');
    return json({ options: [] })();
  });
  assert.deepEqual(await untilServerAnswers(getLoginOptions, { wait: noWait }), { options: [] });

  // A 4xx settles at once with the caller's error.
  setup = sequence([() => new Response('', { status: 403 })]);
  await rejectsWith(untilServerAnswers(getSetupStatus, { wait: noWait }), Error);
  assert.equal(setup.calls(), 1);

  // A non-server error from the call settles at once.
  let attempts = 0;
  await rejectsWith(
    untilServerAnswers(async () => {
      attempts += 1;
      throw new RangeError('bug');
    }, { wait: noWait }),
    RangeError
  );
  assert.equal(attempts, 1);

  console.log('serverUnavailable tests passed');
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
