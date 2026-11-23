-- No row: the tenant is closed already, or does not exist.
update tenants set ended_at = now() where id = $tenant_id and ended_at is null returning id
