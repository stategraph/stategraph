-- Update the profile fields a caller may change; a null argument leaves its column alone.
--
-- The admin grant is deliberately absent, it's done in a separate statement (but in the same transaction).
-- The capabilities returned below are that write's result when it ran first in this
-- transaction, which is how the response reports the grant it just made.
update users
set
    name = coalesce($name, users.name),
    email = coalesce($email, users.email),
    avatar_url = coalesce($avatar_url, users.avatar_url)
where id = $user_id
  and state = 'active'
returning id, name, email, type, avatar_url, auth_origin, users.capability_trie, to_char(created_at, 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"')
