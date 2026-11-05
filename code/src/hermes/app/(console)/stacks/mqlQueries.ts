import { MQL_MAX_LIMIT, asNumber, asText } from "@/lib/mql/providers";
import { sqlLiteral } from "@/lib/mql/escape";
import type { VcsProvider } from "@/lib/vcs/links";

export const STACKS_PR_CAP = Math.min(100, MQL_MAX_LIMIT);
/** Pinned to the server's max_limit — asking for more is silently clamped, and
 *  a truncated fact set would render real pending/failed dirspaces as
 *  "No changes". Callers must surface `capped` instead. */
export const DIRSPACE_FACTS_CAP = Math.min(1000, MQL_MAX_LIMIT);

/** Pin a query to one PR (the detail-page panel); omitted = all open PRs. */
export interface PrScope {
  repoId: number;
  pullNumber: number;
}

/** Pin a query to one repository's PRs (the stack detail page). */
export interface RepoScope {
  owner: string;
  repoName: string;
}

const isPrScope = (s: PrScope | RepoScope): s is PrScope => "pullNumber" in s;

/** Stack lifecycle states, exactly the terrateam `stack-state` enum. */
export type StackState =
  | "apply_failed"
  | "apply_pending"
  | "apply_ready"
  | "apply_success"
  | "no_changes"
  | "plan_failed"
  | "plan_pending";

/**
 * Severity ladder for rolling dirspace states up into inner/outer stack
 * states — a direct port of `stack_state_ordering` + `stack_state_of_dirspaces`
 * (terrat_vcs_stacks.ml): worst state wins by list position; `no_changes` is
 * special-cased as "nothing on the ladder matched".
 */
const STACK_STATE_ORDERING: StackState[] = [
  "plan_failed",
  "plan_pending",
  "apply_failed",
  "apply_pending",
  "apply_ready",
  "apply_success",
];

export function stackStateOf(states: StackState[]): StackState {
  let min = STACK_STATE_ORDERING.length;
  for (const st of states) {
    const i = STACK_STATE_ORDERING.indexOf(st);
    if (i !== -1 && i < min) min = i;
  }
  return min === STACK_STATE_ORDERING.length ? "no_changes" : STACK_STATE_ORDERING[min];
}

/** The stored `pull_request_stacks.stacks` jsonb, shape per the terrateam
 *  `stacks`/`stack-outer`/`stack-inner` schemas. Stored states are all
 *  `no_changes` placeholders — live states are overlaid client-side. */
export interface StackDirspace {
  dir: string;
  workspace: string;
  state: StackState;
}

export interface StackInner {
  name: string;
  state: StackState;
  /** Root-first nested-stack chains from the stored jsonb (paths[i][last] is
   *  the leaf itself; the prefix is its container chain). */
  paths: string[][];
  dirspaces: StackDirspace[];
}

export interface StackOuter {
  name: string;
  state: StackState;
  stacks: StackInner[];
}

export interface PrStacksRow {
  provider: VcsProvider;
  repository: number;
  pullNumber: string;
  owner: string;
  repoName: string;
  title: string;
  /** Selected only by {@link lastKnownStacksQuery}. Undefined for every
   *  stacksQuery variant, including the PR-scoped one, whose pull request can
   *  be in any state. */
  prState?: string;
  /** Outer stacks in stored array order — the PLAN order frozen in by the
   *  engine's topological sort at store time (the sort consumes plan_after
   *  edges only; apply_after never influences it). */
  stacks: StackOuter[];
}

/** Key shared by a PR's stacks entry and its explainer config. */
export function prStacksKey(provider: VcsProvider, repository: number, pullNumber: string): string {
  return `${provider}-${repository}-${pullNumber}`;
}

/** The select list and joins shared by stacksQuery and lastKnownStacksQuery;
 *  `withPrState` adds pr.state for rows that are not open by construction. */
