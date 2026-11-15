-- Lift the trees of the shas the read answers against (select_repo_tree.sql) to today: the read
-- answers only the rows of [current_date], so a tree whose newest stored day is earlier reads as
-- not-there until its newest day is copied to [current_date].  The copy carries every path of
-- the sha, its [changed] and [id], and the source row's [created_at]; the sha of every row that
-- inserted comes back, so the caller can tell a promotion that moved rows from one that found
-- nothing to copy.
--
-- The promotion is its own statement rather than a CTE of the read on purpose: a statement that
-- both writes and answers takes RowExclusiveLock on the partitioned parent on every run, so the
-- warm read -- the read that finds its rows already at today and has nothing to promote -- would
-- queue behind the retention walk's exclusive lock on the parent.  A warm read must issue no
-- write, thus the caller promotes only after a read that answered nothing, and then reads again.
--
-- The base_shas CTE below is a copy of select_repo_tree.sql's: the repository has no SQL include
-- mechanism, so a change to the span of the base lookup must change both files.
with
core as (
    -- The core installation the rows key on.  The views translate it through the map; the
    -- promotion reads and writes the partitioned parents directly, so it translates first.
    select gim.core_id
    from gitlab_installations_map as gim
    where gim.installation_id = $installation_id
),
base_shas as (
    -- The shas the base tree may be stored under.  The base sha itself is one
    -- of them: a tree built for the destination branch is stored under the sha
    -- of that branch, and a destination branch that is pushed to directly has
    -- no pull request row to be found through.  A pull request carries its head
    -- sha and, once merged, its merge sha, and the tree may have been built
    -- under either.
    --
    -- Collecting them into a set first is what lets the lookup below use the
    -- (installation, sha) index prefix.  Expressed as a join condition,
    -- "rt.sha in (bsp.sha, bsp.merged_sha)" is an OR, which cannot become an
    -- index condition: the planner fell back to reading every tree row the
    -- installation had ever stored and discarding almost all of them, so the
    -- cost grew with every sha ever built rather than with the size of one
    -- tree.
    select $base_sha::text as sha
    union
    select bsp.sha as sha
    from gitlab_pull_requests as bsp
    where bsp.sha = $base_sha or bsp.merged_sha = $base_sha
    union
    select bsp.merged_sha as sha
    from gitlab_pull_requests as bsp
    where (bsp.sha = $base_sha or bsp.merged_sha = $base_sha) and bsp.merged_sha is not null
),
span as (
    -- The shas whose trees the promotion lifts: the sha the caller looks up, plus every sha the
    -- base lookup may fall back to.  A base tree left on an earlier day is a tree the read no
    -- longer finds, so it promotes with the head tree and not only the head tree alone.
    select $sha::text as sha
    union
    select sha from base_shas
),
newest_day as (
    -- The newest day each span sha holds rows at: one scalar max per sha, not a grouped max over
    -- the span.  The grouped form has no [cache_day] bound, so it reads every stored day of every
    -- span sha -- one whole tree copy per day -- and the [group by] blocks the planner's
    -- max-becomes-limit rewrite, so the cost grew with the retention window times the tree; the
    -- scalar form lets the planner answer each max with a backward index scan that reads the
    -- first entry of the (installation, sha) prefix in each partition and nothing more.
    select s.sha,
           (select max(rt.cache_day)
            from repo_trees as rt
            where rt.installation = (select core_id from core)
                  and rt.sha = s.sha) as cache_day
    from span as s
),
stale as (
    -- The trees that are not at today.  A sha with no rows answers no row here, and a sha whose
    -- newest day is [current_date] -- the sha of a warm read, or one the promotion already
    -- lifted -- is not stale, so a second promotion of the same span copies nothing.
    select sha, cache_day
    from newest_day
    where cache_day <> current_date
)
insert into repo_trees (installation, sha, cache_day, path, changed, id, created_at)
select
    src.installation,
    src.sha,
    current_date,
    src.path,
    src.changed,
    src.id,
    src.created_at
from stale as st
inner join repo_trees as src
      on src.installation = (select core_id from core)
     and src.sha = st.sha
     and src.cache_day = st.cache_day
on conflict (installation, sha, cache_day, path) do nothing
returning sha
