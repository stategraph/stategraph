select 1
from tenant_vcs_installations as tvi
inner join terrateam_admin.gitlab_installations_map as m
  on m.core_id = tvi.installation_core_id
where tvi.tenant_id = $tenant_id
  and tvi.provider = 'gitlab'
  and m.installation_id = $group_id
