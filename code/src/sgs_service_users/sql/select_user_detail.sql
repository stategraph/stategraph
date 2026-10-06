select
    users.id,
    users.name,
    users.email,
    users.type,
    users.avatar_url,
    users.auth_origin,
    users.capability_trie,
    to_char(users.created_at, 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"')
from users
where users.id = $user_id
  and users.state = 'active'
