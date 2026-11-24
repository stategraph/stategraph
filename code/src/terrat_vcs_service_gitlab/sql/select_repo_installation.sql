-- Which installation, if any, already owns this repository id.  Used to drop
-- events that name a repository belonging to a different installation, while
-- still letting an installation record a repository it is seeing for the first
-- time.
select installation_id
from gitlab_installation_repositories
where id = $id
