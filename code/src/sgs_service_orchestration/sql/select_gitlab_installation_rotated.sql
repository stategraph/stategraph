select gi.name, gi.state
from terrateam_admin.gitlab_installations as gi
where gi.id = $group_id
