select id, slug, client_id, client_secret, html_url,
       to_char(created_at at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
       loaded_at is not null
from terrateam_admin.github_app
