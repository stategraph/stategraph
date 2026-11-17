/** The server answered with a 5xx, or did not answer at all: it is starting or restarting. */
export class ServerUnavailableError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'ServerUnavailableError';
  }
}

/** `fetch` that reports a failed connection or a 5xx as a `ServerUnavailableError`. */
export async function fetchFromServer(url: string, init?: RequestInit): Promise<Response> {
  let response: Response;
  try {
    response = await fetch(url, init);
  } catch (err) {
    throw new ServerUnavailableError(`${url}: ${err instanceof Error ? err.message : String(err)}`);
  }
  if (response.status >= 500) {
    throw new ServerUnavailableError(`${url}: ${response.status}`);
  }
  return response;
}

/** Shown in place of a page while `untilServerAnswers` waits. */
export const SERVER_STARTING_MESSAGE =
  "Stategraph is starting. This page continues when the server is ready.";

const sleep = (ms: number) => new Promise<void>((resolve) => setTimeout(resolve, ms));

export interface UntilServerAnswersOptions {
  /** Called once, on the first `ServerUnavailableError`. */
  onUnavailable?: () => void;
  intervalMs?: number;
  wait?: (ms: number) => Promise<void>;
}

/**
 * Runs `call` until it settles with anything other than a `ServerUnavailableError`, waiting
 * `intervalMs` (default 2000) between attempts, with no attempt limit.
 */
export async function untilServerAnswers<T>(
  call: () => Promise<T>,
  { onUnavailable, intervalMs = 2000, wait = sleep }: UntilServerAnswersOptions = {}
): Promise<T> {
  let reported = false;
  for (;;) {
    try {
      return await call();
    } catch (err) {
      if (!(err instanceof ServerUnavailableError)) throw err;
    }
    if (!reported) {
      reported = true;
      onUnavailable?.();
    }
    await wait(intervalMs);
  }
}