function storedStacksSelect(provider: VcsProvider, withPrState: boolean): string {
  return (
    `select pm.repository_id as repository, pm.pull_number as pull_number, ` +
    `pr.title as title, ${withPrState ? `pr.state as pr_state, ` : ``}r.owner as owner, r.name as name, prs.stacks as stacks ` +
    `from pull_request_stacks as prs ` +
    `inner join ${provider}_pull_requests_map as pm on pm.core_id = prs.pull_request ` +
    `inner join ${provider}_installation_repositories as r on r.id = pm.repository_id ` +
    `inner join ${provider}_pull_requests as pr on pr.repository = pm.repository_id and pr.pull_number = pm.pull_number `
  );
}

/** A repository scope over storedStacksSelect's `r` join, escaped. */
const storedStacksRepoMatch = (scope: RepoScope): string =>
  `r.owner = ${sqlLiteral(scope.owner)} and r.name = ${sqlLiteral(scope.repoName)}`;

/**
 * PRs with their stored stacks: pull_request_stacks joined through the
 * provider PR map to repo + PR metadata. Unscoped = every open PR, newest
 * pull number first; repo-scoped = that repository's open PRs, same order;
 * PR-scoped = that PR in any state.
 */
export function stacksQuery(provider: VcsProvider, scope?: PrScope | RepoScope): string {
  return (
    storedStacksSelect(provider, false) +
    (scope && isPrScope(scope)
      ? `where pm.repository_id = ${scope.repoId} and pm.pull_number = ${scope.pullNumber} limit 1`
      : `where pr.state = 'open' ` +
        (scope ? `and ${storedStacksRepoMatch(scope)} ` : ``) +
        `order by pm.pull_number desc limit ${STACKS_PR_CAP}`)
  );
}

/**
 * The derived config's stacks section for each open PR in the stacks window:
 * the kind='derived' repo_configs row the stored stacks were computed from,
 * keyed by the PR's head branch + head sha. A query of its own, so that only
 * the pending-explainer depends on repo_configs (its row expires after 90 days
 * and its write is best-effort) and the stacks tree loads without it.
 * repo_configs is unique per (installation, repo, branch, sha), so a repo with
 * derived rows under two installations yields two rows; callers keep the first.
 */
export function stacksConfigQuery(provider: VcsProvider): string {
  return (
    `select pm.repository_id as repository, pm.pull_number as pull_number, ` +
    `rc.data -> 'stacks' as stacks_config ` +
    `from pull_request_stacks as prs ` +
    `inner join ${provider}_pull_requests_map as pm on pm.core_id = prs.pull_request ` +
    `inner join ${provider}_pull_requests as pr on pr.repository = pm.repository_id and pr.pull_number = pm.pull_number ` +
    `inner join ${provider}_repositories_map as grm on grm.repository_id = pm.repository_id ` +
    `inner join repo_configs as rc on rc.repo = grm.core_id and rc.kind = 'derived' and rc.branch = pr.branch and rc.sha = pr.sha ` +
    `where pr.state = 'open' order by pm.pull_number desc limit ${STACKS_PR_CAP}`
  );
}

/**
 * Fallback source for the stack detail page when no OPEN pull request carries
 * the stack: the repository's newest pull request, in ANY state, whose stored
 * stacks name the stack. The stored stacks jsonb persists after merge/close,
 * so that row is the stack's last-known shape, frozen at that PR's head. The
 * match is jsonb containment on the outer `stacks[*].name` -- the name
 * mergeOuterStacks looks up -- so the row is found however old it is.
 * `pr.state` rides along so the page can say which PR the shape came from.
 */
export function lastKnownStacksQuery(
  provider: VcsProvider,
  scope: RepoScope,
  stackName: string,
): string {
  return (
    storedStacksSelect(provider, true) +
    `where ${storedStacksRepoMatch(scope)} ` +
    `and prs.stacks @> ${sqlLiteral(JSON.stringify({ stacks: [{ name: stackName }] }))}::jsonb ` +
    `order by pm.pull_number desc limit 1`
  );
}

/**
 * Per-dirspace facts feeding the live state derivation, an MQL port of
 * terrateam's select_dirspace_stack_states.sql: the `latest` CTE replaces
 * `row_number() over (...)` (MQL has no window functions) with a
 * max(created_at) group-by + self-join; the unlock filter discards work
 * manifests older than the PR's last unlock; the final select enumerates the
 * PR's current dirspaces (change_dirspaces at the PR's shas) left-joined to
 * the facts, so a never-run dirspace comes back with a null run_type
 * (→ plan_pending). The 7-way CASE itself is `deriveDirspaceState`.
 *
 * A created_at tie in the self-join can yield two fact rows for one dirspace
 * (upstream's `rn = 1` picks one) — callers fold duplicates through
 * `stackStateOf` so the worst state wins deterministically.
 */
