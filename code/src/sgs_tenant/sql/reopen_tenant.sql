-- No row: the tenant is not closed, or does not exist.
update tenants set ended_at = null where id = $tenant_id and ended_at is not null returning id
