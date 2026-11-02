select
    dsprl.path as path,
    dsprl.workspace as workspace,
    gpr.base_branch as base_branch,
    gpr.branch as branch_name,
    gpr.base_sha as bash_hash,
    gpr.sha as hash,
    gpr.merged_sha as merged_hash,
    gpr.merged_at as merged_at,
    gpr.pull_number as id,
    gpr.state as state,
    gpr.title as title,
    gpr.username as username
from github_dirspace_pull_request_locks as dsprl
inner join github_pull_requests as gpr
    on gpr.repository = dsprl.repository
       and gpr.pull_number = dsprl.pull_number
inner join github_pull_requests as our_pr
    on our_pr.repository = gpr.repository
where our_pr.repository = $repository
      and our_pr.pull_number = $pull_number
      and gpr.pull_number <> our_pr.pull_number
      and (dsprl.path, dsprl.workspace) in (select dir, workspace
                                            from unnest($dirs, $workspaces) as v(dir, workspace))
      and (dsprl.branch_target = 'all'
           or (dsprl.branch_target = 'dest_branch'
               and our_pr.base_branch = gpr.base_branch))
