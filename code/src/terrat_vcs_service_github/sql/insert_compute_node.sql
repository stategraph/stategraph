insert into compute_nodes (capabilities, state) values (
    $capabilities,
    'queued')
returning id, state, created_at, updated_at
