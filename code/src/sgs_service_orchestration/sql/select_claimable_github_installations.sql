-- Installations the caller has proven control of, restricted to those still
-- linked to no tenant. Takes the GitHub numeric installation ids the caller
-- proved (never a login or a name), so a rename on GitHub's side cannot
-- redirect the match. Unlike select_unclaimed_github_installations.sql this is
-- not a browse: the id list is the answer GitHub gave for this caller, so there
-- is nothing here to enumerate.
select gim.core_id, gi.id, gi.login, gi.target_type, gi.state,
       to_char(gi.created_at at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"')
from terrateam.github_installations as gi
inner join terrateam.github_installations_map as gim on gim.installation_id = gi.id
where gi.id = any($github_installation_ids)
  and not exists (
    select 1
    from tenant_vcs_installations as tvi
    where tvi.provider = 'github' and tvi.installation_core_id = gim.core_id)
order by gi.login
