-- The two repo tree tables become time-partitioned caches of rebuildable data.
--
-- [repo_trees] holds the paths of a tree and [repo_tree_builds] records that a tree was built.
-- Only the daily retention task removes their rows, and the tree of a
-- repository of 100 000 files is 100 000 rows, so a repository which is pushed to often fills its
-- tables and never empties them.  Both tables are caches: a tree is fetched or built again the
-- next time its sha is evaluated, and a build row is written again on the next build.  Dropping
-- the backlog is therefore safe.  The only visible effect is that a sha which is not evaluated
-- again inside the retention horizon reads as "tree not built", and a run whose tree is not there
-- counts as a run whose files all changed -- a run which runs again, not work which is lost.
--
-- The scheme: each table is [partition by range (cache_day)], with the day partitions of
-- the current day and the next, plus a [default] partition for everything outside.  The
-- migration body creates the two day partitions after this schema runs, computing their names
-- with the same naming rule the daily retention task uses, so each table starts with three
-- children and the days roll forward without an operator.
--
-- The two timestamp columns carry different roles.  [cache_day] is the day the row was last
-- stored and the retention clock: the write path stamps [current_date], so a re-store of a tree
-- moves the whole tree to today, and the retention horizon runs from the last store.  A sha
-- evaluated again inside the horizon keeps its rows however old its first build is; a sha left
-- alone expires whole, one day after its last store passes the horizon.  [created_at] is the
-- instant the row entered that day; it is in no key, and no read or retention statement orders
-- or filters by it.
--
-- The primary keys carry [cache_day] and not [created_at], because the partition key must be
-- part of every unique constraint of a partitioned table.  Two rows of one (installation, sha,
-- path) can now exist, one per stored day.  The write path (insert_repo_tree.sql) stamps
-- [current_date], so a re-store of one tree on one day hits its own rows again and updates in
-- place, never moving a row between partitions, which PostgreSQL does not allow.
--
-- A process still running the old bytes keeps working across the swap, and that is safe.  Its
-- inserts arbitrate [on conflict on constraint repo_trees_pkey] and [on conflict on constraint
-- repo_tree_builds_pkey]: those constraint names belong to the recreated tables' unnamed primary
-- keys, which regenerate the same auto-names, so its statements re-plan and upsert rather than fail
-- to prepare.  It omits [cache_day], which defaults to [current_date], so it writes the current
-- day's rows -- the rows the new write path writes -- and the new primary keys admit them.  The
-- multi-day model is the only difference, and a stale writer never writes an older day.
--
-- The window reaches the read side too, and the read side is the half that shows.  The deployed
-- reader has no dedup and no day filter: the select_repo_tree.sql of this release reads only the
-- rows of [current_date] and keeps one row per path, so a deployed reader against the new schema
-- returns the rows of every stored day of a sha, and a path reads once per day it was stored at.
-- The duplicate is absorbed downstream: pull_request_diff builds a change set, so two rows of
-- one path name one dirspace and match the same keys.  The two visible effects are a multiplied
-- CHANGES log count and extra VCS fetches, because the cache key hashes the path list and the
-- duplicated list changes it.  Neither flips a verdict, and the duplicate is bounded by the
-- retention horizon: the new write path restores one stored day per sha on its first store, and
-- the horizon expires the rows of the earlier days.
--
-- The transaction guards ([set local timezone] and [set local lock_timeout]) are not in this
-- file: the migration body issues them first, before it reads the day bounds the horizon
-- partitions are named from, and [set local] is transaction-scoped and last-writer-wins, so a
-- later statement must not re-set them.
--
-- The drops below discard every cached tree, which the backwards-compatibility rule of
-- [agent_docs/database_conventions.md] refuses for a table whose rows are not rebuildable.  These
-- rows are rebuildable: a sha evaluated again fetches or builds its tree again, and a run whose
-- tree is gone counts as a run whose files all changed.  This migration therefore takes that rule's
-- rebuildable-cache exception.  The cost is one fetch or build per sha that is evaluated again
-- inside the retention horizon, and the window is bounded by that horizon.  Every statement of this
-- file runs in the migration's single transaction, so no reader observes a missing relation.
drop view github_repo_trees;
drop view gitlab_repo_trees;
drop table repo_trees;
drop table repo_tree_builds;
create table repo_trees (
    installation uuid not null,
    sha text not null,
    created_at timestamp with time zone not null default (now()),
    cache_day date not null default current_date,
    path text not null,
    changed boolean,
    id text,
    -- [include] keeps the primary key index covering for the hot tree read
    -- (select_repo_tree.sql): it projects [changed] and [id] over the rows of
    -- one (installation, sha) at [cache_day] of today, the columns and the
    -- key prefix the read scans.  The include columns propagate to every
    -- partition, so the read stays index-only there.
    primary key (installation, sha, cache_day, path) include (changed, id)
) partition by range (cache_day);
create table repo_tree_builds (
    sha text not null,
    installation uuid not null,
    created_at timestamp with time zone not null default (now()),
    cache_day date not null default current_date,
    built_by_script boolean,
    -- [include] keeps the primary key index covering for the build read
    -- (select_repo_tree_build.sql), whose [built_by_script] filter otherwise
    -- forces a heap fetch of every candidate row.
    primary key (installation, sha, cache_day) include (built_by_script)
) partition by range (cache_day);
create table repo_trees_default partition of repo_trees default;
create table repo_tree_builds_default partition of repo_tree_builds default;
-- The retention statements predicate on [cache_day] against the default
-- partitions -- the expired-rows delete and the drain's day counts -- and no
-- primary key serves them: the default partitions hold the rows of every
-- day.  The index lives on the child only, so the day partitions, which
-- never need it, stay lean.
create index repo_trees_default_cache_day_idx on repo_trees_default (cache_day);
create index repo_tree_builds_default_cache_day_idx on repo_tree_builds_default (cache_day);
create or replace view github_repo_trees as
    select
     gim.installation_id as installation_id,
     rt.sha as sha,
     rt.created_at as created_at,
     rt.cache_day as cache_day,
     rt.path as path,
     rt.changed as changed,
     rt.id as id
    from repo_trees as rt
    inner join github_installations_map as gim
          on rt.installation = gim.core_id;
create or replace view gitlab_repo_trees as
    select
     gim.installation_id as installation_id,
     rt.sha as sha,
     rt.created_at as created_at,
     rt.cache_day as cache_day,
     rt.path as path,
     rt.changed as changed,
     rt.id as id
    from repo_trees as rt
    inner join gitlab_installations_map as gim
          on rt.installation = gim.core_id;
