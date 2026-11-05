/**
 * Mask credential-bearing values in a derived Terrateam repo config before
 * the console renders it.
 *
 * `repo_configs.data` is the effective config as committed, so it can carry
 * literal secrets: `hooks.*.{pre,post}[].env` maps on `run`/`gates` ops (the
 * usual place a token is pasted), `storage.plans.secret_access_key` for the
 * S3 plan store, and anything a team names like a credential. Commands are
 * left visible — masking them would hide what the config does — and gate
 * `token`s are not credentials (they are quoted in PR comments), so only
 * suffixed/prefixed token keys match.
 */

export const REDACTED = "«redacted»";

const SECRET_KEY =
  /secret|password|passwd|credential|private_key|api_key|access_key|webhook|_token$|^token_/i;

const isStringMap = (v: unknown): v is Record<string, unknown> =>
  v !== null && typeof v === "object" && !Array.isArray(v);

export function redactRepoConfig(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(redactRepoConfig);
  if (!isStringMap(value)) return value;
  const out: Record<string, unknown> = {};
  for (const [key, v] of Object.entries(value)) {
    if (SECRET_KEY.test(key) && (typeof v === "string" || typeof v === "number")) {
      out[key] = REDACTED;
    } else if (key === "env" && isStringMap(v)) {
      out[key] = Object.fromEntries(Object.keys(v).map((name) => [name, REDACTED]));
    } else {
      out[key] = redactRepoConfig(v);
    }
  }
  return out;
}
