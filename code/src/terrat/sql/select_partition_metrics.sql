-- The partition-health metrics of the repo tree tables, for the /metrics endpoint.  One row per
-- parent table: the number of its partitions, their total disk size, and the disk size of the
-- [_default] partition among them.  The parents live only in the Terrat connection's catalog, so
-- the scan runs there, not through the FDW.  [count(*)] is [int8]; [sum] over [int8] is
-- [numeric], so the size sums are cast to [bigint].
select
    parent.relname as table_name,
    count(*) as partitions,
    sum(pg_total_relation_size(child.oid))::bigint as total_size,
    coalesce(
        sum(pg_total_relation_size(child.oid))
        filter (where child.relname = parent.relname || '_default'),
        0
    )::bigint as default_size
from pg_inherits
inner join pg_class as parent
    on pg_inherits.inhparent = parent.oid
inner join pg_class as child
    on pg_inherits.inhrelid = child.oid
inner join pg_namespace as n
    on parent.relnamespace = n.oid
where parent.relname in ('repo_trees', 'repo_tree_builds')
  and n.nspname = current_schema()
group by parent.relname
