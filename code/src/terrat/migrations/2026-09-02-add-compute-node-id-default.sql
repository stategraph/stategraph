-- Until now the id of a compute node was the id of its first work manifest,
-- because the server chose it.  The phase before this one made every read of a
-- node go through compute_node_work, so nothing needs that equality any more and
-- the database can choose the id.  Other tables in this schema do the same, for
-- example work_manifests.id.  gen_random_uuid is part of PostgreSQL and it needs
-- no extension.
alter table compute_nodes alter column id set default gen_random_uuid()
