select
    rc.data
from repo_configs as rc
inner join gitlab_installations_map as gim
      on rc.installation = gim.core_id
inner join gitlab_repositories_map as grm
      on rc.repo = grm.core_id
where rc.kind = 'derived'
      and gim.installation_id = $installation_id
      and grm.repository_id = $repository_id
      and rc.branch = $branch
      and rc.sha = any($shas)
      and rc.created_at > now() - make_interval(mins => $stale_min)
order by array_position($shas, rc.sha)
limit 1
