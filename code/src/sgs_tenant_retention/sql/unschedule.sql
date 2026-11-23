-- Takes the tenants that are no longer closed off the schedule.  A deleted tenant keeps its row as
-- the record of its deletion.
delete from tenant_deletions as d
where d.deleted_at is null
    and not exists (select 1 from tenants as t where t.id = d.tenant_id and t.ended_at is not null)
returning d.tenant_id
