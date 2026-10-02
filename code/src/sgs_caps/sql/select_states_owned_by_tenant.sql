select id from states where id = any($state_ids) and tenant_id = $tenant_id
