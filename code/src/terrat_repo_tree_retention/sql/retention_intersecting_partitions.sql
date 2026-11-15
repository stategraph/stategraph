-- The children of [$parent] whose bounds intersect [[$from, $to)]: the overlap check the drain
-- runs before it creates a partition. A child that covers the range exactly is the covered day;
-- a child that only partly overlaps it is a misaligned partition whose bounds the creation would
-- collide with, so the day is skipped instead.  The [regexp_match] is the regex rule's
-- documented exception in RFD 1724: the catalog renders a partition's bound only as text, and
-- the bound is decomposed at write time, so there is no column to read it from.  The parent is
-- matched in [current_schema()] and not by bare [relname]: an unqualified [drop table] resolves
-- through the session's [search_path], and [current_schema()] is the schema an unqualified [create]
-- targets and an unqualified [drop] resolves to, so the scan and the drop agree by definition.  A
-- null [current_schema()] answers no row, which is a no-op.
select relname, bound_from, bound_to
from (
  select c.relname as relname,
         (regexp_match(pg_get_expr(c.relpartbound, c.oid),
                       'FROM \(''([^'']+)''\) TO \(''([^'']+)''\)$'))[1] as bound_from,
         (regexp_match(pg_get_expr(c.relpartbound, c.oid),
                       'FROM \(''([^'']+)''\) TO \(''([^'']+)''\)$'))[2] as bound_to
  from pg_inherits as i
  inner join pg_class as p on i.inhparent = p.oid
  inner join pg_class as c on i.inhrelid = c.oid
  inner join pg_namespace as n on p.relnamespace = n.oid
  where p.relname = $parent
    and n.nspname = current_schema()
    and c.relkind = 'r'
) as bounds
where bound_from::date < $to::date
  and bound_to::date > $from::date
