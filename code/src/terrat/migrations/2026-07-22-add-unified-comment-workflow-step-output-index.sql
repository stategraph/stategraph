-- Supports looking up a dirspace's step outputs without scanning every row of
-- a work manifest.
create index concurrently if not exists workflow_step_outputs_dirspace_idx
    on workflow_step_outputs (work_manifest, (scope->>'dir'), (scope->>'workspace'))
    where scope->>'type' = 'dirspace';