export function dirspaceStatesQuery(provider: VcsProvider, scope?: PrScope | RepoScope): string {
  const prScope = scope && isPrScope(scope) ? scope : undefined;
  const repoScope = scope && !isPrScope(scope) ? scope : undefined;
  // A repo scope narrows the open-PR scopes to one repository, by the owner and
  // name columns each select has at hand.
  const repoMatch = (ownerCol: string, nameCol: string): string =>
    repoScope
      ? `${ownerCol} = ${sqlLiteral(repoScope.owner)} and ${nameCol} = ${sqlLiteral(repoScope.repoName)} and `
      : ``;
  const latestScope = prScope
    ? `wm.repository = ${prScope.repoId} and wm.pull_number = ${prScope.pullNumber}`
    : `${repoMatch("wm.repo_owner", "wm.repo_name")}pr.state = 'open'`;
  const finalScope = prScope
    ? `cd.repository = ${prScope.repoId} and pr.pull_number = ${prScope.pullNumber}`
    : `${repoMatch("r.owner", "r.name")}pr.state = 'open'`;
  return (
    `with latest as (` +
    `select wm.repository as repository, wm.pull_number as pull_number, ` +
    `wmr.path as path, wmr.workspace as workspace, max(wm.created_at) as created_at ` +
    `from ${provider}_work_manifests as wm ` +
    `inner join work_manifest_results as wmr on wmr.work_manifest = wm.id ` +
    `inner join ${provider}_pull_requests as pr on pr.repository = wm.repository and pr.pull_number = wm.pull_number ` +
    `left join ${provider}_pull_request_latest_unlocks as lu on lu.repository = wm.repository and lu.pull_number = wm.pull_number ` +
    `where ${latestScope} and wm.completed_at is not null ` +
    `and pr.base_sha = wm.base_sha and (pr.sha = wm.sha or pr.merged_sha = wm.sha) ` +
    `and (lu.unlocked_at is null or lu.unlocked_at < wm.created_at) ` +
    `group by wm.repository, wm.pull_number, wmr.path, wmr.workspace` +
    `), facts as (` +
    `select l.repository as repository, l.pull_number as pull_number, l.path as path, l.workspace as workspace, ` +
    `wm.run_type as run_type, wmr.success as success, p.work_manifest as plan_wm, p.has_changes as has_changes ` +
    `from latest as l ` +
    `inner join ${provider}_work_manifests as wm on wm.repository = l.repository and wm.pull_number = l.pull_number and wm.created_at = l.created_at and wm.completed_at is not null ` +
    `inner join work_manifest_results as wmr on wmr.work_manifest = wm.id and wmr.path = l.path and wmr.workspace = l.workspace ` +
    `left join plans as p on p.work_manifest = wm.id and p.path = l.path and p.workspace = l.workspace` +
    `) ` +
    `select cd.repository as repository, pr.pull_number as pull_number, cd.path as path, cd.workspace as workspace, ` +
    `f.run_type as run_type, f.success as success, f.plan_wm as plan_wm, f.has_changes as has_changes ` +
    `from ${provider}_change_dirspaces as cd ` +
    `inner join ${provider}_pull_requests as pr on pr.repository = cd.repository and pr.base_sha = cd.base_sha and (pr.sha = cd.sha or pr.merged_sha = cd.sha) ` +
    (repoScope ? `inner join ${provider}_installation_repositories as r on r.id = cd.repository ` : ``) +
    `left join facts as f on f.repository = cd.repository and f.pull_number = pr.pull_number and f.path = cd.path and f.workspace = cd.workspace ` +
    `where ${finalScope} ` +
    // Ordered for two reasons. The server treats an unordered page that hits
    // the limit as a defect and logs PAGINATION_ERR (sgs_mql_paged.ml), and an
    // arbitrary 1000 rows need not cover the PRs stacksQuery actually returned
    // -- a dirspace outside the window misses the state map and renders as the
    // overlay's `no_changes` default, quietly downgrading plan_pending or
    // plan_failed to a neutral chip. Descending pull number matches the
    // stacks query's own window, so the two truncate at the same end. Every
    // column is a field select with an alias in the select list, which is what
    // assert_order_by_cols_can_paginate requires to build a cursor.
    `order by pr.pull_number desc, cd.repository, cd.path, cd.workspace ` +
    `limit ${DIRSPACE_FACTS_CAP}`
  );
}

