update caps_group_rules
set deleted_at = now()
where id = $id and tenant_id = $tenant_id and deleted_at is null
returning id
