insert into compute_nodes (capabilities, id, state) values (
    $capabilities,
    $id,
    'queued')
on conflict (id) do update
set updated_at = now()
returning state, created_at, updated_at
