select gim.core_id, gi.id, gi.login, gi.target_type, gi.state,
       to_char(gi.created_at at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"')
from terrateam.github_installations as gi
inner join terrateam.github_installations_map as gim on gim.installation_id = gi.id
where gi.state <> 'uninstalled'
  and not exists (
    select 1
    from tenant_vcs_installations as tvi
    where tvi.provider = 'github' and tvi.installation_core_id = gim.core_id)
  -- The pair (created_at, core_id) sort exactly. Same
  -- reasoning, and same shape, as select_users_list.sql.
  and ($cursor is null or (gi.created_at, gim.core_id) < ($cursor, $cursor_id))
order by gi.created_at desc, gim.core_id desc
limit $limit
