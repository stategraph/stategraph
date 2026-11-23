-- A member of an open tenant: a closed tenant answers no member, so it refuses every request that
-- needs one.
select tu.user_id
from tenant_users as tu
inner join tenants as t on t.id = tu.tenant_id
where tu.tenant_id = $tenant_id and tu.user_id = $user_id and t.ended_at is null