/**
 * The built-in default stack is a catch-all, not a focal point: in any stack
 * list it sorts LAST, after the user-defined stacks, regardless of the frozen
 * plan order. Stable otherwise (a copy; input order untouched). The engine
 * identifies it only by its literal name.
 */
export function sortStacksDefaultLast<T extends { name: string }>(stacks: T[]): T[] {
  return [...stacks.filter((s) => s.name !== "default"), ...stacks.filter((s) => s.name === "default")];
}

/**
 * The 7-way CASE from select_dirspace_stack_states.sql, ported verbatim.
 * `fact` is undefined when the dirspace has no completed work manifest at the
 * PR's current shas (the SQL's `wm.id is null` arm).
 */
export interface DirspaceFact {
  runType: string;
  success: boolean;
  hasPlanRow: boolean;
  hasChanges: boolean;
}

export function deriveDirspaceState(fact: DirspaceFact | undefined): StackState {
  if (!fact) return "plan_pending";
  if (fact.runType === "apply" && !fact.success) return "apply_failed";
  if (fact.runType === "apply") return "apply_success";
  if (fact.runType === "plan" && !fact.success) return "plan_failed";
  if (fact.runType === "plan" && (!fact.hasPlanRow || !fact.hasChanges)) return "apply_success";
  if (fact.runType === "plan") return "apply_pending";
  return "plan_pending";
}

/** Key for the per-dirspace state map: provider + repo id + PR + dirspace.
 *  Module-private: both sides of the map are built here, so the key shape is
 *  never something a caller has to agree with. */
function dirspaceStateKey(
  provider: VcsProvider,
  repository: number,
  pullNumber: string,
  dir: string,
  workspace: string,
): string {
  return `${provider}|${repository}|${pullNumber}|${dir}|${workspace}`;
}

export function mapDirspaceFactRow(
  provider: VcsProvider,
  raw: unknown,
): { key: string; state: StackState } {
  const o = raw as Record<string, unknown>;
  const hasWm = o.run_type != null;
  return {
    key: dirspaceStateKey(provider, asNumber(o.repository), asText(o.pull_number), asText(o.path), asText(o.workspace)),
    state: deriveDirspaceState(
      hasWm
        ? {
            // `=== true` is safe against SQL three-valued logic only because
            // work_manifest_results.success and plans.has_changes are both
            // NOT NULL upstream; plan_wm-null (no plans row) is hasPlanRow.
            runType: asText(o.run_type),
            success: o.success === true,
            hasPlanRow: o.plan_wm != null,
            hasChanges: o.has_changes === true,
          }
        : undefined,
    ),
  };
}

/** Fold fact rows into the per-dirspace state map, worst state winning on
 *  duplicate keys (the created_at-tie case). */
export function buildStateMap(rows: { key: string; state: StackState }[]): Map<string, StackState> {
  const map = new Map<string, StackState>();
  for (const f of rows) {
    const prev = map.get(f.key);
    map.set(f.key, prev ? stackStateOf([prev, f.state]) : f.state);
  }
  return map;
}

/**
 * Parse a stacks jsonb value (object or JSON string) into typed outer stacks.
 *
 * The stored `state` fields are not read. Upstream writes them as a
 * `no_changes` placeholder and overlayStacks overwrites every one of them, so
 * reading them would only launder an unvalidated wire string into StackState
 * through an unchecked cast. Seed the placeholder here instead, which is both
 * honest about the type and exactly what the overlay falls back to.
 */
