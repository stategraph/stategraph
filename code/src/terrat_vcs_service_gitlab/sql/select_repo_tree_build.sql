-- The built check of one sha.  It answers the sha of the newest build the $script_only filter
-- lets through.  When that build is not of the current day, the same statement promotes the
-- whole answering day to the current day: the build row itself, and every tree row the sha
-- holds at that day.  The tree reads answer only the rows of the current day
-- (select_repo_tree.sql), so the rows of an older day stay unread until something moves them,
-- and this check is what extends their lifetime.
--
-- The write lives inside the read because this check runs once per evaluation and not on every
-- warm tree read: the warm read keeps its promotion in a separate statement
-- (promote_repo_tree.sql), so a warm read writes nothing.  The promotion is also idempotent
-- here: the answering row of a second read is already of the current day, and both copies skip
-- a source day that is the current day.
-- The build row is promoted only while the tree rows it names are still there.  A build row whose
-- tree rows the retention walk has reaped is an orphan: [ensure_repo_tree] reads it as "built",
-- [store_repo_tree] never runs again, and the changes read answers no path -- a run-everything
-- fallback turned into a silent skip.  The gate is the same exists-of-tree-rows relation the
-- [promoted_trees] join above enforces, so the two copies move together.  The trade is stated: a
-- built-and-empty tree has a build row and no tree rows, so its build row stops being kept alive by
-- evaluation and expires once per retention window, then rebuilds on the next evaluation.
with
answering as (
    select rtb.installation,
           rtb.sha,
           rtb.cache_day,
           rtb.created_at,
           rtb.built_by_script
    from repo_tree_builds as rtb
    inner join gitlab_installations_map as gim
          on gim.core_id = rtb.installation
    where gim.installation_id = $installation_id
          and rtb.sha = $sha
          -- With $script_only, only a tree the tree builder script made answers.
          and (not $script_only or coalesce(rtb.built_by_script, false))
    -- One row per (installation, sha, cache_day), and one sha can hold several days: the write
    -- path writes the current day, and a promotion copies an answered day forward beside it.
    -- Answer with the newest build, and prefer the current day when two builds tie on
    -- created_at, which a promotion makes: a promoted row carries the created_at of the row it
    -- came from, so the second read answers the promoted row and writes nothing.
    order by rtb.created_at desc, rtb.cache_day desc
    limit 1
),
promoted_trees as (
    insert into repo_trees (installation, sha, cache_day, path, changed, id, created_at)
    select rt.installation,
           rt.sha,
           current_date,
           rt.path,
           rt.changed,
           rt.id,
           rt.created_at
    from answering as a
    inner join repo_trees as rt
          on rt.installation = a.installation
         and rt.sha = a.sha
         and rt.cache_day = a.cache_day
    where a.cache_day <> current_date
    on conflict (installation, sha, cache_day, path)
    -- The write path's upsert: refresh the payload in place.  The created_at of the source row
    -- rides along, so a promoted row names the time its rows entered their day.
    do update set (
       changed,
       id
    ) = (
      excluded.changed,
      excluded.id
    )
),
promoted_builds as (
    insert into repo_tree_builds (installation, sha, cache_day, created_at, built_by_script)
    select a.installation,
           a.sha,
           current_date,
           a.created_at,
           a.built_by_script
    from answering as a
    where a.cache_day <> current_date
          -- The probe reads the source day, which [promoted_trees] above writes to
          -- [current_date]: the two CTEs touch disjoint rows, and every CTE of one statement reads
          -- one snapshot, so the probe never sees this statement's own inserts.
          and exists (
              select 1
              from repo_trees as rt
              where rt.installation = a.installation
                    and rt.sha = a.sha
                    and rt.cache_day = a.cache_day
          )
    on conflict (installation, sha, cache_day)
    -- The write path's upsert: a tree the script made stays the tree of that commit -- a later
    -- promotion over a forge-built row lifts the producer to true, and a promotion of a
    -- forge-built day never lowers a script-built one.  The created_at of the row stays.
    do update set built_by_script = coalesce(repo_tree_builds.built_by_script, false)
                                or coalesce(excluded.built_by_script, false)
)
select a.sha
from answering as a
