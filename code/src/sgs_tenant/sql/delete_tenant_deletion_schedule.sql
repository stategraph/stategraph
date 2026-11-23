-- A reopened tenant leaves the deletion schedule.  A deleted tenant keeps its row as the record of
-- its deletion.
delete from tenant_deletions where tenant_id = $tenant_id and deleted_at is null
