-- The rows of [repo_trees] are written for each commit whose tree is fetched or built, and nothing
-- else removes them.  The tree of a repository of 100 000 files is 100 000 rows, thus a repository
-- which is pushed to often fills the table and never empties it.  The table is keyed by
-- installation and not by repository, thus delete_repo.sql does not reach it either.
--
-- A tree is deleted whole, thus the batch below counts trees and not rows.  Half a tree reads as a
-- tree whose files were removed, which is safe but makes every dirspace of that run run again for
-- no reason.  [repo_tree_builds] is what says a tree is there, thus the two tables are emptied
-- together, and a tree is reached through [repo_tree_builds].  store_repo_tree writes that row
-- after it writes the rows of the tree, and the two writes are not one transaction, thus a process
-- which stops between them leaves rows this statement does not reach.  The next evaluation of that
-- sha writes the tree again, build row and all, and the tree is then deletable; a sha which is
-- never evaluated again keeps its rows.
--
-- A tree which is deleted is not work which is lost.  The head of a branch is fetched and stored
-- again the next time that branch is evaluated, and a run whose tree is gone counts as a run whose
-- files all changed, thus its dirspace runs again.  Fourteen days is the horizon of
-- delete_old_terraform_plans.sql: after it the plan of that run is gone as well, thus its tree can
-- answer no question.
--
-- The tree of the commit or of the base commit of a queued or running work manifest stays: the
-- result of that run is evaluated with the refs of the run pinned, and a pinned evaluation cannot
-- store a tree again.
--
-- The limit is arbitrary, as it is in delete_old_terraform_plans.sql.  A run which does not keep up
-- leaves the rest to the run of the next hour.
with
in_flight as (
    select sha from work_manifests where state in ('queued', 'running')
    union
    select base_sha from work_manifests where state in ('queued', 'running')
),
old_trees as (
    select installation, sha
    from repo_tree_builds
    where created_at < now() - interval '14 days'
          and sha not in (select sha from in_flight)
    limit 100
),
deleted_trees as (
    delete from repo_trees
    using old_trees
    where repo_trees.installation = old_trees.installation
          and repo_trees.sha = old_trees.sha
),
deleted_builds as (
    delete from repo_tree_builds
    using old_trees
    where repo_tree_builds.installation = old_trees.installation
          and repo_tree_builds.sha = old_trees.sha
    returning repo_tree_builds.sha
)
select count(*) from deleted_builds
