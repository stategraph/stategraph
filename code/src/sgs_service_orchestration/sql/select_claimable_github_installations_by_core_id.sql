-- The installations a proof names, restricted to those still linked to no
-- tenant. The core ids come from the caller's own signed proof, so this is a
-- lookup of an answer we already gave, re-checked against the link table
-- because another tenant may have claimed one in the meantime.
select gim.core_id, gi.id, gi.login, gi.target_type, gi.state,
       to_char(gi.created_at at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"')
from terrateam.github_installations as gi
inner join terrateam.github_installations_map as gim on gim.installation_id = gi.id
where gim.core_id = any($installation_core_ids)
  and not exists (
    select 1
    from tenant_vcs_installations as tvi
    where tvi.provider = 'github' and tvi.installation_core_id = gim.core_id)
order by gi.login
