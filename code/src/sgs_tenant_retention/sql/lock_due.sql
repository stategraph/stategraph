-- Locks one tenant whose deletion is due, and its schedule row, for the transaction of its
-- deletion.  No row: the deletion is no longer due.
select d.tenant_id
from tenant_deletions as d
inner join tenants as t on t.id = d.tenant_id
where d.tenant_id = $tenant_id
    and d.deleted_at is null
    and d.hold is null
    and d.delete_after <= now()
    and t.ended_at is not null
for update of d, t
