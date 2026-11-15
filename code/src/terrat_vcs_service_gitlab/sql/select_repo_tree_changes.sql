-- The paths whose contents are not the same in two trees of one repository.
--
-- A path which only one of the two trees holds is a change as well, thus the join is a full outer
-- join.  A row with no id says nothing about the contents of that file, thus it counts as a
-- change: a tree which is not there must mean "run it" and never "skip it".
--
-- Each tree is read at the newest day its sha holds, as an equality on [cache_day]: the primary
-- key allows one row of one path per stored day, so reading one day needs no dedup, and reading
-- the newest day keeps a path which the newest tree no longer holds from being answered out of
-- an older stored day of the same sha.
--
-- The join reads the rows of the two trees through the (installation, sha, cache_day, path)
-- index, and it gives back the paths which changed and no others.  Thus what crosses to the
-- caller, and what the change match then walks, follows the number of paths which changed.  The
-- work in the database does not: both trees are read whole, thus the cost here follows the number
-- of files in the repository.  The caller keeps the answer of each sha for the evaluation, and it
-- asks repo_tree_builds first, so that a sha with no tree costs a lookup of a primary key rather
-- than this join over a tree which is not there.
-- The anchor is [max(cache_day)] and not [current_date], because the caller reaches this statement
-- only after the built check of both shas (select_repo_tree_build.sql) has promoted their answering
-- day to [current_date].  On a healthy sha the two anchors read identical rows.  They part in one
-- corner: a build chain that stalled after its tree chain advanced, where [current_date] and the
-- build day both answer nothing and the newest tree day is the only day that holds the rows.
with
base_tree as (
    select path, id
    from gitlab_repo_trees
    where installation_id = $installation_id
          and sha = $base_sha
          and cache_day =
              (select max(cache_day)
               from gitlab_repo_trees
               where installation_id = $installation_id and sha = $base_sha)
),
head_tree as (
    select path, id
    from gitlab_repo_trees
    where installation_id = $installation_id
          and sha = $sha
          and cache_day =
              (select max(cache_day)
               from gitlab_repo_trees
               where installation_id = $installation_id and sha = $sha)
)
select coalesce(head_tree.path, base_tree.path)
from head_tree
full outer join base_tree
     on head_tree.path = base_tree.path
where head_tree.path is null
      or base_tree.path is null
      or head_tree.id is null
      or base_tree.id is null
      or head_tree.id is distinct from base_tree.id
