select
    id,
    tenant_id,
    to_char(created_at, 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
    created_by,
    description,
    condition,
    capability_trie
from caps_group_rules
where deleted_at is null and tenant_id = $tenant_id and id = $id
