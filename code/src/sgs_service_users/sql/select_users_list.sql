-- A page of the active users that the caller manages, newest first.
--
-- With $whole_installation, every active user is listed, users in no tenant included.  Otherwise a
-- user is listed when it is a member of an open tenant that the caller's grant reaches, and listed
-- once whatever the number of such tenants.
--
-- The rules come from Sg_caps_ops.Db_checks.scope_rules, which has flattened the grant's reach of
-- tenants.  Each pattern is a literal plus a `prefix` flag, so no character of $rule_pat means
-- anything here: `*` and `!` are gone, and matching is comparison, never LIKE.  The rule that
-- decides a tenant is the most specific one that matches its id -- the longest pattern, a literal
-- before a prefix of the same length -- which is what DISTINCT ON picks below.  Every id matches
-- one rule, because the rules always hold one with an empty prefix.
--
-- What this query answers is what Sg_caps_ops.reaches_user_tenant answers.  The tests
-- users_list_reach_documented_examples and users_list_reach_agrees_with_oracle make sure that this
-- SQL file and the OCaml reference are equivalent.
--
-- The three $rule_* arrays are the columns of one table and are always the same length, being
-- built from a single list on the OCaml side.  unnest() pads a short array with NULLs rather than
-- failing, so that invariant matters.
with
  rules as (
    select *
    from unnest($rule_neg::boolean[], $rule_prefix::boolean[], $rule_pat::text[])
      as r(neg, prefix, pat)
  ),
  judged as (
    select distinct on (t.id)
           t.id,
           u.neg as refused
    from tenants as t
    join rules as u
      on (case when u.prefix then starts_with(t.id::text, u.pat)
               else t.id::text = u.pat end)
    where t.ended_at is null
    order by t.id, length(u.pat) desc, u.prefix asc
  ),
  members as (
    select distinct tu.user_id
    from tenant_users as tu
    join judged as j on j.id = tu.tenant_id
    where not j.refused
  )
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
    -- Mirrors the main query's non-cursor filters (active, the tenants, plus the optional type and
    -- search).
    (select count(*)
     from users as c
     where c.state = 'active'
       and ($whole_installation or c.id in (select user_id from members))
       and ($type is null or c.type = $type)
       and ($search::text is null
            or c.name ilike '%' || $search || '%'
            or c.email ilike '%' || $search || '%')) as total_count
from users
where users.state = 'active'
  and ($whole_installation or users.id in (select user_id from members))
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
