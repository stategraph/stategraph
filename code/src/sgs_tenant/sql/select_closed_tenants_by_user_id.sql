select
    t.id,
    t.name,
    to_char(t.ended_at at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
from tenants as t
inner join tenant_users as tu on tu.tenant_id = t.id
where tu.user_id = $user_id and t.ended_at is not null
order by t.ended_at desc, t.id
