-- The tenants whose deletion is due: on the schedule past their [delete_after], without a hold,
-- not deleted, and still closed.
select d.tenant_id
from tenant_deletions as d
inner join tenants as t on t.id = d.tenant_id
where d.deleted_at is null
    and d.hold is null
    and d.delete_after <= now()
    and t.ended_at is not null
order by d.delete_after, d.tenant_id
limit $limit
