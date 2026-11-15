with
rt1 as (
    -- The rows of today.  The write path stamps [current_date] on every store and the primary
    -- key is (installation, sha, cache_day, path), so one path of one sha holds at most one row
    -- at [current_date]: no dedup and no tie-break is needed.  [cache_day] is the key's third
    -- column, directly after the (installation, sha) prefix both probes filter on, so this
    -- probe and the rt2 probe below run inside the index with no sort.  A tree
    -- whose rows all sit on an earlier day answers nothing here; the caller promotes it through
    -- promote_repo_tree.sql and reads again.
    select rt.path, rt.changed, rt.id
    from gitlab_repo_trees as rt
    where rt.installation_id = $installation_id
          and rt.sha = $sha
          and rt.cache_day = current_date
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
    --
    -- This CTE is copied verbatim into promote_repo_tree.sql: the repository has no SQL include
    -- mechanism, so a change to the span of the base lookup must change both files.
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
rt2 as (
    -- The rows of today of every sha above.  More than one of the shas can hold a tree at
    -- [current_date] -- every sha the write path stored today carries its whole tree there --
    -- and then the left join below multiplies rt1 and the caller sees the same path more than
    -- once, with conflicting answers.  Prefer the tree of the base sha itself; it is the direct
    -- answer, and the pull request lookup above is only a fallback for when the tree was built
    -- under the other sha.  Once the sha is chosen, the primary key holds one row per path at
    -- [current_date], so no tie can remain.
    --
    -- "= any (array(...))" rather than "in (...)": with a subquery the planner
    -- hash joins against a full scan of the tree table, but an array is a value
    -- it can probe with, so the sha becomes part of the index condition
    -- alongside the installation.
    select distinct on (rt.path) rt.path, rt.id
    from gitlab_repo_trees as rt
    where rt.installation_id = $installation_id
      and rt.sha = any (array(select sha from base_shas))
      and rt.cache_day = current_date
    order by rt.path, (rt.sha is not distinct from $base_sha) desc, rt.sha
)
select
    rt1.path,
    (case
       when rt1.changed is not null then rt1.changed
       when rt1.id is not null and rt2.id is not null then rt1.id <> rt2.id
       when rt1.id is not null and rt2.id is null then true
       else null
    end)
from rt1
left join rt2
     on rt1.path = rt2.path
