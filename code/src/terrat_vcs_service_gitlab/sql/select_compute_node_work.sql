select
  to_char(created_at, 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'),
  state,
  work,
  work_manifest
from compute_node_work
where compute_node = $compute_node_id and state = 'created'
