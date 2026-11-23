-- The members of a deleted tenant that belong to no tenant any more.  A user that the history of
-- another tenant still names keeps its row with its personal data blanked; any other one goes,
-- with its tokens.  Runs after delete_tenant.sql, in its transaction.
with
orphans as (
    select u.id
    from users as u
    where u.id in (select m.id from unnest($user_ids) as m(id))
        and u.type = 'user'
        and not exists (select 1 from tenant_users as tu where tu.user_id = u.id)
),
referenced as (
    select o.id
    from orphans as o
    where exists (select 1 from transactions as t where t.created_by = o.id or t.completed_by = o.id)
        or exists (select 1 from revision_hashes as r where r.user_id = o.id)
        or exists (select 1 from revision_tx_hashes as r where r.user_id = o.id)
        or exists (select 1 from transaction_logs as l where l.user_id = o.id)
        or exists (
            select 1
            from tenant_invitations as i
            where i.accepted_by = o.id or i.invited_by = o.id or i.revoked_by = o.id
        )
        or exists (select 1 from caps_group_rules as c where c.created_by = o.id)
        or exists (select 1 from states as s where s.deleted_by = o.id)
),
delete_access_tokens as (
    delete from access_tokens as a using orphans as o where a.user_id = o.id returning 1
),
blank_users as (
    update users as u
    set
        email = null,
        name = 'Deleted user',
        display_name = null,
        avatar_url = null,
        external_id = null,
        auth_origin = null,
        password_hash = null,
        state = 'deleted'
    from referenced as r
    where u.id = r.id
    returning 1
),
delete_users as (
    delete from users as u
    using orphans as o
    where u.id = o.id and not exists (select 1 from referenced as r where r.id = o.id)
    returning 1
)
select jsonb_build_object(
    'access_tokens', (select count(*) from delete_access_tokens),
    'users_blanked', (select count(*) from blank_users),
    'users_deleted', (select count(*) from delete_users)
)
