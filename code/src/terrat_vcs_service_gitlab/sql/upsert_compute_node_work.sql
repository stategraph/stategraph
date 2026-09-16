-- The cast on $work is required, do not remove it.  The column is jsonb and the
-- parameter is bound as json, and coalesce has no implicit cast between the two,
-- so without it PostgreSQL rejects the statement at parse time with 42846
-- "COALESCE could not convert type jsonb to json".  It rejects it whether or not
-- a row conflicts, so add_work fails on the first write and takes the whole
-- transaction with it.  The value in the values clause needs no cast, because an
-- insert into a column takes an assignment cast.
insert into compute_node_work (compute_node, state, work, work_manifest)
values (
  $compute_node_id,
  'created',
  $work,
  $work_manifest
)
on conflict (compute_node, work_manifest) do update
set work = coalesce($work::jsonb, compute_node_work.work)