function parseStacks(v: unknown): StackOuter[] {
  const root = typeof v === "string" ? (JSON.parse(v) as unknown) : v;
  const o = root as Record<string, unknown> | null;
  const outers = Array.isArray(o?.stacks) ? o.stacks : [];
  return outers.map((raw) => {
    const so = raw as Record<string, unknown>;
    const inners = Array.isArray(so.stacks) ? so.stacks : [];
    return {
      name: asText(so.name),
      state: "no_changes",
      stacks: inners.map((iraw) => {
        const si = iraw as Record<string, unknown>;
        const dss = Array.isArray(si.dirspaces) ? si.dirspaces : [];
        const paths = Array.isArray(si.paths)
          ? si.paths.map((pth) => (Array.isArray(pth) ? pth.map(asText) : []))
          : [];
        return {
          name: asText(si.name),
          state: "no_changes",
          paths,
          dirspaces: dss.map((draw) => {
            const d = draw as Record<string, unknown>;
            const ds = d.dirspace as Record<string, unknown> | undefined;
            return {
              dir: asText(ds?.dir),
              workspace: asText(ds?.workspace),
              state: "no_changes" as StackState,
            };
          }),
        };
      }),
    };
  });
}

export function mapPrStacksRow(provider: VcsProvider, raw: unknown): PrStacksRow {
  const o = raw as Record<string, unknown>;
  return {
    provider,
    repository: asNumber(o.repository),
    pullNumber: asText(o.pull_number),
    owner: asText(o.owner),
    repoName: asText(o.name),
    title: asText(o.title),
    prState: o.pr_state == null ? undefined : asText(o.pr_state),
    stacks: parseStacks(o.stacks),
  };
}

export function mapStacksConfigRow(
  provider: VcsProvider,
  raw: unknown,
): { key: string; config: StacksConfig | null } {
  const o = raw as Record<string, unknown>;
  return {
    key: prStacksKey(provider, asNumber(o.repository), asText(o.pull_number)),
    config: parseStacksConfig(o.stacks_config),
  };
}

/**
 * Overlay live dirspace states onto a PR's stored stacks and roll inner/outer
 * states up the ladder — the client-side counterpart of terrat_vcs_stacks.ml's
 * `query` (update_inner_stack_state + outer_stack_state). Missing map entries
 * default to `no_changes`, exactly like the Dirspace_map lookup upstream.
 */
export function overlayStacks(row: PrStacksRow, states: Map<string, StackState>): StackOuter[] {
  return row.stacks.map((outer) => {
    const inners = outer.stacks.map((inner) => {
      const dirspaces = inner.dirspaces.map((d) => ({
        ...d,
        state:
          states.get(dirspaceStateKey(row.provider, row.repository, row.pullNumber, d.dir, d.workspace)) ??
          ("no_changes" as StackState),
      }));
      return { ...inner, dirspaces, state: stackStateOf(dirspaces.map((d) => d.state)) };
    });
    return {
      ...outer,
      stacks: inners,
      state: stackStateOf(inners.flatMap((i) => i.dirspaces.map((d) => d.state))),
    };
  });
}

/* ------------------------------------------------------------------------- */
/* Pending-explainer: why is a stack waiting?                                */
/* ------------------------------------------------------------------------- */

export interface StackRules {
  planAfter: string[];
  applyAfter: string[];
}

export interface StackNode {
  /** Nested-config stacks list; empty for a leaf (tag-query) stack. */
  nested: string[];
  rules: StackRules;
}

/** The derived config's stacks.names map. */
export type StacksConfig = Map<string, StackNode>;

const strList = (v: unknown): string[] => (Array.isArray(v) ? v.map(asText).filter(Boolean) : []);

/** Parse `repo_configs.data->'stacks'` (object or JSON string). Null when the
 *  repo has no user-defined stacks — the serializer omits the whole section
 *  for the implicit default stack — or when the config row was missing. */
export function parseStacksConfig(v: unknown): StacksConfig | null {
  if (v == null) return null;
  let root: unknown;
  try {
    root = typeof v === "string" ? (JSON.parse(v) as unknown) : v;
  } catch {
    // Only the explainer reads this: a malformed value must not throw out of
    // the per-provider load and take the provider's whole tree with it.
    return null;
  }
  const names = (root as Record<string, unknown> | null)?.names;
  if (names == null || typeof names !== "object") return null;
  const out: StacksConfig = new Map();
  for (const [name, raw] of Object.entries(names as Record<string, unknown>)) {
    if (raw == null || typeof raw !== "object") continue;
    const node = raw as Record<string, unknown>;
    const rules = (node.rules ?? {}) as Record<string, unknown>;
    out.set(name, {
      nested: strList(node.stacks),
      rules: { planAfter: strList(rules.plan_after), applyAfter: strList(rules.apply_after) },
    });
  }
  return out.size > 0 ? out : null;
}

