-- The index below is what the poll reads: the rows a node still owes, in the
-- order the job made them.  The pair is a total order because
-- [compute_node_work_work_manifest_idx] makes a work manifest unique for a node.
--
-- The build is not concurrent, and this migration is not asynchronous, on
-- purpose.  An asynchronous migration is recorded as done before its SQL runs
-- (see [Data_mig.exec]), so a failed build is never tried again, and the next
-- phase would then run without the index it needs.  A build inside the
-- transaction fails the migration instead, which leaves it unrecorded and tries
-- again on the next boot.
create index compute_node_work_created_idx
       on compute_node_work (compute_node, created_at, work_manifest)
       where state = 'created';
