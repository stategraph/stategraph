insert into caps_group_rules (tenant_id, created_by, description, condition, capability_trie)
values ($tenant_id, $created_by, $description, $condition, $capability_trie)
returning id