/** Leaves reachable from a nested-config name, transitively (a plain name is
 *  its own leaf). Mirrors the engine's stack-lookup expansion; the visited set
 *  guards against config cycles even though the engine rejects them upstream. */
function nestedLeaves(config: StacksConfig, name: string, seen: Set<string>): string[] {
  if (seen.has(name)) return [];
  seen.add(name);
  const node = config.get(name);
  if (!node || node.nested.length === 0) return [name];
  return node.nested.flatMap((child) => nestedLeaves(config, child, seen));
}

/**
 * The effective plan_after/apply_after lists for a leaf stack — a port of the
 * engine's expand_stack_config (terrat_change_match3.ml): the leaf's own rules
 * merge with the raw rules of every container above it, each name expands to
 * its leaves once, and the result is closed transitively over the raw rules
 * without expanding again (the engine's apply check compares leaf names, so a
 * container name reached that way never blocks). The apply side mirrors the
 * engine's apply_after filter. The plan side covers plan_after edges only: the
 * engine plans one layer at a time and layers also come from depends_on, so a
 * plan_pending stack can be waiting with no line shown.
 */
export function effectiveRules(
  config: StacksConfig,
  leaf: string,
  containers: string[],
): StackRules {
  const effective = (pick: (r: StackRules) => string[]): string[] => {
    const merged = [leaf, ...containers].flatMap((n) => {
      const node = config.get(n);
      return node ? pick(node.rules) : [];
    });
    const queue = merged.flatMap((s) => nestedLeaves(config, s, new Set()));
    const out: string[] = [];
    const seen = new Set<string>();
    while (queue.length > 0) {
      const name = queue.shift()!;
      if (seen.has(name)) continue;
      seen.add(name);
      if (name !== leaf) out.push(name);
      const node = config.get(name);
      if (node) queue.push(...pick(node.rules));
    }
    return out;
  };
  return {
    planAfter: effective((r) => r.planAfter),
    applyAfter: effective((r) => r.applyAfter),
  };
}

export interface PendingReasons {
  plan: string[];
  apply: string[];
  /** Set when nothing blocks this stack, so turning the explainer on always
   *  says something rather than rendering an invisible result. */
  note?: string;
}

/** Whether the pending explainer can be offered: some PR has a derived config,
 *  and the facts query was not truncated -- truncated facts default missing
 *  dirspaces to no_changes, which is not outstanding, so real blockers would
 *  silently disappear. */
export function explainerAvailable(
  entries: { config: StacksConfig | null }[],
  cappedFacts: boolean,
): boolean {
  return !cappedFacts && entries.some((e) => e.config !== null);
}

/** A collapsed outer stack's pending reasons: the de-duplicated union of its
 *  inner stacks'. */
export function outerPendingReasons(
  outer: StackOuter,
  reasons: Map<string, PendingReasons>,
): PendingReasons {
  const plan = [...new Set(outer.stacks.flatMap((i) => reasons.get(i.name)?.plan ?? []))];
  const apply = [...new Set(outer.stacks.flatMap((i) => reasons.get(i.name)?.apply ?? []))];
  if (plan.length > 0 || apply.length > 0) return { plan, apply };
  // Nothing blocks any inner stack: summarize their notes instead, so the
  // collapsed row still says why nothing is waiting.
  const notes = [
    ...new Set(
      outer.stacks.map((i) => reasons.get(i.name)?.note).filter((x): x is string => !!x),
    ),
  ];
  return notes.length > 0 ? { plan, apply, note: notes.join(" · ") } : { plan, apply };
}

/** A stack still has work outstanding — the mirror of the engine's
 *  "unapplied" predicate: anything not applied and not no-changes. */
