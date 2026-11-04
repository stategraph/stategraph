-- The rows a node still owes, in the order the dispatcher ranks them.  The
-- dispatcher is select_next_work_manifest.sql, whose ranking orders by priority
-- (the run type of the work manifest), then by created_at, then by id, and that
-- statement is the authority for the three keys: the row it started must be the
-- first row this statement serves, or the action run of one work manifest is
-- started with the run id of another.  The join to work_manifests reads the run
-- type the priority comes from.
--
-- [compute_node_work.created_at] and [work_manifests.created_at] are written in
-- the same transaction, so ordering by either is the same order for the rows the
-- dispatcher made; the ranking orders on the work manifest's column.
--
-- [work_manifest] is the final tiebreak, and it is the same tiebreak the ranking
-- uses: the index [compute_node_work_work_manifest_idx] makes a work manifest
-- unique for a node.  The index [compute_node_work_created_idx] carries the
-- columns of the where, so the join and the sort are over the rows of one node,
-- which are at most the cap of nine.
select
  to_char(cnw.created_at, 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'),
  cnw.state,
  cnw.work,
  cnw.work_manifest
from compute_node_work as cnw
inner join work_manifests as wm on wm.id = cnw.work_manifest
where cnw.compute_node = $compute_node_id and cnw.state = 'created'
order by (case wm.run_type
          when 'autoapply' then 0
          when 'apply' then 0
          when 'unsafe-apply' then 0
          when 'autoplan' then 1
          when 'plan' then 1
          end),
         wm.created_at,
         wm.id
