import { executeMQL } from "@/lib/api/client";
import type { VcsProvider } from "@/lib/vcs/links";

/** Both VCS providers the catalog exposes twin table sets for. */
export const VCS_PROVIDERS: VcsProvider[] = ["github", "gitlab"];

/**
 * The server clamps any explicit LIMIT to this ceiling. Per-screen caps must clamp to it: a cap
 * above the ceiling would silently receive only this many rows, and the
 * `length >= cap` truncation check in {@link loadAcrossProviders} callers
 * would stop firing while the data is still truncated.
 */
export const MQL_MAX_LIMIT = 1000;

/** Coerce an MQL cell to a display string ("" for SQL NULL). Row mappers use
 *  this for every column — the wire values are untyped JSON. */
export const asText = (v: unknown): string =>
  typeof v === "string" ? v : v == null ? "" : String(v);

/** Coerce an MQL cell to a number (0 for SQL NULL or anything non-numeric).
 *  Aggregates such as count(*) may arrive as a JSON number or, for bigint,
 *  as a numeric string. */
export const asNumber = (v: unknown): number => {
  const n =
    typeof v === "number" ? v : typeof v === "string" && v.trim() !== "" ? Number(v) : Number.NaN;
  return Number.isFinite(n) ? n : 0;
};

/**
 * True when the thrown error is the MQL endpoint rejecting an orchestration
 * table name — i.e. this server runs without the Terrateam orchestration side
 * (STATEGRAPH_ORCHESTRATION_ENABLED off), so the table isn't in the schema.
 */
export function orchestrationUnavailable(e: unknown): boolean {
  const body = (e as { body?: unknown } | null)?.body;
  return (
    body !== null &&
    typeof body === "object" &&
    (body as { id?: unknown }).id === "TABLE_ACCESS_ERR"
  );
}

export interface ProviderResults<T> {
  results: { provider: VcsProvider; value: T }[];
  /** Providers whose body failed while at least one other succeeded. */
  failed: VcsProvider[];
}

/**
 * Run one body per provider (the catalog twins every orchestration table, and
 * MQL has no cross-table union) and keep what succeeded. A single provider
 * failing does not blank the screen — it lands in `failed`; only when every
 * provider fails does this throw, with the FIRST provider's failure so the
 * message is stable. A body that issues several queries is all-or-nothing for
 * its provider: one failing query drops that provider entirely, so a screen
 * never mixes a provider's partial numbers. `providers` narrows the fan-out
 * to a subset (both providers by default).
 */
export async function runAcrossProviders<T>(
  fn: (p: VcsProvider) => Promise<T>,
  providers: readonly VcsProvider[] = VCS_PROVIDERS,
): Promise<ProviderResults<T>> {
  const settled = await Promise.allSettled(providers.map((p) => fn(p)));
  if (settled.every((s) => s.status === "rejected")) {
    throw (settled[0] as PromiseRejectedResult).reason;
  }
  const results: ProviderResults<T>["results"] = [];
  const failed: VcsProvider[] = [];
  settled.forEach((s, i) => {
    if (s.status === "fulfilled") results.push({ provider: providers[i], value: s.value });
    else failed.push(providers[i]);
  });
  return { results, failed };
}

export interface ProviderRows<T> {
  rows: T[];
  /** Providers whose query failed while at least one other succeeded. */
  failed: VcsProvider[];
  /** True when any provider returned exactly its cap — the merged list is incomplete. */
  capped: boolean;
}

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

/** A failure worth one more attempt: a 5xx (a dropped or overloaded proxy
 *  hop), or no HTTP answer at all (the API client has already retried the
 *  network error itself). Any 4xx is deterministic — TABLE_ACCESS_ERR (the
 *  orchestration schema being off), a rejected query, a settled 401 — and
 *  would fail identically. */
export function transientFailure(e: unknown): boolean {
  if (orchestrationUnavailable(e)) return false;
  const status = (e as { status?: unknown } | null)?.status;
  return typeof status !== "number" || status >= 500;
}

/** Run one MQL query and return its rows, retrying a transient failure once
 *  (two attempts at most). `exec` and `delayMs` are overridable for tests. */
export async function executeWithRetry(
  q: string,
  {
    exec = executeMQL,
    delayMs = 750,
  }: { exec?: (q: string) => Promise<{ data: unknown[] }>; delayMs?: number } = {},
): Promise<unknown[]> {
  try {
    return (await exec(q)).data;
  } catch (e) {
    if (!transientFailure(e)) throw e;
    // Only the retry's error is thrown; keep the first one visible.
    console.warn("MQL query failed, retrying once", e);
    await sleep(delayMs);
    return (await exec(q)).data;
  }
}

/**
 * Run the same MQL query shape against every provider's twin tables and merge
 * client-side. Failure semantics are {@link runAcrossProviders}'; a transient
 * failure is retried once ({@link executeWithRetry}) before its provider
 * counts as failed. `enrich`, when given, completes a provider's raw rows
 * before `map` sees them (e.g. with a second query keyed by their ids); it is
 * part of that provider's body, so its failure drops the provider too.
 */
export async function loadAcrossProviders<T>(
  query: (p: VcsProvider) => string,
  map: (p: VcsProvider, raw: unknown) => T,
  cap: number,
  enrich: (rows: unknown[]) => Promise<unknown[]> = async (rows) => rows,
): Promise<ProviderRows<T>> {
  const { results, failed } = await runAcrossProviders(async (p) =>
    (await enrich(await executeWithRetry(query(p)))).map((r) => map(p, r)),
  );
  return {
    rows: results.flatMap((r) => r.value),
    failed,
    capped: results.some((r) => r.value.length >= cap),
  };
}
