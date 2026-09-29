select gi.webhook_secret, gi.state, m.core_id
from terrateam_admin.gitlab_installations as gi
inner join terrateam_admin.gitlab_installations_map as m on m.installation_id = gi.id
where gi.id = $group_id
