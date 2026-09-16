-- A compute node is made when its work manifest is made, which is before the
-- dispatcher starts an action run for it.  The node is in this new state until
-- the dispatcher moves it to 'starting'.
insert into compute_node_states values ('queued');

-- A row of compute_node_work is written when the work manifest is made, but the
-- response for the action is calculated later, on the first poll.  A row with no
-- 'work' shows that the node has the work manifest, but that the server has not
-- made the response yet.
alter table compute_node_work alter column work drop not null;

-- The read from a work manifest to its compute node.  The primary key is
-- (compute_node, work_manifest), so it cannot serve this read, and the read then
-- scans the full table.  The index also makes sure that a work manifest has no
-- more than one compute node, which the next phase depends on.
--
-- The build is not concurrent, and this migration is not asynchronous, on
-- purpose.  An asynchronous migration is recorded as done before its SQL runs
-- (see [Data_mig.exec]), so a build that fails is never tried again, and the
-- next phase would then run without the index it needs.  A build inside the
-- transaction fails the migration instead, which leaves it unrecorded and tries
-- again on the next boot.
create unique index compute_node_work_work_manifest_idx
       on compute_node_work (work_manifest)
