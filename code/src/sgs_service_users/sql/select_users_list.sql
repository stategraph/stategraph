select
    users.id,
    users.name,
    users.email,
    users.type,
    users.avatar_url,
    users.auth_origin,
    users.capability_trie,
    to_char(users.created_at at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
    -- Stable across pages: the whole matching-user count, computed without the cursor predicate.
    -- Mirrors the main query's non-cursor filters (active, plus the optional type and search).
    (select count(*)
     from users as c
     where c.state = 'active'
       and ($type is null or c.type = $type)
       and ($search::text is null
            or c.name ilike '%' || $search || '%'
            or c.email ilike '%' || $search || '%')) as total_count
from users
where users.state = 'active'
  and ($type is null or users.type = $type)
  and ($search::text is null or users.name ilike '%' || $search || '%' or users.email ilike '%' || $search || '%')
  -- $cursor and $cursor_id are the created_at and id of the last row of the previous page.  Both
  -- are needed: users created in the same instant share a created_at (a bulk import, or any two
  -- inserts inside one transaction), so a created_at-only cursor drops every user holding the
  -- timestamp a page boundary lands on -- silently, since the listing still looks well-formed.  The
  -- pair matches the (created_at, id) sort exactly.  Same reasoning, and same shape, as
  -- select_tenant_users.sql.
  and ($cursor is null or (users.created_at, users.id) < ($cursor, $cursor_id))
order by users.created_at desc, users.id desc
limit $limit
