// Search execution via MQL (#1068).
//
// `/search` result execution previously went through the dedicated tag-DSL
// endpoint (`getStateInstances` + `ensureTagQuery`), with all-states fanning out
// one request per state. This module translates the search tag-DSL into an MQL
// WHERE clause so execution runs through `/api/v1/mql` for single-state AND
// all-states (one cursored query), matching (or, for bare terms, improving on)
// the backend's semantics.
//
// Translation of the tag-DSL (`lib/query` `ensureTagQuery` grammar):
//   - `type:` / `address:` / `resource_address:` / `provider:` / `module:`
//        -> exact `col = 'value'`   (unchanged from the backend)
//   - `attr:key:value`  -> `instances.attributes @> '<json>'::jsonb`
//        Dotted keys nest: `attr:tags.Name:prod` -> {"tags":{"Name":"prod"}}
//        (the backend's literal-top-level-key quirk is fixed to real nesting).
//   - `tag:K:V`         -> normalized to `attr:tags.K:V` (as ensureTagQuery does)
//   - a BARE term       -> substring `ILIKE '%term%'` across type/address/module
//        (NEW: the backend's bare path was exact-match and matched ~nothing).
//   - ` OR ` / ` AND ` / leading `NOT ` and double-quoting are preserved.
//
// Engine idioms: scoped tables (`resources`/`instances`/`states`) are bare-name
// with comma-FROM + WHERE (no INNER JOIN). `attributes` comes back MASKED. The
// `(state_id, address)` keyset order gives a stable cursor within and across
// states. Full attributes are selected because the results table renders them
// inline in expandable rows.

import type { Instance, InstanceAttributes } from "@/lib/api/client";

// The `/api/v1/mql` page hard-caps at 1000; the search page requests <= this.
export const SEARCH_PAGE_LIMIT = 50;

// ---------------------------------------------------------------------------
// Row type + mapping
// ---------------------------------------------------------------------------

export interface SearchRow {
  address: string;
  type: string;
  provider: string;
  module: string | null;
  attributes: InstanceAttributes | null;
  sensitive_attributes: InstanceAttributes | null;
  dependencies: string[] | null;
  state_id: string;
  state_name: string | null;
}

export function searchRowToInstance(row: SearchRow): Instance {
  return {
    address: row.address,
    type: row.type,
    provider: row.provider,
    module: row.module ?? undefined,
    attributes: row.attributes ?? undefined,
    sensitive_attributes: row.sensitive_attributes ?? undefined,
    dependencies: row.dependencies ?? undefined,
    state_id: row.state_id,
    state_name: row.state_name ?? undefined,
  };
}

// ---------------------------------------------------------------------------
// SQL literal / pattern escaping
// ---------------------------------------------------------------------------

/** Escape a value for a single-quoted SQL string literal. */
function sqlLiteral(value: string): string {
  return `'${value.replace(/'/g, "''")}'`;
}

/** A single-quoted ILIKE pattern `'%value%'` with LIKE metachars (\ % _) and
 *  quotes escaped (default backslash escape char). */