const outstanding = (inner: StackInner): boolean =>
  inner.dirspaces.some((d) => d.state !== "apply_success" && d.state !== "no_changes");

/**
 * Per-leaf pending reasons across ALL of a PR's outer stacks (blockers can
 * live in a different outer group). A "Pending plan of" line fires for a
 * plan_pending stack whose effective plan_after names an outstanding stack;
 * "Pending apply of" for an apply_pending/apply_ready stack via apply_after.
 * Unknown names are dropped (stale config vs stored stacks) and stacks with
 * no outstanding work are not blockers, mirroring the engine's filter over
 * unapplied matches only.
 */
export function pendingReasons(
  outers: StackOuter[],
  config: StacksConfig | null,
): Map<string, PendingReasons> {
  const out = new Map<string, PendingReasons>();
  if (!config) return out;
  const byName = new Map<string, StackInner>();
  for (const o of outers) for (const i of o.stacks) byName.set(i.name, i);
  for (const o of outers) {
    for (const inner of o.stacks) {
      const containers = [...new Set(inner.paths.flatMap((p) => p.slice(0, -1)))];
      const eff = effectiveRules(config, inner.name, containers);
      const blockers = (list: string[]): string[] =>
        list.filter((nm) => nm !== inner.name && byName.has(nm) && outstanding(byName.get(nm)!));
      const plan = inner.state === "plan_pending" ? blockers(eff.planAfter) : [];
      const apply =
        inner.state === "apply_pending" || inner.state === "apply_ready"
          ? blockers(eff.applyAfter)
          : [];
      if (plan.length > 0 || apply.length > 0) {
        out.set(inner.name, { plan, apply });
        continue;
      }
      // A failed stack is not waiting on ordering, and its chip already says
      // it failed; "Nothing pending" would contradict the blocker line of a
      // stack waiting on it.
      if (inner.state === "plan_failed" || inner.state === "apply_failed") {
        out.set(inner.name, { plan, apply });
        continue;
      }
      // Nothing blocking: say which of the three reasons that is, so the
      // explainer is never a control that produces no visible output.
      const hasRules = eff.planAfter.length > 0 || eff.applyAfter.length > 0;
      const waiting =
        inner.state === "plan_pending" ||
        inner.state === "apply_pending" ||
        inner.state === "apply_ready";
      const note = !waiting
        ? "Nothing pending"
        : hasRules
          ? "Ordering satisfied — ready to run"
          : "No ordering rules — runs independently";
      out.set(inner.name, { plan, apply, note });
    }
  }
  return out;
}

// ---------------------------------------------------------------------------
// Per-stack detail view (#1737 item 5)
// ---------------------------------------------------------------------------

/** The per-stack page for an outer stack of one repository. */
export function stackDetailHref(
  provider: VcsProvider,
  owner: string,
  repoName: string,
  stack: string,
): string {
  return `/stacks/detail?provider=${provider}&owner=${encodeURIComponent(owner)}&repo=${encodeURIComponent(repoName)}&stack=${encodeURIComponent(stack)}`;
}

/** Cap for the per-stack run history query. */
export const STACK_RUNS_CAP = 300;

/**
 * Run history over a stack's directories in one repository, for the stack
 * detail page. One row per (run, dirspace) whose path is one of `dirs` (must be
 * non-empty); the client matches the workspace and dedupes by run. The caller
 * adds each row's `fail_count` (lib/wm/failCounts.ts) before
 * {@link mapStackRunRow}, same as the Runs tab.
 */
export function stackRunsQuery(
  provider: VcsProvider,
  owner: string,
  repoName: string,
  dirs: string[],
): string {
  return (
    `select wm.id as id, wm.state as state, wm.run_type as run_type, ` +
    `wm.run_kind as run_kind, wm.created_at as created_at, wm.username as username, ` +
    `wm.pull_number as pull_number, wmds.path as dir, wmds.workspace as workspace ` +
    `from work_manifest_dirspaceflows as wmds ` +
    `inner join ${provider}_work_manifests as wm on wm.id = wmds.work_manifest ` +
    `where wm.repo_owner = ${sqlLiteral(owner)} and wm.repo_name = ${sqlLiteral(repoName)} ` +
    `and wmds.path in (${dirs.map(sqlLiteral).join(", ")}) ` +
    `order by wm.created_at desc limit ${STACK_RUNS_CAP}`
  );
}

