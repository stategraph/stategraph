insert into repo_trees (sha, path, changed, id, installation, cache_day)
select
        x.sha,
        x.path,
        x.changed,
        x.id,
        gim.core_id,
        current_date
from unnest(
  $installation_ids,
  $shas,
  $paths,
  $changed,
  $id
) as x(installation_id, sha, path, changed, id)
inner join github_installations_map as gim
      on gim.installation_id = x.installation_id
on conflict (installation, sha, cache_day, path)
do update set (
   changed,
   id
) = (
  excluded.changed,
  excluded.id
)