function ilikePattern(value: string): string {
  const esc = value
    .replace(/\\/g, "\\\\")
    .replace(/%/g, "\\%")
    .replace(/_/g, "\\_")
    .replace(/'/g, "''");
  return `'%${esc}%'`;
}

/** Strip matching surrounding double quotes from a tag-DSL value. */
function unquote(value: string): string {
  const v = value.trim();
  if (v.length >= 2 && v.startsWith('"') && v.endsWith('"')) {
    return v.slice(1, -1);
  }
  return v;
}

// ---------------------------------------------------------------------------
// tag-DSL -> MQL WHERE translation
// ---------------------------------------------------------------------------

const FIELD_COLUMN: Record<string, string> = {
  address: "instances.address",
  resource_address: "instances.resource_address",
  type: "resources.type",
  provider: "resources.provider",
  module: "resources.module",
};

const ILIKE_FIELDS = ["resources.type", "instances.address", "resources.module"] as const;

/** `<term>` (bare word) -> substring ILIKE across type/address/module. */
function bareIlike(term: string): string {
  const pat = ilikePattern(term);
  return "(" + ILIKE_FIELDS.map((col) => `${col} ilike ${pat}`).join(" or ") + ")";
}

/** `attr:key:value` -> jsonb containment; dotted keys nest. */
function attrContainment(rest: string): string {
  const idx = rest.indexOf(":");
  if (idx === -1) {
    // `attr:foo` with no value — nothing sensible to match; treat as bare.
    return bareIlike(rest);
  }
  const key = rest.slice(0, idx);
  const value = unquote(rest.slice(idx + 1));
  const parts = key.split(".").filter(Boolean);
  if (parts.length === 0) return bareIlike(value);
  let obj: unknown = value;
  for (let i = parts.length - 1; i >= 0; i--) obj = { [parts[i]]: obj };
  return `instances.attributes @> ${sqlLiteral(JSON.stringify(obj))}::jsonb`;
}

/** Translate one term (`[NOT] field:value` | `attr:k:v` | bare) to a predicate. */
function translateTerm(rawTerm: string): string | null {
  const term = rawTerm.trim();
  if (!term) return null;

  // Leading NOT (unary).
  const notMatch = term.match(/^not\s+(.*)$/i);
  if (notMatch) {
    const inner = translateTerm(notMatch[1]);
    return inner ? `not (${inner})` : null;
  }

  if (term.toLowerCase().startsWith("attr:")) {
    return attrContainment(term.slice("attr:".length));
  }

  const fieldMatch = term.match(/^([a-z_]+):(.+)$/i);
  if (fieldMatch) {
    const col = FIELD_COLUMN[fieldMatch[1].toLowerCase()];
    if (col) {
      return `${col} = ${sqlLiteral(unquote(fieldMatch[2]))}`;
    }
  }

  // Unrecognized field or a bare word inside a boolean expression.
  return bareIlike(unquote(term));
}

/** Split a boolean tag-DSL string into terms + the operators between them,
 *  respecting double-quoted segments. Operators are ` OR ` / ` AND `. */
function splitBoolean(s: string): { terms: string[]; ops: ("or" | "and")[] } {
  const terms: string[] = [];
  const ops: ("or" | "and")[] = [];
  let cur = "";
  let inQuote = false;
  let i = 0;
  while (i < s.length) {
    const ch = s[i];
    if (ch === '"') {
      inQuote = !inQuote;
      cur += ch;
      i += 1;
      continue;
    }
    if (!inQuote && s.startsWith(" OR ", i)) {
      terms.push(cur);
      ops.push("or");
      cur = "";
      i += 4;
      continue;
    }
    if (!inQuote && s.startsWith(" AND ", i)) {
      terms.push(cur);
      ops.push("and");
      cur = "";
      i += 5;
      continue;
    }
    cur += ch;
    i += 1;
  }
  terms.push(cur);
  return { terms, ops };
}

/** Detect tag syntax (mirrors `lib/query` `hasTagSyntax`). */
function hasTagSyntax(query: string): boolean {
  const trimmed = query.trim();
  if (!trimmed) return false;
  return (
    /^(address|resource_address|module|provider|type|attr|tag):/.test(trimmed) ||
    trimmed.includes(":") ||
    trimmed.includes(" AND ") ||
    trimmed.includes(" OR ") ||
    trimmed.includes(" NOT ")
  );
}

/**
 * Translate a search tag-DSL query into an MQL WHERE body (no leading `where`),
 * or `null` for an empty query (match everything). Bare terms become substring
 * ILIKE; tag syntax is parsed and translated exactly.
 */
export function searchWhereClause(q: string): string | null {
  const trimmed = q.trim();
  if (!trimmed) return null;

  if (!hasTagSyntax(trimmed)) {
    return bareIlike(trimmed);
  }

  // `tag:K:V` shorthand -> `attr:tags.K:V` (as ensureTagQuery does).
  const normalized = trimmed.replace(/\btag:([^:]+):(\S+)/g, "attr:tags.$1:$2");

  const { terms, ops } = splitBoolean(normalized);
  const predicates = terms.map(translateTerm);

  // Reassemble, dropping any term that failed to translate (with its operator).
  let out = "";
  for (let i = 0; i < predicates.length; i++) {
    const p = predicates[i];
    if (p === null) continue;
    if (out === "") {
      out = `(${p})`;
    } else {
      out += ` ${ops[i - 1]} (${p})`;
    }
  }
  return out === "" ? null : out;
}

// ---------------------------------------------------------------------------
// Query builder
// ---------------------------------------------------------------------------

const PROJECTION = `instances.address as address,
  resources.type as type,
  resources.provider as provider,
  resources.module as module,
  instances.attributes as attributes,
  instances.sensitive_attributes as sensitive_attributes,
  instances.dependencies as dependencies,
  instances.state_id as state_id,
  states.name as state_name`;

/**
 * Full search query. Single-state when `stateId` is given, else all live states
 * in one cursored query (keyset-ordered by `(state_id, address)`). The tag-DSL
 * `q` is translated to a WHERE predicate; an empty `q` matches everything.
 */
export function searchInstancesQuery(
  q: string,
  stateId: string | undefined,
  limit: number = SEARCH_PAGE_LIMIT
): string {
  const where = searchWhereClause(q);
  const stateFilter = stateId ? `\n  and states.id = ${sqlLiteral(stateId)}` : "";
  const searchFilter = where ? `\n  and (${where})` : "";
  return `select ${PROJECTION}
from resources, instances, states
where instances.resource_address = resources.address
  and instances.state_id = resources.state_id
  and states.id = instances.state_id
  and states.deleted_at is null${stateFilter}${searchFilter}
order by instances.state_id, instances.address
limit ${limit}`;
}