/** The newest plan run of one dirspace of one pull request, in any state and
 *  at any sha. */
export function latestPlanQuery(
  provider: VcsProvider,
  pr: PrScope,
  dir: string,
  workspace: string,
): string {
  return (
    `select wm.id as id, wm.created_at as created_at ` +
    `from work_manifest_dirspaceflows as wmds ` +
    `inner join ${provider}_work_manifests as wm on wm.id = wmds.work_manifest ` +
    `where wm.repository = ${pr.repoId} and wm.pull_number = ${pr.pullNumber} and wm.run_type = 'plan' ` +
    `and wmds.path = ${sqlLiteral(dir)} and wmds.workspace = ${sqlLiteral(workspace)} ` +
    `order by wm.created_at desc limit 1`
  );
}

/** Run detail page opened on the plan of one dirspace. */
export function planRunHref(id: string, dir: string, workspace: string): string {
  return `/runs/wm?${new URLSearchParams({ id, view: "changes", dir, workspace })}`;
}

export interface StackRunRow {
  id: string;
  state: string;
  failCount: number;
  runType: string;
  runKind: string;
  createdAt: string;
  username: string;
  pullNumber: string;
  dir: string;
  workspace: string;
}

export function mapStackRunRow(raw: unknown): StackRunRow {
  const o = (raw ?? {}) as Record<string, unknown>;
  return {
    id: asText(o.id),
    state: asText(o.state),
    failCount: asNumber(o.fail_count),
    runType: asText(o.run_type),
    runKind: asText(o.run_kind),
    createdAt: asText(o.created_at),
    username: asText(o.username),
    pullNumber: asText(o.pull_number),
    dir: asText(o.dir),
    workspace: asText(o.workspace),
  };
}

/** The PR's outer groups named `name`, merged in plan order (the engine groups
 *  only successive entries, so one name can be several groups). Null when absent. */
export function mergeOuterStacks(outers: StackOuter[], name: string): StackOuter | null {
  const groups = outers.filter((o) => o.name === name);
  if (groups.length === 0) return null;
  const stacks = groups.flatMap((g) => g.stacks);
  return { name, stacks, state: stackStateOf(stacks.flatMap((i) => i.dirspaces.map((d) => d.state))) };
}

/** One pull request's version of a stack: the pull request, and the stack's
 *  merged groups with the given live states overlaid. */
export interface StackVersion {
  pullNumber: string;
  title: string;
  prState?: string;
  outer: StackOuter;
}

/** The versions of `stackName` carried by `rows`, newest pull request first.
 *  Rows whose stored stacks don't name the stack are dropped; `states` is the
 *  live-state map to overlay, empty when no live state applies. */
export function stackVersions(
  rows: PrStacksRow[],
  states: Map<string, StackState>,
  stackName: string,
): StackVersion[] {
  return rows
    .flatMap((row) => {
      const outer = mergeOuterStacks(overlayStacks(row, states), stackName);
      return outer
        ? [{ pullNumber: row.pullNumber, title: row.title, prState: row.prState, outer }]
        : [];
    })
    .sort((a, b) => Number(b.pullNumber) - Number(a.pullNumber));
}

/** The `dir:workspace` leaf set of an outer stack, for membership tests. */
export function stackLeafDirspaces(outer: StackOuter): Set<string> {
  const out = new Set<string>();
  for (const inner of outer.stacks) for (const d of inner.dirspaces) out.add(`${d.dir}:${d.workspace}`);
  return out;
}

/**
 * Fold per-(run, dirspace) rows down to the runs that touched the stack:
 * membership by leaf dirspace, first (newest) row per run wins, input order
 * (created_at desc) preserved.
 */
export function filterRunsToStack(rows: StackRunRow[], leaves: Set<string>): StackRunRow[] {
  const seen = new Set<string>();
  const out: StackRunRow[] = [];
  for (const row of rows) {
    if (!leaves.has(`${row.dir}:${row.workspace}`)) continue;
    if (seen.has(row.id)) continue;
    seen.add(row.id);
    out.push(row);
  }
  return out;
}
