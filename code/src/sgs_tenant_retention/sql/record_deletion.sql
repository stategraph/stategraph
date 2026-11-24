update tenant_deletions
set deleted_at = now(), deleted_rows = $deleted_rows
where tenant_id = $tenant_id
