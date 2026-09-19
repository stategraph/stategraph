insert into repo_configs (installation, repo, branch, sha, data, kind)
select
        gim.core_id,
        grm.core_id,
        $branch,
        $sha,
        $data,
        'derived'
from github_installations_map as gim
inner join github_repositories_map as grm
      on grm.repository_id = $repository_id
where gim.installation_id = $installation_id
on conflict (installation, repo, branch, sha) where kind = 'derived'
do update set data = excluded.data, created_at = now()
