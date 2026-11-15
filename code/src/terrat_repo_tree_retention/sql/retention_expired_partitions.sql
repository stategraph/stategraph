-- The children of [$parent] whose upper bound is not after the cutoff day of [$days] days. The
-- bound is read out of the catalog and not out of the partition's name -- the migration's static
-- names say nothing about their bounds -- so the comparison is the retention rule itself: a
-- partition is expired when its [to] bound is on or before the cutoff day, which keeps the day
-- the cutoff falls in.  The [<=] is what keeps a partition whose [to] bound equals the cutoff
-- day from being stranded forever: a strict [<] never drops it, and no earlier run does either.
-- The [regexp_match] is the regex rule's documented exception in
-- RFD 1724: the catalog renders a partition's bound only as text, and the bound is
-- decomposed at write time, so there is no column to read it from.  The parent is matched in
-- [current_schema()] and not by bare [relname]: an unqualified [drop table] resolves through the
-- session's [search_path], and [current_schema()] is the schema an unqualified [create] targets
-- and an unqualified [drop] resolves to, so the scan and the drop agree by definition.  A null
-- [current_schema()] answers no row, which is a no-op.
select c.relname
from pg_inherits as i
inner join pg_class as p on i.inhparent = p.oid
inner join pg_class as c on i.inhrelid = c.oid
inner join pg_namespace as n on p.relnamespace = n.oid
where p.relname = $parent
  and n.nspname = current_schema()
  and c.relkind = 'r'
  and (regexp_match(pg_get_expr(c.relpartbound, c.oid), 'TO \(''([^'']+)''\)$'))[1]::date
      <= current_date - $days
